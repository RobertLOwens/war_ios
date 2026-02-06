// ============================================================================
// FILE: Grow2 iOS/Coordinators/MenuCoordinator+EntityMenus.swift
// PURPOSE: Entity selection menus - army detail, move selection,
//          villager menus, and entity action routing
// ============================================================================

import UIKit
import SpriteKit

// MARK: - Entity Action Menus

extension MenuCoordinator {

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

        let playerEntities = entities.filter { entity in
            guard entity.entity.owner?.id == player.id else { return false }
            guard !entity.isMoving else { return false }

            if let army = entity.armyReference {
                guard !GameEngine.shared.combatEngine.isInCombat(armyID: army.id) else { return false }
            }

            return true
        }

        guard !playerEntities.isEmpty else {
            vc.showAlert(title: "No Units Available", message: "You don't have any units that can move.")
            return
        }

        let sortedEntities = playerEntities.sorted { e1, e2 in
            e1.coordinate.distance(to: coordinate) < e2.coordinate.distance(to: coordinate)
        }

        let visibility = player.getVisibilityLevel(at: coordinate)
        let isUnexplored = (visibility == .unexplored)

        let panelVC = MoveEntityPanelViewController()
        panelVC.destinationCoordinate = coordinate
        panelVC.availableEntities = sortedEntities
        panelVC.isDestinationUnexplored = isUnexplored
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
            actions.append(AlertAction(title: "🚶 Move") { [weak self] in
                self?.gameScene?.initiateMove(to: coordinate)
            })

            let buildingExists = hexMap.getBuilding(at: coordinate) != nil
            if !buildingExists {
                actions.append(AlertAction(title: "🏗️ Build") { [weak self] in
                    self?.showBuildingMenu(at: coordinate, villagerGroup: villagerGroup)
                })
            }

            if let building = hexMap.getBuilding(at: coordinate),
               building.owner?.id == player.id,
               building.canUpgrade {
                actions.append(AlertAction(title: "⬆️ Upgrade \(building.buildingType.displayName)") { [weak self] in
                    self?.showUpgradeConfirmation(for: building, villagerEntity: villagerGroup)
                })
            }

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

            if villagers.villagerCount > 1 {
                actions.append(AlertAction(title: "✂️ Split Group") { [weak self] in
                    self?.delegate?.showSplitVillagerMenu(villagerGroup: villagers, entityNode: villagerGroup)
                })
            }

            if let resourcePoint = hexMap.getResourcePoint(at: coordinate) {
                if resourcePoint.resourceType.isGatherable && !resourcePoint.isDepleted() {
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
}
