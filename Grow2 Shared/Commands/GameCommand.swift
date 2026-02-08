// ============================================================================
// FILE: Grow2 Shared/Commands/GameCommand.swift
// PURPOSE: Base protocol and types for the command pattern
// ============================================================================

import Foundation

// MARK: - Command Result

enum CommandResult {
    case success
    case failure(reason: String)

    var succeeded: Bool {
        if case .success = self { return true }
        return false
    }

    var failureReason: String? {
        if case .failure(let reason) = self { return reason }
        return nil
    }
}

// MARK: - Command Result with State Changes

/// Extended command result that includes state changes for the new architecture
enum CommandResultWithChanges {
    case success(changes: [StateChange])
    case failure(reason: String)

    var succeeded: Bool {
        if case .success = self { return true }
        return false
    }

    var failureReason: String? {
        if case .failure(let reason) = self { return reason }
        return nil
    }

    var changes: [StateChange] {
        if case .success(let changes) = self { return changes }
        return []
    }

    /// Convert to basic CommandResult
    func toCommandResult() -> CommandResult {
        switch self {
        case .success:
            return .success
        case .failure(let reason):
            return .failure(reason: reason)
        }
    }
}

// MARK: - Game Command Protocol

/// Base protocol for all game commands
protocol GameCommand: Codable {
    /// Unique identifier for this command
    var id: UUID { get }
    
    /// When the command was issued (for ordering)
    var timestamp: TimeInterval { get }
    
    /// Which player issued this command
    var playerID: UUID { get }
    
    /// The type of command (for decoding)
    static var commandType: CommandType { get }
    
    /// Validates whether this command can be executed in the current game state
    func validate(in context: CommandContext) -> CommandResult
    
    /// Executes the command and modifies game state
    func execute(in context: CommandContext) -> CommandResult
}

// MARK: - Command Type

/// Enum of all command types for polymorphic decoding
enum CommandType: String, Codable, CaseIterable {
    case move
    case build
    case trainMilitary
    case trainVillager
    case gather
    case stopGathering
    case attack
    case upgrade
    case cancelUpgrade
    case deployArmy
    case deployVillagers
    case reinforceArmy
    case cancelReinforcement
    case recruitCommander
    case demolish
    case cancelDemolition
    case retreat
    case joinVillagerGroup
    case entrench
    case upgradeUnit
}

// MARK: - Command Context

/// Provides access to game state for command validation and execution
class CommandContext {
    let hexMap: HexMap
    let player: Player
    let allPlayers: [Player]
    weak var gameScene: GameScene?  // ← MUST EXIST
    
    var onResourcesChanged: (() -> Void)?
    var onAlert: ((String, String) -> Void)?
    
    // Helper methods...
    func getPlayer(by id: UUID) -> Player? {
        return allPlayers.first { $0.id == id }
    }
    
    func getEntity(by id: UUID) -> EntityNode? {
        return hexMap.entities.first { $0.entity.id == id }
    }
    
    func getBuilding(at coordinate: HexCoordinate) -> BuildingNode? {
        return hexMap.getBuilding(at: coordinate)
    }

    func getBuilding(by id: UUID) -> BuildingNode? {
        return hexMap.buildings.first { $0.data.id == id }
    }
    
    init(hexMap: HexMap, player: Player, allPlayers: [Player], gameScene: GameScene?) {
        self.hexMap = hexMap
        self.player = player
        self.allPlayers = allPlayers
        self.gameScene = gameScene
    }
}

// MARK: - Command Wrapper (for polymorphic decoding)

/// Wrapper that allows encoding/decoding any command type
struct AnyCommand: Codable {
    let type: CommandType
    let data: Data
    
    init<T: GameCommand>(_ command: T) throws {
        self.type = T.commandType
        self.data = try JSONEncoder().encode(command)
    }
    
