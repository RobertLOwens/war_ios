// ============================================================================
// FILE: GameSceneDelegate.swift
// LOCATION: Grow2 Shared/Protocols/GameSceneDelegate.swift
// PURPOSE: Protocol for GameScene -> ViewController communication
//          Replaces scattered callback closures with a unified delegate pattern
// ============================================================================

import Foundation
import SpriteKit

// MARK: - Game Scene Delegate Protocol

protocol GameSceneDelegate: AnyObject {
    
    // MARK: - Tile Interactions
    
    func gameScene(_ scene: GameScene, villagerArrivedForHunt villagerGroup: VillagerGroup, target: ResourcePointNode, entityNode: EntityNode)
    
    /// Called when a tile is selected and menu should be shown
    func gameScene(_ scene: GameScene, didRequestMenuForTile coordinate: HexCoordinate)

    /// Called when an unexplored tile is selected (shows simplified menu with move/scout option)
    func gameScene(_ scene: GameScene, didRequestUnexploredTileMenu coordinate: HexCoordinate)

    /// Called when entities at a location should be shown for move selection
    func gameScene(_ scene: GameScene, didRequestMoveSelection destination: HexCoordinate, availableEntities: [EntityNode])
    
    // MARK: - Entity Interactions

    /// Called when a villager group needs to show its action menu
    func gameScene(_ scene: GameScene, didSelectVillagerGroup entity: EntityNode, at coordinate: HexCoordinate)

    /// Called when an army entity is tapped to show army detail screen
    func gameScene(_ scene: GameScene, didSelectArmy entity: EntityNode, at coordinate: HexCoordinate)
    
    /// Called when a building menu should be shown for construction
    func gameScene(_ scene: GameScene, didRequestBuildMenu coordinate: HexCoordinate, builder: EntityNode)
    
    // MARK: - Combat (Instant)

    /// Called when combat timer UI should be displayed (legacy instant combat)
    func gameScene(_ scene: GameScene, didStartCombat record: CombatRecord, completion: @escaping () -> Void)

    // MARK: - Combat (Phased)

    /// Called when a new phased combat begins between two armies
    func gameScene(_ scene: GameScene, didStartPhasedCombat combat: ActiveCombat)

    /// Called each tick when combat state updates (for UI refresh)
    func gameScene(_ scene: GameScene, didUpdatePhasedCombat combat: ActiveCombat)

    /// Called when a phased combat ends
    func gameScene(_ scene: GameScene, didEndPhasedCombat combat: ActiveCombat, result: CombatResult)
    
    // MARK: - Alerts & Notifications

    /// Called when an alert should be shown to the user
    func gameScene(_ scene: GameScene, showAlertWithTitle title: String, message: String)

    /// Called when a confirmation dialog should be shown to the user
    func gameScene(_ scene: GameScene, showConfirmation title: String, message: String,
                   confirmTitle: String, onConfirm: @escaping () -> Void)
    
    // MARK: - Resource Updates

    /// Called when resource display should be refreshed
    func gameSceneDidUpdateResources(_ scene: GameScene)

    // MARK: - Rotation Preview Mode

    /// Called when rotation preview mode is entered for a multi-tile building
    func gameScene(_ scene: GameScene, didEnterRotationPreviewForBuilding buildingType: BuildingType, at anchor: HexCoordinate)

    /// Called when rotation preview mode is exited
    func gameSceneDidExitRotationPreview(_ scene: GameScene)

    // MARK: - Battle Notifications

    /// Called when a battle ends and a notification should be shown to the player
    func showBattleEndNotification(title: String, message: String, isVictory: Bool)
}

// MARK: - Optional Methods Extension

extension GameSceneDelegate {
    // Default implementations for optional methods

    func gameScene(_ scene: GameScene, didRequestUnexploredTileMenu coordinate: HexCoordinate) {
        // Default: no-op
    }

    func gameScene(_ scene: GameScene, didSelectEntity entity: EntityNode, at coordinate: HexCoordinate) {
        // Default: no-op
    }

    func gameScene(_ scene: GameScene, didSelectArmy entity: EntityNode, at coordinate: HexCoordinate) {
        // Default: no-op
    }

    func gameScene(_ scene: GameScene, didStartCombat record: CombatRecord, completion: @escaping () -> Void) {
        // Default: immediately complete
        completion()
    }

    func gameScene(_ scene: GameScene, didStartPhasedCombat combat: ActiveCombat) {
        // Default: no-op
    }

    func gameScene(_ scene: GameScene, didUpdatePhasedCombat combat: ActiveCombat) {
        // Default: no-op
    }

    func gameScene(_ scene: GameScene, didEndPhasedCombat combat: ActiveCombat, result: CombatResult) {
        // Default: no-op
    }

    func gameScene(_ scene: GameScene, didEnterRotationPreviewForBuilding buildingType: BuildingType, at anchor: HexCoordinate) {
        // Default: no-op
    }

    func gameSceneDidExitRotationPreview(_ scene: GameScene) {
        // Default: no-op
    }

    func showBattleEndNotification(title: String, message: String, isVictory: Bool) {
        // Default: no-op
    }

    func gameScene(_ scene: GameScene, showConfirmation title: String, message: String,
                   confirmTitle: String, onConfirm: @escaping () -> Void) {
        // Default: auto-confirm (for testing/headless scenarios)
        onConfirm()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let updateFogOfWar = Notification.Name("UpdateFogOfWar")
    static let resourcesDidChange = Notification.Name("ResourcesDidChange")
    static let entityDidMove = Notification.Name("EntityDidMove")
    static let buildingDidComplete = Notification.Name("BuildingDidComplete")
    static let trainingDidComplete = Notification.Name("TrainingDidComplete")
    static let phasedCombatStarted = Notification.Name("PhasedCombatStarted")
    static let phasedCombatUpdated = Notification.Name("PhasedCombatUpdated")
    static let phasedCombatEnded = Notification.Name("PhasedCombatEnded")
}
