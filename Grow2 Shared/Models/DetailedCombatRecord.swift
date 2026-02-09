// ============================================================================
// FILE: DetailedCombatRecord.swift
// LOCATION: Grow2 Shared/DetailedCombatRecord.swift
// PURPOSE: Enhanced combat record structures for phase-by-phase battle reports
// ============================================================================

import Foundation

// MARK: - Combat Phase Record

/// Records statistics for a single phase of combat
struct CombatPhaseRecord: Codable {
    let phase: CombatPhase
    let duration: TimeInterval
    let attackerDamageDealt: Double
    let defenderDamageDealt: Double
    let attackerCasualtiesByType: [String: Int]  // MilitaryUnitType.rawValue -> count
    let defenderCasualtiesByType: [String: Int]

    init(
        phase: CombatPhase,
        duration: TimeInterval,
        attackerDamageDealt: Double,
        defenderDamageDealt: Double,
        attackerCasualties: [MilitaryUnitType: Int],
        defenderCasualties: [MilitaryUnitType: Int]
    ) {
        self.phase = phase
        self.duration = duration
        self.attackerDamageDealt = attackerDamageDealt
        self.defenderDamageDealt = defenderDamageDealt

        // Convert to string keys for Codable compatibility
        var attackerDict: [String: Int] = [:]
        for (unitType, count) in attackerCasualties {
            attackerDict[unitType.rawValue] = count
        }
        self.attackerCasualtiesByType = attackerDict

        var defenderDict: [String: Int] = [:]
        for (unitType, count) in defenderCasualties {
            defenderDict[unitType.rawValue] = count
        }
        self.defenderCasualtiesByType = defenderDict
    }

    /// Get casualties as MilitaryUnitType dictionary
    func getAttackerCasualties() -> [MilitaryUnitType: Int] {
        var result: [MilitaryUnitType: Int] = [:]
        for (key, value) in attackerCasualtiesByType {
            if let unitType = MilitaryUnitType(rawValue: key) {
                result[unitType] = value
            }
        }
        return result
    }

    func getDefenderCasualties() -> [MilitaryUnitType: Int] {
        var result: [MilitaryUnitType: Int] = [:]
        for (key, value) in defenderCasualtiesByType {
            if let unitType = MilitaryUnitType(rawValue: key) {
                result[unitType] = value
            }
        }
        return result
    }
}

// MARK: - Unit Combat Breakdown

/// Records combat statistics for a specific unit type
struct UnitCombatBreakdown: Codable {
    let unitTypeRaw: String  // MilitaryUnitType.rawValue
    let initialCount: Int
    let finalCount: Int
    let casualties: Int
    let damageDealt: Double
    let damageReceived: Double

    var unitType: MilitaryUnitType? {
        return MilitaryUnitType(rawValue: unitTypeRaw)
    }

    init(
        unitType: MilitaryUnitType,
        initialCount: Int,
        finalCount: Int,
        casualties: Int,
        damageDealt: Double,
        damageReceived: Double
    ) {
        self.unitTypeRaw = unitType.rawValue
        self.initialCount = initialCount
        self.finalCount = finalCount
        self.casualties = casualties
        self.damageDealt = damageDealt
        self.damageReceived = damageReceived
    }
}

// MARK: - Army Combat Breakdown

/// Records combat statistics for a specific army in a multi-army battle
struct ArmyCombatBreakdown: Codable {
    let armyID: String
    let armyName: String
    let ownerName: String
    let commanderName: String?
    let joinTime: TimeInterval
    let wasReinforcement: Bool
    let initialComposition: [String: Int]   // MilitaryUnitType.rawValue -> count
    let finalComposition: [String: Int]
    let casualtiesByType: [String: Int]
    let damageDealtByType: [String: Double]
    let totalDamageDealt: Double
    let totalCasualties: Int

