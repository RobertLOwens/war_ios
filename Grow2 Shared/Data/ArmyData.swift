// ============================================================================
// FILE: Grow2 Shared/Data/ArmyData.swift
// PURPOSE: Pure data model for armies - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Military Unit Type Data

/// Pure data representation of military unit types
enum MilitaryUnitTypeData: String, Codable, CaseIterable {
    case swordsman
    case archer
    case crossbow
    case pikeman
    case knight
    case heavyCavalry
    case mangonel
    case trebuchet

    var displayName: String {
        switch self {
        case .swordsman: return "Swordsman"
        case .archer: return "Archer"
        case .crossbow: return "Crossbow"
        case .pikeman: return "Pikeman"
        case .knight: return "Knight"
        case .heavyCavalry: return "Heavy Cavalry"
        case .mangonel: return "Mangonel"
        case .trebuchet: return "Trebuchet"
        }
    }

    var category: UnitCategoryData {
        switch self {
        case .swordsman, .pikeman: return .infantry
        case .archer, .crossbow: return .ranged
        case .knight, .heavyCavalry: return .cavalry
        case .mangonel, .trebuchet: return .siege
        }
    }

    /// Combat stats for the new damage/armor system
    var combatStats: UnitCombatStatsData {
        switch self {
        case .swordsman:
            return UnitCombatStatsData(
                meleeDamage: 12, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 10, pierceArmor: 6, bludgeonArmor: 5,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .archer:
            return UnitCombatStatsData(
                meleeDamage: 0, pierceDamage: 12, bludgeonDamage: 0,
                meleeArmor: 3, pierceArmor: 3, bludgeonArmor: 0,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .crossbow:
            return UnitCombatStatsData(
                meleeDamage: 0, pierceDamage: 14, bludgeonDamage: 0,
                meleeArmor: 3, pierceArmor: 7, bludgeonArmor: 0,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .pikeman:
            return UnitCombatStatsData(
                meleeDamage: 6, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 4, pierceArmor: 3, bludgeonArmor: 3,
                bonusVsInfantry: 0, bonusVsCavalry: 15, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .knight:
            return UnitCombatStatsData(
                meleeDamage: 14, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 8, pierceArmor: 5, bludgeonArmor: 4,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .heavyCavalry:
            return UnitCombatStatsData(
                meleeDamage: 18, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 12, pierceArmor: 8, bludgeonArmor: 6,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .mangonel:
            return UnitCombatStatsData(
                meleeDamage: 0, pierceDamage: 0, bludgeonDamage: 18,
                meleeArmor: 6, pierceArmor: 10, bludgeonArmor: 6,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 20
            )
        case .trebuchet:
            return UnitCombatStatsData(
                meleeDamage: 0, pierceDamage: 0, bludgeonDamage: 25,
                meleeArmor: 5, pierceArmor: 12, bludgeonArmor: 5,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 35
            )
        }
    }

    /// Hit points for this unit type
    var hp: Double {
        switch self {
        case .swordsman:  return 120  // Tanky infantry
        case .archer:     return 70   // Fragile ranged
        case .crossbow:   return 85   // Armored ranged
        case .pikeman:    return 100  // Standard infantry
        case .knight:     return 140  // Heavy cavalry
        case .heavyCavalry: return 160 // Very heavy cavalry
        case .mangonel:   return 150  // Siege - tanky but slow
        case .trebuchet:  return 180  // Heavy siege
        }
    }

    var trainingTime: TimeInterval {
        switch self {
        case .swordsman: return 15
        case .archer: return 12
        case .crossbow: return 18
        case .pikeman: return 14
        case .knight: return 25
        case .heavyCavalry: return 35
        case .mangonel: return 45
        case .trebuchet: return 60
        }
    }

    var trainingCost: [ResourceTypeData: Int] {
        switch self {
        case .swordsman: return [.food: 50, .ore: 25]
        case .archer: return [.food: 40, .wood: 30]
        case .crossbow: return [.food: 50, .wood: 40, .ore: 20]
        case .pikeman: return [.food: 45, .wood: 20, .ore: 15]
        case .knight: return [.food: 80, .ore: 60]
        case .heavyCavalry: return [.food: 100, .ore: 80]
        case .mangonel: return [.food: 60, .wood: 100, .ore: 40]
        case .trebuchet: return [.food: 80, .wood: 150, .ore: 60]
        }
    }

    var trainingBuilding: String {
        switch self {
        case .swordsman, .pikeman: return "barracks"
        case .archer, .crossbow: return "archeryRange"
        case .knight, .heavyCavalry: return "stable"
        case .mangonel, .trebuchet: return "siegeWorkshop"
        }
    }
}

// MARK: - Unit Category Data

enum UnitCategoryData: String, Codable, CaseIterable {
    case infantry
    case ranged
    case cavalry
    case siege
}

// MARK: - Unit Combat Stats Data

struct UnitCombatStatsData: Codable {
    var meleeDamage: Double
    var pierceDamage: Double
    var bludgeonDamage: Double

    var meleeArmor: Double
    var pierceArmor: Double
    var bludgeonArmor: Double

    var bonusVsInfantry: Double
    var bonusVsCavalry: Double
    var bonusVsRanged: Double
    var bonusVsSiege: Double
    var bonusVsBuildings: Double

    init(
        meleeDamage: Double = 0,
        pierceDamage: Double = 0,
        bludgeonDamage: Double = 0,
        meleeArmor: Double = 0,
        pierceArmor: Double = 0,
        bludgeonArmor: Double = 0,
        bonusVsInfantry: Double = 0,
        bonusVsCavalry: Double = 0,
        bonusVsRanged: Double = 0,
        bonusVsSiege: Double = 0,
        bonusVsBuildings: Double = 0
    ) {
        self.meleeDamage = meleeDamage
        self.pierceDamage = pierceDamage
        self.bludgeonDamage = bludgeonDamage
        self.meleeArmor = meleeArmor
        self.pierceArmor = pierceArmor
        self.bludgeonArmor = bludgeonArmor
        self.bonusVsInfantry = bonusVsInfantry
        self.bonusVsCavalry = bonusVsCavalry
        self.bonusVsRanged = bonusVsRanged
        self.bonusVsSiege = bonusVsSiege
        self.bonusVsBuildings = bonusVsBuildings
    }

    /// Total raw damage output (sum of all damage types)
    var totalDamage: Double {
        return meleeDamage + pierceDamage + bludgeonDamage
    }

    /// Average armor across all types
    var averageArmor: Double {
        return (meleeArmor + pierceArmor + bludgeonArmor) / 3.0
    }

    /// Calculates effective damage against a target's armor, applying per-damage-type reduction
    func calculateEffectiveDamage(against targetArmor: UnitCombatStatsData, targetCategory: UnitCategoryData?) -> Double {
        // Apply armor reduction per damage type
        let effectiveMelee = max(0, meleeDamage - targetArmor.meleeArmor)
        let effectivePierce = max(0, pierceDamage - targetArmor.pierceArmor)
        let effectiveBludgeon = max(0, bludgeonDamage - targetArmor.bludgeonArmor)

        var total = effectiveMelee + effectivePierce + effectiveBludgeon

        // Apply category bonuses
        if let category = targetCategory {
            switch category {
            case .cavalry:
                total += bonusVsCavalry
            case .infantry:
                total += bonusVsInfantry
            case .ranged:
                total += bonusVsRanged
            case .siege:
                total += bonusVsSiege
            }
        }

        return total
    }

    static func aggregate(_ stats: [UnitCombatStatsData]) -> UnitCombatStatsData {
        var result = UnitCombatStatsData()
        for stat in stats {
            result.meleeDamage += stat.meleeDamage
            result.pierceDamage += stat.pierceDamage
            result.bludgeonDamage += stat.bludgeonDamage
            result.meleeArmor += stat.meleeArmor
            result.pierceArmor += stat.pierceArmor
            result.bludgeonArmor += stat.bludgeonArmor
        }
        // Average the bonuses
        let count = Double(stats.count)
        if count > 0 {
            result.bonusVsInfantry = stats.map { $0.bonusVsInfantry }.reduce(0, +) / count
            result.bonusVsCavalry = stats.map { $0.bonusVsCavalry }.reduce(0, +) / count
            result.bonusVsRanged = stats.map { $0.bonusVsRanged }.reduce(0, +) / count
            result.bonusVsSiege = stats.map { $0.bonusVsSiege }.reduce(0, +) / count
            result.bonusVsBuildings = stats.map { $0.bonusVsBuildings }.reduce(0, +) / count
        }
        return result
    }
}

// MARK: - Pending Reinforcement Data

struct PendingReinforcementData: Codable {
    let reinforcementID: UUID
    let unitComposition: [MilitaryUnitTypeData: Int]
    let estimatedArrivalTime: TimeInterval
    let sourceCoordinate: HexCoordinate
    var currentCoordinate: HexCoordinate
    let path: [HexCoordinate]
    var pathIndex: Int

    init(reinforcementID: UUID, units: [MilitaryUnitTypeData: Int], estimatedArrival: TimeInterval, source: HexCoordinate, path: [HexCoordinate]) {
        self.reinforcementID = reinforcementID
        self.unitComposition = units
        self.estimatedArrivalTime = estimatedArrival
        self.sourceCoordinate = source
        self.currentCoordinate = source
        self.path = path
        self.pathIndex = 0
    }

    func getTotalUnits() -> Int {
        return unitComposition.values.reduce(0, +)
    }
}

// MARK: - Army Data

/// Pure data representation of an army
class ArmyData: Codable {
    let id: UUID
    var name: String
    var ownerID: UUID?
    var coordinate: HexCoordinate

    // Composition
    private(set) var militaryComposition: [MilitaryUnitTypeData: Int] = [:]

    // Commander reference
    var commanderID: UUID?

    // Home base reference
    var homeBaseID: UUID?

    // State
    var isRetreating: Bool = false

    // Pending reinforcements
    private(set) var pendingReinforcements: [PendingReinforcementData] = []

    // Movement
    var currentPath: [HexCoordinate]?
    var pathIndex: Int = 0
    var movementProgress: Double = 0.0

    // Combat state
    var isInCombat: Bool = false
    var combatTargetID: UUID?

    // Stats cache
    var currentStamina: Double = 100.0
    var maxStamina: Double = 100.0

    init(id: UUID = UUID(), name: String = "Army", coordinate: HexCoordinate, ownerID: UUID? = nil) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.ownerID = ownerID
    }

    // MARK: - Unit Management

    func addMilitaryUnits(_ unitType: MilitaryUnitTypeData, count: Int) {
        militaryComposition[unitType, default: 0] += count
    }

    func removeMilitaryUnits(_ unitType: MilitaryUnitTypeData, count: Int) -> Int {
        let current = militaryComposition[unitType] ?? 0
        let toRemove = min(current, count)

        if toRemove > 0 {
            let remaining = current - toRemove
            if remaining > 0 {
                militaryComposition[unitType] = remaining
            } else {
                militaryComposition.removeValue(forKey: unitType)
            }
        }

        return toRemove
    }

    func setMilitaryComposition(_ composition: [MilitaryUnitTypeData: Int]) {
        militaryComposition = composition
    }

    func getTotalUnits() -> Int {
        return militaryComposition.values.reduce(0, +)
    }

    func getUnitCount(ofType type: MilitaryUnitTypeData) -> Int {
        return militaryComposition[type] ?? 0
    }

    func hasMilitaryUnits() -> Bool {
        return getTotalUnits() > 0
    }

    func isEmpty() -> Bool {
        return getTotalUnits() == 0
    }

    // MARK: - Combat Stats

    /// Aggregates combat stats for all units in this army
    func getAggregatedCombatStats() -> UnitCombatStatsData {
        var allStats: [UnitCombatStatsData] = []

        for (unitType, count) in militaryComposition {
            for _ in 0..<count {
                allStats.append(unitType.combatStats)
            }
        }

        return UnitCombatStatsData.aggregate(allStats)
    }

    /// Gets total HP of all units in the army
    func getTotalHP() -> Double {
        var totalHP = 0.0
        for (unitType, count) in militaryComposition {
            totalHP += unitType.hp * Double(count)
        }
        return totalHP
    }

    func getUnitCountByCategory(_ category: UnitCategoryData) -> Int {
        var count = 0
        for (unitType, unitCount) in militaryComposition {
            if unitType.category == category {
                count += unitCount
            }
        }
        return count
    }

    func getPrimaryCategory() -> UnitCategoryData? {
        var categoryCounts: [UnitCategoryData: Int] = [:]

        for (unitType, count) in militaryComposition {
            categoryCounts[unitType.category, default: 0] += count
        }

        return categoryCounts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Reinforcements

    func addPendingReinforcement(_ reinforcement: PendingReinforcementData) {
        pendingReinforcements.append(reinforcement)
    }

    func removePendingReinforcement(id: UUID) {
        pendingReinforcements.removeAll { $0.reinforcementID == id }
    }

    func updatePendingReinforcement(at index: Int, with reinforcement: PendingReinforcementData) {
        guard index >= 0 && index < pendingReinforcements.count else { return }
        pendingReinforcements[index] = reinforcement
    }

    func receiveReinforcement(_ units: [MilitaryUnitTypeData: Int]) {
        for (unitType, count) in units {
            addMilitaryUnits(unitType, count: count)
        }
    }

    var isAwaitingReinforcements: Bool {
        return !pendingReinforcements.isEmpty
    }

    func getTotalPendingUnits() -> Int {
        return pendingReinforcements.reduce(0) { $0 + $1.getTotalUnits() }
    }

    // MARK: - Merging

    func merge(with otherArmy: ArmyData) {
        for (unitType, count) in otherArmy.militaryComposition {
            addMilitaryUnits(unitType, count: count)
        }
    }

    // MARK: - Capacity

    func getMaxArmySize(commanderMaxSize: Int?) -> Int {
        return commanderMaxSize ?? 200
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, ownerID, coordinate
        case militaryComposition
        case commanderID, homeBaseID
        case isRetreating
        case pendingReinforcements
        case currentPath, pathIndex, movementProgress
        case isInCombat, combatTargetID
        case currentStamina, maxStamina
    }
}

// MARK: - Commander Data

/// Pure data representation of a commander
class CommanderData: Codable {
    let id: UUID
    var name: String
    var ownerID: UUID?
    var assignedArmyID: UUID?

    var level: Int = 1
    var experience: Double = 0.0

    var specialty: UnitCategoryData?
    var rank: CommanderRankData = .captain

    init(id: UUID = UUID(), name: String, ownerID: UUID? = nil) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
    }

    func getAttackBonus(for category: UnitCategoryData) -> Double {
        var bonus = rank.baseAttackBonus

        if let specialty = specialty, specialty == category {
            bonus += 0.1  // 10% bonus for specialty
        }

        return bonus
    }

    func getDefenseBonus() -> Double {
        return rank.baseDefenseBonus
    }
}

// MARK: - Commander Rank Data

enum CommanderRankData: String, Codable {
    case captain
    case major
    case colonel
    case general
    case marshal

    var maxArmySize: Int {
        switch self {
        case .captain: return 200
        case .major: return 400
        case .colonel: return 600
        case .general: return 800
        case .marshal: return 1000
        }
    }

    var baseAttackBonus: Double {
        switch self {
        case .captain: return 0.05
        case .major: return 0.10
        case .colonel: return 0.15
        case .general: return 0.20
        case .marshal: return 0.25
        }
    }

    var baseDefenseBonus: Double {
        switch self {
        case .captain: return 0.03
        case .major: return 0.06
        case .colonel: return 0.09
        case .general: return 0.12
        case .marshal: return 0.15
        }
    }
}
