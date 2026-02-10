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
    weak var localPlayer: Player?
    var allPlayers: [Player] = []
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

    // MARK: - Cleanup

    /// Clear all node references to prevent stale access during scene rebuild
    func cleanup() {
        buildingNodes.removeAll()
        entityNodes.removeAll()
        resourceNodes.removeAll()
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
            // Show HP bar for all buildings (always-visible HP bars)
            building.setupHealthBar()
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

    // MARK: - Player Lookup

    private func findPlayer(by ownerID: UUID) -> Player? {
        return allPlayers.first { $0.id == ownerID }
    }

    // MARK: - State Change Processing

    /// Apply a batch of state changes to the visual layer
    func applyChanges(_ batch: StateChangeBatch) {
        dispatchPrecondition(condition: .onQueue(.main))
        for change in batch.changes {
            self.applyChangeInternal(change)
        }
        self.delegate?.visualLayerDidCompleteStateUpdate(self)
    }

    /// Apply a single state change
    func applyChange(_ change: StateChange) {
        dispatchPrecondition(condition: .onQueue(.main))
        applyChangeInternal(change)
    }

    /// Internal implementation of state change application (must be called on main thread)
    private func applyChangeInternal(_ change: StateChange) {
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

        case .villagerGroupTaskChanged(let groupID, let task, _):
            handleVillagerGroupTaskChanged(groupID: groupID, task: task)

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

        // MARK: Entrenchment
        case .armyEntrenchmentStarted(let armyID, _):
            entityNodes[armyID]?.setupEntrenchmentBar()

        case .armyEntrenchmentProgress(let armyID, let progress):
            entityNodes[armyID]?.updateEntrenchmentBar(progress: progress)

        case .armyEntrenched(let armyID, _):
            entityNodes[armyID]?.removeEntrenchmentBar()

        case .armyEntrenchmentCancelled(let armyID, _):
            entityNodes[armyID]?.removeEntrenchmentBar()
            entityNodes[armyID]?.removeEntrenchmentBadge()

        // MARK: Stack Combat
        case .stackCombatStarted(let coordinate, _, _):
            handleCombatStarted(attackerID: UUID(), defenderID: UUID(), coordinate: coordinate)

        case .stackCombatPairingEnded:
            break  // Individual pairings handled by normal combatEnded

        case .stackCombatTierAdvanced:
            break  // Visual tier advancement handled via individual combat changes

        case .stackCombatEnded:
            break  // Overall cleanup handled by individual combat endings

        case .armyAutoRetreating(let armyID, let path):
            handleArmyAutoRetreating(armyID: armyID, path: path)

        case .armyForcedRetreat(let armyID, _, let to):
            if let entityNode = entityNodes[armyID] {
                entityNode.removeEntrenchmentBar()
                entityNode.removeEntrenchmentBadge()
            }
            handleArmyMoved(armyID: armyID, to: to)

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

        // Link ownership so diplomacy colors and player tracking work
        if let ownerPlayer = findPlayer(by: ownerID) {
            ownerPlayer.addBuilding(buildingNode)
        }

        // Show HP bar if building is damaged (e.g., loaded from save)
        buildingNode.showHealthBarIfDamaged()

        delegate?.visualLayer(self, didCreateNode: buildingNode, forChange: .buildingPlaced(buildingID: buildingID, buildingType: buildingType, coordinate: coordinate, ownerID: ownerID, rotation: rotation))
    }

    private func handleBuildingConstructionStarted(buildingID: UUID) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.updateAppearance()
        buildingNode.setupConstructionBar()
    }

    private func handleBuildingConstructionProgress(buildingID: UUID, progress: Double) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.data.constructionProgress = progress
        buildingNode.updateAppearance()
        buildingNode.updateConstructionBar(progress: progress)
    }

    private func handleBuildingCompleted(buildingID: UUID) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.data.state = .completed
        buildingNode.updateAppearance()
        buildingNode.removeConstructionBar()
        buildingNode.setupHealthBar()

        // Release builder entity (visual layer counterpart of engine's releaseBuilders)
        if let builder = buildingNode.builderEntity {
            let buildingType = buildingNode.data.buildingType

            if buildingType == .farm || buildingType == .miningCamp || buildingType == .lumberCamp {
                // Farm/camp villagers start gathering — post completion notification
                debugLog("✅ \(buildingType.displayName) completed - villagers will start gathering")
            } else {
                builder.isMoving = false
                if let villagerGroup = builder.entity as? VillagerGroup {
                    villagerGroup.clearTask()
                    debugLog("✅ Villagers unlocked and available for new tasks")
                }
            }

            // Post farm completion notification for auto-gathering
            if buildingType == .farm {
                var userInfo: [String: Any] = ["coordinate": buildingNode.data.coordinate]
                userInfo["builder"] = builder
                NotificationCenter.default.post(
                    name: NSNotification.Name("FarmCompletedNotification"),
                    object: buildingNode,
                    userInfo: userInfo
                )
            }

            // Post camp completion notification for auto-gathering
            if buildingType == .miningCamp || buildingType == .lumberCamp {
                var userInfo: [String: Any] = ["coordinate": buildingNode.data.coordinate, "campType": buildingType]
                userInfo["builder"] = builder
                NotificationCenter.default.post(
                    name: NSNotification.Name("CampCompletedNotification"),
                    object: buildingNode,
                    userInfo: userInfo
                )
            }
        }
    }

    private func handleBuildingUpgradeStarted(buildingID: UUID, toLevel: Int) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.updateAppearance()
        buildingNode.setupUpgradeBar()
    }

    private func handleBuildingUpgradeProgress(buildingID: UUID, progress: Double) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.data.upgradeProgress = progress
        buildingNode.updateAppearance()
        buildingNode.updateUpgradeBar(progress: progress)
    }

    private func handleBuildingUpgradeCompleted(buildingID: UUID, newLevel: Int) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.completeUpgrade()
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
        buildingNode.run(fadeOut) { [weak self, weak buildingNode] in
            guard let buildingNode = buildingNode else { return }
            buildingNode.removeFromParent()
            hexMap.removeBuilding(buildingNode)
            self?.buildingNodes.removeValue(forKey: buildingID)
        }
    }

    private func handleBuildingDamaged(buildingID: UUID, currentHealth: Double, maxHealth: Double) {
        guard let buildingNode = buildingNodes[buildingID] else { return }
        buildingNode.updateAppearance()

        // Ensure HP bar is set up (will be a no-op if already exists)
        buildingNode.setupHealthBar()
        buildingNode.updateHealthBar()

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

        // Remove from owner's tracking arrays
        if let owner = buildingNode.owner {
            owner.removeBuilding(buildingNode)
        }

        // Remove health bar before destruction
        buildingNode.removeHealthBar()

        // Remove tile overlays (text labels, hex outlines for multi-tile buildings)
        buildingNode.clearTileOverlays()

        // Destruction animation
        let explode = SKAction.group([
            SKAction.scale(to: 1.5, duration: 0.2),
            SKAction.fadeOut(withDuration: 0.2)
        ])

        buildingNode.run(explode) { [weak self, weak buildingNode] in
            guard let buildingNode = buildingNode else { return }
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

        // Link ownership so diplomacy colors and player tracking work
        if let ownerPlayer = findPlayer(by: ownerID) {
            if let army = entityNode.armyReference {
                ownerPlayer.addArmy(army)
                ownerPlayer.addEntity(army)
            }
        }

        entityNode.updateTexture(currentPlayer: localPlayer)

        // Spawn animation
        entityNode.alpha = 0
        entityNode.setScale(0.5)
        let spawnAction = SKAction.group([
            SKAction.fadeIn(withDuration: animationDuration),
            SKAction.scale(to: 1.0, duration: animationDuration)
        ])
        entityNode.run(spawnAction)

        // Update stack badges at spawn coordinate
        updateStackBadges(at: coordinate)
    }

    private func handleArmyMoved(armyID: UUID, to: HexCoordinate) {
        guard let entityNode = entityNodes[armyID] else { return }

        // Skip tile-by-tile re-animation if entity is already doing smooth retreat
        if entityNode.isMoving {
            entityNode.coordinate = to
            return
        }

        let oldCoord = entityNode.coordinate
        let targetPosition = HexMap.hexToPixel(q: to.q, r: to.r)
        let moveAction = SKAction.move(to: targetPosition, duration: animationDuration)
        moveAction.timingMode = .easeInEaseOut

        entityNode.run(moveAction) { [weak self] in
            self?.updateStackBadges(at: to)
        }
        entityNode.coordinate = to

        // Update badges at old coordinate (one fewer entity there now)
        updateStackBadges(at: oldCoord)
    }

    private func handleArmyAutoRetreating(armyID: UUID, path: [HexCoordinate]) {
        guard let entityNode = entityNodes[armyID] else { return }

        let oldCoord = entityNode.coordinate

        // Clear the data-layer path so MovementEngine doesn't also process it
        // (The visual layer will handle the smooth animation instead)
        if let armyData = gameState?.getArmy(id: armyID) {
            armyData.currentPath = nil
            armyData.pathIndex = 0
            armyData.movementProgress = 0.0
        }

        // Update badges at departure coordinate immediately
        updateStackBadges(at: oldCoord)

        // Use the smooth visual-layer retreat animation
        entityNode.moveTo(path: path) { [weak self] in
            debugLog("🏠 Auto-retreat animation completed for army \(armyID)")
            if let dest = path.last {
                self?.updateStackBadges(at: dest)
            }
        }
    }

    private func handleArmyCompositionChanged(armyID: UUID) {
        guard let entityNode = entityNodes[armyID] else { return }
        entityNode.updateTexture(currentPlayer: localPlayer)
    }

    private func handleArmyDestroyed(armyID: UUID) {
        guard let entityNode = entityNodes[armyID],
              let hexMap = hexMap else { return }

        let coord = entityNode.coordinate

        // Remove from owner's tracking arrays
        if let army = entityNode.armyReference, let owner = army.owner {
            owner.removeArmy(army)
            owner.removeEntity(army)
        }

        // Death animation
        let deathAction = SKAction.group([
            SKAction.fadeOut(withDuration: animationDuration),
            SKAction.scale(to: 0.5, duration: animationDuration)
        ])

        entityNode.run(deathAction) { [weak self] in
            entityNode.removeFromParent()
            hexMap.removeEntity(entityNode)
            self?.entityNodes.removeValue(forKey: armyID)
            self?.updateStackBadges(at: coord)
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

        // Link ownership so diplomacy colors and player tracking work
        if let ownerPlayer = findPlayer(by: ownerID) {
            if let villagers = entityNode.villagerReference {
                ownerPlayer.addEntity(villagers)
            }
        }

        entityNode.updateTexture(currentPlayer: localPlayer)

        // Spawn animation
        entityNode.alpha = 0
        let spawnAction = SKAction.fadeIn(withDuration: animationDuration)
        entityNode.run(spawnAction)

        // Update stack badges at spawn coordinate
        updateStackBadges(at: coordinate)
    }

    private func handleVillagerGroupMoved(groupID: UUID, to: HexCoordinate) {
        guard let entityNode = entityNodes[groupID] else { return }

        let oldCoord = entityNode.coordinate
        let targetPosition = HexMap.hexToPixel(q: to.q, r: to.r)
        let moveAction = SKAction.move(to: targetPosition, duration: animationDuration)
        moveAction.timingMode = .easeInEaseOut

        entityNode.run(moveAction) { [weak self] in
            self?.updateStackBadges(at: to)
        }
        entityNode.coordinate = to

        // Update badges at old coordinate
        updateStackBadges(at: oldCoord)
    }

    private func handleVillagerGroupCountChanged(groupID: UUID) {
        guard let entityNode = entityNodes[groupID] else { return }
        entityNode.updateTexture(currentPlayer: localPlayer)
    }

    private func handleVillagerGroupDestroyed(groupID: UUID) {
        guard let entityNode = entityNodes[groupID],
              let hexMap = hexMap else { return }

        let coord = entityNode.coordinate

        // Remove from owner's tracking arrays
        if let villagers = entityNode.villagerReference, let owner = villagers.owner {
            owner.removeEntity(villagers)
        }

        let deathAction = SKAction.fadeOut(withDuration: animationDuration)

        entityNode.run(deathAction) { [weak self] in
            entityNode.removeFromParent()
            hexMap.removeEntity(entityNode)
            self?.entityNodes.removeValue(forKey: groupID)
            self?.updateStackBadges(at: coord)
        }
    }

    private func handleVillagerGroupTaskChanged(groupID: UUID, task: String) {
        guard let entityNode = entityNodes[groupID],
              let villagerGroup = entityNode.entity as? VillagerGroup else { return }

        if task == "idle" {
            villagerGroup.clearTask()
        }
        // Could handle other task types here if needed in future
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
        // Debug logging for building combat HP bar
        debugLog("🎯 Combat started - defenderID: \(defenderID)")
        debugLog("🎯 buildingNodes count: \(buildingNodes.count)")
        debugLog("🎯 buildingNodes keys: \(buildingNodes.keys.map { $0.uuidString.prefix(8) })")

        entityNodes[attackerID]?.updateTexture(currentPlayer: localPlayer)

        // Check if defender is an army or a building
        if let defenderEntity = entityNodes[defenderID] {
            // Army vs Army combat
            defenderEntity.updateTexture(currentPlayer: localPlayer)
            debugLog("✅ Found defender entity (army)")
        } else if let defenderBuilding = buildingNodes[defenderID] ?? hexMap?.buildings.first(where: { $0.data.id == defenderID }) {
            // Army vs Building combat - set up health bar on building
            // Register if found via hexMap fallback (e.g., arena buildings)
            if buildingNodes[defenderID] == nil {
                buildingNodes[defenderID] = defenderBuilding
                debugLog("📝 Registered building from hexMap fallback: \(defenderBuilding.buildingType.displayName)")
            }
            defenderBuilding.setupHealthBar()
            debugLog("✅ Found building: \(defenderBuilding.buildingType.displayName)")
            debugLog("🏰 Building health bar set up for \(defenderBuilding.buildingType.displayName)")
        } else {
            debugLog("❌ Defender not found in entityNodes or buildingNodes for ID: \(defenderID)")
        }
    }

    private func handleCombatEnded(attackerID: UUID, defenderID: UUID) {
        entityNodes[attackerID]?.updateTexture(currentPlayer: localPlayer)

        // Check if defender was an army or a building
        if let defenderEntity = entityNodes[defenderID] {
            // Army vs Army combat
            defenderEntity.updateTexture(currentPlayer: localPlayer)
        } else if let defenderBuilding = buildingNodes[defenderID] {
            // Army vs Building combat - remove health bar
            defenderBuilding.removeHealthBar()
            debugLog("🏰 Building health bar removed for \(defenderBuilding.buildingType.displayName)")
        }
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

    // MARK: - Stack Badge Updates

    /// Updates stack badges for all entities at the given coordinate
    /// Only the front entity (last in array) shows the badge; others hide it
    private func updateStackBadges(at coordinate: HexCoordinate) {
        guard let hexMap = hexMap else { return }
        let entitiesAtCoord = hexMap.getEntities(at: coordinate)
        let count = entitiesAtCoord.count
        for (index, entity) in entitiesAtCoord.enumerated() {
            if index == entitiesAtCoord.count - 1 {
                entity.updateStackBadge(count: count)
            } else {
                entity.updateStackBadge(count: 0)
            }
        }
    }

    // MARK: - Node Access

    /// Register a building node created outside the visual layer (e.g. by BuildCommand)
    func registerBuildingNode(id: UUID, node: BuildingNode) {
        guard buildingNodes[id] == nil else { return }
        buildingNodes[id] = node
        if node.data.state != .constructing && node.data.state != .planning {
            node.setupHealthBar()
        }
    }

    /// Register an entity node created outside the visual layer (e.g. by DeployCommand)
    func registerEntityNode(id: UUID, node: EntityNode) {
        guard entityNodes[id] == nil else { return }
        entityNodes[id] = node
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
