// ============================================================================
// FILE: EntityActionHandler.swift
// LOCATION: Grow2 iOS/Handlers/EntityActionHandler.swift
// PURPOSE: Handles entity-specific actions and logic
//          Extracted from GameViewController to improve separation of concerns
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
    
    // MARK: - Villager Actions
    
    /// Deploys villagers from a building's garrison to the map
    func deployVillagers(from building: BuildingNode, count: Int, at coordinate: HexCoordinate) {
        guard let player = player,
              let gameScene = gameScene,
              let hexMap = hexMap else { return }
        
        // Remove villagers from garrison
        let removed = building.removeVillagersFromGarrison(quantity: count)
        
        guard removed > 0 else {
            delegate?.showSimpleAlert(title: "Deploy Failed", message: "Could not remove villagers from garrison.")
            return
        }
        
        // Create villager group
        let villagerGroup = VillagerGroup(
            name: "Villagers",
            coordinate: coordinate,
            villagerCount: removed,
            owner: player
        )
        
        // Create entity node
        let entityNode = EntityNode(
            coordinate: coordinate,
            entityType: .villagerGroup,
            entity: villagerGroup,
            currentPlayer: player
        )
        let position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        entityNode.position = position
        
        // Add to game
        hexMap.addEntity(entityNode)
        gameScene.entitiesNode.addChild(entityNode)
        player.addEntity(villagerGroup)
        
        print("✅ Deployed \(removed) villagers from \(building.buildingType.displayName) at (\(coordinate.q), \(coordinate.r))")
        
        delegate?.showSimpleAlert(
            title: "✅ Villagers Deployed",
            message: "Deployed \(removed) villagers at (\(coordinate.q), \(coordinate.r))"
        )
    }
    
    /// Shows villager selection for gathering resources
    func showVillagerSelectionForGathering(resourcePoint: ResourcePointNode) {
        guard let player = player,
              let vc = viewController else { return }
        
        let availableVillagers = player.getVillagerGroups().filter {
            $0.coordinate.distance(to: resourcePoint.coordinate) <= 10
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
                self?.assignVillagersToGather(villagerGroup, resource: resourcePoint)
            })
        }
        
        vc.showActionSheet(
            title: "👷 Select Villagers",
            message: "Choose villagers to gather \(resourcePoint.resourceType.displayName)",
            actions: actions
        )
    }
    
    /// Assigns villagers to gather from a resource point
    func assignVillagersToGather(_ villagerGroup: VillagerGroup, resource: ResourcePointNode) {
        guard let hexMap = hexMap else { return }
        
        // Find the entity node for this villager group
        guard let entityNode = hexMap.entities.first(where: {
            ($0.entity as? VillagerGroup)?.id == villagerGroup.id
        }) else {
            delegate?.showSimpleAlert(title: "Error", message: "Could not find villager group on map.")
            return
        }
        
        // Set task and move to resource
        villagerGroup.setTask(.gatheringResource(resource))
        resource.isBeingGathered = true
        resource.assignedVillagerGroup = villagerGroup
        
        // Move villagers to resource location
        gameScene?.moveEntity(entityNode, to: resource.coordinate)
        
        print("✅ Assigned \(villagerGroup.name) to gather \(resource.resourceType.displayName)")
    }
    
    // MARK: - Army Actions
    
    /// Reinforces an army with units from a building's garrison
    func reinforceArmy(_ army: Army, from building: BuildingNode, units: [MilitaryUnitType: Int]) {
        var totalTransferred = 0
        
        for (unitType, count) in units where count > 0 {
            let actualRemoved = building.removeFromGarrison(unitType: unitType, quantity: count)
            army.addMilitaryUnits(unitType, count: actualRemoved)
            totalTransferred += actualRemoved
        }
        
        if totalTransferred > 0 {
            delegate?.showSimpleAlert(
                title: "✅ Reinforcement Complete",
                message: "Transferred \(totalTransferred) units to \(army.name)"
            )
            print("✅ Reinforced \(army.name) with \(totalTransferred) units from \(building.buildingType.displayName)")
        }
    }
    
    /// Handles hunting an animal resource point with an army
    func huntWithArmy(_ army: Army, target: ResourcePointNode) {
        guard let player = player,
              let hexMap = hexMap else { return }
        
        // Calculate combat
        let armyAttack = army.getModifiedAttack()
        let animalDefense = target.resourceType.defense
        
        let netDamage = max(1, armyAttack - animalDefense)
        let isDead = target.takeDamage(netDamage)
        
        if isDead {
            // Animal killed - award food
            let foodGained = target.remainingAmount
            player.addResource(.food, amount: foodGained)
            delegate?.updateResourceDisplay()
            
            // Remove resource point
            hexMap.removeResourcePoint(target)
            target.removeFromParent()
            
            delegate?.showSimpleAlert(
                title: "🎉 Hunt Successful",
                message: "\(army.name) hunted the \(target.resourceType.displayName)\nGained: 🌾 \(foodGained) Food"
            )
            
            print("✅ Army hunted \(target.resourceType.displayName) - gained \(foodGained) food")
        } else {
            delegate?.showSimpleAlert(
                title: "⚔️ Combat",
                message: "The \(target.resourceType.displayName) took \(netDamage) damage\nRemaining health: \(target.currentHealth)/\(target.resourceType.health)"
            )
        }
    }
    
    // MARK: - Commander Actions
    
    /// Deploys a commander at the player's city center
    func deployCommanderAtCityCenter(commander: Commander) {
        guard let player = player,
              let hexMap = hexMap,
              let gameScene = gameScene else {
            print("⚠️ Missing game references - commander not deployed")
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
            print("⚠️ No city center found - commander not deployed")
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
            print("❌ City center occupied by entity: \(existingEntity.entityType)")
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
        player.addEntity(army)
        player.addArmy(army)
        
        // Link commander to army
        commander.assignToArmy(army)
        
        print("✅ Deployed commander \(commander.name) with army at (\(spawnCoord.q), \(spawnCoord.r))")
    }
    
    // MARK: - Combat Actions
    
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
                self?.initiateAttack(attacker: army, target: target, at: coordinate)
            })
        }
        
        vc.showActionSheet(
            title: "⚔️ Select Attacking Army",
            message: "Choose which army to attack \(targetName)",
            actions: actions
        )
    }
    
    /// Initiates an attack from an army to a target
    func initiateAttack(attacker: Army, target: EntityNode, at coordinate: HexCoordinate) {
        guard let gameScene = gameScene else { return }
        
        // Find attacker entity node
        guard let attackerNode = hexMap?.entities.first(where: {
            ($0.entity as? Army)?.id == attacker.id
        }) else {
            print("❌ Attacker node not found")
            return
        }
        
        // Find adjacent tile to move to
        guard let adjacentTile = hexMap?.findNearestWalkable(to: coordinate, maxDistance: 1) else {
            delegate?.showSimpleAlert(title: "Cannot Attack", message: "Cannot reach target location.")
            return
        }
        
        print("⚔️ \(attacker.name) moving to attack at (\(coordinate.q), \(coordinate.r))")
        
        // Move to attack position
        gameScene.moveEntity(attackerNode, to: adjacentTile)
        
        // Start combat after movement
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.gameScene?.startCombat(attacker: attacker, target: target.entity, location: coordinate)
        }
    }
    
    // MARK: - Training Actions
    
    /// Starts training units at a building
    func startTraining(at building: BuildingNode, unitType: TrainableUnitType, quantity: Int) {
        guard let player = player else { return }
        
        // Verify resources
        var canAfford = true
        var missingResources: [String] = []
        
        for (resourceType, unitCost) in unitType.trainingCost {
            let totalCost = unitCost * quantity
            if !player.hasResource(resourceType, amount: totalCost) {
                canAfford = false
                let available = player.getResource(resourceType)
                missingResources.append("\(resourceType.icon) \(resourceType.displayName): need \(totalCost), have \(available)")
            }
        }
        
        guard canAfford else {
            let message = "Insufficient resources:\n" + missingResources.joined(separator: "\n")
            delegate?.showSimpleAlert(title: "Cannot Afford", message: message)
            return
        }
        
        // Deduct resources
        for (resourceType, unitCost) in unitType.trainingCost {
            let totalCost = unitCost * quantity
            player.removeResource(resourceType, amount: totalCost)
        }
        
        // Start training
        let currentTime = Date().timeIntervalSince1970
        
        switch unitType {
        case .villager:
            building.startVillagerTraining(quantity: quantity, at: currentTime)
            print("✅ Started training \(quantity) villagers")
            
        case .military(let militaryType):
            building.startTraining(unitType: militaryType, quantity: quantity, at: currentTime)
            print("✅ Started training \(quantity) \(militaryType.displayName)")
        }
        
        delegate?.updateResourceDisplay()
        
        delegate?.showSimpleAlert(
            title: "✅ Training Started",
            message: "Training \(quantity) \(unitType.displayName)\(quantity > 1 ? "s" : "")"
        )
    }
}

// MARK: - Trainable Unit Type

/// Unified enum for both villagers and military units
enum TrainableUnitType {
    case villager
    case military(MilitaryUnitType)
    
    var displayName: String {
        switch self {
        case .villager:
            return "Villager"
        case .military(let type):
            return type.displayName
        }
    }
    
    var icon: String {
        switch self {
        case .villager:
            return "👷"
        case .military(let type):
            return type.icon
        }
    }
    
    var trainingCost: [ResourceType: Int] {
        switch self {
        case .villager:
            return [.food: 50]
        case .military(let type):
            return type.trainingCost
        }
    }
    
    var trainingTime: TimeInterval {
        switch self {
        case .villager:
            return 15.0
        case .military(let type):
            return type.trainingTime
        }
    }
}
