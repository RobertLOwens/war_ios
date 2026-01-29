import Foundation
import SpriteKit
import UIKit

/// Delegate protocol for combat system events
protocol CombatSystemDelegate: AnyObject {
    func combatSystem(_ system: CombatSystem, didStartPhasedCombat combat: ActiveCombat)
    func combatSystem(_ system: CombatSystem, didUpdateCombat combat: ActiveCombat)
    func combatSystem(_ system: CombatSystem, didEndCombat combat: ActiveCombat, result: CombatResult)
}

/// Default implementations for optional delegate methods
extension CombatSystemDelegate {
    func combatSystem(_ system: CombatSystem, didStartPhasedCombat combat: ActiveCombat) {}
    func combatSystem(_ system: CombatSystem, didUpdateCombat combat: ActiveCombat) {}
    func combatSystem(_ system: CombatSystem, didEndCombat combat: ActiveCombat, result: CombatResult) {}
}

class CombatSystem {

    static let shared = CombatSystem()
    private(set) var combatHistory: [CombatRecord] = []

    /// Detailed combat records with phase-by-phase breakdown
    private(set) var detailedCombatHistory: [DetailedCombatRecord] = []

    // MARK: - Phased Combat System

    /// Active phased combats in progress
    private(set) var activeCombats: [ActiveCombat] = []

    /// Delegate for combat events
    weak var delegate: CombatSystemDelegate?

    // MARK: - New Damage Type System

    /// Calculates damage using the type-specific damage/armor system
    func calculateDamageByType(
        attackerStats: UnitCombatStats,
        defenderStats: UnitCombatStats,
        defenderCategory: UnitCategory?,
        isBuilding: Bool = false
    ) -> Double {
        var totalDamage: Double = 0

        // Each damage type vs corresponding armor
        if attackerStats.meleeDamage > 0 {
            totalDamage += max(1, attackerStats.meleeDamage - defenderStats.meleeArmor)
        }
        if attackerStats.pierceDamage > 0 {
            totalDamage += max(1, attackerStats.pierceDamage - defenderStats.pierceArmor)
        }
        if attackerStats.bludgeonDamage > 0 {
            totalDamage += max(1, attackerStats.bludgeonDamage - defenderStats.bludgeonArmor)
        }

        // Bonus vs cavalry (pikeman special)
        if defenderCategory == .cavalry {
            totalDamage += attackerStats.bonusVsCavalry
        }

        // Bonus vs buildings (siege weapons)
        if isBuilding {
            totalDamage += attackerStats.bonusVsBuildings
        }

        return max(1, totalDamage)
    }

    /// Aggregates combat stats for an army
    func getArmyCombatStats(army: Army) -> UnitCombatStats {
        var allStats: [UnitCombatStats] = []

        for (unitType, count) in army.militaryComposition {
            for _ in 0..<count {
                allStats.append(unitType.combatStats)
            }
        }

        return UnitCombatStats.aggregate(allStats)
    }

    /// Gets the primary unit category of an army (based on majority)
    func getArmyPrimaryCategory(army: Army) -> UnitCategory? {
        var categoryCounts: [UnitCategory: Int] = [:]

        for (unitType, count) in army.militaryComposition {
            categoryCounts[unitType.category, default: 0] += count
        }

        return categoryCounts.max(by: { $0.value < $1.value })?.key
    }

