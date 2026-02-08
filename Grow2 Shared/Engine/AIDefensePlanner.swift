// ============================================================================
// FILE: Grow2 Shared/Engine/AIDefensePlanner.swift
// PURPOSE: AI defensive planning - tower/fort construction and garrison management
// ============================================================================

import Foundation

/// Handles AI defensive decisions: building towers/forts and garrisoning ranged units
struct AIDefensePlanner {

    // MARK: - Configuration

    private let defenseBuildInterval = GameConfig.AI.Intervals.defenseBuild
    private let garrisonCheckInterval = GameConfig.AI.Intervals.garrisonCheck
    private let maxTowersPerAI = GameConfig.AI.Limits.maxTowersPerAI
    private let maxFortsPerAI = GameConfig.AI.Limits.maxFortsPerAI
    private let minThreatForDefenseBuilding = GameConfig.AI.Thresholds.minThreatForDefenseBuilding

    // MARK: - Defensive Building Commands

    func generateDefensiveBuildingCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard currentTime - aiState.lastDefenseBuildTime >= defenseBuildInterval else { return [] }

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }
        guard let player = gameState.getPlayer(id: playerID) else { return [] }

        let threatLevel = gameState.getThreatLevel(at: cityCenter.coordinate, forPlayer: playerID)

        let shouldBuildDefense: Bool
        if aiState.currentState == .peace {
            let hasExcessResources = player.getResource(.wood) > 500 && player.getResource(.stone) > 400
            shouldBuildDefense = hasExcessResources
        } else {
            shouldBuildDefense = threatLevel >= minThreatForDefenseBuilding || aiState.currentState == .defense
        }

        guard shouldBuildDefense else { return [] }

        let towerCount = gameState.getBuildingCount(ofType: .tower, forPlayer: playerID)
        let fortCount = gameState.getBuildingCount(ofType: .woodenFort, forPlayer: playerID)

        if towerCount < maxTowersPerAI {
            if let command = tryBuildDefensiveStructure(.tower, aiState: aiState, gameState: gameState) {
                commands.append(command)
                aiState.lastDefenseBuildTime = currentTime
                return commands
            }
        }

        if fortCount < maxFortsPerAI && (aiState.currentState == .defense || aiState.currentState == .alert) {
            if let command = tryBuildDefensiveStructure(.woodenFort, aiState: aiState, gameState: gameState) {
                commands.append(command)
                aiState.lastDefenseBuildTime = currentTime
                return commands
            }
        }

        return commands
    }

    private func tryBuildDefensiveStructure(_ buildingType: BuildingType, aiState: AIPlayerState, gameState: GameState) -> EngineCommand? {
        let playerID = aiState.playerID

        guard let player = gameState.getPlayer(id: playerID) else { return nil }
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }

        let ccLevel = cityCenter.level
        guard ccLevel >= buildingType.requiredCityCenterLevel else { return nil }

        let cost = buildingType.buildCost
        for (resource, amount) in cost {
            guard player.hasResource(resource, amount: amount) else { return nil }
        }

        let maxDistance = buildingType == .tower ? 4 : 5
        guard let location = findDefenseBuildLocation(near: cityCenter.coordinate, maxDistance: maxDistance, gameState: gameState, playerID: playerID, buildingType: buildingType) else {
            return nil
        }

        debugLog("🤖 AI building \(buildingType.displayName) at (\(location.q), \(location.r)) for defense")
        return AIBuildCommand(playerID: playerID, buildingType: buildingType, coordinate: location, rotation: 0)
    }

    private func findDefenseBuildLocation(near center: HexCoordinate, maxDistance: Int, gameState: GameState, playerID: UUID, buildingType: BuildingType) -> HexCoordinate? {
        for distance in 2...maxDistance {
            let ring = center.coordinatesInRing(distance: distance)
            for coord in ring.shuffled() {
                if buildingType.hexSize == 1 {
                    if gameState.canBuildAt(coord, forPlayer: playerID) {
                        return coord
                    }
                } else {
                    if gameState.canBuildAt(coord, forPlayer: playerID) {
                        let neighbors = coord.neighbors().prefix(buildingType.hexSize - 1)
                        let allBuildable = neighbors.allSatisfy { gameState.canBuildAt($0, forPlayer: playerID) }
                        if allBuildable {
                            return coord
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Garrison Commands

    func generateGarrisonCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard currentTime - aiState.lastGarrisonCheckTime >= garrisonCheckInterval else { return [] }
        aiState.lastGarrisonCheckTime = currentTime

        let defensiveTypes: Set<BuildingType> = [.tower, .castle, .woodenFort]
        let ungarrisonedDefenses = gameState.getBuildingsForPlayer(id: playerID).filter { building in
            defensiveTypes.contains(building.buildingType) &&
            building.isOperational &&
            building.getTotalGarrisonedUnits() == 0
        }

        guard !ungarrisonedDefenses.isEmpty else { return [] }

        let idleArmies = gameState.getArmiesForPlayer(id: playerID).filter { army in
            !army.isInCombat && army.currentPath == nil && hasGarrisonableUnits(army)
        }

        var assignedBuildings: Set<UUID> = []
        for army in idleArmies {
            if let targetBuilding = ungarrisonedDefenses.first(where: { !assignedBuildings.contains($0.id) }) {
                let distance = army.coordinate.distance(to: targetBuilding.coordinate)
                if distance <= 6 {
                    commands.append(AIMoveCommand(
                        playerID: playerID,
                        entityID: army.id,
                        destination: targetBuilding.coordinate,
                        isArmy: true
                    ))
                    assignedBuildings.insert(targetBuilding.id)
                    debugLog("🤖 AI moving army to garrison \(targetBuilding.buildingType.displayName)")
                }
            }
        }

        return commands
    }

    // MARK: - Entrenchment Commands

    func generateEntrenchmentCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        let playerID = aiState.playerID

        guard currentTime - aiState.lastEntrenchCheckTime >= GameConfig.AI.Intervals.entrenchCheck else { return [] }
        aiState.lastEntrenchCheckTime = currentTime

        guard let player = gameState.getPlayer(id: playerID) else { return [] }
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        // Only entrench if there's a threat nearby
        let threatLevel = gameState.getThreatLevel(at: cityCenter.coordinate, forPlayer: playerID)
        guard threatLevel > 0 else { return [] }

        // Need wood buffer beyond entrenchment cost
        let woodBuffer = 200
        guard player.getResource(.wood) >= GameConfig.Entrenchment.woodCost + woodBuffer else { return [] }

        // Count currently entrenched/entrenching armies (limit to 2)
        let armies = gameState.getArmiesForPlayer(id: playerID)
        let entrenchedCount = armies.filter { $0.isEntrenched || $0.isEntrenching }.count
        guard entrenchedCount < 2 else { return [] }

        // Find idle armies near city center that could entrench
        var commands: [EngineCommand] = []
        for army in armies {
            guard !army.isInCombat,
                  army.currentPath == nil,
                  !army.isRetreating,
                  !army.isEntrenched,
                  !army.isEntrenching else { continue }

            let distance = army.coordinate.distance(to: cityCenter.coordinate)
            guard distance <= 8 else { continue }

            commands.append(AIEntrenchCommand(playerID: playerID, armyID: army.id))
            debugLog("🤖 AI entrenching army \(army.name) near city center")
            break // One entrenchment command per cycle
        }

        return commands
    }

    private func hasGarrisonableUnits(_ army: ArmyData) -> Bool {
        let garrisonableTypes: Set<MilitaryUnitTypeData> = [.archer, .crossbow, .mangonel, .trebuchet]
        for (unitType, count) in army.militaryComposition {
            if garrisonableTypes.contains(unitType) && count > 0 {
                return true
            }
        }
        return false
    }
}
