// ============================================================================
// FILE: Grow2 Shared/Data/GameStateQueries.swift
// PURPOSE: AI-specific and analysis query methods for GameState
// ============================================================================

import Foundation

// MARK: - AI Helper Queries

extension GameState {

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
}

// MARK: - Composition Analysis

extension GameState {

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
}

// MARK: - Food Consumption

extension GameState {

    /// Calculate food consumption rate per second for a player based on population
    /// Returns (civilianPopulation, militaryPopulation, totalConsumptionRate)
    func getFoodConsumptionRate(forPlayer playerID: UUID) -> (civilian: Int, military: Int, rate: Double) {
        var civilianCount = 0
        var militaryCount = 0

        // Count villagers in groups
        for group in getVillagerGroupsForPlayer(id: playerID) {
            civilianCount += group.villagerCount
        }

        // Count military units in armies (pop-space-aware)
        for army in getArmiesForPlayer(id: playerID) {
            militaryCount += army.getPopulationUsed()
        }

        // Count garrisoned units
        for building in getBuildingsForPlayer(id: playerID) {
            if building.isOperational {
                civilianCount += building.villagerGarrison
                militaryCount += building.getGarrisonPopulation()

                // Count units in training queues (pop-space-aware)
                for entry in building.trainingQueue {
                    militaryCount += entry.unitType.popSpace * entry.quantity
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
}
