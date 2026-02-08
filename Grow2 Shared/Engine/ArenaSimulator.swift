// ============================================================================
// FILE: ArenaSimulator.swift
// PURPOSE: Headless batch combat simulation for arena scenarios
// ============================================================================

import Foundation

class ArenaSimulator {

    // MARK: - Result Types

    struct SimulationResult {
        let winner: SimWinner
        let attackerCasualties: [String: Int]   // unitType.rawValue -> count killed
        let defenderCasualties: [String: Int]
        let attackerRemaining: [String: Int]
        let defenderRemaining: [String: Int]
        let combatDuration: TimeInterval
        let attackerInitial: [String: Int]
        let defenderInitial: [String: Int]
    }

    enum SimWinner: String {
        case attacker
        case defender
        case draw
    }

    // MARK: - Batch Simulation

    /// Run N headless combat simulations with the given configuration
    static func runBatch(
        armyConfig: ArenaArmyConfiguration,
        scenarioConfig: ArenaScenarioConfig,
        runs: Int,
        completion: @escaping ([SimulationResult]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [SimulationResult] = []
            for _ in 0..<runs {
                let result = runSingleSimulation(armyConfig: armyConfig, scenarioConfig: scenarioConfig)
                results.append(result)
            }
            completion(results)
        }
    }

    // MARK: - Single Headless Simulation

