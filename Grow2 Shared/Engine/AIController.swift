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

    // Strategic memory
    var knownEnemyBases: [HexCoordinate] = []
    var lastAttackTarget: HexCoordinate?
    var consecutiveDefenses: Int = 0

    init(playerID: UUID, difficulty: AIDifficulty = .medium) {
        self.playerID = playerID
        self.difficulty = difficulty
    }
}

// MARK: - AI Controller

/// Main AI controller that manages AI decision-making for all AI players
class AIController {

    // MARK: - Singleton
    static let shared = AIController()

    // MARK: - State
    private var aiPlayers: [UUID: AIPlayerState] = [:]
    private weak var gameState: GameState?

    // MARK: - Configuration
    private let buildInterval: TimeInterval = 2.0      // Min time between build decisions
    private let trainInterval: TimeInterval = 3.0      // Min time between train decisions
    private let scoutInterval: TimeInterval = 30.0     // Min time between scout dispatches

    private init() {}

    // MARK: - Setup

    func setup(gameState: GameState) {
        self.gameState = gameState
        aiPlayers.removeAll()

        // Initialize AI state for each AI player
        for player in gameState.getAIPlayers() {
            aiPlayers[player.id] = AIPlayerState(playerID: player.id)
            print("🤖 AI Controller initialized for player: \(player.name)")
        }
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

            // Update AI state machine
            updateState(for: aiState, gameState: state, currentTime: currentTime)

            // Generate commands based on current state
            let commands = generateCommands(for: aiState, gameState: state, currentTime: currentTime)
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
        let nearbyEnemies = gameState.getEnemyArmies(near: cityCenter.coordinate, range: 5, forPlayer: playerID)

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
            } else if ourStrength < 5 {
                aiState.currentState = .retreat
                print("🤖 AI \(playerID): Defense → Retreat (too weak)")
            }

        case .attack:
            if !nearbyEnemies.isEmpty {
                aiState.currentState = .defense
                print("🤖 AI \(playerID): Attack → Defense (base under attack)")
            } else if ourStrength < 10 {
                aiState.currentState = .peace
                print("🤖 AI \(playerID): Attack → Peace (army depleted)")
            }

