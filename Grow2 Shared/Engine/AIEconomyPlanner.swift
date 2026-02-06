// ============================================================================
// FILE: Grow2 Shared/Engine/AIEconomyPlanner.swift
// PURPOSE: AI economy and expansion planning - resource gathering, building,
//          villager management, resource camps, and scouting
// ============================================================================

import Foundation

/// Handles AI economy decisions: villager training, resource gathering,
/// building construction, resource camp placement, and scouting
struct AIEconomyPlanner {

    // MARK: - Configuration

    private let buildInterval = GameConfig.AI.Intervals.economicBuild
    private let trainInterval = GameConfig.AI.Intervals.militaryTrain
    private let scoutInterval = GameConfig.AI.Intervals.scout
    private let campBuildInterval = GameConfig.AI.Intervals.campBuild
    private let maxCampsPerType = GameConfig.AI.Limits.maxCampsPerType
    private let scoutRange = GameConfig.AI.Limits.scoutRange

    // MARK: - Economy Commands

    func generateEconomyCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard let player = gameState.getPlayer(id: playerID) else {
            return []
        }

        // Check if we need more villagers
        let villagerCount = gameState.getVillagerCount(forPlayer: playerID)
        let popStats = gameState.getPopulationStats(forPlayer: playerID)

        // Train villagers if we have capacity and need more
        if villagerCount < 20 && popStats.current < popStats.capacity {
            if let command = tryTrainVillagers(playerID: playerID, gameState: gameState, currentTime: currentTime, aiState: aiState) {
                commands.append(command)
            }
        }

        // Deploy garrisoned villagers from buildings
        if let command = tryDeployVillagers(playerID: playerID, gameState: gameState) {
            commands.append(command)
        }

        // Assign idle villagers to gather resources
        let gatherCommands = tryAssignVillagersToGather(playerID: playerID, gameState: gameState)
        commands.append(contentsOf: gatherCommands)

        // Rebalance existing villagers if resource needs have changed
        let rebalanceCommands = tryRebalanceVillagers(playerID: playerID, gameState: gameState)
        commands.append(contentsOf: rebalanceCommands)

        // Build farms if we need more food income
        let urgency = analyzeResourceNeeds(playerID: playerID, gameState: gameState)
        let foodUrgency = urgency[.food] ?? 0.0
        let foodRate = player.getCollectionRate(.food)

        // Build farm if food urgency is high or collection rate is very low
        if (foodUrgency > 0.5 || foodRate < 2.0) && currentTime - aiState.lastBuildTime >= buildInterval {
            if let command = tryBuildFarm(playerID: playerID, gameState: gameState) {
                commands.append(command)
                aiState.lastBuildTime = currentTime
            }
        }

        // Build storage if any resource is near capacity
        let shouldBuildStorage = urgency.values.contains { $0 < 0.2 }  // Some resource has low urgency = near full
        if shouldBuildStorage && currentTime - aiState.lastBuildTime >= buildInterval {
            if let command = tryBuildStorage(playerID: playerID, gameState: gameState) {
                commands.append(command)
                aiState.lastBuildTime = currentTime
            }
        }

        // Build houses if we're near population cap or proactively in peace state
        let shouldBuildHouse = popStats.current >= popStats.capacity - 5 ||
            (aiState.currentState == .peace &&
             villagerCount >= 15 &&
             popStats.current >= popStats.capacity - 10 &&
             player.getResource(.wood) > 200 &&
             player.getResource(.stone) > 150)

        if shouldBuildHouse {
            if let command = tryBuildHouse(playerID: playerID, gameState: gameState, currentTime: currentTime, aiState: aiState) {
                commands.append(command)
                aiState.lastBuildTime = currentTime
            }
        }