    private static func runSingleSimulation(
        armyConfig: ArenaArmyConfiguration,
        scenarioConfig: ArenaScenarioConfig
    ) -> SimulationResult {

        // Create fresh game state for this simulation
        let simState = GameState(mapWidth: 7, mapHeight: 7)

        // Set up terrain in mapData
        for r in 0..<7 {
            for q in 0..<7 {
                let coord = HexCoordinate(q: q, r: r)
                simState.mapData.setTile(TileData(coordinate: coord, terrain: .plains, elevation: 0))
            }
        }

        let enemyPos = HexCoordinate(q: 4, r: 3)
        let playerPos = HexCoordinate(q: 2, r: 3)
        let elevation = scenarioConfig.enemyTerrain == .hill ? 1 : (scenarioConfig.enemyTerrain == .mountain ? 2 : 0)
        simState.mapData.setTile(TileData(coordinate: enemyPos, terrain: scenarioConfig.enemyTerrain, elevation: elevation))

        // Create player states
        let attackerPlayerID = UUID()
        let defenderPlayerID = UUID()
        let attackerPS = PlayerState(id: attackerPlayerID, name: "Attacker", colorHex: "#0000FF", isAI: false)
        let defenderPS = PlayerState(id: defenderPlayerID, name: "Defender", colorHex: "#FF0000", isAI: true)
        simState.addPlayer(attackerPS)
        simState.addPlayer(defenderPS)

        // Set diplomacy
        attackerPS.setDiplomacyStatus(with: defenderPlayerID, status: .enemy)
        defenderPS.setDiplomacyStatus(with: attackerPlayerID, status: .enemy)

        // Apply per-unit tier upgrades to attacker
        for (unitType, tier) in scenarioConfig.playerUnitTiers where tier > 0 {
            let upgrades = UnitUpgradeType.upgradesForUnit(unitType).sorted { $0.tier < $1.tier }
            for upgrade in upgrades where upgrade.tier <= tier {
                attackerPS.completeUnitUpgrade(upgrade.rawValue)
            }
        }

        // Apply per-unit tier upgrades to defender
        for (unitType, tier) in scenarioConfig.enemyUnitTiers where tier > 0 {
            let upgrades = UnitUpgradeType.upgradesForUnit(unitType).sorted { $0.tier < $1.tier }
            for upgrade in upgrades where upgrade.tier <= tier {
                defenderPS.completeUnitUpgrade(upgrade.rawValue)
            }
        }

        // Create attacker army
        let attackerArmy = ArmyData(name: "Attacker Army", coordinate: playerPos, ownerID: attackerPlayerID)
        let attackerCommander = CommanderData(name: "Attacker Cmdr", specialty: .infantryAggressive, ownerID: attackerPlayerID)
        attackerArmy.commanderID = attackerCommander.id
        for (unitType, count) in armyConfig.playerArmy where count > 0 {
            attackerArmy.addMilitaryUnits(unitType, count: count)
        }
        simState.addArmy(attackerArmy)

        // Create defender army
        let defenderArmy = ArmyData(name: "Defender Army", coordinate: enemyPos, ownerID: defenderPlayerID)
        let defenderCommander = CommanderData(name: "Defender Cmdr", specialty: scenarioConfig.enemyCommanderSpecialty, ownerID: defenderPlayerID)
        defenderArmy.commanderID = defenderCommander.id
        for (unitType, count) in armyConfig.enemyArmy where count > 0 {
            defenderArmy.addMilitaryUnits(unitType, count: count)
        }
        if scenarioConfig.enemyEntrenched {
            defenderArmy.isEntrenched = true
        }
        simState.addArmy(defenderArmy)

        // Store initial compositions
        let attackerInitial = compositionToDict(attackerArmy.militaryComposition)
        var totalDefenderInitial = compositionToDict(defenderArmy.militaryComposition)

        // Create extra defender armies if stacking
        var extraDefenderArmies: [ArmyData] = []
        let extraCount = abs(scenarioConfig.enemyArmyCount) - 1
        let isStacked = scenarioConfig.enemyArmyCount > 1
        let isAdjacent = scenarioConfig.enemyArmyCount < -1

        if isStacked || isAdjacent {
            let adjacentHexes = enemyPos.neighbors()
            for i in 0..<extraCount {
                let coord = isStacked ? enemyPos : (i < adjacentHexes.count ? adjacentHexes[i] : enemyPos)
                let army = ArmyData(name: "Defender Army \(i + 2)", coordinate: coord, ownerID: defenderPlayerID)
                let cmd = CommanderData(name: "Defender Cmdr \(i + 2)", specialty: scenarioConfig.enemyCommanderSpecialty, ownerID: defenderPlayerID)
                army.commanderID = cmd.id
                for (unitType, count) in armyConfig.enemyArmy where count > 0 {
                    army.addMilitaryUnits(unitType, count: count)
                }
                if scenarioConfig.enemyEntrenched { army.isEntrenched = true }
                simState.addArmy(army)
                extraDefenderArmies.append(army)
                for (unitType, count) in armyConfig.enemyArmy where count > 0 {
                    totalDefenderInitial[unitType.rawValue, default: 0] += count
                }
            }
        }

        // Place building + garrison if configured
        if let buildingType = scenarioConfig.enemyBuilding {
            let buildingData = BuildingData(buildingType: buildingType, coordinate: enemyPos, ownerID: defenderPlayerID)
            buildingData.state = .completed
            if scenarioConfig.garrisonArchers > 0 {
                buildingData.addToGarrison(unitType: .archer, quantity: scenarioConfig.garrisonArchers)
            }
            simState.addBuilding(buildingData)
        }

        // Create a fresh CombatEngine and wire it to our sim state
        let simCombatEngine = CombatEngine()
        simCombatEngine.setup(gameState: simState)

        // Start combat
        let startTime: TimeInterval = 100.0
        simState.currentTime = startTime

        // Determine if we need stack combat
        let needsStackCombat = !extraDefenderArmies.isEmpty || scenarioConfig.enemyEntrenched
        if needsStackCombat {
            _ = simCombatEngine.startStackCombat(
                attackerArmyIDs: [attackerArmy.id],
                at: enemyPos,
                currentTime: startTime
            )
        } else {
            _ = simCombatEngine.startCombat(
                attackerArmyID: attackerArmy.id,
                defenderArmyID: defenderArmy.id,
                currentTime: startTime
            )
        }

        // Tick until combat ends (max 300s simulated time to prevent infinite loop)
        let tickInterval: TimeInterval = 0.5
        var simTime = startTime
        let maxSimTime = startTime + 300.0

        while simTime < maxSimTime {
            simTime += tickInterval
            simState.currentTime = simTime
            _ = simCombatEngine.update(currentTime: simTime)

            // Check if all combats are done
            if simCombatEngine.activeCombats.isEmpty && simCombatEngine.stackCombats.isEmpty {
                break
            }
        }

        // Collect results
        let duration = simTime - startTime

        // Get final compositions
        let attackerFinal = compositionToDict(attackerArmy.militaryComposition)
        var defenderFinalComp = defenderArmy.militaryComposition
        for extraArmy in extraDefenderArmies {
            for (type, count) in extraArmy.militaryComposition {
                defenderFinalComp[type, default: 0] += count
            }
        }
        let defenderFinal = compositionToDict(defenderFinalComp)

        // Calculate casualties
        var attackerCasualties: [String: Int] = [:]
        for (key, initialCount) in attackerInitial {
            attackerCasualties[key] = max(0, initialCount - (attackerFinal[key] ?? 0))
        }

        var defenderCasualties: [String: Int] = [:]
        for (key, initialCount) in totalDefenderInitial {
            defenderCasualties[key] = max(0, initialCount - (defenderFinal[key] ?? 0))
        }

        // Determine winner
        let attackerAlive = attackerFinal.values.reduce(0, +)
        let defenderAlive = defenderFinal.values.reduce(0, +)
        let winner: SimWinner
        if attackerAlive > 0 && defenderAlive == 0 {
            winner = .attacker
        } else if defenderAlive > 0 && attackerAlive == 0 {
            winner = .defender
        } else {
            winner = .draw
        }

        return SimulationResult(
            winner: winner,
            attackerCasualties: attackerCasualties,
            defenderCasualties: defenderCasualties,
            attackerRemaining: attackerFinal,
            defenderRemaining: defenderFinal,
            combatDuration: duration,
            attackerInitial: attackerInitial,
            defenderInitial: totalDefenderInitial
        )
    }

    // MARK: - Helpers

    private static func compositionToDict(_ composition: [MilitaryUnitTypeData: Int]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (type, count) in composition {
            result[type.rawValue] = count
        }
        return result
    }
}
