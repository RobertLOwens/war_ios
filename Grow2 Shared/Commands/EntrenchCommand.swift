// ============================================================================
// FILE: Grow2 Shared/Commands/EntrenchCommand.swift
// PURPOSE: Command to entrench an army at its current position for defense bonus
// ============================================================================

import Foundation

struct EntrenchCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID

    let armyID: UUID

    static var commandType: CommandType { .entrench }

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

        // Check not already entrenched or entrenching
        if army.isEntrenched {
            return .failure(reason: "Army is already entrenched")
        }
        if army.isEntrenching {
            return .failure(reason: "Army is already building entrenchment")
        }

        // Check army is not moving
        if entity.isMoving {
            return .failure(reason: "Cannot entrench while moving")
        }

        // Check army is not in combat
        if GameEngine.shared.combatEngine.isInCombat(armyID: army.id) {
            return .failure(reason: "Cannot entrench while in combat")
        }

        // Check army is not retreating
        if army.isRetreating {
            return .failure(reason: "Cannot entrench while retreating")
        }

        // Check army is not awaiting reinforcements
        if army.isAwaitingReinforcements {
            return .failure(reason: "Cannot entrench while reinforcements are en route")
        }

        // Check commander stamina
        if let commander = army.commander {
            if !commander.hasEnoughStamina() {
                return .failure(reason: "Commander \(commander.name) is too exhausted! (Stamina: \(Int(commander.stamina))/\(Int(Commander.maxStamina)))")
            }
        }

        // Check player has enough wood
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }
        if player.getResource(.wood) < GameConfig.Entrenchment.woodCost {
            return .failure(reason: "Not enough wood (\(GameConfig.Entrenchment.woodCost) required)")
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let entity = context.getEntity(by: armyID),
              let army = entity.armyReference else {
            return .failure(reason: "Army not found")
        }

        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Deduct wood cost
        player.removeResource(.wood, amount: GameConfig.Entrenchment.woodCost)

        // Consume commander stamina
        if let commander = army.commander {
            commander.consumeStamina()
        }

        // Set entrenching state
        army.data.isEntrenching = true
        army.data.entrenchmentStartTime = GameEngine.shared.gameState?.currentTime ?? Date().timeIntervalSince1970

        debugLog("🪖 Army \(army.name) started entrenching at (\(army.coordinate.q), \(army.coordinate.r))")

        return .success
    }
}
