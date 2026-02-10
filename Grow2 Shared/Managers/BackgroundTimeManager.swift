// ============================================================================
// FILE: BackgroundTimeManager.swift
// LOCATION: Create as new file
// ============================================================================

import Foundation

/// Handles calculation of game progress during time when app was closed
class BackgroundTimeManager {
    
    static let shared = BackgroundTimeManager()
    
    private let lastExitTimeKey = "lastExitTime"
    
    /// Save the current time when app goes to background
    func saveExitTime() {
        let currentTime = Date().timeIntervalSince1970
        UserDefaults.standard.set(currentTime, forKey: lastExitTimeKey)
        debugLog("📱 App going to background at: \(currentTime)")
    }
    
    /// Calculate elapsed time since last exit and apply it to game state
    func processBackgroundTime(player: Player, hexMap: HexMap, allPlayers: [Player]) {
        guard let lastExitTime = UserDefaults.standard.object(forKey: lastExitTimeKey) as? TimeInterval else {
            debugLog("ℹ️ No previous exit time found")
            return
        }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsedTime = currentTime - lastExitTime
        
        // Only process if more than 1 second has passed
        guard elapsedTime > 1.0 else {
            debugLog("⏱️ Less than 1 second elapsed, skipping background processing")
            return
        }
        
        debugLog("⏰ Processing \(Int(elapsedTime)) seconds of background time...")
        
        // Process resource collection
        processResourceGeneration(player: player, elapsedTime: elapsedTime)
        
        // Process building construction
        processBuildingConstruction(hexMap: hexMap, elapsedTime: elapsedTime, currentTime: currentTime)
        
        // Process unit training
        processUnitTraining(hexMap: hexMap, currentTime: currentTime)
         
        processBuildingUpgrades(hexMap: hexMap, currentTime: currentTime)
        processResearch(currentTime: currentTime)
        
        // Clear the saved time
        UserDefaults.standard.removeObject(forKey: lastExitTimeKey)
        
        debugLog("✅ Background time processing complete")
    }
    
    private func processResearch(currentTime: TimeInterval) {
        debugLog("🔬 Processing research...")
        
        let manager = ResearchManager.shared
        
        if let active = manager.activeResearch {
            if active.isComplete(currentTime: currentTime) {
                manager.completeResearch(active.researchType)
                debugLog("  ✅ Research completed: \(active.researchType.displayName)")
            } else {
                let progress = Int(active.getProgress(currentTime: currentTime) * 100)
                debugLog("  🔬 \(active.researchType.displayName): \(progress)% complete")
            }
        } else {
            debugLog("  No active research")
        }
    }
    
    private func processResourceGeneration(player: Player, elapsedTime: TimeInterval) {
        debugLog("💰 Calculating resource generation...")
        
        var resourcesGained: [ResourceType: Int] = [:]
        
        for resourceType in ResourceType.allCases {
            let rate = player.getCollectionRate(resourceType)
            let generated = rate * elapsedTime
            let wholeAmount = Int(generated)
            
            if wholeAmount > 0 {
                player.addResource(resourceType, amount: wholeAmount)
                resourcesGained[resourceType] = wholeAmount
            }
        }
        
        // Log what was gained
        for (type, amount) in resourcesGained {
            debugLog("  +\(amount) \(type.icon) \(type.displayName)")
        }
        
        // Remove food from population
        let foodConsumption = player.getFoodConsumptionRate() * elapsedTime
        let wholeConsumption = Int(foodConsumption)
        if wholeConsumption > 0 {
            let currentFood = player.getResource(.food)
            let consumed = min(currentFood, wholeConsumption)
            player.removeResource(.food, amount: consumed)
            debugLog("  -\(consumed) 🌾 Food (population consumption)")
        }
    }
    
    private func processBuildingConstruction(hexMap: HexMap, elapsedTime: TimeInterval, currentTime: TimeInterval) {
        debugLog("🏗️ Processing building construction...")
        
        var completedBuildings: [BuildingNode] = []
        
        for building in hexMap.buildings where building.state == .constructing {
            guard building.buildersAssigned > 0 else { continue }  // stalled

            // Use the incremental HP model to catch up elapsed time
            let lastUpdate = building.lastConstructionUpdateTime ?? building.constructionStartTime ?? currentTime
            let delta = currentTime - lastUpdate
            guard delta > 0 else { continue }

            let baseHPRate = building.maxHealth / building.buildingType.buildTime
            let effective = GameConfig.Construction.effectiveBuilders(count: building.buildersAssigned)
            let hpGain = baseHPRate * effective * delta
            building.constructionHP = min(building.maxHealth, building.constructionHP + hpGain)
            building.constructionProgress = building.constructionHP / building.maxHealth
            building.lastConstructionUpdateTime = currentTime

            if building.constructionHP >= building.maxHealth {
                building.completeConstruction()
                completedBuildings.append(building)
                debugLog("  ✅ \(building.buildingType.displayName) completed!")
            }
        }
        
        if completedBuildings.isEmpty {
            debugLog("  No buildings completed")
        }
    }
    
