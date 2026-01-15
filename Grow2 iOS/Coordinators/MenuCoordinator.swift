// ============================================================================
// FILE: MenuCoordinator.swift
// LOCATION: Grow2 iOS/Coordinators/MenuCoordinator.swift
// PURPOSE: Handles all menu and alert presentation logic
//          Uses Command pattern for all game actions
// ============================================================================

import UIKit
import SpriteKit

// MARK: - Menu Coordinator Delegate

protocol MenuCoordinatorDelegate: AnyObject {
    var player: Player! { get }
    var gameScene: GameScene! { get }
    
    func updateResourceDisplay()
    func deselectAll()
    
    func showSplitVillagerMenu(villagerGroup: VillagerGroup, entityNode: EntityNode)
    func showMergeMenu(group1: EntityNode, group2: EntityNode)
    func splitVillagerGroup(villagerGroup: VillagerGroup, entity: EntityNode, splitCount: Int)
}

// MARK: - Menu Coordinator

class MenuCoordinator {
    
    // MARK: - Properties
    
    weak var viewController: UIViewController?
    weak var delegate: MenuCoordinatorDelegate?
    
    private var player: Player? { delegate?.player }
    private var gameScene: GameScene? { delegate?.gameScene }
    private var hexMap: HexMap? { gameScene?.hexMap }
    
    // MARK: - Initialization
    
    init(viewController: UIViewController, delegate: MenuCoordinatorDelegate) {
        self.viewController = viewController
        self.delegate = delegate
    }
    
    // MARK: - Tile Menus
    
