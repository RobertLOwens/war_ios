import SpriteKit

/// Protocol for reinforcement events
protocol ReinforcementManagerDelegate: AnyObject {
    func reinforcementManager(_ manager: ReinforcementManager, showAlert title: String, message: String)
}

/// Manages reinforcement nodes moving between buildings and armies
class ReinforcementManager {

    // MARK: - Properties

    weak var delegate: ReinforcementManagerDelegate?
    weak var hexMap: HexMap?
    weak var player: Player?

    private(set) var reinforcementNodes: [ReinforcementNode] = []
    private weak var reinforcementsNode: SKNode?

    // MARK: - Initialization

    init(hexMap: HexMap?, player: Player?, reinforcementsNode: SKNode?) {
        self.hexMap = hexMap
        self.player = player
        self.reinforcementsNode = reinforcementsNode
    }

    // MARK: - Update References

    func updateReferences(hexMap: HexMap?, player: Player?, reinforcementsNode: SKNode?) {
        self.hexMap = hexMap
        self.player = player
        self.reinforcementsNode = reinforcementsNode
    }

    // MARK: - Spawning

    /// Spawns a reinforcement node and starts its movement to the target army
    func spawnReinforcementNode(
        reinforcement: ReinforcementGroup,
        path: [HexCoordinate],
        completion: @escaping (Bool) -> Void
    ) {
        guard let hexMap = hexMap else {
            completion(false)
            return
        }

        let node = ReinforcementNode(reinforcement: reinforcement, currentPlayer: player)
        let startPos = HexMap.hexToPixel(q: reinforcement.coordinate.q, r: reinforcement.coordinate.r)
        node.position = startPos

        reinforcementNodes.append(node)
        reinforcementsNode?.addChild(node)

        // Set up path visualization
        if let container = reinforcementsNode {
            node.setupPathLine(parentContainer: container)
        }

        // Register pending reinforcement on the target army
        if let targetArmy = reinforcement.targetArmy {
            let travelTime = node.calculateTravelTime(path: path, hexMap: hexMap)
            let pendingReinforcement = PendingReinforcement(
                reinforcementID: reinforcement.id,
                units: reinforcement.unitComposition,
                estimatedArrival: Date().timeIntervalSince1970 + travelTime,
                source: reinforcement.sourceCoordinate
            )
            targetArmy.addPendingReinforcement(pendingReinforcement)
        }

        // Set up interception check callback
        node.onTileEntered = { [weak self, weak node] coord in
            guard let self = self, let node = node else { return true }
            return self.checkReinforcementInterception(node, at: coord)
        }

        // Start movement
        node.moveTo(path: path, hexMap: hexMap) { [weak self] in
            self?.handleReinforcementArrival(node, success: true)
            completion(true)
        }

        debugLog("Spawned reinforcement with \(reinforcement.getTotalUnits()) units")
    }

    // MARK: - Arrival Handling

    /// Handles reinforcement arrival at the target army
    func handleReinforcementArrival(_ node: ReinforcementNode, success: Bool) {
        let reinforcement = node.reinforcement

        if success, let targetArmy = reinforcement.targetArmy {
            // Add units to army
            targetArmy.receiveReinforcement(reinforcement.unitComposition)

            // Remove pending entry
            targetArmy.removePendingReinforcement(id: reinforcement.id)

            // Notify UI
            delegate?.reinforcementManager(self, showAlert: "Reinforcements Arrived", message: "\(reinforcement.getTotalUnits()) units joined \(targetArmy.name)")
        }

        // Cleanup node
        node.cleanup()
        reinforcementNodes.removeAll { $0 === node }
    }

    // MARK: - Return and Cancel

    /// Handles reinforcement return to source building (when cancelled or army destroyed)
    func returnReinforcementToSource(_ node: ReinforcementNode) {
        guard let hexMap = hexMap else { return }
        let reinforcement = node.reinforcement

        // Find path back to source
        guard let path = hexMap.findPath(from: reinforcement.coordinate, to: reinforcement.sourceCoordinate) else {
            debugLog("No path back to source for reinforcement")
            // Just add units back to building garrison directly
            if let building = reinforcement.sourceBuilding {
                for (unitType, count) in reinforcement.unitComposition {
                    building.addToGarrison(unitType: unitType, quantity: count)
                }
            }
            node.cleanup()
            reinforcementNodes.removeAll { $0 === node }
            return
        }

        reinforcement.isCancelled = true

        // Remove from army's pending list
        if let targetArmy = reinforcement.targetArmy {
            targetArmy.removePendingReinforcement(id: reinforcement.id)
        }

        // Move back to source (moveTo handles path visualization)
        node.moveTo(path: path, hexMap: hexMap) { [weak self] in
            // Add units back to building garrison
            if let building = reinforcement.sourceBuilding {
                for (unitType, count) in reinforcement.unitComposition {
                    building.addToGarrison(unitType: unitType, quantity: count)
                }
                debugLog("Reinforcements returned to \(building.buildingType.displayName)")
            }

            node.cleanup()
            self?.reinforcementNodes.removeAll { $0 === node }
        }
    }

    /// Gets the reinforcement node for a given reinforcement ID
    func getReinforcementNode(id: UUID) -> ReinforcementNode? {
        return reinforcementNodes.first { $0.reinforcement.id == id }
    }

