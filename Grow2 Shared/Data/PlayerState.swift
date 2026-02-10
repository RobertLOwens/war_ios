// ============================================================================
// FILE: Grow2 Shared/Data/PlayerState.swift
// PURPOSE: Pure data model for player state - no SpriteKit dependencies
// ============================================================================

import Foundation

// MARK: - Type Aliases for Backward Compatibility

/// Alias for backward compatibility - use ResourceTypeData directly in new code
typealias ResourceType = ResourceTypeData

/// Alias for backward compatibility - use DiplomacyStatusData directly in new code
typealias DiplomacyStatus = DiplomacyStatusData

// MARK: - Resource Type Data

/// Pure data representation of resource types
enum ResourceTypeData: String, Codable, CaseIterable {
    case wood
    case food
    case stone
    case ore

    var displayName: String {
        return rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .wood: return "🪵"
        case .food: return "🌾"
        case .stone: return "🪨"
        case .ore: return "⛏️"
        }
    }
}

// MARK: - Diplomacy Status Data

/// Pure data representation of diplomacy status between players
enum DiplomacyStatusData: String, Codable {
    case me       // Self
    case guild    // Same guild/team
    case ally     // Allied player
    case neutral  // No relationship
    case enemy    // At war

    var displayName: String {
        switch self {
        case .me: return "You"
        case .guild: return "Guild Member"
        case .ally: return "Ally"
        case .neutral: return "Neutral"
        case .enemy: return "Enemy"
        }
    }

    var strokeColorHex: String {
        switch self {
        case .me: return "#0000FF"      // Blue
        case .guild: return "#800080"   // Purple
        case .ally: return "#00FF00"    // Green
        case .enemy: return "#FF0000"   // Red
        case .neutral: return "#FFA500" // Orange
        }
    }

    var canAttack: Bool {
        return self == .enemy
    }
}

// MARK: - Player State

/// Pure data representation of a player's state
class PlayerState: Codable {
    let id: UUID
    var name: String
    var colorHex: String  // Store color as hex string for serialization
    var isAI: Bool  // Whether this player is controlled by AI

    // MARK: - Resources
    private(set) var resources: [ResourceTypeData: Int] = [
        .wood: 1000,
        .food: 1000,
        .stone: 1000,
        .ore: 1000
    ]

    private(set) var collectionRates: [ResourceTypeData: Double] = [
        .wood: 0,
        .food: 0,
        .stone: 0,
        .ore: 0
    ]

    private var resourceAccumulators: [ResourceTypeData: Double] = [
        .wood: 0.0,
        .food: 0.0,
        .stone: 0.0,
        .ore: 0.0
    ]

    // MARK: - Owned Entities (by ID reference)
    private(set) var ownedBuildingIDs: Set<UUID> = []
    private(set) var ownedArmyIDs: Set<UUID> = []
    private(set) var ownedVillagerGroupIDs: Set<UUID> = []
    private(set) var ownedCommanderIDs: Set<UUID> = []

    // MARK: - Diplomacy
    private(set) var diplomacyRelations: [UUID: DiplomacyStatusData] = [:]

    // MARK: - Vision
    private(set) var visibleCoordinates: Set<HexCoordinate> = []
    private(set) var exploredCoordinates: Set<HexCoordinate> = []

    // MARK: - Time Tracking
    private var lastUpdateTime: TimeInterval?
    private var foodConsumptionAccumulator: Double = 0.0

    // MARK: - Research Tracking
    private(set) var completedResearch: Set<String> = []  // ResearchType rawValue strings
    private(set) var activeResearchType: String? = nil
    private(set) var activeResearchStartTime: TimeInterval? = nil
    private var cachedResearchBonuses: [String: Double] = [:]  // ResearchBonusType rawValue -> value

    // MARK: - Unit Upgrade Tracking
    private(set) var completedUnitUpgrades: Set<String> = []  // UnitUpgradeType rawValue strings
    private(set) var activeUnitUpgrade: String? = nil
    private(set) var activeUnitUpgradeStartTime: TimeInterval? = nil
    private(set) var activeUnitUpgradeBuildingID: UUID? = nil
    private var cachedUnitUpgradeBonuses: [String: UnitUpgradeBonusData] = [:]  // MilitaryUnitTypeData rawValue -> cumulative bonus

    // MARK: - Constants
    static let foodConsumptionPerPop: Double = 0.1

    // MARK: - Initialization

    init(id: UUID = UUID(), name: String, colorHex: String, isAI: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isAI = isAI
    }