    init(
        armyID: UUID,
        armyName: String,
        ownerName: String,
        commanderName: String?,
        joinTime: TimeInterval,
        wasReinforcement: Bool,
        initialComposition: [MilitaryUnitType: Int],
        finalComposition: [MilitaryUnitType: Int],
        casualtiesByType: [MilitaryUnitType: Int],
        damageDealtByType: [MilitaryUnitType: Double]
    ) {
        self.armyID = armyID.uuidString
        self.armyName = armyName
        self.ownerName = ownerName
        self.commanderName = commanderName
        self.joinTime = joinTime
        self.wasReinforcement = wasReinforcement

        // Convert to string-keyed dictionaries
        var initialDict: [String: Int] = [:]
        for (unitType, count) in initialComposition {
            initialDict[unitType.rawValue] = count
        }
        self.initialComposition = initialDict

        var finalDict: [String: Int] = [:]
        for (unitType, count) in finalComposition {
            finalDict[unitType.rawValue] = count
        }
        self.finalComposition = finalDict

        var casualtiesDict: [String: Int] = [:]
        for (unitType, count) in casualtiesByType {
            casualtiesDict[unitType.rawValue] = count
        }
        self.casualtiesByType = casualtiesDict

        var damageDict: [String: Double] = [:]
        for (unitType, damage) in damageDealtByType {
            damageDict[unitType.rawValue] = damage
        }
        self.damageDealtByType = damageDict

        self.totalDamageDealt = damageDealtByType.values.reduce(0.0, +)
        self.totalCasualties = casualtiesByType.values.reduce(0, +)
    }

    // Helper methods
    func getInitialComposition() -> [MilitaryUnitType: Int] {
        var result: [MilitaryUnitType: Int] = [:]
        for (key, value) in initialComposition {
            if let unitType = MilitaryUnitType(rawValue: key) {
                result[unitType] = value
            }
        }
        return result
    }

    func getFinalComposition() -> [MilitaryUnitType: Int] {
        var result: [MilitaryUnitType: Int] = [:]
        for (key, value) in finalComposition {
            if let unitType = MilitaryUnitType(rawValue: key) {
                result[unitType] = value
            }
        }
        return result
    }

    func getCasualtiesByType() -> [MilitaryUnitType: Int] {
        var result: [MilitaryUnitType: Int] = [:]
        for (key, value) in casualtiesByType {
            if let unitType = MilitaryUnitType(rawValue: key) {
                result[unitType] = value
            }
        }
        return result
    }
}

// MARK: - Detailed Combat Record

/// Enhanced combat record with phase-by-phase and unit-by-unit breakdown
struct DetailedCombatRecord: Codable {
    let id: UUID
    let timestamp: Date
    let location: HexCoordinate
    let totalDuration: TimeInterval
    let winner: CombatResult

    // Terrain information
    let terrainType: String
    let terrainDefenseBonus: Double
    let terrainAttackPenalty: Double
    let entrenchmentDefenseBonus: Double

    // Attacker information
    let attackerName: String
    let attackerOwner: String
    let attackerCommander: String?
    let attackerCommanderSpecialty: String?  // CommanderSpecialtyData.rawValue
    let attackerInitialComposition: [String: Int]  // MilitaryUnitType.rawValue -> count
    let attackerFinalComposition: [String: Int]

    // Defender information
    let defenderName: String
    let defenderOwner: String
    let defenderCommander: String?
    let defenderCommanderSpecialty: String?  // CommanderSpecialtyData.rawValue
    let defenderInitialComposition: [String: Int]
    let defenderFinalComposition: [String: Int]

    // Phase breakdown
    let phaseRecords: [CombatPhaseRecord]

    // Unit breakdown
    let attackerUnitBreakdowns: [UnitCombatBreakdown]
    let defenderUnitBreakdowns: [UnitCombatBreakdown]

    // Army breakdown (for multi-army combats)
    let attackerArmyBreakdowns: [ArmyCombatBreakdown]
    let defenderArmyBreakdowns: [ArmyCombatBreakdown]

    // MARK: - Computed Properties

