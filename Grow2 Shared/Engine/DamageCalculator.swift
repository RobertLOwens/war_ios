// ============================================================================
// FILE: Grow2 Shared/Engine/DamageCalculator.swift
// PURPOSE: Extracted DPS calculation logic from CombatEngine
// ============================================================================

import Foundation

/// Handles all damage-per-second calculations for the combat system.
/// Extracted from CombatEngine for clarity and testability.
struct DamageCalculator {

    // MARK: - Charge Bonuses
    static let cavalryChargeBonus = GameConfig.Combat.cavalryChargeBonus
    static let infantryChargeBonus = GameConfig.Combat.infantryChargeBonus

    // MARK: - Terrain Modifier

    static func applyTerrainModifier(to dps: Double, terrainPenalty: Double, terrainBonus: Double, tacticsBonus: Double = 0) -> Double {
        let scaledTerrainBonus = terrainBonus * (1.0 + tacticsBonus)
        let modifier = 1.0 - terrainPenalty + scaledTerrainBonus
        return dps * modifier
    }

    // MARK: - Weighted Bonus

    /// Calculates weighted bonus damage based on enemy unit category composition.
    /// For example: If the enemy has 50% cavalry and the attacker has +8 vs cavalry,
    /// the weighted bonus is 0.5 * 8 = 4 bonus damage per attack.
    static func calculateWeightedBonus(
        attackerStats: UnitCombatStatsData,
        enemyState: SideCombatState
    ) -> Double {
        let totalEnemyUnits = Double(enemyState.totalUnits)
        guard totalEnemyUnits > 0 else { return 0 }

        let infantryRatio = Double(enemyState.infantryUnits) / totalEnemyUnits
        let cavalryRatio = Double(enemyState.cavalryUnits) / totalEnemyUnits
        let rangedRatio = Double(enemyState.rangedUnits) / totalEnemyUnits
        let siegeRatio = Double(enemyState.siegeUnits) / totalEnemyUnits

        return attackerStats.bonusVsInfantry * infantryRatio
             + attackerStats.bonusVsCavalry * cavalryRatio
             + attackerStats.bonusVsRanged * rangedRatio
             + attackerStats.bonusVsSiege * siegeRatio
    }

    // MARK: - Research Bonus Lookup

    /// Returns the flat damage bonus for a unit type from player research
    static func getResearchDamageBonus(for unitType: MilitaryUnitType, playerState: PlayerState?) -> Double {
        guard let ps = playerState else { return 0 }
        switch unitType.category {
        case .infantry:
            return ps.getResearchBonus(ResearchBonusType.infantryMeleeAttack.rawValue)
        case .cavalry:
            return ps.getResearchBonus(ResearchBonusType.cavalryMeleeAttack.rawValue)
        case .ranged:
            return ps.getResearchBonus(ResearchBonusType.piercingDamage.rawValue)
        case .siege:
            return ps.getResearchBonus(ResearchBonusType.siegeBludgeonDamage.rawValue)
        }
    }

    /// Returns the flat melee armor bonus for a unit category from player research
    static func getResearchMeleeArmorBonus(for category: UnitCategoryData, playerState: PlayerState?) -> Double {
        guard let ps = playerState else { return 0 }
        switch category {
        case .infantry:
            return ps.getResearchBonus(ResearchBonusType.infantryMeleeArmor.rawValue)
        case .cavalry:
            return ps.getResearchBonus(ResearchBonusType.cavalryMeleeArmor.rawValue)
        case .ranged:
            return ps.getResearchBonus(ResearchBonusType.archerMeleeArmor.rawValue)
        case .siege:
            return 0
        }
    }

    /// Returns the flat pierce armor bonus for a unit category from player research
    static func getResearchPierceArmorBonus(for category: UnitCategoryData, playerState: PlayerState?) -> Double {
        guard let ps = playerState else { return 0 }
        switch category {
        case .infantry:
            return ps.getResearchBonus(ResearchBonusType.infantryPierceArmor.rawValue)
        case .cavalry:
            return ps.getResearchBonus(ResearchBonusType.cavalryPierceArmor.rawValue)
        case .ranged:
            return ps.getResearchBonus(ResearchBonusType.archerPierceArmor.rawValue)
        case .siege:
            return 0
        }
    }

    // MARK: - DPS Calculations

    static func calculateRangedDPS(_ sideState: SideCombatState, enemyState: SideCombatState, terrainPenalty: Double = 0, terrainBonus: Double = 0, playerState: PlayerState? = nil, tacticsBonus: Double = 0) -> Double {
        var totalDPS: Double = 0

        for (unitType, count) in sideState.unitCounts {
            guard count > 0 else { continue }
            guard unitType.category == .ranged || unitType.category == .siege else { continue }

            let stats = unitType.combatStats
            let researchBonus = getResearchDamageBonus(for: unitType, playerState: playerState)
            let baseDamage = stats.totalDamage + researchBonus
            let bonusDamage = calculateWeightedBonus(attackerStats: stats, enemyState: enemyState)
            let unitDPS = max(1.0 / unitType.attackSpeed, (baseDamage + bonusDamage) / unitType.attackSpeed)
            totalDPS += unitDPS * Double(count)
        }

        return applyTerrainModifier(to: totalDPS, terrainPenalty: terrainPenalty, terrainBonus: terrainBonus, tacticsBonus: tacticsBonus)
    }