    // Combat calculation using new damage type system
    func calculateCombat(
        attacker: Army,
        defender: Any, // Can be Army, BuildingNode, or VillagerGroup
        defenderCoordinate: HexCoordinate
    ) -> CombatRecord {

        // Get attacker stats using new system
        let attackerCombatStats = getArmyCombatStats(army: attacker)
        let attackerCategory = getArmyPrimaryCategory(army: attacker)

        var defenderCombatStats = UnitCombatStats()
        var defenderCategory: UnitCategory? = nil
        var defenderName = ""
        var defenderType: CombatParticipantType = .army
        var defenderOwner: Player? = nil
        var isBuilding = false

        // Determine defender type and stats
        if let defenderArmy = defender as? Army {
            defenderCombatStats = getArmyCombatStats(army: defenderArmy)
            defenderCategory = getArmyPrimaryCategory(army: defenderArmy)
            defenderName = defenderArmy.name
            defenderType = .army
            defenderOwner = defenderArmy.owner

        } else if let building = defender as? BuildingNode {
            // Buildings have high bludgeon armor but low melee/pierce
            defenderCombatStats = UnitCombatStats(
                meleeDamage: building.health / 20,
                pierceDamage: 0,
                bludgeonDamage: 0,
                meleeArmor: 5,
                pierceArmor: 10,
                bludgeonArmor: 3,
                bonusVsCavalry: 0,
                bonusVsBuildings: 0
            )
            defenderName = building.buildingType.displayName
            defenderType = .building
            defenderOwner = building.owner
            isBuilding = true

        } else if let villagers = defender as? VillagerGroup {
            // Villagers are weak in combat with minimal armor
            defenderCombatStats = UnitCombatStats(
                meleeDamage: Double(villagers.villagerCount * 2),
                pierceDamage: 0,
                bludgeonDamage: 0,
                meleeArmor: 1,
                pierceArmor: 1,
                bludgeonArmor: 1,
                bonusVsCavalry: 0,
                bonusVsBuildings: 0
            )
            defenderName = villagers.name
            defenderType = .villagerGroup
            defenderOwner = villagers.owner
        }

        // Calculate damage using new type system
        let attackerDamage = calculateDamageByType(
            attackerStats: attackerCombatStats,
            defenderStats: defenderCombatStats,
            defenderCategory: defenderCategory,
            isBuilding: isBuilding
        )

        let defenderDamage = calculateDamageByType(
            attackerStats: defenderCombatStats,
            defenderStats: attackerCombatStats,
            defenderCategory: attackerCategory,
            isBuilding: false
        )

        // Apply commander bonuses
        var modifiedAttackerDamage = attackerDamage
        var modifiedDefenderDamage = defenderDamage

        if let commander = attacker.commander {
            let bonus = commander.rank.leadershipBonus
            modifiedAttackerDamage *= (1.0 + bonus)
        }

        if let defenderArmy = defender as? Army, let commander = defenderArmy.commander {
            let bonus = commander.rank.leadershipBonus
            modifiedDefenderDamage *= (1.0 + bonus)
        }

        // Calculate casualties (percentage based)
        let totalAttackerUnits = attacker.getTotalUnits()
        let attackerStrength = attacker.getModifiedStrength()
        let attackerCasualtyRate = modifiedDefenderDamage / (attackerStrength + 1)
        let attackerCasualties = Int(Double(totalAttackerUnits) * attackerCasualtyRate * 0.3) // Max 30% casualties

        var defenderCasualties = 0
        var defenderStrength = 0.0

        if let defenderArmy = defender as? Army {
            defenderStrength = defenderArmy.getModifiedStrength()
            let totalDefenderUnits = defenderArmy.getTotalUnits()
            let defenderCasualtyRate = modifiedAttackerDamage / (defenderStrength + 1)
            defenderCasualties = Int(Double(totalDefenderUnits) * defenderCasualtyRate * 0.3)
        } else if let building = defender as? BuildingNode {
            defenderStrength = building.health / 10
            // Siege bonus already applied via bonusVsBuildings
            defenderCasualties = Int(modifiedAttackerDamage * 10)
        } else if let villagers = defender as? VillagerGroup {
            defenderStrength = Double(villagers.villagerCount * 2)
            let casualtyRate = modifiedAttackerDamage / (defenderStrength + 1)
            defenderCasualties = Int(Double(villagers.villagerCount) * casualtyRate * 0.5)
        }

        // Determine winner
        let winner: CombatResult
        if modifiedAttackerDamage > modifiedDefenderDamage * 1.2 {
            winner = .attackerVictory
        } else if modifiedDefenderDamage > modifiedAttackerDamage * 1.2 {
            winner = .defenderVictory
        } else {
            winner = .draw
        }

        // Create combat record
        let attackerParticipant = CombatParticipant(
            name: attacker.name,
            type: .army,
            ownerName: attacker.owner?.name ?? "Unknown",
            ownerColor: attacker.owner?.color ?? .gray,
            commanderName: attacker.commander?.name
        )

        let defenderParticipant = CombatParticipant(
            name: defenderName,
            type: defenderType,
            ownerName: defenderOwner?.name ?? "Unknown",
            ownerColor: defenderOwner?.color ?? .gray,
            commanderName: (defender as? Army)?.commander?.name
        )

        let record = CombatRecord(
            attacker: attackerParticipant,
            defender: defenderParticipant,
            attackerInitialStrength: attackerStrength,
            defenderInitialStrength: defenderStrength,
            attackerFinalStrength: max(0, attackerStrength - modifiedDefenderDamage),
            defenderFinalStrength: max(0, defenderStrength - modifiedAttackerDamage),
            winner: winner,
            attackerCasualties: attackerCasualties,
            defenderCasualties: defenderCasualties,
            location: defenderCoordinate
        )

        combatHistory.insert(record, at: 0) // Add to beginning for recent-first

        return record
    }
    
