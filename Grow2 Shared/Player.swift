import Foundation
import UIKit

// MARK: - Resource Type

enum ResourceType: String, CaseIterable {
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

// MARK: - Player Class

class Player {
    let id: UUID
    var name: String
    var color: UIColor
    private(set) var commanders: [Commander] = []
    var diplomacyRelations: [UUID: DiplomacyStatus] = [:]
    var fogOfWar: FogOfWarManager?

    
    // Resource totals
    private(set) var resources: [ResourceType: Int] = [
        .wood: 1000,
        .food: 1000,
        .stone: 1000,
        .ore: 1000
    ]
    
    // Resource collection rates (per second)
    private(set) var collectionRates: [ResourceType: Double] = [
        .wood: 0,
        .food: 0,
        .stone: 0,
        .ore: 0
    ]
    
    // Entities owned by this player (armies and villager groups)
    private(set) var entities: [MapEntity] = []
    
    // Buildings owned by this player
    private(set) var buildings: [BuildingNode] = []
    
    // Resource accumulator for fractional amounts
    private var resourceAccumulators: [ResourceType: Double] = [
        .wood: 0.0,
        .food: 0.0,
        .stone: 0.0,
        .ore: 0.0
    ]
    
    // Last update time for resource generation
    private var lastUpdateTime: TimeInterval?
    private(set) var armies: [Army] = []
    
    private var foodConsumptionAccumulator: Double = 0.0
    static let foodConsumptionPerPop: Double = 0.1

    // MARK: - Initialization
    
    init(id: UUID = UUID(), name: String, color: UIColor) {
        self.id = id
        self.name = name
        self.color = color
    }


    // Add to Player class methods:
    func initializeFogOfWar(hexMap: HexMap) {
        fogOfWar = FogOfWarManager(player: self, hexMap: hexMap)
    }

    func updateVision(allPlayers: [Player]) {
        fogOfWar?.updateVision(allPlayers: allPlayers)
    }

    func isVisible(_ coord: HexCoordinate) -> Bool {
        return fogOfWar?.isVisible(coord) ?? false
    }

    func isExplored(_ coord: HexCoordinate) -> Bool {
        return fogOfWar?.isExplored(coord) ?? false
    }

    func getVisibilityLevel(at coord: HexCoordinate) -> VisibilityLevel {
        return fogOfWar?.getVisibilityLevel(at: coord) ?? .unexplored
    }
    
    // MARK: - Resource Management
    
    func getResource(_ type: ResourceType) -> Int {
        return resources[type] ?? 0
    }
    
    func getCollectionRate(_ type: ResourceType) -> Double {
        return collectionRates[type] ?? 0.0
    }
    
    func addResource(_ type: ResourceType, amount: Int) {
        let current = resources[type] ?? 0
        let capacity = getStorageCapacity()
        
        // Calculate total resources currently stored
        let currentTotal = ResourceType.allCases.reduce(0) { $0 + getResource($1) }
        
        // Calculate how much space is available
        let availableSpace = max(0, capacity - currentTotal)
        
        // Only add up to the available space
        let actualAmount = min(amount, availableSpace)
        
        if actualAmount > 0 {
            resources[type] = current + actualAmount
        }
        
        // Optionally log when resources are capped
        if actualAmount < amount {
            print("⚠️ Storage full! Only added \(actualAmount)/\(amount) \(type.displayName). Capacity: \(capacity)")
        }
    }
    
    @discardableResult
    func removeResource(_ type: ResourceType, amount: Int) -> Bool {
        let current = resources[type] ?? 0
        if current >= amount {
            resources[type] = current - amount
            return true
        }
        return false
    }
    
    func hasResource(_ type: ResourceType, amount: Int) -> Bool {
        return getResource(type) >= amount
    }
    
    func canAfford(_ buildingType: BuildingType) -> Bool {
        for (resourceType, amount) in buildingType.buildCost {
            if !hasResource(resourceType, amount: amount) {
                return false
            }
        }
        return true
    }
    
    func canAffordMilitaryUnit(_ unitType: MilitaryUnitType) -> Bool {
         for (resourceType, amount) in unitType.trainingCost {
             if !hasResource(resourceType, amount: amount) {
                 return false
             }
         }
         return true
     }
     
