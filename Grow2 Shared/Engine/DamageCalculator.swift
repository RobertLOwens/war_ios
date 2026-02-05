// ============================================================================
// FILE: Grow2 Shared/Engine/DamageCalculator.swift
// PURPOSE: Extracted DPS calculation logic from CombatEngine
// ============================================================================

import Foundation

/// Handles all damage-per-second calculations for the combat system.
/// Extracted from CombatEngine for clarity and testability.
struct DamageCalculator {

    // MARK: - Charge Bonuses
    static let cavalryChargeBonus: Double = 0.2
    static let infantryChargeBonus: Double = 0.1

    // MARK: - Terrain Modifier

    static func applyTerrainModifier(to dps: Double, terrainPenalty: Double, terrainBonus: Double) -> Double {
        let modifier = 1.0 - terrainPenalty + terrainBonus
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

    // MARK: - DPS Calculations

    static func calculateRangedDPS(_ sideState: SideCombatState, enemyState: SideCombatState, terrainPenalty: Double = 0, terrainBonus: Double = 0) -> Double {
        var totalDPS: Double = 0

        for (unitType, count) in sideState.unitCounts {
            guard count > 0 else { continue }
            guard unitType.category == .ranged || unitType.category == .siege else { continue }

            let stats = unitType.combatStats
            let baseDamage = stats.totalDamage
            let bonusDamage = calculateWeightedBonus(attackerStats: stats, enemyState: enemyState)
            let unitDPS = (baseDamage + bonusDamage) / unitType.attackSpeed
            totalDPS += unitDPS * Double(count)
        }

        return applyTerrainModifier(to: totalDPS, terrainPenalty: terrainPenalty, terrainBonus: terrainBonus)
    }

    static func calculateMeleeDPS(_ sideState: SideCombatState, enemyState: SideCombatState, isCharge: Bool, terrainPenalty: Double = 0, terrainBonus: Double = 0) -> Double {
        var totalDPS: Double = 0

        for (unitType, count) in sideState.unitCounts {
            guard count > 0 else { continue }
            guard unitType.category == .infantry || unitType.category == .cavalry else { continue }

            let stats = unitType.combatStats
            let baseDamage = stats.totalDamage
            let bonusDamage = calculateWeightedBonus(attackerStats: stats, enemyState: enemyState)
            var unitDPS = (baseDamage + bonusDamage) / unitType.attackSpeed

            if isCharge {
                if unitType.category == .cavalry {
                    unitDPS *= (1.0 + cavalryChargeBonus)
                } else if unitType.category == .infantry {
                    unitDPS *= (1.0 + infantryChargeBonus)
                }
            }

            totalDPS += unitDPS * Double(count)
        }

        return applyTerrainModifier(to: totalDPS, terrainPenalty: terrainPenalty, terrainBonus: terrainBonus)
    }

    static func calculateTotalDPS(_ sideState: SideCombatState, enemyState: SideCombatState, terrainPenalty: Double = 0, terrainBonus: Double = 0) -> Double {
        var totalDPS: Double = 0

        for (unitType, count) in sideState.unitCounts {
            guard count > 0 else { continue }

            let stats = unitType.combatStats
            let baseDamage = stats.totalDamage
            let bonusDamage = calculateWeightedBonus(attackerStats: stats, enemyState: enemyState)
            let unitDPS = (baseDamage + bonusDamage) / unitType.attackSpeed
            totalDPS += unitDPS * Double(count)
        }

        return applyTerrainModifier(to: totalDPS, terrainPenalty: terrainPenalty, terrainBonus: terrainBonus)
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
