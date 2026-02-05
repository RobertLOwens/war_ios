// ============================================================================
// FILE: Grow2 Shared/Engine/AIController.swift
// PURPOSE: AI opponent controller - hybrid state machine + utility scoring
// ============================================================================

import Foundation

// MARK: - AI State

/// High-level strategic states for the AI
enum AIState: String, Codable {
    case peace       // Build economy, expand
    case alert       // Enemy detected, train military
    case defense     // Engage attacking enemies
    case attack      // Exploit detected weakness
    case retreat     // Regroup after losses
}

// MARK: - AI Difficulty

/// AI difficulty level affects decision speed, resource bonuses, and strategy
enum AIDifficulty: String, Codable {
    case easy
    case medium
    case hard

    /// How often the AI makes decisions (in seconds)
    var decisionInterval: TimeInterval {
        switch self {
        case .easy: return 5.0    // Slower reactions
        case .medium: return 3.0
        case .hard: return 1.5    // Quick reactions
        }
    }

    /// Minimum army strength ratio needed before attacking
    var attackThreshold: Double {
        switch self {
        case .easy: return 2.0    // Needs 2x advantage
        case .medium: return 1.5
        case .hard: return 1.2    // More aggressive
        }
    }

    /// Threat level that triggers alert state
    var alertThreshold: Double {
        switch self {
        case .easy: return 30.0
        case .medium: return 20.0
        case .hard: return 10.0   // More cautious
        }
    }

    /// Health percentage at which armies should retreat
    var retreatHealthThreshold: Double {
        switch self {
        case .easy: return 0.4    // Retreat at 40% health
        case .medium: return 0.3  // Retreat at 30% health
        case .hard: return 0.2    // Retreat at 20% health (more aggressive)
        }
    }

    /// Whether this difficulty level coordinates army movements
    var coordinatesArmies: Bool {
        switch self {
        case .easy: return false
        case .medium: return false
        case .hard: return true   // Only hard difficulty coordinates
        }
    }
}

// MARK: - AI Player State

/// Tracks AI-specific state for a player
class AIPlayerState {
    let playerID: UUID
    var currentState: AIState = .peace
    var difficulty: AIDifficulty = .medium
    var lastDecisionTime: TimeInterval = 0
    var lastBuildTime: TimeInterval = 0
    var lastTrainTime: TimeInterval = 0
    var lastScoutTime: TimeInterval = 0
    var lastCampBuildTime: TimeInterval = 0

    // Research timing
    var lastResearchCheckTime: TimeInterval = 0

    // Defensive building timing
    var lastDefenseBuildTime: TimeInterval = 0
    var lastGarrisonCheckTime: TimeInterval = 0

    // Strategic memory
    var knownEnemyBases: [HexCoordinate] = []
    var lastAttackTarget: HexCoordinate?
    var consecutiveDefenses: Int = 0

    // New: Persistent target tracking - track target until destroyed
    var persistentAttackTargetID: UUID?
    var lastEnemyAnalysis: EnemyCompositionAnalysis?
    var lastEnemyAnalysisTime: TimeInterval = 0
    var pendingArmyConvergence: HexCoordinate?  // Rally point for army grouping

    init(playerID: UUID, difficulty: AIDifficulty = .medium) {
        self.playerID = playerID
        self.difficulty = difficulty
    }
}

// MARK: - Enemy Composition Analysis

/// Analysis of enemy army composition for counter-unit decisions
struct EnemyCompositionAnalysis {
    let cavalryRatio: Double
    let rangedRatio: Double
    let infantryRatio: Double
    let siegeRatio: Double
    let totalStrength: Int
    let weightedStrength: Double

    /// Returns the dominant unit category of the enemy
    var dominantCategory: UnitCategoryData? {
        let ratios: [(UnitCategoryData, Double)] = [
            (.cavalry, cavalryRatio),
            (.ranged, rangedRatio),
            (.infantry, infantryRatio),
            (.siege, siegeRatio)
        ]
        return ratios.max(by: { $0.1 < $1.1 })?.0
    }
}

// MARK: - Target Score

/// Scoring information for potential attack targets
struct TargetScore {
    let targetID: UUID
    let coordinate: HexCoordinate
    let score: Double
    let isBuilding: Bool
}

// MARK: - AI Controller

/// Main AI controller that manages AI decision-making for all AI players
class AIController {

    // MARK: - Singleton
    static let shared = AIController()

    // MARK: - State
    private(set) var aiPlayers: [UUID: AIPlayerState] = [:]
    private weak var gameState: GameState?

    // MARK: - Configuration
    private let buildInterval: TimeInterval = 2.0      // Min time between build decisions
    private let trainInterval: TimeInterval = 3.0      // Min time between train decisions
    private let scoutInterval: TimeInterval = 30.0     // Min time between scout dispatches
    private let campBuildInterval: TimeInterval = 5.0  // Min time between camp builds
    private let maxCampsPerType: Int = 3               // Max lumber camps or mining camps
    private let scoutRange: Int = 12                   // Max distance to scout from city center

    // Research configuration
    private let researchCheckInterval: TimeInterval = 5.0  // Check research every 5 seconds

    // Defensive building configuration
    private let defenseBuildInterval: TimeInterval = 10.0  // Min time between defense builds
    private let garrisonCheckInterval: TimeInterval = 5.0  // Check garrison every 5 seconds
    private let maxTowersPerAI: Int = 4                    // Max towers to build
    private let maxFortsPerAI: Int = 2                     // Max wooden forts to build
    private let minThreatForDefenseBuilding: Double = 15.0 // Threat level to trigger defense building

    private init() {}

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
        aiPlayers.removeAll()

        // Debug: Print all players and their AI status
        print("🤖 AI Controller setup - checking all players:")
        for player in gameState.players.values {
            print("   Player: \(player.name) (ID: \(player.id)) - isAI: \(player.isAI)")
        }

        // Initialize AI state for each AI player
        for player in gameState.getAIPlayers() {
            aiPlayers[player.id] = AIPlayerState(playerID: player.id)

            // Debug: Check if AI player has a city center
            if let cityCenter = gameState.getCityCenter(forPlayer: player.id) {
                print("🤖 AI Controller initialized for player: \(player.name)")
                print("   City center at: (\(cityCenter.coordinate.q), \(cityCenter.coordinate.r))")
                print("   City center state: \(cityCenter.state)")
            } else {
                print("⚠️ AI player \(player.name) has NO city center!")
                let allBuildings = gameState.getBuildingsForPlayer(id: player.id)
                print("   Buildings owned: \(allBuildings.count)")
                for building in allBuildings {
                    print("     - \(building.buildingType.displayName) at (\(building.coordinate.q), \(building.coordinate.r)), state: \(building.state)")
                }
            }

            // Debug: Check resources
            print("   Resources: food=\(player.getResource(.food)), wood=\(player.getResource(.wood)), stone=\(player.getResource(.stone)), ore=\(player.getResource(.ore))")
        }

