// ============================================================================
// FILE: Grow2 Shared/Engine/GameEngine.swift
// PURPOSE: Main authoritative game engine - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Game Engine Delegate

protocol GameEngineDelegate: AnyObject {
    func gameEngine(_ engine: GameEngine, didProduceChanges changes: StateChangeBatch)
    func gameEngine(_ engine: GameEngine, didCompleteCommand commandID: UUID, result: EngineCommandResult)
    func gameEngineDidTick(_ engine: GameEngine, currentTime: TimeInterval)
}

// MARK: - Engine Command Result

enum EngineCommandResult {
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
}

// MARK: - Game Engine

/// The authoritative game engine that processes all game logic
/// Pure Swift - no SpriteKit dependencies
class GameEngine {

    // MARK: - Singleton
    static let shared = GameEngine()

    // MARK: - State
    private(set) var gameState: GameState?

    // MARK: - Subsystem Engines
    let movementEngine: MovementEngine
    let combatEngine: CombatEngine
    let resourceEngine: ResourceEngine
    let constructionEngine: ConstructionEngine
    let trainingEngine: TrainingEngine
    let visionEngine: VisionEngine
    let aiController: AIController

    // MARK: - Delegate
    weak var delegate: GameEngineDelegate?

    // MARK: - Tick Timing
    private var lastTickTime: TimeInterval = 0
    private let tickInterval: TimeInterval = 0.1  // 10 ticks per second

    // MARK: - Update Intervals
    private var lastVisionUpdate: TimeInterval = 0
    private var lastBuildingUpdate: TimeInterval = 0
    private var lastTrainingUpdate: TimeInterval = 0
    private var lastCombatUpdate: TimeInterval = 0
    private var lastResourceUpdate: TimeInterval = 0
    private var lastMovementUpdate: TimeInterval = 0
    private var lastAIUpdate: TimeInterval = 0

    private let visionUpdateInterval: TimeInterval = 0.25  // 4x per second
    private let buildingUpdateInterval: TimeInterval = 0.5  // 2x per second
    private let trainingUpdateInterval: TimeInterval = 1.0  // 1x per second
    private let combatUpdateInterval: TimeInterval = 1.0    // 1x per second
    private let resourceUpdateInterval: TimeInterval = 0.5  // 2x per second
    private let movementUpdateInterval: TimeInterval = 0.1  // 10x per second
    private let aiUpdateInterval: TimeInterval = 0.5        // AI decisions 2x per second

    // MARK: - Initialization

    private init() {
        self.movementEngine = MovementEngine()
        self.combatEngine = CombatEngine()
        self.resourceEngine = ResourceEngine()
        self.constructionEngine = ConstructionEngine()
        self.trainingEngine = TrainingEngine()
        self.visionEngine = VisionEngine()
        self.aiController = AIController.shared
    }

    // MARK: - Setup

    func setup(with gameState: GameState) {
        self.gameState = gameState
        lastTickTime = gameState.currentTime

        // Initialize subsystem engines with game state reference
        movementEngine.setup(gameState: gameState)
        combatEngine.setup(gameState: gameState)
        resourceEngine.setup(gameState: gameState)
        constructionEngine.setup(gameState: gameState)
        trainingEngine.setup(gameState: gameState)
        visionEngine.setup(gameState: gameState)
        aiController.setup(gameState: gameState)

        let aiCount = gameState.getAIPlayers().count
        print("GameEngine initialized with \(gameState.players.count) players (\(aiCount) AI)")
    }

    func reset() {
        gameState = nil
        lastTickTime = 0
        lastVisionUpdate = 0
        lastBuildingUpdate = 0
        lastTrainingUpdate = 0
        lastCombatUpdate = 0
        lastResourceUpdate = 0
        lastMovementUpdate = 0
        lastAIUpdate = 0
        aiController.reset()
    }

    // MARK: - Game Loop