        return commands
    }

    // MARK: - Expansion Commands

    func generateExpansionCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []

        // Try to build resource camps if needed
        if currentTime - aiState.lastCampBuildTime >= campBuildInterval {
            if let campCommand = tryBuildResourceCamp(aiState: aiState, gameState: gameState) {
                commands.append(campCommand)
                aiState.lastCampBuildTime = currentTime
            }
        }

        // Try to scout unexplored areas
        if currentTime - aiState.lastScoutTime >= scoutInterval {
            if let scoutCommand = tryScoutUnexploredArea(aiState: aiState, gameState: gameState) {
                commands.append(scoutCommand)
                aiState.lastScoutTime = currentTime
            }
        }

        return commands
    }

    // MARK: - Villager Training & Deployment

    private func tryTrainVillagers(playerID: UUID, gameState: GameState, currentTime: TimeInterval, aiState: AIPlayerState) -> EngineCommand? {
        guard currentTime - aiState.lastTrainTime >= trainInterval else { return nil }

        let cityCenters = gameState.getBuildingsForPlayer(id: playerID).filter {
            $0.buildingType == .cityCenter && $0.isOperational && $0.villagerTrainingQueue.isEmpty
        }

        guard let cityCenter = cityCenters.first else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        guard player.hasResource(.food, amount: 50) else { return nil }

        aiState.lastTrainTime = currentTime
        return AITrainVillagerCommand(playerID: playerID, buildingID: cityCenter.id, quantity: 1)
    }

    private func tryDeployVillagers(playerID: UUID, gameState: GameState) -> EngineCommand? {
        let buildings = gameState.getBuildingsForPlayer(id: playerID).filter {
            $0.isOperational && $0.villagerGarrison >= 3
        }

        guard let building = buildings.first else { return nil }

        let villagersToSpawn = building.villagerGarrison

        debugLog("🤖 AI deploying \(villagersToSpawn) villagers from \(building.buildingType.displayName)")
        return AIDeployVillagersCommand(playerID: playerID, buildingID: building.id, quantity: villagersToSpawn)
    }

    // MARK: - Resource Gathering

    private func tryAssignVillagersToGather(playerID: UUID, gameState: GameState) -> [EngineCommand] {
        var commands: [EngineCommand] = []

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        let idleVillagers = gameState.getVillagerGroupsForPlayer(id: playerID).filter { group in
            group.currentTask == .idle && group.currentPath == nil
        }

        guard !idleVillagers.isEmpty else { return [] }

        let urgency = analyzeResourceNeeds(playerID: playerID, gameState: gameState)

        let exploredResources = gameState.getExploredResourcePoints(forPlayer: playerID)
        let nearbyResources = exploredResources.filter { resource in
            resource.coordinate.distance(to: cityCenter.coordinate) <= 8 &&
            resource.remainingAmount > 0 &&
            resource.resourceType.isGatherable
        }.sorted { r1, r2 in
            let u1 = urgency[r1.resourceType.resourceYield] ?? 0.0
            let u2 = urgency[r2.resourceType.resourceYield] ?? 0.0
            if abs(u1 - u2) > 0.1 {
                return u1 > u2
            }
            return r1.coordinate.distance(to: cityCenter.coordinate) < r2.coordinate.distance(to: cityCenter.coordinate)
        }

        var assignedResources: Set<UUID> = []
        for villagerGroup in idleVillagers {
            for resource in nearbyResources {
                if assignedResources.contains(resource.id) { continue }

                let existingGatherers = resource.assignedVillagerGroupIDs.count
                if existingGatherers >= 2 { continue }

                let resourceType = resource.resourceType.resourceYield
                let resourceUrgency = urgency[resourceType] ?? 0.0
                if resourceUrgency < 0.15 {
                    continue
                }

                commands.append(AIGatherCommand(
                    playerID: playerID,
                    villagerGroupID: villagerGroup.id,
                    resourcePointID: resource.id
                ))
                assignedResources.insert(resource.id)
                debugLog("🤖 AI assigning villagers to gather \(resource.resourceType.displayName) (urgency: \(String(format: "%.2f", resourceUrgency)))")
                break
            }
        }

        return commands
    }

    // MARK: - Resource Analysis

    func analyzeResourceNeeds(playerID: UUID, gameState: GameState) -> [ResourceTypeData: Double] {
        var urgency: [ResourceTypeData: Double] = [:]
        guard let player = gameState.getPlayer(id: playerID) else { return urgency }

        for resourceType in ResourceTypeData.allCases {
            let current = Double(player.getResource(resourceType))
            let rate = player.getCollectionRate(resourceType)
            let capacity = Double(gameState.getStorageCapacity(forPlayer: playerID, resourceType: resourceType))

            var score = 1.0 - (current / max(1.0, capacity))

            if current < 100 {
                score += 0.5
            }

            if current >= capacity - 50 {
                score = 0.1
            }

            if resourceType == .food {
                score *= 1.2
            }

            if resourceType == .wood {
                let buildingCount = gameState.getBuildingsForPlayer(id: playerID).count
                if buildingCount < 10 {
                    score *= 1.15
                }
            }

            if rate < 0.1 && score > 0.2 {
                score += 0.1
            }

            urgency[resourceType] = max(0.0, min(2.0, score))
        }

        return urgency
    }

    private func tryRebalanceVillagers(playerID: UUID, gameState: GameState) -> [EngineCommand] {
        var commands: [EngineCommand] = []

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        let urgency = analyzeResourceNeeds(playerID: playerID, gameState: gameState)

        var overStaffedGroups: [(VillagerGroupData, ResourcePointData)] = []
        var underStaffedResources: [ResourcePointData] = []

        for group in gameState.getVillagerGroupsForPlayer(id: playerID) {
            guard case .gatheringResource(let resourcePointID) = group.currentTask else { continue }
            guard let resource = gameState.getResourcePoint(id: resourcePointID) else { continue }

            let resourceType = resource.resourceType.resourceYield
            let resourceUrgency = urgency[resourceType] ?? 0.5

            if resourceUrgency < 0.2 && resource.assignedVillagerGroupIDs.count >= 2 {
                overStaffedGroups.append((group, resource))
            }
        }

        let exploredResources = gameState.getExploredResourcePoints(forPlayer: playerID)
        for resource in exploredResources {
            guard resource.coordinate.distance(to: cityCenter.coordinate) <= 8 else { continue }
            guard resource.remainingAmount > 0 && resource.resourceType.isGatherable else { continue }

            let resourceType = resource.resourceType.resourceYield
            let resourceUrgency = urgency[resourceType] ?? 0.5

            if resourceUrgency > 0.6 && resource.assignedVillagerGroupIDs.count < 2 {
                underStaffedResources.append(resource)
            }
        }

        underStaffedResources.sort { r1, r2 in
            let u1 = urgency[r1.resourceType.resourceYield] ?? 0.0
            let u2 = urgency[r2.resourceType.resourceYield] ?? 0.0
            return u1 > u2
        }

        for (group, _) in overStaffedGroups {
            guard let targetResource = underStaffedResources.first(where: { $0.assignedVillagerGroupIDs.count < 2 }) else {
                break
            }

            commands.append(AIGatherCommand(
                playerID: playerID,
                villagerGroupID: group.id,
                resourcePointID: targetResource.id
            ))

            debugLog("🤖 AI rebalancing: moving villagers to \(targetResource.resourceType.displayName) (urgency: \(String(format: "%.2f", urgency[targetResource.resourceType.resourceYield] ?? 0.0)))")
        }

        return commands
    }

    // MARK: - Building Construction

    private func tryBuildFarm(playerID: UUID, gameState: GameState) -> EngineCommand? {
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else {
            debugLog("🤖 tryBuildFarm: No city center")
            return nil
        }
        guard let player = gameState.getPlayer(id: playerID) else {
            debugLog("🤖 tryBuildFarm: No player")
            return nil
        }

        let farmCost = BuildingType.farm.buildCost
        for (resource, amount) in farmCost {
            guard player.hasResource(resource, amount: amount) else {
                debugLog("🤖 tryBuildFarm: Not enough \(resource.displayName) (need \(amount), have \(player.getResource(resource)))")
                return nil
            }
        }

        guard let location = gameState.findBuildLocation(near: cityCenter.coordinate, maxDistance: 4, forPlayer: playerID) else {
            debugLog("🤖 tryBuildFarm: No valid build location found near (\(cityCenter.coordinate.q), \(cityCenter.coordinate.r))")
            return nil
        }

        debugLog("🤖 tryBuildFarm: Building at (\(location.q), \(location.r))")
        return AIBuildCommand(playerID: playerID, buildingType: .farm, coordinate: location, rotation: 0)
    }

    private func tryBuildHouse(playerID: UUID, gameState: GameState, currentTime: TimeInterval, aiState: AIPlayerState) -> EngineCommand? {
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        let houseCost = BuildingType.neighborhood.buildCost
        for (resource, amount) in houseCost {
            guard player.hasResource(resource, amount: amount) else { return nil }
        }

        guard let location = gameState.findBuildLocation(near: cityCenter.coordinate, maxDistance: 5, forPlayer: playerID) else {
            return nil
        }

        return AIBuildCommand(playerID: playerID, buildingType: .neighborhood, coordinate: location, rotation: 0)
    }

    private func tryBuildStorage(playerID: UUID, gameState: GameState) -> EngineCommand? {
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        let ccLevel = cityCenter.level
        let currentWarehouses = gameState.getBuildingCount(ofType: .warehouse, forPlayer: playerID)
        let maxWarehouses = BuildingType.maxWarehousesAllowed(forCityCenterLevel: ccLevel)

        guard currentWarehouses < maxWarehouses else {
            return nil
        }

        let warehouseCost = BuildingType.warehouse.buildCost
        for (resource, amount) in warehouseCost {
            guard player.hasResource(resource, amount: amount) else {
                return nil
            }
        }

        guard let location = gameState.findBuildLocation(near: cityCenter.coordinate, maxDistance: 5, forPlayer: playerID) else {
            return nil
        }

        debugLog("🤖 AI building warehouse at (\(location.q), \(location.r)) - storage expansion needed")
        return AIBuildCommand(playerID: playerID, buildingType: .warehouse, coordinate: location, rotation: 0)
    }

    // MARK: - Resource Camp Building

    func hasResourceCampCoverage(resource: ResourcePointData, gameState: GameState, playerID: UUID) -> Bool {
        guard resource.resourceType.requiresCamp else {
            return true
        }

        guard let requiredCampTypeName = resource.resourceType.requiredCampType else {
            return true
        }

        let requiredCampType: BuildingType
        if requiredCampTypeName == "Lumber Camp" {
            requiredCampType = .lumberCamp
        } else if requiredCampTypeName == "Mining Camp" {
            requiredCampType = .miningCamp
        } else {
            return true
        }

        let tilesToCheck = [resource.coordinate] + resource.coordinate.neighbors()

        for coord in tilesToCheck {
            if let building = gameState.getBuilding(at: coord),
               building.buildingType == requiredCampType,
               building.ownerID == playerID,
               building.isOperational {
                return true
            }
        }

        return false
    }

    private func findResourceNeedingCamp(aiState: AIPlayerState, gameState: GameState) -> (resource: ResourcePointData, campType: BuildingType)? {
        let playerID = aiState.playerID
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        let urgency = analyzeResourceNeeds(playerID: playerID, gameState: gameState)

        let lumberCampCount = gameState.getBuildingCount(ofType: .lumberCamp, forPlayer: playerID)
        let miningCampCount = gameState.getBuildingCount(ofType: .miningCamp, forPlayer: playerID)

        let exploredResources = gameState.getExploredResourcePoints(forPlayer: playerID)

        var candidates: [(resource: ResourcePointData, campType: BuildingType, score: Double)] = []

        for resource in exploredResources {
            guard resource.remainingAmount > 0 else { continue }
            guard resource.resourceType.requiresCamp else { continue }
            guard !hasResourceCampCoverage(resource: resource, gameState: gameState, playerID: playerID) else { continue }

            let distance = max(1, resource.coordinate.distance(to: cityCenter.coordinate))
            guard distance <= 10 else { continue }

            let resourceType = resource.resourceType.resourceYield
            let resourceUrgency = urgency[resourceType] ?? 0.5

            let campType: BuildingType
            switch resource.resourceType {
            case .trees:
                guard lumberCampCount < maxCampsPerType else { continue }
                campType = .lumberCamp
            case .oreMine, .stoneQuarry:
                guard miningCampCount < maxCampsPerType else { continue }
                campType = .miningCamp
            default:
                continue
            }

            let campCost = campType.buildCost
            var canAfford = true
            for (res, amount) in campCost {
                if !player.hasResource(res, amount: amount) {
                    canAfford = false
                    break
                }
            }
            guard canAfford else { continue }

            let score = resourceUrgency * Double(resource.remainingAmount) / (100.0 * Double(distance))
            candidates.append((resource, campType, score))
        }

        return candidates.max(by: { $0.score < $1.score }).map { ($0.resource, $0.campType) }
    }

    private func tryBuildResourceCamp(aiState: AIPlayerState, gameState: GameState) -> EngineCommand? {
        let playerID = aiState.playerID

        guard let (resource, campType) = findResourceNeedingCamp(aiState: aiState, gameState: gameState) else {
            return nil
        }

        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        let campCost = campType.buildCost
        for (res, amount) in campCost {
            guard player.hasResource(res, amount: amount) else { return nil }
        }

        if gameState.canBuildAt(resource.coordinate, forPlayer: playerID) {
            debugLog("🤖 AI building \(campType.displayName) at resource (\(resource.coordinate.q), \(resource.coordinate.r))")
            return AIBuildCommand(playerID: playerID, buildingType: campType, coordinate: resource.coordinate, rotation: 0)
        }

        for neighbor in resource.coordinate.neighbors() {
            if gameState.canBuildAt(neighbor, forPlayer: playerID) {
                debugLog("🤖 AI building \(campType.displayName) adjacent to resource at (\(neighbor.q), \(neighbor.r))")
                return AIBuildCommand(playerID: playerID, buildingType: campType, coordinate: neighbor, rotation: 0)
            }
        }

        return nil
    }

    // MARK: - Scouting

    private func tryScoutUnexploredArea(aiState: AIPlayerState, gameState: GameState) -> EngineCommand? {
        let playerID = aiState.playerID

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }

        guard let scoutTarget = gameState.findNearestUnexploredCoordinate(
            from: cityCenter.coordinate,
            forPlayer: playerID,
            maxRange: scoutRange
        ) else {
            return nil
        }

        let idleArmies = gameState.getArmiesForPlayer(id: playerID).filter {
            !$0.isInCombat && $0.currentPath == nil
        }

        if let scoutArmy = idleArmies.first {
            debugLog("🤖 AI sending army to scout (\(scoutTarget.q), \(scoutTarget.r))")
            return AIMoveCommand(playerID: playerID, entityID: scoutArmy.id, destination: scoutTarget, isArmy: true)
        }

        if aiState.currentState == .peace {
            let idleVillagers = gameState.getVillagerGroupsForPlayer(id: playerID).filter {
                $0.currentTask == .idle && $0.currentPath == nil
            }

            if let scoutVillagers = idleVillagers.first {
                debugLog("🤖 AI sending villagers to scout (\(scoutTarget.q), \(scoutTarget.r))")
                return AIMoveCommand(playerID: playerID, entityID: scoutVillagers.id, destination: scoutTarget, isArmy: false)
            }
        }

        return nil
    }
}
