// ============================================================================
// FILE: Grow2 iOS/Coordinators/MenuCoordinator+TileMenus.swift
// PURPOSE: Tile tap menus - terrain info, building info, resource info,
//          attack options, build here, and movement
// ============================================================================

import UIKit
import SpriteKit

// MARK: - Tile Action Menus

extension MenuCoordinator {

    func showTileActionMenu(for coordinate: HexCoordinate) {
        guard let player = player,
              let hexMap = hexMap,
              let vc = viewController else { return }

        let visibility = player.getVisibilityLevel(at: coordinate)
        var title = "Tile (\(coordinate.q), \(coordinate.r))"
        var message = ""
        var actions: [AlertAction] = []

        // -------------------------
        // Terrain Info
        // -------------------------
        if let tile = hexMap.getTile(at: coordinate) {
            var terrainInfo = "🗺️ \(tile.terrain.displayName)"
            if tile.elevation > 0 {
                terrainInfo += " (Elevation: \(tile.elevation))"
            }
            message = terrainInfo
        }

        // -------------------------
        // Building Info
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
        // Resource Info
        // -------------------------
        if let resourcePoint = hexMap.getResourcePoint(at: coordinate), (visibility == .visible || visibility == .explored) {
            if resourcePoint.resourceType.isHuntable {
                title = "\(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"
                message = "Health: \(Int(resourcePoint.currentHealth))/\(Int(resourcePoint.resourceType.health))"
                message += "\nFood: \(resourcePoint.remainingAmount)"

                actions.append(AlertAction(title: "🏹 Hunt \(resourcePoint.resourceType.displayName)") { [weak self] in
                    self?.showVillagerSelectionForHunt(resourcePoint: resourcePoint)
                })
            } else if resourcePoint.resourceType.isGatherable {
                title = "\(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"

                let gatherers = resourcePoint.getTotalVillagersGathering()
                message = "Remaining: \(resourcePoint.remainingAmount)"
                if gatherers > 0 {
                    message += "\n👷 \(gatherers) villager(s) gathering"
                }

                if resourcePoint.resourceType.requiresCamp {
                    if hexMap.hasExtendedCampCoverage(at: coordinate, forResourceType: resourcePoint.resourceType) {
                        if resourcePoint.getRemainingCapacity() > 0 {
                            let actionVerb = resourcePoint.resourceType == .farmland ? "Work" : "Gather"
                            actions.append(AlertAction(title: "⛏️ \(actionVerb) \(resourcePoint.resourceType.displayName)") { [weak self] in
                                self?.showVillagerSelectionForGathering(resourcePoint: resourcePoint)
                            })
                        } else {
                            message += "\n\n⚠️ Max villagers reached (\(ResourcePointNode.maxVillagersPerTile))"
                        }
                    } else {
                        let campName = resourcePoint.resourceType == .trees ? "Lumber Camp" : "Mining Camp"
                        message += "\n\n⚠️ Build a \(campName) adjacent or connect with roads"
                    }
                } else {
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
        }

        // -------------------------
        // Entities on Tile
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
        // Attack Option (Enemy Buildings or Entities)
        // -------------------------
        let buildingAtCoordinate = hexMap.getBuilding(at: coordinate)

        if let building = buildingAtCoordinate,
           let buildingOwner = building.owner,
           visibility == .visible {
            let diplomacyStatus = player.getDiplomacyStatus(with: buildingOwner)
            if diplomacyStatus == .enemy && building.state == .completed {
                let playerArmies = player.armies.filter { $0.getTotalUnits() > 0 }
                if !playerArmies.isEmpty {
                    actions.append(AlertAction(title: "⚔️ Attack \(building.buildingType.displayName)", style: .destructive) { [weak self] in
                        self?.showAttackerSelectionForBuilding(building: building, at: coordinate)
                    })
                }
            }
        }

        let enemyEntities = visibleEntities.filter { entity in
            guard entity.entity.owner != nil else { return false }
            let diplomacyStatus = player.getDiplomacyStatus(with: entity.entity.owner)
            return diplomacyStatus == .enemy
        }

        if !enemyEntities.isEmpty {
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

            if let villagers = entity.entity as? VillagerGroup {
                if villagers.owner?.id != player.id {
                    actions.append(AlertAction(title: buttonTitle, style: .destructive) { [weak self] in
                        self?.showAttackerSelectionForTile(enemies: [entity], at: coordinate)
                    })
                } else {
                    actions.append(AlertAction(title: buttonTitle) { [weak self] in
                        switch villagers.currentTask {
                        case .gatheringResource, .hunting:
                            self?.showVillagerOptionsMenu(villagerGroup: villagers, entityNode: entity)
                        default:
                            self?.showVillagerMenu(at: coordinate, villagerGroup: entity)
                        }
                    })
                }
            } else {
                actions.append(AlertAction(title: buttonTitle) { [weak self] in
                    self?.showEntityActionMenu(for: entity, at: coordinate)
                })
            }
        }

        // -------------------------
        // Build Here Option
        // -------------------------
        if visibility == .visible || visibility == .explored {
            let existingBuilding = hexMap.getBuilding(at: coordinate)
            let canBuildHere = hexMap.isWalkable(coordinate) && (existingBuilding == nil || existingBuilding?.buildingType.isRoad == true)

            if canBuildHere {
                actions.append(AlertAction(title: "🏗️ Build Here", style: .default) { [weak self] in
                    self?.showBuildingMenuWithVillagerSelection(at: coordinate)
                })
            }
        }

        // -------------------------
        // Movement Action
        // -------------------------
        if visibility == .visible || visibility == .explored || visibility == .unexplored {
            let hasHostileEntities = entitiesAtTile.contains { entity in
                let diplomacyStatus = player.getDiplomacyStatus(with: entity.entity.owner)
                return diplomacyStatus == .neutral || diplomacyStatus == .enemy
            }

            if !hasHostileEntities {
                let moveTitle = visibility == .unexplored ? "🔭 Scout This Location" : "🚶 Move Unit Here"
                actions.append(AlertAction(title: moveTitle, style: .default) { [weak self] in
                    self?.gameScene?.initiateMove(to: coordinate)
                })
            } else {
                if !message.isEmpty { message += "\n" }
                message += "\n⚠️ Cannot move here - hostile units present"
            }
        }

        // -------------------------
        // Show Menu
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

    // MARK: - Unexplored Tile Menu

    func showUnexploredTileMenu(for coordinate: HexCoordinate) {
        guard let vc = viewController,
              let hexMap = hexMap else { return }

        var title = "Unexplored Area"
        var message = "🌫️ This area has not been explored.\n\nSend a unit to reveal what lies here."

        if let tile = hexMap.getTile(at: coordinate) {
            message = "🗺️ \(tile.terrain.displayName)\n\n🌫️ This area has not been explored.\n\nSend a unit to reveal what lies here."
        }

        var actions: [AlertAction] = []

        actions.append(AlertAction(title: "🔭 Scout This Location", style: .default) { [weak self] in
            self?.gameScene?.initiateMove(to: coordinate)
        })

        vc.showActionSheet(
            title: title,
            message: message,
            actions: actions,
            onCancel: { [weak self] in
                self?.delegate?.deselectAll()
            }
        )
    }
}