        print("🤖 Total AI players registered: \(aiPlayers.count)")
    }

    func reset() {
        aiPlayers.removeAll()
        gameState = nil
    }

    /// Register an AI player (can be called after game start)
    func registerAIPlayer(_ playerID: UUID, difficulty: AIDifficulty = .medium) {
        aiPlayers[playerID] = AIPlayerState(playerID: playerID, difficulty: difficulty)
    }

    /// Unregister an AI player
    func unregisterAIPlayer(_ playerID: UUID) {
        aiPlayers.removeValue(forKey: playerID)
    }

    // MARK: - Main Update

    /// Process AI decisions for all AI players
    /// Called by GameEngine during update loop
    func update(currentTime: TimeInterval) -> [EngineCommand] {
        guard let state = gameState else { return [] }

        var allCommands: [EngineCommand] = []

        for (playerID, aiState) in aiPlayers {
            guard let player = state.getPlayer(id: playerID), player.isAI else { continue }

            // Check if enough time has passed since last decision
            let timeSinceLastDecision = currentTime - aiState.lastDecisionTime
            guard timeSinceLastDecision >= aiState.difficulty.decisionInterval else { continue }

            // Debug: Log decision cycle
            let cityCenter = state.getCityCenter(forPlayer: playerID)
            let villagerCount = state.getVillagerCount(forPlayer: playerID)
            let buildingCount = state.getBuildingsForPlayer(id: playerID).count
            print("🤖 AI Decision cycle: state=\(aiState.currentState), cityCenter=\(cityCenter != nil), buildings=\(buildingCount), villagers=\(villagerCount), food=\(player.getResource(.food))")

            // Update enemy analysis cache
            updateEnemyAnalysis(aiState: aiState, gameState: state, currentTime: currentTime)

            // Update AI state machine
            updateState(for: aiState, gameState: state, currentTime: currentTime)

            // Generate commands based on current state
            let commands = generateCommands(for: aiState, gameState: state, currentTime: currentTime)

            print("🤖 AI \(player.name): Generated \(commands.count) commands in state \(aiState.currentState)")

            allCommands.append(contentsOf: commands)

            aiState.lastDecisionTime = currentTime
        }

        return allCommands
    }

    // MARK: - State Machine

    private func updateState(for aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) {
        let playerID = aiState.playerID

        // Get key metrics
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else {
            // No city center - we've lost, stay in retreat
            aiState.currentState = .retreat
            return
        }

        let threatLevel = gameState.getThreatLevel(at: cityCenter.coordinate, forPlayer: playerID)
        let ourStrength = gameState.getMilitaryStrength(forPlayer: playerID)
        let ourWeightedStrength = gameState.getWeightedMilitaryStrength(forPlayer: playerID)
        let nearbyEnemies = gameState.getEnemyArmies(near: cityCenter.coordinate, range: 5, forPlayer: playerID)

        // Check for armies that need to retreat (health-based)
        let armies = gameState.getArmiesForPlayer(id: playerID)
        var armyNeedsRetreat = false
        for army in armies {
            let distanceFromBase = army.coordinate.distance(to: cityCenter.coordinate)
            let isLocallyOutnumbered = gameState.isArmyLocallyOutnumbered(army, forPlayer: playerID)

            // Retreat if locally outnumbered and far from base
            if isLocallyOutnumbered && distanceFromBase > 3 {
                armyNeedsRetreat = true
                break
            }
        }

        // State transitions
        switch aiState.currentState {
        case .peace:
            if !nearbyEnemies.isEmpty {
                aiState.currentState = .defense
                print("🤖 AI \(playerID): Peace → Defense (enemies nearby)")
            } else if threatLevel > aiState.difficulty.alertThreshold {
                aiState.currentState = .alert
                print("🤖 AI \(playerID): Peace → Alert (threat detected)")
            } else if shouldAttack(aiState: aiState, gameState: gameState, ourStrength: ourStrength) {
                aiState.currentState = .attack
                print("🤖 AI \(playerID): Peace → Attack (strong enough)")
            }

        case .alert:
            if !nearbyEnemies.isEmpty {
                aiState.currentState = .defense
                print("🤖 AI \(playerID): Alert → Defense (enemies nearby)")
            } else if threatLevel < aiState.difficulty.alertThreshold * 0.5 {
                aiState.currentState = .peace
                print("🤖 AI \(playerID): Alert → Peace (threat reduced)")
            } else if shouldAttack(aiState: aiState, gameState: gameState, ourStrength: ourStrength) {
                aiState.currentState = .attack
                print("🤖 AI \(playerID): Alert → Attack (strong enough)")
            }

        case .defense:
            if nearbyEnemies.isEmpty {
                aiState.consecutiveDefenses += 1
                if aiState.consecutiveDefenses > 3 {
                    aiState.currentState = .attack
                    aiState.consecutiveDefenses = 0
                    print("🤖 AI \(playerID): Defense → Attack (counter-attack)")
                } else {
                    aiState.currentState = .alert
                    print("🤖 AI \(playerID): Defense → Alert (enemies gone)")
                }
            } else if ourWeightedStrength < 500 || armyNeedsRetreat {
                aiState.currentState = .retreat
                print("🤖 AI \(playerID): Defense → Retreat (too weak or outnumbered)")
            }

        case .attack:
            if !nearbyEnemies.isEmpty {
                aiState.currentState = .defense
                print("🤖 AI \(playerID): Attack → Defense (base under attack)")
            } else if ourWeightedStrength < 1000 {
                aiState.currentState = .peace
                aiState.persistentAttackTargetID = nil  // Clear target when retreating
                print("🤖 AI \(playerID): Attack → Peace (army depleted)")
            } else if armyNeedsRetreat {
                aiState.currentState = .retreat
                print("🤖 AI \(playerID): Attack → Retreat (army in danger)")
            }

        case .retreat:
            if nearbyEnemies.isEmpty && ourWeightedStrength > 1500 {
                aiState.currentState = .alert
                aiState.pendingArmyConvergence = nil  // Clear rally point
                print("🤖 AI \(playerID): Retreat → Alert (regrouped)")
            }
        }
    }

    private func shouldAttack(aiState: AIPlayerState, gameState: GameState, ourStrength: Int) -> Bool {
        let playerID = aiState.playerID

        // Need minimum army (weighted strength)
        let ourWeightedStrength = gameState.getWeightedMilitaryStrength(forPlayer: playerID)
        guard ourWeightedStrength >= 2000 else { return false }

        // Find nearest enemy
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return false }

        // Analyze enemy composition for counter-advantage
        let enemyAnalysis = gameState.analyzeEnemyComposition(forPlayer: playerID)

        guard let enemyArmy = gameState.getNearestEnemyArmy(from: cityCenter.coordinate, forPlayer: playerID) else {
            // No enemy army visible - look for enemy buildings
            let enemyBuildings = gameState.getVisibleEnemyBuildings(forPlayer: playerID)
            return !enemyBuildings.isEmpty
        }

        // Compare weighted strength
        let enemyWeightedStrength = enemyArmy.getWeightedStrength()

        // Calculate composition modifier (0.5 to 1.5x based on counter-advantage)
        var compositionModifier = 1.0
        if let analysis = enemyAnalysis {
            // Update cached analysis
            aiState.lastEnemyAnalysis = EnemyCompositionAnalysis(
                cavalryRatio: analysis.cavalryRatio,
                rangedRatio: analysis.rangedRatio,
                infantryRatio: analysis.infantryRatio,
                siegeRatio: analysis.siegeRatio,
                totalStrength: analysis.totalStrength,
                weightedStrength: analysis.weightedStrength
            )

            // Check if we have counter-units
            let ourArmies = gameState.getArmiesForPlayer(id: playerID)
            var ourCavalryRatio = 0.0
            var ourRangedRatio = 0.0
            var ourInfantryRatio = 0.0
            var totalOurUnits = 0

            for army in ourArmies {
                let ratios = army.getCategoryRatios()
                let count = army.getTotalUnits()
                ourCavalryRatio += ratios.cavalry * Double(count)
                ourRangedRatio += ratios.ranged * Double(count)
                ourInfantryRatio += ratios.infantry * Double(count)
                totalOurUnits += count
            }

            if totalOurUnits > 0 {
                ourCavalryRatio /= Double(totalOurUnits)
                ourRangedRatio /= Double(totalOurUnits)
                ourInfantryRatio /= Double(totalOurUnits)

                // Pikemen (infantry) counter cavalry
                if analysis.cavalryRatio > 0.35 && ourInfantryRatio > 0.3 {
                    compositionModifier += 0.2
                }
                // Cavalry counters ranged
                if analysis.rangedRatio > 0.35 && ourCavalryRatio > 0.3 {
                    compositionModifier += 0.2
                }
                // Ranged counters infantry (at range)
                if analysis.infantryRatio > 0.4 && ourRangedRatio > 0.3 {
                    compositionModifier += 0.15
                }

                // Penalty if enemy has counters to us
                if ourCavalryRatio > 0.35 && analysis.infantryRatio > 0.3 {
                    compositionModifier -= 0.2
                }
                if ourRangedRatio > 0.35 && analysis.cavalryRatio > 0.3 {
                    compositionModifier -= 0.2
                }
            }
        }

        // Clamp modifier to reasonable range
        compositionModifier = max(0.5, min(1.5, compositionModifier))

        // Apply modifier to our effective strength
        let effectiveStrength = ourWeightedStrength * compositionModifier
        let ratio = effectiveStrength / max(1.0, enemyWeightedStrength)

        return ratio >= aiState.difficulty.attackThreshold
    }

    // MARK: - Command Generation

    private func generateCommands(for aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []

        switch aiState.currentState {
        case .peace:
            commands.append(contentsOf: generateEconomyCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateExpansionCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateResearchCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            // Light defensive building in peace time
            commands.append(contentsOf: generateDefensiveBuildingCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .alert:
            commands.append(contentsOf: generateEconomyCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateMilitaryCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateResearchCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateDefensiveBuildingCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateGarrisonCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .defense:
            commands.append(contentsOf: generateDefenseCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateMilitaryCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateResearchCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateDefensiveBuildingCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateGarrisonCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .attack:
            commands.append(contentsOf: generateAttackCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateEconomyCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateResearchCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            // Garrison home defense during attacks
            commands.append(contentsOf: generateGarrisonCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .retreat:
            commands.append(contentsOf: generateRetreatCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
        }

        return commands
    }

    // MARK: - Economy Commands

    private func generateEconomyCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard let player = gameState.getPlayer(id: playerID) else {
            return []
        }

        // Check if we need more villagers
        let villagerCount = gameState.getVillagerCount(forPlayer: playerID)
        let popStats = gameState.getPopulationStats(forPlayer: playerID)

        // Train villagers if we have capacity and need more
        if villagerCount < 20 && popStats.current < popStats.capacity {
            if let command = tryTrainVillagers(playerID: playerID, gameState: gameState, currentTime: currentTime, aiState: aiState) {
                commands.append(command)
            }
        }

        // Deploy garrisoned villagers from buildings
        if let command = tryDeployVillagers(playerID: playerID, gameState: gameState) {
            commands.append(command)
        }

        // Assign idle villagers to gather resources
        let gatherCommands = tryAssignVillagersToGather(playerID: playerID, gameState: gameState)
        commands.append(contentsOf: gatherCommands)

        // Rebalance existing villagers if resource needs have changed
        let rebalanceCommands = tryRebalanceVillagers(playerID: playerID, gameState: gameState)
        commands.append(contentsOf: rebalanceCommands)

        // Build farms if we need more food income
        let urgency = analyzeResourceNeeds(playerID: playerID, gameState: gameState)
        let foodUrgency = urgency[.food] ?? 0.0
        let foodRate = player.getCollectionRate(.food)

        // Build farm if food urgency is high or collection rate is very low
        if (foodUrgency > 0.5 || foodRate < 2.0) && currentTime - aiState.lastBuildTime >= buildInterval {
            if let command = tryBuildFarm(playerID: playerID, gameState: gameState) {
                commands.append(command)
                aiState.lastBuildTime = currentTime
            }
        }

        // Build storage if any resource is near capacity
        let shouldBuildStorage = urgency.values.contains { $0 < 0.2 }  // Some resource has low urgency = near full
        if shouldBuildStorage && currentTime - aiState.lastBuildTime >= buildInterval {
            if let command = tryBuildStorage(playerID: playerID, gameState: gameState) {
                commands.append(command)
                aiState.lastBuildTime = currentTime
            }
        }

        // Build houses if we're near population cap or proactively in peace state
        let shouldBuildHouse = popStats.current >= popStats.capacity - 5 ||
            (aiState.currentState == .peace &&
             villagerCount >= 15 &&
             popStats.current >= popStats.capacity - 10 &&
             player.getResource(.wood) > 200 &&
             player.getResource(.stone) > 150)

        if shouldBuildHouse {
            if let command = tryBuildHouse(playerID: playerID, gameState: gameState, currentTime: currentTime, aiState: aiState) {
                commands.append(command)
                aiState.lastBuildTime = currentTime
            }
        }

        return commands
    }

    private func tryTrainVillagers(playerID: UUID, gameState: GameState, currentTime: TimeInterval, aiState: AIPlayerState) -> EngineCommand? {
        guard currentTime - aiState.lastTrainTime >= trainInterval else { return nil }

        // Find a city center that can train villagers
        let cityCenters = gameState.getBuildingsForPlayer(id: playerID).filter {
            $0.buildingType == .cityCenter && $0.isOperational && $0.villagerTrainingQueue.isEmpty
        }

        guard let cityCenter = cityCenters.first else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        // Check resources (50 food per villager)
        guard player.hasResource(.food, amount: 50) else { return nil }

        aiState.lastTrainTime = currentTime
        return AITrainVillagerCommand(playerID: playerID, buildingID: cityCenter.id, quantity: 1)
    }

    private func tryBuildFarm(playerID: UUID, gameState: GameState) -> EngineCommand? {
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else {
            print("🤖 tryBuildFarm: No city center")
            return nil
        }
        guard let player = gameState.getPlayer(id: playerID) else {
            print("🤖 tryBuildFarm: No player")
            return nil
        }

        // Check resources
        let farmCost = BuildingType.farm.buildCost
        for (resource, amount) in farmCost {
            guard player.hasResource(resource, amount: amount) else {
                print("🤖 tryBuildFarm: Not enough \(resource.displayName) (need \(amount), have \(player.getResource(resource)))")
                return nil
            }
        }

        // Find a location near the city center
        guard let location = gameState.findBuildLocation(near: cityCenter.coordinate, maxDistance: 4, forPlayer: playerID) else {
            print("🤖 tryBuildFarm: No valid build location found near (\(cityCenter.coordinate.q), \(cityCenter.coordinate.r))")
            return nil
        }

        print("🤖 tryBuildFarm: Building at (\(location.q), \(location.r))")
        return AIBuildCommand(playerID: playerID, buildingType: .farm, coordinate: location, rotation: 0)
    }

    private func tryBuildHouse(playerID: UUID, gameState: GameState, currentTime: TimeInterval, aiState: AIPlayerState) -> EngineCommand? {
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        // Check resources for neighborhood
        let houseCost = BuildingType.neighborhood.buildCost
        for (resource, amount) in houseCost {
            guard player.hasResource(resource, amount: amount) else { return nil }
        }

        // Find a location near the city center
        guard let location = gameState.findBuildLocation(near: cityCenter.coordinate, maxDistance: 5, forPlayer: playerID) else {
            return nil
        }

        return AIBuildCommand(playerID: playerID, buildingType: .neighborhood, coordinate: location, rotation: 0)
    }

    private func tryBuildStorage(playerID: UUID, gameState: GameState) -> EngineCommand? {
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        // Check city center level requirement
        let ccLevel = cityCenter.level
        let currentWarehouses = gameState.getBuildingCount(ofType: .warehouse, forPlayer: playerID)
        let maxWarehouses = BuildingType.maxWarehousesAllowed(forCityCenterLevel: ccLevel)

        // Can't build more warehouses
        guard currentWarehouses < maxWarehouses else {
            return nil
        }

        // Check resources
        let warehouseCost = BuildingType.warehouse.buildCost
        for (resource, amount) in warehouseCost {
            guard player.hasResource(resource, amount: amount) else {
                return nil
            }
        }

        // Find a location near the city center
        guard let location = gameState.findBuildLocation(near: cityCenter.coordinate, maxDistance: 5, forPlayer: playerID) else {
            return nil
        }

        print("🤖 AI building warehouse at (\(location.q), \(location.r)) - storage expansion needed")
        return AIBuildCommand(playerID: playerID, buildingType: .warehouse, coordinate: location, rotation: 0)
    }

    private func tryDeployVillagers(playerID: UUID, gameState: GameState) -> EngineCommand? {
        // Find buildings with garrisoned villagers
        let buildings = gameState.getBuildingsForPlayer(id: playerID).filter {
            $0.isOperational && $0.villagerGarrison >= 3  // Deploy when we have at least 3
        }

        guard let building = buildings.first else { return nil }

        let villagersToSpawn = building.villagerGarrison

        print("🤖 AI deploying \(villagersToSpawn) villagers from \(building.buildingType.displayName)")
        return AIDeployVillagersCommand(playerID: playerID, buildingID: building.id, quantity: villagersToSpawn)
    }

    private func tryAssignVillagersToGather(playerID: UUID, gameState: GameState) -> [EngineCommand] {
        var commands: [EngineCommand] = []

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        // Find idle villager groups
        let idleVillagers = gameState.getVillagerGroupsForPlayer(id: playerID).filter { group in
            group.currentTask == .idle && group.currentPath == nil
        }

        guard !idleVillagers.isEmpty else { return [] }

        // Get dynamic resource urgency scores
        let urgency = analyzeResourceNeeds(playerID: playerID, gameState: gameState)

        // Find nearby gatherable resources sorted by urgency (only explored resources - respects fog of war)
        let exploredResources = gameState.getExploredResourcePoints(forPlayer: playerID)
        let nearbyResources = exploredResources.filter { resource in
            resource.coordinate.distance(to: cityCenter.coordinate) <= 8 &&
            resource.remainingAmount > 0 &&
            resource.resourceType.isGatherable
        }.sorted { r1, r2 in
            let u1 = urgency[r1.resourceType.resourceYield] ?? 0.0
            let u2 = urgency[r2.resourceType.resourceYield] ?? 0.0
            if abs(u1 - u2) > 0.1 {
                return u1 > u2  // Higher urgency first
            }
            // Closer resources first as tiebreaker
            return r1.coordinate.distance(to: cityCenter.coordinate) < r2.coordinate.distance(to: cityCenter.coordinate)
        }

        // Assign one villager group per resource
        var assignedResources: Set<UUID> = []
        for villagerGroup in idleVillagers {
            // Find a resource that isn't over-assigned
            for resource in nearbyResources {
                if assignedResources.contains(resource.id) { continue }

                // Check if this resource already has enough gatherers
                let existingGatherers = resource.assignedVillagerGroupIDs.count
                if existingGatherers >= 2 { continue }  // Max 2 groups per resource

                // Skip low-urgency resources if storage is nearly full
                let resourceType = resource.resourceType.resourceYield
                let resourceUrgency = urgency[resourceType] ?? 0.0
                if resourceUrgency < 0.15 {
                    continue  // Skip this resource type, storage is full or near full
                }

                commands.append(AIGatherCommand(
                    playerID: playerID,
                    villagerGroupID: villagerGroup.id,
                    resourcePointID: resource.id
                ))
                assignedResources.insert(resource.id)
                print("🤖 AI assigning villagers to gather \(resource.resourceType.displayName) (urgency: \(String(format: "%.2f", resourceUrgency)))")
                break
            }
        }

        return commands
    }

    // MARK: - Resource Analysis

    /// Analyze current resource needs and return urgency scores for each resource type
    /// Higher score = more urgent need for that resource
    private func analyzeResourceNeeds(playerID: UUID, gameState: GameState) -> [ResourceTypeData: Double] {
        var urgency: [ResourceTypeData: Double] = [:]
        guard let player = gameState.getPlayer(id: playerID) else { return urgency }

        for resourceType in ResourceTypeData.allCases {
            let current = Double(player.getResource(resourceType))
            let rate = player.getCollectionRate(resourceType)
            let capacity = Double(gameState.getStorageCapacity(forPlayer: playerID, resourceType: resourceType))

            // Base urgency: lower stock relative to capacity = higher urgency
            var score = 1.0 - (current / max(1.0, capacity))

            // Critical boost if very low (below 100)
            if current < 100 {
                score += 0.5
            }

            // Significant reduction if storage is nearly full
            if current >= capacity - 50 {
                score = 0.1
            }

            // Food bonus - food is consumed by population so always slightly more important
            if resourceType == .food {
                score *= 1.2
            }

            // Wood bonus early game - needed for most buildings
            if resourceType == .wood {
                let buildingCount = gameState.getBuildingsForPlayer(id: playerID).count
                if buildingCount < 10 {
                    score *= 1.15  // Wood more important early game
                }
            }

            // Small bonus for resources with zero collection rate (not being gathered at all)
            if rate < 0.1 && score > 0.2 {
                score += 0.1
            }

            urgency[resourceType] = max(0.0, min(2.0, score))  // Clamp to 0-2 range
        }

        return urgency
    }

    /// Attempt to rebalance villagers from over-staffed resources to under-staffed ones
    private func tryRebalanceVillagers(playerID: UUID, gameState: GameState) -> [EngineCommand] {
        var commands: [EngineCommand] = []

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        let urgency = analyzeResourceNeeds(playerID: playerID, gameState: gameState)

        // Find resource types that are over-staffed (low urgency but have gatherers)
        // and resource types that are under-staffed (high urgency but few gatherers)
        var overStaffedGroups: [(VillagerGroupData, ResourcePointData)] = []
        var underStaffedResources: [ResourcePointData] = []

        // Analyze current gathering assignments
        for group in gameState.getVillagerGroupsForPlayer(id: playerID) {
            guard case .gatheringResource(let resourcePointID) = group.currentTask else { continue }
            guard let resource = gameState.getResourcePoint(id: resourcePointID) else { continue }

            let resourceType = resource.resourceType.resourceYield
            let resourceUrgency = urgency[resourceType] ?? 0.5

            // If urgency is very low (storage nearly full) and we have 2+ gatherer groups, mark as over-staffed
            if resourceUrgency < 0.2 && resource.assignedVillagerGroupIDs.count >= 2 {
                overStaffedGroups.append((group, resource))
            }
        }

        // Find under-staffed resources (high urgency, few gatherers) - only explored resources
        let exploredResources = gameState.getExploredResourcePoints(forPlayer: playerID)
        for resource in exploredResources {
            guard resource.coordinate.distance(to: cityCenter.coordinate) <= 8 else { continue }
            guard resource.remainingAmount > 0 && resource.resourceType.isGatherable else { continue }

            let resourceType = resource.resourceType.resourceYield
            let resourceUrgency = urgency[resourceType] ?? 0.5

            // High urgency and few gatherers = under-staffed
            if resourceUrgency > 0.6 && resource.assignedVillagerGroupIDs.count < 2 {
                underStaffedResources.append(resource)
            }
        }

        // Sort under-staffed resources by urgency (highest first)
        underStaffedResources.sort { r1, r2 in
            let u1 = urgency[r1.resourceType.resourceYield] ?? 0.0
            let u2 = urgency[r2.resourceType.resourceYield] ?? 0.0
            return u1 > u2
        }

        // Reassign villagers from over-staffed to under-staffed
        for (group, _) in overStaffedGroups {
            guard let targetResource = underStaffedResources.first(where: { $0.assignedVillagerGroupIDs.count < 2 }) else {
                break  // No more under-staffed resources
            }

            commands.append(AIGatherCommand(
                playerID: playerID,
                villagerGroupID: group.id,
                resourcePointID: targetResource.id
            ))

            print("🤖 AI rebalancing: moving villagers to \(targetResource.resourceType.displayName) (urgency: \(String(format: "%.2f", urgency[targetResource.resourceType.resourceYield] ?? 0.0)))")

            // Mark this resource as having one more gatherer for subsequent iterations
            // (The actual assignment happens when the command executes)
        }

        return commands
    }

    // MARK: - Expansion Commands

    private func generateExpansionCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        // Try to build resource camps if needed
        if currentTime - aiState.lastCampBuildTime >= campBuildInterval {
            if let campCommand = tryBuildResourceCamp(aiState: aiState, gameState: gameState) {
                commands.append(campCommand)
                aiState.lastCampBuildTime = currentTime
            }
        }

        // Try to scout unexplored areas
        if currentTime - aiState.lastScoutTime >= scoutInterval {
            if let scoutCommand = tryScoutUnexploredArea(aiState: aiState, gameState: gameState) {
                commands.append(scoutCommand)
                aiState.lastScoutTime = currentTime
            }
        }

        return commands
    }

    // MARK: - Camp Building

    /// Check if a resource has camp coverage (lumber camp for trees, mining camp for ore/stone)
    private func hasResourceCampCoverage(resource: ResourcePointData, gameState: GameState, playerID: UUID) -> Bool {
        guard resource.resourceType.requiresCamp else {
            return true  // No camp required for this resource type
        }

        guard let requiredCampTypeName = resource.resourceType.requiredCampType else {
            return true
        }

        // Determine the actual BuildingType from the name
        let requiredCampType: BuildingType
        if requiredCampTypeName == "Lumber Camp" {
            requiredCampType = .lumberCamp
        } else if requiredCampTypeName == "Mining Camp" {
            requiredCampType = .miningCamp
        } else {
            return true  // Unknown camp type, assume covered
        }

        // Check the resource tile and all neighbors for the required camp
        let tilesToCheck = [resource.coordinate] + resource.coordinate.neighbors()

        for coord in tilesToCheck {
            if let building = gameState.getBuilding(at: coord),
               building.buildingType == requiredCampType,
               building.ownerID == playerID,
               building.isOperational {
                return true
            }
        }

        return false
    }

    /// Find the best resource that needs a camp built nearby
    private func findResourceNeedingCamp(aiState: AIPlayerState, gameState: GameState) -> (resource: ResourcePointData, campType: BuildingType)? {
        let playerID = aiState.playerID
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        // Get resource urgency
        let urgency = analyzeResourceNeeds(playerID: playerID, gameState: gameState)

        // Count existing camps
        let lumberCampCount = gameState.getBuildingCount(ofType: .lumberCamp, forPlayer: playerID)
        let miningCampCount = gameState.getBuildingCount(ofType: .miningCamp, forPlayer: playerID)

        // Get explored resources that need camps
        let exploredResources = gameState.getExploredResourcePoints(forPlayer: playerID)

        // Score resources by: urgency * remaining amount / distance
        var candidates: [(resource: ResourcePointData, campType: BuildingType, score: Double)] = []

        for resource in exploredResources {
            guard resource.remainingAmount > 0 else { continue }
            guard resource.resourceType.requiresCamp else { continue }
            guard !hasResourceCampCoverage(resource: resource, gameState: gameState, playerID: playerID) else { continue }

            let distance = max(1, resource.coordinate.distance(to: cityCenter.coordinate))
            guard distance <= 10 else { continue }  // Don't build camps too far away

            let resourceType = resource.resourceType.resourceYield
            let resourceUrgency = urgency[resourceType] ?? 0.5

            // Determine camp type and check limits
            let campType: BuildingType
            switch resource.resourceType {
            case .trees:
                guard lumberCampCount < maxCampsPerType else { continue }
                campType = .lumberCamp
            case .oreMine, .stoneQuarry:
                guard miningCampCount < maxCampsPerType else { continue }
                campType = .miningCamp
            default:
                continue
            }

            // Check if we can afford the camp
            let campCost = campType.buildCost
            var canAfford = true
            for (res, amount) in campCost {
                if !player.hasResource(res, amount: amount) {
                    canAfford = false
                    break
                }
            }
            guard canAfford else { continue }

            // Score: prioritize high urgency, high remaining amount, closer distance
            let score = resourceUrgency * Double(resource.remainingAmount) / (100.0 * Double(distance))
            candidates.append((resource, campType, score))
        }

        // Return highest scoring candidate
        return candidates.max(by: { $0.score < $1.score }).map { ($0.resource, $0.campType) }
    }

    /// Try to build a resource camp for a resource that needs one
    private func tryBuildResourceCamp(aiState: AIPlayerState, gameState: GameState) -> EngineCommand? {
        let playerID = aiState.playerID

        guard let (resource, campType) = findResourceNeedingCamp(aiState: aiState, gameState: gameState) else {
            return nil
        }

        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        // Check resources again (defensive)
        let campCost = campType.buildCost
        for (res, amount) in campCost {
            guard player.hasResource(res, amount: amount) else { return nil }
        }

        // Find a valid build location adjacent to the resource
        // First try the resource coordinate itself
        if gameState.canBuildAt(resource.coordinate, forPlayer: playerID) {
            print("🤖 AI building \(campType.displayName) at resource (\(resource.coordinate.q), \(resource.coordinate.r))")
            return AIBuildCommand(playerID: playerID, buildingType: campType, coordinate: resource.coordinate, rotation: 0)
        }

        // Try adjacent tiles
        for neighbor in resource.coordinate.neighbors() {
            if gameState.canBuildAt(neighbor, forPlayer: playerID) {
                print("🤖 AI building \(campType.displayName) adjacent to resource at (\(neighbor.q), \(neighbor.r))")
                return AIBuildCommand(playerID: playerID, buildingType: campType, coordinate: neighbor, rotation: 0)
            }
        }

        return nil
    }

    // MARK: - Scouting

    /// Try to send an idle unit to scout unexplored areas
    private func tryScoutUnexploredArea(aiState: AIPlayerState, gameState: GameState) -> EngineCommand? {
        let playerID = aiState.playerID

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }

        // Find nearest unexplored coordinate
        guard let scoutTarget = gameState.findNearestUnexploredCoordinate(
            from: cityCenter.coordinate,
            forPlayer: playerID,
            maxRange: scoutRange
        ) else {
            return nil  // Everything nearby is explored
        }

        // Try to find an idle army to scout (preferred - can defend itself)
        let idleArmies = gameState.getArmiesForPlayer(id: playerID).filter {
            !$0.isInCombat && $0.currentPath == nil
        }

        if let scoutArmy = idleArmies.first {
            print("🤖 AI sending army to scout (\(scoutTarget.q), \(scoutTarget.r))")
            return AIMoveCommand(playerID: playerID, entityID: scoutArmy.id, destination: scoutTarget, isArmy: true)
        }

        // Fallback: try to find idle villagers to scout (only in peace state - safer)
        if aiState.currentState == .peace {
            let idleVillagers = gameState.getVillagerGroupsForPlayer(id: playerID).filter {
                $0.currentTask == .idle && $0.currentPath == nil
            }

            if let scoutVillagers = idleVillagers.first {
                print("🤖 AI sending villagers to scout (\(scoutTarget.q), \(scoutTarget.r))")
                return AIMoveCommand(playerID: playerID, entityID: scoutVillagers.id, destination: scoutTarget, isArmy: false)
            }
        }

        return nil
    }

    // MARK: - Research Commands

    private func generateResearchCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        // Check timing
        guard currentTime - aiState.lastResearchCheckTime >= researchCheckInterval else { return [] }
        aiState.lastResearchCheckTime = currentTime

        guard let player = gameState.getPlayer(id: playerID) else { return [] }

        // Don't start new research if one is already active
        if player.isResearchActive() {
            return []
        }

        // Select the best research based on current state
        if let bestResearch = selectBestResearch(aiState: aiState, gameState: gameState) {
            // Check if we can afford it
            if canAffordResearch(bestResearch, playerID: playerID, gameState: gameState) {
                commands.append(AIStartResearchCommand(playerID: playerID, researchType: bestResearch))
                print("🤖 AI starting research: \(bestResearch.displayName)")
            }
        }

        return commands
    }

    /// Select the best research to pursue based on AI state
    private func selectBestResearch(aiState: AIPlayerState, gameState: GameState) -> ResearchType? {
        let playerID = aiState.playerID
        let availableResearch = getAvailableResearch(for: playerID, gameState: gameState)

        guard !availableResearch.isEmpty else { return nil }

        // Score each available research
        var scoredResearch: [(ResearchType, Double)] = []
        for research in availableResearch {
            let score = scoreResearch(research, aiState: aiState, gameState: gameState)
            scoredResearch.append((research, score))
        }

        // Sort by score (highest first) and return best
        scoredResearch.sort { $0.1 > $1.1 }
        return scoredResearch.first?.0
    }

    /// Score a research type based on AI state and game situation
    private func scoreResearch(_ research: ResearchType, aiState: AIPlayerState, gameState: GameState) -> Double {
        var score = 0.0

        // Base score: prefer lower tier research (cheaper, faster)
        score += Double(4 - research.tier) * 10.0

        // State-based priorities
        switch aiState.currentState {
        case .peace:
            // Prioritize economic research
            if research.category == .economic {
                score += 30.0
                // Specific economic priorities
                switch research {
                case .farmGatheringI, .farmGatheringII, .farmGatheringIII:
                    score += 15.0  // Food is important
                case .lumberCampGatheringI, .lumberCampGatheringII, .lumberCampGatheringIII:
                    score += 12.0  // Wood for buildings
                case .miningCampGatheringI, .miningCampGatheringII, .miningCampGatheringIII:
                    score += 10.0  // Stone/ore for advanced buildings
                case .populationCapacityI, .populationCapacityII, .populationCapacityIII:
                    score += 8.0   // More population capacity
                case .buildingSpeedI, .buildingSpeedII, .buildingSpeedIII:
                    score += 5.0   // Faster construction
                default:
                    break
                }
            }

        case .alert:
            // Balance between military and economy
            if research.category == .military {
                score += 25.0
                // Prioritize armor and training speed
                switch research {
                case .infantryMeleeArmorI, .infantryMeleeArmorII, .infantryMeleeArmorIII,
                     .infantryPierceArmorI, .infantryPierceArmorII, .infantryPierceArmorIII:
                    score += 10.0
                case .militaryTrainingSpeedI, .militaryTrainingSpeedII, .militaryTrainingSpeedIII:
                    score += 15.0
                default:
                    break
                }
            } else {
                score += 15.0
            }

        case .defense:
            // Prioritize defensive research
            if research.category == .military {
                score += 30.0
                switch research {
                case .fortifiedBuildingsI, .fortifiedBuildingsII, .fortifiedBuildingsIII:
                    score += 20.0  // Building HP
                case .buildingBludgeonArmorI, .buildingBludgeonArmorII, .buildingBludgeonArmorIII:
                    score += 18.0  // Resist siege
                case .infantryMeleeArmorI, .infantryMeleeArmorII, .infantryMeleeArmorIII,
                     .cavalryMeleeArmorI, .cavalryMeleeArmorII, .cavalryMeleeArmorIII:
                    score += 12.0  // Armor
                case .retreatSpeedI, .retreatSpeedII, .retreatSpeedIII:
                    score += 8.0   // Retreat speed useful in defense
                default:
                    break
                }
            }

        case .attack:
            // Prioritize offensive research
            if research.category == .military {
                score += 30.0
                switch research {
                case .infantryMeleeAttackI, .infantryMeleeAttackII, .infantryMeleeAttackIII,
                     .cavalryMeleeAttackI, .cavalryMeleeAttackII, .cavalryMeleeAttackIII:
                    score += 15.0  // Attack bonuses
                case .piercingDamageI, .piercingDamageII, .piercingDamageIII:
                    score += 12.0  // Ranged damage
                case .marchSpeedI, .marchSpeedII, .marchSpeedIII:
                    score += 10.0  // Faster movement
                case .siegeBludgeonDamageI, .siegeBludgeonDamageII, .siegeBludgeonDamageIII:
                    score += 15.0  // Building destruction
                default:
                    break
                }
            }

        case .retreat:
            // Prioritize retreat and armor research
            if research.category == .military {
                switch research {
                case .retreatSpeedI, .retreatSpeedII, .retreatSpeedIII:
                    score += 25.0
                case .infantryMeleeArmorI, .infantryMeleeArmorII, .infantryMeleeArmorIII,
                     .cavalryMeleeArmorI, .cavalryMeleeArmorII, .cavalryMeleeArmorIII:
                    score += 15.0
                default:
                    break
                }
            }
        }

        return score
    }

    /// Get all research types available to the player (prerequisites met, not already completed)
    private func getAvailableResearch(for playerID: UUID, gameState: GameState) -> [ResearchType] {
        guard let player = gameState.getPlayer(id: playerID) else { return [] }

        // Get city center level
        let ccLevel = gameState.getCityCenter(forPlayer: playerID)?.level ?? 1

        var available: [ResearchType] = []
        for research in ResearchType.allCases {
            // Skip if already completed
            if player.hasCompletedResearch(research.rawValue) {
                continue
            }

            // Check city center level requirement
            if research.cityCenterLevelRequirement > ccLevel {
                continue
            }

            // Check prerequisites
            var prereqsMet = true
            for prereq in research.prerequisites {
                if !player.hasCompletedResearch(prereq.rawValue) {
                    prereqsMet = false
                    break
                }
            }

            if prereqsMet {
                available.append(research)
            }
        }

        return available
    }

    /// Check if the AI can afford a research
    private func canAffordResearch(_ research: ResearchType, playerID: UUID, gameState: GameState) -> Bool {
        guard let player = gameState.getPlayer(id: playerID) else { return false }

        for (resourceType, amount) in research.cost {
            if !player.hasResource(resourceType, amount: amount) {
                return false
            }
        }
        return true
    }

    // MARK: - Defensive Building Commands

    private func generateDefensiveBuildingCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        // Check timing
        guard currentTime - aiState.lastDefenseBuildTime >= defenseBuildInterval else { return [] }

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }
        guard let player = gameState.getPlayer(id: playerID) else { return [] }

        // Get current threat level
        let threatLevel = gameState.getThreatLevel(at: cityCenter.coordinate, forPlayer: playerID)

        // In peace state, only build defenses if we have good resources
        let shouldBuildDefense: Bool
        if aiState.currentState == .peace {
            // Only build towers in peace if we have plenty of resources
            let hasExcessResources = player.getResource(.wood) > 500 && player.getResource(.stone) > 400
            shouldBuildDefense = hasExcessResources
        } else {
            // In other states, build defense if threat is high enough
            shouldBuildDefense = threatLevel >= minThreatForDefenseBuilding || aiState.currentState == .defense
        }

        guard shouldBuildDefense else { return [] }

        // Count existing defensive buildings
        let towerCount = gameState.getBuildingCount(ofType: .tower, forPlayer: playerID)
        let fortCount = gameState.getBuildingCount(ofType: .woodenFort, forPlayer: playerID)

        // Try to build tower first (cheaper, single tile)
        if towerCount < maxTowersPerAI {
            if let command = tryBuildDefensiveStructure(.tower, aiState: aiState, gameState: gameState) {
                commands.append(command)
                aiState.lastDefenseBuildTime = currentTime
                return commands
            }
        }

        // Try to build wooden fort (more expensive, 3-tile)
        if fortCount < maxFortsPerAI && (aiState.currentState == .defense || aiState.currentState == .alert) {
            if let command = tryBuildDefensiveStructure(.woodenFort, aiState: aiState, gameState: gameState) {
                commands.append(command)
                aiState.lastDefenseBuildTime = currentTime
                return commands
            }
        }

        return commands
    }

    /// Try to build a defensive structure
    private func tryBuildDefensiveStructure(_ buildingType: BuildingType, aiState: AIPlayerState, gameState: GameState) -> EngineCommand? {
        let playerID = aiState.playerID

        guard let player = gameState.getPlayer(id: playerID) else { return nil }
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }

        // Check city center level requirement
        let ccLevel = cityCenter.level
        guard ccLevel >= buildingType.requiredCityCenterLevel else { return nil }

        // Check resources
        let cost = buildingType.buildCost
        for (resource, amount) in cost {
            guard player.hasResource(resource, amount: amount) else { return nil }
        }

        // Find a location near the city center for defense
        let maxDistance = buildingType == .tower ? 4 : 5
        guard let location = findDefenseBuildLocation(near: cityCenter.coordinate, maxDistance: maxDistance, gameState: gameState, playerID: playerID, buildingType: buildingType) else {
            return nil
        }

        print("🤖 AI building \(buildingType.displayName) at (\(location.q), \(location.r)) for defense")
        return AIBuildCommand(playerID: playerID, buildingType: buildingType, coordinate: location, rotation: 0)
    }

    /// Find a location for a defensive building
    private func findDefenseBuildLocation(near center: HexCoordinate, maxDistance: Int, gameState: GameState, playerID: UUID, buildingType: BuildingType) -> HexCoordinate? {
        // Search in rings from closest to farthest
        for distance in 2...maxDistance {
            let ring = center.coordinatesInRing(distance: distance)
            for coord in ring.shuffled() {  // Shuffle for variety
                if buildingType.hexSize == 1 {
                    // Single-tile building
                    if gameState.canBuildAt(coord, forPlayer: playerID) {
                        return coord
                    }
                } else {
                    // Multi-tile building (like wooden fort)
                    // Check if all tiles in the building footprint are buildable
                    // For simplicity, just check the main coordinate
                    if gameState.canBuildAt(coord, forPlayer: playerID) {
                        // Additional check for multi-tile buildings
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

    private func generateGarrisonCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        // Check timing
        guard currentTime - aiState.lastGarrisonCheckTime >= garrisonCheckInterval else { return [] }
        aiState.lastGarrisonCheckTime = currentTime

        // Find defensive buildings without garrison
        let defensiveTypes: Set<BuildingType> = [.tower, .castle, .woodenFort]
        let ungarrisonedDefenses = gameState.getBuildingsForPlayer(id: playerID).filter { building in
            defensiveTypes.contains(building.buildingType) &&
            building.isOperational &&
            building.getTotalGarrisonedUnits() == 0
        }

        guard !ungarrisonedDefenses.isEmpty else { return [] }

        // Find idle armies with ranged/siege units
        let idleArmies = gameState.getArmiesForPlayer(id: playerID).filter { army in
            !army.isInCombat && army.currentPath == nil && hasGarrisonableUnits(army)
        }

        // Move armies with ranged units to defensive buildings
        var assignedBuildings: Set<UUID> = []
        for army in idleArmies {
            // Find nearest ungarrisoned defensive building
            if let targetBuilding = ungarrisonedDefenses.first(where: { !assignedBuildings.contains($0.id) }) {
                // Only garrison if army is close enough (don't pull from frontlines)
                let distance = army.coordinate.distance(to: targetBuilding.coordinate)
                if distance <= 6 {
                    commands.append(AIMoveCommand(
                        playerID: playerID,
                        entityID: army.id,
                        destination: targetBuilding.coordinate,
                        isArmy: true
                    ))
                    assignedBuildings.insert(targetBuilding.id)
                    print("🤖 AI moving army to garrison \(targetBuilding.buildingType.displayName)")
                }
            }
        }

        return commands
    }

    /// Check if an army has units suitable for garrisoning (ranged or siege)
    private func hasGarrisonableUnits(_ army: ArmyData) -> Bool {
        let garrisonableTypes: Set<MilitaryUnitTypeData> = [.archer, .crossbow, .mangonel, .trebuchet]
        for (unitType, count) in army.militaryComposition {
            if garrisonableTypes.contains(unitType) && count > 0 {
                return true
            }
        }
        return false
    }

    // MARK: - Military Commands

    private func generateMilitaryCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard currentTime - aiState.lastTrainTime >= trainInterval else { return [] }

        // Find all military production buildings
        let militaryBuildingTypes: Set<BuildingType> = [.barracks, .archeryRange, .stable, .siegeWorkshop]
        let militaryBuildings = gameState.getBuildingsForPlayer(id: playerID).filter {
            militaryBuildingTypes.contains($0.buildingType) && $0.isOperational && $0.trainingQueue.isEmpty
        }

        // Train from each available building type (prioritize based on enemy composition)
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

        // Deploy garrisoned units if we have enough
        if let command = tryDeployArmy(playerID: playerID, gameState: gameState) {
            commands.append(command)
        }

        return commands
    }

    private func tryTrainMilitary(playerID: UUID, buildingID: UUID, gameState: GameState) -> EngineCommand? {
        guard let building = gameState.getBuilding(id: buildingID) else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        // Get AI state for enemy analysis
        let aiState = aiPlayers[playerID]
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

        // Determine unit type based on building and counter-unit logic
        let unitType: MilitaryUnitType

        switch building.buildingType {
        case .barracks:
            // Counter-unit logic for barracks
            if let analysis = enemyAnalysis, analysis.cavalryRatio > 0.35 {
                // Enemy has lots of cavalry - train pikemen to counter
                unitType = .pikeman
                print("🤖 AI training pikemen to counter enemy cavalry (\(Int(analysis.cavalryRatio * 100))%)")
            } else {
                // Default to balanced swordsman
                unitType = .swordsman
            }

        case .archeryRange:
            // Counter-unit logic for archery range
            if let analysis = enemyAnalysis, analysis.infantryRatio > 0.4 {
                // Enemy has lots of infantry - crossbows are effective
                unitType = .crossbow
                print("🤖 AI training crossbows to counter enemy infantry (\(Int(analysis.infantryRatio * 100))%)")
            } else {
                // Default to archers
                unitType = .archer
            }

        case .stable:
            // Counter-unit logic for stable
            if let analysis = enemyAnalysis, analysis.rangedRatio > 0.4 {
                // Enemy has lots of ranged - knights to run them down
                unitType = .knight
                print("🤖 AI training knights to counter enemy ranged (\(Int(analysis.rangedRatio * 100))%)")
            } else {
                // Default to scouts for mobility
                unitType = .scout
            }

        case .siegeWorkshop:
            // Siege units for attacking buildings
            unitType = .mangonel

        default:
            return nil
        }

        // Check resources
        for (resource, amount) in unitType.trainingCost {
            guard player.hasResource(resource, amount: amount) else { return nil }
        }

        return AITrainMilitaryCommand(playerID: playerID, buildingID: buildingID, unitType: unitType, quantity: 1)
    }

    private func tryDeployArmy(playerID: UUID, gameState: GameState) -> EngineCommand? {
        // Find building with enough garrisoned units
        let buildings = gameState.getBuildingsForPlayer(id: playerID).filter {
            $0.isOperational && $0.getTotalGarrisonedUnits() >= 5
        }

        guard let building = buildings.first else { return nil }

        // Deploy all garrisoned units
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

    private func generateDefenseCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        // Find nearby enemies
        let nearbyEnemies = gameState.getEnemyArmies(near: cityCenter.coordinate, range: 5, forPlayer: playerID)
        guard let nearestEnemy = nearbyEnemies.first else { return [] }

        // Move our armies to intercept
        for army in gameState.getArmiesForPlayer(id: playerID) {
            // Don't move armies already in combat
            guard !army.isInCombat && army.currentPath == nil else { continue }

            // Move to attack the enemy
            let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: nearestEnemy.coordinate, isArmy: true)
            commands.append(command)
        }

        return commands
    }

    // MARK: - Attack Commands

    private func generateAttackCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
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
            // Check if target is an army that still exists
            if let targetArmy = gameState.getArmy(id: persistentTargetID), targetArmy.getTotalUnits() > 0 {
                targetCoordinate = targetArmy.coordinate
                currentTargetID = persistentTargetID
            }
            // Check if target is a building that still exists
            else if let targetBuilding = gameState.getBuilding(id: persistentTargetID), targetBuilding.state != .destroyed {
                targetCoordinate = targetBuilding.coordinate
                currentTargetID = persistentTargetID
            } else {
                // Target destroyed, clear it
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
                // Calculate rally point
                let rallyPoint = calculateRallyPoint(armies: idleArmies, target: target)
                aiState.pendingArmyConvergence = rallyPoint

                // Move all armies to rally point first
                for army in idleArmies {
                    if army.coordinate.distance(to: rallyPoint) > 2 {
                        let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: rallyPoint, isArmy: true)
                        commands.append(command)
                    }
                }

                // Check if armies have converged
                let allConverged = idleArmies.allSatisfy { $0.coordinate.distance(to: rallyPoint) <= 2 }
                if allConverged {
                    aiState.pendingArmyConvergence = nil
                    // Now attack together
                    for army in idleArmies {
                        let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: target, isArmy: true)
                        commands.append(command)
                    }
                }

                return commands
            }
        }

        // Move all idle armies toward target (no coordination)
        for army in idleArmies {
            let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: target, isArmy: true)
            commands.append(command)
        }

        aiState.lastAttackTarget = target
        return commands
    }

    // MARK: - Target Scoring

    /// Score all potential targets and return sorted by score (highest first)
    private func scoreAllTargets(forPlayer playerID: UUID, gameState: GameState, from coordinate: HexCoordinate) -> [TargetScore] {
        var scores: [TargetScore] = []

        // Score enemy armies
        for army in gameState.armies.values {
            guard let armyOwnerID = army.ownerID, armyOwnerID != playerID else { continue }

            let status = gameState.getDiplomacyStatus(playerID: playerID, otherPlayerID: armyOwnerID)
            guard status == .enemy else { continue }

            let distance = max(1, coordinate.distance(to: army.coordinate))
            let strength = army.getTotalUnits()

            // Base score: prefer weaker armies that are closer
            var score = 50.0 - Double(strength) + (20.0 / Double(distance))

            // Bonus for weakened armies (low unit count relative to typical army)
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

        // Score enemy buildings
        let enemyBuildings = gameState.getVisibleEnemyBuildings(forPlayer: playerID)
        for building in enemyBuildings {
            let distance = max(1, coordinate.distance(to: building.coordinate))

            // Strategic value based on building type
            var baseScore: Double
            switch building.buildingType {
            case .cityCenter:
                baseScore = 100.0  // Highest priority - win condition
            case .castle:
                baseScore = 80.0   // Major defensive structure
            case .barracks, .archeryRange, .stable:
                baseScore = 60.0   // Military production
            case .siegeWorkshop:
                baseScore = 55.0   // Siege production
            case .woodenFort, .tower:
                baseScore = 40.0   // Defensive structures
            case .farm:
                baseScore = 20.0   // Economy - low priority
            default:
                baseScore = 30.0   // Other buildings
            }

            // Reduce score for garrisoned buildings (harder to take)
            let garrison = building.getTotalGarrisonedUnits()
            if garrison > 0 {
                baseScore -= Double(garrison) * 2.0
            }

            // Distance penalty
            let score = baseScore + (15.0 / Double(distance))

            scores.append(TargetScore(
                targetID: building.id,
                coordinate: building.coordinate,
                score: score,
                isBuilding: true
            ))
        }

        // Sort by score (highest first)
        return scores.sorted { $0.score > $1.score }
    }

    // MARK: - Army Coordination

    /// Check if armies should wait to converge before attacking
    private func shouldWaitForConvergence(armies: [ArmyData], target: HexCoordinate) -> Bool {
        guard armies.count >= 2 else { return false }

        // Calculate spread of armies
        var maxDistance = 0
        for i in 0..<armies.count {
            for j in (i+1)..<armies.count {
                let dist = armies[i].coordinate.distance(to: armies[j].coordinate)
                maxDistance = max(maxDistance, dist)
            }
        }

        // If armies are spread more than 5 hexes apart, wait for convergence
        return maxDistance > 5
    }

    /// Calculate rally point for army convergence
    private func calculateRallyPoint(armies: [ArmyData], target: HexCoordinate) -> HexCoordinate {
        // Find the army closest to the target - others rally to it
        guard let closestArmy = armies.min(by: {
            $0.coordinate.distance(to: target) < $1.coordinate.distance(to: target)
        }) else {
            return target
        }

        return closestArmy.coordinate
    }

    // MARK: - Retreat Commands

    private func generateRetreatCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        let retreatThreshold = aiState.difficulty.retreatHealthThreshold

        // Move armies that need to retreat
        for army in gameState.getArmiesForPlayer(id: playerID) {
            guard !army.isInCombat else { continue }

            let distanceFromBase = army.coordinate.distance(to: cityCenter.coordinate)
            let isLocallyOutnumbered = gameState.isArmyLocallyOutnumbered(army, forPlayer: playerID)

            // Determine if this army should retreat
            var shouldRetreat = false

            // Retreat if locally outnumbered and not near base
            if isLocallyOutnumbered && distanceFromBase > 3 {
                shouldRetreat = true
                print("🤖 AI army retreating: locally outnumbered")
            }

            // Retreat if army is very weak (few units remaining)
            if army.getTotalUnits() < 5 && distanceFromBase > 3 {
                shouldRetreat = true
                print("🤖 AI army retreating: few units remaining")
            }

            // Always retreat if already in retreat state and not near base
            if aiState.currentState == .retreat && distanceFromBase > 3 {
                shouldRetreat = true
            }

            if shouldRetreat {
                // Clear any persistent target since we're retreating
                aiState.persistentAttackTargetID = nil

                let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: cityCenter.coordinate, isArmy: true)
                commands.append(command)
            }
        }

        return commands
    }

    // MARK: - Analysis Updates

    /// Update enemy analysis cache periodically
    private func updateEnemyAnalysis(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) {
        // Only update every 10 seconds to avoid expensive calculations
        guard currentTime - aiState.lastEnemyAnalysisTime >= 10.0 else { return }

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

// MARK: - AI Engine Commands

/// AI command for building structures
class AIBuildCommand: BaseEngineCommand {
    let buildingType: BuildingType
    let coordinate: HexCoordinate
    let rotation: Int

    init(playerID: UUID, buildingType: BuildingType, coordinate: HexCoordinate, rotation: Int) {
        self.buildingType = buildingType
        self.coordinate = coordinate
        self.rotation = rotation
        super.init(playerID: playerID)
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Check resources
        for (resource, amount) in buildingType.buildCost {
            guard player.hasResource(resource, amount: amount) else {
                return .failure(reason: "Insufficient resources")
            }
        }

        // Check location
        guard state.canBuildAt(coordinate, forPlayer: playerID) else {
            return .failure(reason: "Cannot build at this location")
        }

        return .success(changes: [])
    }

    override func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Deduct resources
        for (resource, amount) in buildingType.buildCost {
            _ = player.removeResource(resource, amount: amount)
        }

        // Create building
        let building = BuildingData(
            buildingType: buildingType,
            coordinate: coordinate,
            ownerID: playerID,
            rotation: rotation
        )
        building.startConstruction(builders: 1)

        state.addBuilding(building)

        changeBuilder.add(.buildingPlaced(
            buildingID: building.id,
            buildingType: buildingType.rawValue,
            coordinate: coordinate,
            ownerID: playerID,
            rotation: rotation
        ))
        changeBuilder.add(.buildingConstructionStarted(buildingID: building.id))

        print("🤖 AI built \(buildingType.displayName) at (\(coordinate.q), \(coordinate.r))")

        return .success(changes: changeBuilder.build().changes)
    }
}

