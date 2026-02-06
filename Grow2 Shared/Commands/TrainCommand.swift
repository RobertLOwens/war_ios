// ============================================================================
// FILE: Grow2 Shared/Commands/TrainCommands.swift
// PURPOSE: Commands for training units
// ============================================================================

import Foundation

// MARK: - Train Military Units

struct TrainMilitaryCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let buildingID: UUID
    let unitType: MilitaryUnitType
    let quantity: Int
    
    static var commandType: CommandType { .trainMilitary }
    
    init(playerID: UUID, buildingID: UUID, unitType: MilitaryUnitType, quantity: Int) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
        self.unitType = unitType
        self.quantity = quantity
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }
        
        guard let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building not found")
        }
        
        guard building.owner?.id == playerID else {
            return .failure(reason: "You don't own this building")
        }
        
        guard building.canTrain(unitType) else {
            return .failure(reason: "This building cannot train \(unitType.displayName)")
        }
        
        // Check population cap
        guard player.hasPopulationSpace(for: quantity) else {
            let available = player.getAvailablePopulation()
            return .failure(reason: "Population cap reached. Available: \(available)")
        }
        
        // Get adjacency cost reduction (warehouse bonus)
        let costReduction = AdjacencyBonusManager.shared.getTrainingCostReduction(for: building.data.id)
        let costMultiplier = 1.0 - costReduction

        // Check resources with adjacency discount applied
        for (resourceType, baseCost) in unitType.trainingCost {
            let discountedCost = Int(ceil(Double(baseCost) * costMultiplier))
            let totalCost = discountedCost * quantity
            if !player.hasResource(resourceType, amount: totalCost) {
                return .failure(reason: "Insufficient \(resourceType.displayName)")
            }
        }

        return .success
    }

    func execute(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID),
              let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building or player not found")
        }

        // Get adjacency cost reduction (warehouse bonus)
        let costReduction = AdjacencyBonusManager.shared.getTrainingCostReduction(for: building.data.id)
        let costMultiplier = 1.0 - costReduction

        // Deduct resources with adjacency discount applied
        for (resourceType, baseCost) in unitType.trainingCost {
            let discountedCost = Int(ceil(Double(baseCost) * costMultiplier))
            let totalCost = discountedCost * quantity
            player.removeResource(resourceType, amount: totalCost)
        }
        
        // Start training
        building.startTraining(unitType: unitType, quantity: quantity, at: timestamp)

        context.onResourcesChanged?()

        if costReduction > 0 {
            debugLog("🎓 Training \(quantity)x \(unitType.displayName) at \(building.buildingType.displayName) (-\(Int(costReduction * 100))% warehouse bonus)")
        } else {
            debugLog("🎓 Training \(quantity)x \(unitType.displayName) at \(building.buildingType.displayName)")
        }

        return .success
    }
}

// MARK: - Train Villagers

struct TrainVillagerCommand: GameCommand {
    let id: UUID
    let timestamp: TimeInterval
    let playerID: UUID
    
    let buildingID: UUID
    let quantity: Int
    
    static var commandType: CommandType { .trainVillager }
    
    init(playerID: UUID, buildingID: UUID, quantity: Int) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.playerID = playerID
        self.buildingID = buildingID
        self.quantity = quantity
    }
    
    func validate(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID) else {
            return .failure(reason: "Player not found")
        }
        
        guard let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building not found")
        }
        
        guard building.canTrainVillagers() else {
            return .failure(reason: "This building cannot train villagers")
        }
        
        guard player.hasPopulationSpace(for: quantity) else {
            return .failure(reason: "Population cap reached")
        }
        
        // Villager cost: 50 food each
        let foodCost = 50 * quantity
        guard player.hasResource(.food, amount: foodCost) else {
            return .failure(reason: "Need \(foodCost) food")
        }
        
        return .success
    }
    
    func execute(in context: CommandContext) -> CommandResult {
        guard let player = context.getPlayer(by: playerID),
              let building = context.getBuilding(by: buildingID) else {
            return .failure(reason: "Building or player not found")
        }
        
        // Deduct food
        let foodCost = 50 * quantity
        player.removeResource(.food, amount: foodCost)
        
        // Start training
        building.startVillagerTraining(quantity: quantity, at: timestamp)
        
        context.onResourcesChanged?()
        
        debugLog("🎓 Training \(quantity)x Villagers at \(building.buildingType.displayName)")
        
        return .success
    }
}
