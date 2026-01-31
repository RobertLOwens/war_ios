// ============================================================================
// FILE: Grow2 Shared/Visual/GameVisualLayer.swift
// PURPOSE: Applies state changes to SpriteKit visuals
// ============================================================================

import Foundation
import SpriteKit

// MARK: - Game Visual Layer Delegate

protocol GameVisualLayerDelegate: AnyObject {
    func visualLayerDidCompleteStateUpdate(_ layer: GameVisualLayer)
    func visualLayer(_ layer: GameVisualLayer, didCreateNode node: SKNode, forChange change: StateChange)
    func visualLayer(_ layer: GameVisualLayer, didRemoveNode node: SKNode, forChange change: StateChange)
}

// MARK: - Game Visual Layer

/// Responsible for synchronizing game state with SpriteKit visuals
/// Receives StateChanges from GameEngine and updates the visual representation
class GameVisualLayer {

    // MARK: - References
    weak var delegate: GameVisualLayerDelegate?
    weak var gameState: GameState?
    weak var hexMap: HexMap?
    private let nodeFactory: NodeFactory

    // MARK: - Scene References
    weak var mapNode: SKNode?
    weak var buildingsNode: SKNode?
    weak var entitiesNode: SKNode?
    weak var resourcesNode: SKNode?
    weak var fogNode: SKNode?

    // MARK: - Node Registries
    private var buildingNodes: [UUID: BuildingNode] = [:]
    private var entityNodes: [UUID: EntityNode] = [:]
    private var resourceNodes: [UUID: ResourcePointNode] = [:]

    // MARK: - Animation Settings
    var animationDuration: TimeInterval = 0.3

    // MARK: - Initialization

    init() {
        self.nodeFactory = NodeFactory()
    }

    // MARK: - Setup

    func setup(gameState: GameState, hexMap: HexMap, sceneNodes: GameSceneNodes) {
        self.gameState = gameState
        self.hexMap = hexMap
        self.mapNode = sceneNodes.mapNode
        self.buildingsNode = sceneNodes.buildingsNode
        self.entitiesNode = sceneNodes.entitiesNode
        self.resourcesNode = sceneNodes.resourcesNode
        self.fogNode = sceneNodes.fogNode

        nodeFactory.setup(hexMap: hexMap)

        // Build initial node registries from existing nodes
        syncNodeRegistries()
    }

    private func syncNodeRegistries() {
        guard let hexMap = hexMap else { return }

        // Sync building nodes
        for building in hexMap.buildings {
            buildingNodes[building.data.id] = building
        }

        // Sync entity nodes
        for entity in hexMap.entities {
            entityNodes[entity.entity.id] = entity
        }

        // Sync resource nodes
        for resource in hexMap.resourcePoints {
            // Resource nodes don't have UUIDs in current implementation
            // Would need to add IDs to ResourcePointNode for full sync
        }
    }

    // MARK: - State Change Processing

    /// Apply a batch of state changes to the visual layer
    func applyChanges(_ batch: StateChangeBatch) {
        for change in batch.changes {
            applyChange(change)
        }
        delegate?.visualLayerDidCompleteStateUpdate(self)
    }

