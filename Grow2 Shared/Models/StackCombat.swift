// ============================================================================
// FILE: Grow2 Shared/Models/StackCombat.swift
// PURPOSE: Coordinates multi-army stack combat with tiered engagement
// ============================================================================

import Foundation

// MARK: - Combat Pairing

/// A single attacker-vs-defender pairing within a stack combat
struct CombatPairing {
    let attackerArmyID: UUID
    let defenderArmyID: UUID
    let activeCombatID: UUID    // References the ActiveCombat in CombatEngine
    var isComplete: Bool = false
    var winnerArmyID: UUID?
    var loserArmyID: UUID?
}

// MARK: - Stack Combat

/// Coordinates multiple combat pairings within one stack battle.
/// Each pairing runs as a full ActiveCombat through the existing 3-phase system.
class StackCombat {
    let id: UUID
    let coordinate: HexCoordinate
    let startTime: TimeInterval
    let attackerOwnerID: UUID

    /// Active pairings (each wraps an ActiveCombat)
    var activePairings: [CombatPairing] = []

    /// Attackers waiting to engage (queue)
    var attackerQueue: [UUID] = []

    /// Defenders waiting to engage, ordered by tier priority
    var defenderQueue: [DefensiveStackEntry] = []

    /// Cross-tile defender IDs — these get forced retreat instead of destroyed on loss
    let crossTileDefenderIDs: Set<UUID>

    /// Army IDs that have been defeated in this stack combat
    var defeatedArmyIDs: Set<UUID> = []

    /// Armies that have retreated from this stack combat
    var retreatedArmyIDs: Set<UUID> = []

    /// Whether we've advanced to villager phase
    var villagerPhaseActive: Bool = false

    /// Villager group IDs at the defended tile
    let villagerGroupIDs: [UUID]

    /// The current defensive tier being fought
    var currentTier: DefensiveTier = .entrenched

    /// Whether this stack combat is fully resolved
    var isComplete: Bool = false

    /// Number of fronts each army is fighting on (for stretching penalty)
    var frontsPerArmy: [UUID: Int] = [:]

    init(id: UUID = UUID(), coordinate: HexCoordinate, startTime: TimeInterval,
         attackerOwnerID: UUID, crossTileDefenderIDs: Set<UUID>, villagerGroupIDs: [UUID]) {
        self.id = id
        self.coordinate = coordinate
        self.startTime = startTime
        self.attackerOwnerID = attackerOwnerID
        self.crossTileDefenderIDs = crossTileDefenderIDs
        self.villagerGroupIDs = villagerGroupIDs
    }

    // MARK: - Stretching Multiplier

    /// Returns the DPS multiplier for an army fighting on multiple fronts
    func stretchingMultiplier(for armyID: UUID) -> Double {
        let fronts = frontsPerArmy[armyID] ?? 1
        guard fronts > 1 else { return 1.0 }
        return max(0.1, 1.0 - GameConfig.StackCombat.stretchingPenaltyPerFront * Double(fronts - 1))
    }

    /// Increments the front count for an army
    func addFront(for armyID: UUID) {
        frontsPerArmy[armyID, default: 0] += 1
    }

    /// Decrements the front count for an army
    func removeFront(for armyID: UUID) {
        if let current = frontsPerArmy[armyID], current > 1 {
            frontsPerArmy[armyID] = current - 1
        } else {
            frontsPerArmy.removeValue(forKey: armyID)
        }
    }

    // MARK: - Queue Management

    /// Adds a new defender to the queue (e.g., reinforcement arriving mid-combat)
    func addDefender(_ entry: DefensiveStackEntry) {
        defenderQueue.append(entry)
    }

    /// Gets the next available defender from the queue
    func dequeueNextDefender() -> DefensiveStackEntry? {
        guard !defenderQueue.isEmpty else { return nil }
        return defenderQueue.removeFirst()
    }

    /// Gets the next available attacker from the queue
    func dequeueNextAttacker() -> UUID? {
        guard !attackerQueue.isEmpty else { return nil }
        return attackerQueue.removeFirst()
    }

    /// Whether all army defenders have been handled (defeated/retreated/in combat)
    var allArmyDefendersEngaged: Bool {
        return defenderQueue.isEmpty
    }

    /// Whether there are unmatched attackers waiting
    var hasWaitingAttackers: Bool {
        return !attackerQueue.isEmpty
    }

    /// Whether there are unmatched defenders waiting
    var hasWaitingDefenders: Bool {
        return !defenderQueue.isEmpty
    }

    /// Checks if a specific army is involved in this stack combat (as attacker or defender)
    func involvesArmy(_ armyID: UUID) -> Bool {
        if activePairings.contains(where: { $0.attackerArmyID == armyID || $0.defenderArmyID == armyID }) {
            return true
        }
        if attackerQueue.contains(armyID) { return true }
        if defenderQueue.contains(where: { $0.armyID == armyID }) { return true }
        return false
    }

    /// Removes an army from the combat (for individual retreat)
    func removeArmy(_ armyID: UUID) {
        attackerQueue.removeAll { $0 == armyID }
        defenderQueue.removeAll { $0.armyID == armyID }
        retreatedArmyIDs.insert(armyID)
        removeFront(for: armyID)
    }
}
