// ============================================================================
// FILE: Grow2 Shared/Data/MapData.swift
// PURPOSE: Pure data model for map state - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Terrain Data

/// Pure data representation of terrain type (mirrors TerrainType but with no UI dependencies)
enum TerrainData: String, Codable, CaseIterable {
    case plains
    case water
    case mountain
    case desert
    case hill

    var isWalkable: Bool {
        switch self {
        case .plains, .desert, .hill, .mountain: return true
        case .water: return false
        }
    }

    var movementCost: Int {
        switch self {
        case .plains, .desert: return 3
        case .hill: return 4
        case .mountain: return 5
        case .water: return Int.max
        }
    }

    var defenderDefenseBonus: Double {
        switch self {
        case .plains: return 0.0
        case .hill: return 0.15
        case .mountain: return 0.25
        case .desert: return -0.05
        case .water: return 0.0
        }
    }

    var attackerAttackPenalty: Double {
        switch self {
        case .mountain: return 0.10
        default: return 0.0
        }
    }
}

// MARK: - Tile Data

/// Pure data representation of a single hex tile
struct TileData: Codable {
    let coordinate: HexCoordinate
    var terrain: TerrainData
    var elevation: Int

    init(coordinate: HexCoordinate, terrain: TerrainData, elevation: Int = 0) {
        self.coordinate = coordinate
        self.terrain = terrain
        self.elevation = elevation
    }
}

// MARK: - Map Data

/// Pure data representation of the entire game map
class MapData: Codable {
    let width: Int
    let height: Int
    private(set) var tiles: [HexCoordinate: TileData]

    // References to entities on the map (by ID, not direct references)
    private(set) var buildingIDs: Set<UUID> = []
    private(set) var armyIDs: Set<UUID> = []
    private(set) var villagerGroupIDs: Set<UUID> = []
    private(set) var resourcePointIDs: Set<UUID> = []

    // Coordinate tracking for quick lookups
    private(set) var buildingCoordinates: [UUID: HexCoordinate] = [:]
    private(set) var armyCoordinates: [UUID: HexCoordinate] = [:]
    private(set) var villagerGroupCoordinates: [UUID: HexCoordinate] = [:]
    private(set) var resourcePointCoordinates: [UUID: HexCoordinate] = [:]