/// AI command for training military units
class AITrainMilitaryCommand: BaseEngineCommand {
    let buildingID: UUID
    let unitType: MilitaryUnitType
    let quantity: Int

    init(playerID: UUID, buildingID: UUID, unitType: MilitaryUnitType, quantity: Int) {
        self.buildingID = buildingID
        self.unitType = unitType
        self.quantity = quantity
        super.init(playerID: playerID)
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        guard let building = state.getBuilding(id: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.ownerID == playerID else {
            return .failure(reason: "Not your building")
        }

        guard building.isOperational else {
            return .failure(reason: "Building not operational")
        }

        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        for (resource, amount) in unitType.trainingCost {
            let totalCost = amount * quantity
            guard player.hasResource(resource, amount: totalCost) else {
                return .failure(reason: "Insufficient resources")
            }
        }

        return .success(changes: [])
    }

    override func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        guard let building = state.getBuilding(id: buildingID),
              let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Not found")
        }

        // Deduct resources
        for (resource, amount) in unitType.trainingCost {
            let totalCost = amount * quantity
            _ = player.removeResource(resource, amount: totalCost)
        }

        // Start training
        building.startTraining(unitType: unitType, quantity: quantity, at: state.currentTime)

        changeBuilder.add(.trainingStarted(
            buildingID: buildingID,
            unitType: unitType.rawValue,
            quantity: quantity,
            startTime: state.currentTime
        ))

