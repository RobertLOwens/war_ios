// ============================================================================
// FILE: Grow2 Shared/Data/GameState.swift
// PURPOSE: Central game state container - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Game State

/// Central container for all game state data
/// This is the authoritative source of truth for the game
class GameState: Codable {

    // MARK: - Map Data
    let mapData: MapData

    // MARK: - Players
    private(set) var players: [UUID: PlayerState] = [:]
    var localPlayerID: UUID?

    // MARK: - Buildings
    private(set) var buildings: [UUID: BuildingData] = [:]

    // MARK: - Armies
    private(set) var armies: [UUID: ArmyData] = [:]

    // MARK: - Villager Groups
    private(set) var villagerGroups: [UUID: VillagerGroupData] = [:]

    // MARK: - Resource Points
    private(set) var resourcePoints: [UUID: ResourcePointData] = [:]

    // MARK: - Commanders
    private(set) var commanders: [UUID: CommanderData] = [:]

    // MARK: - Time
    var currentTime: TimeInterval = 0.0
    var gameStartTime: TimeInterval = 0.0

    // MARK: - Game Settings
    var isPaused: Bool = false
    var gameSpeed: Double = 1.0

    // MARK: - Initialization

    init(mapWidth: Int, mapHeight: Int) {
        self.mapData = MapData(width: mapWidth, height: mapHeight)
    }

    // MARK: - Player Management

    func addPlayer(_ player: PlayerState) {
        players[player.id] = player
    }

    func removePlayer(id: UUID) {
        players.removeValue(forKey: id)
    }

    func getPlayer(id: UUID) -> PlayerState? {
        return players[id]
    }

    func getLocalPlayer() -> PlayerState? {
        guard let localID = localPlayerID else { return nil }
        return players[localID]
    }

    func getAllPlayers() -> [PlayerState] {
        return Array(players.values)
    }

    func getDiplomacyStatus(playerID: UUID, otherPlayerID: UUID) -> DiplomacyStatusData {
        guard let player = getPlayer(id: playerID) else { return .neutral }
        return player.getDiplomacyStatus(with: otherPlayerID)
    }

    // MARK: - Building Management

    func addBuilding(_ building: BuildingData) {
        buildings[building.id] = building

        // Register with map data
        mapData.registerBuilding(
            id: building.id,
            at: building.coordinate,
            occupiedCoords: building.occupiedCoordinates
        )

        // Update player ownership
        if let ownerID = building.ownerID, let player = getPlayer(id: ownerID) {
            player.addOwnedBuilding(building.id)
        }
    }

    func removeBuilding(id: UUID) {
        guard let building = buildings[id] else { return }

        // Update player ownership
        if let ownerID = building.ownerID, let player = getPlayer(id: ownerID) {
            player.removeOwnedBuilding(id)
        }

        // Unregister from map data
        mapData.unregisterBuilding(id: id)

        buildings.removeValue(forKey: id)
    }

    func getBuilding(id: UUID) -> BuildingData? {
        return buildings[id]
    }

    func getBuilding(at coordinate: HexCoordinate) -> BuildingData? {
        guard let buildingID = mapData.getBuildingID(at: coordinate) else { return nil }
        return buildings[buildingID]
    }

    func getBuildingsForPlayer(id: UUID) -> [BuildingData] {
        return buildings.values.filter { $0.ownerID == id }
    }

    // MARK: - Army Management

    func addArmy(_ army: ArmyData) {
        armies[army.id] = army

        // Register with map data
        mapData.registerArmy(id: army.id, at: army.coordinate)

        // Update player ownership
        if let ownerID = army.ownerID, let player = getPlayer(id: ownerID) {
            player.addOwnedArmy(army.id)
        }
    }

    func removeArmy(id: UUID) {
        guard let army = armies[id] else { return }

        // Update player ownership
        if let ownerID = army.ownerID, let player = getPlayer(id: ownerID) {
            player.removeOwnedArmy(id)
        }

        // Unregister from map data
        mapData.unregisterArmy(id: id)

        armies.removeValue(forKey: id)
    }

    func getArmy(id: UUID) -> ArmyData? {
        return armies[id]
    }

    func getArmy(at coordinate: HexCoordinate) -> ArmyData? {
        guard let armyID = mapData.getArmyID(at: coordinate) else { return nil }
        return armies[armyID]
    }