    static func calculateMeleeDPS(_ sideState: SideCombatState, enemyState: SideCombatState, isCharge: Bool, terrainPenalty: Double = 0, terrainBonus: Double = 0, playerState: PlayerState? = nil, tacticsBonus: Double = 0) -> Double {
        var totalDPS: Double = 0

        for (unitType, count) in sideState.unitCounts {
            guard count > 0 else { continue }
            guard unitType.category == .infantry || unitType.category == .cavalry else { continue }

            let stats = unitType.combatStats
            let researchBonus = getResearchDamageBonus(for: unitType, playerState: playerState)
            let baseDamage = stats.totalDamage + researchBonus
            let bonusDamage = calculateWeightedBonus(attackerStats: stats, enemyState: enemyState)
            var unitDPS = max(1.0 / unitType.attackSpeed, (baseDamage + bonusDamage) / unitType.attackSpeed)

            if isCharge {
                if unitType.category == .cavalry {
                    unitDPS *= (1.0 + cavalryChargeBonus)
                } else if unitType.category == .infantry {
                    unitDPS *= (1.0 + infantryChargeBonus)
                }
            }

            totalDPS += unitDPS * Double(count)
        }

        return applyTerrainModifier(to: totalDPS, terrainPenalty: terrainPenalty, terrainBonus: terrainBonus, tacticsBonus: tacticsBonus)
    }

    static func calculateTotalDPS(_ sideState: SideCombatState, enemyState: SideCombatState, terrainPenalty: Double = 0, terrainBonus: Double = 0, playerState: PlayerState? = nil, tacticsBonus: Double = 0) -> Double {
        var totalDPS: Double = 0

        for (unitType, count) in sideState.unitCounts {
            guard count > 0 else { continue }

            let stats = unitType.combatStats
            let researchBonus = getResearchDamageBonus(for: unitType, playerState: playerState)
            let baseDamage = stats.totalDamage + researchBonus
            let bonusDamage = calculateWeightedBonus(attackerStats: stats, enemyState: enemyState)
            let unitDPS = max(1.0 / unitType.attackSpeed, (baseDamage + bonusDamage) / unitType.attackSpeed)
            totalDPS += unitDPS * Double(count)
        }

        return applyTerrainModifier(to: totalDPS, terrainPenalty: terrainPenalty, terrainBonus: terrainBonus, tacticsBonus: tacticsBonus)
    }

    // MARK: - Damage Application

    static func applyDamageToSide(_ sideState: inout SideCombatState, damage: Double, combat: ActiveCombat, isDefender: Bool, state: GameState) {
        var remainingDamage = damage

        let priorityOrder: [UnitCategory] = [.siege, .ranged, .infantry, .cavalry]

        for category in priorityOrder {
            guard remainingDamage > 0 else { break }

            for (unitType, count) in sideState.unitCounts where unitType.category == category && count > 0 {
                guard remainingDamage > 0 else { break }

                let damageToApply = min(remainingDamage, Double(count) * unitType.hp)
                let kills = sideState.applyDamage(damageToApply, to: unitType)

                if kills > 0 {
                    combat.trackPhaseCasualty(isAttacker: !isDefender, unitType: unitType, count: kills)

                    if isDefender {
                        if let armyID = combat.defenderArmies.first?.armyID,
                           let army = state.getArmy(id: armyID) {
                            _ = army.removeMilitaryUnits(unitType, count: kills)
                        }
                    } else {
                        if let armyID = combat.attackerArmies.first?.armyID,
                           let army = state.getArmy(id: armyID) {
                            _ = army.removeMilitaryUnits(unitType, count: kills)
                        }
                    }
                }

                remainingDamage -= damageToApply
            }
        }
    }

    /// Apply damage to an army directly (used by garrison defense)
    static func applyDamageToArmy(_ army: ArmyData, damage: Double) -> [MilitaryUnitTypeData: Int] {
        var casualties: [MilitaryUnitTypeData: Int] = [:]
        var remainingDamage = damage

        for (unitType, count) in army.militaryComposition {
            guard remainingDamage > 0 && count > 0 else { continue }

            let unitHealth = unitType.hp
            let unitsKilled = min(count, Int(remainingDamage / unitHealth))

            if unitsKilled > 0 {
                army.removeMilitaryUnits(unitType, count: unitsKilled)
                casualties[unitType] = unitsKilled
                remainingDamage -= Double(unitsKilled) * unitHealth
            }
        }

        return casualties
    }
}