    /// Main update function - call this every frame
    func update(currentTime: TimeInterval) {
        guard let state = gameState, !state.isPaused else { return }

        let adjustedTime = currentTime * state.gameSpeed
        state.currentTime = adjustedTime

        var allChanges: [StateChange] = []

        // Vision updates (4x per second)
        if adjustedTime - lastVisionUpdate >= visionUpdateInterval {
            let visionChanges = visionEngine.update(currentTime: adjustedTime)
            allChanges.append(contentsOf: visionChanges)
            lastVisionUpdate = adjustedTime
        }

        // Movement updates (10x per second)
        if adjustedTime - lastMovementUpdate >= movementUpdateInterval {
            let movementChanges = movementEngine.update(currentTime: adjustedTime)
            allChanges.append(contentsOf: movementChanges)
            lastMovementUpdate = adjustedTime
        }

        // Building construction/upgrade updates (2x per second)
        if adjustedTime - lastBuildingUpdate >= buildingUpdateInterval {
            let constructionChanges = constructionEngine.update(currentTime: adjustedTime)
            allChanges.append(contentsOf: constructionChanges)
            lastBuildingUpdate = adjustedTime
        }

        // Training updates (1x per second)
        if adjustedTime - lastTrainingUpdate >= trainingUpdateInterval {
            let trainingChanges = trainingEngine.update(currentTime: adjustedTime)
            allChanges.append(contentsOf: trainingChanges)
            lastTrainingUpdate = adjustedTime
        }

        // Resource gathering updates (2x per second)
        if adjustedTime - lastResourceUpdate >= resourceUpdateInterval {
            let resourceChanges = resourceEngine.update(currentTime: adjustedTime)
            allChanges.append(contentsOf: resourceChanges)
            lastResourceUpdate = adjustedTime
        }

        // Combat updates (1x per second)
        if adjustedTime - lastCombatUpdate >= combatUpdateInterval {
            let combatChanges = combatEngine.update(currentTime: adjustedTime)
            allChanges.append(contentsOf: combatChanges)
            lastCombatUpdate = adjustedTime
        }

        // AI updates (2x per second)
        if adjustedTime - lastAIUpdate >= aiUpdateInterval {
            let aiCommands = aiController.update(currentTime: adjustedTime)
            for command in aiCommands {
                let result = executeCommand(command)
                if !result.succeeded {
                    // AI command failed - this is expected sometimes (e.g., not enough resources)
                    // Just log it at debug level
                    if let reason = result.failureReason {
                        print("🤖 AI command failed: \(reason)")
                    }
                } else {
                    allChanges.append(contentsOf: result.changes)
                }
            }
            lastAIUpdate = adjustedTime
        }

        // Notify delegate if there are changes
        if !allChanges.isEmpty {
            let batch = StateChangeBatch(timestamp: adjustedTime, changes: allChanges)
            delegate?.gameEngine(self, didProduceChanges: batch)
        }

        // Notify tick
        delegate?.gameEngineDidTick(self, currentTime: adjustedTime)
        lastTickTime = adjustedTime
    }

    // MARK: - Command Execution

    /// Execute a command and return the result
    func executeCommand(_ command: EngineCommand) -> EngineCommandResult {
        guard let state = gameState else {
            return .failure(reason: "Game engine not initialized")
        }

        // Validate the command
        let validationResult = command.validate(in: state)
        guard validationResult.succeeded else {
            return .failure(reason: validationResult.failureReason ?? "Validation failed")
        }

        // Execute the command
        let changeBuilder = StateChangeBuilder(currentTime: state.currentTime, sourceCommandID: command.id)
        let executionResult = command.execute(in: state, changeBuilder: changeBuilder)

        guard executionResult.succeeded else {
            return .failure(reason: executionResult.failureReason ?? "Execution failed")
        }

        // Build and notify changes
        let batch = changeBuilder.build()
        if !batch.changes.isEmpty {
            delegate?.gameEngine(self, didProduceChanges: batch)
        }

        delegate?.gameEngine(self, didCompleteCommand: command.id, result: .success(changes: batch.changes))

        return .success(changes: batch.changes)
    }

    // MARK: - Convenience Methods

    /// Get the current game state
    func getGameState() -> GameState? {
        return gameState
    }

    /// Get a player by ID
    func getPlayer(id: UUID) -> PlayerState? {
        return gameState?.getPlayer(id: id)
    }

    /// Get the local player
    func getLocalPlayer() -> PlayerState? {
        return gameState?.getLocalPlayer()
    }

    /// Check if the game is paused
    func isPaused() -> Bool {
        return gameState?.isPaused ?? true
    }

    /// Pause the game
    func pause() {
        gameState?.isPaused = true
    }

    /// Resume the game
    func resume() {
        gameState?.isPaused = false
    }

    /// Set game speed
    func setGameSpeed(_ speed: Double) {
        gameState?.gameSpeed = max(0.1, min(speed, 10.0))
    }
}

// MARK: - Engine Command Protocol

/// Protocol for commands that can be executed by the game engine
protocol EngineCommand {
    var id: UUID { get }
    var playerID: UUID { get }
    var timestamp: TimeInterval { get }

    func validate(in state: GameState) -> EngineCommandResult
    func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult
}

// MARK: - Engine Command Base

/// Base class for engine commands
class BaseEngineCommand: EngineCommand {
    let id: UUID
    let playerID: UUID
    let timestamp: TimeInterval

    init(playerID: UUID) {
        self.id = UUID()
        self.playerID = playerID
        self.timestamp = Date().timeIntervalSince1970
    }

    func validate(in state: GameState) -> EngineCommandResult {
        // Override in subclasses
        return .success(changes: [])
    }

    func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        // Override in subclasses
        return .success(changes: [])
    }
}
