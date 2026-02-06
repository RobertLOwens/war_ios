// ============================================================================
// FILE: Grow2 Shared/Engine/AIMilitaryPlanner.swift
// PURPOSE: AI military planning - unit training, army deployment, attack
//          coordination, defense interception, retreat, and target scoring
// ============================================================================

import Foundation

/// Handles AI military decisions: training, deployment, attack, defense, and retreat
struct AIMilitaryPlanner {

    // MARK: - Configuration

    private let trainInterval = GameConfig.AI.Intervals.militaryTrain

    // MARK: - Military Training Commands

    func generateMilitaryCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard currentTime - aiState.lastTrainTime >= trainInterval else { return [] }

        let militaryBuildingTypes: Set<BuildingType> = [.barracks, .archeryRange, .stable, .siegeWorkshop]
        let militaryBuildings = gameState.getBuildingsForPlayer(id: playerID).filter {
            militaryBuildingTypes.contains($0.buildingType) && $0.isOperational && $0.trainingQueue.isEmpty
        }

        var trainedThisCycle = false
        for building in militaryBuildings {
            if let command = tryTrainMilitary(playerID: playerID, buildingID: building.id, gameState: gameState) {
                commands.append(command)
                trainedThisCycle = true
            }
        }

        if trainedThisCycle {
            aiState.lastTrainTime = currentTime
        }

        if let command = tryDeployArmy(playerID: playerID, gameState: gameState) {
            commands.append(command)
        }

