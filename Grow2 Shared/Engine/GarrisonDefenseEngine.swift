// ============================================================================
// FILE: Grow2 Shared/Engine/GarrisonDefenseEngine.swift
// PURPOSE: Handles garrison defense logic - extracted from CombatEngine
// ============================================================================

import Foundation
import UIKit

/// Processes garrison defense attacks where ranged/siege units in defensive
/// buildings fire on nearby enemy armies.
class GarrisonDefenseEngine {

    // MARK: - Garrison Damage Constants
    private let archerGarrisonDamage = GameConfig.GarrisonDefense.archerDamage
    private let crossbowGarrisonDamage = GameConfig.GarrisonDefense.crossbowDamage
    private let mangonelGarrisonDamage = GameConfig.GarrisonDefense.mangonelDamage
    private let trebuchetGarrisonDamage = GameConfig.GarrisonDefense.trebuchetDamage

    // MARK: - State
    private(set) var activeGarrisonEngagements: Set<UUID> = []

    /// Reference to building combats for checking if armies are assaulting defensive buildings
    private var buildingCombatsProvider: (() -> [UUID: ActiveCombatData])?
    private weak var gameState: GameState?

    /// Callback to record combat history
    var onCombatRecord: ((CombatRecord) -> Void)?

    // MARK: - Setup

    func setup(gameState: GameState, buildingCombatsProvider: @escaping () -> [UUID: ActiveCombatData]) {
        self.gameState = gameState
        self.buildingCombatsProvider = buildingCombatsProvider
    }

    func reset() {
        activeGarrisonEngagements.removeAll()
    }

    // MARK: - Process Garrison Defense

    func processGarrisonDefense(currentTime: TimeInterval, state: GameState) -> [StateChange] {
        var changes: [StateChange] = []
        var armiesUnderFireThisTick: Set<UUID> = []

        var aggregatedAttacks: [UUID: (pierceDamage: Double, bludgeonDamage: Double,
                                        buildings: [String], ownerID: UUID,
                                        location: HexCoordinate)] = [:]

        for building in state.buildings.values {
            guard building.canProvideGarrisonDefense else { continue }
            guard building.isOperational else { continue }
            guard let ownerID = building.ownerID else { continue }

            guard let garrisonArmy = state.getArmy(at: building.coordinate) else { continue }
            guard garrisonArmy.ownerID == ownerID else { continue }

            let archerCount = garrisonArmy.getUnitCount(ofType: .archer)
            let crossbowCount = garrisonArmy.getUnitCount(ofType: .crossbow)
            let mangonelCount = garrisonArmy.getUnitCount(ofType: .mangonel)
            let trebuchetCount = garrisonArmy.getUnitCount(ofType: .trebuchet)
            let defensiveUnitCount = archerCount + crossbowCount + mangonelCount + trebuchetCount

            guard defensiveUnitCount > 0 else { continue }

            let enemies = state.getEnemyArmiesInRange(
                of: building.coordinate,
                range: building.garrisonDefenseRange,
                forPlayer: ownerID
            )
            guard !enemies.isEmpty else { continue }

            guard let target = enemies.first(where: { !isArmyAttackingDefensiveBuilding($0.id) }) else {
                continue
            }

            var pierceDamage: Double = 0
            var bludgeonDamage: Double = 0

            pierceDamage += Double(archerCount) * archerGarrisonDamage
            pierceDamage += Double(crossbowCount) * crossbowGarrisonDamage
            bludgeonDamage += Double(mangonelCount) * mangonelGarrisonDamage
            bludgeonDamage += Double(trebuchetCount) * trebuchetGarrisonDamage

            pierceDamage *= ResearchManager.shared.getPiercingDamageMultiplier()

            if pierceDamage > 0 || bludgeonDamage > 0 {
                armiesUnderFireThisTick.insert(target.id)

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

            let targetArmor = target.getAggregatedCombatStats()

            let effectivePierceDamage = max(0, attackData.pierceDamage - targetArmor.pierceArmor)
            let effectiveBludgeonDamage = max(0, attackData.bludgeonDamage - targetArmor.bludgeonArmor)
            let totalEffectiveDamage = effectivePierceDamage + effectiveBludgeonDamage

            guard totalEffectiveDamage > 0 else { continue }

            let targetInitialUnits = target.getTotalUnits()
            _ = DamageCalculator.applyDamageToArmy(target, damage: totalEffectiveDamage)
            let targetFinalUnits = target.getTotalUnits()
            let totalCasualties = targetInitialUnits - targetFinalUnits

            let isNewEngagement = !activeGarrisonEngagements.contains(targetArmyID)
            let isDestroyed = target.isEmpty()

            if isNewEngagement || isDestroyed {
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
                onCombatRecord?(record)

                activeGarrisonEngagements.insert(targetArmyID)
            }

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

    // MARK: - Helpers

    private func isArmyAttackingDefensiveBuilding(_ armyID: UUID) -> Bool {
        guard let buildingCombats = buildingCombatsProvider?(),
              let combat = buildingCombats.values.first(where: { $0.attackerArmyID == armyID }),
              let buildingID = combat.defenderBuildingID,
              let building = gameState?.getBuilding(id: buildingID) else {
            return false
        }
        return building.canProvideGarrisonDefense
    }
}
