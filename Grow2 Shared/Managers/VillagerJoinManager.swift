// ============================================================================
// FILE: VillagerJoinManager.swift
// PURPOSE: Manages marching villager nodes that are traveling to join
//          existing villager groups
// ============================================================================

import SpriteKit

/// Protocol for villager join events
protocol VillagerJoinManagerDelegate: AnyObject {
    func villagerJoinManager(_ manager: VillagerJoinManager, showAlert title: String, message: String)
}

/// Manages marching villager nodes moving from buildings to villager groups
class VillagerJoinManager {

    // MARK: - Properties

    weak var delegate: VillagerJoinManagerDelegate?
    weak var hexMap: HexMap?
    weak var player: Player?

    private(set) var marchingNodes: [MarchingVillagerNode] = []
    private weak var marchingVillagersNode: SKNode?

    // MARK: - Initialization

    init(hexMap: HexMap?, player: Player?, marchingVillagersNode: SKNode?) {
        self.hexMap = hexMap
        self.player = player
        self.marchingVillagersNode = marchingVillagersNode
    }

    // MARK: - Update References

    func updateReferences(hexMap: HexMap?, player: Player?, marchingVillagersNode: SKNode?) {
        self.hexMap = hexMap
        self.player = player
        self.marchingVillagersNode = marchingVillagersNode
    }

    // MARK: - Spawning

    /// Spawns a marching villager node and starts its movement to the target group
    func spawnMarchingVillagerNode(
        marchingGroup: MarchingVillagerGroup,
        path: [HexCoordinate],
        completion: @escaping (Bool) -> Void
    ) {
        guard let hexMap = hexMap else {
            completion(false)
            return
        }

        let node = MarchingVillagerNode(marchingGroup: marchingGroup, currentPlayer: player)
        let startPos = HexMap.hexToPixel(q: marchingGroup.coordinate.q, r: marchingGroup.coordinate.r)
        node.position = startPos

        marchingNodes.append(node)
        marchingVillagersNode?.addChild(node)

        // Set up interception check callback
        node.onTileEntered = { [weak self, weak node] coord in
            guard let self = self, let node = node else { return true }
            return self.checkMarchingVillagerInterception(node, at: coord)
        }

        // Start movement
        node.moveTo(path: path, hexMap: hexMap) { [weak self] in
            self?.handleMarchingVillagerArrival(node, success: true)
            completion(true)
        }

        debugLog("Spawned marching villagers with \(marchingGroup.villagerCount) villagers heading to join group")
    }

    // MARK: - Arrival Handling

    /// Handles marching villager arrival at the target villager group
    func handleMarchingVillagerArrival(_ node: MarchingVillagerNode, success: Bool) {
        let marchingGroup = node.marchingGroup

        if success, let targetGroup = marchingGroup.targetVillagerGroup {
            // Add villagers to target group
            targetGroup.addVillagers(count: marchingGroup.villagerCount)

            // If the target group is gathering resources, update resource collection
            if case .gatheringResource(let resourcePoint) = targetGroup.currentTask {
                // Update the resource point's data layer with new villager count
                _ = resourcePoint.data.assignVillagerGroup(
                    targetGroup.data.id,
                    villagerCount: targetGroup.villagerCount
                )
                resourcePoint.updateLabel()

                // Update collection rates for the player (use engine for accurate rates with adjacency)
                if let owner = targetGroup.owner {
                    // Recalculate collection rates to include adjacency bonuses
                    GameEngine.shared.resourceEngine.updateCollectionRates(forPlayer: owner.id)
                }

                debugLog("📈 Updated resource collection: +\(marchingGroup.villagerCount) villagers gathering \(resourcePoint.resourceType.displayName)")
            }

            // Notify UI
            delegate?.villagerJoinManager(
                self,
                showAlert: "Villagers Arrived",
                message: "\(marchingGroup.villagerCount) villagers joined \(targetGroup.name)"
            )

            debugLog("Villagers arrived: \(marchingGroup.villagerCount) joined \(targetGroup.name), now has \(targetGroup.villagerCount)")
        } else if success {
            // Target group was destroyed while marching - return to source
            debugLog("Target villager group no longer exists - returning villagers to source")
            returnMarchingVillagersToSource(node)
            return
        }

        // Cleanup node
        node.cleanup()
        marchingNodes.removeAll { $0 === node }
    }

    // MARK: - Return and Cancel

