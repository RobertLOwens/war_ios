import Foundation
import SpriteKit
import UIKit

class CombatSystem {
    
    static let shared = CombatSystem()
    private(set) var combatHistory: [CombatRecord] = []
    
    // Simple combat calculation
    func calculateCombat(
        attacker: Army,
        defender: Any, // Can be Army, BuildingNode, or VillagerGroup
        defenderCoordinate: HexCoordinate
    ) -> CombatRecord {
        
        let attackerStrength = attacker.getModifiedStrength()
        let attackerDefense = attacker.getModifiedDefense()
        
        var defenderStrength = 0.0
        var defenderDefense = 0.0
        var defenderName = ""
        var defenderType: CombatParticipantType = .army
        var defenderOwner: Player? = nil
        
        // Determine defender type and stats
        if let defenderArmy = defender as? Army {
            defenderStrength = defenderArmy.getModifiedStrength()
            defenderDefense = defenderArmy.getModifiedDefense()
            defenderName = defenderArmy.name
            defenderType = .army
            defenderOwner = defenderArmy.owner
            
        } else if let building = defender as? BuildingNode {
            // Buildings get defensive bonus
            defenderStrength = building.health / 10
            defenderDefense = building.health / 5
            defenderName = building.buildingType.displayName
            defenderType = .building
            defenderOwner = building.owner
        } else if let villagers = defender as? VillagerGroup {
            // Villagers are weak in combat
            defenderStrength = Double(villagers.villagerCount * 2)
            defenderDefense = Double(villagers.villagerCount)
            defenderName = villagers.name
            defenderType = .villagerGroup
            defenderOwner = villagers.owner
        }
        
        // Combat calculation
        // Damage = (Attacker Strength - Defender Defense) with minimum of 1
        let attackerDamage = max(1, attackerStrength - defenderDefense)
        let defenderDamage = max(1, defenderStrength - attackerDefense)
        
        // Calculate casualties (simplified - percentage based)
        let totalAttackerUnits = attacker.getTotalUnits()
        let attackerCasualtyRate = Double(defenderDamage) / Double(attackerStrength + 1)
        let attackerCasualties = Int(Double(totalAttackerUnits) * attackerCasualtyRate * 0.3) // Max 30% casualties
        
        var defenderCasualties = 0
        if let defenderArmy = defender as? Army {
            let totalDefenderUnits = defenderArmy.getTotalUnits()
            let defenderCasualtyRate = Double(attackerDamage) / Double(defenderStrength + 1)
            defenderCasualties = Int(Double(totalDefenderUnits) * defenderCasualtyRate * 0.3)
        } else if let building = defender as? BuildingNode {
            defenderCasualties = Int(attackerDamage * 10) // Damage to building
        } else if let villagers = defender as? VillagerGroup {
            let casualtyRate = Double(attackerDamage) / Double(defenderStrength + 1)
            defenderCasualties = Int(Double(villagers.villagerCount) * casualtyRate * 0.5)
        }
        
        // Determine winner
        let winner: CombatResult
        if attackerDamage > defenderDamage * 1.2 {
            winner = .attackerVictory
        } else if defenderDamage > attackerDamage * 1.2 {
            winner = .defenderVictory
        } else {
            winner = .draw
        }
        
        // Create combat record
        let attackerParticipant = CombatParticipant(
            name: attacker.name,
            type: .army,
            ownerName: attacker.owner?.name ?? "Unknown",
            ownerColor: attacker.owner?.color ?? .gray,
            commanderName: attacker.commander?.name
        )
        
        let defenderParticipant = CombatParticipant(
            name: defenderName,
            type: defenderType,
            ownerName: defenderOwner?.name ?? "Unknown",
            ownerColor: defenderOwner?.color ?? .gray,
            commanderName: (defender as? Army)?.commander?.name
        )
        
        let record = CombatRecord(
            attacker: attackerParticipant,
            defender: defenderParticipant,
            attackerInitialStrength: attackerStrength,
            defenderInitialStrength: defenderStrength,
            attackerFinalStrength: max(0, attackerStrength - defenderDamage),
            defenderFinalStrength: max(0, defenderStrength - attackerDamage),
            winner: winner,
            attackerCasualties: attackerCasualties,
            defenderCasualties: defenderCasualties,
            location: defenderCoordinate
        )
        
        combatHistory.insert(record, at: 0) // Add to beginning for recent-first
        
        return record
    }
    
    func applyCombatResults(
        record: CombatRecord,
        attacker: Army,
        defender: Any
    ) {
        // Apply casualties to attacker
        applyCasualties(to: attacker, casualties: record.attackerCasualties)
        
        // Apply casualties to defender
        if let defenderArmy = defender as? Army {
            applyCasualties(to: defenderArmy, casualties: record.defenderCasualties)
        } else if let building = defender as? BuildingNode {
            building.takeDamage(Double(record.defenderCasualties))
        } else if let villagers = defender as? VillagerGroup {
            villagers.removeVillagers(count: record.defenderCasualties)
        }
        
        // Award XP to commanders
        if let attackerCommander = attacker.commander {
            let xpGain = record.winner == .attackerVictory ? 50 : 25
            attackerCommander.addExperience(xpGain)
        }
        
        if let defenderArmy = defender as? Army,
           let defenderCommander = defenderArmy.commander {
            let xpGain = record.winner == .defenderVictory ? 50 : 25
            defenderCommander.addExperience(xpGain)
        }
    }
    
    private func applyCasualties(to army: Army, casualties: Int) {
        var remainingCasualties = casualties
        
        // Remove from new military system first
        for (unitType, count) in army.militaryComposition.sorted(by: { $0.key.displayName < $1.key.displayName }) {
            if remainingCasualties <= 0 { break }
            let toRemove = min(count, remainingCasualties)
            army.removeMilitaryUnits(unitType, count: toRemove)
            remainingCasualties -= toRemove
        }
    }
}