        print("🤖 AI training \(quantity)x \(unitType.displayName)")

        return .success(changes: changeBuilder.build().changes)
    }
}

/// AI command for training villagers
class AITrainVillagerCommand: BaseEngineCommand {
    let buildingID: UUID
    let quantity: Int

    init(playerID: UUID, buildingID: UUID, quantity: Int) {
        self.buildingID = buildingID
        self.quantity = quantity
        super.init(playerID: playerID)
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        guard let building = state.getBuilding(id: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.ownerID == playerID else {
            return .failure(reason: "Not your building")
        }

        guard building.canTrainVillagers() else {
            return .failure(reason: "Cannot train villagers here")
        }

        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        // 50 food per villager
        guard player.hasResource(.food, amount: 50 * quantity) else {
            return .failure(reason: "Insufficient food")
        }

        return .success(changes: [])
    }

    override func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        guard let building = state.getBuilding(id: buildingID),
              let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Not found")
        }

        // Deduct resources
        _ = player.removeResource(.food, amount: 50 * quantity)

        // Start training
        building.startVillagerTraining(quantity: quantity, at: state.currentTime)

        changeBuilder.add(.villagerTrainingStarted(
            buildingID: buildingID,
            quantity: quantity,
            startTime: state.currentTime
        ))

        print("🤖 AI training \(quantity) villagers")

