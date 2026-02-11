// ============================================================================
// FILE: OnlineCommand.swift
// LOCATION: Grow2 Shared/Data/OnlineCommand.swift
// PURPOSE: Serializable command wrapper for Firestore command streaming
// ============================================================================

import Foundation

// MARK: - Online Command Errors

enum OnlineCommandError: LocalizedError {
    case serializationFailed(String)
    case deserializationFailed(String)
    case unknownCommandType(String)

    var errorDescription: String? {
        switch self {
        case .serializationFailed(let detail): return "Failed to serialize command: \(detail)"
        case .deserializationFailed(let detail): return "Failed to deserialize command: \(detail)"
        case .unknownCommandType(let type): return "Unknown command type: \(type)"
        }
    }
}

// MARK: - Online Command

struct OnlineCommand: Codable {
    let sequence: Int
    let commandID: String
    let commandType: String
    let playerID: String
    let timestamp: TimeInterval
    let payload: String  // base64-encoded JSON
    let createdAt: Date
    let isAICommand: Bool

    // MARK: - Direct Init

    private init(sequence: Int, commandID: String, commandType: String, playerID: String, timestamp: TimeInterval, payload: String, createdAt: Date, isAICommand: Bool) {
        self.sequence = sequence
        self.commandID = commandID
        self.commandType = commandType
        self.playerID = playerID
        self.timestamp = timestamp
        self.payload = payload
        self.createdAt = createdAt
        self.isAICommand = isAICommand
    }

    // MARK: - Create from GameCommand

    init<T: GameCommand>(sequence: Int, command: T, isAI: Bool = false) throws {
        self.sequence = sequence
        self.commandID = command.id.uuidString
        self.commandType = T.commandType.rawValue
        self.playerID = command.playerID.uuidString
        self.timestamp = command.timestamp
        self.isAICommand = isAI
        self.createdAt = Date()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(command)
        self.payload = data.base64EncodedString()
    }

    // MARK: - Create from AI Command Envelope

    init(sequence: Int, envelope: AICommandEnvelope) throws {
        self.sequence = sequence
        self.commandID = envelope.commandID
        self.commandType = "ai_\(envelope.aiCommandType.rawValue)"
        self.playerID = envelope.playerID
        self.timestamp = envelope.timestamp
        self.isAICommand = true
        self.createdAt = Date()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        self.payload = data.base64EncodedString()
    }

    // MARK: - Decode to GameCommand

    func toGameCommand() throws -> any GameCommand {
        guard !isAICommand || !commandType.hasPrefix("ai_") else {
            throw OnlineCommandError.unknownCommandType(commandType)
        }

        guard let commandTypeEnum = CommandType(rawValue: commandType) else {
            throw OnlineCommandError.unknownCommandType(commandType)
        }

        guard let data = Data(base64Encoded: payload) else {
            throw OnlineCommandError.deserializationFailed("Invalid base64 payload")
        }

        let wrapper = AnyCommand(type: commandTypeEnum, data: data)
        return try wrapper.decode()
    }

    // MARK: - Decode AI Command Envelope

    func toAICommandEnvelope() throws -> AICommandEnvelope {
        guard let data = Data(base64Encoded: payload) else {
            throw OnlineCommandError.deserializationFailed("Invalid base64 payload")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AICommandEnvelope.self, from: data)
    }

    // MARK: - Firestore Serialization

    func toFirestoreData() -> [String: Any] {
        return [
            "sequence": sequence,
            "commandID": commandID,
            "commandType": commandType,
            "playerID": playerID,
            "timestamp": timestamp,
            "payload": payload,
            "createdAt": createdAt,
            "isAICommand": isAICommand
        ]
    }

    static func fromFirestoreData(_ data: [String: Any]) -> OnlineCommand? {
        guard let sequence = data["sequence"] as? Int,
              let commandID = data["commandID"] as? String,
              let commandType = data["commandType"] as? String,
              let playerID = data["playerID"] as? String,
              let timestamp = data["timestamp"] as? TimeInterval,
              let payload = data["payload"] as? String else {
            return nil
        }

        return OnlineCommand(
            sequence: sequence,
            commandID: commandID,
            commandType: commandType,
            playerID: playerID,
            timestamp: timestamp,
            payload: payload,
            createdAt: (data["createdAt"] as? Date) ?? Date(),
            isAICommand: data["isAICommand"] as? Bool ?? false
        )
    }
}

// MARK: - AnyCommand Extension for Direct Construction

extension AnyCommand {
    /// Direct initializer for reconstructing from known type and data
    init(type: CommandType, data: Data) {
        self.type = type
        self.data = data
    }
}