     func canAffordUnitBatch(_ unitType: MilitaryUnitType, quantity: Int) -> Bool {
         for (resourceType, unitCost) in unitType.trainingCost {
             let totalCost = unitCost * quantity
             if !hasResource(resourceType, amount: totalCost) {
                 return false
             }
         }
         return true
     }
    
    func getMissingResources(for buildingType: BuildingType) -> [ResourceType: Int] {
        var missing: [ResourceType: Int] = [:]
        for (resourceType, amount) in buildingType.buildCost {
            let current = getResource(resourceType)
            if current < amount {
                missing[resourceType] = amount - current
            }
        }
        return missing
    }
    
    func modifyCollectionRate(_ type: ResourceType, multiplier: Double) {
           let current = collectionRates[type] ?? 0.0
           collectionRates[type] = max(0, current * multiplier)
       }
       
   func multiplyCollectionRate(_ type: ResourceType, multiplier: Double) {
       let current = collectionRates[type] ?? 0.0
       let newRate = current * multiplier
       collectionRates[type] = max(0, newRate)
       print("🔨 \(type.displayName) rate: \(current)/s × \(multiplier) = \(newRate)/s")
   }
   
   func increaseCollectionRate(_ type: ResourceType, amount: Double) {
       let current = collectionRates[type] ?? 0.0
       collectionRates[type] = max(0, current + amount)
   }
    
    func updateResources(currentTime: TimeInterval) {
        guard let lastTime = lastUpdateTime else {
            lastUpdateTime = currentTime
            return
        }
        
        let deltaTime = currentTime - lastTime
        
        // Generate resources based on rates
        for type in ResourceType.allCases {
            let rate = collectionRates[type] ?? 0.0
            let generated = rate * deltaTime
            
            // Add to accumulator
            resourceAccumulators[type] = (resourceAccumulators[type] ?? 0.0) + generated
            
            // Convert whole numbers to resources
            let wholeAmount = Int(resourceAccumulators[type] ?? 0.0)
            if wholeAmount > 0 {
                addResource(type, amount: wholeAmount)
                resourceAccumulators[type] = (resourceAccumulators[type] ?? 0.0) - Double(wholeAmount)
            }
        }
        
        let foodConsumptionRate = getFoodConsumptionRate()
        let foodConsumed = foodConsumptionRate * deltaTime
        
        foodConsumptionAccumulator += foodConsumed
        let wholeConsumption = Int(foodConsumptionAccumulator)
        if wholeConsumption > 0 {
            let currentFood = resources[.food] ?? 0
            resources[.food] = max(0, currentFood - wholeConsumption)
            foodConsumptionAccumulator -= Double(wholeConsumption)
        }
        
        lastUpdateTime = currentTime
    }
    
    // MARK: - Entity Management
    
    func addEntity(_ entity: MapEntity) {
        if !entities.contains(where: { $0.id == entity.id }) {
            entities.append(entity)
            entity.owner = self
        }
    }
    
    func removeEntity(_ entity: MapEntity) {
        entities.removeAll { $0.id == entity.id }
        if entity.owner?.id == self.id {
            entity.owner = nil
        }
    }
    
    func getArmies() -> [Army] {
        return entities.compactMap { $0 as? Army }
    }
    
    func getVillagerGroups() -> [VillagerGroup] {
        return entities.compactMap { $0 as? VillagerGroup }
    }
    
    func getTotalVillagerCount() -> Int {
        return getVillagerGroups().reduce(0) { $0 + $1.villagerCount }
    }
    
    func getTotalMilitaryUnits() -> Int {
        return getArmies().reduce(0) { $0 + $1.getTotalUnits() }
    }
    
    // MARK: - Building Management
    
    func addBuilding(_ building: BuildingNode) {
        if !buildings.contains(where: { $0 === building }) {
            buildings.append(building)
            building.owner = self
        }
    }
    
    func removeBuilding(_ building: BuildingNode) {
        buildings.removeAll { $0 === building }
        if building.owner === self {
            building.owner = nil
        }
    }
    
    func getBuildings(ofType type: BuildingType) -> [BuildingNode] {
        return buildings.filter { $0.buildingType == type }
    }
    