    /// Apply a single state change
    func applyChange(_ change: StateChange) {
        switch change {
        // MARK: Building Changes
        case .buildingPlaced(let buildingID, let buildingType, let coordinate, let ownerID, let rotation):
            handleBuildingPlaced(buildingID: buildingID, buildingType: buildingType, coordinate: coordinate, ownerID: ownerID, rotation: rotation)

        case .buildingConstructionStarted(let buildingID):
            handleBuildingConstructionStarted(buildingID: buildingID)

        case .buildingConstructionProgress(let buildingID, let progress):
            handleBuildingConstructionProgress(buildingID: buildingID, progress: progress)

        case .buildingCompleted(let buildingID):
            handleBuildingCompleted(buildingID: buildingID)

        case .buildingUpgradeStarted(let buildingID, let toLevel):
            handleBuildingUpgradeStarted(buildingID: buildingID, toLevel: toLevel)

        case .buildingUpgradeProgress(let buildingID, let progress):
            handleBuildingUpgradeProgress(buildingID: buildingID, progress: progress)

        case .buildingUpgradeCompleted(let buildingID, let newLevel):
            handleBuildingUpgradeCompleted(buildingID: buildingID, newLevel: newLevel)

        case .buildingDemolitionStarted(let buildingID):
            handleBuildingDemolitionStarted(buildingID: buildingID)

        case .buildingDemolitionProgress(let buildingID, let progress):
            handleBuildingDemolitionProgress(buildingID: buildingID, progress: progress)

        case .buildingDemolished(let buildingID, _):
            handleBuildingDemolished(buildingID: buildingID)

        case .buildingDamaged(let buildingID, let currentHealth, let maxHealth):
            handleBuildingDamaged(buildingID: buildingID, currentHealth: currentHealth, maxHealth: maxHealth)

        case .buildingDestroyed(let buildingID, _):
            handleBuildingDestroyed(buildingID: buildingID)

        // MARK: Army Changes
        case .armyCreated(let armyID, let ownerID, let coordinate, let composition):
            handleArmyCreated(armyID: armyID, ownerID: ownerID, coordinate: coordinate, composition: composition)

        case .armyMoved(let armyID, _, let to, _):
            handleArmyMoved(armyID: armyID, to: to)

        case .armyCompositionChanged(let armyID, _):
            handleArmyCompositionChanged(armyID: armyID)

        case .armyDestroyed(let armyID, _):
            handleArmyDestroyed(armyID: armyID)

        // MARK: Villager Group Changes
        case .villagerGroupCreated(let groupID, let ownerID, let coordinate, let count):
            handleVillagerGroupCreated(groupID: groupID, ownerID: ownerID, coordinate: coordinate, count: count)

        case .villagerGroupMoved(let groupID, _, let to, _):
            handleVillagerGroupMoved(groupID: groupID, to: to)

        case .villagerGroupCountChanged(let groupID, _):
            handleVillagerGroupCountChanged(groupID: groupID)

        case .villagerGroupDestroyed(let groupID, _):
            handleVillagerGroupDestroyed(groupID: groupID)

        // MARK: Resource Changes
        case .resourcePointDepleted(let coordinate, _):
            handleResourcePointDepleted(at: coordinate)

        case .resourcePointAmountChanged(let coordinate, _, let newAmount):
            handleResourcePointAmountChanged(at: coordinate, newAmount: newAmount)

        case .resourcePointCreated(let coordinate, let resourceType, let amount):
            handleResourcePointCreated(at: coordinate, type: resourceType, amount: amount)

        // MARK: Fog of War
        case .fogOfWarUpdated(_, let coordinate, let visibility):
            handleFogOfWarUpdated(coordinate: coordinate, visibility: visibility)

        // MARK: Combat
        case .combatStarted(let attackerID, let defenderID, let coordinate):
            handleCombatStarted(attackerID: attackerID, defenderID: defenderID, coordinate: coordinate)

        case .combatEnded(let attackerID, let defenderID, _):
            handleCombatEnded(attackerID: attackerID, defenderID: defenderID)

        case .garrisonDefenseAttack(let buildingID, let targetArmyID, let damage):
            handleGarrisonDefenseAttack(buildingID: buildingID, targetArmyID: targetArmyID, damage: damage)

        default:
            // Handle other changes as needed
            break
        }
    }

    // MARK: - Building Handlers

    private func handleBuildingPlaced(buildingID: UUID, buildingType: String, coordinate: HexCoordinate, ownerID: UUID, rotation: Int) {
        guard let buildingsNode = buildingsNode,
              let hexMap = hexMap,
              let state = gameState,
              let buildingData = state.getBuilding(id: buildingID) else { return }

        // Check if node already exists
        if buildingNodes[buildingID] != nil { return }

        // Create building node
        let buildingNode = nodeFactory.createBuildingNode(from: buildingData)
        buildingNode.position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

        // Add to scene
        buildingsNode.addChild(buildingNode)
        hexMap.addBuilding(buildingNode)
        buildingNodes[buildingID] = buildingNode

        delegate?.visualLayer(self, didCreateNode: buildingNode, forChange: .buildingPlaced(buildingID: buildingID, buildingType: buildingType, coordinate: coordinate, ownerID: ownerID, rotation: rotation))
    }

