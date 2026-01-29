// ============================================================================
// FILE: ArabiaMapGenerator.swift
// ============================================================================

import Foundation

/// Arabia-style map generator for 1v1 competitive play
/// Creates a 120x120 hex grid with balanced starting positions and resources
class ArabiaMapGenerator: MapGenerator {

    // MARK: - Properties

    let width: Int = 35
    let height: Int = 35

    var seed: UInt64?

    /// Padding from map edge for starting positions
    private let startPadding: Int = 8

    /// Radius around starting position that must be flat and have guaranteed resources
    private let startingResourceRadius: Int = 5

    /// Radius to keep clear of neutral resources around starting positions
    private let neutralResourceExclusionRadius: Int = 10

    /// Random number generator (can be seeded)
    private var rng: RandomNumberGenerator

    // MARK: - Configuration

    struct Config {
        /// Number of tree pocket clusters to generate
        var treePocketCount: Int = 25
        /// Size range for tree pockets (number of tiles)
        var treePocketSizeRange: ClosedRange<Int> = 3...8
        /// Number of mineral deposit clusters
        var mineralDepositCount: Int = 12
        /// Size range for mineral deposits
        var mineralDepositSizeRange: ClosedRange<Int> = 2...4
        /// Chance for a tile to be part of a hill cluster
        var hillClusterChance: Double = 0.15
        /// Maximum elevation for hills
        var maxElevation: Int = 3
    }

    var config: Config

    // MARK: - Initialization

    init(seed: UInt64? = nil, config: Config = Config()) {
        self.seed = seed
        self.config = config

        if let seed = seed {
            self.rng = SeededRandomNumberGenerator(seed: seed)
        } else {
            self.rng = SystemRandomNumberGenerator()
        }
    }

    // MARK: - MapGenerator Protocol

    func generateTerrain() -> [HexCoordinate: (terrain: TerrainType, elevation: Int)] {
        var terrain: [HexCoordinate: (terrain: TerrainType, elevation: Int)] = [:]

        // Step 1: Fill map with base plains terrain
        for r in 0..<height {
            for q in 0..<width {
                let coord = HexCoordinate(q: q, r: r)
                terrain[coord] = (terrain: .plains, elevation: 0)
            }
        }

        // Step 2: Generate hill clusters with elevation
        generateHillClusters(terrain: &terrain)

        // Step 3: Flatten starting areas
        let startPositions = getStartingPositions().map { $0.coordinate }
        ensureStartingAreasFlat(terrain: &terrain, startPositions: startPositions, radius: 5)

        return terrain
    }

    func getStartingPositions() -> [PlayerStartPosition] {
        // Place players in opposite corners with padding
        let player1Pos = HexCoordinate(q: startPadding, r: startPadding)
        let player2Pos = HexCoordinate(q: width - startPadding - 1, r: height - startPadding - 1)

        return [
            PlayerStartPosition(coordinate: player1Pos, playerIndex: 0),
            PlayerStartPosition(coordinate: player2Pos, playerIndex: 1)
        ]
    }

    func generateStartingResources(around position: HexCoordinate) -> [ResourcePlacement] {
        var placements: [ResourcePlacement] = []
        var usedCoordinates: Set<HexCoordinate> = [position] // Town center position is taken

        // Get all valid coordinates within starting radius (excluding center)
        var availableCoords: [HexCoordinate] = []
        for q in -startingResourceRadius...startingResourceRadius {
            for r in -startingResourceRadius...startingResourceRadius {
                let coord = HexCoordinate(q: position.q + q, r: position.r + r)
                if coord.distance(to: position) <= startingResourceRadius && coord != position {
                    availableCoords.append(coord)
                }
            }
        }

        // Shuffle for randomness
        availableCoords.shuffle(using: &rng)

        // Place 2 wild boars
        for _ in 0..<2 {
            if let coord = findUnusedCoordinate(from: &availableCoords, excluding: usedCoordinates) {
                placements.append(ResourcePlacement(coordinate: coord, resourceType: .wildBoar))
                usedCoordinates.insert(coord)
            }
        }

        // Place 1 deer
        if let coord = findUnusedCoordinate(from: &availableCoords, excluding: usedCoordinates) {
            placements.append(ResourcePlacement(coordinate: coord, resourceType: .deer))
            usedCoordinates.insert(coord)
        }

        // Place 4-tile ore cluster
        let oreCluster = placeResourceCluster(
            type: .oreMine,
            size: 4,
            near: position,
            radius: startingResourceRadius,
            excluding: usedCoordinates
        )
        for placement in oreCluster {
            placements.append(placement)
            usedCoordinates.insert(placement.coordinate)
        }

        // Place 3-tile stone cluster
        let stoneCluster = placeResourceCluster(
            type: .stoneQuarry,
            size: 3,
            near: position,
            radius: startingResourceRadius,
            excluding: usedCoordinates
        )
        for placement in stoneCluster {
            placements.append(placement)
            usedCoordinates.insert(placement.coordinate)
        }

        // Place 3-4 woodlines (tree clusters) within 5 tile radius
        let woodlineCount = Int.random(in: 3...4, using: &rng)
        for _ in 0..<woodlineCount {
            let woodlineSize = Int.random(in: 3...5, using: &rng)
            let woodlineCluster = placeResourceCluster(
                type: .trees,
                size: woodlineSize,
                near: position,
                radius: startingResourceRadius,
                excluding: usedCoordinates
            )
            for placement in woodlineCluster {
                placements.append(placement)
                usedCoordinates.insert(placement.coordinate)
            }
        }

        return placements
    }