    func applyCombatResults(
        record: CombatRecord,
        attacker: Army,
        defender: Any
    ) {
        // Apply casualties to attacker
        applyCasualties(to: attacker, casualties: record.attackerCasualties)
        
        // Apply casualties to defender
        if let defenderArmy = defender as? Army {
            applyCasualties(to: defenderArmy, casualties: record.defenderCasualties)
        } else if let building = defender as? BuildingNode {
            building.takeDamage(Double(record.defenderCasualties))
        } else if let villagers = defender as? VillagerGroup {
            villagers.removeVillagers(count: record.defenderCasualties)
        }
        
        // Award XP to commanders
        if let attackerCommander = attacker.commander {
            let xpGain = record.winner == .attackerVictory ? 50 : 25
            attackerCommander.addExperience(xpGain)
        }
        
        if let defenderArmy = defender as? Army,
           let defenderCommander = defenderArmy.commander {
            let xpGain = record.winner == .defenderVictory ? 50 : 25
            defenderCommander.addExperience(xpGain)
        }
    }
    
    private func applyCasualties(to army: Army, casualties: Int) {
        var remainingCasualties = casualties

        // Remove from new military system first
        for (unitType, count) in army.militaryComposition.sorted(by: { $0.key.displayName < $1.key.displayName }) {
            if remainingCasualties <= 0 { break }
            let toRemove = min(count, remainingCasualties)
            army.removeMilitaryUnits(unitType, count: toRemove)
            remainingCasualties -= toRemove
        }
    }

    // MARK: - Phased Combat Methods

    /// Starts a new phased combat between two armies
    func startPhasedCombat(attacker: Army, defender: Army, location: HexCoordinate, terrainType: TerrainType = .plains) -> ActiveCombat {
        let combat = ActiveCombat(attacker: attacker, defender: defender, location: location, terrainType: terrainType)

        // Set cavalry stances (could be made configurable later)
        combat.attackerState.cavalryStance = .frontline
        combat.defenderState.cavalryStance = .frontline

        // Log terrain modifier if present
        let modifier = combat.terrainModifier
        if modifier.defenderDefenseBonus != 0 || modifier.attackerAttackPenalty != 0 {
            print("🏔️ Combat on \(terrainType.displayName): \(modifier.displayDescription)")
        }

        activeCombats.append(combat)
        delegate?.combatSystem(self, didStartPhasedCombat: combat)

        return combat
    }

    /// Updates all active combats (called from game loop)
    func updateCombats(deltaTime: TimeInterval) {
        var completedCombats: [ActiveCombat] = []

        for combat in activeCombats {
            guard combat.phase != .ended else {
                completedCombats.append(combat)
                continue
            }

            // Advance time
            combat.elapsedTime += deltaTime

            // Simulate one tick of combat
            simulateCombatTick(combat)

            // Check for phase transitions
            combat.updatePhase()

            // Notify delegate of update
            delegate?.combatSystem(self, didUpdateCombat: combat)

            // Check if combat ended
            if combat.phase == .ended {
                completedCombats.append(combat)
            }
        }

        // Process completed combats
        for combat in completedCombats {
            finalizeCombat(combat)
        }
    }

    /// Simulates one tick (1 second) of combat
    private func simulateCombatTick(_ combat: ActiveCombat) {
        // Process attacker dealing damage
        processSideAttacks(
            attackerState: &combat.attackerState,
            defenderState: &combat.defenderState,
            phase: combat.phase,
            attackerCommander: combat.attackerArmy?.commander,
            combat: combat,
            isAttacker: true
        )

        // Process defender dealing damage
        processSideAttacks(
            attackerState: &combat.defenderState,
            defenderState: &combat.attackerState,
            phase: combat.phase,
            attackerCommander: combat.defenderArmy?.commander,
            combat: combat,
            isAttacker: false
        )
    }

