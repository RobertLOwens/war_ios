// ============================================================================
// FILE: UserStatsService.swift
// LOCATION: Grow2 Shared/Managers/UserStatsService.swift
// PURPOSE: Firestore-backed lifetime user statistics tracking
// ============================================================================

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Game History Entry

struct GameHistoryEntry {
    let date: Date
    let isVictory: Bool
    let reason: String
    let duration: Double
    let battlesWon: Int
    let battlesLost: Int
    let unitsKilled: Int
    let unitsLost: Int
    let buildingsBuilt: Int
    let resourcesGathered: Int
    let maxPopulation: Int

    init(data: [String: Any]) {
        self.date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
        self.isVictory = data["isVictory"] as? Bool ?? false
        self.reason = data["reason"] as? String ?? "unknown"
        self.duration = data["duration"] as? Double ?? 0
        self.battlesWon = data["battlesWon"] as? Int ?? 0
        self.battlesLost = data["battlesLost"] as? Int ?? 0
        self.unitsKilled = data["unitsKilled"] as? Int ?? 0
        self.unitsLost = data["unitsLost"] as? Int ?? 0
        self.buildingsBuilt = data["buildingsBuilt"] as? Int ?? 0
        self.resourcesGathered = data["resourcesGathered"] as? Int ?? 0
        self.maxPopulation = data["maxPopulation"] as? Int ?? 0
    }
}

// MARK: - User Stats Model

struct UserStats: Codable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var gamesLost: Int = 0
    var totalPlayTime: Double = 0
    var battlesWon: Int = 0
    var battlesLost: Int = 0
    var unitsKilled: Int = 0
    var unitsLost: Int = 0
    var buildingsBuilt: Int = 0
    var totalResourcesGathered: Int = 0
    var highestPopulation: Int = 0
    var lastUpdated: Date = Date()
}

// MARK: - User Stats Service

class UserStatsService {

    static let shared = UserStatsService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Firestore Path

    private func statsDocument(uid: String) -> DocumentReference {
        return db.collection("users").document(uid).collection("stats").document("lifetime")
    }

    // MARK: - Fetch Stats

    func fetchStats(completion: @escaping (Result<UserStats, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "UserStatsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }

        statsDocument(uid: uid).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data() else {
                // No stats yet — return defaults
                completion(.success(UserStats()))
                return
            }

            let stats = UserStats(
                gamesPlayed: data["gamesPlayed"] as? Int ?? 0,
                gamesWon: data["gamesWon"] as? Int ?? 0,
                gamesLost: data["gamesLost"] as? Int ?? 0,
                totalPlayTime: data["totalPlayTime"] as? Double ?? 0,
                battlesWon: data["battlesWon"] as? Int ?? 0,
                battlesLost: data["battlesLost"] as? Int ?? 0,
                unitsKilled: data["unitsKilled"] as? Int ?? 0,
                unitsLost: data["unitsLost"] as? Int ?? 0,
                buildingsBuilt: data["buildingsBuilt"] as? Int ?? 0,
                totalResourcesGathered: data["totalResourcesGathered"] as? Int ?? 0,
                highestPopulation: data["highestPopulation"] as? Int ?? 0,
                lastUpdated: (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
            )
            completion(.success(stats))
        }
    }

    // MARK: - Record Game End

    func recordGameEnd(isVictory: Bool, reason: GameOverReason, stats: GameStatistics) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let docRef = statsDocument(uid: uid)

        // Use a transaction so we can read-then-compare for highestPopulation
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let snapshot: DocumentSnapshot
            do {
                try snapshot = transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            let currentHighest = snapshot.data()?["highestPopulation"] as? Int ?? 0
            let newHighest = max(currentHighest, stats.maxPopulation)

            var updateData: [String: Any] = [
                "gamesPlayed": FieldValue.increment(Int64(1)),
                "totalPlayTime": FieldValue.increment(stats.totalTimePlayed),
                "battlesWon": FieldValue.increment(Int64(stats.battlesWon)),
                "battlesLost": FieldValue.increment(Int64(stats.battlesLost)),
                "unitsKilled": FieldValue.increment(Int64(stats.unitsKilled)),
                "unitsLost": FieldValue.increment(Int64(stats.unitsLost)),
                "buildingsBuilt": FieldValue.increment(Int64(stats.buildingsBuilt)),
                "totalResourcesGathered": FieldValue.increment(Int64(stats.totalResourcesGathered)),
                "highestPopulation": newHighest,
                "lastUpdated": FieldValue.serverTimestamp()
            ]

            if isVictory {
                updateData["gamesWon"] = FieldValue.increment(Int64(1))
            } else {
                updateData["gamesLost"] = FieldValue.increment(Int64(1))
            }

            transaction.setData(updateData, forDocument: docRef, merge: true)
            return nil
        }) { _, error in
            if let error = error {
                debugLog("Failed to record game stats: \(error)")
            } else {
                debugLog("Game stats recorded successfully")
            }
        }

        // Also record individual game history entry
        recordGameHistory(uid: uid, isVictory: isVictory, reason: reason, stats: stats)
    }

    // MARK: - Game History

    private func gameHistoryCollection(uid: String) -> CollectionReference {
        return db.collection("users").document(uid).collection("gameHistory")
    }

    private func recordGameHistory(uid: String, isVictory: Bool, reason: GameOverReason, stats: GameStatistics) {
        let data: [String: Any] = [
            "date": FieldValue.serverTimestamp(),
            "isVictory": isVictory,
            "reason": reason.rawValue,
            "duration": stats.totalTimePlayed,
            "battlesWon": stats.battlesWon,
            "battlesLost": stats.battlesLost,
            "unitsKilled": stats.unitsKilled,
            "unitsLost": stats.unitsLost,
            "buildingsBuilt": stats.buildingsBuilt,
            "resourcesGathered": stats.totalResourcesGathered,
            "maxPopulation": stats.maxPopulation
        ]

        gameHistoryCollection(uid: uid).addDocument(data: data) { error in
            if let error = error {
                debugLog("Failed to record game history: \(error)")
            } else {
                debugLog("Game history entry recorded")
            }
        }
    }

    func fetchRecentGames(completion: @escaping (Result<[GameHistoryEntry], Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "UserStatsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }

        gameHistoryCollection(uid: uid)
            .order(by: "date", descending: true)
            .limit(to: 10)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                let entries = snapshot?.documents.compactMap { doc in
                    GameHistoryEntry(data: doc.data())
                } ?? []
                completion(.success(entries))
            }
    }
}
