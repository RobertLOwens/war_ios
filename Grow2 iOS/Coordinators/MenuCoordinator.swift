// ============================================================================
// FILE: MenuCoordinator.swift
// LOCATION: Grow2 iOS/Coordinators/MenuCoordinator.swift
// PURPOSE: Handles all menu and alert presentation logic
//          Extracted from GameViewController to improve separation of concerns
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
              let gameScene = gameScene,
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
                
                // ✅ ADD: Level info
                message += "\n⭐ Level: \(building.level)/\(building.maxLevel)"
                
                if building.state == .constructing {
                    let progress = Int(building.constructionProgress * 100)
                    message += "\n🔨 Construction: \(progress)%"
                    if let startTime = building.constructionStartTime {
                        let remaining = getRemainingTime(startTime: startTime, totalTime: building.buildingType.buildTime)
                        message += " (\(formatTime(remaining)))"
                    }
                }
                
                // ✅ ADD: Upgrade progress info
                if building.state == .upgrading {
                    let progress = Int(building.upgradeProgress * 100)
                    message += "\n⬆️ Upgrading to Lv.\(building.level + 1): \(progress)%"
                    if let startTime = building.upgradeStartTime,
                       let upgradeTime = building.getUpgradeTime() {
                        let remaining = getRemainingTime(startTime: startTime, totalTime: upgradeTime)
                        message += " (\(formatTime(remaining)))"
                    }
                }
                
                // ✅ Open Building action (only for completed OR upgrading, player-owned buildings)
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

        if let resourcePoint = hexMap.getResourcePoint(at: coordinate), visibility == .visible {
            // Check if there's also a building here (for camps)
            if let building = hexMap.getBuilding(at: coordinate) {
                // Show combined building + resource info
                title = "\(building.buildingType.icon) \(building.buildingType.displayName)"
                message = building.buildingType.description
                message += "\nOwner: \(building.owner?.name ?? "Unknown")"
                message += "\nHealth: \(Int(building.health))/\(Int(building.maxHealth))"
                
                // Add resource info
                message += "\n\n📦 Resource: \(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"
                message += "\n   Remaining: \(resourcePoint.remainingAmount)"
                
                let villagerCount = resourcePoint.getTotalVillagersGathering()
                if villagerCount > 0 {
                    message += "\n   Gather Rate: \(String(format: "%.1f", resourcePoint.currentGatherRate))/s"
                    message += "\n   👷 Villagers: \(villagerCount)/\(ResourcePointNode.maxVillagersPerTile)"
                }
                
                // Gather action if camp allows it
                if building.state == .completed &&
                    resourcePoint.resourceType.isGatherable &&
                    resourcePoint.getRemainingCapacity() > 0 {
                    actions.append(AlertAction(title: "👷 Assign Villagers to Gather") { [weak self] in
                        self?.showVillagerSelectionForGathering(resourcePoint: resourcePoint)
                    })
                }
            } else {
                // Just resource, no building
                title = "\(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"
                message = resourcePoint.getDescription()
                
                // Check if huntable (use villagers now, not armies)
                if resourcePoint.resourceType.isHuntable {
                    actions.append(AlertAction(title: "🏹 Hunt with Villagers") { [weak self] in
                        self?.showVillagerSelectionForHunting(resourcePoint: resourcePoint)
                    })
                } else if resourcePoint.resourceType.isGatherable {
                    // Check camp requirement
                    if resourcePoint.resourceType.requiresCamp {
                        if hexMap.hasCampCoverage(at: coordinate, forResourceType: resourcePoint.resourceType) {
                            if resourcePoint.getRemainingCapacity() > 0 {
                                actions.append(AlertAction(title: "👷 Assign Villagers to Gather") { [weak self] in
                                    self?.showVillagerSelectionForGathering(resourcePoint: resourcePoint)
                                })
                            } else {
                                message += "\n\n⚠️ Max villagers reached"
                            }
                        } else {
                            let campName = resourcePoint.resourceType.requiredCampType?.displayName ?? "Camp"
                            message += "\n\n⚠️ Requires \(campName) nearby to gather"
                        }
                    } else {
                        // No camp required (forage, carcasses)
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
        
        // Filter to only visible entities
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
        
        // Add entity count to message if there are entities
        if !visibleEntities.isEmpty {
            if !message.isEmpty { message += "\n" }
            message += "\n📍 \(visibleEntities.count) unit(s) on this tile"
        }
        
        print(visibleEntities)
        // ✅ Add action for each visible entity
        for entity in visibleEntities {
            print("Run 1")
            var buttonTitle = ""
            
            if entity.entityType == .villagerGroup {
                if let villagers = entity.entity as? VillagerGroup {
                    print(villagers)
                    buttonTitle = "👷 \(villagers.name) (\(villagers.villagerCount) villagers)"
                                    
                    // Add task indicator
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
                    // Show options menu if gathering/hunting, otherwise show regular villager menu
                    switch villagers.currentTask {
                    case .gatheringResource, .hunting:
                        self?.showVillagerOptionsMenu(villagerGroup: villagers, entityNode: entity)
                    default:
                        self?.showVillagerMenu(at: coordinate, villagerGroup: entity)
                    }
                } else {
                    actions.append(AlertAction(title: buttonTitle, style: .default) { [weak self] in
                        self?.showEntityActionMenu(for: entity, at: coordinate)
                    })
                }
            })

        }
        
        // -------------------------
        // MARK: - Movement Action
        // -------------------------
        // Only show "Move Unit Here" if:
        // 1. Tile is visible or explored
        // 2. No hostile (neutral or enemy) entities on the tile
        
        if visibility == .visible || visibility == .explored {
            let hasHostileEntities = entitiesAtTile.contains { entity in
                let diplomacyStatus = player.getDiplomacyStatus(with: entity.entity.owner)
                return diplomacyStatus == .neutral || diplomacyStatus == .enemy
            }
            
            // Can only move if no hostile entities present
            // (Friendly entities or empty tile is fine)
            if !hasHostileEntities {
                actions.append(AlertAction(title: "🚶 Move Unit Here", style: .default) { [weak self] in
                    self?.gameScene?.initiateMove(to: coordinate)
                })
            } else {
                // Optional: Show why movement is blocked
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
    
    /// Shows available actions for a specific entity
    func showEntityActionMenu(for entity: EntityNode, at coordinate: HexCoordinate) {
        guard let player = player,
              let vc = viewController else { return }
        
        // Villagers have their own specialized menu
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
        
        // Army-specific actions (only for owned entities)
        if entity.entityType == .army,
           let army = entity.entity as? Army,
           army.owner?.id == player.id {
            
            // Reinforce action
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
    
    /// Shows a menu to select which entity to move to a destination
    func showMoveSelectionMenu(to coordinate: HexCoordinate, from entities: [EntityNode]) {
        
        guard let player = player,
              let vc = viewController else { return }
        
        // Filter to only player-owned entities
        let playerEntities = entities.filter { entity in
            // Must be owned by player
            guard entity.entity.owner?.id == player.id else { return false }
            
            // If it's a villager group, must be idle to move
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
                self?.gameScene?.moveEntity(entity, to: coordinate)
                self?.delegate?.deselectAll()
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
    
  
    /// Shows actions available for a villager group
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
                    self?.cancelGathering(villagerGroup: villagers)
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
                        self?.assignVillagersToGather(villagerGroup: villagers, resourcePoint: resourcePoint)
                    })
                }
            }
        }
        
        // -------------------------
        // SHOW MENU
        // -------------------------
        
        vc.showActionSheet(
            title: "👷 \(villagers.name)",
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
        
        var actions: [AlertAction] = []
        
        for type in BuildingType.allCases {
            // Check basic placement
            let canPlace = hexMap.canPlaceBuilding(at: coordinate, buildingType: type)
            
            // Build cost string
            var costString = ""
            for (resourceType, amount) in type.buildCost {
                costString += "\(resourceType.icon)\(amount) "
            }
            
            let title = "\(type.icon) \(type.displayName) - \(costString)"
            
            if canPlace {
                actions.append(AlertAction(title: title) { [weak self] in
                    // Check if there's a resource that will be removed
                    if let resource = hexMap.getResourcePoint(at: coordinate) {
                        if type != .miningCamp && type != .lumberCamp {
                            // Show warning for other building types
                            self?.showBuildingConfirmationWithResourceWarning(
                                buildingType: type,
                                coordinate: coordinate,
                                resource: resource,
                                villagerGroup: villagerGroup
                            )
                            return
                        }
                    }
                    
                    // No resource or it's a camp - proceed normally
                    self?.gameScene?.placeBuilding(type: type, at: coordinate, owner: player)
                })
            } else {
                // Show why it can't be placed
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
            message: "Choose a building to construct at (\(coordinate.q), \(coordinate.r))",
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    // MARK: - Reinforcement Menus
    
    /// Shows available garrison sources for reinforcing an army
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
    
    /// Shows available armies to reinforce from a building
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
            let distance = army.coordinate.distance(to: building.coordinate)
            let title = "🛡️ \(army.name) - \(commanderName) (\(unitCount) units) - Distance: \(distance)"
            
            actions.append(AlertAction(title: title) { [weak self] in
                self?.showReinforcementUnitSelection(from: building, to: army)
            })
        }
        
        vc.showActionSheet(
            title: "⚔️ Select Army to Reinforce",
            message: "Choose which army to reinforce from \(building.buildingType.displayName):\n\nGarrison: \(building.getTotalGarrisonedUnits()) units available",
            actions: actions
        )
    }
    
    /// Shows unit selection UI for transferring units from building to army
    func showReinforcementUnitSelection(from building: BuildingNode, to army: Army) {
        guard let vc = viewController else { return }
        
        // Create custom container for sliders
        let containerVC = UIViewController()
        containerVC.preferredContentSize = CGSize(width: 270, height: 350)
        
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 270, height: 350))
        scrollView.backgroundColor = .clear
        
        let contentView = UIView()
        var yOffset: CGFloat = 10
        var sliders: [MilitaryUnitType: UISlider] = [:]
        
        // Create slider for each unit type in garrison
        for (unitType, count) in building.garrison where count > 0 {
            let label = UILabel(frame: CGRect(x: 10, y: yOffset, width: 250, height: 20))
            label.text = "\(unitType.icon) \(unitType.displayName): 0/\(count)"
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = .label
            label.tag = unitType.hashValue
            contentView.addSubview(label)
            
            let slider = UISlider(frame: CGRect(x: 10, y: yOffset + 25, width: 250, height: 30))
            slider.minimumValue = 0
            slider.maximumValue = Float(count)
            slider.value = 0
            slider.tag = unitType.hashValue
            slider.addTarget(self, action: #selector(reinforcementSliderChanged(_:)), for: .valueChanged)
            contentView.addSubview(slider)
            sliders[unitType] = slider
            
            yOffset += 65
        }
        
        contentView.frame = CGRect(x: 0, y: 0, width: 270, height: yOffset)
        scrollView.addSubview(contentView)
        scrollView.contentSize = contentView.frame.size
        containerVC.view.addSubview(scrollView)
        
        // Store sliders reference for action
        let actions: [AlertAction] = [
            AlertAction(title: "Reinforce") { [weak self] in
                self?.executeReinforcement(from: building, to: army, sliders: sliders)
            },
            .cancel()
        ]
        
        vc.showAlertWithCustomContent(
            title: "🔄 Reinforce \(army.name)",
            message: "Select units from \(building.buildingType.displayName) garrison",
            contentViewController: containerVC,
            actions: actions
        )
    }
    
    @objc private func reinforcementSliderChanged(_ slider: UISlider) {
        // Find label with matching tag and update
        if let label = slider.superview?.viewWithTag(slider.tag) as? UILabel {
            let current = Int(slider.value)
            let max = Int(slider.maximumValue)
            
            // Extract unit name from existing label
            if let text = label.text, let colonIndex = text.firstIndex(of: ":") {
                let unitName = String(text[..<colonIndex])
                label.text = "\(unitName): \(current)/\(max)"
            }
        }
    }
    
    // MARK: - Garrison Menu
    
    /// Shows garrison contents and actions for a building
    func showGarrisonMenu(for building: BuildingNode) {
        guard let vc = viewController else { return }
        
        let militaryCount = building.getTotalGarrisonedUnits()
        let villagerCount = building.villagerGarrison
        let totalCount = militaryCount + villagerCount
        let capacity = building.getGarrisonCapacity()
        
        var message = "Garrisoned Units: \(totalCount)/\(capacity)\n\n"
        
        if villagerCount > 0 {
            message += "👷 Villagers: \(villagerCount)\n"
        }
        
        if militaryCount > 0 {
            message += "\n⚔️ Military Units:\n"
            for (unitType, count) in building.garrison.sorted(by: { $0.key.displayName < $1.key.displayName }) {
                message += "\(unitType.icon) \(unitType.displayName): \(count)\n"
            }
            message += "\n💡 Use 'Reinforce Army' to add these units to an existing army."
        }
        
        if totalCount == 0 {
            message = "No units garrisoned."
        }
        
        vc.showAlert(title: "🏰 Garrison", message: message)
    }
    
    // MARK: - Army Details
    
    /// Shows detailed info about an army
    func showArmyDetails(_ army: Army, at coordinate: HexCoordinate) {
        guard let vc = viewController else { return }
        
        let message = formatArmyComposition(army)
        
        var actions: [AlertAction] = []
        
        // Select for movement
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
    
    /// Shows the main game menu (save/load/quit)
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
    
    // MARK: - Private Helpers
    
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
        return message
    }
    
    private func startConstruction(_ buildingType: BuildingType, at coordinate: HexCoordinate, builder: EntityNode?) {
        guard let player = player,
              let gameScene = gameScene else { return }
        
        // Deduct resources
        for (resourceType, amount) in buildingType.buildCost {
            player.removeResource(resourceType, amount: amount)
        }
        
        // Place building
        gameScene.placeBuilding(type: buildingType, at: coordinate, owner: player)
        
        // Assign builder if available
        if let villagerEntity = builder,
           let villagers = villagerEntity.entity as? VillagerGroup,
           let building = hexMap?.getBuilding(at: coordinate) {
            villagers.assignTask(.building(building))
            villagerEntity.isMoving = true
            building.builderEntity = villagerEntity
        }
        
        delegate?.updateResourceDisplay()
        delegate?.deselectAll()
    }
    
    private func executeReinforcement(from building: BuildingNode, to army: Army, sliders: [MilitaryUnitType: UISlider]) {
        var totalTransferred = 0
        
        for (unitType, slider) in sliders {
            let count = Int(slider.value)
            if count > 0 {
                building.removeFromGarrison(unitType: unitType, quantity: count)
                army.addMilitaryUnits(unitType, count: count)
                totalTransferred += count
            }
        }
        
        if totalTransferred > 0 {
            viewController?.showAlert(
                title: "✅ Reinforcement Complete",
                message: "Transferred \(totalTransferred) units to \(army.name)"
            )
        }
    }
    
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
            self?.gameScene?.placeBuilding(type: buildingType, at: coordinate, owner: self?.player ?? Player(name: "Unknown", color: .gray))
        })
        
        vc.present(alert, animated: true)
    }
    
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
                self?.assignVillagersToGather(villagerGroup: villagerGroup, resourcePoint: resourcePoint)
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
    
    func assignVillagersToGather(villagerGroup: VillagerGroup, resourcePoint: ResourcePointNode) {
         guard let player = player,
               let hexMap = hexMap,
               let gameScene = gameScene,
               let vc = viewController else { return }
         
         // Check if resource is gatherable
         guard resourcePoint.resourceType.isGatherable else {
             vc.showAlert(title: "Cannot Gather", message: "This \(resourcePoint.resourceType.displayName) must be hunted first!")
             return
         }
         
         // Check camp requirement
         if resourcePoint.resourceType.requiresCamp {
             guard hexMap.hasCampCoverage(at: resourcePoint.coordinate, forResourceType: resourcePoint.resourceType) else {
                 let campName = resourcePoint.resourceType.requiredCampType?.displayName ?? "Camp"
                 vc.showAlert(
                     title: "⚠️ No \(campName) Nearby",
                     message: "You need a \(campName) built on or adjacent to this \(resourcePoint.resourceType.displayName) before villagers can gather here."
                 )
                 return
             }
         }
         
         // Check villager capacity
         guard resourcePoint.canAddVillagers(villagerGroup.villagerCount) else {
             let remaining = resourcePoint.getRemainingCapacity()
             vc.showAlert(
                 title: "⚠️ Too Many Villagers",
                 message: "This resource can only support \(ResourcePointNode.maxVillagersPerTile) villagers.\n\nCurrently: \(resourcePoint.getTotalVillagersGathering())\nRemaining capacity: \(remaining)"
             )
             return
         }
         
         // Assign task
         villagerGroup.assignTask(.gatheringResource(resourcePoint), target: resourcePoint.coordinate)
         resourcePoint.startGathering(by: villagerGroup)
         
         // Apply collection rate bonus based on villager count
         let resourceYield = resourcePoint.resourceType.resourceYield
         let rateContribution = 0.2 * Double(villagerGroup.villagerCount)
         player.increaseCollectionRate(resourceYield, amount: rateContribution)
         print("✅ Increased \(resourceYield.displayName) collection rate by \(rateContribution)/s")
         
         // Find entity node and move to resource
         if let entityNode = hexMap.entities.first(where: {
             ($0.entity as? VillagerGroup)?.id == villagerGroup.id
         }) {
             gameScene.moveEntity(entityNode, to: resourcePoint.coordinate)
         }
         
         print("✅ Assigned \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) to gather \(resourcePoint.resourceType.displayName)")
         
         delegate?.deselectAll()
     }
    
    func showVillagerSelectionForHunting(resourcePoint: ResourcePointNode) {
        guard let player = player,
              let vc = viewController else { return }
        
        let availableVillagers = player.getVillagerGroups().filter {
            $0.currentTask == .idle &&
            $0.villagerCount > 0 &&
            $0.coordinate.distance(to: resourcePoint.coordinate) <= 10
        }
        
        guard !availableVillagers.isEmpty else {
            vc.showAlert(title: "No Villagers", message: "No idle villagers available nearby to hunt.")
            return
        }
        
        var actions: [AlertAction] = []
        
        for villagerGroup in availableVillagers {
            let distance = villagerGroup.coordinate.distance(to: resourcePoint.coordinate)
            // Show hunting power (villager count acts as attack strength)
            let huntPower = villagerGroup.villagerCount * 100
            let title = "👷 \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) ⚔️\(huntPower) - Distance: \(distance)"
            
            actions.append(AlertAction(title: title) { [weak self] in
                self?.huntWithVillagers(villagerGroup: villagerGroup, target: resourcePoint)
            })
        }
        
        vc.showActionSheet(
            title: "🏹 Select Hunters",
            message: "Choose villagers to hunt the \(resourcePoint.resourceType.displayName)\n\n❤️ Health: \(Int(resourcePoint.currentHealth))/\(Int(resourcePoint.resourceType.health))\n🛡️ Defense: \(Int(resourcePoint.resourceType.defensePower))\n⚔️ Attack: \(Int(resourcePoint.resourceType.attackPower))\n\n⚠️ Villagers may be injured!",
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
    
    func huntWithVillagers(villagerGroup: VillagerGroup, target: ResourcePointNode) {
            guard let player = player,
                  let hexMap = hexMap,
                  let gameScene = gameScene,
                  let vc = viewController else { return }
            
            // Find the entity node for this villager group
            guard let entityNode = hexMap.entities.first(where: {
                ($0.entity as? VillagerGroup)?.id == villagerGroup.id
            }) else {
                vc.showAlert(title: "Error", message: "Could not find villager group on map.")
                return
            }
            
            // Check if already at the target location
            if villagerGroup.coordinate == target.coordinate {
                // Already there - execute hunt immediately
                executeHunt(villagerGroup: villagerGroup, target: target, entityNode: entityNode)
            } else {
                // Need to move first - assign hunting task and move
                villagerGroup.assignTask(.hunting(target), target: target.coordinate)
                entityNode.isMoving = true
                
                // Move to the target
                gameScene.moveEntity(entityNode, to: target.coordinate)
                
                print("🏹 Villagers moving to hunt \(target.resourceType.displayName) at (\(target.coordinate.q), \(target.coordinate.r))")
            }
            
            delegate?.deselectAll()
        }
        
    // MARK: - ADD: Execute hunt when villagers arrive
    // LOCATION: Add after huntWithVillagers method

        func executeHunt(villagerGroup: VillagerGroup, target: ResourcePointNode, entityNode: EntityNode) {
            guard let player = player,
                  let hexMap = hexMap,
                  let gameScene = gameScene,
                  let vc = viewController else { return }
            
            // Calculate combat - villager count is attack power
            let villagerAttack = Double(villagerGroup.villagerCount) * 25
            let animalDefense = target.resourceType.defensePower
            let animalAttack = target.resourceType.attackPower
            
            // Damage to animal
            let damageToAnimal = max(1.0, villagerAttack - animalDefense)
            let isDead = target.takeDamage(damageToAnimal)
            
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
            
            // Check if villager group is now empty
            if villagerGroup.villagerCount <= 0 {
                // Remove the empty group
                hexMap.removeEntity(entityNode)
                entityNode.removeFromParent()
                player.removeEntity(villagerGroup)
                print("💀 Villager group wiped out during hunt")
            }
            
            delegate?.updateResourceDisplay()
        }
    
    func cancelGathering(villagerGroup: VillagerGroup) {
            guard let player = player,
                  let hexMap = hexMap,
                  let vc = viewController else { return }
            
            // Check if villagers are gathering
            guard case .gatheringResource(let resourcePoint) = villagerGroup.currentTask else {
                vc.showAlert(title: "Not Gathering", message: "\(villagerGroup.name) is not currently gathering resources.")
                return
            }
            
            // Revert collection rate
            let rateContribution = 0.2 * Double(villagerGroup.villagerCount)
            player.decreaseCollectionRate(resourcePoint.resourceType.resourceYield, amount: rateContribution)
            
            // Remove from resource point
            resourcePoint.stopGathering(by: villagerGroup)
            
            // Clear task
            villagerGroup.clearTask()
            
            // Unlock entity
            if let entityNode = hexMap.entities.first(where: {
                ($0.entity as? VillagerGroup)?.id == villagerGroup.id
            }) {
                entityNode.isMoving = false
            }
            
            print("✅ Cancelled gathering for \(villagerGroup.name)")
            
            vc.showAlert(
                title: "✅ Gathering Cancelled",
                message: "\(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) is now idle and available for new tasks."
            )
            
            delegate?.deselectAll()
        }
    
    func showVillagerOptionsMenu(villagerGroup: VillagerGroup, entityNode: EntityNode) {
         guard let vc = viewController else { return }
         
         var actions: [AlertAction] = []
         var message = "Villagers: \(villagerGroup.villagerCount)\n"
         message += "Status: \(villagerGroup.currentTask.displayName)"
         
         // Show cancel option if gathering
         if case .gatheringResource(let resourcePoint) = villagerGroup.currentTask {
             message += "\n\nGathering: \(resourcePoint.resourceType.displayName)"
             message += "\nRemaining: \(resourcePoint.remainingAmount)"
             
             actions.append(AlertAction(title: "🛑 Cancel Gathering", style: .destructive) { [weak self] in
                 self?.cancelGathering(villagerGroup: villagerGroup)
             })
         }
         
         // Show cancel option if hunting
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
     
 // MARK: - ADD: Cancel hunting method
 // LOCATION: Add after cancelGathering method

     func cancelHunting(villagerGroup: VillagerGroup) {
         guard let hexMap = hexMap,
               let vc = viewController else { return }
         
         // Check if villagers are hunting
         guard case .hunting = villagerGroup.currentTask else {
             vc.showAlert(title: "Not Hunting", message: "\(villagerGroup.name) is not currently hunting.")
             return
         }
         
         // Clear task
         villagerGroup.clearTask()
         
         // Unlock entity
         if let entityNode = hexMap.entities.first(where: {
             ($0.entity as? VillagerGroup)?.id == villagerGroup.id
         }) {
             entityNode.isMoving = false
         }
         
         print("✅ Cancelled hunting for \(villagerGroup.name)")
         
         vc.showAlert(
             title: "✅ Hunt Cancelled",
             message: "\(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) has stopped hunting and is now idle."
         )
         
         delegate?.deselectAll()
     }
    
    func cancelBuilding(villagerGroup: VillagerGroup, building: BuildingNode) {
            guard let hexMap = hexMap,
                  let vc = viewController else { return }
            
            // Reduce builders assigned
            building.buildersAssigned = max(0, building.buildersAssigned - villagerGroup.villagerCount)
            
            // Clear task
            villagerGroup.clearTask()
            
            // Unlock entity
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
    
    func showUpgradeOption(for building: BuildingNode, villagerEntity: EntityNode) {
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
            
            // Format cost string
            var costString = ""
            for (resourceType, amount) in upgradeCost {
                let hasEnough = player.hasResource(resourceType, amount: amount)
                let icon = hasEnough ? "✅" : "❌"
                costString += "\(icon) \(resourceType.icon)\(amount) "
            }
            
            // Format time
            let minutes = Int(upgradeTime) / 60
            let seconds = Int(upgradeTime) % 60
            let timeString = "\(minutes)m \(seconds)s"
            
            let message = """
            Upgrade \(building.buildingType.displayName) to Level \(building.level + 1)
            
            Cost: \(costString)
            Time: \(timeString)
            """
            
            let canAfford = upgradeCost.allSatisfy { player.hasResource($0.key, amount: $0.value) }
            
            var actions: [AlertAction] = []
            
            if canAfford {
                actions.append(AlertAction(title: "⬆️ Upgrade to Level \(building.level + 1)") { [weak self] in
                    self?.gameScene?.startBuildingUpgrade(building: building, villagerEntity: villagerEntity)
                })
            } else {
                actions.append(AlertAction(title: "❌ Cannot Afford Upgrade", handler: nil))
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
    
    private func getRemainingTime(startTime: TimeInterval, totalTime: TimeInterval) -> TimeInterval {
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - startTime
        return max(0, totalTime - elapsed)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins)m \(secs)s"
    }
    
    
    
}