    // Multi-tile building support
    private(set) var occupiedCoordinates: [HexCoordinate: UUID] = [:]  // Coordinate -> BuildingID

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.tiles = [:]
    }

    // MARK: - Tile Management

    func setTile(_ tile: TileData) {
        tiles[tile.coordinate] = tile
    }

    func getTile(at coordinate: HexCoordinate) -> TileData? {
        return tiles[coordinate]
    }

    func getTerrain(at coordinate: HexCoordinate) -> TerrainData? {
        return tiles[coordinate]?.terrain
    }

    func isValidCoordinate(_ coord: HexCoordinate) -> Bool {
        return coord.q >= 0 && coord.q < width && coord.r >= 0 && coord.r < height
    }

    func isWalkable(_ coord: HexCoordinate) -> Bool {
        guard let tile = getTile(at: coord) else { return false }
        return tile.terrain.isWalkable
    }

    // MARK: - Building Management

    func registerBuilding(id: UUID, at coordinate: HexCoordinate, occupiedCoords: [HexCoordinate]) {
        buildingIDs.insert(id)
        buildingCoordinates[id] = coordinate

        for coord in occupiedCoords {
            occupiedCoordinates[coord] = id
        }
    }

    func unregisterBuilding(id: UUID) {
        buildingIDs.remove(id)
        buildingCoordinates.removeValue(forKey: id)

        // Remove all occupied coordinates for this building
        occupiedCoordinates = occupiedCoordinates.filter { $0.value != id }
    }

    func getBuildingID(at coordinate: HexCoordinate) -> UUID? {
        return occupiedCoordinates[coordinate]
    }

    func getBuildingCoordinate(id: UUID) -> HexCoordinate? {
        return buildingCoordinates[id]
    }

    // MARK: - Army Management

    func registerArmy(id: UUID, at coordinate: HexCoordinate) {
        armyIDs.insert(id)
        armyCoordinates[id] = coordinate
    }

    func unregisterArmy(id: UUID) {
        armyIDs.remove(id)
        armyCoordinates.removeValue(forKey: id)
    }

    func updateArmyPosition(id: UUID, to coordinate: HexCoordinate) {
        armyCoordinates[id] = coordinate
    }

    func getArmyID(at coordinate: HexCoordinate) -> UUID? {
        return armyCoordinates.first { $0.value == coordinate }?.key
    }

    func getArmyCoordinate(id: UUID) -> HexCoordinate? {
        return armyCoordinates[id]
    }

    // MARK: - Villager Group Management

    func registerVillagerGroup(id: UUID, at coordinate: HexCoordinate) {
        villagerGroupIDs.insert(id)
        villagerGroupCoordinates[id] = coordinate
    }

    func unregisterVillagerGroup(id: UUID) {
        villagerGroupIDs.remove(id)
        villagerGroupCoordinates.removeValue(forKey: id)
    }

    func updateVillagerGroupPosition(id: UUID, to coordinate: HexCoordinate) {
        villagerGroupCoordinates[id] = coordinate
    }

    func getVillagerGroupID(at coordinate: HexCoordinate) -> UUID? {
        return villagerGroupCoordinates.first { $0.value == coordinate }?.key
    }

    func getVillagerGroupCoordinate(id: UUID) -> HexCoordinate? {
        return villagerGroupCoordinates[id]
    }

    // MARK: - Resource Point Management

    func registerResourcePoint(id: UUID, at coordinate: HexCoordinate) {
        resourcePointIDs.insert(id)
        resourcePointCoordinates[id] = coordinate
    }

    func unregisterResourcePoint(id: UUID) {
        resourcePointIDs.remove(id)
        resourcePointCoordinates.removeValue(forKey: id)
    }

    func getResourcePointID(at coordinate: HexCoordinate) -> UUID? {
        return resourcePointCoordinates.first { $0.value == coordinate }?.key
    }

    func getResourcePointCoordinate(id: UUID) -> HexCoordinate? {
        return resourcePointCoordinates[id]
    }

    // MARK: - Passability

    func isPassable(at coord: HexCoordinate, forPlayerID playerID: UUID?, gameState: GameState) -> Bool {
        guard isWalkable(coord) else { return false }

        // Check for buildings that block movement
        if let buildingID = getBuildingID(at: coord),
           let building = gameState.getBuilding(id: buildingID),
           building.state == .completed {
            switch building.buildingType {
            case .wall:
                return false  // Walls block everyone
            case .gate:
                // Gates allow allies through
                guard let gateOwnerID = building.ownerID,
                      let requestorID = playerID else { return false }
                let status = gameState.getDiplomacyStatus(playerID: requestorID, otherPlayerID: gateOwnerID)
                return status.canMove
            default:
                break
            }
        }
        return true
    }

    func getMovementCost(at coordinate: HexCoordinate) -> Int {
        // Roads (buildings) reduce movement cost
        if getBuildingID(at: coordinate) != nil {
            return 1  // Roads negate terrain penalty
        }
        guard let tile = getTile(at: coordinate) else {
            return 3
        }
        return tile.terrain.movementCost
    }

    // MARK: - Pathfinding

    func findPath(from start: HexCoordinate, to goal: HexCoordinate, forPlayerID playerID: UUID?, gameState: GameState) -> [HexCoordinate]? {
        guard isValidCoordinate(start) && isValidCoordinate(goal) else { return nil }
        guard isPassable(at: goal, forPlayerID: playerID, gameState: gameState) else { return nil }
        guard start != goal else { return [] }

        var openSet: Set<HexCoordinate> = [start]
        var cameFrom: [HexCoordinate: HexCoordinate] = [:]
        var gScore: [HexCoordinate: Int] = [start: 0]
        var fScore: [HexCoordinate: Int] = [start: start.distance(to: goal)]

        while !openSet.isEmpty {
            let current = openSet.min(by: { fScore[$0] ?? Int.max < fScore[$1] ?? Int.max })!

            if current == goal {
                var path: [HexCoordinate] = []
                var currentNode = goal

                while currentNode != start {
                    path.append(currentNode)
                    guard let next = cameFrom[currentNode] else { break }
                    currentNode = next
                }

                return path.reversed()
            }

            openSet.remove(current)

            for neighbor in current.neighbors() {
                guard isValidCoordinate(neighbor) && isPassable(at: neighbor, forPlayerID: playerID, gameState: gameState) else { continue }

                let movementCost = getMovementCost(at: neighbor)
                let tentativeGScore = (gScore[current] ?? Int.max) + movementCost

                if tentativeGScore < (gScore[neighbor] ?? Int.max) {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentativeGScore
                    fScore[neighbor] = tentativeGScore + neighbor.distance(to: goal)
                    openSet.insert(neighbor)
                }
            }
        }

        return nil
    }

    func findNearestWalkable(to target: HexCoordinate, maxDistance: Int = 5, forPlayerID playerID: UUID?, gameState: GameState) -> HexCoordinate? {
        if isPassable(at: target, forPlayerID: playerID, gameState: gameState) &&
           getArmyID(at: target) == nil &&
           getVillagerGroupID(at: target) == nil &&
           getBuildingID(at: target) == nil {
            return target
        }

        for distance in 1...maxDistance {
            var candidates: [HexCoordinate] = []

            for (coord, _) in tiles {
                if coord.distance(to: target) == distance {
                    if isPassable(at: coord, forPlayerID: playerID, gameState: gameState) &&
                       getArmyID(at: coord) == nil &&
                       getVillagerGroupID(at: coord) == nil &&
                       getBuildingID(at: coord) == nil {
                        candidates.append(coord)
                    }
                }
            }

            if !candidates.isEmpty {
                return candidates.min(by: { $0.distance(to: target) < $1.distance(to: target) })
            }
        }

        return nil
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case width, height, tiles
        case buildingIDs, armyIDs, villagerGroupIDs, resourcePointIDs
        case buildingCoordinates, armyCoordinates, villagerGroupCoordinates, resourcePointCoordinates
        case occupiedCoordinates
    }
}

// MARK: - Diplomacy Status Extension

extension DiplomacyStatusData {
    var canMove: Bool {
        switch self {
        case .me, .guild, .ally:
            return true
        case .neutral, .enemy:
            return false
        }
    }
}
