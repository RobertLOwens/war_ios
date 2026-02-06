// ============================================================================
// FILE: Grow2 Shared/GameSceneEngineIntegration.swift
// PURPOSE: Integrates GameEngine and GameVisualLayer with GameScene
// ============================================================================

import Foundation
import SpriteKit

// MARK: - Game Scene Engine Integration

extension GameScene: GameEngineDelegate, GameVisualLayerDelegate {

    // MARK: - Engine Properties

    /// The visual layer for state change rendering
    var visualLayer: GameVisualLayer? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.visualLayer) as? GameVisualLayer
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.visualLayer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Whether the engine-based architecture is enabled (defaults to true)
    var isEngineEnabled: Bool {
        get {
            return (objc_getAssociatedObject(self, &AssociatedKeys.isEngineEnabled) as? Bool) ?? true
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isEngineEnabled, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// The pure game state (when engine is enabled)
    var engineGameState: GameState? {
        return GameEngine.shared.getGameState()
    }

    // MARK: - Setup

    /// Initialize the engine-based architecture
    /// Call this after the scene is set up to enable the new architecture
    func initializeEngineArchitecture() {
        guard let player = player, let hexMap = hexMap else {
            debugLog("Cannot initialize engine - scene not ready")
            return
        }

        // Create the game state from existing visual state
        let gameState = GameStateSynchronizer.createGameState(
            from: hexMap,
            players: allGamePlayers,
            mapWidth: mapSize,
            mapHeight: mapSize
        )

        // Set local player
        gameState.localPlayerID = player.id

        // Initialize the game engine
        GameEngine.shared.setup(with: gameState)
        GameEngine.shared.delegate = self

        // Create and setup the visual layer
        let layer = GameVisualLayer()
        let sceneNodes = GameSceneNodes(
            mapNode: mapNode,
            buildingsNode: buildingsNode,
            entitiesNode: entitiesNode,
            resourcesNode: mapNode,  // Resources are in mapNode
            fogNode: mapNode  // Fog overlays are also in mapNode
        )
        layer.setup(gameState: gameState, hexMap: hexMap, sceneNodes: sceneNodes)
        layer.localPlayer = self.player
        layer.allPlayers = self.allGamePlayers
        layer.delegate = self
        self.visualLayer = layer

        // Enable the engine
        isEngineEnabled = true

        debugLog("Engine architecture initialized")
    }

    /// Disable the engine and revert to legacy mode
    func disableEngineArchitecture() {
        isEngineEnabled = false
        visualLayer = nil
        GameEngine.shared.reset()

        debugLog("Engine architecture disabled - using legacy mode")
    }

    // MARK: - Engine Update

    /// Call this in the update loop to tick the engine
    func updateEngine(currentTime: TimeInterval) {
        guard isEngineEnabled else { return }

        GameEngine.shared.update(currentTime: currentTime)
    }

    // MARK: - Command Execution

    /// Execute a command using the appropriate system
    func executeEngineCompatibleCommand<T: GameCommand>(_ command: T) -> CommandResult {
        if isEngineEnabled, let state = engineGameState {
            return CommandBridge.execute(command, context: nil, gameState: state)
        } else {
            return CommandExecutor.shared.execute(command)
        }
    }

    /// Execute an engine command directly
    func executeEngineCommand(_ command: EngineCommand) -> EngineCommandResult {
        guard isEngineEnabled else {
            return .failure(reason: "Engine not enabled")
        }

        return GameEngine.shared.executeCommand(command)
    }

    // MARK: - GameEngineDelegate

    func gameEngine(_ engine: GameEngine, didProduceChanges changes: StateChangeBatch) {
        // Apply changes to the visual layer
        visualLayer?.applyChanges(changes)

        // Process changes for notifications
        NotificationManager.shared.processStateChanges(changes.changes)

        // Notify delegate of state changes
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gameDelegate?.gameSceneDidUpdateState(self)
        }
    }

    func gameEngine(_ engine: GameEngine, didCompleteCommand commandID: UUID, result: EngineCommandResult) {
        // Log command completion
        if result.succeeded {
            debugLog("Command \(commandID) completed with \(result.changes.count) changes")
        } else if let reason = result.failureReason {
            debugLog("Command \(commandID) failed: \(reason)")
        }
    }

    func gameEngineDidTick(_ engine: GameEngine, currentTime: TimeInterval) {
        // Update UI elements that depend on time
        gameDelegate?.gameSceneDidUpdateResources(self)
    }

    // MARK: - GameVisualLayerDelegate

    func visualLayerDidCompleteStateUpdate(_ layer: GameVisualLayer) {
        // Refresh UI after state update
        gameDelegate?.gameSceneDidUpdateState(self)
    }

    func visualLayer(_ layer: GameVisualLayer, didCreateNode node: SKNode, forChange change: StateChange) {
        // Optional: Handle node creation events
    }

    func visualLayer(_ layer: GameVisualLayer, didRemoveNode node: SKNode, forChange change: StateChange) {
        // Optional: Handle node removal events
    }

    // MARK: - State Synchronization

    /// Sync the visual state with the engine state
    /// Use this after loading a save or when states get out of sync
    func syncVisualStateWithEngine() {
        guard isEngineEnabled, let state = engineGameState, let hexMap = hexMap else { return }

        // Sync buildings
        for building in state.buildings.values {
            if let buildingNode = hexMap.buildings.first(where: { $0.data.id == building.id }) {
                // Sync building data
                buildingNode.data.state = building.state
                buildingNode.data.level = building.level
                buildingNode.data.health = building.health
                buildingNode.data.garrison = building.garrison
                buildingNode.data.villagerGarrison = building.villagerGarrison
                buildingNode.updateAppearance()
            }
        }

        // Sync armies
        for army in state.armies.values {
            if let entityNode = hexMap.entities.first(where: { $0.entity.id == army.id }) {
                entityNode.coordinate = army.coordinate
                entityNode.position = HexMap.hexToPixel(q: army.coordinate.q, r: army.coordinate.r)
                entityNode.updateTexture()
            }
        }

        // Sync villager groups
        for group in state.villagerGroups.values {
            if let entityNode = hexMap.entities.first(where: { $0.entity.id == group.id }) {
                entityNode.coordinate = group.coordinate
                entityNode.position = HexMap.hexToPixel(q: group.coordinate.q, r: group.coordinate.r)
                entityNode.updateTexture()
            }
        }

        // Update stack badges on all entity coordinates
        var entityCoordinates: Set<HexCoordinate> = []
        for entity in hexMap.entities {
            entityCoordinates.insert(entity.coordinate)
        }
        for coord in entityCoordinates {
            let entitiesAtCoord = hexMap.getEntities(at: coord)
            let count = entitiesAtCoord.count
            for entity in entitiesAtCoord {
                entity.updateStackBadge(count: count)
            }
        }

        // Sync player resources
        if let localPlayerID = state.localPlayerID,
           let playerState = state.getPlayer(id: localPlayerID),
           let player = self.player {
            PlayerStateAdapter.updatePlayer(player, from: playerState)
        }
    }

    /// Create a snapshot of the current game state for saving
    func createGameStateSnapshot() -> GameStateSnapshot? {
        guard isEngineEnabled, let state = engineGameState else { return nil }
        return GameStateSnapshot(from: state)
    }

    /// Restore game state from a snapshot
    func restoreFromSnapshot(_ snapshot: GameStateSnapshot) {
        let state = snapshot.restore()
        GameEngine.shared.setup(with: state)

        // Rebuild visual layer
        if let layer = visualLayer, let hexMap = hexMap {
            let sceneNodes = GameSceneNodes(
                mapNode: mapNode,
                buildingsNode: buildingsNode,
                entitiesNode: entitiesNode,
                resourcesNode: mapNode,
                fogNode: mapNode
            )
            layer.setup(gameState: state, hexMap: hexMap, sceneNodes: sceneNodes)
            layer.allPlayers = self.allGamePlayers
        }

        syncVisualStateWithEngine()
    }
}

// MARK: - Associated Keys

private struct AssociatedKeys {
    static var visualLayer = "visualLayer"
    static var isEngineEnabled = "isEngineEnabled"
}

// MARK: - GameSceneDelegate Extension

extension GameSceneDelegate {
    /// Called when the game state is updated
    func gameSceneDidUpdateState(_ gameScene: GameScene) {
        // Default empty implementation
    }
}
