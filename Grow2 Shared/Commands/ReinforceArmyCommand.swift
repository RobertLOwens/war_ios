// ============================================================================
// FILE: Grow2 Shared/Commands/ReinforceArmyCommand.swift
// PURPOSE: Command to send reinforcements from a building to an army
// NOTE: Units now march to the army instead of instant transfer
// ============================================================================

import Foundation

struct ReinforceArmyCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let buildingID: UUID
    let armyID: UUID
    let units: [MilitaryUnitType: Int]

    static var commandType: CommandType { .reinforceArmy }

    init(playerID: UUID, buildingID: UUID, armyID: UUID, units: [MilitaryUnitType: Int]) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
        self.armyID = armyID
        self.units = units
    }

    func validate(in context: CommandContext) -> CommandResult {
        // Check player exists
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Check building exists and is owned by player
        guard let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.owner?.id == playerID else {
            return .failure(reason: "You don't own this building")
        }

        // Check building is operational
        guard building.isOperational else {
            return .failure(reason: "Building is not operational")
        }

        // Check army exists and is owned by player
        guard let army = findArmy(id: armyID, in: context) else {
            return .failure(reason: "Army not found")
        }

        guard army.owner?.id == playerID else {
            return .failure(reason: "You don't own this army")
        }

        // Check we're actually transferring something
        let totalUnits = units.values.reduce(0, +)
        guard totalUnits > 0 else {
            return .failure(reason: "No units selected for transfer")
        }

        // Check building has enough of each unit type
        for (unitType, count) in units where count > 0 {
            let available = building.getGarrisonCount(of: unitType)
            if available < count {
                return .failure(reason: "Not enough \(unitType.displayName) in garrison (have \(available), need \(count))")
            }
        }

        // Check path exists from building to army
        guard context.hexMap.findPath(from: building.coordinate, to: army.coordinate) != nil else {
            return .failure(reason: "No path to army location")
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let building = context.getBuilding(by: buildingID),
              let army = findArmy(id: armyID, in: context),
              let player = context.getPlayer(by: playerID),
              let gameScene = context.gameScene else {
            return .failure(reason: "Building, army, or game scene not found")
        }

        // Find path from building to army
        guard let path = context.hexMap.findPath(from: building.coordinate, to: army.coordinate) else {
            return .failure(reason: "No path to army")
        }

        // Remove units from building garrison
        var actualUnits: [MilitaryUnitType: Int] = [:]
        var totalTransferred = 0
        var transferDetails: [String] = []

        for (unitType, count) in units where count > 0 {
            let actualRemoved = building.removeFromGarrison(unitType: unitType, quantity: count)
            if actualRemoved > 0 {
                actualUnits[unitType] = actualRemoved
                totalTransferred += actualRemoved
                transferDetails.append("\(actualRemoved)x \(unitType.displayName)")
            }
        }

        guard totalTransferred > 0 else {
            return .failure(reason: "No units were removed from garrison")
        }

        // Create reinforcement group
        let reinforcement = ReinforcementGroup(
            name: "Reinforcements to \(army.name)",
            sourceCoordinate: building.coordinate,
            targetArmy: army,
            sourceBuilding: building,
            units: actualUnits,
            owner: player
        )
        reinforcement.movementPath = path

        // Spawn reinforcement node and start movement
        gameScene.spawnReinforcementNode(reinforcement: reinforcement, path: path) { success in
            if success {
                print("✅ Reinforcements arrived at \(army.name)")
            } else {
                print("❌ Reinforcement delivery failed")
            }
        }

        print("🚶 Sent \(totalTransferred) units to reinforce \(army.name)")
        print("   Units: \(transferDetails.joined(separator: ", "))")
        print("   Path length: \(path.count) tiles")

        // Notify UI
        context.onAlert?("Reinforcements Dispatched", "\(totalTransferred) units marching to \(army.name)")

        return .success
    }

    // MARK: - Private Helpers

    private func findArmy(id: UUID, in context: CommandContext) -> Army? {
        // Search through all players' armies
        for player in context.allPlayers {
            if let army = player.getArmies().first(where: { $0.id == id }) {
                return army
            }
        }
        return nil
    }
}