    // MARK: - Resource Management

    func getResource(_ type: ResourceTypeData) -> Int {
        return resources[type] ?? 0
    }

    func getCollectionRate(_ type: ResourceTypeData) -> Double {
        return collectionRates[type] ?? 0.0
    }

    func setResource(_ type: ResourceTypeData, amount: Int) {
        resources[type] = max(0, amount)
    }

    func setCollectionRate(_ type: ResourceTypeData, rate: Double) {
        collectionRates[type] = rate
    }

    func addResource(_ type: ResourceTypeData, amount: Int, storageCapacity: Int) -> Int {
        let current = resources[type] ?? 0
        let availableSpace = max(0, storageCapacity - current)
        let actualAmount = min(amount, availableSpace)

        if actualAmount > 0 {
            resources[type] = current + actualAmount
        }

        return actualAmount  // Returns how much was actually added
    }

    @discardableResult
    func removeResource(_ type: ResourceTypeData, amount: Int) -> Bool {
        let current = resources[type] ?? 0
        if current >= amount {
            resources[type] = current - amount
            return true
        }
        return false
    }

    func hasResource(_ type: ResourceTypeData, amount: Int) -> Bool {
        return getResource(type) >= amount
    }

    func canAfford(_ costs: [ResourceTypeData: Int]) -> Bool {
        for (resourceType, amount) in costs {
            if !hasResource(resourceType, amount: amount) {
                return false
            }
        }
        return true
    }

    func increaseCollectionRate(_ type: ResourceTypeData, amount: Double) {
        let current = collectionRates[type] ?? 0.0
        collectionRates[type] = max(0, current + amount)
    }

    func decreaseCollectionRate(_ type: ResourceTypeData, amount: Double) {
        let current = collectionRates[type] ?? 0.0
        collectionRates[type] = max(0, current - amount)
    }

    // MARK: - Food Consumption

    /// Process food consumption based on population. Returns the amount of food consumed.
    func consumeFood(consumptionRate: Double, deltaTime: TimeInterval) -> Int {
        let consumed = consumptionRate * deltaTime
        foodConsumptionAccumulator += consumed

        let wholeConsumption = Int(foodConsumptionAccumulator)
        if wholeConsumption > 0 {
            let current = resources[.food] ?? 0
            let actualConsumed = min(wholeConsumption, current)
            resources[.food] = current - actualConsumed
            foodConsumptionAccumulator -= Double(wholeConsumption)
            return actualConsumed
        }

        return 0
    }

    // MARK: - Resource Update (per-tick)

    func updateResources(currentTime: TimeInterval, getStorageCapacity: (ResourceTypeData) -> Int) -> [ResourceTypeData: Int] {
        guard let lastTime = lastUpdateTime else {
            lastUpdateTime = currentTime
            return [:]
        }

        let deltaTime = currentTime - lastTime
        var resourceChanges: [ResourceTypeData: Int] = [:]

        for type in ResourceTypeData.allCases {
            let rate = collectionRates[type] ?? 0.0
            let generated = rate * deltaTime

            resourceAccumulators[type] = (resourceAccumulators[type] ?? 0.0) + generated

            let wholeAmount = Int(resourceAccumulators[type] ?? 0.0)
            if wholeAmount > 0 {
                let capacity = getStorageCapacity(type)
                let added = addResource(type, amount: wholeAmount, storageCapacity: capacity)
                resourceAccumulators[type] = (resourceAccumulators[type] ?? 0.0) - Double(wholeAmount)
                if added > 0 {
                    resourceChanges[type] = added
                }
            }
        }

        lastUpdateTime = currentTime
        return resourceChanges
    }

    // MARK: - Entity Ownership

    func addOwnedBuilding(_ buildingID: UUID) {
        ownedBuildingIDs.insert(buildingID)
    }

    func removeOwnedBuilding(_ buildingID: UUID) {
        ownedBuildingIDs.remove(buildingID)
    }

    func addOwnedArmy(_ armyID: UUID) {
        ownedArmyIDs.insert(armyID)
    }

    func removeOwnedArmy(_ armyID: UUID) {
        ownedArmyIDs.remove(armyID)
    }

    func addOwnedVillagerGroup(_ groupID: UUID) {
        ownedVillagerGroupIDs.insert(groupID)
    }

    func removeOwnedVillagerGroup(_ groupID: UUID) {
        ownedVillagerGroupIDs.remove(groupID)
    }

    func addOwnedCommander(_ commanderID: UUID) {
        ownedCommanderIDs.insert(commanderID)
    }

