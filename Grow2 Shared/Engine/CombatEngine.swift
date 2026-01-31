// ============================================================================
// FILE: Grow2 Shared/Engine/CombatEngine.swift
// PURPOSE: Handles all combat logic - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Combat State Data

struct ActiveCombatData {
    let id: UUID
    let attackerArmyID: UUID
    let defenderArmyID: UUID?
    let defenderBuildingID: UUID?
    var coordinate: HexCoordinate
    var currentPhase: Int = 0
    var startTime: TimeInterval
    var lastPhaseTime: TimeInterval
    var isComplete: Bool = false
    var result: CombatResultData?
}

// MARK: - Combat Engine

/// Handles all combat calculations and state
class CombatEngine {

    // MARK: - State
    private weak var gameState: GameState?

    // MARK: - Active Combats
    private(set) var activeCombats: [UUID: ActiveCombatData] = [:]

    // MARK: - Combat History
    private(set) var combatHistory: [CombatRecord] = []

    // MARK: - Combat Constants
    private let phaseInterval: TimeInterval = 1.0  // 1 second per phase
    private let maxPhases: Int = 10
    private let baseChargeBonus: Double = 0.2  // 20% charge bonus
    private let cavalryChargeBonus: Double = 0.2
    private let infantryChargeBonus: Double = 0.1

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
        activeCombats.removeAll()
    }

    // MARK: - Update Loop

    func update(currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []

        // Process each active combat
        var completedCombats: [UUID] = []

        for (combatID, var combat) in activeCombats {
            guard !combat.isComplete else {
                completedCombats.append(combatID)
                continue
            }

            // Check if it's time for the next phase
            if currentTime - combat.lastPhaseTime >= phaseInterval {
                let phaseChanges = processNextPhase(&combat, currentTime: currentTime, state: state)
                changes.append(contentsOf: phaseChanges)

                combat.lastPhaseTime = currentTime
                activeCombats[combatID] = combat

                if combat.isComplete {
                    completedCombats.append(combatID)
                }
            }
        }

        // Remove completed combats
        for combatID in completedCombats {
            activeCombats.removeValue(forKey: combatID)
        }

        // Check for garrison defense attacks
        let garrisonChanges = processGarrisonDefense(currentTime: currentTime, state: state)
        changes.append(contentsOf: garrisonChanges)

        return changes
    }

    // MARK: - Combat Initiation

    /// Start combat between two armies
    func startCombat(attackerArmyID: UUID, defenderArmyID: UUID, currentTime: TimeInterval) -> StateChange? {
        guard let state = gameState,
              let attacker = state.getArmy(id: attackerArmyID),
              let defender = state.getArmy(id: defenderArmyID) else {
            return nil
        }

        let combatID = UUID()
        let combat = ActiveCombatData(
            id: combatID,
            attackerArmyID: attackerArmyID,
            defenderArmyID: defenderArmyID,
            defenderBuildingID: nil,
            coordinate: defender.coordinate,
            startTime: currentTime,
            lastPhaseTime: currentTime
        )

        activeCombats[combatID] = combat

        // Mark armies as in combat
        attacker.isInCombat = true
        attacker.combatTargetID = defenderArmyID
        defender.isInCombat = true
        defender.combatTargetID = attackerArmyID

        return .combatStarted(
            attackerID: attackerArmyID,
            defenderID: defenderArmyID,
            coordinate: defender.coordinate
        )
    }

    /// Start combat against a building
    func startBuildingCombat(attackerArmyID: UUID, buildingID: UUID, currentTime: TimeInterval) -> StateChange? {
        guard let state = gameState,
              let attacker = state.getArmy(id: attackerArmyID),
              let building = state.getBuilding(id: buildingID) else {
            return nil
        }

        let combatID = UUID()
        let combat = ActiveCombatData(
            id: combatID,
            attackerArmyID: attackerArmyID,
            defenderArmyID: nil,
            defenderBuildingID: buildingID,
            coordinate: building.coordinate,
            startTime: currentTime,
            lastPhaseTime: currentTime
        )

        activeCombats[combatID] = combat

        attacker.isInCombat = true
        attacker.combatTargetID = buildingID

        return .combatStarted(
            attackerID: attackerArmyID,
            defenderID: buildingID,
            coordinate: building.coordinate
        )
    }

    // MARK: - Combat Phase Processing

    private func processNextPhase(_ combat: inout ActiveCombatData, currentTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []

        combat.currentPhase += 1

        if let defenderArmyID = combat.defenderArmyID {
            // Army vs Army combat
            let phaseChanges = processArmyVsArmyPhase(&combat, defenderArmyID: defenderArmyID, state: state)
            changes.append(contentsOf: phaseChanges)
        } else if let buildingID = combat.defenderBuildingID {
            // Army vs Building combat
            let phaseChanges = processArmyVsBuildingPhase(&combat, buildingID: buildingID, state: state)
            changes.append(contentsOf: phaseChanges)
        }

        changes.append(.combatPhaseCompleted(
            attackerID: combat.attackerArmyID,
            defenderID: combat.defenderArmyID ?? combat.defenderBuildingID ?? UUID(),
            phase: combat.currentPhase
        ))

        // Check for combat end
        if combat.currentPhase >= maxPhases {
            combat.isComplete = true
            let result = determineCombatResult(combat, state: state)
            combat.result = result

            changes.append(.combatEnded(
                attackerID: combat.attackerArmyID,
                defenderID: combat.defenderArmyID ?? combat.defenderBuildingID ?? UUID(),
                result: result
            ))

            // Clean up combat flags
            if let attacker = state.getArmy(id: combat.attackerArmyID) {
                attacker.isInCombat = false
                attacker.combatTargetID = nil
            }
            if let defenderID = combat.defenderArmyID,
               let defender = state.getArmy(id: defenderID) {
                defender.isInCombat = false
                defender.combatTargetID = nil
            }
        }

        return changes
    }

    private func processArmyVsArmyPhase(_ combat: inout ActiveCombatData, defenderArmyID: UUID, state: GameState) -> [StateChange] {
        guard let attacker = state.getArmy(id: combat.attackerArmyID),
              let defender = state.getArmy(id: defenderArmyID) else {
            combat.isComplete = true
            return []
        }

        var changes: [StateChange] = []

        // Calculate attacker damage
        let attackerDamage = calculateArmyDamage(attacker, isCharge: combat.currentPhase == 1, against: defender)

        // Calculate defender damage
        let defenderDamage = calculateArmyDamage(defender, isCharge: false, against: attacker)

        // Apply terrain modifiers
        let terrain = state.mapData.getTerrain(at: combat.coordinate)
        let defenderDefenseBonus = terrain?.defenderDefenseBonus ?? 0.0
        let attackerPenalty = terrain?.attackerAttackPenalty ?? 0.0

        let finalAttackerDamage = attackerDamage * (1.0 - attackerPenalty)
        let finalDefenderDamage = defenderDamage * (1.0 + defenderDefenseBonus)

        // Apply damage (remove units based on damage)
        let attackerCasualties = applyDamageToArmy(defender, damage: finalAttackerDamage)
        let defenderCasualties = applyDamageToArmy(attacker, damage: finalDefenderDamage)

        if finalAttackerDamage > 0 {
            changes.append(.combatDamageDealt(
                sourceID: combat.attackerArmyID,
                targetID: defenderArmyID,
                damage: finalAttackerDamage,
                damageType: "mixed"
            ))
        }

        if finalDefenderDamage > 0 {
            changes.append(.combatDamageDealt(
                sourceID: defenderArmyID,
                targetID: combat.attackerArmyID,
                damage: finalDefenderDamage,
                damageType: "mixed"
            ))
        }

        // Check for army destruction
        if attacker.isEmpty() || defender.isEmpty() {
            combat.isComplete = true
        }

        return changes
    }

    private func processArmyVsBuildingPhase(_ combat: inout ActiveCombatData, buildingID: UUID, state: GameState) -> [StateChange] {
        guard let attacker = state.getArmy(id: combat.attackerArmyID),
              let building = state.getBuilding(id: buildingID) else {
            combat.isComplete = true
            return []
        }

        var changes: [StateChange] = []

        // Calculate siege damage (siege units get bonus)
        var damage = calculateArmyDamage(attacker, isCharge: false, against: nil)

        // Siege bonus vs buildings
        let siegeCount = attacker.getUnitCountByCategory(.siege)
        if siegeCount > 0 {
            damage *= 1.5  // 50% bonus for having siege units
        }

        // Apply damage to building
        building.takeDamage(damage)

        changes.append(.combatDamageDealt(
            sourceID: combat.attackerArmyID,
            targetID: buildingID,
            damage: damage,
            damageType: "siege"
        ))

        changes.append(.buildingDamaged(
            buildingID: buildingID,
            currentHealth: building.health,
            maxHealth: building.maxHealth
        ))

        // Check for building destruction
        if building.health <= 0 {
            combat.isComplete = true

            changes.append(.buildingDestroyed(
                buildingID: buildingID,
                coordinate: building.coordinate
            ))

            // Remove building from game state
            state.removeBuilding(id: buildingID)
        }

        return changes
    }

    // MARK: - Garrison Defense

    private func processGarrisonDefense(currentTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []

        for building in state.buildings.values {
            guard building.canProvideGarrisonDefense && building.hasDefensiveGarrison() else { continue }
            guard let ownerID = building.ownerID else { continue }

            // Find enemies in range
            let enemies = state.getEnemyArmiesInRange(
                of: building.coordinate,
                range: building.garrisonDefenseRange,
                forPlayer: ownerID
            )

            guard !enemies.isEmpty else { continue }

            // Attack the first enemy in range
            let target = enemies[0]
            let damage = building.getTotalGarrisonDefenseDamage()

            if damage > 0 {
                _ = applyDamageToArmy(target, damage: damage)

                changes.append(.garrisonDefenseAttack(
                    buildingID: building.id,
                    targetArmyID: target.id,
                    damage: damage
                ))

                // Check if army was destroyed
                if target.isEmpty() {
                    changes.append(.armyDestroyed(
                        armyID: target.id,
                        coordinate: target.coordinate
                    ))
                    state.removeArmy(id: target.id)
                }
            }
        }

        return changes
    }

    // MARK: - Damage Calculations

    private func calculateArmyDamage(_ army: ArmyData, isCharge: Bool, against defender: ArmyData?) -> Double {
        let attackerStats = army.getAggregatedCombatStats()

        var totalDamage: Double
        if let defender = defender {
            // Calculate effective damage using per-type armor reduction
            let defenderStats = defender.getAggregatedCombatStats()
            let defenderCategory = defender.getPrimaryCategory()
            totalDamage = attackerStats.calculateEffectiveDamage(against: defenderStats, targetCategory: defenderCategory)
        } else {
            // No defender (attacking buildings) - use raw damage
            totalDamage = attackerStats.totalDamage
        }

        // Apply charge bonus on first phase
        if isCharge {
            let cavalryCount = army.getUnitCountByCategory(.cavalry)
            let infantryCount = army.getUnitCountByCategory(.infantry)
            let totalUnits = army.getTotalUnits()

            if totalUnits > 0 {
                let cavalryRatio = Double(cavalryCount) / Double(totalUnits)
                let infantryRatio = Double(infantryCount) / Double(totalUnits)

                let chargeBonus = 1.0 + (cavalryRatio * cavalryChargeBonus) + (infantryRatio * infantryChargeBonus)
                totalDamage *= chargeBonus
            }
        }

        return totalDamage
    }

    private func applyDamageToArmy(_ army: ArmyData, damage: Double) -> [MilitaryUnitTypeData: Int] {
        var casualties: [MilitaryUnitTypeData: Int] = [:]
        var remainingDamage = damage

        // Distribute damage across unit types using their HP
        for (unitType, count) in army.militaryComposition {
            guard remainingDamage > 0 && count > 0 else { continue }

            let unitHealth = unitType.hp  // Use unit's HP instead of legacy defensePower + 10
            let unitsKilled = min(count, Int(remainingDamage / unitHealth))

            if unitsKilled > 0 {
                army.removeMilitaryUnits(unitType, count: unitsKilled)
                casualties[unitType] = unitsKilled
                remainingDamage -= Double(unitsKilled) * unitHealth
            }
        }

        return casualties
    }

    // MARK: - Combat Resolution

    private func determineCombatResult(_ combat: ActiveCombatData, state: GameState) -> CombatResultData {
        var winnerID: UUID?
        var loserID: UUID?

        if let defenderArmyID = combat.defenderArmyID {
            let attacker = state.getArmy(id: combat.attackerArmyID)
            let defender = state.getArmy(id: defenderArmyID)

            if attacker?.isEmpty() == true && defender?.isEmpty() == true {
                // Draw
            } else if attacker?.isEmpty() == true {
                winnerID = defenderArmyID
                loserID = combat.attackerArmyID
            } else if defender?.isEmpty() == true {
                winnerID = combat.attackerArmyID
                loserID = defenderArmyID
            } else {
                // Compare remaining strength using total HP as a tiebreaker
                let attackerStrength = attacker?.getAggregatedCombatStats().totalDamage ?? 0
                let defenderStrength = defender?.getAggregatedCombatStats().totalDamage ?? 0

                if attackerStrength > defenderStrength {
                    winnerID = combat.attackerArmyID
                    loserID = defenderArmyID
                } else if defenderStrength > attackerStrength {
                    winnerID = defenderArmyID
                    loserID = combat.attackerArmyID
                } else {
                    // If damage is equal, compare HP
                    let attackerHP = attacker?.getTotalHP() ?? 0
                    let defenderHP = defender?.getTotalHP() ?? 0
                    if attackerHP >= defenderHP {
                        winnerID = combat.attackerArmyID
                        loserID = defenderArmyID
                    } else {
                        winnerID = defenderArmyID
                        loserID = combat.attackerArmyID
                    }
                }
            }
        }

        return CombatResultData(
            winnerID: winnerID,
            loserID: loserID,
            attackerCasualties: [:],
            defenderCasualties: [:],
            combatDuration: TimeInterval(combat.currentPhase) * phaseInterval
        )
    }

    // MARK: - Query Methods

    func isInCombat(armyID: UUID) -> Bool {
        return activeCombats.values.contains { $0.attackerArmyID == armyID || $0.defenderArmyID == armyID }
    }

    func getCombat(involving armyID: UUID) -> ActiveCombatData? {
        return activeCombats.values.first { $0.attackerArmyID == armyID || $0.defenderArmyID == armyID }
    }

    // MARK: - Combat History

    func addCombatRecord(_ record: CombatRecord) {
        combatHistory.insert(record, at: 0)  // Most recent first
    }

    func getCombatHistory() -> [CombatRecord] {
        return combatHistory
    }

    func clearCombatHistory() {
        combatHistory.removeAll()
        activeCombats.removeAll()
        print("🗑️ Combat history cleared")
    }

    // MARK: - Retreat

    func retreatFromCombat(armyID: UUID) {
        // Find and remove the combat involving this army
        if let combatID = activeCombats.first(where: { $0.value.attackerArmyID == armyID || $0.value.defenderArmyID == armyID })?.key {
            activeCombats.removeValue(forKey: combatID)
        }

        // Mark army as retreating
        if let army = gameState?.getArmy(id: armyID) {
            army.isRetreating = true
        }
    }
}
