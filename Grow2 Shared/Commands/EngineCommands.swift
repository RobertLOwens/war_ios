// ============================================================================
// FILE: Grow2 Shared/Commands/EngineCommands.swift
// PURPOSE: Engine-compatible command implementations
// ============================================================================

import Foundation

// MARK: - Engine Build Command

/// Engine-compatible version of BuildCommand
struct EngineBuildCommand: EngineCompatibleCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let buildingType: BuildingType
    let coordinate: HexCoordinate
    let rotation: Int

    static var commandType: CommandType { .build }

    init(playerID: UUID, buildingType: BuildingType, coordinate: HexCoordinate, rotation: Int = 0) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingType = buildingType
        self.coordinate = coordinate
        self.rotation = rotation
    }

    // Legacy validation
    func validate(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }

        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: coordinate, rotation: rotation)

        for coord in occupiedCoords {
            guard let tile = context.hexMap.getTile(at: coord) else {
                return .failure(reason: "Invalid location")
            }
            guard tile.terrain != .water else {
                return .failure(reason: "Cannot build on water")
            }
            if let existingBuilding = context.getBuilding(at: coord) {
                if !existingBuilding.buildingType.isRoad || buildingType.isRoad {
                    return .failure(reason: "A building already exists here")
                }
            }
        }

        let ccLevel = player.getCityCenterLevel()
        if buildingType.requiredCityCenterLevel > ccLevel {
            return .failure(reason: "Requires City Center Level \(buildingType.requiredCityCenterLevel)")
        }

        for (resourceType, amount) in buildingType.buildCost {
            if !player.hasResource(resourceType, amount: amount) {
                return .failure(reason: "Insufficient \(resourceType.displayName)")
            }
        }

        return .success
    }

    // Legacy execution
    func execute(in context: CommandContext) -> CommandResult {
        // Delegate to the original BuildCommand for legacy support
        let legacyCommand = BuildCommand(
            playerID: playerID,
            buildingType: buildingType,
            coordinate: coordinate,
            builderEntityID: nil,
            rotation: rotation
        )
        return legacyCommand.execute(in: context)
    }

    // Engine-based validation
    func validateOnEngine(in state: GameState) -> CommandResult {
        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: coordinate, rotation: rotation)

        for coord in occupiedCoords {
            guard state.mapData.isValidCoordinate(coord) else {
                return .failure(reason: "Invalid location")
            }
            guard state.mapData.isWalkable(coord) else {
                return .failure(reason: "Cannot build here")
            }
            if state.mapData.getBuildingID(at: coord) != nil {
                return .failure(reason: "A building already exists here")
            }
        }

        let ccLevel = state.getCityCenterLevel(forPlayer: playerID)
        if buildingType.requiredCityCenterLevel > ccLevel {
            return .failure(reason: "Requires City Center Level \(buildingType.requiredCityCenterLevel)")
        }

        let cost = convertCost(buildingType.buildCost)
        if !player.canAfford(cost) {
            return .failure(reason: "Insufficient resources")
        }

        return .success
    }

    // Engine-based execution
    func executeOnEngine(in state: GameState, changeBuilder: StateChangeBuilder) -> CommandResultWithChanges {
        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Deduct resources
        let cost = convertCost(buildingType.buildCost)
        for (resourceType, amount) in cost {
            _ = player.removeResource(resourceType, amount: amount)
        }

        // Create building data
        let building = BuildingData(
            buildingType: buildingType,
            coordinate: coordinate,
            ownerID: playerID,
            rotation: rotation
        )
        building.startConstruction(builders: 1)

        // Add to game state
        state.addBuilding(building)

        // Record changes
        changeBuilder.add(.buildingPlaced(
            buildingID: building.id,
            buildingType: buildingType.rawValue,
            coordinate: coordinate,
            ownerID: playerID,
            rotation: rotation
        ))
        changeBuilder.add(.buildingConstructionStarted(buildingID: building.id))

        return .success(changes: changeBuilder.build().changes)
    }

    private func convertCost(_ cost: [ResourceType: Int]) -> [ResourceTypeData: Int] {
        var result: [ResourceTypeData: Int] = [:]
        for (key, value) in cost {
            if let dataType = ResourceTypeData(rawValue: key.rawValue) {
                result[dataType] = value
            }
        }
        return result
    }
}

// MARK: - Engine Move Command

