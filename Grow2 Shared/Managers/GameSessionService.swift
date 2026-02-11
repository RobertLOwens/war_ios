// ============================================================================
// FILE: GameSessionService.swift
// LOCATION: Grow2 Shared/Managers/GameSessionService.swift
// PURPOSE: Online game session lifecycle - create, command streaming, snapshots
// ============================================================================

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Delegate Protocol

protocol GameSessionServiceDelegate: AnyObject {
    func sessionService(_ service: GameSessionService, didReceiveCommand command: OnlineCommand)
    func sessionService(_ service: GameSessionService, playerStatusChanged uid: String, status: PlayerSessionStatus)
    func sessionService(_ service: GameSessionService, sessionStatusChanged status: GameSessionStatus)
}

// MARK: - Game Session Service

class GameSessionService {

    static let shared = GameSessionService()

    private(set) var currentSession: GameSession?
    private(set) var isHost: Bool = false

    weak var delegate: GameSessionServiceDelegate?

    private let db = Firestore.firestore()
    private var commandListener: ListenerRegistration?
    private var sessionListener: ListenerRegistration?
    private var heartbeatTimer: Timer?

    // Snapshot strategy
    private var commandsSinceSnapshot: Int = 0
    private var lastSnapshotTime: Date = Date()
    private let snapshotCommandInterval = 100
    private let snapshotTimeInterval: TimeInterval = 300  // 5 minutes
    private let maxSnapshots = 3

    private init() {}

    // MARK: - Game Collection Reference

    private func gamesCollection() -> CollectionReference {
        return db.collection("games")
    }

    private func gameDocument(_ gameID: String) -> DocumentReference {
        return gamesCollection().document(gameID)
    }

    // MARK: - Create Game

    func createGame(
        mapConfig: MapGenerationConfig,
        aiPlayers: [(displayName: String, playerID: UUID, colorHex: String)],
        hostPlayerID: UUID,
        hostColorHex: String,
        completion: @escaping (Result<GameSession, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(GameSessionError.notSignedIn))
            return
        }

        let displayName = AuthService.shared.cachedUsername ?? Auth.auth().currentUser?.displayName ?? Auth.auth().currentUser?.email ?? "Player"

        let session = GameSession.create(
            hostUID: uid,
            hostDisplayName: displayName,
            hostPlayerID: hostPlayerID,
            hostColorHex: hostColorHex,
            mapConfig: mapConfig,
            aiPlayers: aiPlayers
        )

        let docRef = gameDocument(session.gameID)
        docRef.setData(session.toFirestoreData()) { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }

            self?.currentSession = session
            self?.isHost = true
            self?.commandsSinceSnapshot = 0
            self?.lastSnapshotTime = Date()

