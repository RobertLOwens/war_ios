// ============================================================================
// FILE: Grow2 Shared/BuildingData.swift
// PURPOSE: Pure data model for buildings - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Building Data

/// Pure data representation of a building, separate from visual representation
class BuildingData: Codable {
    
    // MARK: - Identity
    let id: UUID
    var buildingType: BuildingType
    var coordinate: HexCoordinate  // Anchor coordinate for multi-tile buildings
    var ownerID: UUID?
    var rotation: Int = 0  // 0-5 for hex rotations (only used for multi-tile buildings)

    // MARK: - State
    var state: BuildingState = .planning
    var level: Int = 1
    var health: Double
    var maxHealth: Double
    
    // MARK: - Construction
    var constructionProgress: Double = 0.0
    var constructionStartTime: TimeInterval?
    var buildersAssigned: Int = 0
    
    // MARK: - Upgrade
    var upgradeProgress: Double = 0.0
    var upgradeStartTime: TimeInterval?

    // MARK: - Demolition
    var demolitionProgress: Double = 0.0
    var demolitionStartTime: TimeInterval?
    var demolishersAssigned: Int = 0

    // MARK: - Garrison
    var garrison: [MilitaryUnitType: Int] = [:]
    var villagerGarrison: Int = 0
    
    // MARK: - Training Queues
    var trainingQueue: [TrainingQueueEntry] = []
    var villagerTrainingQueue: [VillagerTrainingEntry] = []
    
    // MARK: - Computed Properties
    
    var maxLevel: Int {
        return buildingType.maxLevel
    }
    
    var isOperational: Bool {
        return state == .completed || state == .upgrading
    }
    
    var canUpgrade: Bool {
        guard state == .completed && level < maxLevel else { return false }
        return true
    }

    /// Returns all coordinates this building occupies
    var occupiedCoordinates: [HexCoordinate] {
        return buildingType.getOccupiedCoordinates(anchor: coordinate, rotation: rotation)
    }

    /// Check if this building occupies a specific coordinate
    func occupies(_ coord: HexCoordinate) -> Bool {
        return occupiedCoordinates.contains(coord)
    }

    // MARK: - Initialization