        return commands
    }

    private func tryTrainMilitary(playerID: UUID, buildingID: UUID, gameState: GameState) -> EngineCommand? {
        guard let building = gameState.getBuilding(id: buildingID) else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        let aiState = AIController.shared.aiPlayers[playerID]
        let enemyAnalysis = aiState?.lastEnemyAnalysis ?? {
            if let analysis = gameState.analyzeEnemyComposition(forPlayer: playerID) {
                return EnemyCompositionAnalysis(
                    cavalryRatio: analysis.cavalryRatio,
                    rangedRatio: analysis.rangedRatio,
                    infantryRatio: analysis.infantryRatio,
                    siegeRatio: analysis.siegeRatio,
                    totalStrength: analysis.totalStrength,
                    weightedStrength: analysis.weightedStrength
                )
            }
            return nil
        }()

        let unitType: MilitaryUnitType

        switch building.buildingType {
        case .barracks:
            if let analysis = enemyAnalysis, analysis.cavalryRatio > 0.35 {
                unitType = .pikeman
                debugLog("🤖 AI training pikemen to counter enemy cavalry (\(Int(analysis.cavalryRatio * 100))%)")
            } else {
                unitType = .swordsman
            }

        case .archeryRange:
            if let analysis = enemyAnalysis, analysis.infantryRatio > 0.4 {
                unitType = .crossbow
                debugLog("🤖 AI training crossbows to counter enemy infantry (\(Int(analysis.infantryRatio * 100))%)")
            } else {
                unitType = .archer
            }

        case .stable:
            if let analysis = enemyAnalysis, analysis.rangedRatio > 0.4 {
                unitType = .knight
                debugLog("🤖 AI training knights to counter enemy ranged (\(Int(analysis.rangedRatio * 100))%)")
            } else {
                unitType = .scout
            }

        case .siegeWorkshop:
            unitType = .mangonel

        default:
            return nil
        }

        for (resource, amount) in unitType.trainingCost {
            guard player.hasResource(resource, amount: amount) else { return nil }
        }

        return AITrainMilitaryCommand(playerID: playerID, buildingID: buildingID, unitType: unitType, quantity: 1)
    }

    private func tryDeployArmy(playerID: UUID, gameState: GameState) -> EngineCommand? {
        let buildings = gameState.getBuildingsForPlayer(id: playerID).filter {
            $0.isOperational && $0.getTotalGarrisonedUnits() >= 5
        }

        guard let building = buildings.first else { return nil }

        var composition: [MilitaryUnitType: Int] = [:]
        for (unitType, count) in building.garrison {
            if count > 0 {
                composition[unitType] = count
            }
        }

        guard !composition.isEmpty else { return nil }

        return AIDeployArmyCommand(playerID: playerID, buildingID: building.id, composition: composition)
    }

    // MARK: - Defense Commands

    func generateDefenseCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        let nearbyEnemies = gameState.getEnemyArmies(near: cityCenter.coordinate, range: 5, forPlayer: playerID)
        guard let nearestEnemy = nearbyEnemies.first else { return [] }

        for army in gameState.getArmiesForPlayer(id: playerID) {
            guard !army.isInCombat && army.currentPath == nil else { continue }

            let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: nearestEnemy.coordinate, isArmy: true)
            commands.append(command)
        }

        return commands
    }

    // MARK: - Attack Commands

    func generateAttackCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        let idleArmies = gameState.getArmiesForPlayer(id: playerID).filter {
            !$0.isInCombat && $0.currentPath == nil
        }

        guard !idleArmies.isEmpty else { return [] }

        // Check if persistent target still exists
        var targetCoordinate: HexCoordinate?
        var currentTargetID: UUID?

        if let persistentTargetID = aiState.persistentAttackTargetID {
            if let targetArmy = gameState.getArmy(id: persistentTargetID), targetArmy.getTotalUnits() > 0 {
                targetCoordinate = targetArmy.coordinate
                currentTargetID = persistentTargetID
            } else if let targetBuilding = gameState.getBuilding(id: persistentTargetID), targetBuilding.state != .destroyed {
                targetCoordinate = targetBuilding.coordinate
                currentTargetID = persistentTargetID
            } else {
                aiState.persistentAttackTargetID = nil
            }
        }

        // If no persistent target, find a new one using scoring
        if targetCoordinate == nil {
            let targets = scoreAllTargets(forPlayer: playerID, gameState: gameState, from: cityCenter.coordinate)
            if let bestTarget = targets.first {
                targetCoordinate = bestTarget.coordinate
                currentTargetID = bestTarget.targetID
                aiState.persistentAttackTargetID = bestTarget.targetID
            }
        }

        guard let target = targetCoordinate else { return [] }

        // Army coordination for hard difficulty
        if aiState.difficulty.coordinatesArmies && idleArmies.count > 1 {
            if shouldWaitForConvergence(armies: idleArmies, target: target) {
                let rallyPoint = calculateRallyPoint(armies: idleArmies, target: target)
                aiState.pendingArmyConvergence = rallyPoint

                for army in idleArmies {
                    if army.coordinate.distance(to: rallyPoint) > 2 {
                        let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: rallyPoint, isArmy: true)
                        commands.append(command)
                    }
                }

                let allConverged = idleArmies.allSatisfy { $0.coordinate.distance(to: rallyPoint) <= 2 }
                if allConverged {
                    aiState.pendingArmyConvergence = nil
                    for army in idleArmies {
                        let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: target, isArmy: true)
                        commands.append(command)
                    }
                }

                return commands
            }
        }

        for army in idleArmies {
            let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: target, isArmy: true)
            commands.append(command)
        }

        aiState.lastAttackTarget = target
        return commands
    }

    // MARK: - Target Scoring

    func scoreAllTargets(forPlayer playerID: UUID, gameState: GameState, from coordinate: HexCoordinate) -> [TargetScore] {
        var scores: [TargetScore] = []

        for army in gameState.armies.values {
            guard let armyOwnerID = army.ownerID, armyOwnerID != playerID else { continue }

            let status = gameState.getDiplomacyStatus(playerID: playerID, otherPlayerID: armyOwnerID)
            guard status == .enemy else { continue }

            let distance = max(1, coordinate.distance(to: army.coordinate))
            let strength = army.getTotalUnits()

            var score = 50.0 - Double(strength) + (20.0 / Double(distance))

            if strength < 10 {
                score += 15.0
            }

            scores.append(TargetScore(
                targetID: army.id,
                coordinate: army.coordinate,
                score: score,
                isBuilding: false
            ))
        }

        let enemyBuildings = gameState.getVisibleEnemyBuildings(forPlayer: playerID)
        for building in enemyBuildings {
            let distance = max(1, coordinate.distance(to: building.coordinate))

            var baseScore: Double
            switch building.buildingType {
            case .cityCenter:
                baseScore = 100.0
            case .castle:
                baseScore = 80.0
            case .barracks, .archeryRange, .stable:
                baseScore = 60.0
            case .siegeWorkshop:
                baseScore = 55.0
            case .woodenFort, .tower:
                baseScore = 40.0
            case .farm:
                baseScore = 20.0
            default:
                baseScore = 30.0
            }

            let garrison = building.getTotalGarrisonedUnits()
            if garrison > 0 {
                baseScore -= Double(garrison) * 2.0
            }

            let score = baseScore + (15.0 / Double(distance))

            scores.append(TargetScore(
                targetID: building.id,
                coordinate: building.coordinate,
                score: score,
                isBuilding: true
            ))
        }

        return scores.sorted { $0.score > $1.score }
    }

    // MARK: - Army Coordination

    private func shouldWaitForConvergence(armies: [ArmyData], target: HexCoordinate) -> Bool {
        guard armies.count >= 2 else { return false }

        var maxDistance = 0
        for i in 0..<armies.count {
            for j in (i+1)..<armies.count {
                let dist = armies[i].coordinate.distance(to: armies[j].coordinate)
                maxDistance = max(maxDistance, dist)
            }
        }

        return maxDistance > 5
    }

    private func calculateRallyPoint(armies: [ArmyData], target: HexCoordinate) -> HexCoordinate {
        guard let closestArmy = armies.min(by: {
            $0.coordinate.distance(to: target) < $1.coordinate.distance(to: target)
        }) else {
            return target
        }

        return closestArmy.coordinate
    }

    // MARK: - Retreat Commands

    func generateRetreatCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        let retreatThreshold = aiState.difficulty.retreatHealthThreshold

        for army in gameState.getArmiesForPlayer(id: playerID) {
            guard !army.isInCombat else { continue }

            let distanceFromBase = army.coordinate.distance(to: cityCenter.coordinate)
            let isLocallyOutnumbered = gameState.isArmyLocallyOutnumbered(army, forPlayer: playerID)

            var shouldRetreat = false

            if isLocallyOutnumbered && distanceFromBase > 3 {
                shouldRetreat = true
                debugLog("🤖 AI army retreating: locally outnumbered")
            }

            if army.getTotalUnits() < 5 && distanceFromBase > 3 {
                shouldRetreat = true
                debugLog("🤖 AI army retreating: few units remaining")
            }

            if aiState.currentState == .retreat && distanceFromBase > 3 {
                shouldRetreat = true
            }

            if shouldRetreat {
                aiState.persistentAttackTargetID = nil

                let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: cityCenter.coordinate, isArmy: true)
                commands.append(command)
            }
        }

        return commands
    }

    // MARK: - Enemy Analysis

    func updateEnemyAnalysis(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) {
        guard currentTime - aiState.lastEnemyAnalysisTime >= GameConfig.AI.Intervals.enemyAnalysis else { return }

        if let analysis = gameState.analyzeEnemyComposition(forPlayer: aiState.playerID) {
            aiState.lastEnemyAnalysis = EnemyCompositionAnalysis(
                cavalryRatio: analysis.cavalryRatio,
                rangedRatio: analysis.rangedRatio,
                infantryRatio: analysis.infantryRatio,
                siegeRatio: analysis.siegeRatio,
                totalStrength: analysis.totalStrength,
                weightedStrength: analysis.weightedStrength
            )
            aiState.lastEnemyAnalysisTime = currentTime
        }
    }
}
