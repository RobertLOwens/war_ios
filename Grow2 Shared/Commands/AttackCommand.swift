// ============================================================================
// FILE: Grow2 Shared/Commands/AttackCommand.swift
// PURPOSE: Command to initiate combat
// ============================================================================

import Foundation

struct AttackCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let attackerEntityID: UUID
    let targetCoordinate: HexCoordinate
    
    static var commandType: CommandType { .attack }
    
    init(playerID: UUID, attackerEntityID: UUID, targetCoordinate: HexCoordinate) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.attackerEntityID = attackerEntityID
        self.targetCoordinate = targetCoordinate
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let attacker = context.getEntity(by: attackerEntityID) else {
            return .failure(reason: "Attacker not found")
        }

        guard attacker.entity.owner?.id == playerID else {
            return .failure(reason: "You don't own this unit")
        }

        guard attacker.entityType == .army else {
            return .failure(reason: "Only armies can attack")
        }

        // Check commander stamina
        if let army = attacker.entity as? Army, let commander = army.commander {
            if !commander.hasEnoughStamina() {
                return .failure(reason: "Commander \(commander.name) is too exhausted! (Stamina: \(Int(commander.stamina))/\(Int(Commander.maxStamina)))")
            }
        }

        // Check target has enemy
        guard let target = context.hexMap.getEntity(at: targetCoordinate) else {
            return .failure(reason: "No target at this location")
        }

        let player = context.getPlayer(by: playerID)
        let diplomacy = player?.getDiplomacyStatus(with: target.entity.owner) ?? .neutral
        guard diplomacy == .enemy else {
            return .failure(reason: "Target is not an enemy")
        }

        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let attacker = context.getEntity(by: attackerEntityID),
              let attackerArmy = attacker.entity as? Army,
              let target = context.hexMap.getEntity(at: targetCoordinate),
              let defenderArmy = target.entity as? Army else {
            return .failure(reason: "Required objects not found")
        }

        // Consume commander stamina for attack command
        if let commander = attackerArmy.commander {
            commander.consumeStamina()
        }

        // Store references for use in completion handler
        let hexMap = context.hexMap
        let targetCoord = targetCoordinate

        // Get terrain type at target location for combat modifiers
        let terrainType = hexMap.getTile(at: targetCoordinate)?.terrain ?? .plains

        if let path = hexMap.findPath(from: attacker.coordinate, to: targetCoordinate, for: attacker.entity.owner) {
            attacker.moveTo(path: path) {
                // Initiate combat when army arrives
                // Use the already-captured defenderArmy (not re-lookup, which would find the attacker)
                print("⚔️ \(attackerArmy.name) arrived - initiating combat!")
                let currentTime = Date().timeIntervalSince1970
                _ = GameEngine.shared.combatEngine.startCombat(
                    attackerArmyID: attackerArmy.id,
                    defenderArmyID: defenderArmy.id,
                    currentTime: currentTime
                )
            }
        }

        print("⚔️ \(attackerArmy.name) attacking target at (\(targetCoordinate.q), \(targetCoordinate.r))")

        return .success
    }
}

