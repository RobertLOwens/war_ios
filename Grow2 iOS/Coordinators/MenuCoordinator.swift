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
                
                if building.state == .constructing {
                    let progress = Int(building.constructionProgress * 100)
                    message += "\n🔨 Construction: \(progress)%"
                }
                
                // ✅ Open Building action (only for completed, player-owned buildings)
                if building.state == .completed && building.owner?.id == player.id {
                    let buildingName = building.buildingType.displayName
                    actions.append(AlertAction(title: "🏗️ Open \(buildingName)", style: .default) { [weak self] in
                        self?.presentBuildingDetail(for: building)
                    })
                }
            } else if visibility == .explored {
                message = "Explored - Last seen: Building here"
            }
        }
        // Check for resource point (only if no building)
        else if let resourcePoint = hexMap.getResourcePoint(at: coordinate), visibility == .visible {
            title = "\(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"
            message = resourcePoint.getDescription()
            if resourcePoint.isBeingGathered {
                message += "\n\n🔨 Currently being gathered"
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
        
        // ✅ Add action for each visible entity
        for entity in visibleEntities {
            var buttonTitle = ""
            
            if entity.entityType == .villagerGroup {
                if let villagers = entity.entity as? VillagerGroup {
                    buttonTitle = "👷 \(villagers.name) (\(villagers.villagerCount) villagers)"
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
            
            actions.append(AlertAction(title: buttonTitle, style: .default) { [weak self] in
                self?.showEntityActionMenu(for: entity, at: coordinate)
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
        let playerEntities = entities.filter { $0.entity.owner?.id == player.id }
        
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
              let vc = viewController else { return }
        
        var message = "Villagers: \(villagers.villagerCount)\n"
        message += "Status: \(villagers.currentTask.displayName)"
        
        let buildingExists = hexMap.getBuilding(at: coordinate) != nil
        
        var actions: [AlertAction] = []
        
        // Build action
        let buildAction = AlertAction(title: "🏗️ Build") { [weak self] in
            self?.showBuildingMenu(at: coordinate, villagerGroup: villagerGroup)
        }
        if !buildingExists {
            actions.append(buildAction)
        } else {
            actions.append(AlertAction(title: "ℹ️ Building Already Exists Here", handler: nil))
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
    
    // MARK: - Building Menu
    
    /// Shows available buildings that can be constructed
    func showBuildingMenu(at coordinate: HexCoordinate, villagerGroup: EntityNode?) {
        guard let player = player,
              let vc = viewController else { return }
        
        var actions: [AlertAction] = []
        
        // Economic buildings
        let economicBuildings: [BuildingType] = [.cityCenter, .farm, .neighborhood, .lumberCamp, .miningCamp, .market, .warehouse, .blacksmith, .university]
        
        for buildingType in economicBuildings {
            let canAfford = player.canAfford(buildingType)
            let costString = formatCost(buildingType.buildCost)
            let title = "\(buildingType.icon) \(buildingType.displayName) - \(costString)"
            
            if canAfford {
                actions.append(AlertAction(title: title) { [weak self] in
                    self?.startConstruction(buildingType, at: coordinate, builder: villagerGroup)
                })
            } else {
                actions.append(AlertAction(title: "❌ \(title)") { [weak vc] in
                    vc?.showAlert(title: "Cannot Afford", message: "You need \(costString) to build \(buildingType.displayName)")
                })
            }
        }
        
        // Military buildings section
        actions.append(AlertAction(title: "--- Military Buildings ---", handler: nil))
        
        let militaryBuildings: [BuildingType] = [.barracks, .archeryRange, .stable, .siegeWorkshop, .tower, .woodenFort, .castle]
        
        for buildingType in militaryBuildings {
            let canAfford = player.canAfford(buildingType)
            let costString = formatCost(buildingType.buildCost)
            let title = "\(buildingType.icon) \(buildingType.displayName) - \(costString)"
            
            if canAfford {
                actions.append(AlertAction(title: title) { [weak self] in
                    self?.startConstruction(buildingType, at: coordinate, builder: villagerGroup)
                })
            } else {
                actions.append(AlertAction(title: "❌ \(title)") { [weak vc] in
                    vc?.showAlert(title: "Cannot Afford", message: "You need \(costString) to build \(buildingType.displayName)")
                })
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
    
}
