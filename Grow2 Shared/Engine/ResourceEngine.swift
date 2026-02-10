// ============================================================================
// FILE: Grow2 Shared/Engine/ResourceEngine.swift
// PURPOSE: Handles resource gathering logic - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Gathering Assignment

struct GatheringAssignment {
    let villagerGroupID: UUID
    let resourcePointID: UUID
    var accumulator: Double = 0.0
    var woodConsumptionAccumulator: Double = 0.0
}

// MARK: - Resource Engine

/// Handles all resource gathering and production logic
class ResourceEngine {

    // MARK: - State
    private weak var gameState: GameState?

    // MARK: - Gathering State
    private var gatheringAssignments: [UUID: GatheringAssignment] = [:]  // VillagerGroupID -> Assignment

    // MARK: - Constants
    private let baseGatherRatePerVillager = GameConfig.Resources.baseGatherRatePerVillager
    private let adjacencyBonusPercent = GameConfig.Resources.adjacencyBonusPercent

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
        gatheringAssignments.removeAll()

        // Restore gathering assignments from game state
        for group in gameState.villagerGroups.values {
            if let resourceID = group.assignedResourcePointID {
                gatheringAssignments[group.id] = GatheringAssignment(
                    villagerGroupID: group.id,
                    resourcePointID: resourceID,
                    accumulator: group.gatheringAccumulator
                )
            }
        }
    }

    // MARK: - Update Loop

    func update(currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []

        // Update resource generation for all players
        for player in state.players.values {
            let playerChanges = updatePlayerResources(player, currentTime: currentTime)
            changes.append(contentsOf: playerChanges)
        }

        // Process all gathering assignments
        let gatheringChanges = processGathering(currentTime: currentTime)
        changes.append(contentsOf: gatheringChanges)

        return changes
    }

    // MARK: - Player Resource Updates

    private func updatePlayerResources(_ player: PlayerState, currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []

        // Note: Resource addition from gathering is handled in processGathering()
        // which directly adds resources and tracks resource point depletion.
        // We do NOT call player.updateResources() here to avoid double-counting.

        // Process food consumption for all players
        let consumptionInfo = state.getFoodConsumptionRate(forPlayer: player.id)
        if consumptionInfo.rate > 0 {
            let deltaTime: TimeInterval = 0.5  // Match resource update interval

            // Apply rationing reduction from player's best commander
            let commanders = state.getCommandersForPlayer(id: player.id)
            let bestRationing = commanders.map { $0.rationing }.max() ?? 0
            let rationingReduction = min(GameConfig.Commander.rationingReductionCap, Double(bestRationing) * GameConfig.Commander.rationingReductionScaling)
            let adjustedRate = consumptionInfo.rate * (1.0 - rationingReduction)

            let oldFood = player.getResource(.food)
            let consumed = player.consumeFood(consumptionRate: adjustedRate, deltaTime: deltaTime)

            if consumed > 0 {
                changes.append(.resourcesChanged(
                    playerID: player.id,
                    resourceType: ResourceTypeData.food.rawValue,
                    oldAmount: oldFood,
                    newAmount: player.getResource(.food)
                ))
            }
        }

        return changes
    }

    // MARK: - Gathering Processing

    private func processGathering(currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []
        var completedAssignments: [UUID] = []
        let deltaTime: TimeInterval = 0.5  // Resource update interval

        for (groupID, var assignment) in gatheringAssignments {
            guard let group = state.getVillagerGroup(id: groupID),
                  let resourcePoint = state.getResourcePoint(id: assignment.resourcePointID),
                  !resourcePoint.isDepleted() else {
                completedAssignments.append(groupID)
                continue
            }

            guard let ownerID = group.ownerID,
                  let player = state.getPlayer(id: ownerID) else {
                continue
            }

            // Farm wood consumption: farms require wood to operate
            if resourcePoint.resourceType == .farmland {
                let woodRate = GameConfig.Resources.farmWoodConsumptionRate
                assignment.woodConsumptionAccumulator += woodRate * deltaTime

                let woodToConsume = Int(assignment.woodConsumptionAccumulator)
                if woodToConsume > 0 {
                    let availableWood = player.getResource(.wood)
                    if availableWood <= 0 {
                        // No wood — pause farming
                        gatheringAssignments[groupID] = assignment
                        continue
                    }
                    let consumed = min(woodToConsume, availableWood)
                    _ = player.removeResource(.wood, amount: consumed)
                    assignment.woodConsumptionAccumulator -= Double(consumed)

                    changes.append(.resourcesChanged(
                        playerID: player.id,
                        resourceType: ResourceTypeData.wood.rawValue,
                        oldAmount: availableWood,
                        newAmount: player.getResource(.wood)
                    ))
                }
            }

            // Calculate gather rate
            let gatherRate = calculateGatherRate(
                villagerCount: group.villagerCount,
                resourceType: resourcePoint.resourceType,
                resourceCoordinate: resourcePoint.coordinate,
                state: state
            )

            // Accumulate gathered resources
            assignment.accumulator += gatherRate * deltaTime
            group.gatheringAccumulator = assignment.accumulator

            // Convert to whole resources
            let wholeAmount = Int(assignment.accumulator)
            if wholeAmount > 0 {
                // Gather from resource point
                let oldResourceAmount = resourcePoint.remainingAmount
                let actualGathered = resourcePoint.gather(amount: wholeAmount)

                // Emit resource point amount change for visual sync
                if actualGathered > 0 {
                    changes.append(.resourcePointAmountChanged(
                        coordinate: resourcePoint.coordinate,
                        oldAmount: oldResourceAmount,
                        newAmount: resourcePoint.remainingAmount
                    ))
                }

                // Add to player resources
                let yieldType = resourcePoint.resourceType.resourceYield
                let storageCapacity = state.getStorageCapacity(forPlayer: player.id, resourceType: yieldType)
                let oldAmount = player.getResource(yieldType)
                let added = player.addResource(yieldType, amount: actualGathered, storageCapacity: storageCapacity)

                assignment.accumulator -= Double(wholeAmount)
                group.gatheringAccumulator = assignment.accumulator

                if added > 0 {
                    changes.append(.resourcesGathered(
                        playerID: player.id,
                        resourceType: yieldType.rawValue,
                        amount: added,
                        sourceCoordinate: resourcePoint.coordinate
                    ))

                    changes.append(.resourcesChanged(
                        playerID: player.id,
                        resourceType: yieldType.rawValue,
                        oldAmount: oldAmount,
                        newAmount: player.getResource(yieldType)
                    ))
                }

                // Check for depletion
                if resourcePoint.isDepleted() {
                    // Emit task change for the villager group going idle
                    // This must be emitted BEFORE resourcePointDepleted so the visual layer
                    // can update the villager before the resource is removed
                    changes.append(.villagerGroupTaskChanged(
                        groupID: groupID,
                        task: "idle",
                        targetCoordinate: nil
                    ))

                    changes.append(.resourcePointDepleted(
                        coordinate: resourcePoint.coordinate,
                        resourceType: resourcePoint.resourceType.rawValue
                    ))

                    // Stop gathering assignment
                    completedAssignments.append(groupID)
                }
            }

            gatheringAssignments[groupID] = assignment
        }

        // Clean up completed assignments
        for groupID in completedAssignments {
            stopGathering(villagerGroupID: groupID)
        }

        return changes
    }

    // MARK: - Gather Rate Calculation

    private func calculateGatherRate(villagerCount: Int, resourceType: ResourcePointTypeData, resourceCoordinate: HexCoordinate, state: GameState) -> Double {
        // Base rate
        var rate = Double(villagerCount) * baseGatherRatePerVillager

        // Apply adjacency bonuses
        let adjacencyMultiplier = calculateAdjacencyBonus(resourceType: resourceType, coordinate: resourceCoordinate, state: state)
        rate *= adjacencyMultiplier

        // Apply camp/farm level bonus
        let campLevelMultiplier = calculateCampLevelBonus(resourceType: resourceType, coordinate: resourceCoordinate, state: state)
        rate *= campLevelMultiplier

        return rate
    }

    private func calculateAdjacencyBonus(resourceType: ResourcePointTypeData, coordinate: HexCoordinate, state: GameState) -> Double {
        var multiplier = 1.0

        // Check for relevant buildings nearby
        let neighbors = coordinate.neighbors()

        for neighborCoord in neighbors {
            if let building = state.getBuilding(at: neighborCoord),
               building.isOperational {

                switch resourceType {
                case .farmland:
                    if building.buildingType == .mill {
                        multiplier += adjacencyBonusPercent
                    }
                case .trees:
                    if building.buildingType == .lumberCamp {
                        // Already covered by camp requirement
                    } else if building.buildingType == .warehouse {
                        multiplier += adjacencyBonusPercent
                    }
                case .oreMine, .stoneQuarry:
                    if building.buildingType == .warehouse {
                        multiplier += adjacencyBonusPercent
                    }
                default:
                    break
                }
            }
        }

        return multiplier
    }

    private func calculateCampLevelBonus(resourceType: ResourcePointTypeData, coordinate: HexCoordinate, state: GameState) -> Double {
        // Determine which building type boosts this resource
        let matchingType: BuildingType
        switch resourceType {
        case .farmland:
            matchingType = .farm
        case .trees:
            matchingType = .lumberCamp
        case .oreMine, .stoneQuarry:
            matchingType = .miningCamp
        default:
            return 1.0
        }

        // Check the tile itself and all neighbors for the highest-level matching building
        let tilesToCheck = [coordinate] + coordinate.neighbors()
        var highestLevel = 0

        for coord in tilesToCheck {
            if let building = state.getBuilding(at: coord),
               building.buildingType == matchingType,
               building.isOperational,
               building.level > highestLevel {
                highestLevel = building.level
            }
        }

        guard highestLevel > 1 else { return 1.0 }
        return 1.0 + Double(highestLevel - 1) * GameConfig.Resources.campLevelBonusPerLevel
    }

    // MARK: - Gathering Assignment Management

    func startGathering(villagerGroupID: UUID, resourcePointID: UUID) -> Bool {
        guard let state = gameState else {
            debugLog("❌ startGathering failed: No game state")
            return false
        }
        guard let group = state.getVillagerGroup(id: villagerGroupID) else {
            debugLog("❌ startGathering failed: VillagerGroup \(villagerGroupID) not found in engine state")
            return false
        }
        guard let resourcePoint = state.getResourcePoint(id: resourcePointID) else {
            debugLog("❌ startGathering failed: ResourcePoint \(resourcePointID) not found in engine state")
            return false
        }

        // Check if resource can accept more villagers
        guard resourcePoint.canAddVillagers(group.villagerCount) else {
            return false
        }

        // Check camp coverage for resources that require it
        if resourcePoint.resourceType.requiresCamp {
            guard hasCampCoverage(at: resourcePoint.coordinate, forResource: resourcePoint.resourceType, state: state) else {
                return false
            }
        }

        // Register the assignment
        resourcePoint.assignVillagerGroup(group.id, villagerCount: group.villagerCount)
        group.assignedResourcePointID = resourcePointID
        group.currentTask = .gatheringResource(resourcePointID: resourcePointID)
        group.taskTargetCoordinate = resourcePoint.coordinate
        group.taskTargetID = resourcePointID

        gatheringAssignments[villagerGroupID] = GatheringAssignment(
            villagerGroupID: villagerGroupID,
            resourcePointID: resourcePointID
        )

        return true
    }

    func stopGathering(villagerGroupID: UUID) {
        guard let state = gameState,
              let group = state.getVillagerGroup(id: villagerGroupID) else {
            return
        }

        // Remove from resource point
        if let resourceID = group.assignedResourcePointID,
           let resourcePoint = state.getResourcePoint(id: resourceID) {
            resourcePoint.unassignVillagerGroup(villagerGroupID, villagerCount: group.villagerCount)
        }

        // Clear group state
        group.assignedResourcePointID = nil
        group.clearTask()

        // Remove assignment
        gatheringAssignments.removeValue(forKey: villagerGroupID)
    }

    // MARK: - Camp Coverage

    private func hasCampCoverage(at coordinate: HexCoordinate, forResource resourceType: ResourcePointTypeData, state: GameState) -> Bool {
        guard let requiredCampType = resourceType.requiredCampType else {
            return true  // No camp required
        }

        // Find all matching camps in the game state
        let matchingCamps = state.buildings.values.filter {
            $0.buildingType.rawValue == requiredCampType && $0.isOperational
        }

        // Check if any camp can reach this coordinate via roads
        for camp in matchingCamps {
            let reachable = getExtendedCampReach(from: camp.coordinate, state: state)
            if reachable.contains(coordinate) {
                return true
            }
        }

        return false
    }

    /// BFS to find all coordinates reachable from a camp via connected buildings/roads.
    /// Mirrors HexMap.getExtendedCampReach() but uses GameState data layer.
    private func getExtendedCampReach(from campCoordinate: HexCoordinate, state: GameState) -> Set<HexCoordinate> {
        var reachable: Set<HexCoordinate> = []
        var visited: Set<HexCoordinate> = []
        var queue: [HexCoordinate] = [campCoordinate]

        // Camp tile + direct neighbors always reachable
        reachable.insert(campCoordinate)
        for neighbor in campCoordinate.neighbors() {
            reachable.insert(neighbor)
        }

        // BFS through connected buildings (all operational buildings act as roads)
        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard !visited.contains(current) else { continue }
            visited.insert(current)

            for neighbor in current.neighbors() {
                guard state.mapData.isValidCoordinate(neighbor) else { continue }

                if let building = state.getBuilding(at: neighbor), building.isOperational, !visited.contains(neighbor) {
                    // Add the building tile itself
                    reachable.insert(neighbor)
                    // Add all neighbors of the building tile (resource can be gathered)
                    for roadNeighbor in neighbor.neighbors() {
                        reachable.insert(roadNeighbor)
                    }
                    // Continue BFS through this building
                    queue.append(neighbor)
                }
            }
        }

        return reachable
    }

    // MARK: - Collection Rate Management

    func updateCollectionRates(forPlayer playerID: UUID) {
        guard let state = gameState,
              let player = state.getPlayer(id: playerID) else {
            return
        }

        // Reset all rates
        for resourceType in ResourceTypeData.allCases {
            player.setCollectionRate(resourceType, rate: 0)
        }

        // Calculate rates from all gathering assignments
        for assignment in gatheringAssignments.values {
            guard let group = state.getVillagerGroup(id: assignment.villagerGroupID),
                  group.ownerID == playerID,
                  let resourcePoint = state.getResourcePoint(id: assignment.resourcePointID) else {
                continue
            }

            let rate = calculateGatherRate(
                villagerCount: group.villagerCount,
                resourceType: resourcePoint.resourceType,
                resourceCoordinate: resourcePoint.coordinate,
                state: state
            )

            let yieldType = resourcePoint.resourceType.resourceYield
            player.increaseCollectionRate(yieldType, amount: rate)

            // Farm wood consumption shows as negative wood rate
            if resourcePoint.resourceType == .farmland {
                let woodDrain = GameConfig.Resources.farmWoodConsumptionRate
                let currentWoodRate = player.getCollectionRate(.wood)
                player.setCollectionRate(.wood, rate: currentWoodRate - woodDrain)
            }
        }
    }
}