    func getBuildingCount(ofType type: BuildingType) -> Int {
        return getBuildings(ofType: type).count
    }
    
    var totalBuildingCount: Int {
        return buildings.count
    }
    
    var completedBuildingCount: Int {
        return buildings.filter { $0.state == .completed }.count
    }
    
    // MARK: - Utility
    
    func getResourceSummary() -> String {
        var summary = "\(name)'s Resources:\n"
        for type in ResourceType.allCases {
            let amount = getResource(type)
            let rate = getCollectionRate(type)
            summary += "\(type.icon) \(type.displayName): \(amount) (+\(String(format: "%.1f", rate))/s)\n"
        }
        return summary
    }
    
    func getEntitySummary() -> String {
        var summary = "\(name)'s Forces:\n"
        summary += "Villagers: \(getTotalVillagerCount())\n"
        summary += "Military Units: \(getTotalMilitaryUnits())\n"
        summary += "Buildings: \(completedBuildingCount)/\(totalBuildingCount)\n"
        return summary
    }
    
    func printStatus() {
        print(getResourceSummary())
        print(getEntitySummary())
    }
    
    func addArmy(_ army: Army) {
         if !armies.contains(where: { $0.id == army.id }) {
             armies.append(army)
             army.owner = self
         }
     }
     
     func removeArmy(_ army: Army) {
         armies.removeAll { $0.id == army.id }
         if army.owner === self {
             army.owner = nil
         }
     }
     
     func getTotalMilitaryUnitsCount() -> Int {
         return armies.reduce(0) { $0 + $1.getTotalMilitaryUnits() }

     }
    
    func addCommander(_ commander: Commander) {
        if !commanders.contains(where: { $0.id == commander.id }) {
            commanders.append(commander)
            commander.owner = self
        }
    }
    
    func removeCommander(_ commander: Commander) {
        commanders.removeAll { $0.id == commander.id }
        if commander.owner === self {
            commander.owner = nil
        }
        // Also remove from any army they were commanding
        commander.removeFromArmy()
    }

    func getUnassignedCommanders() -> [Commander] {
        let assignedCommanderIDs = armies.compactMap { $0.commander?.id }
        return commanders.filter { !assignedCommanderIDs.contains($0.id) }
    }
    
    func getDiplomacyStatus(with otherPlayer: Player?) -> DiplomacyStatus {
        guard let otherPlayer = otherPlayer else { return .neutral }
        
        // Check if this is the same player
        if otherPlayer.id == self.id {
            return .me
        }
        
        // Check stored relations
        return diplomacyRelations[otherPlayer.id] ?? .neutral
    }

    func setDiplomacyStatus(with otherPlayer: Player, status: DiplomacyStatus) {
        diplomacyRelations[otherPlayer.id] = status
    }
    
    func decreaseCollectionRate(_ type: ResourceType, amount: Double) {
        let current = collectionRates[type] ?? 0.0
        collectionRates[type] = max(0, current - amount)
        print("📉 \(type.displayName) rate: \(current)/s → \(collectionRates[type] ?? 0)/s")
    }
    
    func setResource(_ type: ResourceType, amount: Int) {
        resources[type] = max(0, amount)
    }

    /// Directly sets a collection rate (used for loading saves)
    func setCollectionRate(_ type: ResourceType, rate: Double) {
        collectionRates[type] = max(0, rate)
    }
    
    func getPopulationCapacity() -> Int {
        return buildings
            .filter { $0.isOperational }
            .reduce(0) { $0 + $1.buildingType.populationCapacity }
    }
        
    func getCurrentPopulation() -> Int {
        var total = 0
        
        // Count villagers on field
        total += getTotalVillagerCount()
        
        // Count military units in armies
        total += getTotalMilitaryUnits()
        
        // Count garrisoned units in buildings
        for building in buildings {
            total += building.villagerGarrison
            total += building.getTotalGarrisonedUnits()
        }
        
        // Count units currently in training queues
        for building in buildings {
            // Military training queue
            for entry in building.trainingQueue {
                total += entry.quantity
            }
            
            // Villager training queue
            for entry in building.villagerTrainingQueue {
                total += entry.quantity
            }
        }
        
        return total
    }
        