    private func processUnitTraining(hexMap: HexMap, currentTime: TimeInterval) {
        debugLog("🎖️ Processing unit training...")
        
        var totalUnitsCompleted = 0
        
        for building in hexMap.buildings where building.state == .completed {
            // Process military unit training
            if !building.trainingQueue.isEmpty {
                var completedIndices: [Int] = []
                
                for (index, entry) in building.trainingQueue.enumerated() {
                    let progress = entry.getProgress(currentTime: currentTime)
                    
                    if progress >= 1.0 {
                        building.addToGarrison(unitType: entry.unitType, quantity: entry.quantity)
                        completedIndices.append(index)
                        totalUnitsCompleted += entry.quantity
                        debugLog("  ✅ \(entry.quantity)x \(entry.unitType.displayName) trained at \(building.buildingType.displayName)")
                    }
                }
                
                for index in completedIndices.reversed() {
                    building.trainingQueue.remove(at: index)
                }
            }
            
            // Process villager training
            if !building.villagerTrainingQueue.isEmpty {
                var completedIndices: [Int] = []
                
                for (index, entry) in building.villagerTrainingQueue.enumerated() {
                    let progress = entry.getProgress(currentTime: currentTime)
                    
                    if progress >= 1.0 {
                        building.addVillagersToGarrison(quantity: entry.quantity)
                        completedIndices.append(index)
                        totalUnitsCompleted += entry.quantity
                        debugLog("  ✅ \(entry.quantity)x Villagers trained at \(building.buildingType.displayName)")
                    }
                }
                
                for index in completedIndices.reversed() {
                    building.villagerTrainingQueue.remove(at: index)
                }
            }
        }
        
        if totalUnitsCompleted == 0 {
            debugLog("  No units completed training")
        }
    }
    
    /// Get a human-readable summary of what happened during background time
    func getBackgroundSummary(player: Player, hexMap: HexMap) -> String? {
        guard let lastExitTime = UserDefaults.standard.object(forKey: lastExitTimeKey) as? TimeInterval else {
            return nil
        }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsedTime = currentTime - lastExitTime
        
        guard elapsedTime > 60.0 else { // Only show summary if more than 1 minute passed
            return nil
        }
        
        var summary = "⏰ While you were away (\(formatElapsedTime(elapsedTime))):\n\n"
        
        // Calculate resources that would be gained
        var hasResources = false
        for resourceType in ResourceType.allCases {
            let rate = player.getCollectionRate(resourceType)
            let generated = Int(rate * elapsedTime)
            if generated > 0 {
                summary += "💰 +\(generated) \(resourceType.icon) \(resourceType.displayName)\n"
                hasResources = true
            }
        }
        
        // Check for completed buildings
        var completedCount = 0
        for building in hexMap.buildings where building.state == .constructing {
            if let startTime = building.constructionStartTime {
                let totalElapsed = currentTime - startTime
                let effectiveBuildTime = building.buildingType.buildTime
                if totalElapsed >= effectiveBuildTime {
                    completedCount += 1
                }
            }
        }
        
        if completedCount > 0 {
            summary += "\n🏗️ \(completedCount) building(s) completed construction\n"
        }
        
        return hasResources || completedCount > 0 ? summary : nil
    }
    
    private func formatElapsedTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes) minutes"
        } else {
            return "\(Int(seconds)) seconds"
        }
    }
    
    func getElapsedTime() -> TimeInterval? {
        guard let lastExitTime = UserDefaults.standard.object(forKey: lastExitTimeKey) as? TimeInterval else {
            return nil
        }
        
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - lastExitTime
        
        // Only return if meaningful time passed
        guard elapsed > 1 else { return nil }
        
        return elapsed
    }

    /// Clears the saved exit time (call after processing)
    func clearExitTime() {
        UserDefaults.standard.removeObject(forKey: lastExitTimeKey)
        debugLog("📱 Cleared exit time")
    }
    
    private func processBuildingUpgrades(hexMap: HexMap, currentTime: TimeInterval) {
            debugLog("⬆️ Processing building upgrades...")
            
            var completedUpgrades: [BuildingNode] = []
            
            for building in hexMap.buildings where building.state == .upgrading {
                guard let startTime = building.upgradeStartTime,
                      let upgradeTime = building.getUpgradeTime() else { continue }
                
                let totalElapsed = currentTime - startTime
                let newProgress = min(1.0, totalElapsed / upgradeTime)
                building.upgradeProgress = newProgress
                
                if newProgress >= 1.0 {
                    building.completeUpgrade()
                    completedUpgrades.append(building)
                    debugLog("  ✅ \(building.buildingType.displayName) upgraded to level \(building.level)!")
                }
            }
        }
}