    init(buildingType: BuildingType, coordinate: HexCoordinate, ownerID: UUID? = nil, rotation: Int = 0) {
        self.id = UUID()
        self.buildingType = buildingType
        self.coordinate = coordinate
        self.ownerID = ownerID
        self.rotation = rotation

        // Set health based on building type
        switch buildingType.category {
        case .military:
            self.maxHealth = 500.0
        case .economic:
            self.maxHealth = 200.0
        }
        self.health = maxHealth
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, buildingType, coordinate, ownerID, rotation
        case state, level, health, maxHealth
        case constructionProgress, constructionStartTime, buildersAssigned
        case upgradeProgress, upgradeStartTime
        case demolitionProgress, demolitionStartTime, demolishersAssigned
        case garrison, villagerGarrison
        case trainingQueue, villagerTrainingQueue
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        buildingType = try container.decode(BuildingType.self, forKey: .buildingType)
        coordinate = try container.decode(HexCoordinate.self, forKey: .coordinate)
        ownerID = try container.decodeIfPresent(UUID.self, forKey: .ownerID)
        rotation = try container.decodeIfPresent(Int.self, forKey: .rotation) ?? 0

        state = try container.decode(BuildingState.self, forKey: .state)
        level = try container.decode(Int.self, forKey: .level)
        health = try container.decode(Double.self, forKey: .health)
        maxHealth = try container.decode(Double.self, forKey: .maxHealth)
        
        constructionProgress = try container.decode(Double.self, forKey: .constructionProgress)
        constructionStartTime = try container.decodeIfPresent(TimeInterval.self, forKey: .constructionStartTime)
        buildersAssigned = try container.decode(Int.self, forKey: .buildersAssigned)
        
        upgradeProgress = try container.decode(Double.self, forKey: .upgradeProgress)
        upgradeStartTime = try container.decodeIfPresent(TimeInterval.self, forKey: .upgradeStartTime)

        demolitionProgress = try container.decodeIfPresent(Double.self, forKey: .demolitionProgress) ?? 0.0
        demolitionStartTime = try container.decodeIfPresent(TimeInterval.self, forKey: .demolitionStartTime)
        demolishersAssigned = try container.decodeIfPresent(Int.self, forKey: .demolishersAssigned) ?? 0

        garrison = try container.decode([MilitaryUnitType: Int].self, forKey: .garrison)
        villagerGarrison = try container.decode(Int.self, forKey: .villagerGarrison)
        
        trainingQueue = try container.decode([TrainingQueueEntry].self, forKey: .trainingQueue)
        villagerTrainingQueue = try container.decode([VillagerTrainingEntry].self, forKey: .villagerTrainingQueue)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(buildingType, forKey: .buildingType)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encodeIfPresent(ownerID, forKey: .ownerID)
        try container.encode(rotation, forKey: .rotation)

        try container.encode(state, forKey: .state)
        try container.encode(level, forKey: .level)
        try container.encode(health, forKey: .health)
        try container.encode(maxHealth, forKey: .maxHealth)
        
        try container.encode(constructionProgress, forKey: .constructionProgress)
        try container.encodeIfPresent(constructionStartTime, forKey: .constructionStartTime)
        try container.encode(buildersAssigned, forKey: .buildersAssigned)
        
        try container.encode(upgradeProgress, forKey: .upgradeProgress)
        try container.encodeIfPresent(upgradeStartTime, forKey: .upgradeStartTime)

        try container.encode(demolitionProgress, forKey: .demolitionProgress)
        try container.encodeIfPresent(demolitionStartTime, forKey: .demolitionStartTime)
        try container.encode(demolishersAssigned, forKey: .demolishersAssigned)

        try container.encode(garrison, forKey: .garrison)
        try container.encode(villagerGarrison, forKey: .villagerGarrison)
        
        try container.encode(trainingQueue, forKey: .trainingQueue)
        try container.encode(villagerTrainingQueue, forKey: .villagerTrainingQueue)
    }
    
    // MARK: - Construction Logic
    
    func startConstruction(builders: Int = 1) {
        state = .constructing
        constructionStartTime = Date().timeIntervalSince1970
        buildersAssigned = max(1, builders)
        constructionProgress = 0.0
    }
    
    /// Updates construction and returns true if construction completed this frame
    func updateConstruction(currentTime: TimeInterval) -> Bool {
        guard state == .constructing, let startTime = constructionStartTime else { return false }
        
        let elapsed = currentTime - startTime
        let buildSpeedMultiplier = 1.0 + (Double(buildersAssigned - 1) * 0.5)
        let effectiveBuildTime = buildingType.buildTime / buildSpeedMultiplier
        
        constructionProgress = min(1.0, elapsed / effectiveBuildTime)
        
        if constructionProgress >= 1.0 {
            completeConstruction()
            return true
        }
        return false
    }
    
    func completeConstruction() {
        guard state == .constructing else { return }
        
        state = .completed
        constructionProgress = 1.0
        health = maxHealth
        constructionStartTime = nil
    }
    
    func getRemainingConstructionTime(currentTime: TimeInterval) -> TimeInterval? {
        guard state == .constructing, let startTime = constructionStartTime else { return nil }
        
        let elapsed = currentTime - startTime
        let buildSpeedMultiplier = 1.0 + (Double(buildersAssigned - 1) * 0.5)
        let effectiveBuildTime = buildingType.buildTime / buildSpeedMultiplier
        
        return max(0, effectiveBuildTime - elapsed)
    }
    
    // MARK: - Upgrade Logic
    
    func getUpgradeCost() -> [ResourceType: Int]? {
        return buildingType.upgradeCost(forLevel: level)
    }
    
    func getUpgradeTime() -> TimeInterval? {
        return buildingType.upgradeTime(forLevel: level)
    }
    