    /// Processes all attacks from one side to the other
    private func processSideAttacks(
        attackerState: inout SideCombatState,
        defenderState: inout SideCombatState,
        phase: CombatPhase,
        attackerCommander: Commander?,
        combat: ActiveCombat,
        isAttacker: Bool
    ) {
        // Get commander bonus
        let commanderBonus = attackerCommander?.rank.leadershipBonus ?? 0.0

        // Process each unit type that can attack this phase
        for (unitType, count) in attackerState.unitCounts {
            guard count > 0 else { continue }
            guard canAttack(unitType: unitType, phase: phase, stance: attackerState.cavalryStance) else { continue }

            // Find target for this unit type
            guard let targetType = TargetPriority.findTarget(
                attackerCategory: unitType.category,
                stance: attackerState.cavalryStance,
                enemyState: defenderState
            ) else { continue }

            // Calculate damage per unit
            let damagePerUnit = calculateUnitDamage(
                attacker: unitType,
                defender: targetType,
                stance: attackerState.cavalryStance
            )

            // Total damage from all units of this type (with commander bonus and attack speed)
            let attacksPerSecond = 1.0 / unitType.attackSpeed
            var totalDamage = damagePerUnit * Double(count) * attacksPerSecond * (1.0 + commanderBonus)

            // Apply terrain modifiers
            if isAttacker {
                // Attacker dealing damage - apply attack penalty (e.g., mountain -10%)
                totalDamage *= combat.terrainModifier.attackerMultiplier
            } else {
                // Defender counter-attacking - apply defense bonus (e.g., hill +15%)
                totalDamage *= combat.terrainModifier.defenderMultiplier
            }

            // Track damage dealt for battle reports
            attackerState.trackDamageDealt(totalDamage, by: unitType)
            combat.trackPhaseDamage(byAttacker: isAttacker, amount: totalDamage)

            // Apply damage to target and track casualties
            let casualties = defenderState.applyDamage(totalDamage, to: targetType)
            if casualties > 0 {
                combat.trackPhaseCasualty(isAttacker: !isAttacker, unitType: targetType, count: casualties)
            }
        }
    }

    /// Checks if a unit type can attack in the current phase
    private func canAttack(unitType: MilitaryUnitType, phase: CombatPhase, stance: CavalryStance) -> Bool {
        switch phase {
        case .rangedExchange:
            // Only ranged and siege can attack during ranged exchange
            return unitType.category == .ranged || unitType.category == .siege

        case .meleeEngagement:
            // All units can attack except reserve cavalry
            if unitType.category == .cavalry && stance == .reserve {
                return false
            }
            return true

        case .cleanup:
            // Everyone attacks in cleanup
            return true

        case .ended:
            return false
        }
    }

    /// Calculates damage from one unit type to another (per second, per unit)
    private func calculateUnitDamage(
        attacker: MilitaryUnitType,
        defender: MilitaryUnitType,
        stance: CavalryStance
    ) -> Double {
        let attackerStats = attacker.combatStats
        let defenderStats = defender.combatStats

        var damage = calculateDamageByType(
            attackerStats: attackerStats,
            defenderStats: defenderStats,
            defenderCategory: defender.category,
            isBuilding: false
        )

        // Apply flank bonus if cavalry attacking ranged while flanking
        if attacker.category == .cavalry && defender.category == .ranged {
            damage *= stance.flankBonusVsRanged
        }

        return damage
    }

