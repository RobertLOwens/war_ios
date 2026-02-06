// ============================================================================
// FILE: Grow2 Shared/Engine/TrainingEngine.swift
// PURPOSE: Handles unit training logic - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Training Engine

/// Handles all unit training logic for military units and villagers
class TrainingEngine {

    // MARK: - State
    private weak var gameState: GameState?

    // MARK: - Constants
    private let villagerTrainingTime = GameConfig.Training.villagerTrainingTime

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
    }

    // MARK: - Update Loop

    func update(currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []

        // Process training for all buildings
        for building in state.buildings.values {
            guard building.isOperational else { continue }

            // Military training
            if !building.trainingQueue.isEmpty {
                let militaryChanges = updateMilitaryTraining(building, currentTime: currentTime)
                changes.append(contentsOf: militaryChanges)
            }

            // Villager training
            if !building.villagerTrainingQueue.isEmpty {
                let villagerChanges = updateVillagerTraining(building, currentTime: currentTime, state: state)
                changes.append(contentsOf: villagerChanges)
            }
        }

        return changes
    }

    // MARK: - Military Training

    private func updateMilitaryTraining(_ building: BuildingData, currentTime: TimeInterval) -> [StateChange] {
        var changes: [StateChange] = []

        let completedEntries = building.updateTraining(currentTime: currentTime)

        for entry in completedEntries {
            changes.append(.trainingCompleted(
                buildingID: building.id,
                unitType: entry.unitType.rawValue,
                quantity: entry.quantity
            ))

            // Update garrison composition change
            var garrisonDict: [String: Int] = [:]
            for (unitType, count) in building.garrison {
                garrisonDict[unitType.rawValue] = count
            }

            changes.append(.unitsGarrisoned(
                buildingID: building.id,
                unitType: entry.unitType.rawValue,
                quantity: entry.quantity
            ))
        }

        // Update progress for remaining entries
        for (index, entry) in building.trainingQueue.enumerated() {
            if entry.progress > 0 && entry.progress < 1.0 {
                changes.append(.trainingProgress(
                    buildingID: building.id,
                    entryIndex: index,
                    progress: entry.progress
                ))
            }
        }

        return changes
    }

    // MARK: - Villager Training

    private func updateVillagerTraining(_ building: BuildingData, currentTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []

        let completedEntries = building.updateVillagerTraining(currentTime: currentTime)

        for entry in completedEntries {
            changes.append(.villagerTrainingCompleted(
                buildingID: building.id,
                quantity: entry.quantity
            ))

            changes.append(.villagersGarrisoned(
                buildingID: building.id,
                quantity: entry.quantity
            ))
        }

        // Update progress for remaining entries
        for (index, entry) in building.villagerTrainingQueue.enumerated() {
            if entry.progress > 0 && entry.progress < 1.0 {
                changes.append(.villagerTrainingProgress(
                    buildingID: building.id,
                    entryIndex: index,
                    progress: entry.progress
                ))
            }
        }

        return changes
    }

    // MARK: - Training Commands

    func canTrainMilitary(buildingID: UUID, unitType: MilitaryUnitType, quantity: Int, forPlayer playerID: UUID) -> (valid: Bool, reason: String?) {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID),
              let player = state.getPlayer(id: playerID) else {
            return (false, "Building not found")
        }

        guard building.ownerID == playerID else {
            return (false, "Not your building")
        }

        guard building.isOperational else {
            return (false, "Building not operational")
        }

        // Convert to data type for checking
        guard let unitTypeData = MilitaryUnitTypeData(rawValue: unitType.rawValue) else {
            return (false, "Invalid unit type")
        }

        // Check if building can train this unit type
        if unitTypeData.trainingBuilding != building.buildingType {
            return (false, "This building cannot train \(unitType.displayName)")
        }

        // Check population capacity
        let popStats = state.getPopulationStats(forPlayer: playerID)
        if popStats.current + quantity > popStats.capacity {
            return (false, "Not enough population capacity")
        }

        // Check resources
        let cost = convertTrainingCost(unitTypeData.trainingCost, quantity: quantity)
        if !player.canAfford(cost) {
            return (false, "Insufficient resources")
        }

        return (true, nil)
    }

    func startMilitaryTraining(buildingID: UUID, unitType: MilitaryUnitType, quantity: Int, forPlayer playerID: UUID) -> [StateChange] {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID),
              let player = state.getPlayer(id: playerID) else {
            return []
        }

        let validation = canTrainMilitary(buildingID: buildingID, unitType: unitType, quantity: quantity, forPlayer: playerID)
        guard validation.valid else { return [] }

        // Deduct resources
        guard let unitTypeData = MilitaryUnitTypeData(rawValue: unitType.rawValue) else {
            return []
        }

        let cost = convertTrainingCost(unitTypeData.trainingCost, quantity: quantity)
        for (resourceType, amount) in cost {
            _ = player.removeResource(resourceType, amount: amount)
        }

        // Start training
        building.startTraining(unitType: unitType, quantity: quantity, at: state.currentTime)

        return [.trainingStarted(
            buildingID: buildingID,
            unitType: unitType.rawValue,
            quantity: quantity,
            startTime: state.currentTime
        )]
    }

    func canTrainVillagers(buildingID: UUID, quantity: Int, forPlayer playerID: UUID) -> (valid: Bool, reason: String?) {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID),
              let player = state.getPlayer(id: playerID) else {
            return (false, "Building not found")
        }

        guard building.ownerID == playerID else {
            return (false, "Not your building")
        }

        guard building.isOperational else {
            return (false, "Building not operational")
        }

        guard building.canTrainVillagers() else {
            return (false, "This building cannot train villagers")
        }

        // Check population capacity
        let popStats = state.getPopulationStats(forPlayer: playerID)
        if popStats.current + quantity > popStats.capacity {
            return (false, "Not enough population capacity")
        }

        // Check resources (villagers cost 50 food each)
        let cost: [ResourceTypeData: Int] = [.food: 50 * quantity]
        if !player.canAfford(cost) {
            return (false, "Insufficient resources")
        }

        return (true, nil)
    }

    func startVillagerTraining(buildingID: UUID, quantity: Int, forPlayer playerID: UUID) -> [StateChange] {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID),
              let player = state.getPlayer(id: playerID) else {
            return []
        }

        let validation = canTrainVillagers(buildingID: buildingID, quantity: quantity, forPlayer: playerID)
        guard validation.valid else { return [] }

        // Deduct resources
        _ = player.removeResource(.food, amount: 50 * quantity)

        // Start training
        building.startVillagerTraining(quantity: quantity, at: state.currentTime)

        return [.villagerTrainingStarted(
            buildingID: buildingID,
            quantity: quantity,
            startTime: state.currentTime
        )]
    }

    // MARK: - Deployment

    func canDeployArmy(fromBuildingID buildingID: UUID, composition: [MilitaryUnitType: Int], forPlayer playerID: UUID) -> (valid: Bool, reason: String?) {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID) else {
            return (false, "Building not found")
        }

        guard building.ownerID == playerID else {
            return (false, "Not your building")
        }

        // Check garrison has enough units
        for (unitType, count) in composition {
            let available = building.garrison[unitType] ?? 0
            if available < count {
                return (false, "Not enough \(unitType.displayName) in garrison")
            }
        }

        // Check army limit
        let currentArmies = state.getArmiesForPlayer(id: playerID).count
        let ccLevel = state.getCityCenterLevel(forPlayer: playerID)
        let maxArmies = 1 + (ccLevel / 2)

        if currentArmies >= maxArmies {
            return (false, "Maximum army limit reached")
        }

        return (true, nil)
    }

    func deployArmy(fromBuildingID buildingID: UUID, composition: [MilitaryUnitType: Int], forPlayer playerID: UUID) -> (army: ArmyData?, changes: [StateChange]) {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID) else {
            return (nil, [])
        }

        let validation = canDeployArmy(fromBuildingID: buildingID, composition: composition, forPlayer: playerID)
        guard validation.valid else { return (nil, []) }

        var changes: [StateChange] = []

        // Remove units from garrison
        for (unitType, count) in composition {
            _ = building.removeFromGarrison(unitType: unitType, quantity: count)

            changes.append(.unitsUngarrisoned(
                buildingID: buildingID,
                unitType: unitType.rawValue,
                quantity: count
            ))
        }

        // Find spawn position
        let spawnCoord = state.mapData.findNearestWalkable(
            to: building.coordinate,
            maxDistance: 3,
            forPlayerID: playerID,
            gameState: state
        ) ?? building.coordinate

        // Create army
        let army = ArmyData(name: "Army", coordinate: spawnCoord, ownerID: playerID)
        army.homeBaseID = buildingID

        // Add units to army
        for (unitType, count) in composition {
            if let dataType = MilitaryUnitTypeData(rawValue: unitType.rawValue) {
                army.addMilitaryUnits(dataType, count: count)
            }
        }

        // Add to game state
        state.addArmy(army)

        // Build composition dict for change
        var compositionDict: [String: Int] = [:]
        for (unitType, count) in army.militaryComposition {
            compositionDict[unitType.rawValue] = count
        }

        changes.append(.armyCreated(
            armyID: army.id,
            ownerID: playerID,
            coordinate: spawnCoord,
            composition: compositionDict
        ))

        return (army, changes)
    }

    func canDeployVillagers(fromBuildingID buildingID: UUID, count: Int, forPlayer playerID: UUID) -> (valid: Bool, reason: String?) {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID) else {
            return (false, "Building not found")
        }

        guard building.ownerID == playerID else {
            return (false, "Not your building")
        }

        if building.villagerGarrison < count {
            return (false, "Not enough villagers in garrison")
        }

        // Check villager group limit
        let currentGroups = state.getVillagerGroupsForPlayer(id: playerID).count
        let ccLevel = state.getCityCenterLevel(forPlayer: playerID)
        let maxGroups = 2 + ccLevel

        if currentGroups >= maxGroups {
            return (false, "Maximum villager group limit reached")
        }

        return (true, nil)
    }

    func deployVillagers(fromBuildingID buildingID: UUID, count: Int, forPlayer playerID: UUID) -> (group: VillagerGroupData?, changes: [StateChange]) {
        guard let state = gameState,
              let building = state.getBuilding(id: buildingID) else {
            return (nil, [])
        }

        let validation = canDeployVillagers(fromBuildingID: buildingID, count: count, forPlayer: playerID)
        guard validation.valid else { return (nil, []) }

        var changes: [StateChange] = []

        // Remove villagers from garrison
        _ = building.removeVillagersFromGarrison(quantity: count)

        changes.append(.villagersUngarrisoned(
            buildingID: buildingID,
            quantity: count
        ))

        // Find spawn position
        let spawnCoord = state.mapData.findNearestWalkable(
            to: building.coordinate,
            maxDistance: 3,
            forPlayerID: playerID,
            gameState: state
        ) ?? building.coordinate

        // Create villager group
        let group = VillagerGroupData(name: "Villagers", coordinate: spawnCoord, villagerCount: count, ownerID: playerID)

        // Add to game state
        state.addVillagerGroup(group)

        changes.append(.villagerGroupCreated(
            groupID: group.id,
            ownerID: playerID,
            coordinate: spawnCoord,
            count: count
        ))

        return (group, changes)
    }

    // MARK: - Helpers

    private func convertTrainingCost(_ cost: [ResourceTypeData: Int], quantity: Int) -> [ResourceTypeData: Int] {
        var total: [ResourceTypeData: Int] = [:]
        for (resource, amount) in cost {
            total[resource] = amount * quantity
        }
        return total
    }
}