    func startUpgrade() {
        guard canUpgrade, state == .completed else { return }
        
        state = .upgrading
        upgradeStartTime = Date().timeIntervalSince1970
        upgradeProgress = 0.0
    }
    
    /// Updates upgrade and returns true if upgrade completed this frame
    func updateUpgrade(currentTime: TimeInterval) -> Bool {
        guard state == .upgrading,
              let startTime = upgradeStartTime,
              let upgradeTime = getUpgradeTime() else { return false }
        
        let elapsed = currentTime - startTime
        upgradeProgress = min(1.0, elapsed / upgradeTime)
        
        if upgradeProgress >= 1.0 {
            completeUpgrade()
            return true
        }
        return false
    }
    
    func completeUpgrade() {
        guard state == .upgrading else { return }
        
        level += 1
        state = .completed
        upgradeProgress = 0.0
        upgradeStartTime = nil
    }
    
    func cancelUpgrade() -> [ResourceType: Int]? {
        guard state == .upgrading else { return nil }
        
        let refund = getUpgradeCost()
        
        state = .completed
        upgradeProgress = 0.0
        upgradeStartTime = nil
        
        return refund
    }
    
    func getRemainingUpgradeTime(currentTime: TimeInterval) -> TimeInterval? {
        guard state == .upgrading,
              let startTime = upgradeStartTime,
              let totalTime = getUpgradeTime() else { return nil }

        let elapsed = currentTime - startTime
        return max(0, totalTime - elapsed)
    }

    // MARK: - Demolition Logic

    /// Returns demolition time (50% of original build time)
    func getDemolitionTime() -> TimeInterval {
        return buildingType.buildTime * 0.5
    }

    /// Returns resources refunded on demolition (25% of build cost)
    func getDemolitionRefund() -> [ResourceType: Int] {
        var refund: [ResourceType: Int] = [:]
        for (resourceType, amount) in buildingType.buildCost {
            refund[resourceType] = Int(Double(amount) * 0.25)
        }
        return refund
    }

    /// Whether this building can be demolished
    var canDemolish: Bool {
        // Cannot demolish City Center
        guard buildingType != .cityCenter else { return false }
        // Can only demolish completed buildings
        guard state == .completed else { return false }
        return true
    }

    func startDemolition(demolishers: Int = 1) {
        guard canDemolish, state == .completed else { return }

        state = .demolishing
        demolitionStartTime = Date().timeIntervalSince1970
        demolishersAssigned = max(1, demolishers)
        demolitionProgress = 0.0
    }

    /// Updates demolition and returns true if demolition completed this frame
    func updateDemolition(currentTime: TimeInterval) -> Bool {
        guard state == .demolishing, let startTime = demolitionStartTime else { return false }

        let elapsed = currentTime - startTime
        let demolisherMultiplier = 1.0 + (Double(demolishersAssigned - 1) * 0.5)
        let effectiveDemolitionTime = getDemolitionTime() / demolisherMultiplier

        demolitionProgress = min(1.0, elapsed / effectiveDemolitionTime)

        return demolitionProgress >= 1.0
    }

    func cancelDemolition() {
        guard state == .demolishing else { return }

        state = .completed
        demolitionProgress = 0.0
        demolitionStartTime = nil
        demolishersAssigned = 0
    }

    func getRemainingDemolitionTime(currentTime: TimeInterval) -> TimeInterval? {
        guard state == .demolishing, let startTime = demolitionStartTime else { return nil }

        let elapsed = currentTime - startTime
        let demolisherMultiplier = 1.0 + (Double(demolishersAssigned - 1) * 0.5)
        let effectiveDemolitionTime = getDemolitionTime() / demolisherMultiplier

        return max(0, effectiveDemolitionTime - elapsed)
    }

    // MARK: - Training Logic
    
    func canTrain(_ unitType: MilitaryUnitType) -> Bool {
        guard state == .completed else { return false }
        return unitType.trainingBuilding == buildingType
    }
    
    func canTrainVillagers() -> Bool {
        guard state == .completed else { return false }
        return buildingType == .cityCenter || buildingType == .neighborhood
    }
    