    func removeOwnedCommander(_ commanderID: UUID) {
        ownedCommanderIDs.remove(commanderID)
    }

    // MARK: - Diplomacy

    func getDiplomacyStatus(with otherPlayerID: UUID) -> DiplomacyStatusData {
        if otherPlayerID == id {
            return .me
        }
        return diplomacyRelations[otherPlayerID] ?? .neutral
    }

    func setDiplomacyStatus(with otherPlayerID: UUID, status: DiplomacyStatusData) {
        if otherPlayerID != id {
            diplomacyRelations[otherPlayerID] = status
        }
    }

    // MARK: - Vision

    func setVisibleCoordinates(_ coords: Set<HexCoordinate>) {
        visibleCoordinates = coords
        // Explored coordinates are cumulative
        exploredCoordinates.formUnion(coords)
    }

    func isVisible(_ coordinate: HexCoordinate) -> Bool {
        return visibleCoordinates.contains(coordinate)
    }

    func isExplored(_ coordinate: HexCoordinate) -> Bool {
        return exploredCoordinates.contains(coordinate)
    }

    func getVisibilityLevel(at coordinate: HexCoordinate) -> VisibilityLevelData {
        if visibleCoordinates.contains(coordinate) {
            return .visible
        } else if exploredCoordinates.contains(coordinate) {
            return .explored
        } else {
            return .unexplored
        }
    }

    // MARK: - Research Methods

    /// Start researching a new research type
    func startResearch(_ typeRawValue: String, at time: TimeInterval) {
        guard activeResearchType == nil else { return }  // Can only research one at a time
        activeResearchType = typeRawValue
        activeResearchStartTime = time
    }

    /// Complete the active research
    func completeResearch(_ typeRawValue: String) {
        completedResearch.insert(typeRawValue)
        if activeResearchType == typeRawValue {
            activeResearchType = nil
            activeResearchStartTime = nil
        }
        recalculateResearchBonuses()
    }

    /// Cancel the active research without completing it
    func cancelActiveResearch() {
        activeResearchType = nil
        activeResearchStartTime = nil
    }

    /// Check if a specific research has been completed
    func hasCompletedResearch(_ typeRawValue: String) -> Bool {
        return completedResearch.contains(typeRawValue)
    }

    /// Check if any research is currently active
    func isResearchActive() -> Bool {
        return activeResearchType != nil
    }

    /// Get a research bonus multiplier
    func getResearchBonus(_ bonusTypeRawValue: String) -> Double {
        return cachedResearchBonuses[bonusTypeRawValue] ?? 0.0
    }

    /// Get a research bonus multiplier (1.0 + bonus)
    func getResearchBonusMultiplier(_ bonusTypeRawValue: String) -> Double {
        return 1.0 + getResearchBonus(bonusTypeRawValue)
    }

    /// Recalculate cached research bonuses from completed research
    func recalculateResearchBonuses() {
        cachedResearchBonuses.removeAll()
        for researchRawValue in completedResearch {
            if let researchType = ResearchType(rawValue: researchRawValue) {
                for bonus in researchType.bonuses {
                    cachedResearchBonuses[bonus.type.rawValue, default: 0] += bonus.value
                }
            }
        }
    }

    // MARK: - Unit Upgrade Methods

    /// Start a unit upgrade
    func startUnitUpgrade(_ typeRawValue: String, buildingID: UUID, at time: TimeInterval) {
        guard activeUnitUpgrade == nil else { return }
        activeUnitUpgrade = typeRawValue
        activeUnitUpgradeStartTime = time
        activeUnitUpgradeBuildingID = buildingID
    }

    /// Complete the active unit upgrade
    func completeUnitUpgrade(_ typeRawValue: String) {
        completedUnitUpgrades.insert(typeRawValue)
        if activeUnitUpgrade == typeRawValue {
            activeUnitUpgrade = nil
            activeUnitUpgradeStartTime = nil
            activeUnitUpgradeBuildingID = nil
        }
        recalculateUnitUpgradeBonuses()
    }

    /// Cancel the active unit upgrade without completing it
    func cancelActiveUnitUpgrade() {
        activeUnitUpgrade = nil
        activeUnitUpgradeStartTime = nil
        activeUnitUpgradeBuildingID = nil
    }

    /// Check if a specific unit upgrade has been completed
    func hasCompletedUnitUpgrade(_ typeRawValue: String) -> Bool {
        return completedUnitUpgrades.contains(typeRawValue)
    }

