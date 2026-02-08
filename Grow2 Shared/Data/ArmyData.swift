// ============================================================================
// FILE: Grow2 Shared/Data/ArmyData.swift
// PURPOSE: Pure data model for armies - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Military Unit Type Data

/// Pure data representation of military unit types
enum MilitaryUnitTypeData: String, Codable, CaseIterable {
    case swordsman = "Swordsman"
    case archer = "Archer"
    case crossbow = "Crossbow"
    case pikeman = "Pikeman"
    case scout = "Scout"
    case knight = "Knight"
    case heavyCavalry = "Heavy Cavalry"
    case mangonel = "Mangonel"
    case trebuchet = "Trebuchet"

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .swordsman: return "🗡️"
        case .pikeman: return "🔱"
        case .archer: return "🏹"
        case .crossbow: return "🎯"
        case .scout: return "🐎"
        case .knight: return "🐴"
        case .heavyCavalry: return "🐴"
        case .mangonel: return "⚙️"
        case .trebuchet: return "🪨"
        }
    }

    var moveSpeed: TimeInterval {
        switch self {
        case .swordsman: return 1.40
        case .pikeman: return 1.60
        case .archer: return 1.40
        case .crossbow: return 1.52
        case .scout: return 0.88  // Fast cavalry
        case .knight: return 1.00
        case .heavyCavalry: return 1.12
        case .mangonel: return 2.00  // Slow siege
        case .trebuchet: return 2.40  // Very slow siege
        }
    }

    var attackSpeed: TimeInterval {
        switch self {
        case .swordsman: return 1.0    // Standard melee
        case .pikeman: return 1.2      // Slower heavy weapon
        case .archer: return 1.0       // Fast ranged
        case .crossbow: return 1.5     // Slow reload
        case .scout: return 0.7        // Fast light cavalry
        case .knight: return 1.1       // Heavy cavalry
        case .heavyCavalry: return 1.2
        case .mangonel: return 2.5     // Slow siege
        case .trebuchet: return 4.0    // Very slow siege
        }
    }

    var description: String {
        switch self {
        case .swordsman:
            return "Balanced melee infantry unit with good armor"
        case .pikeman:
            return "Anti-cavalry infantry with bonus damage vs mounted units"
        case .archer:
            return "Ranged unit with pierce damage"
        case .crossbow:
            return "Heavy ranged unit with high pierce damage and armor"
        case .scout:
            return "Fast light cavalry for reconnaissance"
        case .knight:
            return "Powerful mounted unit with high melee damage"
        case .heavyCavalry:
            return "Very heavy mounted unit with devastating charge"
        case .mangonel:
            return "Siege weapon with bludgeon damage, effective vs buildings"
        case .trebuchet:
            return "Long-range siege weapon, devastating vs buildings"
        }
    }

    var category: UnitCategoryData {
        switch self {
        case .swordsman, .pikeman: return .infantry
        case .archer, .crossbow: return .ranged
        case .scout, .knight, .heavyCavalry: return .cavalry
        case .mangonel, .trebuchet: return .siege
        }
    }

    /// Combat stats for the new damage/armor system
    var combatStats: UnitCombatStatsData {
        switch self {
        case .swordsman:
            return UnitCombatStatsData(
                meleeDamage: 2, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 2, pierceArmor: 1, bludgeonArmor: 0,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .archer:
            return UnitCombatStatsData(
                meleeDamage: 0, pierceDamage: 2, bludgeonDamage: 0,
                meleeArmor: 0, pierceArmor: 1, bludgeonArmor: 0,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .crossbow:
            return UnitCombatStatsData(
                meleeDamage: 0, pierceDamage: 2, bludgeonDamage: 0,
                meleeArmor: 1, pierceArmor: 2, bludgeonArmor: 0,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .pikeman:
            return UnitCombatStatsData(
                meleeDamage: 1, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 1, pierceArmor: 1, bludgeonArmor: 3,
                bonusVsInfantry: 0, bonusVsCavalry: 8, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .scout:
            return UnitCombatStatsData(
                meleeDamage: 2, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 1, pierceArmor: 0, bludgeonArmor: 0,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 1, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .knight:
            return UnitCombatStatsData(
                meleeDamage: 4, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 2, pierceArmor: 2, bludgeonArmor: 1,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 1, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .heavyCavalry:
            return UnitCombatStatsData(
                meleeDamage: 5, pierceDamage: 0, bludgeonDamage: 0,
                meleeArmor: 3, pierceArmor: 3, bludgeonArmor: 1,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 1, bonusVsSiege: 0, bonusVsBuildings: 0
            )
        case .mangonel:
            return UnitCombatStatsData(
                meleeDamage: 0, pierceDamage: 0, bludgeonDamage: 8,
                meleeArmor: 2, pierceArmor: 10, bludgeonArmor: 3,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 20
            )
        case .trebuchet:
            return UnitCombatStatsData(
                meleeDamage: 0, pierceDamage: 0, bludgeonDamage: 12,
                meleeArmor: 2, pierceArmor: 15, bludgeonArmor: 4,
                bonusVsInfantry: 0, bonusVsCavalry: 0, bonusVsRanged: 0, bonusVsSiege: 0, bonusVsBuildings: 30
            )
        }
    }

    /// Hit points for this unit type
    var hp: Double {
        switch self {
        case .swordsman:    return 50  // Tanky infantry
        case .archer:       return 30   // Fragile ranged
        case .crossbow:     return 40   // Armored ranged
        case .pikeman:      return 35  // Standard infantry
        case .scout:        return 30   // Light cavalry
        case .knight:       return 60  // Heavy cavalry
        case .heavyCavalry: return 80  // Very heavy cavalry
        case .mangonel:     return 70  // Siege - tanky but slow
        case .trebuchet:    return 120  // Heavy siege
        }
    }

    var trainingTime: TimeInterval {
        switch self {
        case .swordsman: return 15
        case .archer: return 12
        case .crossbow: return 18
        case .pikeman: return 14
        case .scout: return 18
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
        case .scout: return [.food: 60, .ore: 20]
        case .knight: return [.food: 80, .ore: 60]
        case .heavyCavalry: return [.food: 100, .ore: 80]
        case .mangonel: return [.food: 60, .wood: 100, .ore: 40]
        case .trebuchet: return [.food: 80, .wood: 150, .ore: 60]
        }
    }

    var trainingBuilding: BuildingType {
        switch self {
        case .swordsman, .pikeman: return .barracks
        case .archer, .crossbow: return .archeryRange
        case .scout, .knight, .heavyCavalry: return .stable
        case .mangonel, .trebuchet: return .siegeWorkshop
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

    // Entrenchment state (transient - not saved)
    var isEntrenching: Bool = false
    var isEntrenched: Bool = false
    var entrenchmentStartTime: TimeInterval?

    // Arrival time (transient - not saved, used for LIFO ordering in stack combat)
    var arrivalTime: TimeInterval = 0

    func clearEntrenchment() {
        isEntrenching = false
        isEntrenched = false
        entrenchmentStartTime = nil
    }

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

    /// Returns the moveSpeed of the slowest unit in the army (higher = slower)
    /// Falls back to default army speed if empty
    var slowestUnitMoveSpeed: TimeInterval {
        guard !militaryComposition.isEmpty else {
            return 1.6  // Default army speed (matches EntityType.army.moveSpeed)
        }
        return militaryComposition.keys.map { $0.moveSpeed }.max() ?? 1.6
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

    /// Calculate weighted strength based on HP * totalDamage for each unit
    /// This gives a more accurate representation of army power than raw unit count
    func getWeightedStrength() -> Double {
        var strength = 0.0
        for (unitType, count) in militaryComposition {
            let hp = unitType.hp
            let damage = unitType.combatStats.totalDamage
            // Weighted strength = HP * damage per unit
            strength += Double(count) * (hp * (1.0 + damage * 0.1))
        }
        return strength
    }

    /// Get ratios of unit categories in this army
    func getCategoryRatios() -> (cavalry: Double, ranged: Double, infantry: Double, siege: Double) {
        let total = Double(getTotalUnits())
        guard total > 0 else { return (0, 0, 0, 0) }

        let cavalry = Double(getUnitCountByCategory(.cavalry)) / total
        let ranged = Double(getUnitCountByCategory(.ranged)) / total
        let infantry = Double(getUnitCountByCategory(.infantry)) / total
        let siege = Double(getUnitCountByCategory(.siege)) / total

        return (cavalry, ranged, infantry, siege)
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

    func getMaxArmySize(commanderLeadership: Int?) -> Int {
        guard let leadership = commanderLeadership else { return 40 }
        return GameConfig.Commander.leadershipToArmySizeBase + leadership * GameConfig.Commander.leadershipToArmySizePerPoint
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

// MARK: - Commander Stat Profile

/// Defines how a commander's stats scale with level and rank
struct CommanderStatProfile {
    let baseLeadership: Int
    let leadershipPerLevel: Int
    let leadershipPerRank: Int

    let baseTactics: Int
    let tacticsPerLevel: Int
    let tacticsPerRank: Int

    let baseLogistics: Int
    let logisticsPerLevel: Int
    let logisticsPerRank: Int

    let baseRationing: Int
    let rationingPerLevel: Int
    let rationingPerRank: Int

    let baseEndurance: Int
    let endurancePerLevel: Int
    let endurancePerRank: Int
}

// MARK: - Commander Specialty Data

/// Type alias for backward compatibility
typealias CommanderSpecialty = CommanderSpecialtyData

enum CommanderSpecialtyData: String, Codable, CaseIterable {
    case infantryAggressive = "Infantry (Aggressive)"
    case infantryDefensive = "Infantry (Defensive)"
    case cavalryAggressive = "Cavalry (Aggressive)"
    case cavalryDefensive = "Cavalry (Defensive)"
    case rangedAggressive = "Ranged (Aggressive)"
    case rangedDefensive = "Ranged (Defensive)"
    case siegeAggressive = "Siege (Aggressive)"
    case siegeDefensive = "Siege (Defensive)"
    case defensive = "Defensive"
    case logistics = "Logistics"

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .infantryAggressive: return "🗡️"
        case .infantryDefensive: return "🛡️"
        case .cavalryAggressive: return "🐴"
        case .cavalryDefensive: return "🐴"
        case .rangedAggressive: return "🏹"
        case .rangedDefensive: return "🏹"
        case .siegeAggressive: return "🎯"
        case .siegeDefensive: return "🎯"
        case .defensive: return "🛡️"
        case .logistics: return "📦"
        }
    }

    var description: String {
        switch self {
        case .infantryAggressive: return "+1 infantry attack, boosted endurance"
        case .infantryDefensive: return "+1 armor, boosted leadership"
        case .cavalryAggressive: return "+1 cavalry attack, boosted endurance"
        case .cavalryDefensive: return "+1 armor, boosted logistics"
        case .rangedAggressive: return "+1 ranged attack, boosted endurance"
        case .rangedDefensive: return "+1 armor, boosted tactics"
        case .siegeAggressive: return "+1 siege attack, boosted endurance"
        case .siegeDefensive: return "+1 armor, boosted rationing"
        case .defensive: return "Strong tactics and rationing, better leadership"
        case .logistics: return "Strong leadership and logistics"
        }
    }

    var detailedDescription: String {
        switch self {
        case .infantryAggressive: return "+1 base attack to Infantry units"
        case .infantryDefensive: return "+1 armor to all units, strong Leadership"
        case .cavalryAggressive: return "+1 base attack to Cavalry units"
        case .cavalryDefensive: return "+1 armor to all units, strong Logistics"
        case .rangedAggressive: return "+1 base attack to Ranged units"
        case .rangedDefensive: return "+1 armor to all units, strong Tactics"
        case .siegeAggressive: return "+1 base attack to Siege units"
        case .siegeDefensive: return "+1 armor to all units, strong Rationing"
        case .defensive: return "Strong Tactics & Rationing growth, good Leadership"
        case .logistics: return "Strong Leadership & Logistics growth"
        }
    }

    /// The unit category this specialty focuses on (nil for standalone specialties)
    var unitCategory: UnitCategoryData? {
        switch self {
        case .infantryAggressive, .infantryDefensive: return .infantry
        case .cavalryAggressive, .cavalryDefensive: return .cavalry
        case .rangedAggressive, .rangedDefensive: return .ranged
        case .siegeAggressive, .siegeDefensive: return .siege
        case .defensive, .logistics: return nil
        }
    }

    /// Whether this is an aggressive variant
    var isAggressive: Bool {
        switch self {
        case .infantryAggressive, .cavalryAggressive, .rangedAggressive, .siegeAggressive:
            return true
        default:
            return false
        }
    }

    /// Whether this is a defensive variant (unit-type defensive, not standalone)
    var isDefensiveVariant: Bool {
        switch self {
        case .infantryDefensive, .cavalryDefensive, .rangedDefensive, .siegeDefensive:
            return true
        default:
            return false
        }
    }

    /// +1 base attack bonus for matching aggressive specialty
    func attackBonus(for category: UnitCategoryData) -> Int {
        guard isAggressive, unitCategory == category else { return 0 }
        return 1
    }

    /// +1 armor bonus for defensive variants
    var armorBonus: Int {
        return isDefensiveVariant || self == .defensive ? 1 : 0
    }

    /// Stat profile defining base values and per-level/per-rank scaling
    var statProfile: CommanderStatProfile {
        switch self {
        case .infantryAggressive:
            return CommanderStatProfile(
                baseLeadership: 10, leadershipPerLevel: 2, leadershipPerRank: 4,
                baseTactics: 8, tacticsPerLevel: 1, tacticsPerRank: 3,
                baseLogistics: 8, logisticsPerLevel: 1, logisticsPerRank: 3,
                baseRationing: 8, rationingPerLevel: 1, rationingPerRank: 3,
                baseEndurance: 10, endurancePerLevel: 2, endurancePerRank: 4)
        case .infantryDefensive:
            return CommanderStatProfile(
                baseLeadership: 10, leadershipPerLevel: 2, leadershipPerRank: 4,
                baseTactics: 8, tacticsPerLevel: 1, tacticsPerRank: 3,
                baseLogistics: 8, logisticsPerLevel: 1, logisticsPerRank: 3,
                baseRationing: 8, rationingPerLevel: 1, rationingPerRank: 3,
                baseEndurance: 8, endurancePerLevel: 1, endurancePerRank: 3)
        case .cavalryAggressive:
            return CommanderStatProfile(
                baseLeadership: 8, leadershipPerLevel: 1, leadershipPerRank: 3,
                baseTactics: 8, tacticsPerLevel: 1, tacticsPerRank: 3,
                baseLogistics: 10, logisticsPerLevel: 2, logisticsPerRank: 4,
                baseRationing: 8, rationingPerLevel: 1, rationingPerRank: 3,
                baseEndurance: 10, endurancePerLevel: 2, endurancePerRank: 4)
        case .cavalryDefensive:
            return CommanderStatProfile(
                baseLeadership: 8, leadershipPerLevel: 1, leadershipPerRank: 3,
                baseTactics: 8, tacticsPerLevel: 1, tacticsPerRank: 3,
                baseLogistics: 10, logisticsPerLevel: 2, logisticsPerRank: 4,
                baseRationing: 8, rationingPerLevel: 1, rationingPerRank: 3,
                baseEndurance: 8, endurancePerLevel: 1, endurancePerRank: 3)
        case .rangedAggressive:
            return CommanderStatProfile(
                baseLeadership: 8, leadershipPerLevel: 1, leadershipPerRank: 3,
                baseTactics: 10, tacticsPerLevel: 2, tacticsPerRank: 4,
                baseLogistics: 8, logisticsPerLevel: 1, logisticsPerRank: 3,
                baseRationing: 8, rationingPerLevel: 1, rationingPerRank: 3,
                baseEndurance: 10, endurancePerLevel: 2, endurancePerRank: 4)
        case .rangedDefensive:
            return CommanderStatProfile(
                baseLeadership: 8, leadershipPerLevel: 1, leadershipPerRank: 3,
                baseTactics: 10, tacticsPerLevel: 2, tacticsPerRank: 4,
                baseLogistics: 8, logisticsPerLevel: 1, logisticsPerRank: 3,
                baseRationing: 8, rationingPerLevel: 1, rationingPerRank: 3,
                baseEndurance: 8, endurancePerLevel: 1, endurancePerRank: 3)
        case .siegeAggressive:
            return CommanderStatProfile(
                baseLeadership: 8, leadershipPerLevel: 1, leadershipPerRank: 3,
                baseTactics: 8, tacticsPerLevel: 1, tacticsPerRank: 3,
                baseLogistics: 8, logisticsPerLevel: 1, logisticsPerRank: 3,
                baseRationing: 10, rationingPerLevel: 2, rationingPerRank: 4,
                baseEndurance: 10, endurancePerLevel: 2, endurancePerRank: 4)
        case .siegeDefensive:
            return CommanderStatProfile(
                baseLeadership: 8, leadershipPerLevel: 1, leadershipPerRank: 3,
                baseTactics: 8, tacticsPerLevel: 1, tacticsPerRank: 3,
                baseLogistics: 8, logisticsPerLevel: 1, logisticsPerRank: 3,
                baseRationing: 10, rationingPerLevel: 2, rationingPerRank: 4,
                baseEndurance: 8, endurancePerLevel: 1, endurancePerRank: 3)
        case .defensive:
            return CommanderStatProfile(
                baseLeadership: 10, leadershipPerLevel: 2, leadershipPerRank: 4,
                baseTactics: 12, tacticsPerLevel: 3, tacticsPerRank: 5,
                baseLogistics: 6, logisticsPerLevel: 1, logisticsPerRank: 2,
                baseRationing: 10, rationingPerLevel: 2, rationingPerRank: 4,
                baseEndurance: 8, endurancePerLevel: 1, endurancePerRank: 3)
        case .logistics:
            return CommanderStatProfile(
                baseLeadership: 10, leadershipPerLevel: 2, leadershipPerRank: 4,
                baseTactics: 6, tacticsPerLevel: 1, tacticsPerRank: 2,
                baseLogistics: 12, logisticsPerLevel: 3, logisticsPerRank: 5,
                baseRationing: 8, rationingPerLevel: 1, rationingPerRank: 3,
                baseEndurance: 8, endurancePerLevel: 1, endurancePerRank: 3)
        }
    }

    /// Migrate from legacy specialty rawValues (pre-rework saves)
    static func fromLegacy(_ rawValue: String) -> CommanderSpecialtyData? {
        switch rawValue {
        case "Infantry": return .infantryAggressive
        case "Cavalry": return .cavalryAggressive
        case "Ranged": return .rangedAggressive
        case "Siege": return .siegeAggressive
        case "Defensive": return .defensive
        case "Logistics": return .logistics
        default: return CommanderSpecialtyData(rawValue: rawValue)
        }
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
    var experience: Int = 0

    var specialty: CommanderSpecialtyData
    var rank: CommanderRankData = .recruit

    // Base stats (set at creation, derived from specialty profile)
    let baseLeadership: Int
    let baseTactics: Int
    let baseLogistics: Int
    let baseRationing: Int
    let baseEndurance: Int

    // Stamina system
    var stamina: Double = 100.0
    var lastStaminaUpdateTime: TimeInterval = 0

    static let maxStamina: Double = 100.0
    static let staminaCostPerCommand: Double = 5.0
    static let staminaRegenPerSecond: Double = 1.0 / 60.0

    // Portrait color stored as hex
    var portraitColorHex: String = "#0000FF"

    init(id: UUID = UUID(), name: String, specialty: CommanderSpecialtyData,
         baseLeadership: Int? = nil, baseTactics: Int? = nil,
         baseLogistics: Int? = nil, baseRationing: Int? = nil, baseEndurance: Int? = nil,
         ownerID: UUID? = nil) {
        let profile = specialty.statProfile
        self.id = id
        self.name = name
        self.specialty = specialty
        self.baseLeadership = baseLeadership ?? profile.baseLeadership
        self.baseTactics = baseTactics ?? profile.baseTactics
        self.baseLogistics = baseLogistics ?? profile.baseLogistics
        self.baseRationing = baseRationing ?? profile.baseRationing
        self.baseEndurance = baseEndurance ?? profile.baseEndurance
        self.ownerID = ownerID
        self.lastStaminaUpdateTime = Date().timeIntervalSince1970
    }

    // MARK: - Computed Stats

    var leadership: Int {
        let profile = specialty.statProfile
        return baseLeadership + (level - 1) * profile.leadershipPerLevel + rank.index * profile.leadershipPerRank
    }

    var tactics: Int {
        let profile = specialty.statProfile
        return baseTactics + (level - 1) * profile.tacticsPerLevel + rank.index * profile.tacticsPerRank
    }

    var logistics: Int {
        let profile = specialty.statProfile
        return baseLogistics + (level - 1) * profile.logisticsPerLevel + rank.index * profile.logisticsPerRank
    }

    var rationing: Int {
        let profile = specialty.statProfile
        return baseRationing + (level - 1) * profile.rationingPerLevel + rank.index * profile.rationingPerRank
    }

    var endurance: Int {
        let profile = specialty.statProfile
        return baseEndurance + (level - 1) * profile.endurancePerLevel + rank.index * profile.endurancePerRank
    }

    var staminaPercentage: Double {
        return stamina / CommanderData.maxStamina
    }

    // MARK: - Stamina Management

    func hasEnoughStamina(cost: Double = CommanderData.staminaCostPerCommand) -> Bool {
        return stamina >= cost
    }

    @discardableResult
    func consumeStamina(cost: Double = CommanderData.staminaCostPerCommand) -> Bool {
        guard hasEnoughStamina(cost: cost) else { return false }
        stamina = max(0, stamina - cost)
        return true
    }

    func regenerateStamina(currentTime: TimeInterval) {
        guard lastStaminaUpdateTime > 0 else {
            lastStaminaUpdateTime = currentTime
            return
        }

        let elapsed = currentTime - lastStaminaUpdateTime
        let enduranceMultiplier = 1.0 + Double(endurance) * GameConfig.Commander.enduranceRegenScaling
        let regenAmount = elapsed * CommanderData.staminaRegenPerSecond * enduranceMultiplier

        if stamina < CommanderData.maxStamina {
            stamina = min(CommanderData.maxStamina, stamina + regenAmount)
        }

        lastStaminaUpdateTime = currentTime
    }

    func setStamina(_ value: Double, lastUpdateTime: TimeInterval) {
        stamina = min(CommanderData.maxStamina, max(0, value))
        lastStaminaUpdateTime = lastUpdateTime
    }

    // MARK: - Experience and Leveling

    func addExperience(_ amount: Int) {
        experience += amount
        checkLevelUp()
    }

    private func checkLevelUp() {
        let requiredXP = level * 100
        if experience >= requiredXP {
            level += 1
            experience -= requiredXP
            checkRankPromotion()
        }
    }

    private func checkRankPromotion() {
        let newRank: CommanderRankData?

        switch level {
        case 5: newRank = .sergeant
        case 10: newRank = .captain
        case 15: newRank = .major
        case 20: newRank = .colonel
        case 25: newRank = .general
        default: newRank = nil
        }

        if let newRank = newRank, newRank.index > rank.index {
            rank = newRank
        }
    }

    // MARK: - Combat Bonuses

    func getAttackBonus(for category: UnitCategoryData) -> Double {
        let specialtyAttackBonus = Double(specialty.attackBonus(for: category))
        let levelBonus = Double(level) * 0.01
        return specialtyAttackBonus * 0.1 + levelBonus
    }

    func getDefenseBonus() -> Double {
        let armorBonus = Double(specialty.armorBonus)
        let levelBonus = Double(level) * 0.01
        return armorBonus * 0.1 + levelBonus
    }

    func getSpeedBonus() -> Double {
        return 1.0 + Double(logistics) * GameConfig.Commander.logisticsSpeedScaling
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, ownerID, assignedArmyID
        case level, experience
        case specialty, rank
        case baseLeadership, baseTactics
        case baseLogistics, baseRationing, baseEndurance
        case stamina, lastStaminaUpdateTime
        case portraitColorHex
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        ownerID = try container.decodeIfPresent(UUID.self, forKey: .ownerID)
        assignedArmyID = try container.decodeIfPresent(UUID.self, forKey: .assignedArmyID)
        level = try container.decode(Int.self, forKey: .level)
        experience = try container.decode(Int.self, forKey: .experience)
        rank = try container.decode(CommanderRankData.self, forKey: .rank)
        stamina = try container.decode(Double.self, forKey: .stamina)
        lastStaminaUpdateTime = try container.decode(TimeInterval.self, forKey: .lastStaminaUpdateTime)
        portraitColorHex = try container.decodeIfPresent(String.self, forKey: .portraitColorHex) ?? "#0000FF"

        // Handle specialty migration from legacy rawValues
        let specialtyRaw = try container.decode(String.self, forKey: .specialty)
        specialty = CommanderSpecialtyData(rawValue: specialtyRaw) ?? CommanderSpecialtyData.fromLegacy(specialtyRaw) ?? .infantryAggressive

        baseLeadership = try container.decode(Int.self, forKey: .baseLeadership)
        baseTactics = try container.decode(Int.self, forKey: .baseTactics)

        // New stats with backward compatibility defaults
        let profile = specialty.statProfile
        baseLogistics = try container.decodeIfPresent(Int.self, forKey: .baseLogistics) ?? profile.baseLogistics
        baseRationing = try container.decodeIfPresent(Int.self, forKey: .baseRationing) ?? profile.baseRationing
        baseEndurance = try container.decodeIfPresent(Int.self, forKey: .baseEndurance) ?? profile.baseEndurance
    }
}

// MARK: - Commander Rank Data

/// Type alias for backward compatibility
typealias CommanderRank = CommanderRankData

enum CommanderRankData: String, Codable, CaseIterable {
    case recruit = "Recruit"
    case sergeant = "Sergeant"
    case captain = "Captain"
    case major = "Major"
    case colonel = "Colonel"
    case general = "General"

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .recruit: return "⭐"
        case .sergeant: return "⭐⭐"
        case .captain: return "⭐⭐⭐"
        case .major: return "🎖️"
        case .colonel: return "🎖️🎖️"
        case .general: return "👑"
        }
    }

    /// Rank index used for stat scaling (Recruit=0 through General=5)
    var index: Int {
        switch self {
        case .recruit: return 0
        case .sergeant: return 1
        case .captain: return 2
        case .major: return 3
        case .colonel: return 4
        case .general: return 5
        }
    }
}

// MARK: - Training Queue Entry Data

/// Pure data representation of a military unit training queue entry
struct TrainingQueueEntryData: Codable {
    let id: UUID
    let unitType: MilitaryUnitTypeData
    let quantity: Int
    let startTime: TimeInterval
    var progress: Double = 0.0

    init(unitType: MilitaryUnitTypeData, quantity: Int, startTime: TimeInterval) {
        self.id = UUID()
        self.unitType = unitType
        self.quantity = quantity
        self.startTime = startTime
    }

    func getProgress(currentTime: TimeInterval, trainingSpeedMultiplier: Double = 1.0) -> Double {
        let elapsed = currentTime - startTime
        let baseTime = unitType.trainingTime * Double(quantity)
        let totalTime = baseTime / trainingSpeedMultiplier
        return min(1.0, elapsed / totalTime)
    }
}

// MARK: - Villager Training Entry Data

/// Pure data representation of a villager training queue entry
struct VillagerTrainingEntryData: Codable {
    let id: UUID
    let quantity: Int
    let startTime: TimeInterval
    var progress: Double = 0.0

    static let trainingTimePerVillager: TimeInterval = 10.0

    init(quantity: Int, startTime: TimeInterval) {
        self.id = UUID()
        self.quantity = quantity
        self.startTime = startTime
    }

    func getProgress(currentTime: TimeInterval) -> Double {
        let elapsed = currentTime - startTime
        let totalTime = VillagerTrainingEntryData.trainingTimePerVillager * Double(quantity)
        return min(1.0, elapsed / totalTime)
    }
}
