import Foundation
import UIKit

// MARK: - UIColor Hex Extension

extension UIColor {
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255)
        return String(format: "#%06x", rgb)
    }
}

// MARK: - Player Class

class Player {
    let id: UUID
    var name: String
    var color: UIColor

    // MARK: - Data Layer (Single Source of Truth for State)
    let state: PlayerState

    // MARK: - Visual Layer Only
    private(set) var commanders: [Commander] = []
    var fogOfWar: FogOfWarManager?

    // Entities owned by this player (armies and villager groups)
    private(set) var entities: [MapEntity] = []

    // Buildings owned by this player
    private(set) var buildings: [BuildingNode] = []

    private(set) var armies: [Army] = []

    // Food consumption tracking (visual layer handles the tick-based consumption)
    private var foodConsumptionAccumulator: Double = 0.0
    private var lastFoodUpdateTime: TimeInterval?
    static let foodConsumptionPerPop: Double = 0.1

    // MARK: - Initialization

    init(id: UUID = UUID(), name: String, color: UIColor, state: PlayerState? = nil) {
        self.id = id
        self.name = name
        self.color = color

        // Use provided state or create new one
        if let existingState = state {
            self.state = existingState
        } else {
            self.state = PlayerState(id: id, name: name, colorHex: color.toHexString())
        }
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
    
    // MARK: - Resource Management (Delegates to PlayerState)

    func getResource(_ type: ResourceType) -> Int {
        return state.getResource(type)
    }

    func getCollectionRate(_ type: ResourceType) -> Double {
        return state.getCollectionRate(type)
    }

    func addResource(_ type: ResourceType, amount: Int) {
        let capacity = getStorageCapacity(for: type)
        let added = state.addResource(type, amount: amount, storageCapacity: capacity)

        // Log when resources are capped
        if added < amount {
            print("⚠️ \(type.displayName) storage full! Only added \(added)/\(amount). Cap: \(capacity)")
        }
    }

    @discardableResult
    func removeResource(_ type: ResourceType, amount: Int) -> Bool {
        return state.removeResource(type, amount: amount)
    }

    func hasResource(_ type: ResourceType, amount: Int) -> Bool {
        return state.hasResource(type, amount: amount)
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
        let current = state.getCollectionRate(type)
        state.setCollectionRate(type, rate: current * multiplier)
    }

    func multiplyCollectionRate(_ type: ResourceType, multiplier: Double) {
        let current = state.getCollectionRate(type)
        let newRate = current * multiplier
        state.setCollectionRate(type, rate: newRate)
        print("🔨 \(type.displayName) rate: \(current)/s × \(multiplier) = \(newRate)/s")
    }

    func increaseCollectionRate(_ type: ResourceType, amount: Double) {
        state.increaseCollectionRate(type, amount: amount)
    }
    
    func updateResources(currentTime: TimeInterval) {
        // Delegate resource generation to state
        _ = state.updateResources(currentTime: currentTime) { [weak self] type in
            return self?.getStorageCapacity(for: type) ?? 200
        }

        // Handle food consumption (visual layer manages the population-based calculation)
        guard let lastTime = lastFoodUpdateTime else {
            lastFoodUpdateTime = currentTime
            return
        }

        let deltaTime = currentTime - lastTime
        let foodConsumptionRate = getFoodConsumptionRate()
        let foodConsumed = foodConsumptionRate * deltaTime

        foodConsumptionAccumulator += foodConsumed
        let wholeConsumption = Int(foodConsumptionAccumulator)
        if wholeConsumption > 0 {
            _ = state.removeResource(.food, amount: wholeConsumption)
            foodConsumptionAccumulator -= Double(wholeConsumption)
        }

        lastFoodUpdateTime = currentTime
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

    func getIdleVillagerCount() -> Int {
        return getVillagerGroups().filter { $0.currentTask == .idle }.count
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
        return state.getDiplomacyStatus(with: otherPlayer.id)
    }

    func setDiplomacyStatus(with otherPlayer: Player, status: DiplomacyStatus) {
        state.setDiplomacyStatus(with: otherPlayer.id, status: status)
    }

    func decreaseCollectionRate(_ type: ResourceType, amount: Double) {
        let current = state.getCollectionRate(type)
        state.decreaseCollectionRate(type, amount: amount)
        print("📉 \(type.displayName) rate: \(current)/s → \(state.getCollectionRate(type))/s")
    }

    func setResource(_ type: ResourceType, amount: Int) {
        state.setResource(type, amount: amount)
    }

    /// Directly sets a collection rate (used for loading saves)
    func setCollectionRate(_ type: ResourceType, rate: Double) {
        state.setCollectionRate(type, rate: rate)
    }
    
    func getPopulationCapacity() -> Int {
        let buildingCapacity = buildings
            .filter { $0.isOperational }
            .reduce(0) { $0 + $1.buildingType.populationCapacity }

        // Add research bonus for population capacity
        let researchBonus = ResearchManager.shared.getPopulationCapacityBonus()

        return buildingCapacity + researchBonus
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
        // Calculate military population
        let militaryPopulation = getTotalMilitaryUnits()
        // Include garrisoned military units
        let garrisonedMilitary = buildings.reduce(0) { $0 + $1.getTotalGarrisonedUnits() }
        let totalMilitary = militaryPopulation + garrisonedMilitary

        // Calculate civilian population (villagers + garrisoned villagers + training)
        let totalPop = getCurrentPopulation()
        let civilianPopulation = totalPop - totalMilitary

        // Base rates
        let civilianBaseRate = Double(civilianPopulation) * Player.foodConsumptionPerPop
        let militaryBaseRate = Double(totalMilitary) * Player.foodConsumptionPerPop

        // Apply Efficient Rations research bonus (reduces civilian food consumption)
        let civilianMultiplier = ResearchManager.shared.getFoodConsumptionMultiplier()

        // Apply Military Rations research bonus (reduces military food consumption)
        let militaryMultiplier = ResearchManager.shared.getMilitaryFoodConsumptionMultiplier()

        return (civilianBaseRate * civilianMultiplier) + (militaryBaseRate * militaryMultiplier)
    }
    
    func getCityCenterLevel() -> Int {
        // Include upgrading buildings - they should still count at their current level
        let cityCenters = buildings.filter {
            $0.buildingType == .cityCenter && ($0.state == .completed || $0.state == .upgrading)
        }
        return cityCenters.map { $0.level }.max() ?? 0
    }
    
    func getStorageCapacity(for type: ResourceType) -> Int {
        var capacity = 0
        
        for building in buildings where building.isOperational {
            let buildingCapacity = building.buildingType.storageCapacityPerResource(forLevel: building.level)
            if buildingCapacity > 0 {
                capacity += buildingCapacity
            }
        }
        
        // Minimum storage of 200 per resource even without buildings (starting storage)
        return max(200, capacity)
    }
    
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

    // MARK: - Entity Limits

    /// Returns maximum number of villager groups allowed based on City Center level
    /// Formula: 2 + CC level
    func getMaxVillagerGroups() -> Int {
        return 2 + getCityCenterLevel()
    }

    /// Returns maximum number of armies allowed based on City Center level
    /// Formula: 1 + (CC level / 2)
    func getMaxArmies() -> Int {
        return 1 + (getCityCenterLevel() / 2)
    }

    /// Returns true if player can spawn another villager group
    func canSpawnVillagerGroup() -> Bool {
        return getVillagerGroups().count < getMaxVillagerGroups()
    }

    /// Returns true if player can spawn another army
    func canSpawnArmy() -> Bool {
        return getArmies().count < getMaxArmies()
    }

    /// Returns the reason why player can't spawn a villager group, or nil if they can
    func getVillagerGroupSpawnError() -> String? {
        let currentCount = getVillagerGroups().count
        let maxAllowed = getMaxVillagerGroups()

        if currentCount >= maxAllowed {
            let ccLevel = getCityCenterLevel()
            return "Max \(maxAllowed) villager groups at CC Lv.\(ccLevel). Upgrade City Center for more."
        }
        return nil
    }

    /// Returns the reason why player can't spawn an army, or nil if they can
    func getArmySpawnError() -> String? {
        let currentCount = getArmies().count
        let maxAllowed = getMaxArmies()

        if currentCount >= maxAllowed {
            let ccLevel = getCityCenterLevel()
            return "Max \(maxAllowed) armies at CC Lv.\(ccLevel). Upgrade City Center for more."
        }
        return nil
    }

    func getTotalStorageCapacity() -> Int {
        return ResourceType.allCases.reduce(0) { $0 + getStorageCapacity(for: $1) }
    }

    /// Returns total resources currently stored across all types
    func getTotalResourcesStored() -> Int {
        return ResourceType.allCases.reduce(0) { $0 + getResource($1) }
    }
    
    /// Returns storage percentage for a specific resource (0.0 to 1.0+)
    func getStoragePercent(for type: ResourceType) -> Double {
        let capacity = getStorageCapacity(for: type)
        guard capacity > 0 else { return 0 }
        return Double(getResource(type)) / Double(capacity)
    }
    
    @discardableResult
    func addResourceWithOverflow(_ type: ResourceType, amount: Int) -> (added: Int, overflow: Int) {
        let capacity = getStorageCapacity(for: type)
        let added = state.addResource(type, amount: amount, storageCapacity: capacity)
        let overflow = amount - added
        return (added: added, overflow: overflow)
    }

}