    /// Check if any unit upgrade is currently active
    func isUnitUpgradeActive() -> Bool {
        return activeUnitUpgrade != nil
    }

    /// Get the cumulative upgrade bonus for a unit type
    func getUnitUpgradeBonus(for unitType: MilitaryUnitTypeData) -> UnitUpgradeBonusData {
        return cachedUnitUpgradeBonuses[unitType.rawValue] ?? UnitUpgradeBonusData(attackBonus: 0, armorBonus: 0, hpBonus: 0)
    }

    /// Get the current completed tier for a unit type
    func getUnitUpgradeTier(for unitType: MilitaryUnitTypeData) -> Int {
        return UnitUpgradeType.currentTier(for: unitType, completedUpgrades: completedUnitUpgrades)
    }

    /// Recalculate cached unit upgrade bonuses from completed upgrades
    func recalculateUnitUpgradeBonuses() {
        cachedUnitUpgradeBonuses.removeAll()
        for unitType in MilitaryUnitTypeData.allCases {
            let bonus = UnitUpgradeType.cumulativeBonuses(for: unitType, completedUpgrades: completedUnitUpgrades)
            if bonus.attackBonus > 0 || bonus.armorBonus > 0 || bonus.hpBonus > 0 {
                cachedUnitUpgradeBonuses[unitType.rawValue] = bonus
            }
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, isAI
        case resources, collectionRates, resourceAccumulators
        case ownedBuildingIDs, ownedArmyIDs, ownedVillagerGroupIDs, ownedCommanderIDs
        case diplomacyRelations
        case visibleCoordinates, exploredCoordinates
        case lastUpdateTime, foodConsumptionAccumulator
        case completedResearch, activeResearchType, activeResearchStartTime, cachedResearchBonuses
        case completedUnitUpgrades, activeUnitUpgrade, activeUnitUpgradeStartTime, activeUnitUpgradeBuildingID
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        isAI = try container.decode(Bool.self, forKey: .isAI)

        resources = try container.decode([ResourceTypeData: Int].self, forKey: .resources)
        collectionRates = try container.decode([ResourceTypeData: Double].self, forKey: .collectionRates)
        resourceAccumulators = try container.decode([ResourceTypeData: Double].self, forKey: .resourceAccumulators)

        ownedBuildingIDs = try container.decode(Set<UUID>.self, forKey: .ownedBuildingIDs)
        ownedArmyIDs = try container.decode(Set<UUID>.self, forKey: .ownedArmyIDs)
        ownedVillagerGroupIDs = try container.decode(Set<UUID>.self, forKey: .ownedVillagerGroupIDs)
        ownedCommanderIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .ownedCommanderIDs) ?? []

        diplomacyRelations = try container.decode([UUID: DiplomacyStatusData].self, forKey: .diplomacyRelations)

        visibleCoordinates = try container.decode(Set<HexCoordinate>.self, forKey: .visibleCoordinates)
        exploredCoordinates = try container.decode(Set<HexCoordinate>.self, forKey: .exploredCoordinates)

        lastUpdateTime = try container.decodeIfPresent(TimeInterval.self, forKey: .lastUpdateTime)
        foodConsumptionAccumulator = try container.decodeIfPresent(Double.self, forKey: .foodConsumptionAccumulator) ?? 0.0

        completedResearch = try container.decodeIfPresent(Set<String>.self, forKey: .completedResearch) ?? []
        activeResearchType = try container.decodeIfPresent(String.self, forKey: .activeResearchType)
        activeResearchStartTime = try container.decodeIfPresent(TimeInterval.self, forKey: .activeResearchStartTime)
        cachedResearchBonuses = try container.decodeIfPresent([String: Double].self, forKey: .cachedResearchBonuses) ?? [:]

        // Unit upgrade fields with backward-compatible defaults
        completedUnitUpgrades = try container.decodeIfPresent(Set<String>.self, forKey: .completedUnitUpgrades) ?? []
        activeUnitUpgrade = try container.decodeIfPresent(String.self, forKey: .activeUnitUpgrade)
        activeUnitUpgradeStartTime = try container.decodeIfPresent(TimeInterval.self, forKey: .activeUnitUpgradeStartTime)
        activeUnitUpgradeBuildingID = try container.decodeIfPresent(UUID.self, forKey: .activeUnitUpgradeBuildingID)
    }
}

// MARK: - Visibility Level Data

enum VisibilityLevelData: String, Codable {
    case unexplored
    case explored
    case visible
}

