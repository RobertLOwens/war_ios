// ============================================================================
// FILE: GameSession.swift
// LOCATION: Grow2 Shared/Data/GameSession.swift
// PURPOSE: Online game session data types for multiplayer pipeline
// ============================================================================

import Foundation
import FirebaseFirestore

// MARK: - Game Session Status

enum GameSessionStatus: String, Codable {
    case lobby
    case playing
    case paused
    case finished
}

// MARK: - Player Session Status

enum PlayerSessionStatus: String, Codable {
    case active
    case disconnected
    case defeated
    case left
}

// MARK: - Map Generation Config

struct MapGenerationConfig: Codable {
    let mapType: String
    let seed: UInt64
    let width: Int
    let height: Int

    // ArabiaMapGenerator.Config fields
    var treePocketCount: Int = 25
    var treePocketSizeRange: [Int] = [3, 8]
    var mineralDepositCount: Int = 12
    var mineralDepositSizeRange: [Int] = [2, 4]
    var hillClusterChance: Double = 0.15
    var maxElevation: Int = 3

    func toArabiaConfig() -> ArabiaMapGenerator.Config {
        var config = ArabiaMapGenerator.Config()
        config.treePocketCount = treePocketCount
        if treePocketSizeRange.count == 2 {
            config.treePocketSizeRange = treePocketSizeRange[0]...treePocketSizeRange[1]
        }
        config.mineralDepositCount = mineralDepositCount
        if mineralDepositSizeRange.count == 2 {
            config.mineralDepositSizeRange = mineralDepositSizeRange[0]...mineralDepositSizeRange[1]
        }
        config.hillClusterChance = hillClusterChance
        config.maxElevation = maxElevation
        return config
    }

    static func fromArabia(seed: UInt64, config: ArabiaMapGenerator.Config = ArabiaMapGenerator.Config()) -> MapGenerationConfig {
        return MapGenerationConfig(
            mapType: "arabia",
            seed: seed,
            width: 35,
            height: 35,
            treePocketCount: config.treePocketCount,
            treePocketSizeRange: [config.treePocketSizeRange.lowerBound, config.treePocketSizeRange.upperBound],
            mineralDepositCount: config.mineralDepositCount,
            mineralDepositSizeRange: [config.mineralDepositSizeRange.lowerBound, config.mineralDepositSizeRange.upperBound],
            hillClusterChance: config.hillClusterChance,
            maxElevation: config.maxElevation
        )
    }
}

// MARK: - Game Session Player

struct GameSessionPlayer: Codable {
    let uid: String
    let displayName: String
    let playerID: String  // UUID string
    let colorHex: String
    let isAI: Bool
    let isHost: Bool
    var status: PlayerSessionStatus
    var lastHeartbeat: Date

    func toFirestoreData() -> [String: Any] {
        return [
            "uid": uid,
            "displayName": displayName,
            "playerID": playerID,
            "colorHex": colorHex,
            "isAI": isAI,
            "isHost": isHost,
            "status": status.rawValue,
            "lastHeartbeat": lastHeartbeat
        ]
    }

