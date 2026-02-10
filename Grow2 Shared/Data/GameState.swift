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

    // MARK: - Transient State (not saved)
    /// Active reinforcement positions per player (synced from visual layer)
    var activeReinforcementPositions: [UUID: Set<HexCoordinate>] = [:]

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

        // Reassign home bases for armies that had this building as home
        reassignHomeBasesForDestroyedBuilding(id, ownerID: building.ownerID)

        // Update player ownership
        if let ownerID = building.ownerID, let player = getPlayer(id: ownerID) {
            player.removeOwnedBuilding(id)
        }

        // Unregister from map data
        mapData.unregisterBuilding(id: id)

        buildings.removeValue(forKey: id)
    }

    /// Reassigns home bases for armies when their home building is destroyed.
    /// Distributes evicted armies across available home bases respecting capacity, with city center as fallback.
    private func reassignHomeBasesForDestroyedBuilding(_ buildingID: UUID, ownerID: UUID?) {
        guard let ownerID = ownerID else { return }

        let evictedArmies = armies.values.filter { $0.homeBaseID == buildingID }
        guard !evictedArmies.isEmpty else { return }

        for army in evictedArmies {
            // Try to find a home base with capacity (nearest first, excluding city center initially)
            let validTypes: Set<BuildingType> = [.woodenFort, .castle]
            let candidateBases = buildings.values.filter {
                $0.ownerID == ownerID &&
                validTypes.contains($0.buildingType) &&
                $0.isOperational &&
                $0.id != buildingID
            }.sorted { army.coordinate.distance(to: $0.coordinate) < army.coordinate.distance(to: $1.coordinate) }

            var assigned = false
            for base in candidateBases {
                if hasHomeBaseCapacity(buildingID: base.id) {
                    army.homeBaseID = base.id
                    debugLog("🏠 \(army.name) home base reassigned to \(base.buildingType.displayName) (level \(base.level))")
                    assigned = true
                    break
                }
            }

            // Fallback: city center (unlimited capacity)
            if !assigned {
                if let cityCenter = buildings.values.first(where: { $0.ownerID == ownerID && $0.buildingType == .cityCenter }) {
                    army.homeBaseID = cityCenter.id
                    debugLog("🏠 \(army.name) home base reassigned to City Center")
                }
            }
        }
    }

    // MARK: - Home Base Capacity

    /// Returns the count of armies currently using this building as their home base
    func getArmyCountForHomeBase(buildingID: UUID) -> Int {
        return armies.values.filter { $0.homeBaseID == buildingID }.count
    }

    /// Returns the armies currently using this building as their home base
    func getArmiesForHomeBase(buildingID: UUID) -> [ArmyData] {
        return armies.values.filter { $0.homeBaseID == buildingID }
    }

    /// Returns true if the building has room for another army as home base.
    /// City center always returns true (unlimited). Non-home-base buildings return false.
    func hasHomeBaseCapacity(buildingID: UUID) -> Bool {
        guard let building = buildings[buildingID] else { return false }
        guard let capacity = building.getArmyHomeBaseCapacity() else { return true }  // nil = unlimited
        guard capacity > 0 else { return false }  // 0 = not a home base
        return getArmyCountForHomeBase(buildingID: buildingID) < capacity
    }

    /// Finds a home base with available capacity for the given player, nearest to the coordinate.
    /// Prefers forts/castles with capacity, falls back to city center.
    func findHomeBaseWithCapacity(for playerID: UUID, from coordinate: HexCoordinate, excluding buildingID: UUID? = nil) -> BuildingData? {
        let validTypes: Set<BuildingType> = [.cityCenter, .woodenFort, .castle]
        let candidates = buildings.values.filter {
            $0.ownerID == playerID &&
            validTypes.contains($0.buildingType) &&
            $0.isOperational &&
            $0.id != buildingID
        }.sorted { coordinate.distance(to: $0.coordinate) < coordinate.distance(to: $1.coordinate) }

        for base in candidates {
            if hasHomeBaseCapacity(buildingID: base.id) {
                return base
            }
        }
        return nil
    }

    /// Finds the nearest valid home base building for retreat (City Center, Castle, or Wooden Fort)
    /// - Parameters:
    ///   - playerID: The player who owns the buildings
    ///   - coordinate: The coordinate to measure distance from
    ///   - excluding: Optional coordinate to exclude (e.g., the building the army is currently at)
    func findNearestHomeBase(for playerID: UUID, from coordinate: HexCoordinate, excluding: HexCoordinate? = nil) -> BuildingData? {
        let validTypes: Set<BuildingType> = [.cityCenter, .woodenFort, .castle]
        var playerBuildings = buildings.values.filter {
            $0.ownerID == playerID &&
            validTypes.contains($0.buildingType) &&
            $0.isOperational
        }

        // Exclude buildings at the specified coordinate (for retreat from current location)
        if let excludeCoord = excluding {
            playerBuildings = playerBuildings.filter { building in
                // Check if any of the building's occupied coordinates match the exclusion
                !building.occupiedCoordinates.contains(excludeCoord)
            }
        }

        return playerBuildings.min(by: {
            coordinate.distance(to: $0.coordinate) < coordinate.distance(to: $1.coordinate)
        })
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

    /// Returns all armies at the given coordinate
    func getArmies(at coordinate: HexCoordinate) -> [ArmyData] {
        return mapData.getArmyIDs(at: coordinate).compactMap { armies[$0] }
    }

    /// Returns all entrenched armies that cover a given coordinate (from adjacent tiles)
    func getEntrenchedArmiesCovering(coordinate: HexCoordinate) -> [ArmyData] {
        var result: [ArmyData] = []
        for neighbor in coordinate.neighbors() {
            let armiesAtNeighbor = getArmies(at: neighbor)
            for army in armiesAtNeighbor where army.isEntrenched {
                if army.entrenchedCoveredTiles.contains(coordinate) {
                    result.append(army)
                }
            }
        }
        return result
    }

    /// Computes which neighbor tiles an army's entrenchment should cover,
    /// excluding tiles already covered by enemy entrenchment.
    func computeEntrenchmentCoverage(for army: ArmyData) -> Set<HexCoordinate> {
        var covered = Set<HexCoordinate>()
        for neighbor in army.coordinate.neighbors() {
            let enemyCoverage = getEntrenchedArmiesCovering(coordinate: neighbor)
                .filter { $0.ownerID != army.ownerID }
            if enemyCoverage.isEmpty {
                covered.insert(neighbor)
            }
        }
        return covered
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

    /// Returns all villager groups at the given coordinate
    func getVillagerGroups(at coordinate: HexCoordinate) -> [VillagerGroupData] {
        return mapData.getVillagerGroupIDs(at: coordinate).compactMap { villagerGroups[$0] }
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

        // Count military units in armies (pop-space-aware)
        for army in getArmiesForPlayer(id: playerID) {
            current += army.getPopulationUsed()
        }

        // Count garrisoned units and calculate capacity
        for building in getBuildingsForPlayer(id: playerID) {
            if building.isOperational {
                current += building.villagerGarrison
                current += building.getGarrisonPopulation()

                // Add training queue units (pop-space-aware)
                for entry in building.trainingQueue {
                    current += entry.unitType.popSpace * entry.quantity
                }
                for entry in building.villagerTrainingQueue {
                    current += entry.quantity
                }

                // Add capacity from building type (scales with level)
                capacity += building.buildingType.populationCapacity(forLevel: building.level)
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

    // MARK: - Building Protection

    /// Check if a building is protected by a nearby defensive building (Castle/Fort/Tower)
    /// A building is protected if there's an operational defensive building owned by the same player within range
    func isBuildingProtected(_ buildingID: UUID) -> Bool {
        return !getProtectingBuildings(for: buildingID).isEmpty
    }

    /// Get defensive buildings (Castle/Fort/Tower) within range of a coordinate for a player
    /// - Parameters:
    ///   - coordinate: The coordinate to check around
    ///   - range: The maximum distance in hexes
    ///   - playerID: The player who owns the defensive buildings
    /// - Returns: Array of defensive BuildingData within range
    func getDefensiveBuildingsInRange(of coordinate: HexCoordinate, range: Int, forPlayer playerID: UUID) -> [BuildingData] {
        var defensiveBuildings: [BuildingData] = []

        for building in buildings.values {
            // Must be owned by the specified player
            guard building.ownerID == playerID else { continue }

            // Must be a defensive building type
            guard building.canProvideGarrisonDefense else { continue }

            // Must be operational (not under construction or destroyed)
            guard building.isOperational else { continue }

            // Check distance from any occupied coordinate of the defensive building
            // to the target coordinate
            let minDistance = building.occupiedCoordinates.map { $0.distance(to: coordinate) }.min() ?? Int.max
            if minDistance <= range {
                defensiveBuildings.append(building)
            }
        }

        return defensiveBuildings
    }

    /// Get the specific defensive building(s) protecting a target building
    /// A defensive building protects another building if:
    /// - Both are owned by the same player
    /// - The defensive building is operational
    /// - The defensive building is within garrisonDefenseRange of any tile the target occupies
    /// - The defensive building is NOT the target itself (no self-protection)
    func getProtectingBuildings(for buildingID: UUID) -> [BuildingData] {
        guard let targetBuilding = buildings[buildingID],
              let ownerID = targetBuilding.ownerID else {
            return []
        }

        var protectors: [BuildingData] = []

        for building in buildings.values {
            // Skip self - buildings don't protect themselves
            guard building.id != buildingID else { continue }

            // Must be owned by the same player
            guard building.ownerID == ownerID else { continue }

            // Must be a defensive building type
            guard building.canProvideGarrisonDefense else { continue }

            // Must be operational
            guard building.isOperational else { continue }

            let defenseRange = building.garrisonDefenseRange

            // Check if any tile of the defensive building is within range of any tile of the target
            let isInRange = building.occupiedCoordinates.contains { defenderCoord in
                targetBuilding.occupiedCoordinates.contains { targetCoord in
                    defenderCoord.distance(to: targetCoord) <= defenseRange
                }
            }

            if isInRange {
                protectors.append(building)
            }
        }

        return protectors
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
