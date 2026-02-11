// ============================================================================
// FILE: GameSnapshot.swift
// LOCATION: Grow2 Shared/Data/GameSnapshot.swift
// PURPOSE: Periodic game state snapshots for online session recovery
// ============================================================================

import Foundation

// MARK: - Game Snapshot

struct GameSnapshot: Codable {
    let snapshotID: String
    let createdAt: Date
    let gameTime: TimeInterval
    let commandSequence: Int
    let stateJSON: String  // base64-encoded GameState JSON
    let sizeBytes: Int

    // MARK: - Create Snapshot from GameState

    static func create(from gameState: GameState, sequence: Int) -> GameSnapshot? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(gameState)

            return GameSnapshot(
                snapshotID: UUID().uuidString,
                createdAt: Date(),
                gameTime: gameState.currentTime,
                commandSequence: sequence,
                stateJSON: jsonData.base64EncodedString(),
                sizeBytes: jsonData.count
            )
        } catch {
            debugLog("Failed to create game snapshot: \(error)")
            return nil
        }
    }

    // MARK: - Restore GameState from Snapshot

    func toGameState() throws -> GameState {
        guard let data = Data(base64Encoded: stateJSON) else {
            throw GameSnapshotError.corruptedData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GameState.self, from: data)
    }

    // MARK: - Firestore Serialization

    func toFirestoreData() -> [String: Any] {
        return [
            "snapshotID": snapshotID,
            "createdAt": createdAt,
            "gameTime": gameTime,
            "commandSequence": commandSequence,
            "stateJSON": stateJSON,
            "sizeBytes": sizeBytes
        ]
    }

    static func fromFirestoreData(_ data: [String: Any]) -> GameSnapshot? {
        guard let snapshotID = data["snapshotID"] as? String,
              let gameTime = data["gameTime"] as? TimeInterval,
              let commandSequence = data["commandSequence"] as? Int,
              let stateJSON = data["stateJSON"] as? String,
              let sizeBytes = data["sizeBytes"] as? Int else {
            return nil
        }

        return GameSnapshot(
            snapshotID: snapshotID,
            createdAt: (data["createdAt"] as? Date) ?? Date(),
            gameTime: gameTime,
            commandSequence: commandSequence,
            stateJSON: stateJSON,
            sizeBytes: sizeBytes
        )
    }
}

// MARK: - Snapshot Errors

enum GameSnapshotError: LocalizedError {
    case corruptedData
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .corruptedData: return "Snapshot data is corrupted or missing."
        case .decodingFailed(let detail): return "Failed to decode snapshot: \(detail)"
        }
    }
}
