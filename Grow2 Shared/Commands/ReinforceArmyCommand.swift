// ============================================================================
// FILE: Grow2 Shared/Commands/ReinforceArmyCommand.swift
// PURPOSE: Command to transfer units from a building's garrison to an army
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
        guard context.getPlayer(by: playerID) != nil else {
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
        
        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let building = context.getBuilding(by: buildingID),
              let army = findArmy(id: armyID, in: context) else {
            return .failure(reason: "Building or army not found")
        }
        
        var totalTransferred = 0
        var transferDetails: [String] = []
        
        for (unitType, count) in units where count > 0 {
            // Remove from building garrison
            let actualRemoved = building.removeFromGarrison(unitType: unitType, quantity: count)
            
            if actualRemoved > 0 {
                // Add to army
                army.addMilitaryUnits(unitType, count: actualRemoved)
                totalTransferred += actualRemoved
                transferDetails.append("\(actualRemoved)x \(unitType.displayName)")
            }
        }
        
        if totalTransferred > 0 {
            print("✅ Reinforced \(army.name) with \(totalTransferred) units from \(building.buildingType.displayName)")
            print("   Units: \(transferDetails.joined(separator: ", "))")
            
            // Notify UI
            context.onAlert?("✅ Reinforcement Complete", "Transferred \(totalTransferred) units to \(army.name)")
        } else {
            return .failure(reason: "No units were transferred")
        }
        
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