        return .success(changes: changeBuilder.build().changes)
    }
}

/// AI command for deploying armies
class AIDeployArmyCommand: BaseEngineCommand {
    let buildingID: UUID
    let composition: [MilitaryUnitType: Int]

    init(playerID: UUID, buildingID: UUID, composition: [MilitaryUnitType: Int]) {
        self.buildingID = buildingID
        self.composition = composition
        super.init(playerID: playerID)
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        guard let building = state.getBuilding(id: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.ownerID == playerID else {
            return .failure(reason: "Not your building")
        }

        for (unitType, count) in composition {
            let available = building.garrison[unitType] ?? 0
            if available < count {
                return .failure(reason: "Not enough \(unitType.displayName)")
            }
        }

        return .success(changes: [])
    }

    override func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        guard let building = state.getBuilding(id: buildingID) else {
            return .failure(reason: "Building not found")
        }

        // Remove units from garrison
        for (unitType, count) in composition {
            _ = building.removeFromGarrison(unitType: unitType, quantity: count)
        }

        // Find spawn position
        let spawnCoord = state.mapData.findNearestWalkable(
            to: building.coordinate,
            maxDistance: 3,
            forPlayerID: playerID,
            gameState: state
        ) ?? building.coordinate

        // Create army
        let army = ArmyData(name: "AI Army", coordinate: spawnCoord, ownerID: playerID)
        army.homeBaseID = buildingID

        for (unitType, count) in composition {
            if let dataType = MilitaryUnitTypeData(rawValue: unitType.rawValue) {
                army.addMilitaryUnits(dataType, count: count)
            }
        }

        state.addArmy(army)

        var compositionDict: [String: Int] = [:]
        for (unitType, count) in army.militaryComposition {
            compositionDict[unitType.rawValue] = count
        }

        changeBuilder.add(.armyCreated(
            armyID: army.id,
            ownerID: playerID,
            coordinate: spawnCoord,
            composition: compositionDict
        ))

        print("🤖 AI deployed army with \(army.getTotalUnits()) units")

        return .success(changes: changeBuilder.build().changes)
    }
}

