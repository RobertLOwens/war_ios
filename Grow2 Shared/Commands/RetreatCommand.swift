// ============================================================================
// FILE: Grow2 Shared/Commands/RetreatCommand.swift
// PURPOSE: Command to retreat an army to its home base with speed bonus
// ============================================================================

import Foundation

struct RetreatCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let armyID: UUID

    static var commandType: CommandType { .retreat }

    init(playerID: UUID, armyID: UUID) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.armyID = armyID
    }

    func validate(in context: CommandContext) -> CommandResult {
        // Check player owns this army
        guard let entity = context.getEntity(by: armyID) else {
            return .failure(reason: "Army not found")
        }

        guard entity.entity.owner?.id == playerID else {
            return .failure(reason: "You don't own this army")
        }

        guard let army = entity.armyReference else {
            return .failure(reason: "Entity is not an army")
        }

        // Check army has a home base
        guard let homeBaseID = army.homeBaseID else {
            return .failure(reason: "No home base set. Move to a City Center, Fort, or Castle first.")
        }

        // Check home base still exists
        guard let homeBase = context.getBuilding(by: homeBaseID) else {
            return .failure(reason: "Home base has been destroyed")
        }

        // Check home base is still owned by same player
        guard homeBase.owner?.id == playerID else {
            return .failure(reason: "Home base no longer belongs to you")
        }

        // Check home base is still operational
        guard homeBase.data.isOperational else {
            return .failure(reason: "Home base is not operational")
        }

        // Note: Retreat is now allowed during combat - army will disengage immediately

        // Check commander stamina
        if let commander = army.commander {
            if !commander.hasEnoughStamina() {
                return .failure(reason: "Commander \(commander.name) is too exhausted! (Stamina: \(Int(commander.stamina))/\(Int(Commander.maxStamina)))")
            }
        }

        // Check army isn't already at home base
        if army.coordinate == homeBase.coordinate {
            return .failure(reason: "Already at home base")
        }

        // Check army isn't currently moving
        if entity.isMoving {
            return .failure(reason: "Army is already moving")
        }

        // Check army isn't awaiting reinforcements
        if army.isAwaitingReinforcements {
            return .failure(reason: "Cannot retreat while reinforcements are en route")
        }

        // Check path exists to home base (pass owner for wall/gate checks)
        guard context.hexMap.findPath(from: army.coordinate, to: homeBase.coordinate, for: army.owner) != nil else {
            return .failure(reason: "No valid path to home base")
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let entity = context.getEntity(by: armyID),
              let army = entity.armyReference,
              let homeBaseID = army.homeBaseID,
              let homeBase = context.getBuilding(by: homeBaseID) else {
            return .failure(reason: "Required objects not found")
        }

        // If army is in combat, disengage immediately
        if CombatSystem.shared.isInCombat(army) {
            CombatSystem.shared.retreatFromCombat(army: army)
            print("⚔️➡️🏃 Army \(army.name) disengaging from combat to retreat!")
        }

        // Find path to home base (pass owner for wall/gate checks)
        guard let path = context.hexMap.findPath(from: army.coordinate, to: homeBase.coordinate, for: army.owner) else {
            return .failure(reason: "No valid path to home base")
        }

        // Consume commander stamina for retreat command
        if let commander = army.commander {
            commander.consumeStamina()
        }

        // Set retreating flag for speed bonus
        army.isRetreating = true

        // Start movement
        entity.moveTo(path: path) {
            print("🏠 Army \(army.name) arrived at home base")
        }

        print("🏃 Army \(army.name) retreating to \(homeBase.buildingType.displayName) at (\(homeBase.coordinate.q), \(homeBase.coordinate.r)) with 10% speed bonus")

        return .success
    }
}
