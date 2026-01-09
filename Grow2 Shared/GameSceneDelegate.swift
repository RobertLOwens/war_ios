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
    
    /// Called when entities at a location should be shown for move selection
    func gameScene(_ scene: GameScene, didRequestMoveSelection destination: HexCoordinate, availableEntities: [EntityNode])
    
    // MARK: - Entity Interactions
    
    /// Called when a villager group needs to show its action menu
    func gameScene(_ scene: GameScene, didSelectVillagerGroup entity: EntityNode, at coordinate: HexCoordinate)
    
    /// Called when a building menu should be shown for construction
    func gameScene(_ scene: GameScene, didRequestBuildMenu coordinate: HexCoordinate, builder: EntityNode)
    
    // MARK: - Combat
    
    /// Called when combat timer UI should be displayed
    func gameScene(_ scene: GameScene, didStartCombat record: CombatRecord, completion: @escaping () -> Void)
    
    // MARK: - Alerts & Notifications
    
    /// Called when an alert should be shown to the user
    func gameScene(_ scene: GameScene, showAlertWithTitle title: String, message: String)
    
    // MARK: - Resource Updates
    
    /// Called when resource display should be refreshed
    func gameSceneDidUpdateResources(_ scene: GameScene)
}

// MARK: - Optional Methods Extension

extension GameSceneDelegate {
    // Default implementations for optional methods
    
    func gameScene(_ scene: GameScene, didSelectEntity entity: EntityNode, at coordinate: HexCoordinate) {
        // Default: no-op
    }
    
    func gameScene(_ scene: GameScene, didStartCombat record: CombatRecord, completion: @escaping () -> Void) {
        // Default: immediately complete
        completion()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let updateFogOfWar = Notification.Name("UpdateFogOfWar")
    static let resourcesDidChange = Notification.Name("ResourcesDidChange")
    static let entityDidMove = Notification.Name("EntityDidMove")
    static let buildingDidComplete = Notification.Name("BuildingDidComplete")
    static let trainingDidComplete = Notification.Name("TrainingDidComplete")
}