    func generateNeutralResources(excludingRadius: Int, aroundPositions: [HexCoordinate]) -> [ResourcePlacement] {
        var placements: [ResourcePlacement] = []
        var usedCoordinates: Set<HexCoordinate> = []

        // Mark starting area coordinates as used
        for startPos in aroundPositions {
            for q in -excludingRadius...excludingRadius {
                for r in -excludingRadius...excludingRadius {
                    let coord = HexCoordinate(q: startPos.q + q, r: startPos.r + r)
                    if coord.distance(to: startPos) <= excludingRadius {
                        usedCoordinates.insert(coord)
                    }
                }
            }
        }

        // Generate tree pockets
        // Use smaller exclusion for trees since players have guaranteed starting woodlines
        let treeExclusionRadius = 6
        for _ in 0..<config.treePocketCount {
            let pocketSize = Int.random(in: config.treePocketSizeRange, using: &rng)
            let centerQ = Int.random(in: 3..<(width - 3), using: &rng)
            let centerR = Int.random(in: 3..<(height - 3), using: &rng)
            let center = HexCoordinate(q: centerQ, r: centerR)

            // Skip if too close to starting positions
            var tooClose = false
            for startPos in aroundPositions {
                if center.distance(to: startPos) < treeExclusionRadius {
                    tooClose = true
                    break
                }
            }
            if tooClose { continue }

            // Generate cluster of trees
            let treePlacements = generateResourceCluster(
                type: .trees,
                size: pocketSize,
                center: center,
                excluding: usedCoordinates
            )
            for placement in treePlacements {
                placements.append(placement)
                usedCoordinates.insert(placement.coordinate)
            }
        }

        // Generate mineral deposits (mix of ore and stone)
        for i in 0..<config.mineralDepositCount {
            let depositSize = Int.random(in: config.mineralDepositSizeRange, using: &rng)
            let centerQ = Int.random(in: 10..<(width - 10), using: &rng)
            let centerR = Int.random(in: 10..<(height - 10), using: &rng)
            let center = HexCoordinate(q: centerQ, r: centerR)

            // Skip if too close to starting positions
            var tooClose = false
            for startPos in aroundPositions {
                if center.distance(to: startPos) < excludingRadius + 3 {
                    tooClose = true
                    break
                }
            }
            if tooClose { continue }

            // Alternate between ore and stone
            let resourceType: ResourcePointType = (i % 2 == 0) ? .oreMine : .stoneQuarry

            let mineralPlacements = generateResourceCluster(
                type: resourceType,
                size: depositSize,
                center: center,
                excluding: usedCoordinates
            )
            for placement in mineralPlacements {
                placements.append(placement)
                usedCoordinates.insert(placement.coordinate)
            }
        }

        // Scatter some deer and boar across the map
        let animalCount = 15
        for _ in 0..<animalCount {
            let q = Int.random(in: 5..<(width - 5), using: &rng)
            let r = Int.random(in: 5..<(height - 5), using: &rng)
            let coord = HexCoordinate(q: q, r: r)

            // Skip if used or too close to starting positions
            if usedCoordinates.contains(coord) { continue }
            var tooClose = false
            for startPos in aroundPositions {
                if coord.distance(to: startPos) < excludingRadius {
                    tooClose = true
                    break
                }
            }
            if tooClose { continue }

            let animalType: ResourcePointType = Bool.random(using: &rng) ? .deer : .wildBoar
            placements.append(ResourcePlacement(coordinate: coord, resourceType: animalType))
            usedCoordinates.insert(coord)
        }

        return placements
    }

    // MARK: - Private Helper Methods

