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
        .wood: 1.0,
        .food: 1.0,
        .stone: 0.5,
        .ore: 0.25
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
        resources[type] = max(0, current + amount)
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
    
    func canAffordUnit(_ unitType: UnitType) -> Bool {
        for (resourceType, amount) in unitType.trainingCost {
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
        return getArmies().reduce(0) { $0 + $1.getUnitCount() }
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
        }
    }

    func removeCommander(_ commander: Commander) {
        commanders.removeAll { $0.id == commander.id }
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
}
