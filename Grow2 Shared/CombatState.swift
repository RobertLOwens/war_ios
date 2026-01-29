import Foundation

// MARK: - Combat Phase

/// Represents the current phase of a phased combat
enum CombatPhase: String, Codable {
    case rangedExchange   // 0-10s: Ranged/siege fire, melee units closing
    case meleeEngagement  // 10s+: Full melee combat, ranged continues
    case cleanup          // One side's melee gone, mop up remaining
    case ended            // Combat concluded

    var displayName: String {
        switch self {
        case .rangedExchange: return "Ranged Exchange"
        case .meleeEngagement: return "Melee Engagement"
        case .cleanup: return "Cleanup"
        case .ended: return "Ended"
        }
    }
}

// MARK: - Cavalry Stance

/// Cavalry positioning in phased combat
enum CavalryStance: String, Codable {
    case frontline  // Fight alongside infantry
    case flank      // +25% damage to ranged units
    case reserve    // Wait until cleanup phase

    var displayName: String {
        switch self {
        case .frontline: return "Frontline"
        case .flank: return "Flanking"
        case .reserve: return "Reserve"
        }
    }

    /// Damage multiplier when attacking ranged units while flanking
    var flankBonusVsRanged: Double {
        return self == .flank ? 1.25 : 1.0
    }
}

// MARK: - Side Combat State

/// Tracks the combat state for one side of a phased combat
struct SideCombatState: Codable {
    /// Unit counts by type
    var unitCounts: [MilitaryUnitType: Int]

    /// Accumulated damage per unit type (kills happen when >= unit's HP)
    var damageAccumulators: [MilitaryUnitType: Double]

    /// Initial unit count at combat start (for calculating casualties)
    let initialUnitCount: Int

    /// Reference to the army (not stored in saves)
    weak var army: Army?

    /// Cavalry stance for this side
    var cavalryStance: CavalryStance = .frontline

    // MARK: - Tracking for Detailed Combat Records

    /// Initial composition snapshot at combat start
    var initialComposition: [MilitaryUnitType: Int]

    /// Total damage dealt by each unit type throughout combat
    var damageDealtByType: [MilitaryUnitType: Double] = [:]

    /// Total damage received by each unit type throughout combat
    var damageReceivedByType: [MilitaryUnitType: Double] = [:]

