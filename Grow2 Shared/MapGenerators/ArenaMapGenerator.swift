// ============================================================================
// FILE: ArenaMapGenerator.swift
// ============================================================================

import Foundation

/// Arena map generator for combat testing
/// Creates a minimal 5x5 hex grid with no resources - just combat testing
class ArenaMapGenerator: MapGenerator {

    // MARK: - Properties

    let width: Int = 5
    let height: Int = 5

    var seed: UInt64?

    // MARK: - Initialization

    init(seed: UInt64? = nil) {
        self.seed = seed
    }

    // MARK: - MapGenerator Protocol

    func generateTerrain() -> [HexCoordinate: (terrain: TerrainType, elevation: Int)] {
        var terrain: [HexCoordinate: (terrain: TerrainType, elevation: Int)] = [:]

        // Fill 5x5 grid with plains terrain, no elevation
        for r in 0..<height {
            for q in 0..<width {
                let coord = HexCoordinate(q: q, r: r)
                terrain[coord] = (terrain: .plains, elevation: 0)
            }
        }

        // Set hill terrain at player 2's position for testing terrain bonuses
        // Hill gives defender +15% defense bonus
        let player2Pos = HexCoordinate(q: 3, r: 2)
        terrain[player2Pos] = (terrain: .hill, elevation: 1)

        return terrain
    }

    func getStartingPositions() -> [PlayerStartPosition] {
        // Player 1 spawns on left side
        // Player 2 spawns entrenched on plains
        let player1Pos = HexCoordinate(q: 1, r: 2)
        let player2Pos = HexCoordinate(q: 3, r: 3)  // Player 2 starts entrenched on plains

        return [
            PlayerStartPosition(coordinate: player1Pos, playerIndex: 0),
            PlayerStartPosition(coordinate: player2Pos, playerIndex: 1)
        ]
    }

    func generateStartingResources(around position: HexCoordinate) -> [ResourcePlacement] {
        // No resources in arena - it's just for combat testing
        return []
    }

    func generateNeutralResources(excludingRadius: Int, aroundPositions: [HexCoordinate]) -> [ResourcePlacement] {
        // No neutral resources in arena
        return []
    }
}