    private func handleBuildingConstructionStarted(buildingID: UUID) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.updateAppearance()
    }

    private func handleBuildingConstructionProgress(buildingID: UUID, progress: Double) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.data.constructionProgress = progress
        buildingNode.updateAppearance()
    }

    private func handleBuildingCompleted(buildingID: UUID) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.data.state = .completed
        buildingNode.updateAppearance()
    }

    private func handleBuildingUpgradeStarted(buildingID: UUID, toLevel: Int) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.updateAppearance()
    }

    private func handleBuildingUpgradeProgress(buildingID: UUID, progress: Double) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.data.upgradeProgress = progress
        buildingNode.updateAppearance()
    }

    private func handleBuildingUpgradeCompleted(buildingID: UUID, newLevel: Int) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.data.level = newLevel
        buildingNode.data.state = .completed
        buildingNode.updateAppearance()
    }

    private func handleBuildingDemolitionStarted(buildingID: UUID) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.updateAppearance()
    }

    private func handleBuildingDemolitionProgress(buildingID: UUID, progress: Double) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.data.demolitionProgress = progress
        buildingNode.updateAppearance()
    }

    private func handleBuildingDemolished(buildingID: UUID) {
        guard let buildingNode = buildingNodes[buildingID],
              let hexMap = hexMap else { return }

        // Animate removal
        let fadeOut = SKAction.fadeOut(withDuration: animationDuration)
        buildingNode.run(fadeOut) { [weak self] in
            buildingNode.removeFromParent()
            hexMap.removeBuilding(buildingNode)
            self?.buildingNodes.removeValue(forKey: buildingID)
        }
    }

    private func handleBuildingDamaged(buildingID: UUID, currentHealth: Double, maxHealth: Double) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.updateAppearance()

        // Visual damage effect
        let flash = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.1),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
        ])
        buildingNode.run(flash)
    }

    private func handleBuildingDestroyed(buildingID: UUID) {
        guard let buildingNode = buildingNodes[buildingID],
              let hexMap = hexMap else { return }

        // Destruction animation
        let explode = SKAction.group([
            SKAction.scale(to: 1.5, duration: 0.2),
            SKAction.fadeOut(withDuration: 0.2)
        ])

        buildingNode.run(explode) { [weak self] in
            buildingNode.removeFromParent()
            hexMap.removeBuilding(buildingNode)
            self?.buildingNodes.removeValue(forKey: buildingID)
        }
    }

    // MARK: - Army Handlers

    private func handleArmyCreated(armyID: UUID, ownerID: UUID, coordinate: HexCoordinate, composition: [String: Int]) {
        guard let entitiesNode = entitiesNode,
              let hexMap = hexMap,
              let state = gameState,
              let armyData = state.getArmy(id: armyID) else { return }

        // Check if node already exists
        if entityNodes[armyID] != nil { return }

        // Create entity node
        let entityNode = nodeFactory.createEntityNode(from: armyData)
        entityNode.position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

        // Add to scene
        entitiesNode.addChild(entityNode)
        hexMap.addEntity(entityNode)
        entityNodes[armyID] = entityNode

        // Spawn animation
        entityNode.alpha = 0
        entityNode.setScale(0.5)
        let spawnAction = SKAction.group([
            SKAction.fadeIn(withDuration: animationDuration),
            SKAction.scale(to: 1.0, duration: animationDuration)
        ])
        entityNode.run(spawnAction)
    }

    private func handleArmyMoved(armyID: UUID, to: HexCoordinate) {
        guard let entityNode = entityNodes[armyID] else { return }

        let targetPosition = HexMap.hexToPixel(q: to.q, r: to.r)
        let moveAction = SKAction.move(to: targetPosition, duration: animationDuration)
        moveAction.timingMode = .easeInEaseOut

        entityNode.run(moveAction)
        entityNode.coordinate = to
    }

    private func handleArmyCompositionChanged(armyID: UUID) {
        guard let entityNode = entityNodes[armyID] else { return }
        entityNode.updateTexture()
    }

    private func handleArmyDestroyed(armyID: UUID) {
        guard let entityNode = entityNodes[armyID],
              let hexMap = hexMap else { return }

        // Death animation
        let deathAction = SKAction.group([
            SKAction.fadeOut(withDuration: animationDuration),
            SKAction.scale(to: 0.5, duration: animationDuration)
        ])

        entityNode.run(deathAction) { [weak self] in
            entityNode.removeFromParent()
            hexMap.removeEntity(entityNode)
            self?.entityNodes.removeValue(forKey: armyID)
        }
    }

    // MARK: - Villager Group Handlers

    private func handleVillagerGroupCreated(groupID: UUID, ownerID: UUID, coordinate: HexCoordinate, count: Int) {
        guard let entitiesNode = entitiesNode,
              let hexMap = hexMap,
              let state = gameState,
              let groupData = state.getVillagerGroup(id: groupID) else { return }

        // Check if node already exists
        if entityNodes[groupID] != nil { return }

        // Create entity node
        let entityNode = nodeFactory.createEntityNode(from: groupData)
        entityNode.position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

        // Add to scene
        entitiesNode.addChild(entityNode)
        hexMap.addEntity(entityNode)
        entityNodes[groupID] = entityNode

        // Spawn animation
        entityNode.alpha = 0
        let spawnAction = SKAction.fadeIn(withDuration: animationDuration)
        entityNode.run(spawnAction)
    }

    private func handleVillagerGroupMoved(groupID: UUID, to: HexCoordinate) {
        guard let entityNode = entityNodes[groupID] else { return }

        let targetPosition = HexMap.hexToPixel(q: to.q, r: to.r)
        let moveAction = SKAction.move(to: targetPosition, duration: animationDuration)
        moveAction.timingMode = .easeInEaseOut

        entityNode.run(moveAction)
        entityNode.coordinate = to
    }

    private func handleVillagerGroupCountChanged(groupID: UUID) {
        guard let entityNode = entityNodes[groupID] else { return }
        entityNode.updateTexture()
    }

    private func handleVillagerGroupDestroyed(groupID: UUID) {
        guard let entityNode = entityNodes[groupID],
              let hexMap = hexMap else { return }

        let deathAction = SKAction.fadeOut(withDuration: animationDuration)

        entityNode.run(deathAction) { [weak self] in
            entityNode.removeFromParent()
            hexMap.removeEntity(entityNode)
            self?.entityNodes.removeValue(forKey: groupID)
        }
    }

    // MARK: - Resource Handlers

    private func handleResourcePointDepleted(at coordinate: HexCoordinate) {
        guard let hexMap = hexMap,
              let resource = hexMap.getResourcePoint(at: coordinate) else { return }

        let fadeOut = SKAction.fadeOut(withDuration: animationDuration)
        resource.run(fadeOut) {
            resource.removeFromParent()
            hexMap.removeResourcePoint(resource)
        }
    }

    private func handleResourcePointAmountChanged(at coordinate: HexCoordinate, newAmount: Int) {
        guard let hexMap = hexMap,
              let resource = hexMap.getResourcePoint(at: coordinate) else { return }

        // Update the visual node's remaining amount
        resource.setRemainingAmount(newAmount)
        resource.updateLabel()
    }

    private func handleResourcePointCreated(at coordinate: HexCoordinate, type: String, amount: Int) {
        guard let resourcesNode = resourcesNode,
              let hexMap = hexMap else { return }

        guard let resourceType = ResourcePointType(rawValue: type) else { return }

        let resourceNode = ResourcePointNode(coordinate: coordinate, resourceType: resourceType)
        resourceNode.position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        resourceNode.setRemainingAmount(amount)

        resourcesNode.addChild(resourceNode)
        hexMap.addResourcePoint(resourceNode)

        // Spawn animation
        resourceNode.alpha = 0
        resourceNode.setScale(0.5)
        let spawnAction = SKAction.group([
            SKAction.fadeIn(withDuration: animationDuration),
            SKAction.scale(to: 1.0, duration: animationDuration)
        ])
        resourceNode.run(spawnAction)
    }

    // MARK: - Fog of War Handlers

    private func handleFogOfWarUpdated(coordinate: HexCoordinate, visibility: String) {
        guard let hexMap = hexMap else { return }

        if let fogOverlay = hexMap.fogOverlays[coordinate] {
            let level: VisibilityLevel
            switch visibility {
            case "visible": level = .visible
            case "explored": level = .explored
            default: level = .unexplored
            }
            fogOverlay.setVisibility(level)
        }
    }

    // MARK: - Combat Handlers

    private func handleCombatStarted(attackerID: UUID, defenderID: UUID, coordinate: HexCoordinate) {
        // Visual combat indicator could be added here
        // For now, we just ensure both entities are updated
        entityNodes[attackerID]?.updateTexture()
        entityNodes[defenderID]?.updateTexture()
    }

    private func handleCombatEnded(attackerID: UUID, defenderID: UUID) {
        entityNodes[attackerID]?.updateTexture()
        entityNodes[defenderID]?.updateTexture()
    }

    private func handleGarrisonDefenseAttack(buildingID: UUID, targetArmyID: UUID, damage: Double) {
        guard let buildingNode = buildingNodes[buildingID],
              let targetNode = entityNodes[targetArmyID] else { return }

        // Visual effect: line from building to target
        let startPos = buildingNode.position
        let endPos = targetNode.position

        // Create projectile effect
        let projectile = SKShapeNode(circleOfRadius: 3)
        projectile.fillColor = .yellow
        projectile.strokeColor = .orange
        projectile.position = startPos
        projectile.zPosition = 100

        buildingsNode?.parent?.addChild(projectile)

        let moveAction = SKAction.move(to: endPos, duration: 0.2)
        let removeAction = SKAction.removeFromParent()
        projectile.run(SKAction.sequence([moveAction, removeAction]))

        // Flash target
        let flash = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.1),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
        ])
        targetNode.run(flash)
    }

    // MARK: - Node Access

    func getBuildingNode(id: UUID) -> BuildingNode? {
        return buildingNodes[id]
    }

    func getEntityNode(id: UUID) -> EntityNode? {
        return entityNodes[id]
    }
}

// MARK: - Game Scene Nodes Container

struct GameSceneNodes {
    weak var mapNode: SKNode?
    weak var buildingsNode: SKNode?
    weak var entitiesNode: SKNode?
    weak var resourcesNode: SKNode?
    weak var fogNode: SKNode?
}