    static func fromFirestoreData(_ data: [String: Any], uid: String) -> GameSessionPlayer? {
        guard let displayName = data["displayName"] as? String,
              let playerID = data["playerID"] as? String,
              let colorHex = data["colorHex"] as? String else {
            return nil
        }

        return GameSessionPlayer(
            uid: uid,
            displayName: displayName,
            playerID: playerID,
            colorHex: colorHex,
            isAI: data["isAI"] as? Bool ?? false,
            isHost: data["isHost"] as? Bool ?? false,
            status: PlayerSessionStatus(rawValue: data["status"] as? String ?? "active") ?? .active,
            lastHeartbeat: (data["lastHeartbeat"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

// MARK: - Game Session

struct GameSession: Codable {
    let gameID: String
    let hostUID: String
    let mapConfig: MapGenerationConfig
    var players: [String: GameSessionPlayer]  // keyed by uid
    var status: GameSessionStatus
    var currentCommandSequence: Int
    var latestSnapshotID: String?
    var currentGameTime: TimeInterval
    let gameSpeed: Double
    let gameVersion: String
    let createdAt: Date

    static func create(
        hostUID: String,
        hostDisplayName: String,
        hostPlayerID: UUID,
        hostColorHex: String,
        mapConfig: MapGenerationConfig,
        aiPlayers: [(displayName: String, playerID: UUID, colorHex: String)]
    ) -> GameSession {
        let gameID = UUID().uuidString

        var players: [String: GameSessionPlayer] = [:]

        // Host player
        players[hostUID] = GameSessionPlayer(
            uid: hostUID,
            displayName: hostDisplayName,
            playerID: hostPlayerID.uuidString,
            colorHex: hostColorHex,
            isAI: false,
            isHost: true,
            status: .active,
            lastHeartbeat: Date()
        )

        // AI players (keyed by "ai_0", "ai_1", etc.)
        for (index, ai) in aiPlayers.enumerated() {
            let aiKey = "ai_\(index)"
            players[aiKey] = GameSessionPlayer(
                uid: aiKey,
                displayName: ai.displayName,
                playerID: ai.playerID.uuidString,
                colorHex: ai.colorHex,
                isAI: true,
                isHost: false,
                status: .active,
                lastHeartbeat: Date()
            )
        }

        return GameSession(
            gameID: gameID,
            hostUID: hostUID,
            mapConfig: mapConfig,
            players: players,
            status: .lobby,
            currentCommandSequence: 0,
            latestSnapshotID: nil,
            currentGameTime: 0,
            gameSpeed: 1.0,
            gameVersion: "1.0.0",
            createdAt: Date()
        )
    }

    func toFirestoreData() -> [String: Any] {
        var playersData: [String: Any] = [:]
        for (key, player) in players {
            playersData[key] = player.toFirestoreData()
        }

        var mapConfigData: [String: Any] = [:]
        mapConfigData["mapType"] = mapConfig.mapType
        mapConfigData["seed"] = Int64(bitPattern: mapConfig.seed)  // Firestore doesn't support UInt64
        mapConfigData["width"] = mapConfig.width
        mapConfigData["height"] = mapConfig.height
        mapConfigData["treePocketCount"] = mapConfig.treePocketCount
        mapConfigData["treePocketSizeRange"] = mapConfig.treePocketSizeRange
        mapConfigData["mineralDepositCount"] = mapConfig.mineralDepositCount
        mapConfigData["mineralDepositSizeRange"] = mapConfig.mineralDepositSizeRange
        mapConfigData["hillClusterChance"] = mapConfig.hillClusterChance
        mapConfigData["maxElevation"] = mapConfig.maxElevation

        return [
            "hostUID": hostUID,
            "status": status.rawValue,
            "gameSpeed": gameSpeed,
            "gameVersion": gameVersion,
            "mapConfig": mapConfigData,
            "players": playersData,
            "currentCommandSequence": currentCommandSequence,
            "latestSnapshotID": latestSnapshotID as Any,
            "currentGameTime": currentGameTime,
            "createdAt": createdAt
        ]
    }

    static func fromFirestoreData(_ data: [String: Any], gameID: String) -> GameSession? {
        guard let hostUID = data["hostUID"] as? String,
              let statusRaw = data["status"] as? String,
              let status = GameSessionStatus(rawValue: statusRaw),
              let mapConfigData = data["mapConfig"] as? [String: Any],
              let mapType = mapConfigData["mapType"] as? String,
              let seedInt64 = mapConfigData["seed"] as? Int64,
              let width = mapConfigData["width"] as? Int,
              let height = mapConfigData["height"] as? Int else {
            return nil
        }

        let seed = UInt64(bitPattern: seedInt64)

        let mapConfig = MapGenerationConfig(
            mapType: mapType,
            seed: seed,
            width: width,
            height: height,
            treePocketCount: mapConfigData["treePocketCount"] as? Int ?? 25,
            treePocketSizeRange: mapConfigData["treePocketSizeRange"] as? [Int] ?? [3, 8],
            mineralDepositCount: mapConfigData["mineralDepositCount"] as? Int ?? 12,
            mineralDepositSizeRange: mapConfigData["mineralDepositSizeRange"] as? [Int] ?? [2, 4],
            hillClusterChance: mapConfigData["hillClusterChance"] as? Double ?? 0.15,
            maxElevation: mapConfigData["maxElevation"] as? Int ?? 3
        )

        var players: [String: GameSessionPlayer] = [:]
        if let playersData = data["players"] as? [String: Any] {
            for (key, value) in playersData {
                if let playerData = value as? [String: Any],
                   let player = GameSessionPlayer.fromFirestoreData(playerData, uid: key) {
                    players[key] = player
                }
            }
        }

        return GameSession(
            gameID: gameID,
            hostUID: hostUID,
            mapConfig: mapConfig,
            players: players,
            status: status,
            currentCommandSequence: data["currentCommandSequence"] as? Int ?? 0,
            latestSnapshotID: data["latestSnapshotID"] as? String,
            currentGameTime: data["currentGameTime"] as? TimeInterval ?? 0,
            gameSpeed: data["gameSpeed"] as? Double ?? 1.0,
            gameVersion: data["gameVersion"] as? String ?? "1.0.0",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}