        case .retreat:
            if nearbyEnemies.isEmpty && ourStrength > 15 {
                aiState.currentState = .alert
                print("🤖 AI \(playerID): Retreat → Alert (regrouped)")
            }
        }
    }

    private func shouldAttack(aiState: AIPlayerState, gameState: GameState, ourStrength: Int) -> Bool {
        let playerID = aiState.playerID

        // Need minimum army
        guard ourStrength >= 20 else { return false }

        // Find nearest enemy
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return false }
        guard let enemyArmy = gameState.getNearestEnemyArmy(from: cityCenter.coordinate, forPlayer: playerID) else {
            // No enemy army visible - look for enemy buildings
            let enemyBuildings = gameState.getVisibleEnemyBuildings(forPlayer: playerID)
            return !enemyBuildings.isEmpty
        }

        // Compare strength
        let enemyStrength = enemyArmy.getTotalUnits()
        let ratio = Double(ourStrength) / Double(max(1, enemyStrength))

        return ratio >= aiState.difficulty.attackThreshold
    }

    // MARK: - Command Generation

    private func generateCommands(for aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []

        switch aiState.currentState {
        case .peace:
            commands.append(contentsOf: generateEconomyCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateExpansionCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .alert:
            commands.append(contentsOf: generateEconomyCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateMilitaryCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .defense:
            commands.append(contentsOf: generateDefenseCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateMilitaryCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .attack:
            commands.append(contentsOf: generateAttackCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
            commands.append(contentsOf: generateEconomyCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))

        case .retreat:
            commands.append(contentsOf: generateRetreatCommands(aiState: aiState, gameState: gameState, currentTime: currentTime))
        }

        return commands
    }

    // MARK: - Economy Commands

    private func generateEconomyCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard let player = gameState.getPlayer(id: playerID) else { return [] }

        // Check if we need more villagers
        let villagerCount = gameState.getVillagerCount(forPlayer: playerID)
        let popStats = gameState.getPopulationStats(forPlayer: playerID)

        // Train villagers if we have capacity and need more
        if villagerCount < 20 && popStats.current < popStats.capacity {
            if let command = tryTrainVillagers(playerID: playerID, gameState: gameState, currentTime: currentTime, aiState: aiState) {
                commands.append(command)
            }
        }

        // Build farms if we need more food income
        let foodRate = player.getCollectionRate(.food)
        if foodRate < 3.0 && currentTime - aiState.lastBuildTime >= buildInterval {
            if let command = tryBuildFarm(playerID: playerID, gameState: gameState) {
                commands.append(command)
                aiState.lastBuildTime = currentTime
            }
        }

        // Build houses if we're near population cap
        if popStats.current >= popStats.capacity - 5 {
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
        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return nil }
        guard let player = gameState.getPlayer(id: playerID) else { return nil }

        // Check resources
        let farmCost = BuildingType.farm.buildCost
        for (resource, amount) in farmCost {
            guard player.hasResource(resource, amount: amount) else { return nil }
        }

        // Find a location near the city center
        guard let location = gameState.findBuildLocation(near: cityCenter.coordinate, maxDistance: 4, forPlayer: playerID) else {
            return nil
        }

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

    // MARK: - Expansion Commands

    private func generateExpansionCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        // TODO: Implement resource camp building and territory expansion
        return []
    }

    // MARK: - Military Commands

    private func generateMilitaryCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard currentTime - aiState.lastTrainTime >= trainInterval else { return [] }

        // Find barracks to train units
        let barracks = gameState.getBuildingsForPlayer(id: playerID).filter {
            $0.buildingType == .barracks && $0.isOperational && $0.trainingQueue.isEmpty
        }

        if let barracks = barracks.first {
            if let command = tryTrainMilitary(playerID: playerID, buildingID: barracks.id, gameState: gameState) {
                commands.append(command)
                aiState.lastTrainTime = currentTime
            }
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

        // Determine unit type based on building
        let unitType: MilitaryUnitType
        switch building.buildingType {
        case .barracks:
            unitType = .swordsman
        case .archeryRange:
            unitType = .archer
        case .stable:
            unitType = .scout
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

        // Find target - enemy army or building
        var targetCoordinate: HexCoordinate?

        if let enemyArmy = gameState.getNearestEnemyArmy(from: cityCenter.coordinate, forPlayer: playerID) {
            targetCoordinate = enemyArmy.coordinate
        } else {
            // Attack enemy buildings
            let enemyBuildings = gameState.getVisibleEnemyBuildings(forPlayer: playerID)
            if let nearestBuilding = enemyBuildings.min(by: { $0.coordinate.distance(to: cityCenter.coordinate) < $1.coordinate.distance(to: cityCenter.coordinate) }) {
                targetCoordinate = nearestBuilding.coordinate
            }
        }

        guard let target = targetCoordinate else { return [] }

        // Move all idle armies toward target
        for army in gameState.getArmiesForPlayer(id: playerID) {
            guard !army.isInCombat && army.currentPath == nil else { continue }

            let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: target, isArmy: true)
            commands.append(command)
        }

        aiState.lastAttackTarget = target
        return commands
    }

    // MARK: - Retreat Commands

    private func generateRetreatCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard let cityCenter = gameState.getCityCenter(forPlayer: playerID) else { return [] }

        // Move all armies back toward city center
        for army in gameState.getArmiesForPlayer(id: playerID) {
            guard !army.isInCombat else { continue }

            // Only retreat if not already near city center
            guard army.coordinate.distance(to: cityCenter.coordinate) > 3 else { continue }

            let command = AIMoveCommand(playerID: playerID, entityID: army.id, destination: cityCenter.coordinate, isArmy: true)
            commands.append(command)
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