    /// Returns available population space
    func getAvailablePopulation() -> Int {
        return max(0, getPopulationCapacity() - getCurrentPopulation())
    }
    
    /// Returns true if player has room for more population
    func hasPopulationSpace(for amount: Int = 1) -> Bool {
        return getAvailablePopulation() >= amount
    }
    
    /// Returns the food consumption rate per second based on current population
    func getFoodConsumptionRate() -> Double {
        return Double(getCurrentPopulation()) * Player.foodConsumptionPerPop
    }
    
    func getCityCenterLevel() -> Int {
        let cityCenters = buildings.filter {
            $0.buildingType == .cityCenter && $0.state == .completed
        }
        return cityCenters.map { $0.level }.max() ?? 0
    }
    
    func getStorageCapacity() -> Int {
        var totalCapacity = 0
        
        for building in buildings where building.isOperational {
            let capacity = building.buildingType.storageCapacity(forLevel: building.level)
            if capacity > 0 {
                totalCapacity += capacity
                // Debug: print("📦 \(building.buildingType.displayName) Lv.\(building.level): +\(capacity) storage")
            }
        }
        
        // Minimum storage of 500 even without buildings (starting storage)
        return max(500, totalCapacity)
    }
    
    /// Returns the number of completed warehouses the player owns
    func getWarehouseCount() -> Int {
        return buildings.filter {
            $0.buildingType == .warehouse && $0.state == .completed
        }.count
    }
    
    /// Returns the number of warehouses currently being built
    func getWarehousesUnderConstruction() -> Int {
        return buildings.filter {
            $0.buildingType == .warehouse && $0.state == .constructing
        }.count
    }
    
    /// Returns true if the player can build another warehouse
    func canBuildWarehouse() -> Bool {
        let ccLevel = getCityCenterLevel()
        let maxAllowed = BuildingType.maxWarehousesAllowed(forCityCenterLevel: ccLevel)
        let currentCount = getWarehouseCount() + getWarehousesUnderConstruction()
        return currentCount < maxAllowed
    }
    
    /// Returns the reason why player can't build a warehouse, or nil if they can
    func getWarehouseBuildError() -> String? {
        let ccLevel = getCityCenterLevel()
        let maxAllowed = BuildingType.maxWarehousesAllowed(forCityCenterLevel: ccLevel)
        let currentCount = getWarehouseCount() + getWarehousesUnderConstruction()
        
        if currentCount >= maxAllowed {
            if maxAllowed == 0 {
                return "Requires City Center Level 2"
            } else {
                let nextRequired = BuildingType.cityCenterLevelRequired(forWarehouseNumber: maxAllowed + 1)
                if nextRequired <= 10 {
                    return "Max \(maxAllowed) warehouse(s) at CC Lv.\(ccLevel). Need CC Lv.\(nextRequired) for more."
                } else {
                    return "Maximum warehouses reached (\(maxAllowed)/\(maxAllowed))"
                }
            }
        }
        return nil
    }
    
    /// Returns remaining storage space
    func getRemainingStorage() -> Int {
        let capacity = getStorageCapacity()
        let totalStored = ResourceType.allCases.reduce(0) { $0 + getResource($1) }
        return max(0, capacity - totalStored)
    }
    
    /// Returns true if adding this amount would exceed storage
    func wouldExceedStorage(_ type: ResourceType, amount: Int) -> Bool {
        let capacity = getStorageCapacity()
        let currentTotal = ResourceType.allCases.reduce(0) { $0 + getResource($1) }
        return (currentTotal + amount) > capacity
    }
    
    @discardableResult
    func addResourceWithOverflow(_ type: ResourceType, amount: Int) -> (added: Int, overflow: Int) {
        let current = resources[type] ?? 0
        let capacity = getStorageCapacity()
        
        // Calculate total resources currently stored
        let currentTotal = ResourceType.allCases.reduce(0) { $0 + getResource($1) }
        
        // Calculate how much space is available
        let availableSpace = max(0, capacity - currentTotal)
        
        // Only add up to the available space
        let actualAmount = min(amount, availableSpace)
        let overflow = amount - actualAmount
        
        if actualAmount > 0 {
            resources[type] = current + actualAmount
        }
        
        return (added: actualAmount, overflow: overflow)
    }

}