    func showTileActionMenu(for coordinate: HexCoordinate) {
        guard let player = player,
              let hexMap = hexMap,
              let vc = viewController else { return }
        
        let visibility = player.getVisibilityLevel(at: coordinate)
        var title = "Tile (\(coordinate.q), \(coordinate.r))"
        var message = ""
        var actions: [AlertAction] = []
        
        // -------------------------
        // MARK: - Building Info
        // -------------------------
        if let building = hexMap.getBuilding(at: coordinate) {
            if visibility == .visible || building.owner?.id == player.id {
                title = "\(building.buildingType.icon) \(building.buildingType.displayName)"
                message = building.buildingType.description
                message += "\nOwner: \(building.owner?.name ?? "Unknown")"
                message += "\nHealth: \(Int(building.health))/\(Int(building.maxHealth))"
                message += "\n⭐ Level: \(building.level)/\(building.maxLevel)"
                
                if building.state == .constructing {
                    let progress = Int(building.constructionProgress * 100)
                    message += "\n🔨 Construction: \(progress)%"
                    if let startTime = building.constructionStartTime {
                        let remaining = getRemainingTime(startTime: startTime, totalTime: building.buildingType.buildTime)
                        message += " (\(formatTime(remaining)))"
                    }
                }
                
                if building.state == .upgrading {
                    let progress = Int(building.upgradeProgress * 100)
                    message += "\n⬆️ Upgrading to Lv.\(building.level + 1): \(progress)%"
                    if let startTime = building.upgradeStartTime,
                       let upgradeTime = building.getUpgradeTime() {
                        let remaining = getRemainingTime(startTime: startTime, totalTime: upgradeTime)
                        message += " (\(formatTime(remaining)))"
                    }
                }
                
                // Open Building action (only for completed OR upgrading, player-owned buildings)
                if (building.state == .completed || building.state == .upgrading) && building.owner?.id == player.id {
                    let buildingName = building.buildingType.displayName
                    actions.append(AlertAction(title: "🏗️ Open \(buildingName)", style: .default) { [weak self] in
                        self?.presentBuildingDetail(for: building)
                    })
                }
            } else if visibility == .explored {
                message = "Explored - Last seen: Building here"
            }
        }
        
        // -------------------------
        // MARK: - Resource Info
        // -------------------------
        if let resourcePoint = hexMap.getResourcePoint(at: coordinate), visibility == .visible {
            if let building = hexMap.getBuilding(at: coordinate) {
                // Show combined building + resource info for camps
                title = "\(building.buildingType.icon) \(building.buildingType.displayName)"
                message = building.buildingType.description
                message += "\nOwner: \(building.owner?.name ?? "Unknown")"
                message += "\n\n\(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"
                message += "\nRemaining: \(resourcePoint.remainingAmount)"
                
                if resourcePoint.resourceType.isGatherable {
                    let gatherers = resourcePoint.getTotalVillagersGathering()
                    if gatherers > 0 {
                        message += "\n👷 \(gatherers) villager(s) gathering"
                    }
                    
                    if resourcePoint.getRemainingCapacity() > 0 {
                        actions.append(AlertAction(title: "👷 Assign Villagers to Gather") { [weak self] in
                            self?.showVillagerSelectionForGathering(resourcePoint: resourcePoint)
                        })
                    } else {
                        message += "\n\n⚠️ Max villagers reached"
                    }
                }
            } else {
                // Standalone resource
                title = "\(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"
                message = "Remaining: \(resourcePoint.remainingAmount)"
                
                if resourcePoint.resourceType.isHuntable {
                    message += "\nHealth: \(Int(resourcePoint.currentHealth))/\(Int(resourcePoint.resourceType.health))"
                    actions.append(AlertAction(title: "🏹 Hunt") { [weak self] in
                        self?.showVillagerSelectionForHunt(resourcePoint: resourcePoint)
                    })
                } else if resourcePoint.resourceType.isGatherable {
                    let gatherers = resourcePoint.getTotalVillagersGathering()
                    if gatherers > 0 {
                        message += "\n👷 \(gatherers) villager(s) gathering"
                    }
                    
                    // Check if camp is required
                    if resourcePoint.resourceType.requiresCamp {
                        if let camp = hexMap.getBuilding(at: coordinate),
                           (camp.buildingType == .miningCamp || camp.buildingType == .lumberCamp) {
                            if resourcePoint.getRemainingCapacity() > 0 {
                                actions.append(AlertAction(title: "👷 Assign Villagers to Gather") { [weak self] in
                                    self?.showVillagerSelectionForGathering(resourcePoint: resourcePoint)
                                })
                            }
                        } else {
                            let campName = resourcePoint.resourceType == .trees ? "Lumber Camp" : "Mining Camp"
                            message += "\n\n⚠️ Requires \(campName) nearby to gather"
                        }
                    } else {
                        // No camp required (forage, carcasses, farmland)
                        if resourcePoint.getRemainingCapacity() > 0 {
                            actions.append(AlertAction(title: "👷 Assign Villagers to Gather") { [weak self] in
                                self?.showVillagerSelectionForGathering(resourcePoint: resourcePoint)
                            })
                        } else {
                            message += "\n\n⚠️ Max villagers reached"
                        }
                    }
                }
            }
        }
        
        // -------------------------
        // MARK: - Entities on Tile
        // -------------------------
        let entitiesAtTile = hexMap.entities.filter { $0.coordinate == coordinate }
        
        let visibleEntities: [EntityNode]
        if visibility == .visible {
            visibleEntities = entitiesAtTile.filter { entity in
                if let fogOfWar = player.fogOfWar {
                    return fogOfWar.shouldShowEntity(entity.entity, at: coordinate)
                }
                return true
            }
        } else {
            visibleEntities = []
        }
        
        if !visibleEntities.isEmpty {
            if !message.isEmpty { message += "\n" }
            message += "\n📍 \(visibleEntities.count) unit(s) on this tile"
        }
        
        // Add action for each visible entity
        for entity in visibleEntities {
            var buttonTitle = ""
            
            if entity.entityType == .villagerGroup {
                if let villagers = entity.entity as? VillagerGroup {
                    buttonTitle = "👷 \(villagers.name) (\(villagers.villagerCount) villagers)"
                    
                    switch villagers.currentTask {
                    case .gatheringResource:
                        buttonTitle += " ⛏️"
                    case .hunting:
                        buttonTitle += " 🏹"
                    case .building:
                        buttonTitle += " 🔨"
                    case .idle:
                        buttonTitle += " 💤"
                    default:
                        break
                    }
                } else {
                    buttonTitle = "👷 Villager Group"
                }
                
            } else if entity.entityType == .army {
                if let army = entity.entity as? Army {
                    let totalUnits = army.getTotalMilitaryUnits()
                    buttonTitle = "🛡️ \(army.name) (\(totalUnits) units)"
                } else {
                    buttonTitle = "🛡️ Army"
                }
            }
            
            actions.append(AlertAction(title: buttonTitle) { [weak self] in
                if let villagers = entity.entity as? VillagerGroup {
                    switch villagers.currentTask {
                    case .gatheringResource, .hunting:
                        self?.showVillagerOptionsMenu(villagerGroup: villagers, entityNode: entity)
                    default:
                        self?.showVillagerMenu(at: coordinate, villagerGroup: entity)
                    }
                } else {
                    self?.showEntityActionMenu(for: entity, at: coordinate)
                }
            })
        }
        
        // -------------------------
        // MARK: - Movement Action
        // -------------------------
        if visibility == .visible || visibility == .explored {
            let hasHostileEntities = entitiesAtTile.contains { entity in
                let diplomacyStatus = player.getDiplomacyStatus(with: entity.entity.owner)
                return diplomacyStatus == .neutral || diplomacyStatus == .enemy
            }
            
            if !hasHostileEntities {
                actions.append(AlertAction(title: "🚶 Move Unit Here", style: .default) { [weak self] in
                    self?.gameScene?.initiateMove(to: coordinate)
                })
            } else {
                if !message.isEmpty { message += "\n" }
                message += "\n⚠️ Cannot move here - hostile units present"
            }
        }
        
        // -------------------------
        // MARK: - Show Menu
        // -------------------------
        vc.showActionSheet(
            title: title,
            message: message.isEmpty ? nil : message,
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    // MARK: - Entity Selection Menus
    
    func showEntityActionMenu(for entity: EntityNode, at coordinate: HexCoordinate) {
        guard let player = player,
              let vc = viewController else { return }
        
        if entity.entityType == .villagerGroup {
            showVillagerMenu(at: coordinate, villagerGroup: entity)
            return
        }
        
        var actions: [AlertAction] = []
        
        // Move action
        actions.append(AlertAction(title: "🚶 Move") { [weak self] in
            self?.gameScene?.selectEntity(entity)
            vc.showAlert(title: "Select Destination", message: "Tap a tile to move this entity.")
        })
        
        // Army-specific actions
        if entity.entityType == .army,
           let army = entity.entity as? Army,
           army.owner?.id == player.id {
            
            let buildingsWithGarrison = player.buildings.filter { $0.getTotalGarrisonedUnits() > 0 }
            if !buildingsWithGarrison.isEmpty {
                actions.append(AlertAction(title: "🔄 Reinforce Army") { [weak self] in
                    self?.showReinforcementSourceSelection(for: army)
                })
            }
        }
        
        actions.append(AlertAction(title: "← Back") { [weak self] in
            self?.showTileActionMenu(for: coordinate)
        })
        
        vc.showActionSheet(
            title: "Entity Actions",
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    // MARK: - Move Selection
    
    func showMoveSelectionMenu(to coordinate: HexCoordinate, from entities: [EntityNode]) {
        guard let player = player,
              let vc = viewController else { return }
        
        let playerEntities = entities.filter { entity in
            guard entity.entity.owner?.id == player.id else { return false }
            
            if let villagers = entity.entity as? VillagerGroup {
                return villagers.currentTask == .idle
            }
            
            return true
        }
        
        guard !playerEntities.isEmpty else {
            vc.showAlert(title: "No Units Available", message: "You don't have any units that can move.")
            return
        }
        
        var actions: [AlertAction] = []
        
        for entity in playerEntities {
            let distance = entity.coordinate.distance(to: coordinate)
            var title = "\(entity.entityType.icon) "
            
            if entity.entityType == .army, let army = entity.entity as? Army {
                let totalUnits = army.getTotalMilitaryUnits()
                title += "\(army.name) (\(totalUnits) units) - Distance: \(distance)"
            } else if entity.entityType == .villagerGroup, let villagers = entity.entity as? VillagerGroup {
                title += "\(villagers.name) (\(villagers.villagerCount) villagers) - Distance: \(distance)"
            }
            
            actions.append(AlertAction(title: title) { [weak self] in
                self?.executeMoveCommand(entity: entity, to: coordinate)
            })
        }
        
        vc.showActionSheet(
            title: "Select Entity to Move",
            message: "Choose which entity to move to (\(coordinate.q), \(coordinate.r))",
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    // MARK: - Villager Menu
    
    func showVillagerMenu(at coordinate: HexCoordinate, villagerGroup: EntityNode) {
        guard let villagers = villagerGroup.entity as? VillagerGroup,
              let hexMap = hexMap,
              let player = player,
              let vc = viewController else { return }
        
        var message = "👷 Villagers: \(villagers.villagerCount)\n"
        message += "📍 Status: \(villagers.currentTask.displayName)"
        
        var actions: [AlertAction] = []
        
        let isIdle = villagers.currentTask == .idle
        
        // -------------------------
        // NON-IDLE: Cancel Task Only
        // -------------------------
        if !isIdle {
            switch villagers.currentTask {
            case .gatheringResource(let resourcePoint):
                message += "\n\n⛏️ Gathering: \(resourcePoint.resourceType.displayName)"
                message += "\n📦 Remaining: \(resourcePoint.remainingAmount)"
                
                actions.append(AlertAction(title: "🛑 Cancel Gathering", style: .destructive) { [weak self] in
                    self?.executeStopGatheringCommand(villagerGroup: villagers)
                })
                
            case .hunting(let target):
                message += "\n\n🎯 Hunting: \(target.resourceType.displayName)"
                
                actions.append(AlertAction(title: "🛑 Cancel Hunt", style: .destructive) { [weak self] in
                    self?.cancelHunting(villagerGroup: villagers)
                })
                
            case .building(let building):
                message += "\n\n🏗️ Constructing: \(building.buildingType.displayName)"
                
                actions.append(AlertAction(title: "🛑 Cancel Building", style: .destructive) { [weak self] in
                    self?.cancelBuilding(villagerGroup: villagers, building: building)
                })
                
            case .upgrading(let building):
                message += "\n\n⬆️ Upgrading: \(building.buildingType.displayName)"
                
                actions.append(AlertAction(title: "🛑 Cancel Upgrade", style: .destructive) { [weak self] in
                    self?.executeCancelUpgradeCommand(building: building)
                })
                
            default:
                actions.append(AlertAction(title: "🛑 Cancel Task", style: .destructive) { [weak self] in
                    villagers.clearTask()
                    if let entityNode = hexMap.entities.first(where: {
                        ($0.entity as? VillagerGroup)?.id == villagers.id
                    }) {
                        entityNode.isMoving = false
                    }
                    self?.delegate?.deselectAll()
                })
            }
            
            message += "\n\n⚠️ Cancel task to move or assign new tasks."
        }
        
        // -------------------------
        // IDLE: Full Options
        // -------------------------
        if isIdle {
            // Move
            actions.append(AlertAction(title: "🚶 Move") { [weak self] in
                self?.gameScene?.initiateMove(to: coordinate)
            })
            
            // Build (only if no building on tile)
            let buildingExists = hexMap.getBuilding(at: coordinate) != nil
            if !buildingExists {
                actions.append(AlertAction(title: "🏗️ Build") { [weak self] in
                    self?.showBuildingMenu(at: coordinate, villagerGroup: villagerGroup)
                })
            }
            
            // Upgrade (if on a player-owned building)
            if let building = hexMap.getBuilding(at: coordinate),
               building.owner?.id == player.id,
               building.canUpgrade {
                actions.append(AlertAction(title: "⬆️ Upgrade \(building.buildingType.displayName)") { [weak self] in
                    self?.showUpgradeConfirmation(for: building, villagerEntity: villagerGroup)
                })
            }
            
            // Merge (only if another villager group on same tile)
            let otherVillagerGroups = hexMap.entities.filter {
                $0.coordinate == coordinate &&
                $0.entityType == .villagerGroup &&
                ($0.entity as? VillagerGroup)?.id != villagers.id &&
                $0.entity.owner?.id == player.id
            }
            
            if let otherGroup = otherVillagerGroups.first {
                if let otherVillagers = otherGroup.entity as? VillagerGroup {
                    actions.append(AlertAction(title: "🔀 Merge with \(otherVillagers.name) (\(otherVillagers.villagerCount))") { [weak self] in
                        self?.delegate?.showMergeMenu(group1: villagerGroup, group2: otherGroup)
                    })
                }
            }
            
            // Split (only if more than 1 villager)
            if villagers.villagerCount > 1 {
                actions.append(AlertAction(title: "✂️ Split Group") { [weak self] in
                    self?.delegate?.showSplitVillagerMenu(villagerGroup: villagers, entityNode: villagerGroup)
                })
            }
            
            // Gather (only if on a gatherable resource tile)
            if let resourcePoint = hexMap.getResourcePoint(at: coordinate) {
                if resourcePoint.resourceType.isGatherable && !resourcePoint.isDepleted() {
                    actions.append(AlertAction(title: "⛏️ Gather \(resourcePoint.resourceType.displayName)") { [weak self] in
                        self?.executeGatherCommand(villagerGroup: villagers, resourcePoint: resourcePoint)
                    })
                }
            }
        }
        
        vc.showActionSheet(
            title: "👷 \(villagers.name)",
            message: message,
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    func showVillagerOptionsMenu(villagerGroup: VillagerGroup, entityNode: EntityNode) {
        guard let vc = viewController else { return }
        
        var actions: [AlertAction] = []
        var message = "Villagers: \(villagerGroup.villagerCount)\n"
        message += "Status: \(villagerGroup.currentTask.displayName)"
        
        if case .gatheringResource(let resourcePoint) = villagerGroup.currentTask {
            message += "\n\nGathering: \(resourcePoint.resourceType.displayName)"
            message += "\nRemaining: \(resourcePoint.remainingAmount)"
            
            actions.append(AlertAction(title: "🛑 Cancel Gathering", style: .destructive) { [weak self] in
                self?.executeStopGatheringCommand(villagerGroup: villagerGroup)
            })
        }
        
        if case .hunting(let target) = villagerGroup.currentTask {
            message += "\n\nHunting: \(target.resourceType.displayName)"
            
            actions.append(AlertAction(title: "🛑 Cancel Hunt", style: .destructive) { [weak self] in
                self?.cancelHunting(villagerGroup: villagerGroup)
            })
        }
        
        vc.showActionSheet(
            title: "👷 \(villagerGroup.name)",
            message: message,
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    // MARK: - Building Menu
    
    func showBuildingMenu(at coordinate: HexCoordinate, villagerGroup: EntityNode?) {
        guard let player = player,
              let hexMap = hexMap,
              let vc = viewController else { return }
        
        let cityCenterLevel = player.getCityCenterLevel()
        var actions: [AlertAction] = []
        
        for type in BuildingType.allCases {
            if type == .cityCenter { continue }
            
            let requiredCCLevel = type.requiredCityCenterLevel
            let meetsRequirement = cityCenterLevel >= requiredCCLevel
            let canPlace = hexMap.canPlaceBuilding(at: coordinate, buildingType: type)
            
            var costString = ""
            for (resourceType, amount) in type.buildCost {
                costString += "\(resourceType.icon)\(amount) "
            }
            
            if !meetsRequirement {
                let title = "🔒 \(type.displayName) (CC Lv.\(requiredCCLevel) req.)"
                actions.append(AlertAction(title: title, handler: nil))
            } else if canPlace {
                let title = "\(type.icon) \(type.displayName) - \(costString)"
                actions.append(AlertAction(title: title) { [weak self] in
                    // Check if there's a resource that will be removed
                    if let resource = hexMap.getResourcePoint(at: coordinate) {
                        if type != .miningCamp && type != .lumberCamp {
                            self?.showBuildingConfirmationWithResourceWarning(
                                buildingType: type,
                                coordinate: coordinate,
                                resource: resource,
                                villagerGroup: villagerGroup
                            )
                            return
                        }
                    }
                    
                    // No resource warning needed - proceed with build command
                    self?.executeBuildCommand(buildingType: type, at: coordinate, builder: villagerGroup)
                })
            } else {
                var reason = ""
                if type == .miningCamp {
                    reason = " (Requires Ore/Stone)"
                } else if type == .lumberCamp {
                    reason = " (Requires Trees)"
                }
                actions.append(AlertAction(title: "❌ \(type.displayName)\(reason)", handler: nil))
            }
        }
        
        vc.showActionSheet(
            title: "🏗️ Select Building",
            message: "Choose a building to construct at (\(coordinate.q), \(coordinate.r))\n⭐ City Center: Lv.\(cityCenterLevel)",
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    func showBuildingConfirmationWithResourceWarning(
        buildingType: BuildingType,
        coordinate: HexCoordinate,
        resource: ResourcePointNode,
        villagerGroup: EntityNode?
    ) {
        guard let vc = viewController else { return }
        
        let alert = UIAlertController(
            title: "⚠️ Resource Will Be Removed",
            message: "Building \(buildingType.displayName) here will permanently remove the \(resource.resourceType.displayName) (\(resource.remainingAmount) remaining).\n\nAre you sure you want to continue?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Build Anyway", style: .destructive) { [weak self] _ in
            self?.executeBuildCommand(buildingType: buildingType, at: coordinate, builder: villagerGroup)
        })
        
        vc.present(alert, animated: true)
    }
    
    // MARK: - Upgrade Menu
    
    func showUpgradeConfirmation(for building: BuildingNode, villagerEntity: EntityNode) {
        guard let vc = viewController,
              let player = player else { return }
        
        guard building.canUpgrade else {
            vc.showAlert(title: "Max Level", message: "\(building.buildingType.displayName) is already at maximum level (\(building.level)).")
            return
        }
        
        guard let upgradeCost = building.getUpgradeCost(),
              let upgradeTime = building.getUpgradeTime() else {
            return
        }
        
        var costString = ""
        var canAfford = true
        for (resourceType, amount) in upgradeCost {
            let hasEnough = player.hasResource(resourceType, amount: amount)
            let icon = hasEnough ? "✅" : "❌"
            costString += "\(icon) \(resourceType.icon)\(amount) "
            if !hasEnough { canAfford = false }
        }
        
        let timeString = formatTime(upgradeTime)
        
        let message = """
        Upgrade \(building.buildingType.displayName) to Level \(building.level + 1)
        
        Cost: \(costString)
        Time: \(timeString)
        """
        
        var actions: [AlertAction] = []
        
        if canAfford {
            actions.append(AlertAction(title: "⬆️ Start Upgrade") { [weak self] in
                self?.executeUpgradeCommand(building: building, villagerEntity: villagerEntity)
            })
        } else {
            actions.append(AlertAction(title: "❌ Cannot Afford", handler: nil))
        }
        
        vc.showActionSheet(
            title: "⬆️ Upgrade Building",
            message: message,
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    // MARK: - Reinforcement Menus
    
    func showReinforcementSourceSelection(for army: Army) {
        guard let player = player,
              let vc = viewController else { return }
        
        let buildingsWithGarrison = player.buildings.filter { $0.getTotalGarrisonedUnits() > 0 }
        
        var actions: [AlertAction] = []
        
        for building in buildingsWithGarrison {
            let garrisonCount = building.getTotalGarrisonedUnits()
            let title = "\(building.buildingType.icon) \(building.buildingType.displayName) (\(garrisonCount) units) - (\(building.coordinate.q), \(building.coordinate.r))"
            
            actions.append(AlertAction(title: title) { [weak self] in
                self?.showReinforcementUnitSelection(from: building, to: army)
            })
        }
        
        vc.showActionSheet(
            title: "🔄 Select Garrison Source",
            message: "Choose which building to reinforce \(army.name) from:",
            actions: actions
        )
    }
    
    func showReinforcementTargetSelection(from building: BuildingNode) {
        guard let player = player,
              let vc = viewController else { return }
        
        let armies = player.getArmies()
        
        guard !armies.isEmpty else {
            vc.showAlert(title: "No Armies", message: "You don't have any armies to reinforce. Recruit a commander first!")
            return
        }
        
        var actions: [AlertAction] = []
        
        for army in armies {
            let unitCount = army.getTotalMilitaryUnits()
            let commanderName = army.commander?.name ?? "No Commander"
            let title = "🛡️ \(army.name) - \(commanderName) (\(unitCount) units)"
            
            actions.append(AlertAction(title: title) { [weak self] in
                self?.showReinforcementUnitSelection(from: building, to: army)
            })
        }
        
        vc.showActionSheet(
            title: "⚔️ Select Army to Reinforce",
            message: "Choose which army to reinforce from \(building.buildingType.displayName):",
            actions: actions
        )
    }
    
    func showReinforcementUnitSelection(from building: BuildingNode, to army: Army) {
        guard let vc = viewController else { return }
        
        let militaryGarrison = building.garrison
        
        guard !militaryGarrison.isEmpty else {
            vc.showAlert(title: "No Military Units", message: "This building has no military units to reinforce with.")
            return
        }
        
        // Create slider-based selection UI
        let alert = UIAlertController(
            title: "🔄 Reinforce \(army.name)",
            message: "Select units to transfer from \(building.buildingType.displayName):\n\n\n\n\n",
            preferredStyle: .alert
        )
        
        var sliders: [MilitaryUnitType: UISlider] = [:]
        var yOffset: CGFloat = 60
        
        for (unitType, count) in militaryGarrison.sorted(by: { $0.key.displayName < $1.key.displayName }) {
            let label = UILabel(frame: CGRect(x: 10, y: yOffset, width: 250, height: 20))
            label.text = "\(unitType.icon) \(unitType.displayName): 0/\(count)"
            label.font = UIFont.systemFont(ofSize: 14)
            label.tag = unitType.hashValue
            alert.view.addSubview(label)
            
            let slider = UISlider(frame: CGRect(x: 10, y: yOffset + 25, width: 250, height: 30))
            slider.minimumValue = 0
            slider.maximumValue = Float(count)
            slider.value = 0
            slider.tag = unitType.hashValue
            slider.addTarget(self, action: #selector(reinforceSliderChanged(_:)), for: .valueChanged)
            alert.view.addSubview(slider)
            
            sliders[unitType] = slider
            yOffset += 60
        }
        
        // Adjust alert height
        let height = NSLayoutConstraint(item: alert.view!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: yOffset + 100)
        alert.view.addConstraint(height)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reinforce", style: .default) { [weak self] _ in
            self?.executeReinforcementCommand(from: building, to: army, sliders: sliders)
        })
        
        vc.present(alert, animated: true)
    }
    
    @objc private func reinforceSliderChanged(_ sender: UISlider) {
        guard let alert = viewController?.presentedViewController as? UIAlertController else { return }
        
        for subview in alert.view.subviews {
            if let label = subview as? UILabel, label.tag == sender.tag {
                let unitType = MilitaryUnitType.allCases.first { $0.hashValue == sender.tag }
                if let type = unitType {
                    label.text = "\(type.icon) \(type.displayName): \(Int(sender.value))/\(Int(sender.maximumValue))"
                }
                break
            }
        }
    }
    
    // MARK: - Villager Selection for Gathering
    
    func showVillagerSelectionForGathering(resourcePoint: ResourcePointNode) {
        guard let player = player,
              let vc = viewController else { return }
        
        let availableVillagers = player.getVillagerGroups().filter {
            $0.currentTask == .idle && $0.coordinate.distance(to: resourcePoint.coordinate) <= 10
        }
        
        guard !availableVillagers.isEmpty else {
            vc.showAlert(title: "No Villagers", message: "No idle villagers available nearby to gather resources.")
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
            message: "Choose which villager group to gather \(resourcePoint.resourceType.displayName)\n\nRemaining: \(resourcePoint.remainingAmount)\nCapacity: \(resourcePoint.getTotalVillagersGathering())/\(ResourcePointNode.maxVillagersPerTile)",
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    // MARK: - Villager Selection for Hunt
    
    func showVillagerSelectionForHunt(resourcePoint: ResourcePointNode) {
        guard let player = player,
              let vc = viewController else { return }
        
        let availableVillagers = player.getVillagerGroups().filter {
            $0.currentTask == .idle && $0.coordinate.distance(to: resourcePoint.coordinate) <= 10
        }
        
        guard !availableVillagers.isEmpty else {
            vc.showAlert(title: "No Villagers", message: "No idle villagers available nearby to hunt.")
            return
        }
        
        var actions: [AlertAction] = []
        
        for villagerGroup in availableVillagers {
            let distance = villagerGroup.coordinate.distance(to: resourcePoint.coordinate)
            let title = "👷 \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) - Distance: \(distance)"
            
            actions.append(AlertAction(title: title) { [weak self] in
                self?.startHunt(villagerGroup: villagerGroup, target: resourcePoint)
            })
        }
        
        vc.showActionSheet(
            title: "🏹 Select Villagers to Hunt",
            message: "Choose which villager group to hunt \(resourcePoint.resourceType.displayName)\n\nHealth: \(Int(resourcePoint.currentHealth))/\(Int(resourcePoint.resourceType.health))",
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    // MARK: - Garrison Info
    
    func showGarrisonInfo(for building: BuildingNode) {
        guard let vc = viewController else { return }
        
        var message = ""
        var totalCount = 0
        
        // Military units
        for (unitType, count) in building.garrison.sorted(by: { $0.key.displayName < $1.key.displayName }) {
            message += "\(unitType.icon) \(unitType.displayName): \(count)\n"
            totalCount += count
        }
        
        // Villagers
        if building.villagerGarrison > 0 {
            message += "👷 Villagers: \(building.villagerGarrison)\n"
            totalCount += building.villagerGarrison
        }
        
        if totalCount == 0 {
            message = "No units garrisoned."
        }
        
        vc.showAlert(title: "🏰 Garrison", message: message)
    }
    
    // MARK: - Army Details
    
    func showArmyDetails(_ army: Army, at coordinate: HexCoordinate) {
        guard let vc = viewController else { return }
        
        let message = formatArmyComposition(army)
        
        var actions: [AlertAction] = []
        
        actions.append(AlertAction(title: "🚶 Select to Move") { [weak self] in
            if let entityNode = self?.hexMap?.entities.first(where: {
                ($0.entity as? Army)?.id == army.id
            }) {
                self?.gameScene?.selectEntity(entityNode)
            }
        })
        
        vc.showActionSheet(
            title: "🛡️ \(army.name)",
            message: message,
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    // MARK: - Game Menu
    
    func showGameMenu() {
        guard let vc = viewController,
              let gameVC = vc as? GameViewController else { return }
        
        let actions: [AlertAction] = [
            AlertAction(title: "💾 Save Game") {
                gameVC.manualSave()
            },
            AlertAction(title: "📂 Load Game") {
                gameVC.confirmLoad()
            },
            AlertAction(title: "🏠 Main Menu") {
                gameVC.returnToMainMenu()
            }
        ]
        
        vc.showActionSheet(
            title: "⚙️ Game Menu",
            actions: actions,
            sourceRect: CGRect(x: vc.view.bounds.width - 70, y: 50, width: 0, height: 0)
        )
    }
    
    // MARK: - Building Detail
    
    func presentBuildingDetail(for building: BuildingNode) {
        guard let vc = viewController as? GameViewController,
              let player = player,
              let hexMap = hexMap,
              let gameScene = gameScene else { return }
        
        let detailVC = BuildingDetailViewController()
        detailVC.building = building
        detailVC.player = player
        detailVC.hexMap = hexMap
        detailVC.gameScene = gameScene
        detailVC.gameViewController = vc
        detailVC.modalPresentationStyle = .pageSheet
        
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.selectedDetentIdentifier = .large
        }
        
        vc.present(detailVC, animated: true)
    }
    
    // =========================================================================
    // MARK: - Command Execution Methods
    // =========================================================================
    
    /// Executes a MoveCommand
    private func executeMoveCommand(entity: EntityNode, to destination: HexCoordinate) {
        guard let player = player else { return }
        
        let command = MoveCommand(
            playerID: player.id,
            entityID: entity.entity.id,
            destination: destination
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if !result.succeeded, let reason = result.failureReason {
            viewController?.showAlert(title: "Cannot Move", message: reason)
        }
        
        delegate?.deselectAll()
    }
    
    /// Executes a BuildCommand
    private func executeBuildCommand(buildingType: BuildingType, at coordinate: HexCoordinate, builder: EntityNode?) {
        guard let player = player else { return }
        
        let command = BuildCommand(
            playerID: player.id,
            buildingType: buildingType,
            coordinate: coordinate,
            builderEntityID: builder?.entity.id
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if !result.succeeded, let reason = result.failureReason {
            viewController?.showAlert(title: "Cannot Build", message: reason)
        }
        
        delegate?.updateResourceDisplay()
        delegate?.deselectAll()
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
            viewController?.showAlert(title: "Cannot Gather", message: reason)
        }
        
        delegate?.updateResourceDisplay()
        delegate?.deselectAll()
    }
    
    /// Executes a StopGatheringCommand
    private func executeStopGatheringCommand(villagerGroup: VillagerGroup) {
        guard let player = player else { return }
        
        let command = StopGatheringCommand(
            playerID: player.id,
            villagerGroupID: villagerGroup.id
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if result.succeeded {
            viewController?.showAlert(
                title: "✅ Gathering Cancelled",
                message: "\(villagerGroup.name) is now idle and available for new tasks."
            )
        } else if let reason = result.failureReason {
            viewController?.showAlert(title: "Cannot Stop Gathering", message: reason)
        }
        
        delegate?.updateResourceDisplay()
        delegate?.deselectAll()
    }
    
    /// Executes an UpgradeCommand
    private func executeUpgradeCommand(building: BuildingNode, villagerEntity: EntityNode) {
        guard let player = player else { return }
        
        let command = UpgradeCommand(
            playerID: player.id,
            buildingID: building.data.id,
            upgraderEntityID: villagerEntity.entity.id
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if !result.succeeded, let reason = result.failureReason {
            viewController?.showAlert(title: "Cannot Upgrade", message: reason)
        }
        
        delegate?.updateResourceDisplay()
        delegate?.deselectAll()
    }
    
    /// Executes a CancelUpgradeCommand
    private func executeCancelUpgradeCommand(building: BuildingNode) {
        guard let player = player else { return }
        
        let command = CancelUpgradeCommand(
            playerID: player.id,
            buildingID: building.data.id
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if result.succeeded {
            viewController?.showAlert(title: "✅ Upgrade Cancelled", message: "Resources have been refunded.")
        } else if let reason = result.failureReason {
            viewController?.showAlert(title: "Cannot Cancel", message: reason)
        }
        
        delegate?.updateResourceDisplay()
        delegate?.deselectAll()
    }
    
    /// Executes a ReinforceArmyCommand
    private func executeReinforcementCommand(from building: BuildingNode, to army: Army, sliders: [MilitaryUnitType: UISlider]) {
        guard let player = player else { return }
        
        var units: [MilitaryUnitType: Int] = [:]
        for (unitType, slider) in sliders {
            let count = Int(slider.value)
            if count > 0 {
                units[unitType] = count
            }
        }
        
        guard !units.isEmpty else {
            viewController?.showAlert(title: "No Units Selected", message: "Select at least one unit to transfer.")
            return
        }
        
        let command = ReinforceArmyCommand(
            playerID: player.id,
            buildingID: building.data.id,
            armyID: army.id,
            units: units
        )
        
        let result = CommandExecutor.shared.execute(command)
        
        if !result.succeeded, let reason = result.failureReason {
            viewController?.showAlert(title: "Reinforcement Failed", message: reason)
        }
    }
    
    // =========================================================================
    // MARK: - Non-Command Methods (Hunting, Cancel Tasks)
    // =========================================================================
    
    /// Starts a hunt (not yet converted to command - complex combat logic)
    private func startHunt(villagerGroup: VillagerGroup, target: ResourcePointNode) {
        guard let hexMap = hexMap,
              let gameScene = gameScene else { return }
        
        guard let entityNode = hexMap.entities.first(where: {
            ($0.entity as? VillagerGroup)?.id == villagerGroup.id
        }) else {
            viewController?.showAlert(title: "Error", message: "Could not find villager group.")
            return
        }
        
        villagerGroup.assignTask(.hunting(target), target: target.coordinate)
        entityNode.isMoving = true
        
        // Move to target
        if let path = hexMap.findPath(from: entityNode.coordinate, to: target.coordinate) {
            entityNode.moveTo(path: path) { [weak self] in
                self?.gameScene?.villagerArrivedForHunt(villagerGroup: villagerGroup, target: target, entityNode: entityNode)
            }
        }
        
        print("🏹 \(villagerGroup.name) heading to hunt \(target.resourceType.displayName)")
        delegate?.deselectAll()
    }
    
    func executeHunt(villagerGroup: VillagerGroup, target: ResourcePointNode, entityNode: EntityNode) {
        guard let player = player,
              let hexMap = hexMap,
              let gameScene = gameScene,
              let vc = viewController else { return }
        
        // Verify target still valid
        guard target.parent != nil,
              target.resourceType.isHuntable,
              target.currentHealth > 0 else {
            villagerGroup.clearTask()
            entityNode.isMoving = false
            vc.showAlert(title: "Hunt Failed", message: "The target is no longer available.")
            return
        }
        
        // Calculate combat - villager count is attack power
        let villagerAttack = Double(villagerGroup.villagerCount) * 25
        let animalDefense = target.resourceType.defensePower
        let animalAttack = target.resourceType.attackPower
        
        // Damage to animal
        let damageToAnimal = max(1.0, villagerAttack - animalDefense)
        let isDead = target.takeDamage(damageToAnimal)
        
        print("⚔️ Villagers dealt \(damageToAnimal) damage to \(target.resourceType.displayName)")
        
        // Damage to villagers (animal fights back)
        let damageToVillagers = max(0.0, animalAttack - Double(villagerGroup.villagerCount) * 0.5)
        let villagersLost = Int(damageToVillagers / 5.0)  // Every 5 damage kills a villager
        
        if villagersLost > 0 {
            let actualLost = villagerGroup.removeVillagers(count: villagersLost)
            print("⚠️ \(actualLost) villagers were injured/killed by \(target.resourceType.displayName)")
        }
        
        if isDead {
            // Animal killed - create carcass
            villagerGroup.clearTask()
            entityNode.isMoving = false
            
            if let resourcesNode = gameScene.childNode(withName: "resourcesNode") {
                if let carcass = hexMap.createCarcass(from: target, scene: resourcesNode) {
                    // Remove the original animal
                    hexMap.removeResourcePoint(target)
                    target.removeFromParent()
                    
                    var message = "\(villagerGroup.name) killed the \(target.resourceType.displayName)!\n\n🥩 \(carcass.resourceType.displayName) left behind with \(carcass.remainingAmount) food.\n\nAssign villagers to gather the food."
                    
                    if villagersLost > 0 {
                        message += "\n\n⚠️ \(villagersLost) villager(s) were lost in the hunt."
                    }
                    
                    vc.showAlert(title: "🎯 Hunt Successful!", message: message)
                    
                    print("✅ Villagers hunted \(target.resourceType.displayName) - carcass created")
                }
            }
        } else {
            // Animal wounded but not dead - clear task so they can try again
            villagerGroup.clearTask()
            entityNode.isMoving = false
            
            let healthRemaining = Int(target.currentHealth)
            var message = "\(villagerGroup.name) wounded the \(target.resourceType.displayName)!\n\n❤️ Animal Health: \(healthRemaining)/\(Int(target.resourceType.health))"
            
            if villagersLost > 0 {
                message += "\n\n⚠️ \(villagersLost) villager(s) were injured."
            }
            
            message += "\n\nSend more villagers to finish the hunt!"
            
            vc.showAlert(title: "⚔️ Combat Continues", message: message)
        }
        
        // Remove empty villager groups
        if villagerGroup.villagerCount <= 0 {
            hexMap.removeEntity(entityNode)
            entityNode.removeFromParent()
            player.removeEntity(villagerGroup)
            print("💀 Villager group wiped out during hunt")
        }
        
        delegate?.updateResourceDisplay()
    }
  
    
    /// Cancels a hunting task (not yet a command)
    private func cancelHunting(villagerGroup: VillagerGroup) {
        guard let hexMap = hexMap,
              let vc = viewController else { return }
        
        guard case .hunting = villagerGroup.currentTask else {
            vc.showAlert(title: "Not Hunting", message: "\(villagerGroup.name) is not currently hunting.")
            return
        }
        
        villagerGroup.clearTask()
        
        if let entityNode = hexMap.entities.first(where: {
            ($0.entity as? VillagerGroup)?.id == villagerGroup.id
        }) {
            entityNode.isMoving = false
        }
        
        print("✅ Cancelled hunting for \(villagerGroup.name)")
        
        vc.showAlert(
            title: "✅ Hunt Cancelled",
            message: "\(villagerGroup.name) has stopped hunting and is now idle."
        )
        
        delegate?.deselectAll()
    }
    
    /// Cancels a building task (not yet a command)
    private func cancelBuilding(villagerGroup: VillagerGroup, building: BuildingNode) {
        guard let hexMap = hexMap,
              let vc = viewController else { return }
        
        building.buildersAssigned = max(0, building.buildersAssigned - villagerGroup.villagerCount)
        
        villagerGroup.clearTask()
        
        if let entityNode = hexMap.entities.first(where: {
            ($0.entity as? VillagerGroup)?.id == villagerGroup.id
        }) {
            entityNode.isMoving = false
        }
        
        print("✅ Cancelled building for \(villagerGroup.name)")
        
        vc.showAlert(
            title: "✅ Building Cancelled",
            message: "\(villagerGroup.name) stopped building \(building.buildingType.displayName)"
        )
        
        delegate?.deselectAll()
    }
    
    // =========================================================================
    // MARK: - Private Helpers
    // =========================================================================
    
    private func formatEntityTitle(_ entity: EntityNode) -> String {
        var title = "\(entity.entityType.icon) "
        
        if entity.entityType == .army, let army = entity.entity as? Army {
            let totalUnits = army.getTotalMilitaryUnits()
            title += "\(army.name) (\(totalUnits) units)"
        } else if entity.entityType == .villagerGroup, let villagers = entity.entity as? VillagerGroup {
            title += "\(villagers.name) (\(villagers.villagerCount) villagers)"
        }
        
        return title
    }
    
    private func formatCost(_ cost: [ResourceType: Int]) -> String {
        cost.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
    }
    
    private func formatArmyComposition(_ army: Army) -> String {
        var message = ""
        let totalUnits = army.getTotalMilitaryUnits()
        message += "Total Units: \(totalUnits)\n\n"
        
        if let commander = army.commander {
            message += "Commander: \(commander.name)\n"
            message += "Rank: \(commander.rank.displayName)\n"
        }
        
        return message
    }
    
    private func getRemainingTime(startTime: TimeInterval, totalTime: TimeInterval) -> TimeInterval {
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - startTime
        return max(0, totalTime - elapsed)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
