// ============================================================================
// FILE: Grow2 Shared/Engine/VisionEngine.swift
// PURPOSE: Handles fog of war and vision logic - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Vision Range

struct VisionRangeData {
    let baseRange: Int
    let buildingType: BuildingType?
    let entityType: String?
}

// MARK: - Vision Engine

/// Handles all fog of war and visibility calculations
class VisionEngine {

    // MARK: - State
    private weak var gameState: GameState?

    // MARK: - Vision Ranges
    private let baseUnitVisionRange = 3
    private let baseVillagerVisionRange = 2

    // Building vision ranges
    private let buildingVisionRanges: [BuildingType: Int] = [
        .cityCenter: 5,
        .tower: 6,
        .castle: 5,
        .woodenFort: 4,
        .barracks: 3,
        .archeryRange: 3,
        .stable: 3,
        .siegeWorkshop: 3,
        .lumberCamp: 2,
        .miningCamp: 2,
        .farm: 1,
        .mill: 2,
        .warehouse: 2,
        .blacksmith: 2,
        .market: 2,
        .neighborhood: 2,
        .university: 3,
        .wall: 1,
        .gate: 2,
        .road: 1
    ]

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
    }

    // MARK: - Update Loop

    func update(currentTime: TimeInterval) -> [StateChange] {
        guard let state = gameState else { return [] }

        var changes: [StateChange] = []

        // Update vision for all players
        for player in state.players.values {
            let visibleCoords = calculateVisibleCoordinates(for: player.id, state: state)
            let previousVisible = player.visibleCoordinates

            player.setVisibleCoordinates(visibleCoords)

            // Generate changes for newly visible/hidden coordinates
            let newlyVisible = visibleCoords.subtracting(previousVisible)
            let newlyHidden = previousVisible.subtracting(visibleCoords)

            for coord in newlyVisible {
                changes.append(.fogOfWarUpdated(
                    playerID: player.id,
                    coordinate: coord,
                    visibility: "visible"
                ))
            }

            for coord in newlyHidden {
                // Check if it's now explored (was visible) or unexplored
                let visibility = player.isExplored(coord) ? "explored" : "unexplored"
                changes.append(.fogOfWarUpdated(
                    playerID: player.id,
                    coordinate: coord,
                    visibility: visibility
                ))
            }
        }

        return changes
    }

    // MARK: - Vision Calculation

    private func calculateVisibleCoordinates(for playerID: UUID, state: GameState) -> Set<HexCoordinate> {
        var visibleCoords: Set<HexCoordinate> = []

        // Vision from buildings
        for building in state.getBuildingsForPlayer(id: playerID) {
            guard building.isOperational else { continue }

            let range = buildingVisionRanges[building.buildingType] ?? 2

            // Add vision from all coordinates the building occupies
            for occupiedCoord in building.occupiedCoordinates {
                let coords = getCoordinatesInRange(center: occupiedCoord, range: range, state: state)
                visibleCoords.formUnion(coords)
            }
        }

        // Vision from armies
        for army in state.getArmiesForPlayer(id: playerID) {
            let range = baseUnitVisionRange
            let coords = getCoordinatesInRange(center: army.coordinate, range: range, state: state)
            visibleCoords.formUnion(coords)
        }

        // Vision from villager groups
        for group in state.getVillagerGroupsForPlayer(id: playerID) {
            let range = baseVillagerVisionRange
            let coords = getCoordinatesInRange(center: group.coordinate, range: range, state: state)
            visibleCoords.formUnion(coords)
        }

        return visibleCoords
    }

    private func getCoordinatesInRange(center: HexCoordinate, range: Int, state: GameState) -> Set<HexCoordinate> {
        var coords: Set<HexCoordinate> = []

        // Add center
        coords.insert(center)

        // Add all hexes in range
        for r in 1...range {
            let ring = getRing(center: center, radius: r)
            for coord in ring {
                if state.mapData.isValidCoordinate(coord) {
                    // Check for line of sight blocking (mountains reduce vision)
                    if hasLineOfSight(from: center, to: coord, maxBlockedRange: r, state: state) {
                        coords.insert(coord)
                    }
                }
            }
        }

        return coords
    }

    private func getRing(center: HexCoordinate, radius: Int) -> [HexCoordinate] {
        if radius == 0 {
            return [center]
        }

        var results: [HexCoordinate] = []
        var hex = HexCoordinate(q: center.q - radius, r: center.r + radius)

        let directions = [
            HexCoordinate(q: 1, r: 0), HexCoordinate(q: 1, r: -1),
            HexCoordinate(q: 0, r: -1), HexCoordinate(q: -1, r: 0),
            HexCoordinate(q: -1, r: 1), HexCoordinate(q: 0, r: 1)
        ]

        for direction in directions {
            for _ in 0..<radius {
                results.append(hex)
                hex = HexCoordinate(q: hex.q + direction.q, r: hex.r + direction.r)
            }
        }

        return results
    }

    private func hasLineOfSight(from start: HexCoordinate, to end: HexCoordinate, maxBlockedRange: Int, state: GameState) -> Bool {
        // Simple line of sight check - mountains at close range block vision beyond them
        // For simplicity, we just reduce vision through mountains by not counting hexes beyond them

        let distance = start.distance(to: end)
        if distance <= 1 {
            return true  // Adjacent hexes always visible
        }

        // Check intermediate hexes for mountains
        let path = getLinePath(from: start, to: end)

        for i in 1..<path.count - 1 {
            let coord = path[i]
            if let terrain = state.mapData.getTerrain(at: coord) {
                if terrain == .mountain {
                    // Mountain blocks vision to hexes beyond it
                    return false
                }
            }
        }

        return true
    }

    private func getLinePath(from start: HexCoordinate, to end: HexCoordinate) -> [HexCoordinate] {
        let distance = start.distance(to: end)
        guard distance > 0 else { return [start] }

        var path: [HexCoordinate] = []

        for i in 0...distance {
            let t = Double(i) / Double(distance)

            // Linear interpolation in cube coordinates
            let startCube = start.toCube()
            let endCube = end.toCube()

            let x = startCube.0 + (endCube.0 - startCube.0) * t
            let y = startCube.1 + (endCube.1 - startCube.1) * t
            let z = startCube.2 + (endCube.2 - startCube.2) * t

            // Round to nearest hex
            let coord = roundCubeToHex(x: x, y: y, z: z)
            if path.last != coord {
                path.append(coord)
            }
        }

        return path
    }

    private func roundCubeToHex(x: Double, y: Double, z: Double) -> HexCoordinate {
        var rx = round(x)
        var ry = round(y)
        var rz = round(z)

        let xDiff = abs(rx - x)
        let yDiff = abs(ry - y)
        let zDiff = abs(rz - z)

        if xDiff > yDiff && xDiff > zDiff {
            rx = -ry - rz
        } else if yDiff > zDiff {
            ry = -rx - rz
        } else {
            rz = -rx - ry
        }

        // Convert cube to axial
        return HexCoordinate(q: Int(rx), r: Int(rz))
    }

    // MARK: - Query Methods

    func isVisible(coordinate: HexCoordinate, forPlayer playerID: UUID) -> Bool {
        guard let player = gameState?.getPlayer(id: playerID) else { return false }
        return player.isVisible(coordinate)
    }

    func isExplored(coordinate: HexCoordinate, forPlayer playerID: UUID) -> Bool {
        guard let player = gameState?.getPlayer(id: playerID) else { return false }
        return player.isExplored(coordinate)
    }

    func getVisibilityLevel(coordinate: HexCoordinate, forPlayer playerID: UUID) -> VisibilityLevelData {
        guard let player = gameState?.getPlayer(id: playerID) else { return .unexplored }
        return player.getVisibilityLevel(at: coordinate)
    }

    func getVisibleEnemies(forPlayer playerID: UUID) -> [ArmyData] {
        guard let state = gameState,
              let player = state.getPlayer(id: playerID) else { return [] }

        var visibleEnemies: [ArmyData] = []

        for army in state.armies.values {
            guard let armyOwnerID = army.ownerID, armyOwnerID != playerID else { continue }

            if player.isVisible(army.coordinate) {
                visibleEnemies.append(army)
            }
        }

        return visibleEnemies
    }

    func getVisibleEnemyBuildings(forPlayer playerID: UUID) -> [BuildingData] {
        guard let state = gameState,
              let player = state.getPlayer(id: playerID) else { return [] }

        var visibleBuildings: [BuildingData] = []

        for building in state.buildings.values {
            guard let buildingOwnerID = building.ownerID, buildingOwnerID != playerID else { continue }

            // Check if any of the building's coordinates are visible
            for coord in building.occupiedCoordinates {
                if player.isVisible(coord) {
                    visibleBuildings.append(building)
                    break
                }
            }
        }

        return visibleBuildings
    }
}

// MARK: - HexCoordinate Extension for Cube Coordinates

extension HexCoordinate {
    func toCube() -> (Double, Double, Double) {
        let x = Double(q)
        let z = Double(r)
        let y = -x - z
        return (x, y, z)
    }
}