    func startTraining(unitType: MilitaryUnitType, quantity: Int, at time: TimeInterval) {
        guard canTrain(unitType) else { return }
        let entry = TrainingQueueEntry(unitType: unitType, quantity: quantity, startTime: time)
        trainingQueue.append(entry)
    }
    
    func startVillagerTraining(quantity: Int, at time: TimeInterval) {
        guard canTrainVillagers() else { return }
        let entry = VillagerTrainingEntry(quantity: quantity, startTime: time)
        villagerTrainingQueue.append(entry)
    }
    
    /// Updates training and returns completed entries
    func updateTraining(currentTime: TimeInterval) -> [TrainingQueueEntry] {
        guard !trainingQueue.isEmpty else { return [] }
        
        var completed: [TrainingQueueEntry] = []
        var completedIndices: [Int] = []
        
        for (index, entry) in trainingQueue.enumerated() {
            let progress = entry.getProgress(currentTime: currentTime)
            trainingQueue[index].progress = progress
            
            if progress >= 1.0 {
                addToGarrison(unitType: entry.unitType, quantity: entry.quantity)
                completed.append(entry)
                completedIndices.append(index)
            }
        }
        
        for index in completedIndices.reversed() {
            trainingQueue.remove(at: index)
        }
        
        return completed
    }
    
    /// Updates villager training and returns completed entries
    func updateVillagerTraining(currentTime: TimeInterval) -> [VillagerTrainingEntry] {
        guard !villagerTrainingQueue.isEmpty else { return [] }
        
        var completed: [VillagerTrainingEntry] = []
        var completedIndices: [Int] = []
        
        for (index, entry) in villagerTrainingQueue.enumerated() {
            let progress = entry.getProgress(currentTime: currentTime)
            villagerTrainingQueue[index].progress = progress
            
            if progress >= 1.0 {
                addVillagersToGarrison(quantity: entry.quantity)
                completed.append(entry)
                completedIndices.append(index)
            }
        }
        
        for index in completedIndices.reversed() {
            villagerTrainingQueue.remove(at: index)
        }
        
        return completed
    }
    
    // MARK: - Garrison Logic
    
    func addToGarrison(unitType: MilitaryUnitType, quantity: Int) {
        garrison[unitType, default: 0] += quantity
    }
    
    func removeFromGarrison(unitType: MilitaryUnitType, quantity: Int) -> Int {
        let current = garrison[unitType] ?? 0
        let toRemove = min(current, quantity)
        
        if toRemove > 0 {
            let remaining = current - toRemove
            if remaining > 0 {
                garrison[unitType] = remaining
            } else {
                garrison.removeValue(forKey: unitType)
            }
        }
        
        return toRemove
    }
    
    func addVillagersToGarrison(quantity: Int) {
        villagerGarrison += quantity
    }
    
    func removeVillagersFromGarrison(quantity: Int) -> Int {
        let toRemove = min(villagerGarrison, quantity)
        villagerGarrison -= toRemove
        return toRemove
    }
    
    func getTotalGarrisonedUnits() -> Int {
        return garrison.values.reduce(0, +)
    }
    
    func getTotalGarrisonCount() -> Int {
        return getTotalGarrisonedUnits() + villagerGarrison
    }
    
    func getGarrisonCapacity() -> Int {
        switch buildingType.category {
        case .military: return 500
        case .economic: return 100
        }
    }
    
    func hasGarrisonSpace(for count: Int) -> Bool {
        return getTotalGarrisonCount() + count <= getGarrisonCapacity()
    }
    
    // MARK: - Combat Logic
    
    func takeDamage(_ amount: Double) {
        guard state == .completed || state == .damaged else { return }
        
        health = max(0, health - amount)
        
        if health <= 0 {
            state = .destroyed
        } else if health < maxHealth / 2 {
            state = .damaged
        }
    }
    
    func repair(_ amount: Double) {
        guard state == .damaged else { return }
        
        health = min(maxHealth, health + amount)
        
        if health >= maxHealth / 2 {
            state = .completed
        }
    }
}