            debugLog("Online game created: \(session.gameID)")
            completion(.success(session))
        }
    }

    // MARK: - Submit Command (GameCommand)

    func submitCommand<T: GameCommand>(_ command: T, isAI: Bool = false, completion: ((Error?) -> Void)? = nil) {
        guard var session = currentSession else {
            completion?(GameSessionError.noActiveSession)
            return
        }

        let sequence = session.currentCommandSequence + 1
        session.currentCommandSequence = sequence
        currentSession = session

        do {
            let onlineCmd = try OnlineCommand(sequence: sequence, command: command, isAI: isAI)
            writeCommand(onlineCmd, gameID: session.gameID, sequence: sequence, completion: completion)
        } catch {
            completion?(error)
        }
    }

    // MARK: - Submit AI Command (BaseEngineCommand)

    func submitAICommand(_ command: BaseEngineCommand, completion: ((Error?) -> Void)? = nil) {
        guard var session = currentSession else {
            completion?(GameSessionError.noActiveSession)
            return
        }

        guard let envelope = AICommandEnvelope.from(command) else {
            completion?(GameSessionError.serializationFailed)
            return
        }

        let sequence = session.currentCommandSequence + 1
        session.currentCommandSequence = sequence
        currentSession = session

        do {
            let onlineCmd = try OnlineCommand(sequence: sequence, envelope: envelope)
            writeCommand(onlineCmd, gameID: session.gameID, sequence: sequence, completion: completion)
        } catch {
            completion?(error)
        }
    }

    private func writeCommand(_ onlineCmd: OnlineCommand, gameID: String, sequence: Int, completion: ((Error?) -> Void)?) {
        let cmdRef = gameDocument(gameID).collection("commands").document(onlineCmd.commandID)

        cmdRef.setData(onlineCmd.toFirestoreData()) { [weak self] error in
            if let error = error {
                debugLog("Failed to write command: \(error)")
                completion?(error)
                return
            }

            // Update sequence on game document
            self?.gameDocument(gameID).updateData([
                "currentCommandSequence": sequence
            ])

            self?.commandsSinceSnapshot += 1
            completion?(nil)
        }
    }

    // MARK: - Command Listener

    func startCommandListener(fromSequence: Int) {
        guard let session = currentSession else { return }

        stopCommandListener()

        commandListener = gameDocument(session.gameID)
            .collection("commands")
            .whereField("sequence", isGreaterThan: fromSequence)
            .order(by: "sequence")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else {
                    if let error = error {
                        debugLog("Command listener error: \(error)")
                    }
                    return
                }

                for change in snapshot.documentChanges {
                    if change.type == .added {
                        let data = change.document.data()
                        if let cmd = OnlineCommand.fromFirestoreData(data) {
                            self.delegate?.sessionService(self, didReceiveCommand: cmd)
                        }
                    }
                }
            }
    }

    func stopCommandListener() {
        commandListener?.remove()
        commandListener = nil
    }

    // MARK: - Snapshots

    func createSnapshot(gameState: GameState, completion: ((Error?) -> Void)? = nil) {
        guard let session = currentSession else {
            completion?(GameSessionError.noActiveSession)
            return
        }

        guard let snapshot = GameSnapshot.create(from: gameState, sequence: session.currentCommandSequence) else {
            completion?(GameSessionError.serializationFailed)
            return
        }

        let snapshotRef = gameDocument(session.gameID).collection("snapshots").document(snapshot.snapshotID)

        snapshotRef.setData(snapshot.toFirestoreData()) { [weak self] error in
            if let error = error {
                completion?(error)
                return
            }

            // Update game doc with latest snapshot ID
            self?.gameDocument(session.gameID).updateData([
                "latestSnapshotID": snapshot.snapshotID,
                "currentGameTime": gameState.currentTime
            ])

            self?.commandsSinceSnapshot = 0
            self?.lastSnapshotTime = Date()

            // Prune old snapshots
            self?.pruneSnapshots(gameID: session.gameID)

            debugLog("Snapshot created: \(snapshot.snapshotID) (seq: \(snapshot.commandSequence))")
            completion?(nil)
        }
    }

    func shouldCreateSnapshot() -> Bool {
        return commandsSinceSnapshot >= snapshotCommandInterval ||
               Date().timeIntervalSince(lastSnapshotTime) >= snapshotTimeInterval
    }

    private func pruneSnapshots(gameID: String) {
        let snapshotsRef = gameDocument(gameID).collection("snapshots")
        snapshotsRef.order(by: "commandSequence", descending: true).getDocuments { snapshot, error in
            guard let docs = snapshot?.documents, docs.count > self.maxSnapshots else { return }

            // Delete all beyond the latest 3
            for doc in docs.dropFirst(self.maxSnapshots) {
                doc.reference.delete()
            }
        }
    }

    // MARK: - Load Latest Snapshot

    func loadLatestSnapshot(gameID: String, completion: @escaping (Result<(GameSnapshot, [OnlineCommand]), Error>) -> Void) {
        let gameRef = gameDocument(gameID)

        gameRef.getDocument { [weak self] document, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = document?.data(),
                  let session = GameSession.fromFirestoreData(data, gameID: gameID) else {
                completion(.failure(GameSessionError.sessionNotFound))
                return
            }

            self.currentSession = session
            self.isHost = session.hostUID == Auth.auth().currentUser?.uid

            guard let snapshotID = session.latestSnapshotID else {
                completion(.failure(GameSessionError.noSnapshot))
                return
            }

            // Load the snapshot
            gameRef.collection("snapshots").document(snapshotID).getDocument { snapshotDoc, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let snapData = snapshotDoc?.data(),
                      let snapshot = GameSnapshot.fromFirestoreData(snapData) else {
                    completion(.failure(GameSessionError.noSnapshot))
                    return
                }

                // Load commands since snapshot
                gameRef.collection("commands")
                    .whereField("sequence", isGreaterThan: snapshot.commandSequence)
                    .order(by: "sequence")
                    .getDocuments { cmdSnapshot, error in
                        if let error = error {
                            completion(.failure(error))
                            return
                        }

                        let commands = cmdSnapshot?.documents.compactMap { doc in
                            OnlineCommand.fromFirestoreData(doc.data())
                        } ?? []

                        completion(.success((snapshot, commands)))
                    }
            }
        }
    }

    // MARK: - List My Games

    func listMyGames(completion: @escaping (Result<[GameSession], Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(GameSessionError.notSignedIn))
            return
        }

        gamesCollection()
            .whereField("hostUID", isEqualTo: uid)
            .limit(to: 20)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                var sessions = snapshot?.documents.compactMap { doc in
                    GameSession.fromFirestoreData(doc.data(), gameID: doc.documentID)
                } ?? []

                sessions.sort { $0.createdAt > $1.createdAt }

                completion(.success(sessions))
            }
    }

    // MARK: - Update Game Status

    func updateGameStatus(_ status: GameSessionStatus, completion: ((Error?) -> Void)? = nil) {
        guard var session = currentSession else {
            completion?(GameSessionError.noActiveSession)
            return
        }

        session.status = status
        currentSession = session

        gameDocument(session.gameID).updateData([
            "status": status.rawValue
        ]) { error in
            completion?(error)
        }
    }

    // MARK: - Heartbeat

    func startHeartbeat() {
        stopHeartbeat()

        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func sendHeartbeat() {
        guard let session = currentSession,
              let uid = Auth.auth().currentUser?.uid else { return }

        gameDocument(session.gameID).updateData([
            "players.\(uid).lastHeartbeat": FieldValue.serverTimestamp(),
            "players.\(uid).status": PlayerSessionStatus.active.rawValue
        ])
    }

    // MARK: - Leave / Cleanup

    func leaveSession() {
        stopCommandListener()
        stopHeartbeat()

        if let session = currentSession, let uid = Auth.auth().currentUser?.uid {
            gameDocument(session.gameID).updateData([
                "players.\(uid).status": PlayerSessionStatus.left.rawValue
            ])
        }

        currentSession = nil
        isHost = false
    }

    func deleteGame(gameID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let gameRef = gameDocument(gameID)

        // Delete subcollections first
        let group = DispatchGroup()
        var deleteError: Error?

        for subcollection in ["commands", "snapshots", "playerData"] {
            group.enter()
            gameRef.collection(subcollection).getDocuments { snapshot, error in
                if let docs = snapshot?.documents {
                    for doc in docs {
                        doc.reference.delete()
                    }
                }
                if let error = error, deleteError == nil {
                    deleteError = error
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let error = deleteError {
                completion(.failure(error))
                return
            }

            gameRef.delete { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    if self.currentSession?.gameID == gameID {
                        self.currentSession = nil
                        self.isHost = false
                    }
                    completion(.success(()))
                }
            }
        }
    }
}

// MARK: - Errors

enum GameSessionError: LocalizedError {
    case notSignedIn
    case noActiveSession
    case sessionNotFound
    case noSnapshot
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You must be signed in to use online games."
        case .noActiveSession: return "No active game session."
        case .sessionNotFound: return "Game session not found."
        case .noSnapshot: return "No snapshot available for this game."
        case .serializationFailed: return "Failed to serialize game data."
        }
    }
}