    /// Finalizes a combat and applies results to armies
    private func finalizeCombat(_ combat: ActiveCombat) {
        print("🔍 Finalizing combat...")
        print("   Attacker army ref: \(combat.attackerArmy?.name ?? "nil")")
        print("   Defender army ref: \(combat.defenderArmy?.name ?? "nil")")
        print("   Attacker state units: \(combat.attackerState.totalUnits)")
        print("   Defender state units: \(combat.defenderState.totalUnits)")

        // Remove from active combats
        activeCombats.removeAll { $0.id == combat.id }

        // Record final phase if not already recorded
        if combat.phase != .ended {
            combat.recordPhaseCompletion(combat.phase)
        }

        // Calculate total casualties for each side
        let attackerOriginal = combat.attackerState.initialComposition
        let defenderOriginal = combat.defenderState.initialComposition

        var attackerCasualties = 0
        var defenderCasualties = 0

        // Calculate attacker casualties
        for (unitType, originalCount) in attackerOriginal {
            let remaining = combat.attackerState.unitCounts[unitType] ?? 0
            attackerCasualties += max(0, originalCount - remaining)
        }

        // Calculate defender casualties
        for (unitType, originalCount) in defenderOriginal {
            let remaining = combat.defenderState.unitCounts[unitType] ?? 0
            defenderCasualties += max(0, originalCount - remaining)
        }

        print("   Total attacker casualties: \(attackerCasualties)")
        print("   Total defender casualties: \(defenderCasualties)")

        // Apply final unit counts to armies
        if let attackerArmy = combat.attackerArmy {
            print("   Before sync - attacker army units: \(attackerArmy.getTotalMilitaryUnits())")
            syncArmyToState(army: attackerArmy, state: combat.attackerState)
            print("   After sync - attacker army units: \(attackerArmy.getTotalMilitaryUnits())")
        } else {
            print("   ⚠️ Attacker army ref is nil - cannot sync casualties!")
        }
        if let defenderArmy = combat.defenderArmy {
            print("   Before sync - defender army units: \(defenderArmy.getTotalMilitaryUnits())")
            syncArmyToState(army: defenderArmy, state: combat.defenderState)
            print("   After sync - defender army units: \(defenderArmy.getTotalMilitaryUnits())")
        } else {
            print("   ⚠️ Defender army ref is nil - cannot sync casualties!")
        }

        // Award commander XP
        if let attackerCommander = combat.attackerArmy?.commander {
            let xpGain = combat.winner == .attackerVictory ? 50 : 25
            attackerCommander.addExperience(xpGain)
        }
        if let defenderCommander = combat.defenderArmy?.commander {
            let xpGain = combat.winner == .defenderVictory ? 50 : 25
            defenderCommander.addExperience(xpGain)
        }

        // Create combat record for history
        let attackerParticipant = CombatParticipant(
            name: combat.attackerArmy?.name ?? "Unknown",
            type: .army,
            ownerName: combat.attackerArmy?.owner?.name ?? "Unknown",
            ownerColor: combat.attackerArmy?.owner?.color ?? .gray,
            commanderName: combat.attackerArmy?.commander?.name
        )

        let defenderParticipant = CombatParticipant(
            name: combat.defenderArmy?.name ?? "Unknown",
            type: .army,
            ownerName: combat.defenderArmy?.owner?.name ?? "Unknown",
            ownerColor: combat.defenderArmy?.owner?.color ?? .gray,
            commanderName: combat.defenderArmy?.commander?.name
        )

        let record = CombatRecord(
            attacker: attackerParticipant,
            defender: defenderParticipant,
            attackerInitialStrength: Double(attackerOriginal.values.reduce(0, +) * 10),
            defenderInitialStrength: Double(defenderOriginal.values.reduce(0, +) * 10),
            attackerFinalStrength: Double(combat.attackerState.totalUnits * 10),
            defenderFinalStrength: Double(combat.defenderState.totalUnits * 10),
            winner: combat.winner,
            attackerCasualties: attackerCasualties,
            defenderCasualties: defenderCasualties,
            location: combat.location
        )

        combatHistory.insert(record, at: 0)

        // Create detailed combat record with phase and unit breakdowns
        let detailedRecord = createDetailedCombatRecord(from: combat)
        detailedCombatHistory.insert(detailedRecord, at: 0)

        // Notify delegate
        delegate?.combatSystem(self, didEndCombat: combat, result: combat.winner)
    }

    /// Creates a detailed combat record from an ActiveCombat
    private func createDetailedCombatRecord(from combat: ActiveCombat) -> DetailedCombatRecord {
        // Build unit breakdowns for attacker
        var attackerBreakdowns: [UnitCombatBreakdown] = []
        for (unitType, initialCount) in combat.attackerState.initialComposition {
            let finalCount = combat.attackerState.unitCounts[unitType] ?? 0
            let breakdown = UnitCombatBreakdown(
                unitType: unitType,
                initialCount: initialCount,
                finalCount: finalCount,
                casualties: initialCount - finalCount,
                damageDealt: combat.attackerState.damageDealtByType[unitType] ?? 0,
                damageReceived: combat.attackerState.damageReceivedByType[unitType] ?? 0
            )
            attackerBreakdowns.append(breakdown)
        }

        // Build unit breakdowns for defender
        var defenderBreakdowns: [UnitCombatBreakdown] = []
        for (unitType, initialCount) in combat.defenderState.initialComposition {
            let finalCount = combat.defenderState.unitCounts[unitType] ?? 0
            let breakdown = UnitCombatBreakdown(
                unitType: unitType,
                initialCount: initialCount,
                finalCount: finalCount,
                casualties: initialCount - finalCount,
                damageDealt: combat.defenderState.damageDealtByType[unitType] ?? 0,
                damageReceived: combat.defenderState.damageReceivedByType[unitType] ?? 0
            )
            defenderBreakdowns.append(breakdown)
        }

        return DetailedCombatRecord(
            location: combat.location,
            totalDuration: combat.elapsedTime,
            winner: combat.winner,
            terrainType: combat.terrainType,
            terrainDefenseBonus: combat.terrainDefenseBonus,
            terrainAttackPenalty: combat.terrainAttackPenalty,
            attackerName: combat.attackerArmy?.name ?? "Unknown",
            attackerOwner: combat.attackerArmy?.owner?.name ?? "Unknown",
            attackerCommander: combat.attackerArmy?.commander?.name,
            attackerInitialComposition: combat.attackerState.initialComposition,
            attackerFinalComposition: combat.attackerState.unitCounts,
            defenderName: combat.defenderArmy?.name ?? "Unknown",
            defenderOwner: combat.defenderArmy?.owner?.name ?? "Unknown",
            defenderCommander: combat.defenderArmy?.commander?.name,
            defenderInitialComposition: combat.defenderState.initialComposition,
            defenderFinalComposition: combat.defenderState.unitCounts,
            phaseRecords: combat.phaseRecords,
            attackerUnitBreakdowns: attackerBreakdowns,
            defenderUnitBreakdowns: defenderBreakdowns
        )
    }

