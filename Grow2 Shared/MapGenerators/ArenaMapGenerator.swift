// ============================================================================
// FILE: ArenaMapGenerator.swift
// ============================================================================

import Foundation

/// Arena map generator for combat testing
/// Creates a 7x7 hex grid with configurable enemy terrain - no resources
class ArenaMapGenerator: MapGenerator {

    // MARK: - Properties

    let width: Int = 7
    let height: Int = 7

    var seed: UInt64?
    var enemyTerrain: TerrainData

    // MARK: - Initialization

    init(seed: UInt64? = nil, enemyTerrain: TerrainData = .plains) {
        self.seed = seed
        self.enemyTerrain = enemyTerrain
    }

    // MARK: - MapGenerator Protocol

    func generateTerrain() -> [HexCoordinate: (terrain: TerrainType, elevation: Int)] {
        var terrain: [HexCoordinate: (terrain: TerrainType, elevation: Int)] = [:]

        // Fill 7x7 grid with plains terrain, no elevation
        for r in 0..<height {
            for q in 0..<width {
                let coord = HexCoordinate(q: q, r: r)
                terrain[coord] = (terrain: .plains, elevation: 0)
            }
        }

        // Set enemy position terrain based on config
        let player2Pos = HexCoordinate(q: 4, r: 3)
        let elevation = enemyTerrain == .hill ? 1 : (enemyTerrain == .mountain ? 2 : 0)
        terrain[player2Pos] = (terrain: enemyTerrain, elevation: elevation)

        return terrain
    }

    func getStartingPositions() -> [PlayerStartPosition] {
        // Player 1 spawns left-center, Player 2 spawns right-center
        let player1Pos = HexCoordinate(q: 2, r: 3)
        let player2Pos = HexCoordinate(q: 4, r: 3)

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