/// Engine-compatible version of MoveCommand
struct EngineMoveCommand: EngineCompatibleCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let entityID: UUID
    let destination: HexCoordinate
    let isArmy: Bool  // true for army, false for villager group

    static var commandType: CommandType { .move }

    init(playerID: UUID, entityID: UUID, destination: HexCoordinate, isArmy: Bool) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.entityID = entityID
        self.destination = destination
        self.isArmy = isArmy
    }

    func validate(in context: CommandContext) -> CommandResult {
        // Use legacy validation
        let legacyCommand = MoveCommand(playerID: playerID, entityID: entityID, destination: destination)
        return legacyCommand.validate(in: context)
    }

    func execute(in context: CommandContext) -> CommandResult {
        let legacyCommand = MoveCommand(playerID: playerID, entityID: entityID, destination: destination)
        return legacyCommand.execute(in: context)
    }

    func validateOnEngine(in state: GameState) -> CommandResult {
        if isArmy {
            guard let army = state.getArmy(id: entityID) else {
                return .failure(reason: "Army not found")
            }
            guard army.ownerID == playerID else {
                return .failure(reason: "Not your army")
            }
            guard !army.isInCombat else {
                return .failure(reason: "Cannot move while in combat")
            }
        } else {
            guard let group = state.getVillagerGroup(id: entityID) else {
                return .failure(reason: "Villager group not found")
            }
            guard group.ownerID == playerID else {
                return .failure(reason: "Not your villagers")
            }
        }

        guard state.mapData.isValidCoordinate(destination) else {
            return .failure(reason: "Invalid destination")
        }

        // Check stacking limit
        if state.mapData.getEntityCount(at: destination) >= GameConfig.Stacking.maxEntitiesPerTile {
            return .failure(reason: "Tile is full")
        }

        return .success
    }

    func executeOnEngine(in state: GameState, changeBuilder: StateChangeBuilder) -> CommandResultWithChanges {
        if isArmy {
            guard let army = state.getArmy(id: entityID) else {
                return .failure(reason: "Army not found")
            }

            // Calculate path
            guard let path = state.mapData.findPath(
                from: army.coordinate,
                to: destination,
                forPlayerID: playerID,
                gameState: state
            ) else {
                return .failure(reason: "No valid path")
            }

            // Set the path on the army
            army.currentPath = path
            army.pathIndex = 0
            army.movementProgress = 0.0

            changeBuilder.add(.armyMoved(
                armyID: entityID,
                from: army.coordinate,
                to: destination,
                path: path
            ))
        } else {
            guard let group = state.getVillagerGroup(id: entityID) else {
                return .failure(reason: "Villager group not found")
            }

            guard let path = state.mapData.findPath(
                from: group.coordinate,
                to: destination,
                forPlayerID: playerID,
                gameState: state
            ) else {
                return .failure(reason: "No valid path")
            }

            group.setPath(path)
            group.currentTask = .moving(targetCoordinate: destination)

            changeBuilder.add(.villagerGroupMoved(
                groupID: entityID,
                from: group.coordinate,
                to: destination,
                path: path
            ))
        }

        return .success(changes: changeBuilder.build().changes)
    }
}

// MARK: - Engine Train Command