    private func generateHillClusters(terrain: inout [HexCoordinate: (terrain: TerrainType, elevation: Int)]) {
        // Use Perlin-like noise simulation for natural hill distribution
        // Start with random "hill seeds" and expand outward

        var hillSeeds: [HexCoordinate] = []

        // Generate hill seed points
        for r in 0..<height {
            for q in 0..<width {
                if Double.random(in: 0...1, using: &rng) < config.hillClusterChance * 0.3 {
                    hillSeeds.append(HexCoordinate(q: q, r: r))
                }
            }
        }

        // For each seed, create a hill cluster
        for seed in hillSeeds {
            let clusterSize = Int.random(in: 2...5, using: &rng)
            let peakElevation = Int.random(in: 1...config.maxElevation, using: &rng)

            // Set the seed tile
            if var data = terrain[seed] {
                data.terrain = .hill
                data.elevation = peakElevation
                terrain[seed] = data
            }

            // Expand outward with decreasing elevation
            var frontier = [seed]
            var visited = Set<HexCoordinate>([seed])
            var tilesPlaced = 1

            while tilesPlaced < clusterSize && !frontier.isEmpty {
                let current = frontier.removeFirst()
                let currentElevation = terrain[current]?.elevation ?? 0

                for neighbor in current.neighbors() {
                    if tilesPlaced >= clusterSize { break }
                    if visited.contains(neighbor) { continue }
                    if neighbor.q < 0 || neighbor.q >= width || neighbor.r < 0 || neighbor.r >= height { continue }

                    visited.insert(neighbor)

                    // Probability decreases with distance from seed
                    if Double.random(in: 0...1, using: &rng) < 0.6 {
                        let newElevation = max(1, currentElevation - Int.random(in: 0...1, using: &rng))
                        if var data = terrain[neighbor] {
                            data.terrain = .hill
                            data.elevation = newElevation
                            terrain[neighbor] = data
                        }
                        frontier.append(neighbor)
                        tilesPlaced += 1
                    }
                }
            }
        }
    }

    private func findUnusedCoordinate(from coords: inout [HexCoordinate], excluding used: Set<HexCoordinate>) -> HexCoordinate? {
        while !coords.isEmpty {
            let coord = coords.removeFirst()
            if !used.contains(coord) {
                return coord
            }
        }
        return nil
    }

    private func placeResourceCluster(
        type: ResourcePointType,
        size: Int,
        near center: HexCoordinate,
        radius: Int,
        excluding used: Set<HexCoordinate>
    ) -> [ResourcePlacement] {
        var placements: [ResourcePlacement] = []
        var usedLocal = used

        // Find a starting point for the cluster
        var candidates: [HexCoordinate] = []
        for q in -radius...radius {
            for r in -radius...radius {
                let coord = HexCoordinate(q: center.q + q, r: center.r + r)
                if coord.distance(to: center) <= radius && !usedLocal.contains(coord) {
                    candidates.append(coord)
                }
            }
        }

        candidates.shuffle(using: &rng)

        guard let startCoord = candidates.first else { return placements }

        // BFS to create adjacent cluster
        var frontier = [startCoord]
        var placed = 0

        while placed < size && !frontier.isEmpty {
            let current = frontier.removeFirst()

            if usedLocal.contains(current) { continue }
            if current.distance(to: center) > radius { continue }

            placements.append(ResourcePlacement(coordinate: current, resourceType: type))
            usedLocal.insert(current)
            placed += 1

            // Add neighbors to frontier
            for neighbor in current.neighbors().shuffled(using: &rng) {
                if !usedLocal.contains(neighbor) && neighbor.distance(to: center) <= radius {
                    frontier.append(neighbor)
                }
            }
        }

        return placements
    }

    private func generateResourceCluster(
        type: ResourcePointType,
        size: Int,
        center: HexCoordinate,
        excluding used: Set<HexCoordinate>
    ) -> [ResourcePlacement] {
        var placements: [ResourcePlacement] = []
        var usedLocal = used
        var frontier = [center]
        var placed = 0

        while placed < size && !frontier.isEmpty {
            let current = frontier.removeFirst()

            if usedLocal.contains(current) { continue }
            if current.q < 0 || current.q >= width || current.r < 0 || current.r >= height { continue }

            placements.append(ResourcePlacement(coordinate: current, resourceType: type))
            usedLocal.insert(current)
            placed += 1

            // Add neighbors to frontier (shuffled for organic shape)
            for neighbor in current.neighbors().shuffled(using: &rng) {
                if !usedLocal.contains(neighbor) {
                    frontier.append(neighbor)
                }
            }
        }

        return placements
    }
}

// MARK: - Seeded Random Number Generator

/// A simple seeded random number generator for reproducible map generation
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64 algorithm
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