/// AI command for deploying villagers from a building's garrison
class AIDeployVillagersCommand: BaseEngineCommand {
    let buildingID: UUID
    let quantity: Int

    init(playerID: UUID, buildingID: UUID, quantity: Int) {
        self.buildingID = buildingID
        self.quantity = quantity
        super.init(playerID: playerID)
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        guard let building = state.getBuilding(id: buildingID) else {
            return .failure(reason: "Building not found")
        }

        guard building.ownerID == playerID else {
            return .failure(reason: "Not your building")
        }

        guard building.villagerGarrison >= quantity else {
            return .failure(reason: "Not enough villagers in garrison")
        }

        return .success(changes: [])
    }

    override func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        guard let building = state.getBuilding(id: buildingID) else {
            return .failure(reason: "Building not found")
        }

        // Remove villagers from garrison
        building.villagerGarrison -= quantity

        // Find spawn position near building
        let spawnCoord = state.mapData.findNearestWalkable(
            to: building.coordinate,
            maxDistance: 3,
            forPlayerID: playerID,
            gameState: state
        ) ?? building.coordinate

        // Create villager group
        let group = VillagerGroupData(
            name: "AI Villagers",
            coordinate: spawnCoord,
            villagerCount: quantity,
            ownerID: playerID
        )

        state.addVillagerGroup(group)

