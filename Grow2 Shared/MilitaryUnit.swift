import Foundation

struct VillagerTrainingEntry {
    let id: UUID
    let quantity: Int
    let startTime: TimeInterval
    var progress: Double = 0.0
    let trainingTime: TimeInterval = 15.0 // Same as villager training time
    
    init(quantity: Int, startTime: TimeInterval) {
        self.id = UUID()
        self.quantity = quantity
        self.startTime = startTime
        self.progress = 0.0
    }
    
    func getTimeRemaining(currentTime: TimeInterval) -> TimeInterval {
        let elapsed = currentTime - startTime
        let totalTime = trainingTime * Double(quantity)
        return max(0, totalTime - elapsed)
    }
    
    func getProgress(currentTime: TimeInterval) -> Double {
        let elapsed = currentTime - startTime
        let totalTime = trainingTime * Double(quantity)
        return min(1.0, elapsed / totalTime)
    }
    
    func getVillagersCompleted(currentTime: TimeInterval) -> Int {
        let elapsed = currentTime - startTime
        let villagersCompleted = Int(elapsed / trainingTime)
        return min(quantity, villagersCompleted)
    }
}


// MARK: - Military Unit Type

enum TrainableUnitType {
    case military(MilitaryUnitType)
    case villager
    
    var displayName: String {
        switch self {
        case .military(let type):
            return type.displayName
        case .villager:
            return "Villager"
        }
    }
    
    var icon: String {
        switch self {
        case .military(let type):
            return type.icon
        case .villager:
            return "👷"
        }
    }
    
    var trainingCost: [ResourceType: Int] {
        switch self {
        case .military(let type):
            return type.trainingCost
        case .villager:
            return [.food: 50]
        }
    }
    
    var trainingTime: TimeInterval {
        switch self {
        case .military(let type):
            return type.trainingTime
        case .villager:
            return 15.0
        }
    }
    
    var description: String {
        switch self {
        case .military(let type):
            return type.description
        case .villager:
            return "Gathers resources and constructs buildings"
        }
    }
}

enum MilitaryUnitType: String, CaseIterable {
    case swordsman = "Swordsman"
    case pikeman = "Pikeman"
    case archer = "Archer"
    case knight = "Knight"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .swordsman: return "🗡️"
        case .pikeman: return "🔱"
        case .archer: return "🏹"
        case .knight: return "🐴"
        }
    }
    
    var trainingBuilding: BuildingType {
        switch self {
        case .swordsman, .pikeman:
            return .barracks
        case .archer:
            return .archeryRange
        case .knight:
            return .stable
        }
    }
    
    var trainingCost: [ResourceType: Int] {
        switch self {
        case .swordsman:
            return [.food: 5, .ore: 2]
        case .pikeman:
            return [.food: 45, .wood: 25]
        case .archer:
            return [.food: 40, .wood: 35]
        case .knight:
            return [.food: 80, .ore: 40]
        }
    }
    
    var trainingTime: TimeInterval {
        switch self {
        case .swordsman: return 1
        case .pikeman: return 20.0
        case .archer: return 22.0
        case .knight: return 35.0
        }
    }
    
    var attackPower: Double {
        switch self {
        case .swordsman: return 12
        case .pikeman: return 15
        case .archer: return 8
        case .knight: return 20
        }
    }
    
    var defensePower: Double {
        switch self {
        case .swordsman: return 10
        case .pikeman: return 8
        case .archer: return 5
        case .knight: return 12
        }
    }
    
    var moveSpeed: TimeInterval {
        switch self {
        case .swordsman: return 0.35
        case .pikeman: return 0.40
        case .archer: return 0.35
        case .knight: return 0.25
        }
    }
    
    var description: String {
        switch self {
        case .swordsman:
            return "Balanced melee infantry unit"
        case .pikeman:
            return "Anti-cavalry infantry with longer reach"
        case .archer:
            return "Ranged unit effective against infantry"
        case .knight:
            return "Fast and powerful mounted unit"
        }
    }
}

// MARK: - Training Queue Entry

struct TrainingQueueEntry {
    let id: UUID
    let unitType: MilitaryUnitType
    let quantity: Int
    let startTime: TimeInterval
    var progress: Double = 0.0
    
    init(unitType: MilitaryUnitType, quantity: Int, startTime: TimeInterval) {
        self.id = UUID()
        self.unitType = unitType
        self.quantity = quantity
        self.startTime = startTime
        self.progress = 0.0
    }
    
    func getTimeRemaining(currentTime: TimeInterval) -> TimeInterval {
        let elapsed = currentTime - startTime
        let totalTime = unitType.trainingTime * Double(quantity)
        return max(0, totalTime - elapsed)
    }
    
    func getProgress(currentTime: TimeInterval) -> Double {
        let elapsed = currentTime - startTime
        let totalTime = unitType.trainingTime * Double(quantity)
        return min(1.0, elapsed / totalTime)
    }
    
    func getUnitsCompleted(currentTime: TimeInterval) -> Int {
        let elapsed = currentTime - startTime
        let unitsCompleted = Int(elapsed / unitType.trainingTime)
        return min(quantity, unitsCompleted)
    }
}
