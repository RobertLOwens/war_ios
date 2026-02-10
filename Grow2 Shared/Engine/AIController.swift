// ============================================================================
// FILE: Grow2 Shared/Engine/AIController.swift
// PURPOSE: AI opponent controller - orchestrates planners via state machine
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

    // Unit upgrade timing
    var lastUnitUpgradeCheckTime: TimeInterval = 0

    // Defensive building timing
    var lastDefenseBuildTime: TimeInterval = 0
    var lastGarrisonCheckTime: TimeInterval = 0
    var lastEntrenchCheckTime: TimeInterval = 0

    // Strategic memory
    var knownEnemyBases: [HexCoordinate] = []
    var lastAttackTarget: HexCoordinate?
    var consecutiveDefenses: Int = 0

    // Persistent target tracking - track target until destroyed
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

/// Main AI controller that orchestrates planners for all AI players
class AIController {

    // MARK: - Singleton
    static let shared = AIController()

    // MARK: - State
    private(set) var aiPlayers: [UUID: AIPlayerState] = [:]
    private weak var gameState: GameState?

    // MARK: - Planners
    private let economyPlanner = AIEconomyPlanner()
    private let militaryPlanner = AIMilitaryPlanner()
    private let defensePlanner = AIDefensePlanner()
    private let researchPlanner = AIResearchPlanner()

    private init() {}

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
        aiPlayers.removeAll()

        debugLog("🤖 AI Controller setup - checking all players:")
        for player in gameState.players.values {
            debugLog("   Player: \(player.name) (ID: \(player.id)) - isAI: \(player.isAI)")
        }

        for player in gameState.getAIPlayers() {
            aiPlayers[player.id] = AIPlayerState(playerID: player.id)

            if let cityCenter = gameState.getCityCenter(forPlayer: player.id) {
                debugLog("🤖 AI Controller initialized for player: \(player.name)")
                debugLog("   City center at: (\(cityCenter.coordinate.q), \(cityCenter.coordinate.r))")
                debugLog("   City center state: \(cityCenter.state)")
            } else {
                debugLog("⚠️ AI player \(player.name) has NO city center!")
                let allBuildings = gameState.getBuildingsForPlayer(id: player.id)
                debugLog("   Buildings owned: \(allBuildings.count)")
                for building in allBuildings {
                    debugLog("     - \(building.buildingType.displayName) at (\(building.coordinate.q), \(building.coordinate.r)), state: \(building.state)")
                }
            }

            debugLog("   Resources: food=\(player.getResource(.food)), wood=\(player.getResource(.wood)), stone=\(player.getResource(.stone)), ore=\(player.getResource(.ore))")
        }

        debugLog("🤖 Total AI players registered: \(aiPlayers.count)")
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

            let timeSinceLastDecision = currentTime - aiState.lastDecisionTime
            guard timeSinceLastDecision >= aiState.difficulty.decisionInterval else { continue }

            let cityCenter = state.getCityCenter(forPlayer: playerID)
            let villagerCount = state.getVillagerCount(forPlayer: playerID)
            let buildingCount = state.getBuildingsForPlayer(id: playerID).count
            debugLog("🤖 AI Decision cycle: state=\(aiState.currentState), cityCenter=\(cityCenter != nil), buildings=\(buildingCount), villagers=\(villagerCount), food=\(player.getResource(.food))")

            // Update enemy analysis cache
            militaryPlanner.updateEnemyAnalysis(aiState: aiState, gameState: state, currentTime: currentTime)

            // Update AI state machine
            updateState(for: aiState, gameState: state, currentTime: currentTime)

            // Generate commands based on current state
            let commands = generateCommands(for: aiState, gameState: state, currentTime: currentTime)

            debugLog("🤖 AI \(player.name): Generated \(commands.count) commands in state \(aiState.currentState)")

            allCommands.append(contentsOf: commands)

