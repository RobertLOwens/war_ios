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
        // MARK: - Terrain Info
        // -------------------------
        if let tile = hexMap.getTile(at: coordinate) {
            var terrainInfo = "🗺️ \(tile.terrain.displayName)"
            if tile.elevation > 0 {
                terrainInfo += " (Elevation: \(tile.elevation))"
            }
            message = terrainInfo
        }

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

                if building.state == .demolishing {
                    let progress = Int(building.demolitionProgress * 100)
                    message += "\n🏚️ Demolishing: \(progress)%"
                    let currentTime = Date().timeIntervalSince1970
                    if let remainingTime = building.data.getRemainingDemolitionTime(currentTime: currentTime) {
                        message += " (\(formatTime(remainingTime)))"
                    }
                }

                // Open Building action (only for completed, upgrading, or demolishing player-owned buildings)
                if (building.state == .completed || building.state == .upgrading || building.state == .demolishing) && building.owner?.id == player.id {
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
            // Check if there's a building (camp) at this location
            let buildingAtLocation = hexMap.getBuilding(at: coordinate)

            if resourcePoint.resourceType.isHuntable {
                // Huntable animal - show hunt action
                title = "\(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"
                message = "Health: \(Int(resourcePoint.currentHealth))/\(Int(resourcePoint.resourceType.health))"
                message += "\nFood: \(resourcePoint.remainingAmount)"

                actions.append(AlertAction(title: "🏹 Hunt \(resourcePoint.resourceType.displayName)") { [weak self] in
                    self?.showVillagerSelectionForHunt(resourcePoint: resourcePoint)
                })
            } else if resourcePoint.resourceType.isGatherable {
                // Gatherable resource - show gather action
                title = "\(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"

                let gatherers = resourcePoint.getTotalVillagersGathering()
                message = "Remaining: \(resourcePoint.remainingAmount)"
                if gatherers > 0 {
                    message += "\n👷 \(gatherers) villager(s) gathering"
                }

                // Check if camp is required
                if resourcePoint.resourceType.requiresCamp {
                    // Check if camp coverage exists (adjacent OR via roads)
                    if hexMap.hasExtendedCampCoverage(at: coordinate, forResourceType: resourcePoint.resourceType) {
                        // Camp in range - can gather
                        if resourcePoint.getRemainingCapacity() > 0 {
                            let actionVerb = resourcePoint.resourceType == .farmland ? "Work" : "Gather"
                            actions.append(AlertAction(title: "⛏️ \(actionVerb) \(resourcePoint.resourceType.displayName)") { [weak self] in
                                self?.showVillagerSelectionForGathering(resourcePoint: resourcePoint)
                            })
                        } else {
                            message += "\n\n⚠️ Max villagers reached (\(ResourcePointNode.maxVillagersPerTile))"
                        }
                    } else {
                        // No camp in range - show what's needed
                        let campName = resourcePoint.resourceType == .trees ? "Lumber Camp" : "Mining Camp"
                        message += "\n\n⚠️ Build a \(campName) adjacent or connect with roads"
                    }
                } else {
                    // No camp required (berries, carcasses, farmland)
                    if resourcePoint.getRemainingCapacity() > 0 {
                        let actionVerb = resourcePoint.resourceType == .farmland ? "Work" : "Gather"
                        actions.append(AlertAction(title: "⛏️ \(actionVerb) \(resourcePoint.resourceType.displayName)") { [weak self] in
                            self?.showVillagerSelectionForGathering(resourcePoint: resourcePoint)
                        })
                    } else {
                        message += "\n\n⚠️ Max villagers reached (\(ResourcePointNode.maxVillagersPerTile))"
                    }
                }
            }

            // If there's also a building here (camp), add option to view it
            if let building = buildingAtLocation, building.owner?.id == player.id {
                if building.state == .completed || building.state == .upgrading {
                    actions.append(AlertAction(title: "🏗️ Open \(building.buildingType.displayName)") { [weak self] in
                        self?.presentBuildingDetail(for: building)
                    })
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
        
        // -------------------------
        // MARK: - Attack Option (Enemy Entities)
        // -------------------------
        let enemyEntities = visibleEntities.filter { entity in
            guard entity.entity.owner != nil else { return false }
            let diplomacyStatus = player.getDiplomacyStatus(with: entity.entity.owner)
            return diplomacyStatus == .enemy
        }

        if !enemyEntities.isEmpty {
            // Check if player has armies that can attack
            let playerArmies = player.armies.filter { $0.getTotalUnits() > 0 }
            if !playerArmies.isEmpty {
                actions.append(AlertAction(title: "⚔️ Attack", style: .destructive) { [weak self] in
                    self?.showAttackerSelectionForTile(enemies: enemyEntities, at: coordinate)
                })
            }
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
                    case .upgrading:
                        buttonTitle += " ⬆️"
                    case .demolishing:
                        buttonTitle += " 🏚️"
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
        // MARK: - Build Here Option
        // -------------------------
        // Show build option if tile is empty and buildable (no building, walkable terrain)
        if visibility == .visible {
            let existingBuilding = hexMap.getBuilding(at: coordinate)
            let canBuildHere = hexMap.isWalkable(coordinate) && (existingBuilding == nil || existingBuilding?.buildingType.isRoad == true)

            if canBuildHere {
                actions.append(AlertAction(title: "🏗️ Build Here", style: .default) { [weak self] in
                    self?.showBuildingMenuWithVillagerSelection(at: coordinate)
                })
            }
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

        // For armies, show the detail screen directly
        if entity.entityType == .army,
           let army = entity.armyReference {
            presentArmyDetail(for: army, entityNode: entity)
            return
        }

        var actions: [AlertAction] = []

        // Move action
        actions.append(AlertAction(title: "🚶 Move") { [weak self] in
            self?.gameScene?.selectEntity(entity)
            vc.showAlert(title: "Select Destination", message: "Tap a tile to move this entity.")
        })

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

    // MARK: - Army Detail

    func presentArmyDetail(for army: Army, entityNode: EntityNode) {
        guard let vc = viewController as? GameViewController,
              let player = player,
              let hexMap = hexMap,
              let gameScene = gameScene else { return }

        let armyDetailVC = ArmyDetailViewController()
        armyDetailVC.army = army
        armyDetailVC.player = player
        armyDetailVC.hexMap = hexMap
        armyDetailVC.gameScene = gameScene
        armyDetailVC.modalPresentationStyle = .pageSheet

        if let sheet = armyDetailVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        vc.present(armyDetailVC, animated: true)
    }
    
    // MARK: - Move Selection

    func showMoveSelectionMenu(to coordinate: HexCoordinate, from entities: [EntityNode]) {
        guard let player = player,
              let vc = viewController,
              let hexMap = hexMap,
              let gameScene = gameScene else { return }

        // Filter entities:
        // - Must be owned by player
        // - Must not be currently moving
        // - Armies: exclude only if isInCombat == true
        // - Villagers: INCLUDE all (even busy ones - panel shows warning)
        let playerEntities = entities.filter { entity in
            guard entity.entity.owner?.id == player.id else { return false }
            guard !entity.isMoving else { return false }

            // If it's an army, must not be in active combat
            if let army = entity.armyReference {
                guard !GameEngine.shared.combatEngine.isInCombat(armyID: army.id) else { return false }
            }

            return true
        }

        guard !playerEntities.isEmpty else {
            vc.showAlert(title: "No Units Available", message: "You don't have any units that can move.")
            return
        }

        // Sort entities by distance to destination
        let sortedEntities = playerEntities.sorted { e1, e2 in
            e1.coordinate.distance(to: coordinate) < e2.coordinate.distance(to: coordinate)
        }

        // Present the MoveEntityPanelViewController
        let panelVC = MoveEntityPanelViewController()
        panelVC.destinationCoordinate = coordinate
        panelVC.availableEntities = sortedEntities
        panelVC.hexMap = hexMap
        panelVC.gameScene = gameScene
        panelVC.player = player
        panelVC.modalPresentationStyle = .overFullScreen
        panelVC.modalTransitionStyle = .crossDissolve

        panelVC.onConfirm = { [weak self] selectedEntity in
            self?.executeMoveCommand(entity: selectedEntity, to: coordinate)
        }

        panelVC.onCancel = { [weak self] in
            self?.delegate?.deselectAll()
        }

        vc.present(panelVC, animated: false)
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

            case .demolishing(let building):
                message += "\n\n🏚️ Demolishing: \(building.buildingType.displayName)"

                actions.append(AlertAction(title: "🛑 Cancel Demolition", style: .destructive) { [weak self] in
                    self?.executeCancelDemolitionCommand(building: building)
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
                    // ✅ FIX: Use "Work" for farms, "Gather" for other resources
                    let actionVerb = resourcePoint.resourceType == .farmland ? "Work" : "Gather"
                    
                    actions.append(AlertAction(title: "\(actionVerb) \(resourcePoint.resourceType.displayName)") { [weak self] in
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
              let vc = viewController,
              let gameScene = gameScene else { return }

        let cityCenterLevel = player.getCityCenterLevel()
        var actions: [AlertAction] = []

        // Get the villager group for the builder
        let villagers = (villagerGroup?.entity as? VillagerGroup)

        for type in BuildingType.allCases {
            // Skip City Center - players shouldn't build additional ones
            if type == .cityCenter { continue }

            // Check City Center level requirement
            let requiredCCLevel = type.requiredCityCenterLevel
            let meetsRequirement = cityCenterLevel >= requiredCCLevel

            // Skip locked buildings entirely instead of showing them
            guard meetsRequirement else { continue }

            // Check if player can afford the building
            let canAfford = player.canAfford(type)

            // Build cost string with affordability indicators
            var costString = ""
            for (resourceType, amount) in type.buildCost {
                let hasEnough = player.hasResource(resourceType, amount: amount)
                let checkmark = hasEnough ? "✓" : "✗"
                costString += "\(resourceType.icon)\(amount)\(checkmark) "
            }

            if canAfford {
                let title = "\(type.icon) \(type.displayName) - \(costString)"
                actions.append(AlertAction(title: title) { [weak self] in
                    // Enter building placement mode to show valid locations on map
                    self?.enterBuildingPlacementMode(buildingType: type, villagerGroup: villagers, entityNode: villagerGroup)
                })
            } else {
                // Show building but indicate it can't be afforded
                actions.append(AlertAction(title: "💰 \(type.displayName) - \(costString)", handler: nil))
            }
        }

        // Show message if no buildings are available
        let message: String
        if actions.isEmpty {
            message = "No buildings available at City Center Level \(cityCenterLevel).\nUpgrade your City Center to unlock more buildings."
        } else {
            message = "Choose a building type, then tap a highlighted location on the map.\n⭐ City Center: Lv.\(cityCenterLevel)"
        }

        vc.showActionSheet(
            title: "🏗️ Select Building",
            message: message,
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }

    /// Enters building placement mode - highlights valid locations on the map
    private func enterBuildingPlacementMode(buildingType: BuildingType, villagerGroup: VillagerGroup?, entityNode: EntityNode?) {
        guard let gameScene = gameScene,
              let vc = viewController else { return }

        // Set up the callback for when a location is selected
        gameScene.onBuildingPlacementSelected = { [weak self] selectedCoordinate in
            self?.handleBuildingPlacementSelection(
                buildingType: buildingType,
                coordinate: selectedCoordinate,
                villagerGroup: villagerGroup,
                entityNode: entityNode
            )
        }

        // Enter placement mode on the game scene
        gameScene.enterBuildingPlacementMode(buildingType: buildingType, villagerGroup: villagerGroup)

        // Show instruction banner
        vc.showTemporaryMessage("Tap a highlighted tile to place \(buildingType.displayName)")

        // Dismiss any current selection
        delegate?.deselectAll()
    }

    /// Handles the selection of a building placement location
    private func handleBuildingPlacementSelection(buildingType: BuildingType, coordinate: HexCoordinate, villagerGroup: VillagerGroup?, entityNode: EntityNode?) {
        guard let hexMap = hexMap else { return }

        // Check if there's a resource that will be removed
        if let resource = hexMap.getResourcePoint(at: coordinate) {
            if buildingType != .miningCamp && buildingType != .lumberCamp {
                // Show warning for other building types
                showBuildingConfirmationWithResourceWarning(
                    buildingType: buildingType,
                    coordinate: coordinate,
                    resource: resource,
                    villagerGroup: entityNode
                )
                return
            }
        }

        // For multi-tile buildings, use interactive rotation preview mode
        if buildingType.requiresRotation {
            enterRotationPreviewModeForBuilding(buildingType: buildingType, at: coordinate, villagerGroup: villagerGroup, entityNode: entityNode)
        } else {
            // Execute the build command
            executeBuildCommand(buildingType: buildingType, at: coordinate, builder: entityNode)
        }
    }

    /// Enters rotation preview mode for multi-tile buildings with interactive on-map preview
    private func enterRotationPreviewModeForBuilding(buildingType: BuildingType, at coordinate: HexCoordinate, villagerGroup: VillagerGroup?, entityNode: EntityNode?) {
        guard let gameScene = gameScene else { return }

        // Set up the callback for when rotation is confirmed
        gameScene.onRotationConfirmed = { [weak self] anchor, rotation in
            // Show villager selection after rotation is confirmed
            self?.showIdleVillagerSelectionForBuildingWithRotation(
                buildingType: buildingType,
                at: anchor,
                rotation: rotation
            )
        }

        // Enter rotation preview mode on the game scene
        gameScene.enterRotationPreviewMode(buildingType: buildingType, anchor: coordinate)
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

    // MARK: - Building Menu with Villager Selection

    /// Shows building options first, then lets user select an idle villager group
    func showBuildingMenuWithVillagerSelection(at coordinate: HexCoordinate) {
        guard let player = player,
              let hexMap = hexMap,
              let vc = viewController else { return }

        let cityCenterLevel = player.getCityCenterLevel()
        var actions: [AlertAction] = []

        for type in BuildingType.allCases {
            // Skip City Center
            if type == .cityCenter { continue }

            // Check City Center level requirement
            let requiredCCLevel = type.requiredCityCenterLevel
            guard cityCenterLevel >= requiredCCLevel else { continue }

            // Check basic placement
            // For multi-tile buildings, check if ANY rotation (0-5) allows valid placement
            let canPlace: Bool
            if type.requiresRotation {
                canPlace = (0..<6).contains { rotation in
                    hexMap.canPlaceBuilding(at: coordinate, buildingType: type, rotation: rotation)
                }
            } else {
                canPlace = hexMap.canPlaceBuilding(at: coordinate, buildingType: type)
            }

            // Build cost string
            var costString = ""
            for (resourceType, amount) in type.buildCost {
                costString += "\(resourceType.icon)\(amount) "
            }

            if canPlace {
                let title = "\(type.icon) \(type.displayName) - \(costString)"
                actions.append(AlertAction(title: title) { [weak self] in
                    // Check if there's a resource that will be removed
                    if let resource = hexMap.getResourcePoint(at: coordinate) {
                        if type != .miningCamp && type != .lumberCamp && !type.isRoad {
                            // Show warning then proceed to villager selection
                            self?.showBuildingConfirmationWithResourceWarningThenSelectVillager(
                                buildingType: type,
                                coordinate: coordinate,
                                resource: resource
                            )
                            return
                        }
                    }

                    // Show idle villager selection
                    self?.showIdleVillagerSelectionForBuilding(buildingType: type, at: coordinate)
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

        let message: String
        if actions.isEmpty {
            message = "No buildings available at City Center Level \(cityCenterLevel).\nUpgrade your City Center to unlock more buildings."
        } else {
            message = "Choose a building to construct at (\(coordinate.q), \(coordinate.r))\n⭐ City Center: Lv.\(cityCenterLevel)"
        }

        vc.showActionSheet(
            title: "🏗️ Select Building",
            message: message,
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }

    /// Shows resource warning, then proceeds to villager selection
    func showBuildingConfirmationWithResourceWarningThenSelectVillager(
        buildingType: BuildingType,
        coordinate: HexCoordinate,
        resource: ResourcePointNode
    ) {
        guard let vc = viewController else { return }

        let alert = UIAlertController(
            title: "⚠️ Resource Will Be Removed",
            message: "Building \(buildingType.displayName) here will permanently remove the \(resource.resourceType.displayName) (\(resource.remainingAmount) remaining).\n\nAre you sure you want to continue?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Build Anyway", style: .destructive) { [weak self] _ in
            self?.showIdleVillagerSelectionForBuilding(buildingType: buildingType, at: coordinate)
        })

        vc.present(alert, animated: true)
    }

    /// Shows a slide-out panel for selecting villager groups to build
    func showIdleVillagerSelectionForBuilding(buildingType: BuildingType, at coordinate: HexCoordinate, rotation: Int = 0) {
        guard let player = player,
              let hexMap = hexMap,
              let vc = viewController,
              let gameScene = gameScene else { return }

        // For multi-tile buildings, use rotation preview mode instead of text menu
        if buildingType.requiresRotation && rotation == 0 {
            enterRotationPreviewModeForBuilding(buildingType: buildingType, at: coordinate, villagerGroup: nil, entityNode: nil)
            return
        }

        // Find ALL villager groups owned by player (not just idle - panel shows warnings)
        let allVillagerGroups = hexMap.entities.filter { entity in
            guard entity.entity.owner?.id == player.id,
                  entity.entityType == .villagerGroup,
                  entity.entity is VillagerGroup else {
                return false
            }
            return true
        }

        if allVillagerGroups.isEmpty {
            vc.showAlert(
                title: "No Villagers",
                message: "You don't have any villager groups to construct buildings."
            )
            return
        }

        // Sort by distance to build site
        let sortedVillagers = allVillagerGroups.sorted { e1, e2 in
            e1.coordinate.distance(to: coordinate) < e2.coordinate.distance(to: coordinate)
        }

        // Present the BuildEntityPanelViewController
        let panelVC = BuildEntityPanelViewController()
        panelVC.buildingType = buildingType
        panelVC.buildCoordinate = coordinate
        panelVC.rotation = rotation
        panelVC.availableVillagers = sortedVillagers
        panelVC.hexMap = hexMap
        panelVC.gameScene = gameScene
        panelVC.player = player
        panelVC.modalPresentationStyle = .overFullScreen
        panelVC.modalTransitionStyle = .crossDissolve

        panelVC.onConfirm = { [weak self] selectedEntity in
            self?.assignVillagerToBuild(
                villagerEntity: selectedEntity,
                buildingType: buildingType,
                at: coordinate,
                rotation: rotation
            )
        }

        panelVC.onCancel = { [weak self] in
            self?.delegate?.deselectAll()
        }

        vc.present(panelVC, animated: false)
    }

    /// Shows rotation options for multi-tile buildings (DEPRECATED - use interactive rotation preview instead)
    /// Kept for backwards compatibility, but enterRotationPreviewModeForBuilding is preferred
    func showRotationSelectionForBuilding(buildingType: BuildingType, at coordinate: HexCoordinate) {
        guard let hexMap = hexMap,
              let vc = viewController else { return }

        var actions: [AlertAction] = []
        let directions = ["East ➡️", "Northeast ↗️", "Northwest ↖️", "West ⬅️", "Southwest ↙️", "Southeast ↘️"]

        for rotation in 0..<6 {
            // Check if this rotation is valid (all tiles can be placed)
            let canPlace = hexMap.canPlaceBuilding(at: coordinate, buildingType: buildingType, rotation: rotation)

            if canPlace {
                let title = "🔄 \(directions[rotation])"
                actions.append(AlertAction(title: title) { [weak self] in
                    self?.showIdleVillagerSelectionForBuildingWithRotation(
                        buildingType: buildingType,
                        at: coordinate,
                        rotation: rotation
                    )
                })
            } else {
                // Show as disabled with reason
                actions.append(AlertAction(title: "❌ \(directions[rotation]) (blocked)", handler: nil))
            }
        }

        // Get the tiles that would be occupied for visual reference
        let message = """
        \(buildingType.displayName) is a 3-tile building.
        Choose which direction it should face.

        The building will occupy:
        • Anchor tile at (\(coordinate.q), \(coordinate.r))
        • Two adjacent tiles based on rotation
        """

        vc.showActionSheet(
            title: "🔄 Select Rotation",
            message: message,
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }

    /// Shows villager selection after rotation has been chosen (uses slide-out panel)
    func showIdleVillagerSelectionForBuildingWithRotation(buildingType: BuildingType, at coordinate: HexCoordinate, rotation: Int) {
        // Delegate to the main method which now uses the panel
        showIdleVillagerSelectionForBuilding(buildingType: buildingType, at: coordinate, rotation: rotation)
    }

    /// Assigns a villager to build at the target location
    /// Villager will move to the tile first, then start building
    func assignVillagerToBuild(villagerEntity: EntityNode, buildingType: BuildingType, at coordinate: HexCoordinate, rotation: Int = 0) {
        guard let player = player,
              let hexMap = hexMap else { return }

        // Check if villager is already at the location
        if villagerEntity.coordinate == coordinate {
            // Already there, just execute the build command
            executeBuildCommand(buildingType: buildingType, at: coordinate, builder: villagerEntity, rotation: rotation)
        } else {
            // Need to move to the location first
            // Find a path to the target or adjacent tile
            var targetCoord = coordinate

            // If the coordinate has a building being placed, find adjacent walkable tile
            if hexMap.getBuilding(at: coordinate) != nil && !hexMap.getBuilding(at: coordinate)!.buildingType.isRoad {
                if let adjacent = hexMap.findNearestWalkable(to: coordinate, maxDistance: 2) {
                    targetCoord = adjacent
                }
            }

            // Execute build command first (creates the building in constructing state)
            executeBuildCommand(buildingType: buildingType, at: coordinate, builder: villagerEntity, rotation: rotation)

            // The BuildCommand will assign the villager to the building task and move them
        }

        delegate?.deselectAll()
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
              let vc = viewController,
              let hexMap = hexMap,
              let gameScene = gameScene else { return }

        // Include ALL player villagers (not just idle), sorted by distance
        let allVillagers = player.getVillagerGroups().sorted { v1, v2 in
            v1.coordinate.distance(to: resourcePoint.coordinate) < v2.coordinate.distance(to: resourcePoint.coordinate)
        }

        guard !allVillagers.isEmpty else {
            vc.showAlert(title: "No Villagers", message: "You don't have any villager groups.")
            return
        }

        // Present the GatherEntityPanelViewController
        let panelVC = GatherEntityPanelViewController()
        panelVC.resourcePoint = resourcePoint
        panelVC.availableVillagers = allVillagers
        panelVC.mode = .gather
        panelVC.hexMap = hexMap
        panelVC.gameScene = gameScene
        panelVC.player = player
        panelVC.modalPresentationStyle = .overFullScreen
        panelVC.modalTransitionStyle = .crossDissolve

        panelVC.onConfirm = { [weak self] selectedVillagers in
            self?.executeGatherCommand(villagerGroup: selectedVillagers, resourcePoint: resourcePoint)
        }

        panelVC.onCancel = { [weak self] in
            self?.delegate?.deselectAll()
        }

        vc.present(panelVC, animated: false)
    }
    
    // MARK: - Villager Selection for Hunt

    func showVillagerSelectionForHunt(resourcePoint: ResourcePointNode) {
        guard let player = player,
              let vc = viewController,
              let hexMap = hexMap,
              let gameScene = gameScene else { return }

        // Include ALL player villagers (not just idle), sorted by distance
        let allVillagers = player.getVillagerGroups().sorted { v1, v2 in
            v1.coordinate.distance(to: resourcePoint.coordinate) < v2.coordinate.distance(to: resourcePoint.coordinate)
        }

        guard !allVillagers.isEmpty else {
            vc.showAlert(title: "No Villagers", message: "You don't have any villager groups.")
            return
        }

        // Present the GatherEntityPanelViewController in hunt mode
        let panelVC = GatherEntityPanelViewController()
        panelVC.resourcePoint = resourcePoint
        panelVC.availableVillagers = allVillagers
        panelVC.mode = .hunt
        panelVC.hexMap = hexMap
        panelVC.gameScene = gameScene
        panelVC.player = player
        panelVC.modalPresentationStyle = .overFullScreen
        panelVC.modalTransitionStyle = .crossDissolve

        panelVC.onConfirm = { [weak self] selectedVillagers in
            self?.startHunt(villagerGroup: selectedVillagers, target: resourcePoint)
        }

        panelVC.onCancel = { [weak self] in
            self?.delegate?.deselectAll()
        }

        vc.present(panelVC, animated: false)
    }
    
    // MARK: - Attack Selection

    /// Shows a slide-out panel for selecting player's armies to attack enemies at a tile
    func showAttackerSelectionForTile(enemies: [EntityNode], at coordinate: HexCoordinate) {
        guard let player = player,
              let vc = viewController,
              let hexMap = hexMap,
              let gameScene = gameScene else { return }

        let playerArmies = player.armies.filter { $0.getTotalUnits() > 0 }

        guard !playerArmies.isEmpty else {
            vc.showAlert(
                title: "No Armies",
                message: "You don't have any armies with military units to attack."
            )
            return
        }

        // Sort armies by distance to target
        let sortedArmies = playerArmies.sorted { a1, a2 in
            a1.coordinate.distance(to: coordinate) < a2.coordinate.distance(to: coordinate)
        }

        // Present the AttackEntityPanelViewController
        let panelVC = AttackEntityPanelViewController()
        panelVC.targetCoordinate = coordinate
        panelVC.enemies = enemies
        panelVC.availableArmies = sortedArmies
        panelVC.hexMap = hexMap
        panelVC.gameScene = gameScene
        panelVC.player = player
        panelVC.modalPresentationStyle = .overFullScreen
        panelVC.modalTransitionStyle = .crossDissolve

        panelVC.onConfirm = { [weak self] selectedArmy in
            self?.executeAttackCommand(attacker: selectedArmy, targetCoordinate: coordinate)
        }

        panelVC.onCancel = { [weak self] in
            self?.delegate?.deselectAll()
        }

        vc.present(panelVC, animated: false)
    }

    /// Executes an AttackCommand
    private func executeAttackCommand(attacker: Army, targetCoordinate: HexCoordinate) {
        guard let player = player else { return }

        let command = AttackCommand(
            playerID: player.id,
            attackerEntityID: attacker.id,
            targetCoordinate: targetCoordinate
        )

        let result = CommandExecutor.shared.execute(command)

        if !result.succeeded, let reason = result.failureReason {
            viewController?.showAlert(title: "Cannot Attack", message: reason)
        }

        delegate?.deselectAll()
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
            AlertAction(title: "🏳️ Resign", style: .destructive) {
                gameVC.confirmResign()
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
    private func executeBuildCommand(buildingType: BuildingType, at coordinate: HexCoordinate, builder: EntityNode?, rotation: Int = 0) {
        guard let player = player else { return }

        let command = BuildCommand(
            playerID: player.id,
            buildingType: buildingType,
            coordinate: coordinate,
            builderEntityID: builder?.entity.id,
            rotation: rotation
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

    /// Executes a CancelDemolitionCommand
    private func executeCancelDemolitionCommand(building: BuildingNode) {
        guard let player = player else { return }

        let command = CancelDemolitionCommand(
            playerID: player.id,
            buildingID: building.data.id
        )

        let result = CommandExecutor.shared.execute(command)

        if result.succeeded {
            viewController?.showAlert(title: "🚫 Demolition Cancelled", message: "\(building.buildingType.displayName) will no longer be demolished.")
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
            if let resourcesNode = gameScene.childNode(withName: "resourcesNode") {
                if let carcass = hexMap.createCarcass(from: target, scene: resourcesNode) {
                    // Remove the original animal
                    hexMap.removeResourcePoint(target)
                    target.removeFromParent()

                    // Automatically start gathering from the carcass
                    villagerGroup.currentTask = .gatheringResource(carcass)
                    carcass.startGathering(by: villagerGroup)
                    entityNode.isMoving = true

                    // Update collection rate for the player
                    let rateContribution = 0.2 * Double(villagerGroup.villagerCount)
                    player.increaseCollectionRate(.food, amount: rateContribution)

                    // If engine is enabled, also register with ResourceEngine
                    if gameScene.isEngineEnabled {
                        // Create resource point data in engine state
                        if let engineState = gameScene.engineGameState {
                            // Add carcass to engine state
                            let carcassData = ResourcePointData(
                                coordinate: carcass.coordinate,
                                resourceType: ResourcePointTypeData(rawValue: carcass.resourceType.rawValue) ?? .deerCarcass
                            )
                            carcassData.setRemainingAmount(carcass.remainingAmount)
                            engineState.addResourcePoint(carcassData)

                            // Ensure villager group exists in engine state (may have been created after init)
                            if engineState.getVillagerGroup(id: villagerGroup.id) == nil {
                                let groupData = VillagerGroupData(
                                    id: villagerGroup.id,
                                    name: villagerGroup.name,
                                    coordinate: villagerGroup.coordinate,
                                    villagerCount: villagerGroup.villagerCount,
                                    ownerID: player.id
                                )
                                engineState.addVillagerGroup(groupData)
                                print("➕ Added VillagerGroupData to engine for \(villagerGroup.name)")
                            }

                            // Start gathering in engine
                            GameEngine.shared.resourceEngine.startGathering(
                                villagerGroupID: villagerGroup.id,
                                resourcePointID: carcassData.id
                            )
                        }
                    }

                    var message = "\(villagerGroup.name) killed the \(target.resourceType.displayName)!\n\n🥩 Now gathering from \(carcass.resourceType.displayName) (\(carcass.remainingAmount) food)."

                    if villagersLost > 0 {
                        message += "\n\n⚠️ \(villagersLost) villager(s) were lost in the hunt."
                    }

                    vc.showAlert(title: "🎯 Hunt Successful!", message: message)

                    print("✅ Villagers hunted \(target.resourceType.displayName) - now gathering from carcass")
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
              let player = player,
              let vc = viewController else { return }

        building.buildersAssigned = max(0, building.buildersAssigned - villagerGroup.villagerCount)

        villagerGroup.clearTask()

        if let entityNode = hexMap.entities.first(where: {
            ($0.entity as? VillagerGroup)?.id == villagerGroup.id
        }) {
            entityNode.isMoving = false
        }

        // If no more builders are assigned and building is still under construction, remove it
        if building.buildersAssigned == 0 && building.state == .constructing {
            // Refund the build cost
            for (resourceType, amount) in building.buildingType.buildCost {
                player.addResource(resourceType, amount: amount)
            }

            // Remove the building from the map and player
            hexMap.removeBuilding(building)
            player.removeBuilding(building)
            building.clearTileOverlays()  // Clean up multi-tile overlays
            building.removeFromParent()

            print("✅ Building cancelled and removed, resources refunded")

            vc.showAlert(
                title: "✅ Building Cancelled",
                message: "\(building.buildingType.displayName) construction cancelled. Resources refunded."
            )
        } else {
            print("✅ Cancelled building for \(villagerGroup.name)")

            vc.showAlert(
                title: "✅ Builder Removed",
                message: "\(villagerGroup.name) stopped building \(building.buildingType.displayName)"
            )
        }

        delegate?.updateResourceDisplay()
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

    // MARK: - Resource Overview

    func presentResourceOverview() {
        guard let vc = viewController as? GameViewController,
              let player = player,
              let hexMap = hexMap,
              let gameScene = gameScene else { return }

        let resourceVC = ResourceOverviewViewController()
        resourceVC.player = player
        resourceVC.hexMap = hexMap
        resourceVC.gameScene = gameScene
        resourceVC.gameViewController = vc
        resourceVC.modalPresentationStyle = .pageSheet

        if let sheet = resourceVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        vc.present(resourceVC, animated: true)
    }
}