    /// Number of armies that participated on attacker side
    var attackerArmyCount: Int {
        return attackerArmyBreakdowns.count
    }

    /// Number of armies that participated on defender side
    var defenderArmyCount: Int {
        return defenderArmyBreakdowns.count
    }

    /// Whether this was a multi-army battle
    var isMultiArmyBattle: Bool {
        return attackerArmyBreakdowns.count > 1 || defenderArmyBreakdowns.count > 1
    }

    var attackerTotalCasualties: Int {
        return attackerUnitBreakdowns.reduce(0) { $0 + $1.casualties }
    }

    var defenderTotalCasualties: Int {
        return defenderUnitBreakdowns.reduce(0) { $0 + $1.casualties }
    }

    var attackerTotalDamageDealt: Double {
        return attackerUnitBreakdowns.reduce(0.0) { $0 + $1.damageDealt }
    }

    var defenderTotalDamageDealt: Double {
        return defenderUnitBreakdowns.reduce(0.0) { $0 + $1.damageDealt }
    }

    var attackerInitialStrength: Int {
        return attackerInitialComposition.values.reduce(0, +)
    }

    var defenderInitialStrength: Int {
        return defenderInitialComposition.values.reduce(0, +)
    }

    var attackerFinalStrength: Int {
        return attackerFinalComposition.values.reduce(0, +)
    }

    var defenderFinalStrength: Int {
        return defenderFinalComposition.values.reduce(0, +)
    }

    // MARK: - Initializer

    init(
        location: HexCoordinate,
        totalDuration: TimeInterval,
        winner: CombatResult,
        terrainType: TerrainType = .plains,
        terrainDefenseBonus: Double = 0.0,
        terrainAttackPenalty: Double = 0.0,
        entrenchmentDefenseBonus: Double = 0.0,
        attackerName: String,
        attackerOwner: String,
        attackerCommander: String?,
        attackerCommanderSpecialty: String? = nil,
        attackerInitialComposition: [MilitaryUnitType: Int],
        attackerFinalComposition: [MilitaryUnitType: Int],
        defenderName: String,
        defenderOwner: String,
        defenderCommander: String?,
        defenderCommanderSpecialty: String? = nil,
        defenderInitialComposition: [MilitaryUnitType: Int],
        defenderFinalComposition: [MilitaryUnitType: Int],
        phaseRecords: [CombatPhaseRecord],
        attackerUnitBreakdowns: [UnitCombatBreakdown],
        defenderUnitBreakdowns: [UnitCombatBreakdown],
        attackerArmyBreakdowns: [ArmyCombatBreakdown] = [],
        defenderArmyBreakdowns: [ArmyCombatBreakdown] = []
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.location = location
        self.totalDuration = totalDuration
        self.winner = winner
        self.terrainType = terrainType.rawValue
        self.terrainDefenseBonus = terrainDefenseBonus
        self.terrainAttackPenalty = terrainAttackPenalty
        self.entrenchmentDefenseBonus = entrenchmentDefenseBonus
        self.attackerName = attackerName
        self.attackerOwner = attackerOwner
        self.attackerCommander = attackerCommander
        self.attackerCommanderSpecialty = attackerCommanderSpecialty
        self.defenderName = defenderName
        self.defenderOwner = defenderOwner
        self.defenderCommander = defenderCommander
        self.defenderCommanderSpecialty = defenderCommanderSpecialty
        self.phaseRecords = phaseRecords
        self.attackerUnitBreakdowns = attackerUnitBreakdowns
        self.defenderUnitBreakdowns = defenderUnitBreakdowns
        self.attackerArmyBreakdowns = attackerArmyBreakdowns
        self.defenderArmyBreakdowns = defenderArmyBreakdowns

        // Convert compositions to string-keyed dictionaries
        var attackerInitial: [String: Int] = [:]
        for (unitType, count) in attackerInitialComposition {
            attackerInitial[unitType.rawValue] = count
        }
        self.attackerInitialComposition = attackerInitial

        var attackerFinal: [String: Int] = [:]
        for (unitType, count) in attackerFinalComposition {
            attackerFinal[unitType.rawValue] = count
        }
        self.attackerFinalComposition = attackerFinal

        var defenderInitial: [String: Int] = [:]
        for (unitType, count) in defenderInitialComposition {
            defenderInitial[unitType.rawValue] = count
        }
        self.defenderInitialComposition = defenderInitial

        var defenderFinal: [String: Int] = [:]
        for (unitType, count) in defenderFinalComposition {
            defenderFinal[unitType.rawValue] = count
        }
        self.defenderFinalComposition = defenderFinal
    }