    /// Gets detailed combat record by ID
    func getDetailedCombatRecord(id: UUID) -> DetailedCombatRecord? {
        return detailedCombatHistory.first { $0.id == id }
    }

    /// Gets detailed combat record at index
    func getDetailedCombatRecord(at index: Int) -> DetailedCombatRecord? {
        guard index >= 0 && index < detailedCombatHistory.count else { return nil }
        return detailedCombatHistory[index]
    }

    /// Syncs an army's composition to match the combat state
    private func syncArmyToState(army: Army, state: SideCombatState) {
        print("      🔄 syncArmyToState called for \(army.name)")

        // Get current composition
        let currentComposition = army.militaryComposition
        print("         Current composition: \(currentComposition)")
        print("         State unitCounts: \(state.unitCounts)")

        // Remove all current units
        for (unitType, count) in currentComposition {
            army.removeMilitaryUnits(unitType, count: count)
        }
        print("         After removal: \(army.militaryComposition)")

        // Add back surviving units
        for (unitType, count) in state.unitCounts {
            army.addMilitaryUnits(unitType, count: count)
        }
        print("         After adding survivors: \(army.militaryComposition)")
    }

    /// Checks if an army is currently in combat
    func isInCombat(_ army: Army) -> Bool {
        return activeCombats.contains { combat in
            combat.attackerArmy === army || combat.defenderArmy === army
        }
    }

    /// Gets the active combat for an army (if any)
    func getActiveCombat(for army: Army) -> ActiveCombat? {
        return activeCombats.first { combat in
            combat.attackerArmy === army || combat.defenderArmy === army
        }
    }

    /// Checks if there are any active combats at a location
    func hasActiveCombat(at location: HexCoordinate) -> Bool {
        return activeCombats.contains { $0.location == location }
    }

    /// Gets all active combats at a location
    func getActiveCombats(at location: HexCoordinate) -> [ActiveCombat] {
        return activeCombats.filter { $0.location == location }
    }

    /// Sets cavalry stance for an army in combat
    func setCavalryStance(for army: Army, stance: CavalryStance) {
        guard let combat = getActiveCombat(for: army) else { return }

        if combat.attackerArmy === army {
            combat.attackerState.cavalryStance = stance
        } else if combat.defenderArmy === army {
            combat.defenderState.cavalryStance = stance
        }
    }

    /// Cancels/retreats from an active combat (army retreats with remaining units)
    func retreatFromCombat(army: Army) {
        guard let combat = getActiveCombat(for: army) else { return }

        // Sync current state to army
        if combat.attackerArmy === army {
            syncArmyToState(army: army, state: combat.attackerState)
        } else if combat.defenderArmy === army {
            syncArmyToState(army: army, state: combat.defenderState)
        }

        // Mark combat as ended
        combat.phase = .ended

        // Will be cleaned up on next update
    }

    // MARK: - Reset Methods

    /// Clears all combat history (call when starting new game)
    func clearCombatHistory() {
        combatHistory.removeAll()
        detailedCombatHistory.removeAll()
        activeCombats.removeAll()
        print("🗑️ Combat history cleared")
    }
}