/// Engine-compatible version of TrainCommand
struct EngineTrainMilitaryCommand: EngineCompatibleCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let buildingID: UUID
    let unitType: MilitaryUnitType
    let quantity: Int

    static var commandType: CommandType { .trainMilitary }

    init(playerID: UUID, buildingID: UUID, unitType: MilitaryUnitType, quantity: Int) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
        self.unitType = unitType
        self.quantity = quantity
    }

    func validate(in context: CommandContext) -> CommandResult {
        // Use legacy validation
        let legacyCommand = TrainMilitaryCommand(
            playerID: playerID,
            buildingID: buildingID,
            unitType: unitType,
            quantity: quantity
        )
        return legacyCommand.validate(in: context)
    }

    func execute(in context: CommandContext) -> CommandResult {
        let legacyCommand = TrainMilitaryCommand(
            playerID: playerID,
            buildingID: buildingID,
            unitType: unitType,
            quantity: quantity
        )
        return legacyCommand.execute(in: context)
    }

    func validateOnEngine(in state: GameState) -> CommandResult {
        guard let building = state.getBuilding(id: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.ownerID == playerID else {
            return .failure(reason: "Not your building")
        }

        guard building.isOperational else {
            return .failure(reason: "Building not operational")
        }

        guard building.canTrain(unitType) else {
            return .failure(reason: "Cannot train \(unitType.displayName) here")
        }

        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        let cost = convertCost(unitType.trainingCost, quantity: quantity)
        if !player.canAfford(cost) {
            return .failure(reason: "Insufficient resources")
        }

        let popStats = state.getPopulationStats(forPlayer: playerID)
        if popStats.current + quantity > popStats.capacity {
            return .failure(reason: "Not enough population capacity")
        }

        return .success
    }

    func executeOnEngine(in state: GameState, changeBuilder: StateChangeBuilder) -> CommandResultWithChanges {
        guard let building = state.getBuilding(id: buildingID),
              let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Not found")
        }

        // Deduct resources
        let cost = convertCost(unitType.trainingCost, quantity: quantity)
        for (resourceType, amount) in cost {
            _ = player.removeResource(resourceType, amount: amount)
        }

        // Start training
        building.startTraining(unitType: unitType, quantity: quantity, at: state.currentTime)

        changeBuilder.add(.trainingStarted(
            buildingID: buildingID,
            unitType: unitType.rawValue,
            quantity: quantity,
            startTime: state.currentTime
        ))

        return .success(changes: changeBuilder.build().changes)
    }

    private func convertCost(_ cost: [ResourceType: Int], quantity: Int) -> [ResourceTypeData: Int] {
        var result: [ResourceTypeData: Int] = [:]
        for (key, value) in cost {
            if let dataType = ResourceTypeData(rawValue: key.rawValue) {
                result[dataType] = value * quantity
            }
        }
        return result
    }
}

// MARK: - Engine Deploy Command

/// Engine-compatible version of DeployCommand
struct EngineDeployArmyCommand: EngineCompatibleCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let buildingID: UUID
    let composition: [MilitaryUnitType: Int]

    static var commandType: CommandType { .deployArmy }

    init(playerID: UUID, buildingID: UUID, composition: [MilitaryUnitType: Int]) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
        self.composition = composition
    }

    func validate(in context: CommandContext) -> CommandResult {
        let legacyCommand = DeployArmyCommand(
            playerID: playerID,
            buildingID: buildingID,
            units: composition
        )
        return legacyCommand.validate(in: context)
    }

    func execute(in context: CommandContext) -> CommandResult {
        let legacyCommand = DeployArmyCommand(
            playerID: playerID,
            buildingID: buildingID,
            units: composition
        )
        return legacyCommand.execute(in: context)
    }

    func validateOnEngine(in state: GameState) -> CommandResult {
        guard let building = state.getBuilding(id: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.ownerID == playerID else {
            return .failure(reason: "Not your building")
        }

        for (unitType, count) in composition {
            let available = building.garrison[unitType] ?? 0
            if available < count {
                return .failure(reason: "Not enough \(unitType.displayName) in garrison")
            }
        }

        let currentArmies = state.getArmiesForPlayer(id: playerID).count
        let ccLevel = state.getCityCenterLevel(forPlayer: playerID)
        let maxArmies = 1 + (ccLevel / 2)

        if currentArmies >= maxArmies {
            return .failure(reason: "Maximum army limit reached")
        }

        return .success
    }

    func executeOnEngine(in state: GameState, changeBuilder: StateChangeBuilder) -> CommandResultWithChanges {
        guard let building = state.getBuilding(id: buildingID) else {
            return .failure(reason: "Building not found")
        }

        // Remove units from garrison
        for (unitType, count) in composition {
            _ = building.removeFromGarrison(unitType: unitType, quantity: count)
            changeBuilder.add(.unitsUngarrisoned(
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

        // Add units
        for (unitType, count) in composition {
            if let dataType = MilitaryUnitTypeData(rawValue: unitType.rawValue) {
                army.addMilitaryUnits(dataType, count: count)
            }
        }

        state.addArmy(army)

        var compositionDict: [String: Int] = [:]
        for (unitType, count) in army.militaryComposition {
            compositionDict[unitType.rawValue] = count
        }

        changeBuilder.add(.armyCreated(
            armyID: army.id,
            ownerID: playerID,
            coordinate: spawnCoord,
            composition: compositionDict
        ))

        return .success(changes: changeBuilder.build().changes)
    }
}