    func getArmiesForPlayer(id: UUID) -> [ArmyData] {
        return armies.values.filter { $0.ownerID == id }
    }

    func updateArmyPosition(armyID: UUID, to coordinate: HexCoordinate) {
        guard let army = armies[armyID] else { return }
        army.coordinate = coordinate
        mapData.updateArmyPosition(id: armyID, to: coordinate)
    }

    // MARK: - Villager Group Management

    func addVillagerGroup(_ group: VillagerGroupData) {
        villagerGroups[group.id] = group

        // Register with map data
        mapData.registerVillagerGroup(id: group.id, at: group.coordinate)

        // Update player ownership
        if let ownerID = group.ownerID, let player = getPlayer(id: ownerID) {
            player.addOwnedVillagerGroup(group.id)
        }
    }

    func removeVillagerGroup(id: UUID) {
        guard let group = villagerGroups[id] else { return }

        // Update player ownership
        if let ownerID = group.ownerID, let player = getPlayer(id: ownerID) {
            player.removeOwnedVillagerGroup(id)
        }

        // Unregister from map data
        mapData.unregisterVillagerGroup(id: id)

        villagerGroups.removeValue(forKey: id)
    }

    func getVillagerGroup(id: UUID) -> VillagerGroupData? {
        return villagerGroups[id]
    }

    func getVillagerGroup(at coordinate: HexCoordinate) -> VillagerGroupData? {
        guard let groupID = mapData.getVillagerGroupID(at: coordinate) else { return nil }
        return villagerGroups[groupID]
    }

    func getVillagerGroupsForPlayer(id: UUID) -> [VillagerGroupData] {
        return villagerGroups.values.filter { $0.ownerID == id }
    }

    func updateVillagerGroupPosition(groupID: UUID, to coordinate: HexCoordinate) {
        guard let group = villagerGroups[groupID] else { return }
        group.coordinate = coordinate
        mapData.updateVillagerGroupPosition(id: groupID, to: coordinate)
    }

    // MARK: - Resource Point Management

    func addResourcePoint(_ resourcePoint: ResourcePointData) {
        resourcePoints[resourcePoint.id] = resourcePoint

        // Register with map data
        mapData.registerResourcePoint(id: resourcePoint.id, at: resourcePoint.coordinate)
    }

    func removeResourcePoint(id: UUID) {
        // Unregister from map data
        mapData.unregisterResourcePoint(id: id)

        resourcePoints.removeValue(forKey: id)
    }

    func getResourcePoint(id: UUID) -> ResourcePointData? {
        return resourcePoints[id]
    }

    func getResourcePoint(at coordinate: HexCoordinate) -> ResourcePointData? {
        guard let resourceID = mapData.getResourcePointID(at: coordinate) else { return nil }
        return resourcePoints[resourceID]
    }

    func getAllResourcePoints() -> [ResourcePointData] {
        return Array(resourcePoints.values)
    }

    // MARK: - Commander Management

    func addCommander(_ commander: CommanderData) {
        commanders[commander.id] = commander

        // Update player ownership
        if let ownerID = commander.ownerID, let player = getPlayer(id: ownerID) {
            player.addOwnedCommander(commander.id)
        }
    }

    func removeCommander(id: UUID) {
        guard let commander = commanders[id] else { return }

        // Update player ownership
        if let ownerID = commander.ownerID, let player = getPlayer(id: ownerID) {
            player.removeOwnedCommander(id)
        }

        commanders.removeValue(forKey: id)
    }

    func getCommander(id: UUID) -> CommanderData? {
        return commanders[id]
    }

    func getCommandersForPlayer(id: UUID) -> [CommanderData] {
        return commanders.values.filter { $0.ownerID == id }
    }

    // MARK: - Query Helpers

    /// Get all entities at a coordinate
    func getEntitiesAt(coordinate: HexCoordinate) -> (building: BuildingData?, army: ArmyData?, villagerGroup: VillagerGroupData?, resourcePoint: ResourcePointData?) {
        return (
            building: getBuilding(at: coordinate),
            army: getArmy(at: coordinate),
            villagerGroup: getVillagerGroup(at: coordinate),
            resourcePoint: getResourcePoint(at: coordinate)
        )
    }

    /// Check if coordinate is empty (no entities)
    func isCoordinateEmpty(_ coordinate: HexCoordinate) -> Bool {
        let entities = getEntitiesAt(coordinate: coordinate)
        return entities.building == nil &&
               entities.army == nil &&
               entities.villagerGroup == nil
    }