        changeBuilder.add(.villagerGroupCreated(
            groupID: group.id,
            ownerID: playerID,
            coordinate: spawnCoord,
            count: quantity
        ))

        changeBuilder.add(.villagersUngarrisoned(
            buildingID: buildingID,
            quantity: quantity
        ))

        print("🤖 AI deployed \(quantity) villagers at (\(spawnCoord.q), \(spawnCoord.r))")

        return .success(changes: changeBuilder.build().changes)
    }
}

/// AI command for assigning villagers to gather resources
class AIGatherCommand: BaseEngineCommand {
    let villagerGroupID: UUID
    let resourcePointID: UUID

    init(playerID: UUID, villagerGroupID: UUID, resourcePointID: UUID) {
        self.villagerGroupID = villagerGroupID
        self.resourcePointID = resourcePointID
        super.init(playerID: playerID)
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        guard let group = state.getVillagerGroup(id: villagerGroupID) else {
            return .failure(reason: "Villager group not found")
        }

        guard group.ownerID == playerID else {
            return .failure(reason: "Not your villagers")
        }

        guard let resource = state.getResourcePoint(id: resourcePointID) else {
            return .failure(reason: "Resource not found")
        }

        guard resource.remainingAmount > 0 else {
            return .failure(reason: "Resource depleted")
        }

        return .success(changes: [])
    }

