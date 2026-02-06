// ============================================================================
// FILE: CombatRecord.swift
// LOCATION: Create this as a NEW FILE
// ============================================================================

import Foundation
import UIKit

// MARK: - Combat Record

struct CombatRecord {
    let id: UUID
    let timestamp: Date
    
    // Participants
    let attacker: CombatParticipant
    let defender: CombatParticipant
    
    // Combat stats
    let attackerInitialStrength: Double
    let defenderInitialStrength: Double
    let attackerFinalStrength: Double
    let defenderFinalStrength: Double
    
    // Results
    let winner: CombatResult
    let attackerCasualties: Int
    let defenderCasualties: Int
    let duration: TimeInterval
    
    // Location
    let location: HexCoordinate
    
    init(
        attacker: CombatParticipant,
        defender: CombatParticipant,
        attackerInitialStrength: Double,
        defenderInitialStrength: Double,
        attackerFinalStrength: Double,
        defenderFinalStrength: Double,
        winner: CombatResult,
        attackerCasualties: Int,
        defenderCasualties: Int,
        location: HexCoordinate,
        duration: TimeInterval = 5.0
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.attacker = attacker
        self.defender = defender
        self.attackerInitialStrength = attackerInitialStrength
        self.defenderInitialStrength = defenderInitialStrength
        self.attackerFinalStrength = attackerFinalStrength
        self.defenderFinalStrength = defenderFinalStrength
        self.winner = winner
        self.attackerCasualties = attackerCasualties
        self.defenderCasualties = defenderCasualties
        self.location = location
        self.duration = duration
    }
    
    func getFormattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    func getFormattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: timestamp)
    }
    
    func getSummary() -> String {
        let winnerName = winner == .attackerVictory ? attacker.name : defender.name
        return "\(attacker.name) vs \(defender.name) - \(winnerName) Victory"
    }
}

// MARK: - Combat Participant

struct CombatParticipant {
    let name: String
    let type: CombatParticipantType
    let ownerName: String
    let ownerColor: UIColor
    let commanderName: String?
}

enum CombatParticipantType {
    case army
    case building
    case villagerGroup
    
    var icon: String {
        switch self {
        case .army: return "🛡️"
        case .building: return "🏰"
        case .villagerGroup: return "👷"
        }
    }
}

// MARK: - Combat Result

enum CombatResult {
    case attackerVictory
    case defenderVictory
    case draw
    
    var displayName: String {
        switch self {
        case .attackerVictory: return "Attacker Victory"
        case .defenderVictory: return "Defender Victory"
        case .draw: return "Draw"
        }
    }
}