    func decode() throws -> any GameCommand {
        let decoder = JSONDecoder()
        
        switch type {
        case .move:
            return try decoder.decode(MoveCommand.self, from: data)
        case .build:
            return try decoder.decode(BuildCommand.self, from: data)
        case .trainMilitary:
            return try decoder.decode(TrainMilitaryCommand.self, from: data)
        case .trainVillager:
            return try decoder.decode(TrainVillagerCommand.self, from: data)
        case .gather:
            return try decoder.decode(GatherCommand.self, from: data)
        case .stopGathering:
            return try decoder.decode(StopGatheringCommand.self, from: data)
        case .attack:
            return try decoder.decode(AttackCommand.self, from: data)
        case .upgrade:
            return try decoder.decode(UpgradeCommand.self, from: data)
        case .cancelUpgrade:
            return try decoder.decode(CancelUpgradeCommand.self, from: data)
        case .deployArmy:
            return try decoder.decode(DeployArmyCommand.self, from: data)
        case .deployVillagers:
            return try decoder.decode(DeployVillagersCommand.self, from: data)
        case .reinforceArmy:
            return try decoder.decode(ReinforceArmyCommand.self, from: data)
        case .cancelReinforcement:
            return try decoder.decode(CancelReinforcementCommand.self, from: data)
        case .recruitCommander:
            return try decoder.decode(RecruitCommanderCommand.self, from: data)
        case .demolish:
            return try decoder.decode(DemolishCommand.self, from: data)
        case .cancelDemolition:
            return try decoder.decode(CancelDemolitionCommand.self, from: data)
        case .retreat:
            return try decoder.decode(RetreatCommand.self, from: data)
        case .joinVillagerGroup:
            return try decoder.decode(JoinVillagerGroupCommand.self, from: data)
        case .entrench:
            return try decoder.decode(EntrenchCommand.self, from: data)
        case .upgradeUnit:
            return try decoder.decode(UpgradeUnitCommand.self, from: data)
        }
    }
}

// MARK: - Engine-Compatible Game Command

/// Protocol for commands that can execute against the pure GameState
/// This allows commands to work with both the legacy system and the new engine
protocol EngineCompatibleCommand: GameCommand {
    /// Execute this command against the pure game state (new architecture)
    /// Returns state changes that describe what happened
    func executeOnEngine(in state: GameState, changeBuilder: StateChangeBuilder) -> CommandResultWithChanges

    /// Validate this command against the pure game state
    func validateOnEngine(in state: GameState) -> CommandResult
}

// MARK: - Default Implementation

extension EngineCompatibleCommand {
    /// Default implementation that falls back to legacy execution
    func executeOnEngine(in state: GameState, changeBuilder: StateChangeBuilder) -> CommandResultWithChanges {
        // By default, commands that haven't been updated will just return success
        // Subclasses should override to provide proper state change tracking
        return .success(changes: [])
    }

    func validateOnEngine(in state: GameState) -> CommandResult {
        // Default validation - subclasses should override
        return .success
    }
}

// MARK: - Command Bridge

/// Bridges between legacy CommandContext and new GameState for gradual migration
class CommandBridge {

    /// Execute a command using the appropriate system based on availability
    static func execute<T: GameCommand>(_ command: T, context: CommandContext?, gameState: GameState?) -> CommandResult {
        // If this command supports the new engine and we have a game state, use it
        if let engineCommand = command as? EngineCompatibleCommand,
           let state = gameState {
            let validation = engineCommand.validateOnEngine(in: state)
            guard validation.succeeded else { return validation }

            let changeBuilder = StateChangeBuilder(currentTime: state.currentTime, sourceCommandID: command.id)
            let result = engineCommand.executeOnEngine(in: state, changeBuilder: changeBuilder)

            // Notify the game engine of changes
            if result.succeeded {
                let batch = changeBuilder.build()
                if !batch.changes.isEmpty {
                    GameEngine.shared.delegate?.gameEngine(GameEngine.shared, didProduceChanges: batch)
                }
            }

            return result.toCommandResult()
        }

        // Fall back to legacy context-based execution
        if let ctx = context {
            let validation = command.validate(in: ctx)
            guard validation.succeeded else { return validation }
            return command.execute(in: ctx)
        }

        return .failure(reason: "No execution context available")
    }
}