    /// Get all enemy armies within range of a coordinate for a player
    func getEnemyArmiesInRange(of coordinate: HexCoordinate, range: Int, forPlayer playerID: UUID) -> [ArmyData] {
        var enemyArmies: [ArmyData] = []

        for army in armies.values {
            guard let armyOwnerID = army.ownerID, armyOwnerID != playerID else { continue }

            if army.coordinate.distance(to: coordinate) <= range {
                enemyArmies.append(army)
            }
        }

        return enemyArmies
    }

    /// Get population stats for a player
    func getPopulationStats(forPlayer playerID: UUID) -> (current: Int, capacity: Int) {
        var current = 0
        var capacity = 0

        // Count villagers
        for group in getVillagerGroupsForPlayer(id: playerID) {
            current += group.villagerCount
        }

        // Count military units in armies
        for army in getArmiesForPlayer(id: playerID) {
            current += army.getTotalUnits()
        }

        // Count garrisoned units and calculate capacity
        for building in getBuildingsForPlayer(id: playerID) {
            if building.isOperational {
                current += building.villagerGarrison
                current += building.getTotalGarrisonedUnits()

                // Add training queue units
                for entry in building.trainingQueue {
                    current += entry.quantity
                }
                for entry in building.villagerTrainingQueue {
                    current += entry.quantity
                }

                // Add capacity from building type
                capacity += building.buildingType.populationCapacity
            }
        }

        return (current: current, capacity: capacity)
    }

    /// Get storage capacity for a player
    func getStorageCapacity(forPlayer playerID: UUID, resourceType: ResourceTypeData) -> Int {
        var capacity = 0

        for building in getBuildingsForPlayer(id: playerID) {
            if building.isOperational {
                let buildingCapacity = building.buildingType.storageCapacityPerResource(forLevel: building.level)
                if buildingCapacity > 0 {
                    capacity += buildingCapacity
                }
            }
        }

        // Minimum storage of 200 even without buildings
        return max(200, capacity)
    }

    /// Get city center level for a player
    func getCityCenterLevel(forPlayer playerID: UUID) -> Int {
        let cityCenters = getBuildingsForPlayer(id: playerID).filter {
            $0.buildingType == .cityCenter && ($0.state == .completed || $0.state == .upgrading)
        }
        return cityCenters.map { $0.level }.max() ?? 0
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case mapData
        case players, localPlayerID
        case buildings, armies, villagerGroups, resourcePoints, commanders
        case currentTime, gameStartTime
        case isPaused, gameSpeed
    }
}

// MARK: - Game State Snapshot

/// A lightweight snapshot of game state for serialization
struct GameStateSnapshot: Codable {
    let timestamp: TimeInterval
    let mapWidth: Int
    let mapHeight: Int
    let players: [PlayerState]
    let buildings: [BuildingData]
    let armies: [ArmyData]
    let villagerGroups: [VillagerGroupData]
    let resourcePoints: [ResourcePointData]
    let commanders: [CommanderData]
    let localPlayerID: UUID?

    init(from gameState: GameState) {
        self.timestamp = gameState.currentTime
        self.mapWidth = gameState.mapData.width
        self.mapHeight = gameState.mapData.height
        self.players = Array(gameState.players.values)
        self.buildings = Array(gameState.buildings.values)
        self.armies = Array(gameState.armies.values)
        self.villagerGroups = Array(gameState.villagerGroups.values)
        self.resourcePoints = Array(gameState.resourcePoints.values)
        self.commanders = Array(gameState.commanders.values)
        self.localPlayerID = gameState.localPlayerID
    }

    func restore() -> GameState {
        let gameState = GameState(mapWidth: mapWidth, mapHeight: mapHeight)
        gameState.currentTime = timestamp
        gameState.localPlayerID = localPlayerID

        for player in players {
            gameState.addPlayer(player)
        }

        for resourcePoint in resourcePoints {
            gameState.addResourcePoint(resourcePoint)
        }

        for building in buildings {
            gameState.addBuilding(building)
        }

        for army in armies {
            gameState.addArmy(army)
        }

        for villagerGroup in villagerGroups {
            gameState.addVillagerGroup(villagerGroup)
        }

        for commander in commanders {
            gameState.addCommander(commander)
        }

        return gameState
    }
}
