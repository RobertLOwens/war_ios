// ============================================================================
// FILE: Grow2 Shared/Models/DefensiveStack.swift
// PURPOSE: Tiered defensive stack model for multi-army stack combat
// ============================================================================

import Foundation

// MARK: - Defensive Tier

/// The tier of a defender in a defensive stack
enum DefensiveTier: Int, Comparable {
    case entrenched = 1   // Front line: entrenched armies (on-tile + cross-tile)
    case regular = 2      // Middle: non-entrenched armies on tile
    case villager = 3     // Back: villagers (only exposed after all armies dead)

    static func < (lhs: DefensiveTier, rhs: DefensiveTier) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .entrenched: return "Entrenched"
        case .regular: return "Regular"
        case .villager: return "Villagers"
        }
    }
}

// MARK: - Defensive Stack Entry

/// A single entry in the defensive stack
struct DefensiveStackEntry {
    let armyID: UUID
    let tier: DefensiveTier
    let isCrossTile: Bool          // True if defending from an adjacent entrenched tile
    let sourceCoordinate: HexCoordinate  // Where this army actually is
    let entrenchmentBonus: Double  // Defense bonus from entrenchment (0 if not entrenched)
}

// MARK: - Defensive Stack

/// Ordered collection of defenders at a tile, built when combat is initiated
struct DefensiveStack {
    /// All defender entries sorted by tier then LIFO within tier
    let entries: [DefensiveStackEntry]

    /// Villager group IDs at this coordinate (Tier 3)
    let villagerGroupIDs: [UUID]

    /// The coordinate being defended
    let coordinate: HexCoordinate

    /// Whether this tile has any entrenched defenders
    var hasEntrenchedDefenders: Bool {
        return entries.contains { $0.tier == .entrenched }
    }

    /// All army entries (excludes villagers)
    var armyEntries: [DefensiveStackEntry] {
        return entries.filter { $0.tier != .villager }
    }

    /// Entries for a specific tier
    func entries(for tier: DefensiveTier) -> [DefensiveStackEntry] {
        return entries.filter { $0.tier == tier }
    }

    /// Cross-tile defender IDs (for death-save logic)
    var crossTileDefenderIDs: Set<UUID> {
        return Set(entries.filter { $0.isCrossTile }.map { $0.armyID })
    }

    /// Whether the stack has any defenders (armies or villagers)
    var isEmpty: Bool {
        return entries.isEmpty && villagerGroupIDs.isEmpty
    }

    /// Whether the stack only has villagers (no army defenders)
    var onlyVillagers: Bool {
        return armyEntries.isEmpty && !villagerGroupIDs.isEmpty
    }

    // MARK: - Builder

    /// Builds a defensive stack at the given coordinate
    /// - Parameters:
    ///   - coordinate: The tile being attacked
    ///   - state: Current game state
    ///   - attackerOwnerID: Owner of the attacking army (to filter out friendly units)
    /// - Returns: A DefensiveStack with tiered defenders
    static func build(at coordinate: HexCoordinate, state: GameState, attackerOwnerID: UUID) -> DefensiveStack {
        var entries: [DefensiveStackEntry] = []

        // --- Tier 1: Entrenched armies ---

        // On-tile entrenched armies
        let armiesOnTile = state.getArmies(at: coordinate)
        let entrenchedOnTile = armiesOnTile.filter { army in
            army.isEntrenched && army.ownerID != attackerOwnerID
        }
        for army in entrenchedOnTile {
            entries.append(DefensiveStackEntry(
                armyID: army.id,
                tier: .entrenched,
                isCrossTile: false,
                sourceCoordinate: coordinate,
                entrenchmentBonus: GameConfig.Entrenchment.defenseBonus
            ))
        }

        // Cross-tile entrenched armies (adjacent tiles with entrenched armies covering this tile)
        let crossTileEntrenched = state.getEntrenchedArmiesCovering(coordinate: coordinate)
            .filter { army in
                army.ownerID != attackerOwnerID &&
                !entrenchedOnTile.contains(where: { $0.id == army.id })
            }
        for army in crossTileEntrenched {
            entries.append(DefensiveStackEntry(
                armyID: army.id,
                tier: .entrenched,
                isCrossTile: true,
                sourceCoordinate: army.coordinate,
                entrenchmentBonus: GameConfig.Entrenchment.defenseBonus
            ))
        }

        // Sort Tier 1 LIFO by entrenchmentStartTime (most recent first = frontline)
        let tier1Start = 0
        let tier1End = entries.count
        if tier1End > tier1Start {
            let tier1 = entries[tier1Start..<tier1End].sorted { a, b in
                guard let aArmy = state.getArmy(id: a.armyID),
                      let bArmy = state.getArmy(id: b.armyID) else { return false }
                let aTime = aArmy.entrenchmentStartTime ?? 0
                let bTime = bArmy.entrenchmentStartTime ?? 0
                return aTime > bTime  // Most recent first
            }
            for (i, entry) in tier1.enumerated() {
                entries[tier1Start + i] = entry
            }
        }

        // --- Tier 2: Non-entrenched armies on tile ---
        let nonEntrenchedOnTile = armiesOnTile.filter { army in
            !army.isEntrenched && army.ownerID != attackerOwnerID && !army.isInCombat
        }
        // Sort LIFO by arrival time (most recent first)
        let sortedNonEntrenched = nonEntrenchedOnTile.sorted { $0.arrivalTime > $1.arrivalTime }
        for army in sortedNonEntrenched {
            entries.append(DefensiveStackEntry(
                armyID: army.id,
                tier: .regular,
                isCrossTile: false,
                sourceCoordinate: coordinate,
                entrenchmentBonus: 0
            ))
        }

        // --- Tier 3: Villager groups on tile ---
        let villagerGroups = state.getVillagerGroups(at: coordinate)
            .filter { $0.ownerID != attackerOwnerID }
        let villagerGroupIDs = villagerGroups.map { $0.id }

        return DefensiveStack(
            entries: entries,
            villagerGroupIDs: villagerGroupIDs,
            coordinate: coordinate
        )
    }
}
