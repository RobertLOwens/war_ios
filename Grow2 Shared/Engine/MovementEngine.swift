// ============================================================================
// FILE: Grow2 Shared/Engine/MovementEngine.swift
// PURPOSE: Handles all movement logic - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Movement Engine

/// Handles pathfinding and movement for all movable entities
class MovementEngine {

    // MARK: - State
    private weak var gameState: GameState?

    // MARK: - Movement Constants
    private let baseMovementSpeed: Double = 0.75  // Hexes per second on roads
    private let terrainSpeedMultiplier: Double = 0.33  // Off-road speed penalty
    private let retreatSpeedBonus: Double = 1.1  // 10% faster when retreating

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
    }

    // MARK: - Update Loop

    func update(currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []

        // Update army movements
        for army in state.armies.values {
            let armyChanges = updateArmyMovement(army, currentTime: currentTime)
            changes.append(contentsOf: armyChanges)
        }

        // Update villager group movements
        for group in state.villagerGroups.values {
            let groupChanges = updateVillagerGroupMovement(group, currentTime: currentTime)
            changes.append(contentsOf: groupChanges)
        }

        // Update reinforcement movements
        for army in state.armies.values {
            let reinforcementChanges = updateReinforcementMovements(army, currentTime: currentTime)
            changes.append(contentsOf: reinforcementChanges)
        }

        return changes
    }

    // MARK: - Army Movement

    private func updateArmyMovement(_ army: ArmyData, currentTime: TimeInterval) -> [StateChange] {
        guard let path = army.currentPath, army.pathIndex < path.count else {
            return []
        }
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []
        let targetCoord = path[army.pathIndex]

        // Calculate movement speed based on slowest unit in army
        let slowestUnitSpeed = army.slowestUnitMoveSpeed
        // Normalize: default army speed (1.6) = base speed, slower units reduce speed proportionally
        let speedMultiplier = 1.6 / slowestUnitSpeed

        var speed = baseMovementSpeed * speedMultiplier
        if state.mapData.getBuildingID(at: targetCoord) != nil {
            // On road
            speed = baseMovementSpeed * speedMultiplier
        } else {
            speed = baseMovementSpeed * speedMultiplier * terrainSpeedMultiplier
        }

        if army.isRetreating {
            speed *= retreatSpeedBonus
        }

        // Update progress
        army.movementProgress += speed * 0.1  // 0.1 second update interval

        // Check if we've reached the next tile
        if army.movementProgress >= 1.0 {
            let fromCoord = army.coordinate

            // Move to next tile
            army.coordinate = targetCoord
            state.mapData.updateArmyPosition(id: army.id, to: targetCoord)
            army.pathIndex += 1
            army.movementProgress = 0.0

            changes.append(.armyMoved(
                armyID: army.id,
                from: fromCoord,
                to: targetCoord,
                path: Array(path.suffix(from: army.pathIndex))
            ))

            // Check if path is complete
            if army.pathIndex >= path.count {
                army.currentPath = nil
                army.pathIndex = 0
                army.isRetreating = false
            }
        }

        return changes
    }

    // MARK: - Villager Group Movement

    private func updateVillagerGroupMovement(_ group: VillagerGroupData, currentTime: TimeInterval) -> [StateChange] {
        guard let path = group.currentPath, group.pathIndex < path.count else {
            return []
        }
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []
        let targetCoord = path[group.pathIndex]

        // Calculate movement speed (villagers are slower)
        var speed = baseMovementSpeed * 0.8  // 80% of base speed
        if state.mapData.getBuildingID(at: targetCoord) != nil {
            // On road
            speed = baseMovementSpeed * 0.8
        } else {
            speed = baseMovementSpeed * 0.8 * terrainSpeedMultiplier
        }

        // Update progress
        group.movementProgress += speed * 0.1

        // Check if we've reached the next tile
        if group.movementProgress >= 1.0 {
            let fromCoord = group.coordinate

            // Move to next tile
            group.coordinate = targetCoord
            state.mapData.updateVillagerGroupPosition(id: group.id, to: targetCoord)
            group.pathIndex += 1
            group.movementProgress = 0.0

            changes.append(.villagerGroupMoved(
                groupID: group.id,
                from: fromCoord,
                to: targetCoord,
                path: Array(path.suffix(from: group.pathIndex))
            ))

            // Check if path is complete
            if group.pathIndex >= path.count {
                group.currentPath = nil
                group.pathIndex = 0

                // Clear moving task if that was the current task
                if case .moving = group.currentTask {
                    group.clearTask()
                }
            }
        }

        return changes
    }

    // MARK: - Reinforcement Movement

    private func updateReinforcementMovements(_ army: ArmyData, currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []
        var arrivedReinforcements: [UUID] = []

        for i in 0..<army.pendingReinforcements.count {
            var reinforcement = army.pendingReinforcements[i]

            guard reinforcement.pathIndex < reinforcement.path.count else {
                // Reinforcement has arrived
                arrivedReinforcements.append(reinforcement.reinforcementID)
                continue
            }

            // Calculate movement speed for reinforcements
            let targetCoord = reinforcement.path[reinforcement.pathIndex]
            var speed = baseMovementSpeed * 0.7  // 70% of base speed

            if state.mapData.getBuildingID(at: targetCoord) != nil {
                speed = baseMovementSpeed * 0.7
            } else {
                speed = baseMovementSpeed * 0.7 * terrainSpeedMultiplier
            }

            // Simple progress update
            reinforcement.pathIndex += 1
            reinforcement.currentCoordinate = targetCoord

            // Update in army using helper method
            army.updatePendingReinforcement(at: i, with: reinforcement)

            changes.append(.reinforcementProgress(
                reinforcementID: reinforcement.reinforcementID,
                currentCoordinate: targetCoord,
                progress: Double(reinforcement.pathIndex) / Double(reinforcement.path.count)
            ))

            // Check if arrived at target
            if reinforcement.currentCoordinate == army.coordinate || reinforcement.pathIndex >= reinforcement.path.count {
                arrivedReinforcements.append(reinforcement.reinforcementID)
            }
        }

        // Process arrived reinforcements
        for reinforcementID in arrivedReinforcements {
            if let reinforcement = army.pendingReinforcements.first(where: { $0.reinforcementID == reinforcementID }) {
                // Add units to army
                for (unitType, count) in reinforcement.unitComposition {
                    army.addMilitaryUnits(unitType, count: count)
                }

                // Remove from pending using helper method
                army.removePendingReinforcement(id: reinforcementID)

                changes.append(.reinforcementArrived(
                    reinforcementID: reinforcementID,
                    targetArmyID: army.id
                ))

                // Update army composition change
                var compositionDict: [String: Int] = [:]
                for (unitType, count) in army.militaryComposition {
                    compositionDict[unitType.rawValue] = count
                }
                changes.append(.armyCompositionChanged(armyID: army.id, newComposition: compositionDict))
            }
        }

        return changes
    }

    // MARK: - Path Calculation

    /// Calculate a path for an army
    func calculatePath(for armyID: UUID, to target: HexCoordinate) -> [HexCoordinate]? {
        guard let state = gameState,
              let army = state.getArmy(id: armyID) else {
            return nil
        }

        return state.mapData.findPath(
            from: army.coordinate,
            to: target,
            forPlayerID: army.ownerID,
            gameState: state
        )
    }

    /// Calculate a path for a villager group
    func calculatePath(forVillagerGroup groupID: UUID, to target: HexCoordinate) -> [HexCoordinate]? {
        guard let state = gameState,
              let group = state.getVillagerGroup(id: groupID) else {
            return nil
        }

        return state.mapData.findPath(
            from: group.coordinate,
            to: target,
            forPlayerID: group.ownerID,
            gameState: state
        )
    }

    /// Set a movement path for an army
    func setArmyPath(_ armyID: UUID, path: [HexCoordinate]) {
        guard let army = gameState?.getArmy(id: armyID) else { return }

        army.currentPath = path
        army.pathIndex = 0
        army.movementProgress = 0.0
    }

    /// Set a movement path for a villager group
    func setVillagerGroupPath(_ groupID: UUID, path: [HexCoordinate]) {
        guard let group = gameState?.getVillagerGroup(id: groupID) else { return }

        group.currentPath = path
        group.pathIndex = 0
        group.movementProgress = 0.0
        group.currentTask = .moving(targetCoordinate: path.last ?? group.coordinate)
    }

    /// Stop army movement
    func stopArmyMovement(_ armyID: UUID) {
        guard let army = gameState?.getArmy(id: armyID) else { return }

        army.currentPath = nil
        army.pathIndex = 0
        army.movementProgress = 0.0
        army.isRetreating = false
    }

    /// Stop villager group movement
    func stopVillagerGroupMovement(_ groupID: UUID) {
        guard let group = gameState?.getVillagerGroup(id: groupID) else { return }

        group.currentPath = nil
        group.pathIndex = 0
        group.movementProgress = 0.0

        if case .moving = group.currentTask {
            group.clearTask()
        }
    }
}