    init(army: Army) {
        self.army = army
        self.unitCounts = army.militaryComposition
        self.damageAccumulators = [:]
        self.initialUnitCount = army.getTotalMilitaryUnits()

        // Snapshot initial composition for battle reports
        self.initialComposition = army.militaryComposition

        // Initialize tracking dictionaries for all unit types present
        for unitType in unitCounts.keys {
            damageAccumulators[unitType] = 0.0
            damageDealtByType[unitType] = 0.0
            damageReceivedByType[unitType] = 0.0
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case unitCounts, damageAccumulators, cavalryStance, initialUnitCount
        case initialComposition, damageDealtByType, damageReceivedByType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unitCounts = try container.decode([MilitaryUnitType: Int].self, forKey: .unitCounts)
        damageAccumulators = try container.decode([MilitaryUnitType: Double].self, forKey: .damageAccumulators)
        cavalryStance = try container.decode(CavalryStance.self, forKey: .cavalryStance)
        initialUnitCount = try container.decodeIfPresent(Int.self, forKey: .initialUnitCount) ?? unitCounts.values.reduce(0, +)
        initialComposition = try container.decodeIfPresent([MilitaryUnitType: Int].self, forKey: .initialComposition) ?? unitCounts
        damageDealtByType = try container.decodeIfPresent([MilitaryUnitType: Double].self, forKey: .damageDealtByType) ?? [:]
        damageReceivedByType = try container.decodeIfPresent([MilitaryUnitType: Double].self, forKey: .damageReceivedByType) ?? [:]
        army = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(unitCounts, forKey: .unitCounts)
        try container.encode(damageAccumulators, forKey: .damageAccumulators)
        try container.encode(cavalryStance, forKey: .cavalryStance)
        try container.encode(initialUnitCount, forKey: .initialUnitCount)
        try container.encode(initialComposition, forKey: .initialComposition)
        try container.encode(damageDealtByType, forKey: .damageDealtByType)
        try container.encode(damageReceivedByType, forKey: .damageReceivedByType)
    }

    // MARK: - Computed Properties

    /// Total units remaining
    var totalUnits: Int {
        return unitCounts.values.reduce(0, +)
    }

    /// Total melee units (infantry + cavalry)
    var meleeUnits: Int {
        return unitCounts.filter { $0.key.category == .infantry || $0.key.category == .cavalry }
            .values.reduce(0, +)
    }

    /// Total ranged units
    var rangedUnits: Int {
        return unitCounts.filter { $0.key.category == .ranged }
            .values.reduce(0, +)
    }

    /// Total siege units
    var siegeUnits: Int {
        return unitCounts.filter { $0.key.category == .siege }
            .values.reduce(0, +)
    }

    /// Total infantry units
    var infantryUnits: Int {
        return unitCounts.filter { $0.key.category == .infantry }
            .values.reduce(0, +)
    }

    /// Total cavalry units
    var cavalryUnits: Int {
        return unitCounts.filter { $0.key.category == .cavalry }
            .values.reduce(0, +)
    }

    /// Units by category
    func units(in category: UnitCategory) -> Int {
        return unitCounts.filter { $0.key.category == category }
            .values.reduce(0, +)
    }

    /// Check if side has any units of a category
    func hasUnits(in category: UnitCategory) -> Bool {
        return units(in: category) > 0
    }

    // MARK: - Damage Application

    /// Apply damage to a specific unit type, returns number of units killed
    mutating func applyDamage(_ damage: Double, to unitType: MilitaryUnitType) -> Int {
        guard let currentCount = unitCounts[unitType], currentCount > 0 else { return 0 }

        // Track damage received for battle reports
        damageReceivedByType[unitType, default: 0.0] += damage

        let unitHP = unitType.hp  // Use unit-specific HP
        let currentAccumulator = damageAccumulators[unitType] ?? 0.0
        let newAccumulator = currentAccumulator + damage

        // Calculate kills (damage >= unit HP kills one unit)
        let kills = Int(newAccumulator / unitHP)
        let actualKills = min(kills, currentCount)

        // Update counts and accumulator
        unitCounts[unitType] = currentCount - actualKills
        damageAccumulators[unitType] = newAccumulator.truncatingRemainder(dividingBy: unitHP)

        // Clean up if no units left
        if unitCounts[unitType] == 0 {
            unitCounts.removeValue(forKey: unitType)
            damageAccumulators.removeValue(forKey: unitType)
        }

        return actualKills
    }

    /// Track damage dealt by a specific unit type (for battle reports)
    mutating func trackDamageDealt(_ damage: Double, by unitType: MilitaryUnitType) {
        damageDealtByType[unitType, default: 0.0] += damage
    }

    /// Get units of a specific type
    func getUnits(ofType type: MilitaryUnitType) -> Int {
        return unitCounts[type] ?? 0
    }
}

// MARK: - Active Combat

/// Represents an ongoing phased combat between two armies
class ActiveCombat: Codable {
    let id: UUID
    var attackerState: SideCombatState
    var defenderState: SideCombatState
    var phase: CombatPhase
    var elapsedTime: TimeInterval
    let location: HexCoordinate
    let startTime: Date

    /// Terrain at combat location
    let terrainType: TerrainType
    let terrainDefenseBonus: Double
    let terrainAttackPenalty: Double

    /// Phase transition threshold (seconds)
    static let meleeEngagementThreshold: TimeInterval = 3.0

    /// Weak references to actual armies (not saved)
    weak var attackerArmy: Army?
    weak var defenderArmy: Army?

    // MARK: - Phase Tracking for Detailed Combat Records

    /// Records for completed phases
    var phaseRecords: [CombatPhaseRecord] = []

    /// When the current phase started
    var phaseStartTime: TimeInterval = 0

    /// Damage dealt by attacker in current phase
    var phaseAttackerDamage: Double = 0

    /// Damage dealt by defender in current phase
    var phaseDefenderDamage: Double = 0

    /// Casualties suffered by attacker in current phase
    var phaseAttackerCasualties: [MilitaryUnitType: Int] = [:]

    /// Casualties suffered by defender in current phase
    var phaseDefenderCasualties: [MilitaryUnitType: Int] = [:]

