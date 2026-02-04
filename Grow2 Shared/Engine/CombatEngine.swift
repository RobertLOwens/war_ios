// ============================================================================
// FILE: Grow2 Shared/Engine/CombatEngine.swift
// PURPOSE: Handles all combat logic using the 3-phase combat system
// ============================================================================

import Foundation
import UIKit

// MARK: - Combat State Data (Legacy - kept for UI/History compatibility)

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

    // Building damage tracking
    var buildingType: String?
    var buildingHealthBefore: Double = 0
    var totalBuildingDamage: Double = 0
}

/// Data for army vs villager combat (quick massacre - villagers don't fight back)
struct VillagerCombatData {
    let id: UUID
    let attackerArmyID: UUID
    let defenderVillagerGroupID: UUID
    let defenderOwnerID: UUID?
    var coordinate: HexCoordinate
    var startTime: TimeInterval
    var lastTickTime: TimeInterval
    var isComplete: Bool = false
    var villagersKilled: Int = 0
    let initialVillagerCount: Int
    var accumulatedDamage: Double = 0.0
}

// MARK: - Combat Engine

/// Handles all combat calculations and state using the 3-phase combat system:
/// - Ranged Exchange (0-3s): Only ranged/siege units deal damage
/// - Melee Engagement (3s+): All units fight
/// - Cleanup: One side's melee units are gone
class CombatEngine {

    // MARK: - State
    private weak var gameState: GameState?

    // MARK: - Active Combats (using proper 3-phase system)
    private(set) var activeCombats: [UUID: ActiveCombat] = [:]

    // MARK: - Building Combats (separate tracking for army vs building)
    private(set) var buildingCombats: [UUID: ActiveCombatData] = [:]

    // MARK: - Villager Combats (army vs villager group)
    private(set) var villagerCombats: [UUID: VillagerCombatData] = [:]

    // MARK: - Garrison Defense Tracking
    private var activeGarrisonEngagements: Set<UUID> = []  // Army IDs currently under garrison fire

    // MARK: - Combat History
    private(set) var combatHistory: [CombatRecord] = []
    private(set) var detailedCombatHistory: [DetailedCombatRecord] = []