    // MARK: - Helper Methods

    func getAttackerInitialComposition() -> [MilitaryUnitType: Int] {
        var result: [MilitaryUnitType: Int] = [:]
        for (key, value) in attackerInitialComposition {
            if let unitType = MilitaryUnitType(rawValue: key) {
                result[unitType] = value
            }
        }
        return result
    }

    func getAttackerFinalComposition() -> [MilitaryUnitType: Int] {
        var result: [MilitaryUnitType: Int] = [:]
        for (key, value) in attackerFinalComposition {
            if let unitType = MilitaryUnitType(rawValue: key) {
                result[unitType] = value
            }
        }
        return result
    }

    func getDefenderInitialComposition() -> [MilitaryUnitType: Int] {
        var result: [MilitaryUnitType: Int] = [:]
        for (key, value) in defenderInitialComposition {
            if let unitType = MilitaryUnitType(rawValue: key) {
                result[unitType] = value
            }
        }
        return result
    }

    func getDefenderFinalComposition() -> [MilitaryUnitType: Int] {
        var result: [MilitaryUnitType: Int] = [:]
        for (key, value) in defenderFinalComposition {
            if let unitType = MilitaryUnitType(rawValue: key) {
                result[unitType] = value
            }
        }
        return result
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
        let winnerName = winner == .attackerVictory ? attackerName : defenderName
        return "\(attackerName) vs \(defenderName) - \(winnerName) Victory"
    }

    func getTerrainDisplayName() -> String {
        return TerrainType(rawValue: terrainType)?.displayName ?? terrainType.capitalized
    }

    func getTerrainModifierDescription() -> String {
        var parts: [String] = []
        if terrainDefenseBonus > 0 {
            parts.append("Defender +\(Int(terrainDefenseBonus * 100))% defense")
        } else if terrainDefenseBonus < 0 {
            parts.append("Defender \(Int(terrainDefenseBonus * 100))% defense")
        }
        if terrainAttackPenalty > 0 {
            parts.append("Attacker -\(Int(terrainAttackPenalty * 100))% attack")
        }
        if entrenchmentDefenseBonus > 0 {
            parts.append("Entrenched +\(Int(entrenchmentDefenseBonus * 100))% defense")
        }
        if parts.isEmpty { return "No terrain effects" }
        var result = parts.joined(separator: ", ")
        if terrainDefenseBonus > 0 && entrenchmentDefenseBonus > 0 {
            let total = Int((terrainDefenseBonus + entrenchmentDefenseBonus) * 100)
            result += " (Combined: +\(total)%)"
        }
        return result
    }

    var hasTerrainModifiers: Bool {
        return terrainDefenseBonus != 0 || terrainAttackPenalty != 0 || entrenchmentDefenseBonus != 0
    }

    func getFormattedDuration() -> String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - CombatResult Codable Extension

extension CombatResult: Codable {
    enum CodingKeys: String, CodingKey {
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "attackerVictory": self = .attackerVictory
        case "defenderVictory": self = .defenderVictory
        case "draw": self = .draw
        default: self = .draw
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .attackerVictory: try container.encode("attackerVictory")
        case .defenderVictory: try container.encode("defenderVictory")
        case .draw: try container.encode("draw")
        }
    }
}

// MARK: - CombatPhase Codable Extension

// CombatPhase is already Codable via rawValue in CombatState.swift