    init(attacker: Army, defender: Army, location: HexCoordinate, terrainType: TerrainType = .plains) {
        self.id = UUID()
        self.attackerState = SideCombatState(army: attacker)
        self.defenderState = SideCombatState(army: defender)
        self.phase = .rangedExchange
        self.elapsedTime = 0
        self.location = location
        self.startTime = Date()
        self.terrainType = terrainType
        self.terrainDefenseBonus = terrainType.combatModifier.defenderDefenseBonus
        self.terrainAttackPenalty = terrainType.combatModifier.attackerAttackPenalty
        self.attackerArmy = attacker
        self.defenderArmy = defender
        self.phaseStartTime = 0
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, attackerState, defenderState, phase, elapsedTime, location, startTime
        case terrainType, terrainDefenseBonus, terrainAttackPenalty
        case phaseRecords, phaseStartTime, phaseAttackerDamage, phaseDefenderDamage
        case phaseAttackerCasualties, phaseDefenderCasualties
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        attackerState = try container.decode(SideCombatState.self, forKey: .attackerState)
        defenderState = try container.decode(SideCombatState.self, forKey: .defenderState)
        phase = try container.decode(CombatPhase.self, forKey: .phase)
        elapsedTime = try container.decode(TimeInterval.self, forKey: .elapsedTime)
        location = try container.decode(HexCoordinate.self, forKey: .location)
        startTime = try container.decode(Date.self, forKey: .startTime)
        terrainType = try container.decodeIfPresent(TerrainType.self, forKey: .terrainType) ?? .plains
        terrainDefenseBonus = try container.decodeIfPresent(Double.self, forKey: .terrainDefenseBonus) ?? 0.0
        terrainAttackPenalty = try container.decodeIfPresent(Double.self, forKey: .terrainAttackPenalty) ?? 0.0
        phaseRecords = try container.decodeIfPresent([CombatPhaseRecord].self, forKey: .phaseRecords) ?? []
        phaseStartTime = try container.decodeIfPresent(TimeInterval.self, forKey: .phaseStartTime) ?? 0
        phaseAttackerDamage = try container.decodeIfPresent(Double.self, forKey: .phaseAttackerDamage) ?? 0
        phaseDefenderDamage = try container.decodeIfPresent(Double.self, forKey: .phaseDefenderDamage) ?? 0
        phaseAttackerCasualties = try container.decodeIfPresent([MilitaryUnitType: Int].self, forKey: .phaseAttackerCasualties) ?? [:]
        phaseDefenderCasualties = try container.decodeIfPresent([MilitaryUnitType: Int].self, forKey: .phaseDefenderCasualties) ?? [:]
        attackerArmy = nil
        defenderArmy = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(attackerState, forKey: .attackerState)
        try container.encode(defenderState, forKey: .defenderState)
        try container.encode(phase, forKey: .phase)
        try container.encode(elapsedTime, forKey: .elapsedTime)
        try container.encode(location, forKey: .location)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(terrainType, forKey: .terrainType)
        try container.encode(terrainDefenseBonus, forKey: .terrainDefenseBonus)
        try container.encode(terrainAttackPenalty, forKey: .terrainAttackPenalty)
        try container.encode(phaseRecords, forKey: .phaseRecords)
        try container.encode(phaseStartTime, forKey: .phaseStartTime)
        try container.encode(phaseAttackerDamage, forKey: .phaseAttackerDamage)
        try container.encode(phaseDefenderDamage, forKey: .phaseDefenderDamage)
        try container.encode(phaseAttackerCasualties, forKey: .phaseAttackerCasualties)
        try container.encode(phaseDefenderCasualties, forKey: .phaseDefenderCasualties)
    }

    // MARK: - Terrain Modifiers

    /// Computed terrain modifier based on stored values
    var terrainModifier: TerrainCombatModifier {
        return TerrainCombatModifier(
            terrain: terrainType,
            defenderDefenseBonus: terrainDefenseBonus,
            attackerAttackPenalty: terrainAttackPenalty
        )
    }

    // MARK: - Combat State

    /// Check if combat should end
    var shouldEnd: Bool {
        return attackerState.totalUnits == 0 || defenderState.totalUnits == 0
    }

    /// Determine the winner (nil if draw or ongoing)
    var winner: CombatResult {
        if attackerState.totalUnits > 0 && defenderState.totalUnits == 0 {
            return .attackerVictory
        } else if defenderState.totalUnits > 0 && attackerState.totalUnits == 0 {
            return .defenderVictory
        } else if attackerState.totalUnits == 0 && defenderState.totalUnits == 0 {
            return .draw
        }
        return .draw // Ongoing
    }