    override func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        guard let group = state.getVillagerGroup(id: villagerGroupID),
              let resource = state.getResourcePoint(id: resourcePointID) else {
            return .failure(reason: "Not found")
        }

        // Set the villager task
        group.currentTask = .gatheringResource(resourcePointID: resourcePointID)
        group.taskTargetCoordinate = resource.coordinate
        group.assignedResourcePointID = resourcePointID

        // Move villagers to resource if not there
        if group.coordinate != resource.coordinate {
            if let path = state.mapData.findPath(
                from: group.coordinate,
                to: resource.coordinate,
                forPlayerID: playerID,
                gameState: state
            ) {
                group.setPath(path)
            }
        }

        // Register with resource engine
        let registered = GameEngine.shared.resourceEngine.startGathering(
            villagerGroupID: villagerGroupID,
            resourcePointID: resourcePointID
        )

        if registered {
            // Update collection rates
            GameEngine.shared.resourceEngine.updateCollectionRates(forPlayer: playerID)
        }

        changeBuilder.add(.villagerGroupTaskChanged(
            groupID: villagerGroupID,
            task: "gathering",
            targetCoordinate: resource.coordinate
        ))

        print("🤖 AI villagers assigned to gather \(resource.resourceType.displayName)")

        return .success(changes: changeBuilder.build().changes)
    }
}

/// AI command for moving units
class AIMoveCommand: BaseEngineCommand {
    let entityID: UUID
    let destination: HexCoordinate
    let isArmy: Bool

    init(playerID: UUID, entityID: UUID, destination: HexCoordinate, isArmy: Bool) {
        self.entityID = entityID
        self.destination = destination
        self.isArmy = isArmy
        super.init(playerID: playerID)
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        if isArmy {
            guard let army = state.getArmy(id: entityID) else {
                return .failure(reason: "Army not found")
            }
            guard army.ownerID == playerID else {
                return .failure(reason: "Not your army")
            }
            guard !army.isInCombat else {
                return .failure(reason: "Cannot move during combat")
            }
        } else {
            guard let group = state.getVillagerGroup(id: entityID) else {
                return .failure(reason: "Villager group not found")
            }
            guard group.ownerID == playerID else {
                return .failure(reason: "Not your villagers")
            }
        }

        guard state.mapData.isValidCoordinate(destination) else {
            return .failure(reason: "Invalid destination")
        }

        return .success(changes: [])
    }

    override func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        if isArmy {
            guard let army = state.getArmy(id: entityID) else {
                return .failure(reason: "Army not found")
            }

            guard let path = state.mapData.findPath(
                from: army.coordinate,
                to: destination,
                forPlayerID: playerID,
                gameState: state
            ) else {
                return .failure(reason: "No valid path")
            }

            army.currentPath = path
            army.pathIndex = 0
            army.movementProgress = 0.0

            changeBuilder.add(.armyMoved(
                armyID: entityID,
                from: army.coordinate,
                to: destination,
                path: path
            ))

            print("🤖 AI moving army to (\(destination.q), \(destination.r))")
        } else {
            guard let group = state.getVillagerGroup(id: entityID) else {
                return .failure(reason: "Villager group not found")
            }

            guard let path = state.mapData.findPath(
                from: group.coordinate,
                to: destination,
                forPlayerID: playerID,
                gameState: state
            ) else {
                return .failure(reason: "No valid path")
            }

            group.setPath(path)
            group.currentTask = .moving(targetCoordinate: destination)

            changeBuilder.add(.villagerGroupMoved(
                groupID: entityID,
                from: group.coordinate,
                to: destination,
                path: path
            ))
        }

        return .success(changes: changeBuilder.build().changes)
    }
}

/// AI command for starting research
class AIStartResearchCommand: BaseEngineCommand {
    let researchType: ResearchType

    init(playerID: UUID, researchType: ResearchType) {
        self.researchType = researchType
        super.init(playerID: playerID)
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Check if research is already active
        if player.isResearchActive() {
            return .failure(reason: "Research already in progress")
        }

        // Check if already completed
        if player.hasCompletedResearch(researchType.rawValue) {
            return .failure(reason: "Research already completed")
        }

        // Check prerequisites
        for prereq in researchType.prerequisites {
            if !player.hasCompletedResearch(prereq.rawValue) {
                return .failure(reason: "Prerequisites not met")
            }
        }

        // Check city center level
        let ccLevel = state.getCityCenter(forPlayer: playerID)?.level ?? 1
        if researchType.cityCenterLevelRequirement > ccLevel {
            return .failure(reason: "City Center level too low")
        }

        // Check resources
        for (resource, amount) in researchType.cost {
            if !player.hasResource(resource, amount: amount) {
                return .failure(reason: "Insufficient resources")
            }
        }

        return .success(changes: [])
    }

    override func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        // Deduct resources
        for (resource, amount) in researchType.cost {
            _ = player.removeResource(resource, amount: amount)
        }

        // Start research
        player.startResearch(researchType.rawValue, at: state.currentTime)

        changeBuilder.add(.researchStarted(
            playerID: playerID,
            researchType: researchType.rawValue,
            startTime: state.currentTime
        ))

        print("🤖 AI started research: \(researchType.displayName)")

        return .success(changes: changeBuilder.build().changes)
    }
}
