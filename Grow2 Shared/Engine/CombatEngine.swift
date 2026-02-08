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
    let initialAttackerUnitCount: Int
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

    // MARK: - Stack Combats (multi-army engagement)
    private(set) var stackCombats: [UUID: StackCombat] = [:]

    // MARK: - Garrison Defense
    let garrisonDefenseEngine = GarrisonDefenseEngine()

    // MARK: - Combat History
    private(set) var combatHistory: [CombatRecord] = []
    private(set) var detailedCombatHistory: [DetailedCombatRecord] = []

    // MARK: - Combat Constants
    private let buildingPhaseInterval = GameConfig.Combat.buildingPhaseInterval
    private let siegeBuildingBonusMultiplier = GameConfig.Combat.siegeBuildingBonusMultiplier

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
        activeCombats.removeAll()
        buildingCombats.removeAll()
        villagerCombats.removeAll()
        stackCombats.removeAll()

        garrisonDefenseEngine.setup(gameState: gameState, buildingCombatsProvider: { [weak self] in
            self?.buildingCombats ?? [:]
        })
        garrisonDefenseEngine.onCombatRecord = { [weak self] record in
            self?.addCombatRecord(record)
        }
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

        // Process stack combats (multi-army engagement)
        let stackChanges = processStackCombats(currentTime: currentTime, state: state)
        changes.append(contentsOf: stackChanges)

        // Check for garrison defense attacks
        let garrisonChanges = garrisonDefenseEngine.processGarrisonDefense(currentTime: currentTime, state: state)
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
                debugLog("⚔️ Combat phase changed: \(previousPhase.displayName) -> \(combat.phase.displayName)")
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
            NotificationCenter.default.post(name: .phasedCombatUpdated, object: combat)

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
                NotificationCenter.default.post(name: .phasedCombatEnded, object: combat)
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
            debugLog("❌ CombatEngine: gameState is nil")
            return nil
        }
        guard let attacker = state.getArmy(id: attackerArmyID) else {
            debugLog("❌ CombatEngine: Attacker army not found in GameState (ID: \(attackerArmyID))")
            return nil
        }
        guard let defender = state.getArmy(id: defenderArmyID) else {
            debugLog("❌ CombatEngine: Defender army not found in GameState (ID: \(defenderArmyID))")
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

        // Look up player states for research bonus application
        if let attackerOwnerID = attacker.ownerID {
            combat.attackerPlayerState = state.getPlayer(id: attackerOwnerID)
        }
        if let defenderOwnerID = defender.ownerID {
            combat.defenderPlayerState = state.getPlayer(id: defenderOwnerID)
        }

        // Look up commander tactics bonuses for terrain scaling
        if let attackerCommanderID = attacker.commanderID,
           let attackerCommander = state.getCommander(id: attackerCommanderID) {
            combat.attackerTacticsBonus = Double(attackerCommander.tactics) * GameConfig.Commander.tacticsTerrainScaling
        }
        if let defenderCommanderID = defender.commanderID,
           let defenderCommander = state.getCommander(id: defenderCommanderID) {
            combat.defenderTacticsBonus = Double(defenderCommander.tactics) * GameConfig.Commander.tacticsTerrainScaling
        }

        // Apply entrenchment defense bonus to defender (tracked separately)
        if defender.isEntrenched {
            combat.entrenchmentDefenseBonus = GameConfig.Entrenchment.defenseBonus
            debugLog("   🪖 Defender is entrenched: +\(Int(GameConfig.Entrenchment.defenseBonus * 100))% defense bonus")
        }

        // Store with combat's own ID
        activeCombats[combat.id] = combat

        // Mark armies as in combat
        attacker.isInCombat = true
        attacker.combatTargetID = defenderArmyID
        defender.isInCombat = true
        defender.combatTargetID = attackerArmyID

        // Debug logging for terrain bonuses
        debugLog("⚔️ Combat started: Phase \(combat.phase.displayName) at \(defender.coordinate)")
        debugLog("   📍 Terrain: \(terrain.displayName)")
        if combat.terrainDefenseBonus > 0 {
            debugLog("   🛡️ Defender defense bonus: +\(Int(combat.terrainDefenseBonus * 100))%")
        }
        if combat.terrainAttackPenalty > 0 {
            debugLog("   ⚔️ Attacker attack penalty: -\(Int(combat.terrainAttackPenalty * 100))%")
        }
        if combat.terrainDefenseBonus == 0 && combat.terrainAttackPenalty == 0 {
            debugLog("   ⚖️ No terrain modifiers")
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
            initialVillagerCount: villagerGroup.villagerCount,
            initialAttackerUnitCount: attacker.getTotalUnits()
        )

        villagerCombats[combatID] = combat

        attacker.isInCombat = true
        attacker.combatTargetID = defenderVillagerGroupID

        debugLog("⚔️ Army vs Villagers combat started: \(attacker.name) attacking \(villagerGroup.villagerCount) villagers")

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
        let attackerRangedDPS = DamageCalculator.calculateRangedDPS(combat.attackerState, enemyState: combat.defenderState, terrainPenalty: combat.terrainAttackPenalty, playerState: combat.attackerPlayerState, tacticsBonus: combat.attackerTacticsBonus)
        let defenderRangedDPS = DamageCalculator.calculateRangedDPS(combat.defenderState, enemyState: combat.attackerState, terrainBonus: combat.terrainDefenseBonus + combat.entrenchmentDefenseBonus, playerState: combat.defenderPlayerState, tacticsBonus: combat.defenderTacticsBonus)

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
        let attackerMeleeDPS = DamageCalculator.calculateMeleeDPS(combat.attackerState, enemyState: combat.defenderState, isCharge: isCharging, terrainPenalty: combat.terrainAttackPenalty, playerState: combat.attackerPlayerState, tacticsBonus: combat.attackerTacticsBonus)
        let defenderMeleeDPS = DamageCalculator.calculateMeleeDPS(combat.defenderState, enemyState: combat.attackerState, isCharge: false, terrainBonus: combat.terrainDefenseBonus + combat.entrenchmentDefenseBonus, playerState: combat.defenderPlayerState, tacticsBonus: combat.defenderTacticsBonus)

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
        let attackerTotalDPS = DamageCalculator.calculateTotalDPS(combat.attackerState, enemyState: combat.defenderState, terrainPenalty: combat.terrainAttackPenalty, playerState: combat.attackerPlayerState, tacticsBonus: combat.attackerTacticsBonus)
        let defenderTotalDPS = DamageCalculator.calculateTotalDPS(combat.defenderState, enemyState: combat.attackerState, terrainBonus: combat.terrainDefenseBonus + combat.entrenchmentDefenseBonus, playerState: combat.defenderPlayerState, tacticsBonus: combat.defenderTacticsBonus)

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

    // MARK: - Damage Application

    private func applyDamageToSide(_ sideState: inout SideCombatState, damage: Double, combat: ActiveCombat, isDefender: Bool, state: GameState) {
        DamageCalculator.applyDamageToSide(&sideState, damage: damage, combat: combat, isDefender: isDefender, state: state)
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
        debugLog("⚔️ Auto-starting building attack: \(army.name) vs \(building.buildingType.displayName)")

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
                        NotificationCenter.default.post(
                            name: .buildingCombatEnded,
                            object: nil,
                            userInfo: combatInfo
                        )
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
            damage *= siegeBuildingBonusMultiplier
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
            debugLog("⚠️ No home base available for retreat - defenders have nowhere to go")
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
                debugLog("🏃 \(army.name) cannot find retreat path from destroyed building")
                continue
            }

            // Set retreat state
            army.isRetreating = true
            army.currentPath = path
            army.pathIndex = 0
            army.movementProgress = 0.0

            debugLog("🏃 \(army.name) retreating from destroyed \(building.buildingType.displayName) to \(newHomeBase.buildingType.displayName)")
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
                let armyCasualties = DamageCalculator.applyDamageToArmy(attacker, damage: villagerDamage)

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

                    debugLog("⚔️ Army destroyed by villagers!")

                    // Save combat record before removing army
                    let record = createVillagerCombatRecord(from: combat, currentTime: currentTime, state: state)
                    addCombatRecord(record)

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

                debugLog("⚔️ Villager group destroyed: \(combat.villagersKilled) villagers killed")

                // Save combat record before removing villager group
                let record = createVillagerCombatRecord(from: combat, currentTime: currentTime, state: state)
                addCombatRecord(record)

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
            let attackerStrength = DamageCalculator.calculateTotalDPS(combat.attackerState, enemyState: combat.defenderState, playerState: combat.attackerPlayerState)
            let defenderStrength = DamageCalculator.calculateTotalDPS(combat.defenderState, enemyState: combat.attackerState, playerState: combat.defenderPlayerState)

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

    /// Creates a CombatRecord from a completed VillagerCombatData for battle history
    private func createVillagerCombatRecord(from combat: VillagerCombatData, currentTime: TimeInterval, state: GameState) -> CombatRecord {
        // Get attacker info
        let attackerArmy = state.getArmy(id: combat.attackerArmyID)
        let attackerOwner = attackerArmy?.ownerID.flatMap { state.getPlayer(id: $0) }
        let commanderName = attackerArmy?.commanderID.flatMap { state.getCommander(id: $0)?.name }

        let attackerParticipant = CombatParticipant(
            name: attackerArmy?.name ?? "Unknown Army",
            type: .army,
            ownerName: attackerOwner?.name ?? "Unknown",
            ownerColor: attackerOwner.flatMap { UIColor(hex: $0.colorHex) } ?? .gray,
            commanderName: commanderName
        )

        // Get defender info
        let defenderOwner = combat.defenderOwnerID.flatMap { state.getPlayer(id: $0) }
        let villagerGroup = state.getVillagerGroup(id: combat.defenderVillagerGroupID)

        let defenderParticipant = CombatParticipant(
            name: villagerGroup?.name ?? "Villagers",
            type: .villagerGroup,
            ownerName: defenderOwner?.name ?? "Unknown",
            ownerColor: defenderOwner.flatMap { UIColor(hex: $0.colorHex) } ?? .gray,
            commanderName: nil
        )

        // Calculate casualties
        let attackerFinalUnits = attackerArmy?.getTotalUnits() ?? 0
        let attackerCasualties = combat.initialAttackerUnitCount - attackerFinalUnits
        let defenderFinalUnits = villagerGroup?.villagerCount ?? 0

        // Determine winner
        let winner: CombatResult
        if attackerFinalUnits == 0 {
            winner = .defenderVictory
        } else if defenderFinalUnits == 0 {
            winner = .attackerVictory
        } else {
            winner = .draw
        }

        return CombatRecord(
            attacker: attackerParticipant,
            defender: defenderParticipant,
            attackerInitialStrength: Double(combat.initialAttackerUnitCount),
            defenderInitialStrength: Double(combat.initialVillagerCount),
            attackerFinalStrength: Double(attackerFinalUnits),
            defenderFinalStrength: Double(defenderFinalUnits),
            winner: winner,
            attackerCasualties: attackerCasualties,
            defenderCasualties: combat.villagersKilled,
            location: combat.coordinate,
            duration: currentTime - combat.startTime
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
            entrenchmentDefenseBonus: combat.entrenchmentDefenseBonus,
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

    // MARK: - Stack Combat Initiation

    /// Start a stack combat at the target coordinate with multiple attackers vs a defensive stack
    func startStackCombat(attackerArmyIDs: [UUID], at coordinate: HexCoordinate, currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        let attackerOwnerID = attackerArmyIDs.compactMap({ state.getArmy(id: $0)?.ownerID }).first ?? UUID()

        // Build defensive stack
        let defensiveStack = DefensiveStack.build(at: coordinate, state: state, attackerOwnerID: attackerOwnerID)

        guard !defensiveStack.isEmpty else {
            debugLog("⚔️ Stack combat: No defenders at \(coordinate)")
            return []
        }

        let stackCombat = StackCombat(
            coordinate: coordinate,
            startTime: currentTime,
            attackerOwnerID: attackerOwnerID,
            crossTileDefenderIDs: defensiveStack.crossTileDefenderIDs,
            villagerGroupIDs: defensiveStack.villagerGroupIDs
        )

        // Queue all defenders by tier order
        stackCombat.defenderQueue = defensiveStack.armyEntries

        // Create N-to-N pairings
        var remainingAttackers = attackerArmyIDs
        var changes: [StateChange] = []

        // Pair attackers with defenders
        while !remainingAttackers.isEmpty && !stackCombat.defenderQueue.isEmpty {
            let attackerID = remainingAttackers.removeFirst()
            guard let defenderEntry = stackCombat.dequeueNextDefender() else { break }

            if let combatChange = createStackPairing(
                stackCombat: stackCombat,
                attackerID: attackerID,
                defenderEntry: defenderEntry,
                currentTime: currentTime,
                state: state
            ) {
                changes.append(combatChange)
            }
        }

        // Queue unmatched attackers
        stackCombat.attackerQueue = remainingAttackers

        // Unmatched attackers join existing pairings as reinforcements
        while let nextAttacker = stackCombat.dequeueNextAttacker() {
            if let firstPairing = stackCombat.activePairings.first(where: { !$0.isComplete }),
               let combat = activeCombats[firstPairing.activeCombatID] {
                if let attackerArmy = state.getArmy(id: nextAttacker) {
                    combat.addReinforcement(armyData: attackerArmy, isAttacker: true)
                    attackerArmy.isInCombat = true
                    attackerArmy.combatTargetID = firstPairing.defenderArmyID
                    debugLog("⚔️ Stack: Attacker \(attackerArmy.name) joining as reinforcement")
                }
            }
        }

        stackCombats[stackCombat.id] = stackCombat

        let defenderArmyIDs = defensiveStack.armyEntries.map { $0.armyID }
        changes.insert(.stackCombatStarted(
            coordinate: coordinate,
            attackerArmyIDs: attackerArmyIDs,
            defenderArmyIDs: defenderArmyIDs
        ), at: 0)

        debugLog("⚔️ Stack combat started at \(coordinate): \(attackerArmyIDs.count) attackers vs \(defensiveStack.entries.count) defenders (\(defensiveStack.villagerGroupIDs.count) villager groups)")

        return changes
    }

    /// Creates a single combat pairing within a stack combat
    private func createStackPairing(stackCombat: StackCombat, attackerID: UUID, defenderEntry: DefensiveStackEntry, currentTime: TimeInterval, state: GameState) -> StateChange? {
        guard let attacker = state.getArmy(id: attackerID),
              let defender = state.getArmy(id: defenderEntry.armyID) else {
            return nil
        }

        // Get terrain at combat location
        let terrain = state.mapData.getTerrain(at: stackCombat.coordinate) ?? .plains

        // Create the ActiveCombat
        let combat = ActiveCombat(
            attackerData: attacker,
            defenderData: defender,
            location: stackCombat.coordinate,
            terrainType: terrain,
            gameStartTime: currentTime
        )

        // Set player states for research bonuses
        if let attackerOwnerID = attacker.ownerID {
            combat.attackerPlayerState = state.getPlayer(id: attackerOwnerID)
        }
        if let defenderOwnerID = defender.ownerID {
            combat.defenderPlayerState = state.getPlayer(id: defenderOwnerID)
        }

        // Commander tactics bonuses
        if let attackerCommanderID = attacker.commanderID,
           let attackerCommander = state.getCommander(id: attackerCommanderID) {
            combat.attackerTacticsBonus = Double(attackerCommander.tactics) * GameConfig.Commander.tacticsTerrainScaling
        }
        if let defenderCommanderID = defender.commanderID,
           let defenderCommander = state.getCommander(id: defenderCommanderID) {
            combat.defenderTacticsBonus = Double(defenderCommander.tactics) * GameConfig.Commander.tacticsTerrainScaling
        }

        // Apply entrenchment defense bonus
        if defenderEntry.entrenchmentBonus > 0 {
            combat.entrenchmentDefenseBonus = defenderEntry.entrenchmentBonus
        }

        // Store combat
        activeCombats[combat.id] = combat

        // Mark armies as in combat
        attacker.isInCombat = true
        attacker.combatTargetID = defenderEntry.armyID
        defender.isInCombat = true
        defender.combatTargetID = attackerID

        // Track fronts for stretching
        stackCombat.addFront(for: attackerID)
        stackCombat.addFront(for: defenderEntry.armyID)

        // Create pairing record
        let pairing = CombatPairing(
            attackerArmyID: attackerID,
            defenderArmyID: defenderEntry.armyID,
            activeCombatID: combat.id
        )
        stackCombat.activePairings.append(pairing)

        debugLog("⚔️ Stack pairing: \(attacker.name) vs \(defender.name) (Tier: \(defenderEntry.tier.displayName), Cross-tile: \(defenderEntry.isCrossTile))")

        return .combatStarted(
            attackerID: attackerID,
            defenderID: defenderEntry.armyID,
            coordinate: stackCombat.coordinate
        )
    }

    // MARK: - Stack Combat Processing

    private func processStackCombats(currentTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []
        var completedStacks: [UUID] = []

        for (stackID, stackCombat) in stackCombats {
            guard !stackCombat.isComplete else {
                completedStacks.append(stackID)
                continue
            }

            // Check each pairing for completion
            for (index, pairing) in stackCombat.activePairings.enumerated() {
                guard !pairing.isComplete else { continue }

                // Check if the underlying ActiveCombat has ended
                guard let combat = activeCombats[pairing.activeCombatID] else {
                    // Combat was already cleaned up (retreat, etc.)
                    stackCombat.activePairings[index].isComplete = true
                    continue
                }

                guard combat.phase == .ended else { continue }

                // Pairing completed
                stackCombat.activePairings[index].isComplete = true

                let result = determineCombatResult(combat)
                stackCombat.activePairings[index].winnerArmyID = result.winnerID
                stackCombat.activePairings[index].loserArmyID = result.loserID

                // Handle the loser
                if let loserID = result.loserID {
                    stackCombat.defeatedArmyIDs.insert(loserID)
                    stackCombat.removeFront(for: loserID)

                    // Cross-tile entrenched losers get forced retreat instead of destruction
                    if stackCombat.crossTileDefenderIDs.contains(loserID) {
                        if let loserArmy = state.getArmy(id: loserID), !loserArmy.isEmpty() {
                            loserArmy.clearEntrenchment()
                            let fromCoord = loserArmy.coordinate
                            initiateAutoRetreat(for: loserID, state: state)
                            let toCoord = loserArmy.currentPath?.last ?? loserArmy.coordinate
                            changes.append(.armyForcedRetreat(armyID: loserID, from: fromCoord, to: toCoord))
                            debugLog("⚔️ Stack: Cross-tile defender \(loserArmy.name) forced to retreat (not destroyed)")
                        }
                    } else {
                        // Same-tile losers are destroyed (handled by normal combat cleanup)
                        initiateAutoRetreat(for: loserID, state: state)
                    }
                }

                changes.append(.stackCombatPairingEnded(
                    coordinate: stackCombat.coordinate,
                    winnerArmyID: result.winnerID,
                    loserArmyID: result.loserID
                ))

                // Save records
                let combatRecord = createCombatRecord(from: combat, state: state)
                addCombatRecord(combatRecord)
                let detailedRecord = createDetailedCombatRecord(from: combat, state: state)
                addDetailedCombatRecord(detailedRecord)

                // Clean up combat flags
                cleanupCombatFlags(combat, state: state)

                // Chain: Winner engages next fresh enemy or reinforces an ally
                if let winnerID = result.winnerID {
                    stackCombat.removeFront(for: winnerID)

                    let winnerIsAttacker = pairing.attackerArmyID == winnerID

                    if winnerIsAttacker {
                        // Attacker won — engage next defender
                        if let nextDefender = stackCombat.dequeueNextDefender() {
                            if let combatChange = createStackPairing(
                                stackCombat: stackCombat,
                                attackerID: winnerID,
                                defenderEntry: nextDefender,
                                currentTime: currentTime,
                                state: state
                            ) {
                                changes.append(combatChange)
                                debugLog("⚔️ Stack chain: \(state.getArmy(id: winnerID)?.name ?? "Winner") engages next defender")
                            }
                        } else if let allyPairing = stackCombat.activePairings.first(where: { !$0.isComplete }),
                                  let allyCombat = activeCombats[allyPairing.activeCombatID],
                                  let winnerArmy = state.getArmy(id: winnerID) {
                            // No more defenders in queue — reinforce an ally's fight
                            allyCombat.addReinforcement(armyData: winnerArmy, isAttacker: true)
                            winnerArmy.isInCombat = true
                            debugLog("⚔️ Stack chain: \(winnerArmy.name) reinforcing ally")
                        }
                    } else {
                        // Defender won — engage next attacker
                        if let nextAttacker = stackCombat.dequeueNextAttacker() {
                            let defenderEntry = DefensiveStackEntry(
                                armyID: winnerID,
                                tier: .regular,
                                isCrossTile: stackCombat.crossTileDefenderIDs.contains(winnerID),
                                sourceCoordinate: state.getArmy(id: winnerID)?.coordinate ?? stackCombat.coordinate,
                                entrenchmentBonus: state.getArmy(id: winnerID)?.isEntrenched == true ? GameConfig.Entrenchment.defenseBonus : 0
                            )
                            if let combatChange = createStackPairing(
                                stackCombat: stackCombat,
                                attackerID: nextAttacker,
                                defenderEntry: defenderEntry,
                                currentTime: currentTime,
                                state: state
                            ) {
                                changes.append(combatChange)
                                debugLog("⚔️ Stack chain: Defender engages next attacker")
                            }
                        }
                    }
                }
            }

            // Check for tier advancement
            let activePairingsRemaining = stackCombat.activePairings.filter { !$0.isComplete }
            if activePairingsRemaining.isEmpty && stackCombat.defenderQueue.isEmpty {
                if !stackCombat.villagerPhaseActive && !stackCombat.villagerGroupIDs.isEmpty {
                    // All army defenders defeated — advance to villager phase
                    stackCombat.villagerPhaseActive = true
                    stackCombat.currentTier = .villager
                    changes.append(.stackCombatTierAdvanced(coordinate: stackCombat.coordinate, newTier: DefensiveTier.villager.rawValue))

                    // Start villager combats for remaining attackers
                    let survivingAttackers = stackCombat.activePairings
                        .compactMap { $0.winnerArmyID }
                        .filter { !stackCombat.defeatedArmyIDs.contains($0) && !stackCombat.retreatedArmyIDs.contains($0) }

                    for villagerGroupID in stackCombat.villagerGroupIDs {
                        if let attackerID = survivingAttackers.first {
                            if let villagerChange = startVillagerCombat(
                                attackerArmyID: attackerID,
                                defenderVillagerGroupID: villagerGroupID,
                                currentTime: currentTime
                            ) {
                                changes.append(villagerChange)
                            }
                        }
                    }

                    debugLog("⚔️ Stack: All army defenders defeated, advancing to villager phase")
                } else {
                    // Stack combat is complete
                    stackCombat.isComplete = true
                    completedStacks.append(stackID)

                    // Auto-attack building at location if attackers won
                    let survivingAttackers = stackCombat.activePairings
                        .compactMap { $0.winnerArmyID }
                        .filter { !stackCombat.defeatedArmyIDs.contains($0) && !stackCombat.retreatedArmyIDs.contains($0) }

                    if let firstAttacker = survivingAttackers.first {
                        autoStartBuildingCombat(for: firstAttacker, at: stackCombat.coordinate, state: state, currentTime: currentTime, changes: &changes)
                    }

                    let overallResult = CombatResultData(
                        winnerID: survivingAttackers.first,
                        loserID: nil,
                        combatDuration: currentTime - stackCombat.startTime
                    )
                    changes.append(.stackCombatEnded(coordinate: stackCombat.coordinate, result: overallResult))
                    debugLog("⚔️ Stack combat completed at \(stackCombat.coordinate)")
                }
            }
        }

        // Remove completed stacks
        for id in completedStacks {
            stackCombats.removeValue(forKey: id)
        }

        return changes
    }

    // MARK: - Stack Combat Individual Retreat

    /// Handles an army retreating from a stack combat
    func handleIndividualRetreat(armyID: UUID) {
        for (_, stackCombat) in stackCombats {
            guard stackCombat.involvesArmy(armyID) else { continue }

            // Remove from active pairing if in one
            for (index, pairing) in stackCombat.activePairings.enumerated() {
                guard !pairing.isComplete else { continue }

                if pairing.attackerArmyID == armyID || pairing.defenderArmyID == armyID {
                    // End this pairing's underlying combat
                    if let combat = activeCombats[pairing.activeCombatID] {
                        combat.phase = .ended
                    }
                    activeCombats.removeValue(forKey: pairing.activeCombatID)
                    stackCombat.activePairings[index].isComplete = true

                    // Determine who the opponent was
                    let opponentID = pairing.attackerArmyID == armyID ? pairing.defenderArmyID : pairing.attackerArmyID
                    stackCombat.activePairings[index].winnerArmyID = opponentID
                    stackCombat.activePairings[index].loserArmyID = armyID

                    stackCombat.removeFront(for: opponentID)

                    // Opponent can now engage next enemy
                    if pairing.attackerArmyID == armyID {
                        // Attacker retreated, defender won — engage next attacker
                        if let nextAttacker = stackCombat.dequeueNextAttacker(),
                           let state = gameState {
                            let defenderEntry = DefensiveStackEntry(
                                armyID: opponentID,
                                tier: .regular,
                                isCrossTile: stackCombat.crossTileDefenderIDs.contains(opponentID),
                                sourceCoordinate: state.getArmy(id: opponentID)?.coordinate ?? stackCombat.coordinate,
                                entrenchmentBonus: state.getArmy(id: opponentID)?.isEntrenched == true ? GameConfig.Entrenchment.defenseBonus : 0
                            )
                            let currentTime = state.currentTime
                            _ = createStackPairing(stackCombat: stackCombat, attackerID: nextAttacker, defenderEntry: defenderEntry, currentTime: currentTime, state: state)
                        }
                    } else {
                        // Defender retreated, attacker won — engage next defender
                        if let nextDefender = stackCombat.dequeueNextDefender(),
                           let state = gameState {
                            let currentTime = state.currentTime
                            _ = createStackPairing(stackCombat: stackCombat, attackerID: opponentID, defenderEntry: nextDefender, currentTime: currentTime, state: state)
                        }
                    }

                    break
                }
            }

            // Remove from queues
            stackCombat.removeArmy(armyID)
            break
        }
    }

    /// Get the stack combat involving a specific army
    func getStackCombat(involvingArmyID armyID: UUID) -> StackCombat? {
        return stackCombats.values.first { $0.involvesArmy(armyID) }
    }

    /// Get an active (non-complete) stack combat at a coordinate
    func getStackCombat(at coordinate: HexCoordinate) -> StackCombat? {
        return stackCombats.values.first { $0.coordinate == coordinate && !$0.isComplete }
    }

    // MARK: - Defender Reinforcement

    /// Adds a newly arrived army as a defender reinforcement to an active stack combat
    /// Returns state changes for any new pairings created
    func addDefenderToStackCombat(armyID: UUID, at coordinate: HexCoordinate, currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState,
              let army = state.getArmy(id: armyID),
              let armyOwnerID = army.ownerID else {
            return []
        }

        guard let stackCombat = getStackCombat(at: coordinate) else {
            return []
        }

        // Only join if this army is enemy of the attackers (i.e., friendly to defenders)
        guard armyOwnerID != stackCombat.attackerOwnerID else {
            return []
        }

        // Don't join if already involved
        guard !stackCombat.involvesArmy(armyID) else {
            return []
        }

        // Don't join if already in combat
        guard !army.isInCombat else {
            return []
        }

        var changes: [StateChange] = []

        let defenderEntry = DefensiveStackEntry(
            armyID: armyID,
            tier: .regular,
            isCrossTile: false,
            sourceCoordinate: coordinate,
            entrenchmentBonus: 0
        )

        // Priority 1: Match with a queued attacker
        if let nextAttacker = stackCombat.dequeueNextAttacker() {
            if let combatChange = createStackPairing(
                stackCombat: stackCombat,
                attackerID: nextAttacker,
                defenderEntry: defenderEntry,
                currentTime: currentTime,
                state: state
            ) {
                changes.append(combatChange)
                debugLog("⚔️ Stack reinforcement: \(army.name) paired with queued attacker")
            }
        }
        // Priority 2: Reinforce an outnumbered active fight
        else if let outnumberedPairing = stackCombat.activePairings.first(where: { pairing in
            guard !pairing.isComplete else { return false }
            guard let combat = activeCombats[pairing.activeCombatID] else { return false }
            return combat.attackerArmies.count > combat.defenderArmies.count
        }),
        let combat = activeCombats[outnumberedPairing.activeCombatID] {
            combat.addReinforcement(armyData: army, isAttacker: false)
            army.isInCombat = true
            army.combatTargetID = outnumberedPairing.attackerArmyID
            stackCombat.addFront(for: armyID)
            debugLog("⚔️ Stack reinforcement: \(army.name) reinforcing outnumbered defender")
        }
        // Priority 3: Queue for later chain combat pickup
        else {
            stackCombat.addDefender(defenderEntry)
            army.isInCombat = true
            debugLog("⚔️ Stack reinforcement: \(army.name) queued as reserve defender")
        }

        return changes
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
        if villagerCombats.values.contains(where: { $0.attackerArmyID == armyID }) {
            return true
        }

        // Check stack combats
        if stackCombats.values.contains(where: { $0.involvesArmy(armyID) }) {
            return true
        }

        return false
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
        stackCombats.removeAll()
        garrisonDefenseEngine.reset()
        debugLog("🗑️ Combat history cleared")
    }

    // MARK: - Retreat

    /// Initiates auto-retreat for a losing army after combat ends
    private func initiateAutoRetreat(for armyID: UUID, state: GameState) {
        guard let army = state.getArmy(id: armyID),
              !army.isEmpty(),
              let ownerID = army.ownerID else {
            debugLog("DEBUG: initiateAutoRetreat - Army \(armyID) not found in GameState or is empty/has no owner")
            return // Army doesn't exist or is destroyed - nothing to retreat
        }
        debugLog("DEBUG: initiateAutoRetreat - Processing army \(army.name) at \(army.coordinate), homeBaseID: \(String(describing: army.homeBaseID))")

        // Clear entrenchment when retreating from combat loss
        if army.isEntrenching || army.isEntrenched {
            army.clearEntrenchment()
            debugLog("🪖 Army \(army.name) entrenchment cancelled due to combat loss")
        }

        // Check if army is currently at their home base (lost a fight defending it)
        // If so, they stay to defend the building - only retreat when building is destroyed
        if let homeBaseID = army.homeBaseID,
           let homeBase = state.getBuilding(id: homeBaseID),
           homeBase.occupiedCoordinates.contains(army.coordinate) {
            debugLog("🛡️ \(army.name) staying to defend \(homeBase.buildingType.displayName)")
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
            debugLog("🏠 \(army.name) home base reassigned to \(nearestBase.buildingType.displayName)")
        }

        // 3. Calculate path to destination
        guard let destination = retreatDestination,
              let path = state.mapData.findPath(
                  from: army.coordinate,
                  to: destination,
                  forPlayerID: ownerID,
                  gameState: state
              ), !path.isEmpty else {
            debugLog("🏃 \(army.name) cannot find retreat path - staying in place")
            return
        }

        // Set retreat state and path
        army.isRetreating = true
        army.currentPath = path
        army.pathIndex = 0
        army.movementProgress = 0.0

        let buildingName = retreatBuilding?.buildingType.displayName ?? "unknown"
        debugLog("🏃 \(army.name) retreating to \(buildingName)")
    }

    func retreatFromCombat(armyID: UUID) {
        // Check if army is in a stack combat first
        if getStackCombat(involvingArmyID: armyID) != nil {
            handleIndividualRetreat(armyID: armyID)
        }

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
