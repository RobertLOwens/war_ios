// ============================================================================
// FILE: MapGenerator.swift
// ============================================================================

import Foundation

// MARK: - Resource Placement

struct ResourcePlacement {
    let coordinate: HexCoordinate
    let resourceType: ResourcePointType
}

// MARK: - Player Start Position

struct PlayerStartPosition {
    let coordinate: HexCoordinate
    let playerIndex: Int
}

// MARK: - Map Generator Protocol

protocol MapGenerator {
    /// Map dimensions
    var width: Int { get }
    var height: Int { get }

    /// Optional seed for reproducible maps
    var seed: UInt64? { get set }

    /// Generate terrain with elevation data for all tiles
    /// Returns dictionary mapping coordinates to terrain type and elevation
    func generateTerrain() -> [HexCoordinate: (terrain: TerrainType, elevation: Int)]

    /// Get starting positions for all players
    /// For Arabia, returns 2 positions on opposite corners
    func getStartingPositions() -> [PlayerStartPosition]

    /// Generate guaranteed resources around a starting position
    /// These resources spawn within a specified radius of the position
    func generateStartingResources(around position: HexCoordinate) -> [ResourcePlacement]

    /// Generate neutral resources scattered across the map
    /// Excludes areas near starting positions
    func generateNeutralResources(excludingRadius: Int, aroundPositions: [HexCoordinate]) -> [ResourcePlacement]

    /// Ensure starting areas have flat terrain (elevation 0)
    /// Returns updated terrain data with flattened starting zones
    func ensureStartingAreasFlat(terrain: inout [HexCoordinate: (terrain: TerrainType, elevation: Int)], startPositions: [HexCoordinate], radius: Int)
}

// MARK: - Default Implementations

extension MapGenerator {
    /// Default seed is nil (random generation)
    var seed: UInt64? {
        get { return nil }
        set { }
    }

    /// Default implementation to flatten starting areas
    func ensureStartingAreasFlat(terrain: inout [HexCoordinate: (terrain: TerrainType, elevation: Int)], startPositions: [HexCoordinate], radius: Int) {
        for startPos in startPositions {
            for q in -radius...radius {
                for r in -radius...radius {
                    let coord = HexCoordinate(q: startPos.q + q, r: startPos.r + r)
                    if coord.distance(to: startPos) <= radius {
                        if var tileData = terrain[coord] {
                            // Flatten elevation and ensure walkable terrain
                            tileData.elevation = 0
                            if !tileData.terrain.isWalkable {
                                tileData.terrain = .plains
                            }
                            terrain[coord] = tileData
                        }
                    }
                }
            }
        }
    }
}