    // MARK: - Combat Constants
    private let cavalryChargeBonus: Double = 0.2
    private let infantryChargeBonus: Double = 0.1
    private let buildingPhaseInterval: TimeInterval = 1.0

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
        activeCombats.removeAll()
        buildingCombats.removeAll()
        villagerCombats.removeAll()
        activeGarrisonEngagements.removeAll()
    }

    // MARK: - Update Loop

    func update(currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []

        // Process army vs army combats (3-phase system)
        let armyChanges = processArmyCombats(currentTime: currentTime, state: state)
        changes.append(contentsOf: armyChanges)

        // Process army vs building combats (simpler phase system)
        let buildingChanges = processBuildingCombats(currentTime: currentTime, state: state)
        changes.append(contentsOf: buildingChanges)

        // Process army vs villager combats (quick massacre)
        let villagerChanges = processVillagerCombats(currentTime: currentTime, state: state)
        changes.append(contentsOf: villagerChanges)

        // Check for garrison defense attacks
        let garrisonChanges = processGarrisonDefense(currentTime: currentTime, state: state)
        changes.append(contentsOf: garrisonChanges)

        return changes
    }

    // MARK: - Army vs Army Combat Processing (3-Phase System)

    private func processArmyCombats(currentTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []
        var completedCombats: [UUID] = []

        for (combatID, combat) in activeCombats {
            guard combat.phase != .ended else {
                completedCombats.append(combatID)
                continue
            }

            // Calculate elapsed time since combat started (using game time, not Unix time)
            let newElapsed = currentTime - combat.gameStartTime
            let deltaTime = newElapsed - combat.elapsedTime

            // Skip if no time has passed
            guard deltaTime > 0 else { continue }

            combat.elapsedTime = newElapsed

            // Check phase transition
            let previousPhase = combat.phase
            combat.updatePhase()

            if combat.phase != previousPhase {
                print("⚔️ Combat phase changed: \(previousPhase.displayName) -> \(combat.phase.displayName)")
                changes.append(.combatPhaseCompleted(
                    attackerID: combat.attackerArmies.first?.armyID ?? UUID(),
                    defenderID: combat.defenderArmies.first?.armyID ?? UUID(),
                    phase: phaseToInt(combat.phase)
                ))
            }

            // Process damage based on current phase
            let phaseChanges = processCombatDamage(combat, deltaTime: deltaTime, state: state)
            changes.append(contentsOf: phaseChanges)

            // Notify UI of combat update
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .phasedCombatUpdated, object: combat)
            }

            // Check for combat end
            if combat.shouldEnd {
                combat.phase = .ended
                completedCombats.append(combatID)

                let result = determineCombatResult(combat)
                changes.append(.combatEnded(
                    attackerID: combat.attackerArmies.first?.armyID ?? UUID(),
                    defenderID: combat.defenderArmies.first?.armyID ?? UUID(),
                    result: result
                ))

                // Save combat record to history (both basic and detailed)
                let combatRecord = createCombatRecord(from: combat, state: state)
                addCombatRecord(combatRecord)

                let detailedRecord = createDetailedCombatRecord(from: combat, state: state)
                addDetailedCombatRecord(detailedRecord)

                // Clean up combat flags on armies
                cleanupCombatFlags(combat, state: state)

                // Auto-retreat for the losing army
                if let loserID = result.loserID {
                    initiateAutoRetreat(for: loserID, state: state)
                }

                // Auto-attack enemy building at combat location if attacker won
                if let winnerID = result.winnerID,
                   combat.attackerArmies.contains(where: { $0.armyID == winnerID }) {
                    // Winner was the attacker - check for enemy building at this location
                    autoStartBuildingCombat(for: winnerID, at: combat.location, state: state, currentTime: currentTime, changes: &changes)
                }

                // Notify UI of combat end
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .phasedCombatEnded, object: combat)
                }
            }
        }

        // Remove completed combats
        for id in completedCombats {
            activeCombats.removeValue(forKey: id)
        }

        return changes
    }

    private func phaseToInt(_ phase: CombatPhase) -> Int {
        switch phase {
        case .rangedExchange: return 1
        case .meleeEngagement: return 2
        case .cleanup: return 3
        case .ended: return 4
        }
    }

    // MARK: - Combat Initiation

    /// Start combat between two armies using the 3-phase system
    func startCombat(attackerArmyID: UUID, defenderArmyID: UUID, currentTime: TimeInterval) -> StateChange? {
        guard let state = gameState else {
            print("❌ CombatEngine: gameState is nil")
            return nil
        }
        guard let attacker = state.getArmy(id: attackerArmyID) else {
            print("❌ CombatEngine: Attacker army not found in GameState (ID: \(attackerArmyID))")
            return nil
        }
        guard let defender = state.getArmy(id: defenderArmyID) else {
            print("❌ CombatEngine: Defender army not found in GameState (ID: \(defenderArmyID))")
            return nil
        }

        // Get terrain at combat location
        let terrain = state.mapData.getTerrain(at: defender.coordinate) ?? .plains

        // Create the ActiveCombat using the 3-phase system
        let combat = ActiveCombat(
            attackerData: attacker,
            defenderData: defender,
            location: defender.coordinate,
            terrainType: terrain,
            gameStartTime: currentTime
        )

        // Store with combat's own ID
        activeCombats[combat.id] = combat

        // Mark armies as in combat
        attacker.isInCombat = true
        attacker.combatTargetID = defenderArmyID
        defender.isInCombat = true
        defender.combatTargetID = attackerArmyID

        // Debug logging for terrain bonuses
        print("⚔️ Combat started: Phase \(combat.phase.displayName) at \(defender.coordinate)")
        print("   📍 Terrain: \(terrain.displayName)")
        if combat.terrainDefenseBonus > 0 {
            print("   🛡️ Defender defense bonus: +\(Int(combat.terrainDefenseBonus * 100))%")
        }
        if combat.terrainAttackPenalty > 0 {
            print("   ⚔️ Attacker attack penalty: -\(Int(combat.terrainAttackPenalty * 100))%")
        }
        if combat.terrainDefenseBonus == 0 && combat.terrainAttackPenalty == 0 {
            print("   ⚖️ No terrain modifiers")
        }

        return .combatStarted(
            attackerID: attackerArmyID,
            defenderID: defenderArmyID,
            coordinate: defender.coordinate
        )
    }

    /// Start combat against a building (uses simpler phase system)
    func startBuildingCombat(attackerArmyID: UUID, buildingID: UUID, currentTime: TimeInterval) -> StateChange? {
        guard let state = gameState,
              let attacker = state.getArmy(id: attackerArmyID),
              let building = state.getBuilding(id: buildingID) else {
            return nil
        }

        let combatID = UUID()
        var combat = ActiveCombatData(
            id: combatID,
            attackerArmyID: attackerArmyID,
            defenderArmyID: nil,
            defenderBuildingID: buildingID,
            coordinate: building.coordinate,
            startTime: currentTime,
            lastPhaseTime: currentTime
        )

        // Track building info for damage reporting
        combat.buildingType = building.buildingType.displayName
        combat.buildingHealthBefore = building.health

        buildingCombats[combatID] = combat

        attacker.isInCombat = true
        attacker.combatTargetID = buildingID

        return .combatStarted(
            attackerID: attackerArmyID,
            defenderID: buildingID,
            coordinate: building.coordinate
        )
    }

    /// Start combat against a villager group (army massacres defenseless civilians)
    func startVillagerCombat(attackerArmyID: UUID, defenderVillagerGroupID: UUID, currentTime: TimeInterval) -> StateChange? {
        guard let state = gameState,
              let attacker = state.getArmy(id: attackerArmyID),
              let villagerGroup = state.getVillagerGroup(id: defenderVillagerGroupID) else {
            return nil
        }

        let combatID = UUID()
        let combat = VillagerCombatData(
            id: combatID,
            attackerArmyID: attackerArmyID,
            defenderVillagerGroupID: defenderVillagerGroupID,
            defenderOwnerID: villagerGroup.ownerID,
            coordinate: villagerGroup.coordinate,
            startTime: currentTime,
            lastTickTime: currentTime,
            initialVillagerCount: villagerGroup.villagerCount
        )

        villagerCombats[combatID] = combat

        attacker.isInCombat = true
        attacker.combatTargetID = defenderVillagerGroupID

        print("⚔️ Army vs Villagers combat started: \(attacker.name) attacking \(villagerGroup.villagerCount) villagers")

        return .combatStarted(
            attackerID: attackerArmyID,
            defenderID: defenderVillagerGroupID,
            coordinate: villagerGroup.coordinate
        )
    }

    // MARK: - Phase-Specific Damage Processing

    private func processCombatDamage(_ combat: ActiveCombat, deltaTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []

        switch combat.phase {
        case .rangedExchange:
            // Only ranged and siege units deal damage
            processRangedDamage(combat, deltaTime: deltaTime, changes: &changes, state: state)

        case .meleeEngagement:
            // Ranged continue, melee units now engage
            processRangedDamage(combat, deltaTime: deltaTime, changes: &changes, state: state)
            processMeleeDamage(combat, deltaTime: deltaTime, changes: &changes, state: state)

        case .cleanup:
            // All remaining units attack
            processAllDamage(combat, deltaTime: deltaTime, changes: &changes, state: state)

        case .ended:
            break
        }

        return changes
    }

    private func processRangedDamage(_ combat: ActiveCombat, deltaTime: TimeInterval, changes: inout [StateChange], state: GameState) {
        // Calculate DPS from ranged/siege units only, including bonus damage vs enemy composition
        let attackerRangedDPS = calculateRangedDPS(combat.attackerState, enemyState: combat.defenderState, terrainPenalty: combat.terrainAttackPenalty)
        let defenderRangedDPS = calculateRangedDPS(combat.defenderState, enemyState: combat.attackerState, terrainBonus: combat.terrainDefenseBonus)

        let attackerDamage = attackerRangedDPS * deltaTime
        let defenderDamage = defenderRangedDPS * deltaTime

        // Apply damage to defender from attacker's ranged units
        if attackerDamage > 0 {
            applyDamageToSide(&combat.defenderState, damage: attackerDamage, combat: combat, isDefender: true, state: state)
            combat.trackPhaseDamage(byAttacker: true, amount: attackerDamage)
            // Track damage dealt by attacker's ranged/siege units
            trackDamageDealtByCategory(&combat.attackerState, damage: attackerDamage, categories: [.ranged, .siege])

            if let attackerID = combat.attackerArmies.first?.armyID,
               let defenderID = combat.defenderArmies.first?.armyID {
                changes.append(.combatDamageDealt(
                    sourceID: attackerID,
                    targetID: defenderID,
                    damage: attackerDamage,
                    damageType: "ranged"
                ))
            }
        }

        // Apply damage to attacker from defender's ranged units
        if defenderDamage > 0 {
            applyDamageToSide(&combat.attackerState, damage: defenderDamage, combat: combat, isDefender: false, state: state)
            combat.trackPhaseDamage(byAttacker: false, amount: defenderDamage)
            // Track damage dealt by defender's ranged/siege units
            trackDamageDealtByCategory(&combat.defenderState, damage: defenderDamage, categories: [.ranged, .siege])

            if let attackerID = combat.attackerArmies.first?.armyID,
               let defenderID = combat.defenderArmies.first?.armyID {
                changes.append(.combatDamageDealt(
                    sourceID: defenderID,
                    targetID: attackerID,
                    damage: defenderDamage,
                    damageType: "ranged"
                ))
            }
        }
    }

    private func processMeleeDamage(_ combat: ActiveCombat, deltaTime: TimeInterval, changes: inout [StateChange], state: GameState) {
        // Calculate DPS from infantry/cavalry units, including bonus damage vs enemy composition
        let isCharging = combat.elapsedTime < ActiveCombat.meleeEngagementThreshold + 1.0  // 1 second charge window after melee starts
        let attackerMeleeDPS = calculateMeleeDPS(combat.attackerState, enemyState: combat.defenderState, isCharge: isCharging, terrainPenalty: combat.terrainAttackPenalty)
        let defenderMeleeDPS = calculateMeleeDPS(combat.defenderState, enemyState: combat.attackerState, isCharge: false, terrainBonus: combat.terrainDefenseBonus)

        let attackerDamage = attackerMeleeDPS * deltaTime
        let defenderDamage = defenderMeleeDPS * deltaTime

        // Apply damage to defender from attacker's melee units
        if attackerDamage > 0 {
            applyDamageToSide(&combat.defenderState, damage: attackerDamage, combat: combat, isDefender: true, state: state)
            combat.trackPhaseDamage(byAttacker: true, amount: attackerDamage)
            // Track damage dealt by attacker's melee units
            trackDamageDealtByCategory(&combat.attackerState, damage: attackerDamage, categories: [.infantry, .cavalry])

            if let attackerID = combat.attackerArmies.first?.armyID,
               let defenderID = combat.defenderArmies.first?.armyID {
                changes.append(.combatDamageDealt(
                    sourceID: attackerID,
                    targetID: defenderID,
                    damage: attackerDamage,
                    damageType: "melee"
                ))
            }
        }

        // Apply damage to attacker from defender's melee units
        if defenderDamage > 0 {
            applyDamageToSide(&combat.attackerState, damage: defenderDamage, combat: combat, isDefender: false, state: state)
            combat.trackPhaseDamage(byAttacker: false, amount: defenderDamage)
            // Track damage dealt by defender's melee units
            trackDamageDealtByCategory(&combat.defenderState, damage: defenderDamage, categories: [.infantry, .cavalry])

            if let attackerID = combat.attackerArmies.first?.armyID,
               let defenderID = combat.defenderArmies.first?.armyID {
                changes.append(.combatDamageDealt(
                    sourceID: defenderID,
                    targetID: attackerID,
                    damage: defenderDamage,
                    damageType: "melee"
                ))
            }
        }
    }

    private func processAllDamage(_ combat: ActiveCombat, deltaTime: TimeInterval, changes: inout [StateChange], state: GameState) {
        // In cleanup phase, all units attack, including bonus damage vs enemy composition
        let attackerTotalDPS = calculateTotalDPS(combat.attackerState, enemyState: combat.defenderState, terrainPenalty: combat.terrainAttackPenalty)
        let defenderTotalDPS = calculateTotalDPS(combat.defenderState, enemyState: combat.attackerState, terrainBonus: combat.terrainDefenseBonus)

        let attackerDamage = attackerTotalDPS * deltaTime
        let defenderDamage = defenderTotalDPS * deltaTime

        if attackerDamage > 0 {
            applyDamageToSide(&combat.defenderState, damage: attackerDamage, combat: combat, isDefender: true, state: state)
            combat.trackPhaseDamage(byAttacker: true, amount: attackerDamage)
            // Track damage dealt by all attacker units
            trackDamageDealtByCategory(&combat.attackerState, damage: attackerDamage, categories: [.infantry, .cavalry, .ranged, .siege])

            if let attackerID = combat.attackerArmies.first?.armyID,
               let defenderID = combat.defenderArmies.first?.armyID {
                changes.append(.combatDamageDealt(
                    sourceID: attackerID,
                    targetID: defenderID,
                    damage: attackerDamage,
                    damageType: "mixed"
                ))
            }
        }

        if defenderDamage > 0 {
            applyDamageToSide(&combat.attackerState, damage: defenderDamage, combat: combat, isDefender: false, state: state)
            combat.trackPhaseDamage(byAttacker: false, amount: defenderDamage)
            // Track damage dealt by all defender units
            trackDamageDealtByCategory(&combat.defenderState, damage: defenderDamage, categories: [.infantry, .cavalry, .ranged, .siege])

            if let attackerID = combat.attackerArmies.first?.armyID,
               let defenderID = combat.defenderArmies.first?.armyID {
                changes.append(.combatDamageDealt(
                    sourceID: defenderID,
                    targetID: attackerID,
                    damage: defenderDamage,
                    damageType: "mixed"
                ))
            }
        }
    }

    // MARK: - Damage Dealt Tracking

    /// Tracks damage dealt by units in specified categories, distributing proportionally
    private func trackDamageDealtByCategory(_ sideState: inout SideCombatState, damage: Double, categories: [UnitCategory]) {
        // Get total DPS from units in these categories to distribute damage proportionally
        var totalDPS: Double = 0
        var unitDPSMap: [MilitaryUnitType: Double] = [:]

        for (unitType, count) in sideState.unitCounts {
            guard count > 0, categories.contains(unitType.category) else { continue }
            let unitDPS = unitType.combatStats.totalDamage / unitType.attackSpeed * Double(count)
            unitDPSMap[unitType] = unitDPS
            totalDPS += unitDPS
        }

        guard totalDPS > 0 else { return }

        // Distribute damage proportionally based on each unit type's contribution
        for (unitType, unitDPS) in unitDPSMap {
            let proportion = unitDPS / totalDPS
            let damageContribution = damage * proportion
            sideState.trackDamageDealt(damageContribution, by: unitType)
        }
    }

    // MARK: - DPS Calculations

    /// Calculates weighted bonus damage based on enemy unit category composition
    /// For example: If the enemy has 50% cavalry and the attacker has +8 vs cavalry,
    /// the weighted bonus is 0.5 * 8 = 4 bonus damage per attack
    private func calculateWeightedBonus(
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

    private func calculateRangedDPS(_ sideState: SideCombatState, enemyState: SideCombatState, terrainPenalty: Double = 0, terrainBonus: Double = 0) -> Double {
        var totalDPS: Double = 0

        for (unitType, count) in sideState.unitCounts {
            guard count > 0 else { continue }

            // Only ranged and siege units contribute in ranged phase
            guard unitType.category == .ranged || unitType.category == .siege else { continue }

            let stats = unitType.combatStats
            let baseDamage = stats.totalDamage
            let bonusDamage = calculateWeightedBonus(attackerStats: stats, enemyState: enemyState)
            let unitDPS = (baseDamage + bonusDamage) / unitType.attackSpeed
            totalDPS += unitDPS * Double(count)
        }

        // Apply terrain modifiers
        let modifier = 1.0 - terrainPenalty + terrainBonus
        return totalDPS * modifier
    }

    private func calculateMeleeDPS(_ sideState: SideCombatState, enemyState: SideCombatState, isCharge: Bool, terrainPenalty: Double = 0, terrainBonus: Double = 0) -> Double {
        var totalDPS: Double = 0

        for (unitType, count) in sideState.unitCounts {
            guard count > 0 else { continue }

            // Only infantry and cavalry contribute in melee phase
            guard unitType.category == .infantry || unitType.category == .cavalry else { continue }

            let stats = unitType.combatStats
            let baseDamage = stats.totalDamage
            let bonusDamage = calculateWeightedBonus(attackerStats: stats, enemyState: enemyState)
            var unitDPS = (baseDamage + bonusDamage) / unitType.attackSpeed

            // Apply charge bonus
            if isCharge {
                if unitType.category == .cavalry {
                    unitDPS *= (1.0 + cavalryChargeBonus)
                } else if unitType.category == .infantry {
                    unitDPS *= (1.0 + infantryChargeBonus)
                }
            }

            totalDPS += unitDPS * Double(count)
        }

        // Apply terrain modifiers
        let modifier = 1.0 - terrainPenalty + terrainBonus
        return totalDPS * modifier
    }

    private func calculateTotalDPS(_ sideState: SideCombatState, enemyState: SideCombatState, terrainPenalty: Double = 0, terrainBonus: Double = 0) -> Double {
        var totalDPS: Double = 0

        for (unitType, count) in sideState.unitCounts {
            guard count > 0 else { continue }

            let stats = unitType.combatStats
            let baseDamage = stats.totalDamage
            let bonusDamage = calculateWeightedBonus(attackerStats: stats, enemyState: enemyState)
            let unitDPS = (baseDamage + bonusDamage) / unitType.attackSpeed
            totalDPS += unitDPS * Double(count)
        }

        // Apply terrain modifiers
        let modifier = 1.0 - terrainPenalty + terrainBonus
        return totalDPS * modifier
    }

    // MARK: - Damage Application

    private func applyDamageToSide(_ sideState: inout SideCombatState, damage: Double, combat: ActiveCombat, isDefender: Bool, state: GameState) {
        var remainingDamage = damage

        // Priority order for damage: siege, ranged, infantry, cavalry
        let priorityOrder: [UnitCategory] = [.siege, .ranged, .infantry, .cavalry]

        for category in priorityOrder {
            guard remainingDamage > 0 else { break }

            for (unitType, count) in sideState.unitCounts where unitType.category == category && count > 0 {
                guard remainingDamage > 0 else { break }

                let damageToApply = min(remainingDamage, Double(count) * unitType.hp)
                let kills = sideState.applyDamage(damageToApply, to: unitType)

                if kills > 0 {
                    combat.trackPhaseCasualty(isAttacker: !isDefender, unitType: unitType, count: kills)

                    // Also update the actual army data
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

    // MARK: - Auto-Start Building Combat

    /// Automatically starts combat against an enemy building at the given location
    /// Called after winning army vs army combat
    private func autoStartBuildingCombat(for armyID: UUID, at location: HexCoordinate, state: GameState, currentTime: TimeInterval, changes: inout [StateChange]) {
        guard let army = state.getArmy(id: armyID),
              let ownerID = army.ownerID else {
            return
        }

        // Find enemy building at this location
        guard let building = state.getBuilding(at: location),
              let buildingOwnerID = building.ownerID,
              buildingOwnerID != ownerID,
              building.isOperational else {
            return
        }

        // Start building combat
        print("⚔️ Auto-starting building attack: \(army.name) vs \(building.buildingType.displayName)")

        if let combatChange = startBuildingCombat(attackerArmyID: armyID, buildingID: building.id, currentTime: currentTime) {
            changes.append(combatChange)
        }
    }

    // MARK: - Building Combat Processing

    private func processBuildingCombats(currentTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []
        var completedCombats: [UUID] = []

        for (combatID, var combat) in buildingCombats {
            guard !combat.isComplete else {
                completedCombats.append(combatID)
                continue
            }

            // Check if it's time for the next phase
            if currentTime - combat.lastPhaseTime >= buildingPhaseInterval {
                if let buildingID = combat.defenderBuildingID {
                    let phaseChanges = processArmyVsBuildingPhase(&combat, buildingID: buildingID, state: state)
                    changes.append(contentsOf: phaseChanges)
                }

                combat.currentPhase += 1
                combat.lastPhaseTime = currentTime
                buildingCombats[combatID] = combat

                if combat.isComplete {
                    completedCombats.append(combatID)

                    // Emit combatEnded with building damage result
                    if let result = combat.result, let buildingID = combat.defenderBuildingID {
                        changes.append(.combatEnded(
                            attackerID: combat.attackerArmyID,
                            defenderID: buildingID,
                            result: result
                        ))

                        // Notify UI of building combat end
                        let combatInfo: [String: Any] = [
                            "attackerArmyID": combat.attackerArmyID,
                            "buildingID": buildingID,
                            "result": result
                        ]
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: .buildingCombatEnded,
                                object: nil,
                                userInfo: combatInfo
                            )
                        }
                    }
                }
            }
        }

        // Remove completed combats
        for combatID in completedCombats {
            buildingCombats.removeValue(forKey: combatID)
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

        // Calculate siege damage
        let attackerStats = attacker.getAggregatedCombatStats()
        var damage = attackerStats.totalDamage

        // Siege bonus vs buildings
        let siegeCount = attacker.getUnitCountByCategory(.siege)
        if siegeCount > 0 {
            damage += attackerStats.bonusVsBuildings
            damage *= 1.5  // 50% bonus for having siege units
        }

        // Track damage for reporting
        combat.totalBuildingDamage += damage

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

            // Create building damage record
            let buildingDamageRecord = BuildingDamageRecord(
                buildingID: buildingID,
                buildingType: combat.buildingType ?? building.buildingType.displayName,
                damageDealt: combat.totalBuildingDamage,
                healthBefore: combat.buildingHealthBefore,
                healthAfter: 0,
                wasDestroyed: true
            )

            // Set combat result with building damage info
            combat.result = CombatResultData(
                winnerID: combat.attackerArmyID,
                loserID: nil,
                attackerCasualties: [:],
                defenderCasualties: [:],
                combatDuration: 0,
                buildingDamage: buildingDamageRecord
            )

            changes.append(.buildingDestroyed(
                buildingID: buildingID,
                coordinate: building.coordinate
            ))

            // Clean up attacker's combat flags
            attacker.isInCombat = false
            attacker.combatTargetID = nil

            // Initiate retreat for any defending armies that were stationed at this building
            initiateRetreatForDefendersAtBuilding(building, state: state)

            // Remove building from game state
            state.removeBuilding(id: buildingID)
        }

        return changes
    }

    /// Initiates retreat for armies that were defending a building when it was destroyed
    private func initiateRetreatForDefendersAtBuilding(_ building: BuildingData, state: GameState) {
        guard let buildingOwnerID = building.ownerID else { return }

        // Find armies at any of the building's occupied coordinates
        // Include empty armies (commanders with 0 units) so they retreat when their home is destroyed
        let buildingCoords = building.occupiedCoordinates
        let defendingArmies = state.armies.values.filter { army in
            army.ownerID == buildingOwnerID &&
            buildingCoords.contains(army.coordinate)
        }

        guard !defendingArmies.isEmpty else { return }

        // Find a new home base for retreat (excluding the destroyed building's location)
        guard let newHomeBase = state.findNearestHomeBase(
            for: buildingOwnerID,
            from: building.coordinate,
            excluding: building.coordinate
        ) else {
            print("⚠️ No home base available for retreat - defenders have nowhere to go")
            return
        }

        for army in defendingArmies {
            // Update home base
            army.homeBaseID = newHomeBase.id

            // Calculate retreat path
            guard let path = state.mapData.findPath(
                from: army.coordinate,
                to: newHomeBase.coordinate,
                forPlayerID: buildingOwnerID,
                gameState: state
            ), !path.isEmpty else {
                print("🏃 \(army.name) cannot find retreat path from destroyed building")
                continue
            }

            // Set retreat state
            army.isRetreating = true
            army.currentPath = path
            army.pathIndex = 0
            army.movementProgress = 0.0

            print("🏃 \(army.name) retreating from destroyed \(building.buildingType.displayName) to \(newHomeBase.buildingType.displayName)")
        }
    }

    // MARK: - Villager Combat Processing

    private func processVillagerCombats(currentTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []
        var completedCombats: [UUID] = []

        for (combatID, var combat) in villagerCombats {
            guard !combat.isComplete else {
                completedCombats.append(combatID)
                continue
            }

            // Get attacker and defender
            guard let attacker = state.getArmy(id: combat.attackerArmyID),
                  let villagerGroup = state.getVillagerGroup(id: combat.defenderVillagerGroupID) else {
                // Combat target no longer exists
                combat.isComplete = true
                villagerCombats[combatID] = combat
                completedCombats.append(combatID)

                // Clean up attacker
                if let attacker = state.getArmy(id: combat.attackerArmyID) {
                    attacker.isInCombat = false
                    attacker.combatTargetID = nil
                }
                continue
            }

            // Calculate time delta
            let deltaTime = currentTime - combat.lastTickTime
            guard deltaTime > 0 else { continue }

            combat.lastTickTime = currentTime

            // === Army attacks villagers ===
            let attackerStats = attacker.getAggregatedCombatStats()
            let armyDamagePerSecond = attackerStats.totalDamage
            // Reduce damage by villager armor (minimum 1 damage)
            let effectiveArmyDamage = max(1.0, armyDamagePerSecond - villagerGroup.totalMeleeArmor) * deltaTime

            // Accumulate damage and convert to villager kills
            combat.accumulatedDamage += effectiveArmyDamage
            let villagersToKill = Int(combat.accumulatedDamage / VillagerGroupData.hpPerVillager)

            if villagersToKill > 0 {
                let actualKills = min(villagersToKill, villagerGroup.villagerCount)
                let removedCount = villagerGroup.removeVillagers(count: actualKills)
                combat.villagersKilled += removedCount
                combat.accumulatedDamage -= Double(villagersToKill) * VillagerGroupData.hpPerVillager

                changes.append(.villagerCasualties(
                    villagerGroupID: combat.defenderVillagerGroupID,
                    casualties: removedCount,
                    remaining: villagerGroup.villagerCount
                ))

                changes.append(.combatDamageDealt(
                    sourceID: combat.attackerArmyID,
                    targetID: combat.defenderVillagerGroupID,
                    damage: Double(removedCount) * VillagerGroupData.hpPerVillager,
                    damageType: "melee"
                ))
            }

            // === Villagers fight back (weakly) ===
            if villagerGroup.villagerCount > 0 {
                let villagerDamage = villagerGroup.totalMeleeAttack * deltaTime
                // Apply damage to army (simplified - spread across units)
                let armyCasualties = applyDamageToArmy(attacker, damage: villagerDamage)

                if !armyCasualties.isEmpty {
                    let totalDamageDealt = armyCasualties.reduce(0.0) { $0 + Double($1.value) * $1.key.hp }
                    changes.append(.combatDamageDealt(
                        sourceID: combat.defenderVillagerGroupID,
                        targetID: combat.attackerArmyID,
                        damage: totalDamageDealt,
                        damageType: "melee"
                    ))
                }

                // Check if army was destroyed
                if attacker.isEmpty() {
                    combat.isComplete = true
                    completedCombats.append(combatID)

                    print("⚔️ Army destroyed by villagers!")

                    changes.append(.armyDestroyed(
                        armyID: combat.attackerArmyID,
                        coordinate: attacker.coordinate
                    ))

                    state.removeArmy(id: combat.attackerArmyID)
                    villagerCombats[combatID] = combat
                    continue
                }
            }

            // Check if all villagers are dead
            if villagerGroup.isEmpty() {
                combat.isComplete = true
                completedCombats.append(combatID)

                print("⚔️ Villager group destroyed: \(combat.villagersKilled) villagers killed")

                changes.append(.villagerGroupDestroyed(
                    groupID: combat.defenderVillagerGroupID,
                    coordinate: combat.coordinate
                ))

                // Clean up attacker's combat flags
                attacker.isInCombat = false
                attacker.combatTargetID = nil

                // Remove villager group from game state
                state.removeVillagerGroup(id: combat.defenderVillagerGroupID)
            }

            villagerCombats[combatID] = combat
        }

        // Remove completed combats
        for combatID in completedCombats {
            villagerCombats.removeValue(forKey: combatID)
        }

        return changes
    }

    // MARK: - Garrison Defense

    private func processGarrisonDefense(currentTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []
        var armiesUnderFireThisTick: Set<UUID> = []

        // Aggregate damage per target: tracking pierce and bludgeon separately for armor calculation
        var aggregatedAttacks: [UUID: (pierceDamage: Double, bludgeonDamage: Double,
                                        buildings: [String], ownerID: UUID,
                                        location: HexCoordinate)] = [:]

        for building in state.buildings.values {
            // Must be a defensive building type (fort, castle, tower)
            guard building.canProvideGarrisonDefense else { continue }

            // Must be operational
            guard building.isOperational else { continue }

            guard let ownerID = building.ownerID else { continue }

            // GARRISON = army positioned on the building tile (not building's internal garrison)
            guard let garrisonArmy = state.getArmy(at: building.coordinate) else { continue }

            // Army must belong to the building owner
            guard garrisonArmy.ownerID == ownerID else { continue }

            // Calculate defensive unit count from army (ranged + siege only)
            let archerCount = garrisonArmy.getUnitCount(ofType: .archer)
            let crossbowCount = garrisonArmy.getUnitCount(ofType: .crossbow)
            let mangonelCount = garrisonArmy.getUnitCount(ofType: .mangonel)
            let trebuchetCount = garrisonArmy.getUnitCount(ofType: .trebuchet)
            let defensiveUnitCount = archerCount + crossbowCount + mangonelCount + trebuchetCount

            // Must have ranged/siege units to attack
            guard defensiveUnitCount > 0 else { continue }

            // Find enemies in range
            let enemies = state.getEnemyArmiesInRange(
                of: building.coordinate,
                range: building.garrisonDefenseRange,
                forPlayer: ownerID
            )
            guard !enemies.isEmpty else { continue }

            // Attack first enemy not attacking a defensive building
            guard let target = enemies.first(where: { !isArmyAttackingDefensiveBuilding($0.id) }) else {
                continue
            }

            // Calculate damage from army's ranged/siege units
            var pierceDamage: Double = 0
            var bludgeonDamage: Double = 0

            // Archers: 12 pierce damage each
            pierceDamage += Double(archerCount) * 12.0
            // Crossbows: 14 pierce damage each
            pierceDamage += Double(crossbowCount) * 14.0
            // Mangonels: 18 bludgeon damage each
            bludgeonDamage += Double(mangonelCount) * 18.0
            // Trebuchets: 25 bludgeon damage each
            bludgeonDamage += Double(trebuchetCount) * 25.0

            // Apply research bonuses
            pierceDamage *= ResearchManager.shared.getPiercingDamageMultiplier()

            if pierceDamage > 0 || bludgeonDamage > 0 {
                armiesUnderFireThisTick.insert(target.id)

                // Aggregate attacks
                if var existing = aggregatedAttacks[target.id] {
                    existing.pierceDamage += pierceDamage
                    existing.bludgeonDamage += bludgeonDamage
                    existing.buildings.append(building.buildingType.displayName)
                    aggregatedAttacks[target.id] = existing
                } else {
                    aggregatedAttacks[target.id] = (
                        pierceDamage: pierceDamage,
                        bludgeonDamage: bludgeonDamage,
                        buildings: [building.buildingType.displayName],
                        ownerID: ownerID,
                        location: building.coordinate
                    )
                }

                // Visual effect state change
                changes.append(.garrisonDefenseAttack(
                    buildingID: building.id,
                    targetArmyID: target.id,
                    damage: pierceDamage + bludgeonDamage
                ))
            }
        }

        // Apply damage with armor reduction
        for (targetArmyID, attackData) in aggregatedAttacks {
            guard let target = state.getArmy(id: targetArmyID) else { continue }

            // Get target's aggregated armor
            let targetArmor = target.getAggregatedCombatStats()

            // Apply armor reduction (damage - armor, minimum 0)
            let effectivePierceDamage = max(0, attackData.pierceDamage - targetArmor.pierceArmor)
            let effectiveBludgeonDamage = max(0, attackData.bludgeonDamage - targetArmor.bludgeonArmor)
            let totalEffectiveDamage = effectivePierceDamage + effectiveBludgeonDamage

            // Skip if all damage absorbed by armor
            guard totalEffectiveDamage > 0 else { continue }

            let targetInitialUnits = target.getTotalUnits()
            _ = applyDamageToArmy(target, damage: totalEffectiveDamage)
            let targetFinalUnits = target.getTotalUnits()
            let totalCasualties = targetInitialUnits - targetFinalUnits

            // Create report only for NEW engagements or destruction
            let isNewEngagement = !activeGarrisonEngagements.contains(targetArmyID)
            let isDestroyed = target.isEmpty()

            if isNewEngagement || isDestroyed {
                // Create combat record
                let buildingOwner = state.getPlayer(id: attackData.ownerID)
                let targetOwner = target.ownerID.flatMap { state.getPlayer(id: $0) }

                let attackerName: String
                if attackData.buildings.count == 1 {
                    attackerName = "\(attackData.buildings[0]) Garrison"
                } else {
                    let uniqueBuildings = Array(Set(attackData.buildings)).sorted()
                    attackerName = "\(uniqueBuildings.joined(separator: " & ")) Garrisons"
                }

                let attackerParticipant = CombatParticipant(
                    name: attackerName,
                    type: .building,
                    ownerName: buildingOwner?.name ?? "Unknown",
                    ownerColor: buildingOwner.flatMap { UIColor(hex: $0.colorHex) } ?? .gray,
                    commanderName: nil
                )

                let defenderParticipant = CombatParticipant(
                    name: target.name,
                    type: .army,
                    ownerName: targetOwner?.name ?? "Unknown",
                    ownerColor: targetOwner.flatMap { UIColor(hex: $0.colorHex) } ?? .gray,
                    commanderName: target.commanderID.flatMap { state.getCommander(id: $0)?.name }
                )

                let winner: CombatResult = target.isEmpty() ? .attackerVictory : .draw

                let record = CombatRecord(
                    attacker: attackerParticipant,
                    defender: defenderParticipant,
                    attackerInitialStrength: totalEffectiveDamage,
                    defenderInitialStrength: Double(targetInitialUnits),
                    attackerFinalStrength: totalEffectiveDamage,
                    defenderFinalStrength: Double(targetFinalUnits),
                    winner: winner,
                    attackerCasualties: 0,
                    defenderCasualties: totalCasualties,
                    location: attackData.location,
                    duration: 0.0
                )
                addCombatRecord(record)

                // Mark this army as engaged
                activeGarrisonEngagements.insert(targetArmyID)
            }

            // Handle destruction
            if isDestroyed {
                activeGarrisonEngagements.remove(targetArmyID)

                changes.append(.armyDestroyed(
                    armyID: target.id,
                    coordinate: target.coordinate
                ))
                state.removeArmy(id: target.id)
            }
        }

        // Clean up engagements for armies that left range
        let armiesThatLeftRange = activeGarrisonEngagements.subtracting(armiesUnderFireThisTick)
        for armyID in armiesThatLeftRange {
            activeGarrisonEngagements.remove(armyID)
        }

        return changes
    }

    /// Check if an army is actively attacking a defensive building (fort, castle, tower)
    /// If so, garrison defense should not fire - the assault is happening in close combat
    private func isArmyAttackingDefensiveBuilding(_ armyID: UUID) -> Bool {
        // Check if army is in building combat
        guard let combat = buildingCombats.values.first(where: { $0.attackerArmyID == armyID }),
              let buildingID = combat.defenderBuildingID,
              let building = gameState?.getBuilding(id: buildingID) else {
            return false
        }

        // If attacking any defensive building (fort, castle, tower), don't fire
        return building.canProvideGarrisonDefense
    }

    // MARK: - Legacy Damage Application (for garrison defense)

    private func applyDamageToArmy(_ army: ArmyData, damage: Double) -> [MilitaryUnitTypeData: Int] {
        var casualties: [MilitaryUnitTypeData: Int] = [:]
        var remainingDamage = damage

        // Distribute damage across unit types using their HP
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

    // MARK: - Combat Resolution

    private func determineCombatResult(_ combat: ActiveCombat) -> CombatResultData {
        var winnerID: UUID?
        var loserID: UUID?

        let attackerID = combat.attackerArmies.first?.armyID
        let defenderID = combat.defenderArmies.first?.armyID

        let attackerDead = combat.attackerState.totalUnits == 0
        let defenderDead = combat.defenderState.totalUnits == 0

        if attackerDead && defenderDead {
            // Draw - mutual destruction
        } else if attackerDead {
            winnerID = defenderID
            loserID = attackerID
        } else if defenderDead {
            winnerID = attackerID
            loserID = defenderID
        } else {
            // Combat ended without total destruction - compare remaining strength
            // Use enemy state for bonus damage calculation to get accurate DPS comparison
            let attackerStrength = calculateTotalDPS(combat.attackerState, enemyState: combat.defenderState)
            let defenderStrength = calculateTotalDPS(combat.defenderState, enemyState: combat.attackerState)

            if attackerStrength > defenderStrength {
                winnerID = attackerID
                loserID = defenderID
            } else {
                winnerID = defenderID
                loserID = attackerID
            }
        }

        // Calculate casualties for the result
        var attackerCasualties: [String: Int] = [:]
        var defenderCasualties: [String: Int] = [:]

        for (unitType, initialCount) in combat.attackerState.initialComposition {
            let currentCount = combat.attackerState.unitCounts[unitType] ?? 0
            let lost = initialCount - currentCount
            if lost > 0 {
                attackerCasualties[unitType.rawValue] = lost
            }
        }

        for (unitType, initialCount) in combat.defenderState.initialComposition {
            let currentCount = combat.defenderState.unitCounts[unitType] ?? 0
            let lost = initialCount - currentCount
            if lost > 0 {
                defenderCasualties[unitType.rawValue] = lost
            }
        }

        return CombatResultData(
            winnerID: winnerID,
            loserID: loserID,
            attackerCasualties: attackerCasualties,
            defenderCasualties: defenderCasualties,
            combatDuration: combat.elapsedTime
        )
    }

    private func cleanupCombatFlags(_ combat: ActiveCombat, state: GameState) {
        // Clean up attacker armies
        for armyState in combat.attackerArmies {
            if let army = state.getArmy(id: armyState.armyID) {
                army.isInCombat = false
                army.combatTargetID = nil
            }
        }

        // Clean up defender armies
        for armyState in combat.defenderArmies {
            if let army = state.getArmy(id: armyState.armyID) {
                army.isInCombat = false
                army.combatTargetID = nil
            }
        }
    }

    /// Creates a CombatRecord from an ActiveCombat for saving to history
    private func createCombatRecord(from combat: ActiveCombat, state: GameState) -> CombatRecord {
        // Get attacker info
        let attackerArmyState = combat.attackerArmies.first
        let attackerArmy = attackerArmyState.flatMap { state.getArmy(id: $0.armyID) }
        let attackerOwner = attackerArmy?.ownerID.flatMap { state.getPlayer(id: $0) }

        let attackerParticipant = CombatParticipant(
            name: attackerArmyState?.armyName ?? "Unknown Attacker",
            type: .army,
            ownerName: attackerOwner?.name ?? "Unknown",
            ownerColor: attackerOwner.flatMap { UIColor(hex: $0.colorHex) } ?? .gray,
            commanderName: attackerArmyState?.commanderName
        )

        // Get defender info
        let defenderArmyState = combat.defenderArmies.first
        let defenderArmy = defenderArmyState.flatMap { state.getArmy(id: $0.armyID) }
        let defenderOwner = defenderArmy?.ownerID.flatMap { state.getPlayer(id: $0) }

        let defenderParticipant = CombatParticipant(
            name: defenderArmyState?.armyName ?? "Unknown Defender",
            type: .army,
            ownerName: defenderOwner?.name ?? "Unknown",
            ownerColor: defenderOwner.flatMap { UIColor(hex: $0.colorHex) } ?? .gray,
            commanderName: defenderArmyState?.commanderName
        )

        // Calculate casualties
        let attackerCasualties = combat.attackerState.initialUnitCount - combat.attackerState.totalUnits
        let defenderCasualties = combat.defenderState.initialUnitCount - combat.defenderState.totalUnits

        return CombatRecord(
            attacker: attackerParticipant,
            defender: defenderParticipant,
            attackerInitialStrength: Double(combat.attackerState.initialUnitCount),
            defenderInitialStrength: Double(combat.defenderState.initialUnitCount),
            attackerFinalStrength: Double(combat.attackerState.totalUnits),
            defenderFinalStrength: Double(combat.defenderState.totalUnits),
            winner: combat.winner,
            attackerCasualties: attackerCasualties,
            defenderCasualties: defenderCasualties,
            location: combat.location,
            duration: combat.elapsedTime
        )
    }

    /// Creates a DetailedCombatRecord from an ActiveCombat for enhanced battle reports
    private func createDetailedCombatRecord(from combat: ActiveCombat, state: GameState) -> DetailedCombatRecord {
        // Get attacker info
        let attackerArmyState = combat.attackerArmies.first
        let attackerArmy = attackerArmyState.flatMap { state.getArmy(id: $0.armyID) }
        let attackerOwner = attackerArmy?.ownerID.flatMap { state.getPlayer(id: $0) }

        // Get defender info
        let defenderArmyState = combat.defenderArmies.first
        let defenderArmy = defenderArmyState.flatMap { state.getArmy(id: $0.armyID) }
        let defenderOwner = defenderArmy?.ownerID.flatMap { state.getPlayer(id: $0) }

        // Build unit breakdowns for attacker
        var attackerUnitBreakdowns: [UnitCombatBreakdown] = []
        for (unitType, initialCount) in combat.attackerState.initialComposition {
            let finalCount = combat.attackerState.unitCounts[unitType] ?? 0
            let casualties = initialCount - finalCount
            let damageDealt = combat.attackerState.damageDealtByType[unitType] ?? 0
            let damageReceived = combat.attackerState.damageReceivedByType[unitType] ?? 0

            attackerUnitBreakdowns.append(UnitCombatBreakdown(
                unitType: unitType,
                initialCount: initialCount,
                finalCount: finalCount,
                casualties: casualties,
                damageDealt: damageDealt,
                damageReceived: damageReceived
            ))
        }

        // Build unit breakdowns for defender
        var defenderUnitBreakdowns: [UnitCombatBreakdown] = []
        for (unitType, initialCount) in combat.defenderState.initialComposition {
            let finalCount = combat.defenderState.unitCounts[unitType] ?? 0
            let casualties = initialCount - finalCount
            let damageDealt = combat.defenderState.damageDealtByType[unitType] ?? 0
            let damageReceived = combat.defenderState.damageReceivedByType[unitType] ?? 0

            defenderUnitBreakdowns.append(UnitCombatBreakdown(
                unitType: unitType,
                initialCount: initialCount,
                finalCount: finalCount,
                casualties: casualties,
                damageDealt: damageDealt,
                damageReceived: damageReceived
            ))
        }

        // Build army breakdowns for multi-army support
        var attackerArmyBreakdowns: [ArmyCombatBreakdown] = []
        for (index, armyState) in combat.attackerArmies.enumerated() {
            attackerArmyBreakdowns.append(ArmyCombatBreakdown(
                armyID: armyState.armyID,
                armyName: armyState.armyName,
                ownerName: armyState.ownerName,
                commanderName: armyState.commanderName,
                joinTime: armyState.joinTime,
                wasReinforcement: index > 0,
                initialComposition: armyState.initialComposition,
                finalComposition: armyState.currentUnits,
                casualtiesByType: armyState.casualtiesByType,
                damageDealtByType: armyState.damageDealtByType
            ))
        }

        var defenderArmyBreakdowns: [ArmyCombatBreakdown] = []
        for (index, armyState) in combat.defenderArmies.enumerated() {
            defenderArmyBreakdowns.append(ArmyCombatBreakdown(
                armyID: armyState.armyID,
                armyName: armyState.armyName,
                ownerName: armyState.ownerName,
                commanderName: armyState.commanderName,
                joinTime: armyState.joinTime,
                wasReinforcement: index > 0,
                initialComposition: armyState.initialComposition,
                finalComposition: armyState.currentUnits,
                casualtiesByType: armyState.casualtiesByType,
                damageDealtByType: armyState.damageDealtByType
            ))
        }

        return DetailedCombatRecord(
            location: combat.location,
            totalDuration: combat.elapsedTime,
            winner: combat.winner,
            terrainType: combat.terrainType,
            terrainDefenseBonus: combat.terrainDefenseBonus,
            terrainAttackPenalty: combat.terrainAttackPenalty,
            attackerName: attackerArmyState?.armyName ?? "Unknown Attacker",
            attackerOwner: attackerOwner?.name ?? "Unknown",
            attackerCommander: attackerArmyState?.commanderName,
            attackerInitialComposition: combat.attackerState.initialComposition,
            attackerFinalComposition: combat.attackerState.unitCounts,
            defenderName: defenderArmyState?.armyName ?? "Unknown Defender",
            defenderOwner: defenderOwner?.name ?? "Unknown",
            defenderCommander: defenderArmyState?.commanderName,
            defenderInitialComposition: combat.defenderState.initialComposition,
            defenderFinalComposition: combat.defenderState.unitCounts,
            phaseRecords: combat.phaseRecords,
            attackerUnitBreakdowns: attackerUnitBreakdowns,
            defenderUnitBreakdowns: defenderUnitBreakdowns,
            attackerArmyBreakdowns: attackerArmyBreakdowns,
            defenderArmyBreakdowns: defenderArmyBreakdowns
        )
    }

    // MARK: - Query Methods

    func isInCombat(armyID: UUID) -> Bool {
        // Check army combats
        for combat in activeCombats.values {
            if combat.attackerArmies.contains(where: { $0.armyID == armyID }) ||
               combat.defenderArmies.contains(where: { $0.armyID == armyID }) {
                return true
            }
        }

        // Check building combats
        if buildingCombats.values.contains(where: { $0.attackerArmyID == armyID }) {
            return true
        }

        // Check villager combats
        return villagerCombats.values.contains { $0.attackerArmyID == armyID }
    }

    func getCombat(involving armyID: UUID) -> ActiveCombatData? {
        // Check army combats and convert to ActiveCombatData for compatibility
        for combat in activeCombats.values {
            let isAttacker = combat.attackerArmies.contains(where: { $0.armyID == armyID })
            let isDefender = combat.defenderArmies.contains(where: { $0.armyID == armyID })

            if isAttacker || isDefender {
                return ActiveCombatData(
                    id: combat.id,
                    attackerArmyID: combat.attackerArmies.first?.armyID ?? UUID(),
                    defenderArmyID: combat.defenderArmies.first?.armyID,
                    defenderBuildingID: nil,
                    coordinate: combat.location,
                    currentPhase: phaseToInt(combat.phase),
                    startTime: combat.gameStartTime,
                    lastPhaseTime: combat.gameStartTime + combat.elapsedTime,
                    isComplete: combat.phase == .ended,
                    result: nil
                )
            }
        }

        // Check building combats
        return buildingCombats.values.first { $0.attackerArmyID == armyID }
    }

    /// Get active combat data for UI display
    func getActiveCombatData() -> [ActiveCombatData] {
        var result: [ActiveCombatData] = []

        // Convert ActiveCombat to ActiveCombatData
        for combat in activeCombats.values {
            result.append(ActiveCombatData(
                id: combat.id,
                attackerArmyID: combat.attackerArmies.first?.armyID ?? UUID(),
                defenderArmyID: combat.defenderArmies.first?.armyID,
                defenderBuildingID: nil,
                coordinate: combat.location,
                currentPhase: phaseToInt(combat.phase),
                startTime: combat.gameStartTime,
                lastPhaseTime: combat.gameStartTime + combat.elapsedTime,
                isComplete: combat.phase == .ended,
                result: nil
            ))
        }

        // Add building combats
        result.append(contentsOf: buildingCombats.values)

        return result
    }

    /// Get an ActiveCombat by its ID
    func getActiveCombat(id: UUID) -> ActiveCombat? {
        return activeCombats[id]
    }

    /// Get an ActiveCombat involving a specific army ID
    func getActiveCombat(involvingArmyID armyID: UUID) -> ActiveCombat? {
        return activeCombats.values.first { combat in
            combat.attackerArmies.contains { $0.armyID == armyID } ||
            combat.defenderArmies.contains { $0.armyID == armyID }
        }
    }

    // MARK: - Combat History

    func addCombatRecord(_ record: CombatRecord) {
        combatHistory.insert(record, at: 0)  // Most recent first
    }

    func addDetailedCombatRecord(_ record: DetailedCombatRecord) {
        detailedCombatHistory.insert(record, at: 0)  // Most recent first
    }

    func getCombatHistory() -> [CombatRecord] {
        return combatHistory
    }

    func getDetailedCombatHistory() -> [DetailedCombatRecord] {
        return detailedCombatHistory
    }

    /// Get detailed record by matching basic record ID (by timestamp proximity)
    func getDetailedRecord(for basicRecord: CombatRecord) -> DetailedCombatRecord? {
        // Find matching detailed record by comparing timestamps
        return detailedCombatHistory.first { detailedRecord in
            abs(detailedRecord.timestamp.timeIntervalSince(basicRecord.timestamp)) < 1.0 &&
            detailedRecord.location == basicRecord.location
        }
    }

    func clearCombatHistory() {
        combatHistory.removeAll()
        detailedCombatHistory.removeAll()
        activeCombats.removeAll()
        buildingCombats.removeAll()
        villagerCombats.removeAll()
        activeGarrisonEngagements.removeAll()
        print("🗑️ Combat history cleared")
    }

    // MARK: - Retreat

    /// Initiates auto-retreat for a losing army after combat ends
    private func initiateAutoRetreat(for armyID: UUID, state: GameState) {
        guard let army = state.getArmy(id: armyID),
              !army.isEmpty(),
              let ownerID = army.ownerID else {
            print("DEBUG: initiateAutoRetreat - Army \(armyID) not found in GameState or is empty/has no owner")
            return // Army doesn't exist or is destroyed - nothing to retreat
        }
        print("DEBUG: initiateAutoRetreat - Processing army \(army.name) at \(army.coordinate), homeBaseID: \(String(describing: army.homeBaseID))")

        // Check if army is currently at their home base (lost a fight defending it)
        // If so, they stay to defend the building - only retreat when building is destroyed
        if let homeBaseID = army.homeBaseID,
           let homeBase = state.getBuilding(id: homeBaseID),
           homeBase.occupiedCoordinates.contains(army.coordinate) {
            print("🛡️ \(army.name) staying to defend \(homeBase.buildingType.displayName)")
            return
        }

        // Try to find a retreat destination
        var retreatDestination: HexCoordinate?
        var retreatBuilding: BuildingData?

        // 1. Try existing home base
        if let homeBaseID = army.homeBaseID,
           let homeBase = state.getBuilding(id: homeBaseID),
           homeBase.isOperational,
           army.coordinate != homeBase.coordinate {
            retreatBuilding = homeBase
            retreatDestination = homeBase.coordinate
        }

        // 2. Fallback: Find nearest valid home base
        if retreatDestination == nil,
           let nearestBase = state.findNearestHomeBase(for: ownerID, from: army.coordinate),
           army.coordinate != nearestBase.coordinate {
            retreatBuilding = nearestBase
            retreatDestination = nearestBase.coordinate
            // Update army's home base reference
            army.homeBaseID = nearestBase.id
            print("🏠 \(army.name) home base reassigned to \(nearestBase.buildingType.displayName)")
        }

        // 3. Calculate path to destination
        guard let destination = retreatDestination,
              let path = state.mapData.findPath(
                  from: army.coordinate,
                  to: destination,
                  forPlayerID: ownerID,
                  gameState: state
              ), !path.isEmpty else {
            print("🏃 \(army.name) cannot find retreat path - staying in place")
            return
        }

        // Set retreat state and path
        army.isRetreating = true
        army.currentPath = path
        army.pathIndex = 0
        army.movementProgress = 0.0

        let buildingName = retreatBuilding?.buildingType.displayName ?? "unknown"
        print("🏃 \(army.name) retreating to \(buildingName)")
    }

    func retreatFromCombat(armyID: UUID) {
        // Find and remove the combat involving this army
        if let combatID = activeCombats.first(where: {
            $0.value.attackerArmies.contains(where: { $0.armyID == armyID }) ||
            $0.value.defenderArmies.contains(where: { $0.armyID == armyID })
        })?.key {
            activeCombats.removeValue(forKey: combatID)
        }

        // Check building combats too
        if let combatID = buildingCombats.first(where: { $0.value.attackerArmyID == armyID })?.key {
            buildingCombats.removeValue(forKey: combatID)
        }

        // Check villager combats too
        if let combatID = villagerCombats.first(where: { $0.value.attackerArmyID == armyID })?.key {
            villagerCombats.removeValue(forKey: combatID)
        }

        // Mark army as retreating
        if let army = gameState?.getArmy(id: armyID) {
            army.isRetreating = true
            army.isInCombat = false
            army.combatTargetID = nil
        }
    }
}