    /// Handles marching villagers return to source building (when cancelled or target destroyed)
    func returnMarchingVillagersToSource(_ node: MarchingVillagerNode) {
        let marchingGroup = node.marchingGroup

        // Try to find building by ID if weak reference is nil
        var building = marchingGroup.sourceBuilding
        if building == nil, let hexMap = hexMap {
            building = hexMap.buildings.first { $0.data.id == marchingGroup.sourceBuildingID }
        }

        // If hexMap is nil, return villagers directly without pathing
        guard let hexMap = hexMap else {
            // Direct return if no path possible
            if let building = building {
                building.addVillagersToGarrison(quantity: marchingGroup.villagerCount)
                debugLog("Villagers returned directly to \(building.buildingType.displayName) garrison (no hexMap)")

                delegate?.villagerJoinManager(
                    self,
                    showAlert: "Villagers Returned",
                    message: "\(marchingGroup.villagerCount) villagers returned to \(building.buildingType.displayName)"
                )
            } else {
                debugLog("Warning: Could not return villagers - no building found for ID \(marchingGroup.sourceBuildingID)")
            }
            node.cleanup()
            marchingNodes.removeAll { $0 === node }
            return
        }

        // Find path back to source
        guard let path = hexMap.findPath(from: marchingGroup.coordinate, to: marchingGroup.sourceCoordinate) else {
            debugLog("No path back to source for marching villagers")
            // Just add villagers back to building garrison directly
            if let building = building {
                building.addVillagersToGarrison(quantity: marchingGroup.villagerCount)
                debugLog("Villagers returned directly to \(building.buildingType.displayName) garrison")

                delegate?.villagerJoinManager(
                    self,
                    showAlert: "Villagers Returned",
                    message: "\(marchingGroup.villagerCount) villagers returned to \(building.buildingType.displayName)"
                )
            } else {
                debugLog("Warning: Could not return villagers - no building found for ID \(marchingGroup.sourceBuildingID)")
            }
            node.cleanup()
            marchingNodes.removeAll { $0 === node }
            return
        }

        marchingGroup.isCancelled = true

        // Move back to source
        node.moveTo(path: path, hexMap: hexMap) { [weak self] in
            // Try to find building again in case reference changed
            var targetBuilding = marchingGroup.sourceBuilding
            if targetBuilding == nil {
                targetBuilding = self?.hexMap?.buildings.first { $0.data.id == marchingGroup.sourceBuildingID }
            }

            // Add villagers back to building garrison
            if let building = targetBuilding {
                building.addVillagersToGarrison(quantity: marchingGroup.villagerCount)
                debugLog("Villagers returned to \(building.buildingType.displayName)")

                self?.delegate?.villagerJoinManager(
                    self!,
                    showAlert: "Villagers Returned",
                    message: "\(marchingGroup.villagerCount) villagers returned to \(building.buildingType.displayName)"
                )
            } else {
                debugLog("Warning: Could not return villagers on arrival - no building found for ID \(marchingGroup.sourceBuildingID)")
            }

            node.cleanup()
            self?.marchingNodes.removeAll { $0 === node }
        }
    }

    /// Gets the marching villager node for a given ID
    func getMarchingVillagerNode(id: UUID) -> MarchingVillagerNode? {
        return marchingNodes.first { $0.marchingGroup.id == id }
    }

    /// Cancels marching villagers and returns them to source
    func cancelMarchingVillagers(id: UUID) {
        guard let node = getMarchingVillagerNode(id: id) else {
            debugLog("Marching villager group not found: \(id)")
            return
        }

        // Stop current movement
        node.removeAllActions()
        node.isMoving = false

        // Return to source
        returnMarchingVillagersToSource(node)
    }

    // MARK: - Target Group Events

    /// Handles when a villager group is destroyed while marching villagers are en route
    func handleVillagerGroupDestroyed(_ group: VillagerGroup) {
        // Find all marching villagers targeting this group
        let targetingNodes = marchingNodes.filter { $0.marchingGroup.targetVillagerGroupID == group.id }

        for node in targetingNodes {
            debugLog("Target villager group destroyed - returning marching villagers to source")
            returnMarchingVillagersToSource(node)
        }
    }

    // MARK: - Interception

    /// Checks if marching villagers are intercepted by enemy army at this coordinate
    /// Returns true to continue movement, false to stop (combat/interception occurred)
    func checkMarchingVillagerInterception(_ node: MarchingVillagerNode, at coord: HexCoordinate) -> Bool {
        guard let hexMap = hexMap else { return true }
        let marchingGroup = node.marchingGroup

        // Check for enemy armies at this tile
        for entityNode in hexMap.entities {
            guard let army = entityNode.entity as? Army else { continue }

            // Skip if same owner
            guard army.owner?.id != marchingGroup.owner?.id else { continue }

            // Check if on same tile
            guard army.coordinate == coord else { continue }

            // Check diplomacy - only intercept if enemy
            let diplomacy = marchingGroup.owner?.getDiplomacyStatus(with: army.owner) ?? .neutral
            guard diplomacy == .enemy else { continue }

            // Interception triggered!
            debugLog("Marching villagers intercepted by \(army.name) at (\(coord.q), \(coord.r))!")

            // Stop villager movement
            node.removeAllActions()
            node.isMoving = false

            // Villagers are defenseless - they are killed by the army
            handleMarchingVillagerCombat(node, interceptingArmy: army)

            return false  // Stop movement
        }

        return true  // Continue movement
    }

    // MARK: - Combat

    /// Handles combat when marching villagers are intercepted
    /// Note: Villagers are defenseless and will be killed
    func handleMarchingVillagerCombat(_ node: MarchingVillagerNode, interceptingArmy: Army) {
        let marchingGroup = node.marchingGroup

        // Villagers are defenseless - they are killed
        debugLog("Marching villagers killed by intercepting army")
        delegate?.villagerJoinManager(
            self,
            showAlert: "Villagers Lost",
            message: "\(marchingGroup.villagerCount) villagers killed by enemy army"
        )

        // Cleanup
        node.cleanup()
        marchingNodes.removeAll { $0 === node }
    }

    // MARK: - Update

    /// Called each frame to update marching villager visibility
    func update(for player: Player) {
        for node in marchingNodes {
            node.updateVisibility(for: player)
        }
    }

    // MARK: - Cleanup

    /// Removes all marching villager nodes
    func cleanup() {
        for node in marchingNodes {
            node.cleanup()
        }
        marchingNodes.removeAll()
    }
}
