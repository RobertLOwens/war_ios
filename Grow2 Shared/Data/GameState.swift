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

    /// Reassigns home bases for armies when their home building is destroyed
    private func reassignHomeBasesForDestroyedBuilding(_ buildingID: UUID, ownerID: UUID?) {
        guard let ownerID = ownerID else { return }

        // Find city center for this player
        let cityCenter = buildings.values.first {
            $0.ownerID == ownerID && $0.buildingType == .cityCenter
        }
        guard let cityCenterID = cityCenter?.id else { return }

        // Reassign all armies that had this building as home base
        for army in armies.values where army.homeBaseID == buildingID {
            army.homeBaseID = cityCenterID
            print("🏠 \(army.name) home base reassigned to City Center")
        }
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

    // MARK: - AI Helper Methods

    /// Get all AI players
    func getAIPlayers() -> [PlayerState] {
        return players.values.filter { $0.isAI }
    }

    /// Get resource points that the player has explored (for AI fog of war respect)
    func getExploredResourcePoints(forPlayer playerID: UUID) -> [ResourcePointData] {
        guard let player = getPlayer(id: playerID) else { return [] }
        return resourcePoints.values.filter { player.isExplored($0.coordinate) }
    }

    /// Get resource points that are currently visible to the player
    func getVisibleResourcePoints(forPlayer playerID: UUID) -> [ResourcePointData] {
        guard let player = getPlayer(id: playerID) else { return [] }
        return resourcePoints.values.filter { player.isVisible($0.coordinate) }
    }

    /// Find nearest unexplored coordinate within range for scouting
    func findNearestUnexploredCoordinate(from coordinate: HexCoordinate, forPlayer playerID: UUID, maxRange: Int = 12) -> HexCoordinate? {
        guard let player = getPlayer(id: playerID) else { return nil }

        // Search in expanding rings to find nearest unexplored tile
        for distance in 1...maxRange {
            let ring = coordinate.coordinatesInRing(distance: distance)
            for coord in ring {
                // Must be valid and walkable
                guard mapData.isValidCoordinate(coord) && mapData.isWalkable(coord) else { continue }

                // Must be unexplored
                if !player.isExplored(coord) {
                    return coord
                }
            }
        }

        return nil
    }

    /// Get the nearest enemy army to a coordinate for a player
    func getNearestEnemyArmy(from coordinate: HexCoordinate, forPlayer playerID: UUID) -> ArmyData? {
        var nearestArmy: ArmyData?
        var nearestDistance = Int.max

        for army in armies.values {
            guard let armyOwnerID = army.ownerID, armyOwnerID != playerID else { continue }

            // Check if this army belongs to an enemy
            let status = getDiplomacyStatus(playerID: playerID, otherPlayerID: armyOwnerID)
            guard status == .enemy else { continue }

            let distance = coordinate.distance(to: army.coordinate)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestArmy = army
            }
        }

        return nearestArmy
    }

    /// Get all enemy armies within a range of a coordinate for a player
    func getEnemyArmies(near coordinate: HexCoordinate, range: Int, forPlayer playerID: UUID) -> [ArmyData] {
        var enemyArmies: [ArmyData] = []

        for army in armies.values {
            guard let armyOwnerID = army.ownerID, armyOwnerID != playerID else { continue }

            let status = getDiplomacyStatus(playerID: playerID, otherPlayerID: armyOwnerID)
            guard status == .enemy else { continue }

            if army.coordinate.distance(to: coordinate) <= range {
                enemyArmies.append(army)
            }
        }

        return enemyArmies
    }

    /// Get undefended buildings (not protected by defensive structures) for a player
    func getUndefendedBuildings(forPlayer playerID: UUID) -> [BuildingData] {
        return getBuildingsForPlayer(id: playerID).filter { building in
            !isBuildingProtected(building.id) && building.isOperational
        }
    }

    /// Calculate threat level at a coordinate for a player (0.0 = no threat, 1.0+ = high threat)
    func getThreatLevel(at coordinate: HexCoordinate, forPlayer playerID: UUID, sightRange: Int = 10) -> Double {
        var threatLevel = 0.0

        // Get nearby enemy armies
        let nearbyEnemies = getEnemyArmies(near: coordinate, range: sightRange, forPlayer: playerID)

        for enemy in nearbyEnemies {
            let distance = max(1, coordinate.distance(to: enemy.coordinate))
            let armyStrength = Double(enemy.getTotalUnits())

            // Closer armies contribute more to threat
            threatLevel += armyStrength / Double(distance)
        }

        return threatLevel
    }

    /// Get the total military strength of a player
    func getMilitaryStrength(forPlayer playerID: UUID) -> Int {
        var strength = 0

        // Count army units
        for army in getArmiesForPlayer(id: playerID) {
            strength += army.getTotalUnits()
        }

        // Count garrisoned units
        for building in getBuildingsForPlayer(id: playerID) {
            strength += building.getTotalGarrisonedUnits()
        }

        return strength
    }

    /// Get the total villager count for a player
    func getVillagerCount(forPlayer playerID: UUID) -> Int {
        var count = 0

        for group in getVillagerGroupsForPlayer(id: playerID) {
            count += group.villagerCount
        }

        // Also count garrisoned villagers
        for building in getBuildingsForPlayer(id: playerID) {
            count += building.villagerGarrison
        }

        return count
    }

    /// Get all enemy buildings visible to a player
    func getVisibleEnemyBuildings(forPlayer playerID: UUID) -> [BuildingData] {
        guard let player = getPlayer(id: playerID) else { return [] }

        var enemyBuildings: [BuildingData] = []

        for building in buildings.values {
            guard let ownerID = building.ownerID, ownerID != playerID else { continue }

            let status = getDiplomacyStatus(playerID: playerID, otherPlayerID: ownerID)
            guard status == .enemy else { continue }

            // Check if any of the building's coordinates are visible
            let isVisible = building.occupiedCoordinates.contains { coord in
                player.isVisible(coord)
            }

            if isVisible {
                enemyBuildings.append(building)
            }
        }

        return enemyBuildings
    }

    /// Get the city center for a player
    func getCityCenter(forPlayer playerID: UUID) -> BuildingData? {
        return getBuildingsForPlayer(id: playerID).first {
            $0.buildingType == .cityCenter && $0.isOperational
        }
    }

    /// Get available resource points near a coordinate that don't have camps built on them
    func getAvailableResourcePoints(near coordinate: HexCoordinate, range: Int, forPlayer playerID: UUID) -> [ResourcePointData] {
        return resourcePoints.values.filter { resourcePoint in
            guard resourcePoint.coordinate.distance(to: coordinate) <= range else { return false }
            guard resourcePoint.remainingAmount > 0 else { return false }

            // Check if there's already a camp built here
            if let buildingID = mapData.getBuildingID(at: resourcePoint.coordinate),
               let building = getBuilding(id: buildingID),
               building.ownerID == playerID {
                return false  // Already have a camp here
            }

            return true
        }
    }

    /// Check if a coordinate has a building of a specific type for a player
    func hasBuilding(ofType type: BuildingType, at coordinate: HexCoordinate, forPlayer playerID: UUID) -> Bool {
        guard let buildingID = mapData.getBuildingID(at: coordinate),
              let building = getBuilding(id: buildingID) else { return false }
        return building.buildingType == type && building.ownerID == playerID
    }

    /// Get count of buildings of a specific type for a player
    func getBuildingCount(ofType type: BuildingType, forPlayer playerID: UUID) -> Int {
        return getBuildingsForPlayer(id: playerID).filter {
            $0.buildingType == type && $0.isOperational
        }.count
    }

    /// Find a good location to build near a target coordinate
    func findBuildLocation(near target: HexCoordinate, maxDistance: Int = 5, forPlayer playerID: UUID) -> HexCoordinate? {
        // Try the target first
        if canBuildAt(target, forPlayer: playerID) {
            return target
        }

        // Search in expanding rings
        for distance in 1...maxDistance {
            let candidates = target.coordinatesInRing(distance: distance)
            let validCandidates = candidates.filter { canBuildAt($0, forPlayer: playerID) }

            if !validCandidates.isEmpty {
                // Return the closest valid candidate to target
                return validCandidates.min(by: { $0.distance(to: target) < $1.distance(to: target) })
            }
        }

        return nil
    }

    /// Check if a coordinate is valid for building placement
    func canBuildAt(_ coordinate: HexCoordinate, forPlayer playerID: UUID) -> Bool {
        // Must be valid coordinate
        guard mapData.isValidCoordinate(coordinate) else { return false }

        // Must be walkable terrain
        guard mapData.isWalkable(coordinate) else { return false }

        // Must not have existing building
        guard mapData.getBuildingID(at: coordinate) == nil else { return false }

        // Must not have army or villager group
        guard mapData.getArmyID(at: coordinate) == nil else { return false }
        guard mapData.getVillagerGroupID(at: coordinate) == nil else { return false }

        return true
    }

    // MARK: - AI Composition Analysis

    /// Analyze enemy army composition for counter-unit decisions
    /// Returns nil if no enemy armies are visible
    func analyzeEnemyComposition(forPlayer playerID: UUID) -> (cavalryRatio: Double, rangedRatio: Double, infantryRatio: Double, siegeRatio: Double, totalStrength: Int, weightedStrength: Double)? {
        var totalCavalry = 0
        var totalRanged = 0
        var totalInfantry = 0
        var totalSiege = 0
        var totalWeightedStrength = 0.0

        // Get all enemy armies
        for army in armies.values {
            guard let armyOwnerID = army.ownerID, armyOwnerID != playerID else { continue }

            let status = getDiplomacyStatus(playerID: playerID, otherPlayerID: armyOwnerID)
            guard status == .enemy else { continue }

            totalCavalry += army.getUnitCountByCategory(.cavalry)
            totalRanged += army.getUnitCountByCategory(.ranged)
            totalInfantry += army.getUnitCountByCategory(.infantry)
            totalSiege += army.getUnitCountByCategory(.siege)
            totalWeightedStrength += army.getWeightedStrength()
        }

        // Also count garrisoned units in enemy buildings
        for building in buildings.values {
            guard let ownerID = building.ownerID, ownerID != playerID else { continue }

            let status = getDiplomacyStatus(playerID: playerID, otherPlayerID: ownerID)
            guard status == .enemy else { continue }

            for (unitType, count) in building.garrison {
                if let dataType = MilitaryUnitTypeData(rawValue: unitType.rawValue) {
                    switch dataType.category {
                    case .cavalry: totalCavalry += count
                    case .ranged: totalRanged += count
                    case .infantry: totalInfantry += count
                    case .siege: totalSiege += count
                    }
                }
            }
        }

        let totalUnits = totalCavalry + totalRanged + totalInfantry + totalSiege
        guard totalUnits > 0 else { return nil }

        let total = Double(totalUnits)
        return (
            cavalryRatio: Double(totalCavalry) / total,
            rangedRatio: Double(totalRanged) / total,
            infantryRatio: Double(totalInfantry) / total,
            siegeRatio: Double(totalSiege) / total,
            totalStrength: totalUnits,
            weightedStrength: totalWeightedStrength
        )
    }

    /// Get the weighted military strength of a player (accounts for unit quality)
    func getWeightedMilitaryStrength(forPlayer playerID: UUID) -> Double {
        var strength = 0.0

        // Count army units
        for army in getArmiesForPlayer(id: playerID) {
            strength += army.getWeightedStrength()
        }

        // Count garrisoned units
        for building in getBuildingsForPlayer(id: playerID) {
            for (unitType, count) in building.garrison {
                if let dataType = MilitaryUnitTypeData(rawValue: unitType.rawValue) {
                    let hp = dataType.hp
                    let damage = dataType.combatStats.totalDamage
                    strength += Double(count) * (hp * (1.0 + damage * 0.1))
                }
            }
        }

        return strength
    }

    /// Get health percentage of an army (current HP / max HP)
    /// This requires tracking individual unit health, which we approximate from unit counts
    func getArmyHealthPercentage(_ armyID: UUID) -> Double {
        guard let army = armies[armyID] else { return 0.0 }

        // If army has no units, it's at 0% health
        guard army.getTotalUnits() > 0 else { return 0.0 }

        // Calculate max HP if army was at full strength
        let maxHP = army.getTotalHP()

        // For now, we assume full health since we don't track individual unit HP
        // In the future, this could track actual unit damage
        // Return a simple approximation based on unit count vs expected
        return min(1.0, maxHP > 0 ? 1.0 : 0.0)
    }

    /// Check if an army is locally outnumbered (enemies within 3 hexes have more strength)
    func isArmyLocallyOutnumbered(_ army: ArmyData, forPlayer playerID: UUID) -> Bool {
        let armyStrength = army.getWeightedStrength()
        let nearbyEnemies = getEnemyArmies(near: army.coordinate, range: 3, forPlayer: playerID)

        var enemyStrength = 0.0
        for enemy in nearbyEnemies {
            enemyStrength += enemy.getWeightedStrength()
        }

        // Outnumbered if enemy strength is 1.5x or more
        return enemyStrength > armyStrength * 1.5
    }

    // MARK: - Food Consumption

    /// Calculate food consumption rate per second for a player based on population
    /// Returns (civilianPopulation, militaryPopulation, totalConsumptionRate)
    func getFoodConsumptionRate(forPlayer playerID: UUID) -> (civilian: Int, military: Int, rate: Double) {
        var civilianCount = 0
        var militaryCount = 0

        // Count villagers in groups
        for group in getVillagerGroupsForPlayer(id: playerID) {
            civilianCount += group.villagerCount
        }

        // Count military units in armies
        for army in getArmiesForPlayer(id: playerID) {
            militaryCount += army.getTotalUnits()
        }

        // Count garrisoned units
        for building in getBuildingsForPlayer(id: playerID) {
            if building.isOperational {
                civilianCount += building.villagerGarrison
                militaryCount += building.getTotalGarrisonedUnits()

                // Count units in training queues
                for entry in building.trainingQueue {
                    militaryCount += entry.quantity
                }
                for entry in building.villagerTrainingQueue {
                    civilianCount += entry.quantity
                }
            }
        }

        // Base consumption rate: 0.1 food per pop per second
        let baseRate = 0.1
        let civilianRate = Double(civilianCount) * baseRate
        let militaryRate = Double(militaryCount) * baseRate

        // Note: Research multipliers would be applied here if AI had access to ResearchManager
        // For now, use base rates
        let totalRate = civilianRate + militaryRate

        return (civilian: civilianCount, military: militaryCount, rate: totalRate)
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