    /// Cancels a reinforcement and returns it to source
    func cancelReinforcement(id: UUID) {
        guard let node = getReinforcementNode(id: id) else {
            debugLog("Reinforcement not found: \(id)")
            return
        }

        // Stop current movement
        node.removeAllActions()
        node.isMoving = false

        // Return to source
        returnReinforcementToSource(node)
    }

    // MARK: - Army Events

    /// Handles when an army is destroyed while reinforcements are en route
    func handleArmyDestroyed(_ army: Army) {
        // Find all reinforcements targeting this army
        let targetingNodes = reinforcementNodes.filter { $0.reinforcement.targetArmyID == army.id }

        for node in targetingNodes {
            debugLog("Army destroyed - returning reinforcement to source")
            returnReinforcementToSource(node)
        }
    }

    // MARK: - Interception

    /// Checks if reinforcements are intercepted by enemy army at this coordinate
    /// Returns true to continue movement, false to stop (combat/interception occurred)
    func checkReinforcementInterception(_ node: ReinforcementNode, at coord: HexCoordinate) -> Bool {
        guard let hexMap = hexMap else { return true }
        let reinforcement = node.reinforcement

        // Check for enemy armies at this tile
        for entityNode in hexMap.entities {
            guard let army = entityNode.entity as? Army else { continue }

            // Skip if same owner
            guard army.owner?.id != reinforcement.owner?.id else { continue }

            // Check if on same tile
            guard army.coordinate == coord else { continue }

            // Check diplomacy - only intercept if enemy
            let diplomacy = reinforcement.owner?.getDiplomacyStatus(with: army.owner) ?? .neutral
            guard diplomacy == .enemy else { continue }

            // Interception triggered!
            debugLog("Reinforcements intercepted by \(army.name) at (\(coord.q), \(coord.r))!")

            // Stop reinforcement movement
            node.removeAllActions()
            node.isMoving = false

            // Combat at reduced effectiveness (no commander bonus)
            handleReinforcementCombat(node, interceptingArmy: army)

            return false  // Stop movement
        }

        return true  // Continue movement
    }

    // MARK: - Combat

    /// Handles combat when reinforcements are intercepted
    func handleReinforcementCombat(_ node: ReinforcementNode, interceptingArmy: Army) {
        guard let hexMap = hexMap else { return }
        let reinforcement = node.reinforcement

        // Calculate reinforcement combat strength using combatStats (no commander bonus)
        var reinforcementStrength = 0.0
        for (unitType, count) in reinforcement.unitComposition {
            let stats = unitType.combatStats
            let unitDamage = stats.meleeDamage + stats.pierceDamage + stats.bludgeonDamage
            reinforcementStrength += unitDamage * Double(count)
        }

        // Get army strength (with commander bonus if present)
        let armyStrength = interceptingArmy.getModifiedStrength()

        // Simple combat resolution - side with higher strength wins
        // Reinforcements fight at 75% effectiveness due to no commander
        let effectiveReinforcementStrength = reinforcementStrength * 0.75

        if effectiveReinforcementStrength > armyStrength {
            // Reinforcements win but take losses
            let lossRatio = armyStrength / effectiveReinforcementStrength
            applyReinforcementLosses(reinforcement, lossRatio: lossRatio)

            // Army is destroyed
            debugLog("Reinforcements defeated intercepting army (took \(Int(lossRatio * 100))% losses)")
            delegate?.reinforcementManager(self, showAlert: "Interception Repelled", message: "Reinforcements defeated enemy but took losses")

            // Continue to destination (will need to restart movement)
            if let targetCoord = reinforcement.getTargetCoordinate(),
               let path = hexMap.findPath(from: reinforcement.coordinate, to: targetCoord) {
                node.moveTo(path: path, hexMap: hexMap) { [weak self] in
                    self?.handleReinforcementArrival(node, success: true)
                }
            }
        } else {
            // Army wins - reinforcements are destroyed
            debugLog("Reinforcements destroyed by intercepting army")
            delegate?.reinforcementManager(self, showAlert: "Reinforcements Lost", message: "\(reinforcement.getTotalUnits()) units lost to enemy interception")

            // Remove pending from target army
            if let targetArmy = reinforcement.targetArmy {
                targetArmy.removePendingReinforcement(id: reinforcement.id)
            }

            // Cleanup
            node.cleanup()
            reinforcementNodes.removeAll { $0 === node }

            // Apply some losses to the intercepting army
            let armyLossRatio = effectiveReinforcementStrength / armyStrength * 0.5
            // Note: Would need to implement army loss application
        }
    }

    /// Applies losses to reinforcement group based on combat
    private func applyReinforcementLosses(_ reinforcement: ReinforcementGroup, lossRatio: Double) {
        var newComposition: [MilitaryUnitType: Int] = [:]
        for (unitType, count) in reinforcement.unitComposition {
            let survivingCount = Int(Double(count) * (1.0 - lossRatio))
            if survivingCount > 0 {
                newComposition[unitType] = survivingCount
            }
        }
        // Note: Would need to add a method to update reinforcement composition
        // For now, losses are tracked conceptually
    }
}