    /// Check and update phase based on current state
    func updatePhase() {
        guard phase != .ended else { return }

        let previousPhase = phase

        switch phase {
        case .rangedExchange:
            // Transition to melee after threshold time
            if elapsedTime >= ActiveCombat.meleeEngagementThreshold {
                recordPhaseCompletion(previousPhase)
                phase = .meleeEngagement
            }

        case .meleeEngagement:
            // Transition to cleanup when one side has no melee units
            if attackerState.meleeUnits == 0 || defenderState.meleeUnits == 0 {
                recordPhaseCompletion(previousPhase)
                phase = .cleanup
            }

        case .cleanup:
            // End when one side has no units
            if shouldEnd {
                recordPhaseCompletion(previousPhase)
                phase = .ended
            }

        case .ended:
            break
        }
    }

    // MARK: - Phase Tracking Methods

    /// Records the current phase statistics and resets accumulators
    func recordPhaseCompletion(_ completedPhase: CombatPhase) {
        let phaseDuration = elapsedTime - phaseStartTime

        let record = CombatPhaseRecord(
            phase: completedPhase,
            duration: phaseDuration,
            attackerDamageDealt: phaseAttackerDamage,
            defenderDamageDealt: phaseDefenderDamage,
            attackerCasualties: phaseAttackerCasualties,
            defenderCasualties: phaseDefenderCasualties
        )

        phaseRecords.append(record)

        // Reset phase accumulators
        phaseStartTime = elapsedTime
        phaseAttackerDamage = 0
        phaseDefenderDamage = 0
        phaseAttackerCasualties = [:]
        phaseDefenderCasualties = [:]
    }

    /// Track damage dealt during this phase
    func trackPhaseDamage(byAttacker: Bool, amount: Double) {
        if byAttacker {
            phaseAttackerDamage += amount
        } else {
            phaseDefenderDamage += amount
        }
    }

    /// Track casualties during this phase
    func trackPhaseCasualty(isAttacker: Bool, unitType: MilitaryUnitType, count: Int) {
        if isAttacker {
            phaseAttackerCasualties[unitType, default: 0] += count
        } else {
            phaseDefenderCasualties[unitType, default: 0] += count
        }
    }

    /// Link armies after loading from save
    func linkArmies(attacker: Army, defender: Army) {
        self.attackerArmy = attacker
        self.defenderArmy = defender
        self.attackerState.army = attacker
        self.defenderState.army = defender
    }
}

// MARK: - Target Priority

/// Determines which enemy units to prioritize based on attacker category
struct TargetPriority {

    /// Get prioritized target categories for an attacker type
    static func getTargetPriority(for attackerCategory: UnitCategory, stance: CavalryStance = .frontline) -> [UnitCategory] {
        switch attackerCategory {
        case .ranged:
            // Ranged prioritize: Siege > Cavalry > Infantry > Ranged
            return [.siege, .cavalry, .infantry, .ranged]

        case .siege:
            // Siege prioritize: Siege > Ranged > Infantry > Cavalry
            return [.siege, .ranged, .infantry, .cavalry]

        case .infantry:
            // Infantry prioritize: Infantry > Cavalry > Ranged > Siege
            return [.infantry, .cavalry, .ranged, .siege]

        case .cavalry:
            if stance == .flank {
                // Flanking cavalry prioritize ranged: Ranged > Siege > Infantry > Cavalry
                return [.ranged, .siege, .infantry, .cavalry]
            } else {
                // Frontline cavalry same as infantry: Infantry > Cavalry > Ranged > Siege
                return [.infantry, .cavalry, .ranged, .siege]
            }
        }
    }

    /// Find the best target unit type from enemy state
    static func findTarget(
        attackerCategory: UnitCategory,
        stance: CavalryStance,
        enemyState: SideCombatState
    ) -> MilitaryUnitType? {
        let priorities = getTargetPriority(for: attackerCategory, stance: stance)

        for targetCategory in priorities {
            // Find unit types in this category that the enemy has
            let availableTargets = enemyState.unitCounts.filter {
                $0.key.category == targetCategory && $0.value > 0
            }

            // Return first available target (could be enhanced to pick weakest/strongest)
            if let target = availableTargets.keys.first {
                return target
            }
        }

        return nil
    }
}
