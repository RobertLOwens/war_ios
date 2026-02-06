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

        // Calculate storage capacities
        func getCapacity(_ type: ResourceTypeData) -> Int {
            return state.getStorageCapacity(forPlayer: player.id, resourceType: type)
        }

        // Update resources based on collection rates
        let resourceChanges = player.updateResources(currentTime: currentTime, getStorageCapacity: getCapacity)

        // Generate state changes for any resources that changed
        for (resourceType, amount) in resourceChanges {
            if amount > 0 {
                changes.append(.resourcesChanged(
                    playerID: player.id,
                    resourceType: resourceType.rawValue,
                    oldAmount: player.getResource(resourceType) - amount,
                    newAmount: player.getResource(resourceType)
                ))
            }
        }

        // Process food consumption for AI players only
        // Human players have food consumption handled in the visual layer (Player.updateResources())
        if player.isAI {
            let consumptionInfo = state.getFoodConsumptionRate(forPlayer: player.id)
            if consumptionInfo.rate > 0 {
                let deltaTime: TimeInterval = 0.5  // Match resource update interval
                let oldFood = player.getResource(.food)
                let consumed = player.consumeFood(consumptionRate: consumptionInfo.rate, deltaTime: deltaTime)

                if consumed > 0 {
                    changes.append(.resourcesChanged(
                        playerID: player.id,
                        resourceType: ResourceTypeData.food.rawValue,
                        oldAmount: oldFood,
                        newAmount: player.getResource(.food)
                    ))
                }
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
        var rate = resourceType.baseGatherRate + (Double(villagerCount) * baseGatherRatePerVillager)

        // Apply adjacency bonuses
        let adjacencyMultiplier = calculateAdjacencyBonus(resourceType: resourceType, coordinate: resourceCoordinate, state: state)
        rate *= adjacencyMultiplier

        // Apply research bonuses (would come from ResearchManager in full implementation)
        // For now, return base rate with adjacency
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

        // Check the tile itself and all neighbors
        let tilesToCheck = [coordinate] + coordinate.neighbors()

        for coord in tilesToCheck {
            if let building = state.getBuilding(at: coord),
               building.buildingType.rawValue == requiredCampType,
               building.isOperational {
                return true
            }
        }

        return false
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
        }
    }
}
