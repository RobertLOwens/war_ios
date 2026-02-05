// ============================================================================
// FILE: Grow2 Shared/Engine/ConstructionEngine.swift
// PURPOSE: Handles building construction and upgrades - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Construction Engine

/// Handles all building construction, upgrade, and demolition logic
class ConstructionEngine {

    // MARK: - State
    private weak var gameState: GameState?

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
    }

    // MARK: - Update Loop

    func update(currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []

        // Process all buildings
        for building in state.buildings.values {
            // Construction updates
            if building.state == .constructing {
                let constructionChanges = updateConstruction(building, currentTime: currentTime)
                changes.append(contentsOf: constructionChanges)
            }

            // Upgrade updates
            if building.state == .upgrading {
                let upgradeChanges = updateUpgrade(building, currentTime: currentTime)
                changes.append(contentsOf: upgradeChanges)
            }

            // Demolition updates
            if building.state == .demolishing {
                let demolitionChanges = updateDemolition(building, currentTime: currentTime, state: state)
                changes.append(contentsOf: demolitionChanges)
            }
        }

        return changes
    }

    // MARK: - Construction

    private func updateConstruction(_ building: BuildingData, currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }
        var changes: [StateChange] = []

        let previousProgress = building.constructionProgress
        let completed = building.updateConstruction(currentTime: currentTime)

        // Only emit progress change if it changed significantly
        if abs(building.constructionProgress - previousProgress) > 0.01 {
            changes.append(.buildingConstructionProgress(
                buildingID: building.id,
                progress: building.constructionProgress
            ))
        }

        if completed {
            // Find and release any villagers assigned to build this building
            let builderChanges = releaseBuilders(forBuildingID: building.id, state: state)
            changes.append(contentsOf: builderChanges)

            changes.append(.buildingCompleted(buildingID: building.id))
        }

        return changes
    }

    /// Finds villagers assigned to a building and clears their task, emitting state changes
    private func releaseBuilders(forBuildingID buildingID: UUID, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []

        for group in state.villagerGroups.values {
            if case .building(let assignedBuildingID) = group.currentTask,
               assignedBuildingID == buildingID {
                // Clear the villager's task
                group.clearTask()

                // Emit state change for visual layer sync
                changes.append(.villagerGroupTaskChanged(
                    groupID: group.id,
                    task: "idle",
                    targetCoordinate: nil
                ))
            }
        }

        return changes
    }

    // MARK: - Upgrades

    private func updateUpgrade(_ building: BuildingData, currentTime: TimeInterval) -> [StateChange] {
        var changes: [StateChange] = []

        let previousProgress = building.upgradeProgress
        let completed = building.updateUpgrade(currentTime: currentTime)

        // Only emit progress change if it changed significantly
        if abs(building.upgradeProgress - previousProgress) > 0.01 {
            changes.append(.buildingUpgradeProgress(
                buildingID: building.id,
                progress: building.upgradeProgress
            ))
        }

        if completed {
            changes.append(.buildingUpgradeCompleted(
                buildingID: building.id,
                newLevel: building.level
            ))
        }

        return changes
    }

    // MARK: - Demolition

    private func updateDemolition(_ building: BuildingData, currentTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []

        let previousProgress = building.demolitionProgress
        let completed = building.updateDemolition(currentTime: currentTime)

        // Only emit progress change if it changed significantly
        if abs(building.demolitionProgress - previousProgress) > 0.01 {
            changes.append(.buildingDemolitionProgress(
                buildingID: building.id,
                progress: building.demolitionProgress
            ))
        }

        if completed {
            let coordinate = building.coordinate

            // Refund resources to owner
            if let ownerID = building.ownerID, let player = state.getPlayer(id: ownerID) {
                let refund = building.getDemolitionRefund()
                for (resourceType, amount) in refund {
                    let dataType = ResourceTypeData(rawValue: resourceType.rawValue)!
                    let capacity = state.getStorageCapacity(forPlayer: ownerID, resourceType: dataType)
                    _ = player.addResource(dataType, amount: amount, storageCapacity: capacity)
                }
            }

            // Remove building from state
            state.removeBuilding(id: building.id)

            changes.append(.buildingDemolished(
                buildingID: building.id,
                coordinate: coordinate
            ))
        }

        return changes
    }

    // MARK: - Building Placement

    func canPlaceBuilding(type: BuildingType, at coordinate: HexCoordinate, rotation: Int = 0, forPlayer playerID: UUID) -> (valid: Bool, reason: String?) {
        guard let state = gameState,
              let player = state.getPlayer(id: playerID) else {
            return (false, "Invalid player")
        }

        // Check city center level requirements
        let ccLevel = state.getCityCenterLevel(forPlayer: playerID)
        if type.requiredCityCenterLevel > ccLevel {
            return (false, "Requires City Center Level \(type.requiredCityCenterLevel)")
        }

        // Check warehouse limits
        if type == .warehouse {
            let maxAllowed = BuildingType.maxWarehousesAllowed(forCityCenterLevel: ccLevel)
            let currentCount = state.getBuildingsForPlayer(id: playerID).filter { $0.buildingType == .warehouse }.count
            if currentCount >= maxAllowed {
                return (false, "Maximum warehouses reached for City Center level")
            }
        }

        // Check resources
        if !player.canAfford(convertBuildCost(type.buildCost)) {
            return (false, "Insufficient resources")
        }

        // Get all coordinates this building would occupy
        let occupiedCoords = type.getOccupiedCoordinates(anchor: coordinate, rotation: rotation)

        // Check all tiles
        for coord in occupiedCoords {
            // Check map bounds
            guard state.mapData.isValidCoordinate(coord) else {
                return (false, "Outside map bounds")
            }

            // Check walkable terrain
            guard state.mapData.isWalkable(coord) else {
                return (false, "Cannot build on this terrain")
            }

            // Check for existing buildings
            if state.mapData.getBuildingID(at: coord) != nil {
                return (false, "Space already occupied")
            }
        }

        // Special checks for camps
        if type == .miningCamp {
            if let resource = state.getResourcePoint(at: coordinate) {
                if resource.resourceType != .oreMine && resource.resourceType != .stoneQuarry {
                    return (false, "Mining camp requires ore or stone resource")
                }
            } else {
                return (false, "Mining camp requires ore or stone resource")
            }
        }

        if type == .lumberCamp {
            if let resource = state.getResourcePoint(at: coordinate) {
                if resource.resourceType != .trees {
                    return (false, "Lumber camp requires trees")
                }
            } else {
                return (false, "Lumber camp requires trees")
            }
        }

        return (true, nil)
    }

    func placeBuilding(type: BuildingType, at coordinate: HexCoordinate, rotation: Int = 0, forPlayer playerID: UUID) -> (building: BuildingData?, changes: [StateChange]) {
        guard let state = gameState,
              let player = state.getPlayer(id: playerID) else {
            return (nil, [])
        }

        // Validate placement
        let validation = canPlaceBuilding(type: type, at: coordinate, rotation: rotation, forPlayer: playerID)
        guard validation.valid else {
            return (nil, [])
        }

        var changes: [StateChange] = []

        // Deduct resources
        let cost = convertBuildCost(type.buildCost)
        for (resourceType, amount) in cost {
            _ = player.removeResource(resourceType, amount: amount)
        }

        // Create building
        let building = BuildingData(buildingType: type, coordinate: coordinate, ownerID: playerID, rotation: rotation)

        // Add to game state
        state.addBuilding(building)

        // Start construction
        building.startConstruction(builders: 1)

        changes.append(.buildingPlaced(
            buildingID: building.id,
            buildingType: type.rawValue,
            coordinate: coordinate,
            ownerID: playerID,
            rotation: rotation
        ))

        changes.append(.buildingConstructionStarted(buildingID: building.id))

        // Remove any resource point at this location (except for camps)
        if type != .miningCamp && type != .lumberCamp {
            let occupiedCoords = type.getOccupiedCoordinates(anchor: coordinate, rotation: rotation)
            for coord in occupiedCoords {
                if let resourceID = state.mapData.getResourcePointID(at: coord) {
                    state.removeResourcePoint(id: resourceID)
                }
            }
        }

        return (building, changes)
    }

    // MARK: - Upgrades

    func canStartUpgrade(buildingID: UUID, forPlayer playerID: UUID) -> (valid: Bool, reason: String?) {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID),
              let player = state.getPlayer(id: playerID) else {
            return (false, "Building not found")
        }

        guard building.ownerID == playerID else {
            return (false, "Not your building")
        }

        guard building.canUpgrade else {
            return (false, "Building cannot be upgraded")
        }

        guard let upgradeCost = building.getUpgradeCost() else {
            return (false, "No upgrade available")
        }

        if !player.canAfford(convertBuildCost(upgradeCost)) {
            return (false, "Insufficient resources")
        }

        return (true, nil)
    }

    func startUpgrade(buildingID: UUID, forPlayer playerID: UUID) -> [StateChange] {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID),
              let player = state.getPlayer(id: playerID) else {
            return []
        }

        let validation = canStartUpgrade(buildingID: buildingID, forPlayer: playerID)
        guard validation.valid else { return [] }

        // Deduct resources
        if let upgradeCost = building.getUpgradeCost() {
            for (resourceType, amount) in upgradeCost {
                let dataType = ResourceTypeData(rawValue: resourceType.rawValue)!
                _ = player.removeResource(dataType, amount: amount)
            }
        }

        // Start upgrade
        let targetLevel = building.level + 1
        building.startUpgrade()

        return [.buildingUpgradeStarted(buildingID: buildingID, toLevel: targetLevel)]
    }

    // MARK: - Demolition

    func canStartDemolition(buildingID: UUID, forPlayer playerID: UUID) -> (valid: Bool, reason: String?) {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID) else {
            return (false, "Building not found")
        }

        guard building.ownerID == playerID else {
            return (false, "Not your building")
        }

        guard building.canDemolish else {
            return (false, "Building cannot be demolished")
        }

        return (true, nil)
    }

    func startDemolition(buildingID: UUID, forPlayer playerID: UUID, demolishers: Int = 1) -> [StateChange] {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID) else {
            return []
        }

        let validation = canStartDemolition(buildingID: buildingID, forPlayer: playerID)
        guard validation.valid else { return [] }

        building.startDemolition(demolishers: demolishers)

        return [.buildingDemolitionStarted(buildingID: buildingID)]
    }

    // MARK: - Helpers

    private func convertBuildCost(_ cost: [ResourceType: Int]) -> [ResourceTypeData: Int] {
        var converted: [ResourceTypeData: Int] = [:]
        for (key, value) in cost {
            if let dataType = ResourceTypeData(rawValue: key.rawValue) {
                converted[dataType] = value
            }
        }
        return converted
    }
}
