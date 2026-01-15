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
              let target = context.hexMap.getEntity(at: targetCoordinate) else {
            return .failure(reason: "Required objects not found")
        }
        
        // Move to target and initiate combat
        // The actual combat resolution would happen in the game loop
        // For now, just set up the attack
        
        if let path = context.hexMap.findPath(from: attacker.coordinate, to: targetCoordinate) {
            attacker.moveTo(path: path) {
                print("⚔️ \(attackerArmy.name) arrived at attack position")
            }
        }
        
        print("⚔️ \(attackerArmy.name) attacking target at (\(targetCoordinate.q), \(targetCoordinate.r))")
        
        return .success
    }
}

