// ============================================================================
// FILE: EntityActionHandler.swift
// LOCATION: Grow2 iOS/Handlers/EntityActionHandler.swift
// PURPOSE: Handles entity-specific actions and logic
//          Uses Command pattern for all game actions
// ============================================================================

import UIKit
import SpriteKit

// MARK: - Entity Action Handler Delegate

protocol EntityActionHandlerDelegate: AnyObject {
    var player: Player! { get }
    var gameScene: GameScene! { get }
    
    func updateResourceDisplay()
    func showSimpleAlert(title: String, message: String)
}

// MARK: - Entity Action Handler

class EntityActionHandler {
    
    // MARK: - Properties
    
    weak var viewController: UIViewController?
    weak var delegate: EntityActionHandlerDelegate?
    
    private var player: Player? { delegate?.player }
    private var gameScene: GameScene? { delegate?.gameScene }
    private var hexMap: HexMap? { gameScene?.hexMap }
    
    // MARK: - Initialization
    
    init(viewController: UIViewController, delegate: EntityActionHandlerDelegate) {
        self.viewController = viewController
        self.delegate = delegate
    }
    
    // =========================================================================
    // MARK: - Villager Actions (Using Commands)
    // =========================================================================
    
    /// Deploys villagers from a building's garrison to the map
    func deployVillagers(from building: BuildingNode, count: Int, at coordinate: HexCoordinate) {
        guard let player = player else { return }
        
        let command = DeployVillagersCommand(
            playerID: player.id,
            buildingID: building.data.id,
            count: count
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if result.succeeded {
            delegate?.showSimpleAlert(
                title: "✅ Villagers Deployed",
                message: "Deployed \(count) villagers at (\(coordinate.q), \(coordinate.r))"
            )
        } else if let reason = result.failureReason {
            delegate?.showSimpleAlert(title: "Deploy Failed", message: reason)
        }
    }
    
    /// Shows villager selection for gathering resources
    func showVillagerSelectionForGathering(resourcePoint: ResourcePointNode) {
        guard let player = player,
              let vc = viewController else { return }
        
        let availableVillagers = player.getVillagerGroups().filter {
            $0.currentTask == .idle && $0.coordinate.distance(to: resourcePoint.coordinate) <= 10
        }
        
        guard !availableVillagers.isEmpty else {
            delegate?.showSimpleAlert(
                title: "No Villagers",
                message: "No idle villagers available nearby to gather resources."
            )
            return
        }
        
        var actions: [AlertAction] = []
        
        for villagerGroup in availableVillagers {
            let distance = villagerGroup.coordinate.distance(to: resourcePoint.coordinate)
            let title = "👷 \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) - Distance: \(distance)"
            
            actions.append(AlertAction(title: title) { [weak self] in
                self?.executeGatherCommand(villagerGroup: villagerGroup, resourcePoint: resourcePoint)
            })
        }
        
        vc.showActionSheet(
            title: "👷 Select Villagers",
            message: "Choose villagers to gather \(resourcePoint.resourceType.displayName)",
            actions: actions
        )
    }
    
    /// Executes a GatherCommand
    private func executeGatherCommand(villagerGroup: VillagerGroup, resourcePoint: ResourcePointNode) {
        guard let player = player else { return }
        
        let command = GatherCommand(
            playerID: player.id,
            villagerGroupID: villagerGroup.id,
            resourceCoordinate: resourcePoint.coordinate
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if !result.succeeded, let reason = result.failureReason {
            delegate?.showSimpleAlert(title: "Cannot Gather", message: reason)
        }
        
        delegate?.updateResourceDisplay()
    }
    
    // =========================================================================
    // MARK: - Army Actions (Using Commands)
    // =========================================================================
    
    /// Reinforces an army with units from a building's garrison
    func reinforceArmy(_ army: Army, from building: BuildingNode, units: [MilitaryUnitType: Int]) {
        guard let player = player else { return }
        
        let command = ReinforceArmyCommand(
            playerID: player.id,
            buildingID: building.data.id,
            armyID: army.id,
            units: units
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if !result.succeeded, let reason = result.failureReason {
            delegate?.showSimpleAlert(title: "Reinforcement Failed", message: reason)
        }
    }
    
    // =========================================================================
    // MARK: - Commander Actions
    // =========================================================================
    
    /// Deploys a commander at the player's city center
    func deployCommanderAtCityCenter(commander: Commander) {
        guard let player = player,
              let hexMap = hexMap,
              let gameScene = gameScene else {
            debugLog("⚠️ Missing game references - commander not deployed")
            delegate?.showSimpleAlert(
                title: "Error",
                message: "Cannot deploy commander - missing game references"
            )
            return
        }
        
        // Find player's city center
        let cityCenters = player.buildings.filter {
            $0.buildingType == .cityCenter &&
            $0.state == .completed &&
            $0.owner?.id == player.id
        }
        
        guard let cityCenter = cityCenters.first else {
            debugLog("⚠️ No city center found - commander not deployed")
            delegate?.showSimpleAlert(
                title: "Error",
                message: "No City Center found. Build one first!"
            )
            return
        }
        
        // Spawn directly ON the city center coordinate
        let spawnCoord = cityCenter.coordinate
        
        // Check if there's already an entity on the city center
        if let existingEntity = hexMap.getEntity(at: spawnCoord) {
            debugLog("❌ City center occupied by entity: \(existingEntity.entityType)")
            delegate?.showSimpleAlert(
                title: "Error",
                message: "City Center is occupied. Move units away first."
            )
            return
        }
        
        // Create army for commander
        let army = Army(
            name: "\(commander.name)'s Army",
            coordinate: spawnCoord,
            commander: commander,
            owner: player
        )

        // Set the city center as the army's home base
        army.setHomeBase(cityCenter.data.id)

        // Create entity node
        let entityNode = EntityNode(
            coordinate: spawnCoord,
            entityType: .army,
            entity: army,
            currentPlayer: player
        )
        let position = HexMap.hexToPixel(q: spawnCoord.q, r: spawnCoord.r)
        entityNode.position = position
        
        // Add to game
        hexMap.addEntity(entityNode)
        gameScene.entitiesNode.addChild(entityNode)

        // Register in visual layer
        gameScene.visualLayer?.registerEntityNode(id: army.id, node: entityNode)

        player.addEntity(army)
        player.addArmy(army)
        
        // Link commander to army
        commander.assignToArmy(army)
        
        debugLog("✅ Deployed commander \(commander.name) with army at (\(spawnCoord.q), \(spawnCoord.r))")
    }
    
    // =========================================================================
    // MARK: - Combat Actions
    // =========================================================================
    
    /// Shows attacker selection for initiating combat
    func showAttackerSelection(target: EntityNode, at coordinate: HexCoordinate) {
        guard let player = player,
              let vc = viewController else { return }
        
        let playerArmies = player.getArmies().filter { $0.hasMilitaryUnits() }
        
        let targetName: String
        if let army = target.entity as? Army {
            targetName = army.name
        } else if let villagers = target.entity as? VillagerGroup {
            targetName = villagers.name
        } else {
            targetName = "Unknown"
        }
        
        guard !playerArmies.isEmpty else {
            delegate?.showSimpleAlert(
                title: "No Armies",
                message: "You don't have any armies with military units to attack."
            )
            return
        }
        
        var actions: [AlertAction] = []
        
        for army in playerArmies {
            let distance = army.coordinate.distance(to: coordinate)
            let unitCount = army.getTotalMilitaryUnits()
            let title = "🛡️ \(army.name) (\(unitCount) units) - Distance: \(distance)"
            
            actions.append(AlertAction(title: title) { [weak self] in
                self?.executeAttackCommand(attacker: army, targetCoordinate: coordinate, targetEntityID: target.entity.id)
            })
        }
        
        vc.showActionSheet(
            title: "⚔️ Select Attacking Army",
            message: "Choose which army to attack \(targetName)",
            actions: actions
        )
    }
    
    /// Executes an AttackCommand
    private func executeAttackCommand(attacker: Army, targetCoordinate: HexCoordinate, targetEntityID: UUID? = nil) {
        guard let player = player else { return }

        let command = AttackCommand(
            playerID: player.id,
            attackerEntityID: attacker.id,
            targetCoordinate: targetCoordinate,
            targetEntityID: targetEntityID
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if !result.succeeded, let reason = result.failureReason {
            delegate?.showSimpleAlert(title: "Cannot Attack", message: reason)
        }
    }
    
    // =========================================================================
    // MARK: - Training Actions (Using Commands)
    // =========================================================================
    
    /// Starts training units at a building
    func startTraining(at building: BuildingNode, unitType: TrainableUnitType, quantity: Int) {
        guard let player = player else { return }
        
        switch unitType {
        case .villager:
            let command = TrainVillagerCommand(
                playerID: player.id,
                buildingID: building.data.id,
                quantity: quantity
            )
            
            let result = CommandExecutor.shared.execute(command)
            
            if result.succeeded {
                delegate?.showSimpleAlert(
                    title: "✅ Training Started",
                    message: "Training \(quantity) Villager\(quantity > 1 ? "s" : "")"
                )
            } else if let reason = result.failureReason {
                delegate?.showSimpleAlert(title: "Cannot Train", message: reason)
            }
            
        case .military(let militaryType):
            let command = TrainMilitaryCommand(
                playerID: player.id,
                buildingID: building.data.id,
                unitType: militaryType,
                quantity: quantity
            )
            
            let result = CommandExecutor.shared.execute(command)
            
            if result.succeeded {
                delegate?.showSimpleAlert(
                    title: "✅ Training Started",
                    message: "Training \(quantity) \(militaryType.displayName)\(quantity > 1 ? "s" : "")"
                )
            } else if let reason = result.failureReason {
                delegate?.showSimpleAlert(title: "Cannot Train", message: reason)
            }
        }
        
        delegate?.updateResourceDisplay()
    }
}
