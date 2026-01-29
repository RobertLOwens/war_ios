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

    // MARK: - Charge Bonus Constants

    /// Duration of charge bonus during melee phase (first 3 seconds)
    private let chargeBonusDuration: TimeInterval = 3.0
    /// Cavalry charge bonus (+20% damage)
    private let cavalryChargeBonus: Double = 0.20
    /// Swordsman charge bonus (+10% damage)
    private let swordsmanChargeBonus: Double = 0.10

    /// Detailed combat records with phase-by-phase breakdown
    private(set) var detailedCombatHistory: [DetailedCombatRecord] = []

    // MARK: - Phased Combat System

    /// Active phased combats in progress
    private(set) var activeCombats: [ActiveCombat] = []

    /// Delegate for combat events
    weak var delegate: CombatSystemDelegate?

    // MARK: - New Damage Type System

    /// Calculates damage using the type-specific damage/armor system with research bonuses
    func calculateDamageByType(
        attackerStats: UnitCombatStats,
        defenderStats: UnitCombatStats,
        attackerCategory: UnitCategory? = nil,
        defenderCategory: UnitCategory?,
        isBuilding: Bool = false
    ) -> Double {
        let rm = ResearchManager.shared
        var totalDamage: Double = 0

        // Melee damage with research bonus
        if attackerStats.meleeDamage > 0 {
            var meleeDmg = attackerStats.meleeDamage

            // Apply attacker melee attack bonus based on category
            if attackerCategory == .infantry {
                meleeDmg *= rm.getInfantryMeleeAttackMultiplier()
            } else if attackerCategory == .cavalry {
                meleeDmg *= rm.getCavalryMeleeAttackMultiplier()
            }

            var meleeArmor = defenderStats.meleeArmor

            // Apply defender melee armor bonus based on category
            if defenderCategory == .infantry {
                meleeArmor *= rm.getInfantryMeleeArmorMultiplier()
            } else if defenderCategory == .cavalry {
                meleeArmor *= rm.getCavalryMeleeArmorMultiplier()
            } else if defenderCategory == .ranged {
                meleeArmor *= rm.getArcherMeleeArmorMultiplier()
            }

            totalDamage += max(1, meleeDmg - meleeArmor)
        }

        // Pierce damage with research bonus
        if attackerStats.pierceDamage > 0 {
            var pierceDmg = attackerStats.pierceDamage

            // Piercing damage bonus applies to ranged units
            if attackerCategory == .ranged {
                pierceDmg *= rm.getPiercingDamageMultiplier()
            }

            var pierceArmor = defenderStats.pierceArmor

            // Apply defender pierce armor bonus based on category
            if defenderCategory == .infantry {
                pierceArmor *= rm.getInfantryPierceArmorMultiplier()
            } else if defenderCategory == .cavalry {
                pierceArmor *= rm.getCavalryPierceArmorMultiplier()
            } else if defenderCategory == .ranged {
                pierceArmor *= rm.getArcherPierceArmorMultiplier()
            }

            totalDamage += max(1, pierceDmg - pierceArmor)
        }

        // Bludgeon damage with research bonus
        if attackerStats.bludgeonDamage > 0 {
            var bludgeonDmg = attackerStats.bludgeonDamage

            // Siege bludgeon damage bonus applies to siege units
            if attackerCategory == .siege {
                bludgeonDmg *= rm.getSiegeBludgeonDamageMultiplier()
            }

            var bludgeonArmor = defenderStats.bludgeonArmor

            // Building bludgeon armor bonus
            if isBuilding {
                bludgeonArmor *= rm.getBuildingBludgeonArmorMultiplier()
            }

            totalDamage += max(1, bludgeonDmg - bludgeonArmor)
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
            attackerCategory: attackerCategory,
            defenderCategory: defenderCategory,
            isBuilding: isBuilding
        )

        let defenderDamage = calculateDamageByType(
            attackerStats: defenderCombatStats,
            defenderStats: attackerCombatStats,
            attackerCategory: defenderCategory,
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

    /// Starts a new phased combat between two armies, or joins existing combat as reinforcement
    func startPhasedCombat(attacker: Army, defender: Army, location: HexCoordinate, terrainType: TerrainType = .plains) -> ActiveCombat {
        // Check if there's already a combat at this location that the attacker should join
        if let existingCombat = findCombatToJoin(army: attacker, at: location) {
            let isAttackerSide = shouldJoinAsAttacker(army: attacker, combat: existingCombat)
            joinCombat(army: attacker, combat: existingCombat, asAttacker: isAttackerSide)
            return existingCombat
        }

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

    /// Adds an army to an existing combat as a reinforcement
    func joinCombat(army: Army, combat: ActiveCombat, asAttacker: Bool) {
        combat.addReinforcement(army: army, isAttacker: asAttacker)
        delegate?.combatSystem(self, didUpdateCombat: combat)
    }

    /// Finds an existing combat at a location that the army could join
    func findCombatToJoin(army: Army, at location: HexCoordinate) -> ActiveCombat? {
        return activeCombats.first { combat in
            combat.location == location && combat.phase != .ended
        }
    }

    /// Determines which side an army should join based on owner/diplomacy
    func shouldJoinAsAttacker(army: Army, combat: ActiveCombat) -> Bool {
        guard let armyOwner = army.owner else { return true }

        // Check if army belongs to the same player as original attacker
        if let attackerOwner = combat.attackerArmy?.owner, attackerOwner === armyOwner {
            return true
        }

        // Check if army belongs to the same player as original defender
        if let defenderOwner = combat.defenderArmy?.owner, defenderOwner === armyOwner {
            return false
        }

        // Check allies on attacker side
        for armyState in combat.attackerArmies {
            if armyState.ownerName == armyOwner.name {
                return true
            }
        }

        // Check allies on defender side
        for armyState in combat.defenderArmies {
            if armyState.ownerName == armyOwner.name {
                return false
            }
        }

        // Default to attacker side if no match found
        return true
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
            attackerArmies: &combat.attackerArmies,
            defenderArmies: &combat.defenderArmies,
            phase: combat.phase,
            combat: combat,
            isAttacker: true
        )

        // Process defender dealing damage
        processSideAttacks(
            attackerState: &combat.defenderState,
            defenderState: &combat.attackerState,
            attackerArmies: &combat.defenderArmies,
            defenderArmies: &combat.attackerArmies,
            phase: combat.phase,
            combat: combat,
            isAttacker: false
        )
    }

    // MARK: - Charge Bonus Helpers

    /// Checks if combat is currently in the charge phase (first 3 seconds of melee)
    private func isInChargePhase(_ combat: ActiveCombat) -> Bool {
        guard combat.phase == .meleeEngagement else { return false }
        let timeInPhase = combat.elapsedTime - combat.phaseStartTime
        return timeInPhase <= chargeBonusDuration
    }

    /// Gets the charge bonus multiplier for a unit type (attacker only)
    private func getChargeBonus(for unitType: MilitaryUnitType) -> Double {
        switch unitType.category {
        case .cavalry:
            return cavalryChargeBonus
        case .infantry:
            return unitType == .swordsman ? swordsmanChargeBonus : 0.0
        default:
            return 0.0
        }
    }

    /// Processes all attacks from one side to the other
    private func processSideAttacks(
        attackerState: inout SideCombatState,
        defenderState: inout SideCombatState,
        attackerArmies: inout [ArmyCombatState],
        defenderArmies: inout [ArmyCombatState],
        phase: CombatPhase,
        combat: ActiveCombat,
        isAttacker: Bool
    ) {
        // Get average commander bonus from all active armies
        let commanderBonus = calculateAverageCommanderBonus(armies: attackerArmies)

        // Process each unit type that can attack this phase
        for (unitType, count) in attackerState.unitCounts {
            guard count > 0 else { continue }

            // Check if this unit type can attack in current phase
            // Also check for reinforcement ranged windows
            let canAttackNormally = canAttack(unitType: unitType, phase: phase, stance: attackerState.cavalryStance)
            let hasReinforcementRangedWindow = checkReinforcementRangedWindow(
                unitType: unitType,
                armyStates: attackerArmies,
                combatTime: combat.elapsedTime
            )

            guard canAttackNormally || hasReinforcementRangedWindow else { continue }

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

            // Apply charge bonus - now considering per-army charge windows
            let chargeMultiplier = calculateChargeBonus(
                for: unitType,
                combat: combat,
                armyStates: attackerArmies,
                isAttacker: isAttacker
            )
            if chargeMultiplier > 1.0 {
                totalDamage *= chargeMultiplier
            }

            // Apply terrain modifiers
            if isAttacker {
                // Attacker dealing damage - apply attack penalty (e.g., mountain -10%)
                totalDamage *= combat.terrainModifier.attackerMultiplier
            } else {
                // Defender counter-attacking - apply defense bonus (e.g., hill +15%)
                totalDamage *= combat.terrainModifier.defenderMultiplier
            }

            // Track damage dealt for battle reports (aggregated state)
            attackerState.trackDamageDealt(totalDamage, by: unitType)
            combat.trackPhaseDamage(byAttacker: isAttacker, amount: totalDamage)

            // Distribute damage dealt to individual army states proportionally
            distributeDamageToArmies(
                unitType: unitType,
                totalDamage: totalDamage,
                armyStates: &attackerArmies
            )

            // Apply damage to target and track casualties
            let casualties = defenderState.applyDamage(totalDamage, to: targetType)
            if casualties > 0 {
                combat.trackPhaseCasualty(isAttacker: !isAttacker, unitType: targetType, count: casualties)

                // Distribute casualties to individual army states proportionally
                distributeCasualtiesToArmies(
                    unitType: targetType,
                    totalCasualties: casualties,
                    armyStates: &defenderArmies
                )
            }
        }
    }

    /// Calculate average commander bonus from all active armies
    private func calculateAverageCommanderBonus(armies: [ArmyCombatState]) -> Double {
        var totalBonus: Double = 0.0
        var commanderCount = 0

        for armyState in armies where armyState.isActive {
            if let army = armyState.army, let commander = army.commander {
                totalBonus += commander.rank.leadershipBonus
                commanderCount += 1
            }
        }

        return commanderCount > 0 ? totalBonus / Double(commanderCount) : 0.0
    }

    /// Checks if any reinforcement army has an active ranged window for the given unit type
    private func checkReinforcementRangedWindow(
        unitType: MilitaryUnitType,
        armyStates: [ArmyCombatState],
        combatTime: TimeInterval
    ) -> Bool {
        // Only ranged units benefit from reinforcement ranged windows
        guard unitType.category == .ranged || unitType.category == .siege else { return false }

        // Check if any reinforcement (skip first army) has units of this type in their ranged window
        for armyState in armyStates.dropFirst() {
            if armyState.isInRangedWindow(combatTime: combatTime) &&
               armyState.getUnits(ofType: unitType) > 0 {
                return true
            }
        }

        return false
    }

    /// Calculates charge bonus considering per-army charge windows
    private func calculateChargeBonus(
        for unitType: MilitaryUnitType,
        combat: ActiveCombat,
        armyStates: [ArmyCombatState],
        isAttacker: Bool
    ) -> Double {
        let baseChargeBonus = getChargeBonus(for: unitType)
        guard baseChargeBonus > 0 else { return 1.0 }

        // Count units with charge bonus vs total units
        var unitsWithChargeBonus = 0
        var totalUnits = 0

        for (index, armyState) in armyStates.enumerated() {
            let armyUnits = armyState.getUnits(ofType: unitType)
            totalUnits += armyUnits

            // First army gets charge bonus during normal charge phase
            if index == 0 {
                if isAttacker && isInChargePhase(combat) {
                    unitsWithChargeBonus += armyUnits
                }
            } else {
                // Reinforcement armies get charge bonus during their window
                if armyState.isInChargeWindow(combatTime: combat.elapsedTime) {
                    unitsWithChargeBonus += armyUnits
                }
            }
        }

        guard totalUnits > 0 else { return 1.0 }

        // Calculate proportional charge bonus
        let proportionWithBonus = Double(unitsWithChargeBonus) / Double(totalUnits)
        return 1.0 + (baseChargeBonus * proportionWithBonus)
    }

    /// Distributes damage dealt proportionally among army states
    private func distributeDamageToArmies(
        unitType: MilitaryUnitType,
        totalDamage: Double,
        armyStates: inout [ArmyCombatState]
    ) {
        // Get total units of this type across all armies
        var totalUnits = 0
        for armyState in armyStates {
            totalUnits += armyState.getUnits(ofType: unitType)
        }

        guard totalUnits > 0 else { return }

        // Distribute damage proportionally
        for i in 0..<armyStates.count {
            let armyUnits = armyStates[i].getUnits(ofType: unitType)
            if armyUnits > 0 {
                let proportion = Double(armyUnits) / Double(totalUnits)
                let armyDamage = totalDamage * proportion
                armyStates[i].trackDamageDealt(armyDamage, by: unitType)
            }
        }
    }

    /// Distributes casualties proportionally among army states
    private func distributeCasualtiesToArmies(
        unitType: MilitaryUnitType,
        totalCasualties: Int,
        armyStates: inout [ArmyCombatState]
    ) {
        guard totalCasualties > 0 else { return }

        // Get total units of this type across all armies
        var totalUnits = 0
        for armyState in armyStates {
            totalUnits += armyState.getUnits(ofType: unitType)
        }

        guard totalUnits > 0 else { return }

        // Distribute casualties proportionally
        var remainingCasualties = totalCasualties

        for i in 0..<armyStates.count {
            let armyUnits = armyStates[i].getUnits(ofType: unitType)
            if armyUnits > 0 {
                let proportion = Double(armyUnits) / Double(totalUnits)
                var armyCasualties = Int((Double(totalCasualties) * proportion).rounded())

                // Don't exceed remaining casualties
                armyCasualties = min(armyCasualties, remainingCasualties)
                // Don't exceed army's units of this type
                armyCasualties = min(armyCasualties, armyUnits)

                armyStates[i].applyCasualties(unitType: unitType, count: armyCasualties)
                remainingCasualties -= armyCasualties
            }
        }

        // If there are remaining casualties due to rounding, apply to first army with units
        if remainingCasualties > 0 {
            for i in 0..<armyStates.count {
                let armyUnits = armyStates[i].getUnits(ofType: unitType)
                if armyUnits > 0 {
                    let toApply = min(remainingCasualties, armyUnits)
                    armyStates[i].applyCasualties(unitType: unitType, count: toApply)
                    remainingCasualties -= toApply
                    if remainingCasualties <= 0 { break }
                }
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
            attackerCategory: attacker.category,
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
        print("🔍 Finalizing multi-army combat...")
        print("   Attacker armies: \(combat.attackerArmies.count)")
        print("   Defender armies: \(combat.defenderArmies.count)")
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

        // Sync all attacker armies to their respective states
        for armyState in combat.attackerArmies {
            if let army = armyState.army {
                print("   Syncing attacker army: \(army.name)")
                syncArmyToArmyState(army: army, state: armyState)
            } else {
                print("   ⚠️ Attacker army ref is nil for \(armyState.armyName)")
            }
        }

        // Sync all defender armies to their respective states
        for armyState in combat.defenderArmies {
            if let army = armyState.army {
                print("   Syncing defender army: \(army.name)")
                syncArmyToArmyState(army: army, state: armyState)
            } else {
                print("   ⚠️ Defender army ref is nil for \(armyState.armyName)")
            }
        }

        // Award commander XP to all attacker army commanders
        for armyState in combat.attackerArmies {
            if let army = armyState.army, let commander = army.commander {
                let xpGain = combat.winner == .attackerVictory ? 50 : 25
                commander.addExperience(xpGain)
                print("   Awarded \(xpGain) XP to attacker commander: \(commander.name)")
            }
        }

        // Award commander XP to all defender army commanders
        for armyState in combat.defenderArmies {
            if let army = armyState.army, let commander = army.commander {
                let xpGain = combat.winner == .defenderVictory ? 50 : 25
                commander.addExperience(xpGain)
                print("   Awarded \(xpGain) XP to defender commander: \(commander.name)")
            }
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

        // Build army breakdowns for attacker
        var attackerArmyBreakdowns: [ArmyCombatBreakdown] = []
        for (index, armyState) in combat.attackerArmies.enumerated() {
            let breakdown = ArmyCombatBreakdown(
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
            )
            attackerArmyBreakdowns.append(breakdown)
        }

        // Build army breakdowns for defender
        var defenderArmyBreakdowns: [ArmyCombatBreakdown] = []
        for (index, armyState) in combat.defenderArmies.enumerated() {
            let breakdown = ArmyCombatBreakdown(
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
            )
            defenderArmyBreakdowns.append(breakdown)
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
            defenderUnitBreakdowns: defenderBreakdowns,
            attackerArmyBreakdowns: attackerArmyBreakdowns,
            defenderArmyBreakdowns: defenderArmyBreakdowns
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

    /// Syncs an army's composition to match the combat state (for single-army backward compatibility)
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

    /// Syncs an army's composition to match its ArmyCombatState (for multi-army support)
    private func syncArmyToArmyState(army: Army, state: ArmyCombatState) {
        print("      🔄 syncArmyToArmyState called for \(army.name)")

        // Get current composition
        let currentComposition = army.militaryComposition
        print("         Current composition: \(currentComposition)")
        print("         State currentUnits: \(state.currentUnits)")

        // Remove all current units
        for (unitType, count) in currentComposition {
            army.removeMilitaryUnits(unitType, count: count)
        }
        print("         After removal: \(army.militaryComposition)")

        // Add back surviving units from this army's state
        for (unitType, count) in state.currentUnits {
            army.addMilitaryUnits(unitType, count: count)
        }
        print("         After adding survivors: \(army.militaryComposition)")
    }

    /// Checks if an army is currently in combat (checks all armies in multi-army combats)
    func isInCombat(_ army: Army) -> Bool {
        return activeCombats.contains { combat in
            // Check primary references
            if combat.attackerArmy === army || combat.defenderArmy === army {
                return true
            }
            // Check all attacker armies
            if combat.attackerArmies.contains(where: { $0.armyID == army.id }) {
                return true
            }
            // Check all defender armies
            if combat.defenderArmies.contains(where: { $0.armyID == army.id }) {
                return true
            }
            return false
        }
    }

    /// Gets the active combat for an army (if any) - checks all armies in multi-army combats
    func getActiveCombat(for army: Army) -> ActiveCombat? {
        return activeCombats.first { combat in
            // Check primary references
            if combat.attackerArmy === army || combat.defenderArmy === army {
                return true
            }
            // Check all attacker armies
            if combat.attackerArmies.contains(where: { $0.armyID == army.id }) {
                return true
            }
            // Check all defender armies
            if combat.defenderArmies.contains(where: { $0.armyID == army.id }) {
                return true
            }
            return false
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

    // MARK: - Garrison Defense

    /// Result of a garrison attack against an enemy army
    struct GarrisonAttackResult {
        let buildingID: UUID
        let buildingName: String
        let targetArmyID: UUID
        let targetArmyName: String
        let pierceDamageDealt: Double
        let bludgeonDamageDealt: Double
        let totalDamageDealt: Double
        let casualtiesInflicted: [MilitaryUnitType: Int]
        let armyDestroyed: Bool
    }

    /// Processes garrison defense for a building against target armies
    /// Returns array of results for each army attacked
    func processGarrisonDefense(building: BuildingData, targetArmies: [Army]) -> [GarrisonAttackResult] {
        guard building.hasDefensiveGarrison() else { return [] }
        guard !targetArmies.isEmpty else { return [] }

        let pierceDamage = building.getGarrisonPierceDamage()
        let bludgeonDamage = building.getGarrisonBludgeonDamage()
        let totalDamage = pierceDamage + bludgeonDamage

        guard totalDamage > 0 else { return [] }

        // Split damage evenly among all targets
        let damagePerTarget = totalDamage / Double(targetArmies.count)
        let piercePerTarget = pierceDamage / Double(targetArmies.count)
        let bludgeonPerTarget = bludgeonDamage / Double(targetArmies.count)

        var results: [GarrisonAttackResult] = []

        for army in targetArmies {
            let (casualties, armyDestroyed) = applyGarrisonDamageToArmy(
                army: army,
                pierceDamage: piercePerTarget,
                bludgeonDamage: bludgeonPerTarget
            )

            let result = GarrisonAttackResult(
                buildingID: building.id,
                buildingName: building.buildingType.displayName,
                targetArmyID: army.id,
                targetArmyName: army.name,
                pierceDamageDealt: piercePerTarget,
                bludgeonDamageDealt: bludgeonPerTarget,
                totalDamageDealt: damagePerTarget,
                casualtiesInflicted: casualties,
                armyDestroyed: armyDestroyed
            )
            results.append(result)
        }

        return results
    }

    /// Applies garrison damage to an army and returns casualties inflicted
    /// Returns tuple of (casualties by unit type, whether army was destroyed)
    func applyGarrisonDamageToArmy(
        army: Army,
        pierceDamage: Double,
        bludgeonDamage: Double
    ) -> ([MilitaryUnitType: Int], Bool) {
        var casualties: [MilitaryUnitType: Int] = [:]
        var remainingPierce = pierceDamage
        var remainingBludgeon = bludgeonDamage

        // Get all unit types in the army
        let unitTypes = army.militaryComposition.keys.sorted { $0.displayName < $1.displayName }

        // Apply pierce damage - prioritize low pierce armor units
        let pierceTargets = unitTypes.sorted { $0.combatStats.pierceArmor < $1.combatStats.pierceArmor }
        for unitType in pierceTargets {
            guard remainingPierce > 0 else { break }
            guard let count = army.militaryComposition[unitType], count > 0 else { continue }

            let stats = unitType.combatStats
            let effectiveDamage = max(1, remainingPierce - stats.pierceArmor)
            let hp = unitType.hp
            let unitsKilled = min(count, Int(effectiveDamage / hp))

            if unitsKilled > 0 {
                army.removeMilitaryUnits(unitType, count: unitsKilled)
                casualties[unitType, default: 0] += unitsKilled
                remainingPierce -= Double(unitsKilled) * hp
            }
        }

        // Apply bludgeon damage - prioritize low bludgeon armor units
        let bludgeonTargets = unitTypes.sorted { $0.combatStats.bludgeonArmor < $1.combatStats.bludgeonArmor }
        for unitType in bludgeonTargets {
            guard remainingBludgeon > 0 else { break }
            guard let count = army.militaryComposition[unitType], count > 0 else { continue }

            let stats = unitType.combatStats
            let effectiveDamage = max(1, remainingBludgeon - stats.bludgeonArmor)
            let hp = unitType.hp
            let unitsKilled = min(count, Int(effectiveDamage / hp))

            if unitsKilled > 0 {
                army.removeMilitaryUnits(unitType, count: unitsKilled)
                casualties[unitType, default: 0] += unitsKilled
                remainingBludgeon -= Double(unitsKilled) * hp
            }
        }

        let armyDestroyed = army.getTotalUnits() == 0
        return (casualties, armyDestroyed)
    }

    // MARK: - Reset Methods

    /// Clears all combat history (call when starting new game)
    func clearCombatHistory() {
        combatHistory.removeAll()
        detailedCombatHistory.removeAll()
        activeCombats.removeAll()
        print("🗑️ Combat history cleared")
    }

    /// Returns the combat history for statistics
    func getCombatHistory() -> [CombatRecord] {
        return combatHistory
    }
}