            aiState.lastDecisionTime = currentTime
        }

        return allCommands
    }

    // MARK: - State Machine

    private func updateState(for aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) {
        let playerID = aiState.playerID

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else {
            aiState.currentState = .retreat
            return
        }

        let threatLevel = gameState.getThreatLevel(at: cityCenter.coordinate, forPlayer: playerID)
        let ourStrength = gameState.getMilitaryStrength(forPlayer: playerID)
        let ourWeightedStrength = gameState.getWeightedMilitaryStrength(forPlayer: playerID)
        let nearbyEnemies = gameState.getEnemyArmies(near: cityCenter.coordinate, range: 5, forPlayer: playerID)

        let armies = gameState.getArmiesForPlayer(id: playerID)
        var armyNeedsRetreat = false
        for army in armies {
            let distanceFromBase = army.coordinate.distance(to: cityCenter.coordinate)
            let isLocallyOutnumbered = gameState.isArmyLocallyOutnumbered(army, forPlayer: playerID)

            if isLocallyOutnumbered && distanceFromBase > 3 {
                armyNeedsRetreat = true
                break
            }
        }

        switch aiState.currentState {
        case .peace:
            if !nearbyEnemies.isEmpty {
                aiState.currentState = .defense
                debugLog("🤖 AI \(playerID): Peace → Defense (enemies nearby)")
            } else if threatLevel > aiState.difficulty.alertThreshold {
                aiState.currentState = .alert
                debugLog("🤖 AI \(playerID): Peace → Alert (threat detected)")
            } else if shouldAttack(aiState: aiState, gameState: gameState, ourStrength: ourStrength) {
                aiState.currentState = .attack
                debugLog("🤖 AI \(playerID): Peace → Attack (strong enough)")
            }

        case .alert:
            if !nearbyEnemies.isEmpty {
                aiState.currentState = .defense
                debugLog("🤖 AI \(playerID): Alert → Defense (enemies nearby)")
            } else if threatLevel < aiState.difficulty.alertThreshold * 0.5 {
                aiState.currentState = .peace
                debugLog("🤖 AI \(playerID): Alert → Peace (threat reduced)")
            } else if shouldAttack(aiState: aiState, gameState: gameState, ourStrength: ourStrength) {
                aiState.currentState = .attack
                debugLog("🤖 AI \(playerID): Alert → Attack (strong enough)")
            }

        case .defense:
            if nearbyEnemies.isEmpty {
                aiState.consecutiveDefenses += 1
                if aiState.consecutiveDefenses > 3 {
                    aiState.currentState = .attack
                    aiState.consecutiveDefenses = 0
                    debugLog("🤖 AI \(playerID): Defense → Attack (counter-attack)")
                } else {
                    aiState.currentState = .alert
                    debugLog("🤖 AI \(playerID): Defense → Alert (enemies gone)")
                }
            } else if ourWeightedStrength < 500 || armyNeedsRetreat {
                aiState.currentState = .retreat
                debugLog("🤖 AI \(playerID): Defense → Retreat (too weak or outnumbered)")
            }

        case .attack:
            if !nearbyEnemies.isEmpty {
                aiState.currentState = .defense
                debugLog("🤖 AI \(playerID): Attack → Defense (base under attack)")
            } else if ourWeightedStrength < 1000 {
                aiState.currentState = .peace
                aiState.persistentAttackTargetID = nil
                debugLog("🤖 AI \(playerID): Attack → Peace (army depleted)")
            } else if armyNeedsRetreat {
                aiState.currentState = .retreat
                debugLog("🤖 AI \(playerID): Attack → Retreat (army in danger)")
            }

        case .retreat:
            if nearbyEnemies.isEmpty && ourWeightedStrength > 1500 {
                aiState.currentState = .alert
                aiState.pendingArmyConvergence = nil
                debugLog("🤖 AI \(playerID): Retreat → Alert (regrouped)")
            }
        }
    }

    private func shouldAttack(aiState: AIPlayerState, gameState: GameState, ourStrength: Int) -> Bool {
        let playerID = aiState.playerID

        let ourWeightedStrength = gameState.getWeightedMilitaryStrength(forPlayer: playerID)
        guard ourWeightedStrength >= 2000 else { return false }

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return false }

        let enemyAnalysis = gameState.analyzeEnemyComposition(forPlayer: playerID)

        guard let enemyArmy = gameState.getNearestEnemyArmy(from: cityCenter.coordinate, forPlayer: playerID) else {
            let enemyBuildings = gameState.getVisibleEnemyBuildings(forPlayer: playerID)
            return !enemyBuildings.isEmpty
        }

        let enemyWeightedStrength = enemyArmy.getWeightedStrength()

        var compositionModifier = 1.0
        if let analysis = enemyAnalysis {
            aiState.lastEnemyAnalysis = EnemyCompositionAnalysis(
                cavalryRatio: analysis.cavalryRatio,
                rangedRatio: analysis.rangedRatio,
                infantryRatio: analysis.infantryRatio,
                siegeRatio: analysis.siegeRatio,
                totalStrength: analysis.totalStrength,
                weightedStrength: analysis.weightedStrength
            )

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

                if analysis.cavalryRatio > 0.35 && ourInfantryRatio > 0.3 {
                    compositionModifier += 0.2
                }
                if analysis.rangedRatio > 0.35 && ourCavalryRatio > 0.3 {
                    compositionModifier += 0.2
                }
                if analysis.infantryRatio > 0.4 && ourRangedRatio > 0.3 {
                    compositionModifier += 0.15
                }

                if ourCavalryRatio > 0.35 && analysis.infantryRatio > 0.3 {
                    compositionModifier -= 0.2
                }
                if ourRangedRatio > 0.35 && analysis.cavalryRatio > 0.3 {
                    compositionModifier -= 0.2
                }
            }
        }

        compositionModifier = max(0.5, min(1.5, compositionModifier))

        let effectiveStrength = ourWeightedStrength * compositionModifier
        let ratio = effectiveStrength / max(1.0, enemyWeightedStrength)

        return ratio >= aiState.difficulty.attackThreshold
    }

    // MARK: - Command Generation (Delegates to Planners)

    // MARK: - Unit Upgrade Commands

    private func generateUnitUpgradeCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        let playerID = aiState.playerID

        guard currentTime - aiState.lastUnitUpgradeCheckTime >= GameConfig.AI.Intervals.unitUpgradeCheck else { return [] }
        aiState.lastUnitUpgradeCheckTime = currentTime

        guard let player = gameState.getPlayer(id: playerID) else { return [] }

        // Don't start if one is already active
        if player.isUnitUpgradeActive() { return [] }

        // Get all available upgrades
        let available = getAvailableUnitUpgrades(for: playerID, gameState: gameState)
        guard !available.isEmpty else { return [] }

        // Score and pick the best
        var scored: [(UnitUpgradeType, Double)] = []
        for upgrade in available {
            let score = scoreUnitUpgrade(upgrade, playerID: playerID, gameState: gameState)
            scored.append((upgrade, score))
        }
        scored.sort { $0.1 > $1.1 }

        guard let (best, _) = scored.first else { return [] }

        // Check affordability
        guard player.canAfford(best.cost) else { return [] }

        // Find a building of the right type with sufficient level
        let buildings = gameState.getBuildingsForPlayer(id: playerID)
        guard let building = buildings.first(where: {
            $0.buildingType == best.requiredBuildingType &&
            $0.state == .completed &&
            $0.level >= best.requiredBuildingLevel
        }) else { return [] }

        debugLog("🤖 AI starting unit upgrade: \(best.displayName)")
        return [AIUpgradeUnitCommand(playerID: playerID, upgradeType: best, buildingID: building.id)]
    }

    private func getAvailableUnitUpgrades(for playerID: UUID, gameState: GameState) -> [UnitUpgradeType] {
        guard let player = gameState.getPlayer(id: playerID) else { return [] }

        let buildings = gameState.getBuildingsForPlayer(id: playerID)

        var available: [UnitUpgradeType] = []
        for upgrade in UnitUpgradeType.allCases {
            // Skip completed
            if player.hasCompletedUnitUpgrade(upgrade.rawValue) { continue }

            // Check prerequisite
            if let prereq = upgrade.prerequisite {
                if !player.hasCompletedUnitUpgrade(prereq.rawValue) { continue }
            }

            // Check if player has a building of the right type at the right level
            let hasBuilding = buildings.contains {
                $0.buildingType == upgrade.requiredBuildingType &&
                $0.state == .completed &&
                $0.level >= upgrade.requiredBuildingLevel
            }
            if !hasBuilding { continue }

            available.append(upgrade)
        }

        return available
    }

    private func scoreUnitUpgrade(_ upgrade: UnitUpgradeType, playerID: UUID, gameState: GameState) -> Double {
        var score = 0.0

        // Prefer lower tiers first (cheaper, faster)
        score += Double(4 - upgrade.tier) * 20.0

        // Prefer upgrades for units the AI currently has
        let armies = gameState.getArmiesForPlayer(id: playerID)
        var hasUnit = false
        for army in armies {
            if army.getUnitCount(ofType: upgrade.unitType) > 0 {
                hasUnit = true
                score += 30.0
                break
            }
        }

        // Give some score even without units, based on category usefulness
        if !hasUnit {
            score += 5.0
        }

        return score
    }

    private func generateCommands(for aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []

        switch aiState.currentState {
        case .peace:
            commands.append(contentsOf: economyPlanner.generateEconomyCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: economyPlanner.generateExpansionCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: researchPlanner.generateResearchCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: defensePlanner.generateDefensiveBuildingCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateUnitUpgradeCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .alert:
            commands.append(contentsOf: economyPlanner.generateEconomyCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: militaryPlanner.generateMilitaryCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: researchPlanner.generateResearchCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: defensePlanner.generateDefensiveBuildingCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: defensePlanner.generateGarrisonCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: defensePlanner.generateEntrenchmentCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateUnitUpgradeCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .defense:
            commands.append(contentsOf: militaryPlanner.generateDefenseCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: militaryPlanner.generateMilitaryCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: researchPlanner.generateResearchCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: defensePlanner.generateDefensiveBuildingCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: defensePlanner.generateGarrisonCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: defensePlanner.generateEntrenchmentCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateUnitUpgradeCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .attack:
            commands.append(contentsOf: militaryPlanner.generateAttackCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: economyPlanner.generateEconomyCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: researchPlanner.generateResearchCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: defensePlanner.generateGarrisonCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateUnitUpgradeCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .retreat:
            commands.append(contentsOf: militaryPlanner.generateRetreatCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
        }

        return commands
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

    private func getTerrainCostMultiplier(in state: GameState) -> Double {
        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: coordinate, rotation: rotation)
        let hasMountain = occupiedCoords.contains { state.mapData.getTerrain(at: $0) == .mountain }
        return hasMountain ? GameConfig.Terrain.mountainBuildingCostMultiplier : 1.0
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        let costMultiplier = getTerrainCostMultiplier(in: state)
        for (resource, baseAmount) in buildingType.buildCost {
            let adjustedAmount = Int(ceil(Double(baseAmount) * costMultiplier))
            guard player.hasResource(resource, amount: adjustedAmount) else {
                return .failure(reason: "Insufficient resources")
            }
        }

        guard state.canBuildAt(coordinate, forPlayer: playerID) else {
            return .failure(reason: "Cannot build at this location")
        }

        return .success(changes: [])
    }

    override func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        let costMultiplier = getTerrainCostMultiplier(in: state)
        for (resource, baseAmount) in buildingType.buildCost {
            let adjustedAmount = Int(ceil(Double(baseAmount) * costMultiplier))
            _ = player.removeResource(resource, amount: adjustedAmount)
        }

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

        debugLog("🤖 AI built \(buildingType.displayName) at (\(coordinate.q), \(coordinate.r))")

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

        for (resource, amount) in unitType.trainingCost {
            let totalCost = amount * quantity
            _ = player.removeResource(resource, amount: totalCost)
        }

        building.startTraining(unitType: unitType, quantity: quantity, at: state.currentTime)

        changeBuilder.add(.trainingStarted(
            buildingID: buildingID,
            unitType: unitType.rawValue,
            quantity: quantity,
            startTime: state.currentTime
        ))

        debugLog("🤖 AI training \(quantity)x \(unitType.displayName)")

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

        _ = player.removeResource(.food, amount: 50 * quantity)

        building.startVillagerTraining(quantity: quantity, at: state.currentTime)

        changeBuilder.add(.villagerTrainingStarted(
            buildingID: buildingID,
            quantity: quantity,
            startTime: state.currentTime
        ))

        debugLog("🤖 AI training \(quantity) villagers")

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

        for (unitType, count) in composition {
            _ = building.removeFromGarrison(unitType: unitType, quantity: count)
        }

        let spawnCoord = state.mapData.findNearestWalkable(
            to: building.coordinate,
            maxDistance: 3,
            forPlayerID: playerID,
            gameState: state
        ) ?? building.coordinate

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

        debugLog("🤖 AI deployed army with \(army.getTotalUnits()) units")

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

        building.villagerGarrison -= quantity

        let spawnCoord = state.mapData.findNearestWalkable(
            to: building.coordinate,
            maxDistance: 3,
            forPlayerID: playerID,
            gameState: state
        ) ?? building.coordinate

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

        debugLog("🤖 AI deployed \(quantity) villagers at (\(spawnCoord.q), \(spawnCoord.r))")

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

        group.currentTask = .gatheringResource(resourcePointID: resourcePointID)
        group.taskTargetCoordinate = resource.coordinate
        group.assignedResourcePointID = resourcePointID

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

        let registered = GameEngine.shared.resourceEngine.startGathering(
            villagerGroupID: villagerGroupID,
            resourcePointID: resourcePointID
        )

        if registered {
            GameEngine.shared.resourceEngine.updateCollectionRates(forPlayer: playerID)
        }

        changeBuilder.add(.villagerGroupTaskChanged(
            groupID: villagerGroupID,
            task: "gathering",
            targetCoordinate: resource.coordinate
        ))

        debugLog("🤖 AI villagers assigned to gather \(resource.resourceType.displayName)")

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

        // Check stacking limit
        if state.mapData.getEntityCount(at: destination) >= GameConfig.Stacking.maxEntitiesPerTile {
            return .failure(reason: "Tile is full")
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

            debugLog("🤖 AI moving army to (\(destination.q), \(destination.r))")
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

        if player.isResearchActive() {
            return .failure(reason: "Research already in progress")
        }

        if player.hasCompletedResearch(researchType.rawValue) {
            return .failure(reason: "Research already completed")
        }

        for prereq in researchType.prerequisites {
            if !player.hasCompletedResearch(prereq.rawValue) {
                return .failure(reason: "Prerequisites not met")
            }
        }

        let ccLevel = state.getCityCenter(forPlayer: playerID)?.level ?? 1
        if researchType.cityCenterLevelRequirement > ccLevel {
            return .failure(reason: "City Center level too low")
        }

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

        for (resource, amount) in researchType.cost {
            _ = player.removeResource(resource, amount: amount)
        }

        player.startResearch(researchType.rawValue, at: state.currentTime)

        changeBuilder.add(.researchStarted(
            playerID: playerID,
            researchType: researchType.rawValue,
            startTime: state.currentTime
        ))

        debugLog("🤖 AI started research: \(researchType.displayName)")

        return .success(changes: changeBuilder.build().changes)
    }
}

/// AI command for entrenching an army at its current position
class AIEntrenchCommand: BaseEngineCommand {
    let armyID: UUID

    init(playerID: UUID, armyID: UUID) {
        self.armyID = armyID
        super.init(playerID: playerID)
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        guard let army = state.getArmy(id: armyID) else {
            return .failure(reason: "Army not found")
        }

        guard army.ownerID == playerID else {
            return .failure(reason: "Not your army")
        }

        guard !army.isEntrenched else {
            return .failure(reason: "Already entrenched")
        }

        guard !army.isEntrenching else {
            return .failure(reason: "Already entrenching")
        }

        guard army.currentPath == nil else {
            return .failure(reason: "Cannot entrench while moving")
        }

        guard !army.isInCombat else {
            return .failure(reason: "Cannot entrench while in combat")
        }

        guard !army.isRetreating else {
            return .failure(reason: "Cannot entrench while retreating")
        }

        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        guard player.hasResource(.wood, amount: GameConfig.Entrenchment.woodCost) else {
            return .failure(reason: "Not enough wood")
        }

        if let commanderID = army.commanderID,
           let commander = state.getCommander(id: commanderID) {
            guard commander.stamina >= Commander.staminaCostPerCommand else {
                return .failure(reason: "Commander too exhausted")
            }
        }

        return .success(changes: [])
    }

    override func execute(in state: GameState, changeBuilder: StateChangeBuilder) -> EngineCommandResult {
        guard let army = state.getArmy(id: armyID),
              let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Not found")
        }

        _ = player.removeResource(.wood, amount: GameConfig.Entrenchment.woodCost)

        if let commanderID = army.commanderID,
           let commander = state.getCommander(id: commanderID) {
            commander.consumeStamina()
        }

        army.isEntrenching = true
        army.entrenchmentStartTime = state.currentTime

        changeBuilder.add(.armyEntrenchmentStarted(armyID: armyID, coordinate: army.coordinate))

        debugLog("🤖 AI army \(army.name) started entrenching at (\(army.coordinate.q), \(army.coordinate.r))")

        return .success(changes: changeBuilder.build().changes)
    }
}

/// AI command for starting a unit upgrade
class AIUpgradeUnitCommand: BaseEngineCommand {
    let upgradeType: UnitUpgradeType
    let buildingID: UUID

    init(playerID: UUID, upgradeType: UnitUpgradeType, buildingID: UUID) {
        self.upgradeType = upgradeType
        self.buildingID = buildingID
        super.init(playerID: playerID)
    }

    override func validate(in state: GameState) -> EngineCommandResult {
        guard let player = state.getPlayer(id: playerID) else {
            return .failure(reason: "Player not found")
        }

        if player.isUnitUpgradeActive() {
            return .failure(reason: "Unit upgrade already in progress")
        }

        if player.hasCompletedUnitUpgrade(upgradeType.rawValue) {
            return .failure(reason: "Unit upgrade already completed")
        }

        if let prereq = upgradeType.prerequisite {
            if !player.hasCompletedUnitUpgrade(prereq.rawValue) {
                return .failure(reason: "Prerequisites not met")
            }
        }

        // Check building
        guard let building = state.getBuilding(id: buildingID) else {
            return .failure(reason: "Building not found")
        }

        if building.buildingType != upgradeType.requiredBuildingType {
            return .failure(reason: "Wrong building type")
        }

        if building.level < upgradeType.requiredBuildingLevel {
            return .failure(reason: "Building level too low")
        }

        for (resource, amount) in upgradeType.cost {
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

        for (resource, amount) in upgradeType.cost {
            _ = player.removeResource(resource, amount: amount)
        }

        player.startUnitUpgrade(upgradeType.rawValue, buildingID: buildingID, at: state.currentTime)

        changeBuilder.add(.unitUpgradeStarted(
            playerID: playerID,
            unitType: upgradeType.unitType.rawValue,
            tier: upgradeType.tier,
            buildingID: buildingID,
            startTime: state.currentTime
        ))

        debugLog("🤖 AI started unit upgrade: \(upgradeType.displayName)")

        return .success(changes: changeBuilder.build().changes)
    }
}
