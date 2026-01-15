// ============================================================================
// FILE: ResearchManager.swift
// LOCATION: Grow2 Shared/ResearchManager.swift (new file)
// ============================================================================

import Foundation

// MARK: - Research Manager

class ResearchManager {
    
    static let shared = ResearchManager()
    
    // Completed research for the current player
    private(set) var completedResearch: Set<ResearchType> = []
    
    // Currently researching (only one at a time for now)
    private(set) var activeResearch: ActiveResearch?
    
    // Cached bonuses (recalculated when research completes)
    private var cachedBonuses: [ResearchBonusType: Double] = [:]
    
    // Weak reference to player (set when game loads)
    weak var player: Player?
    
    private init() {}
    
    // MARK: - Setup
    
    func setup(player: Player) {
        self.player = player
        recalculateBonuses()
    }
    
    func reset() {
        completedResearch.removeAll()
        activeResearch = nil
        cachedBonuses.removeAll()
        player = nil
    }
    
    // MARK: - Research Status
    
    func isResearched(_ researchType: ResearchType) -> Bool {
        return completedResearch.contains(researchType)
    }
    
    func isResearching(_ researchType: ResearchType) -> Bool {
        return activeResearch?.researchType == researchType
    }
    
    func isAvailable(_ researchType: ResearchType) -> Bool {
        // Already researched
        if isResearched(researchType) { return false }
        
        // Currently researching something else
        if activeResearch != nil && !isResearching(researchType) { return false }
        
        // Check prerequisites
        for prereq in researchType.prerequisites {
            if !isResearched(prereq) { return false }
        }
        
        // Check building requirement
        if let (buildingType, level) = researchType.buildingRequirement {
            guard let player = player else { return false }
            let hasBuilding = player.buildings.contains { 
                $0.buildingType == buildingType && 
                $0.level >= level && 
                $0.isOperational 
            }
            if !hasBuilding { return false }
        }
        
        return true
    }
    
    func canAfford(_ researchType: ResearchType) -> Bool {
        guard let player = player else { return false }
        
        for (resourceType, amount) in researchType.cost {
            if !player.hasResource(resourceType, amount: amount) {
                return false
            }
        }
        return true
    }
    
    func getMissingResources(for researchType: ResearchType) -> [ResourceType: Int] {
        guard let player = player else { return researchType.cost }
        
        var missing: [ResourceType: Int] = [:]
        for (resourceType, amount) in researchType.cost {
            let current = player.getResource(resourceType)
            if current < amount {
                missing[resourceType] = amount - current
            }
        }
        return missing
    }
    
    // MARK: - Start Research
    
    func startResearch(_ researchType: ResearchType) -> Bool {
        guard isAvailable(researchType) else {
            print("❌ Research not available: \(researchType.displayName)")
            return false
        }
        
        guard canAfford(researchType) else {
            print("❌ Cannot afford research: \(researchType.displayName)")
            return false
        }
        
        guard let player = player else {
            print("❌ No player set for research")
            return false
        }
        
        // Deduct resources
        for (resourceType, amount) in researchType.cost {
            player.removeResource(resourceType, amount: amount)
        }
        
        // Start research
        activeResearch = ActiveResearch(researchType: researchType)
        
        print("🔬 Started research: \(researchType.displayName)")
        print("   Cost: \(researchType.costString)")
        print("   Time: \(researchType.timeString)")
        
        return true
    }
    
    // MARK: - Cancel Research
    
    func cancelResearch() -> Bool {
        guard let active = activeResearch, let player = player else {
            return false
        }
        
        // Refund 50% of resources
        for (resourceType, amount) in active.researchType.cost {
            let refund = amount / 2
            player.addResource(resourceType, amount: refund)
        }
        
        activeResearch = nil
        
        print("❌ Cancelled research: \(active.researchType.displayName)")
        return true
    }
    
    // MARK: - Complete Research
    
    func completeResearch(_ researchType: ResearchType) {
        completedResearch.insert(researchType)
        
        if activeResearch?.researchType == researchType {
            activeResearch = nil
        }
        
        recalculateBonuses()
        
        print("✅ Research completed: \(researchType.displayName)")
        for bonus in researchType.bonuses {
            print("   \(bonus.displayString)")
        }
        
        // Post notification
        NotificationCenter.default.post(
            name: .researchDidComplete,
            object: self,
            userInfo: ["researchType": researchType]
        )
    }
    
    // MARK: - Update (called from game loop)
    
    func update(currentTime: TimeInterval = Date().timeIntervalSince1970) {
        guard let active = activeResearch else { return }
        
        if active.isComplete(currentTime: currentTime) {
            completeResearch(active.researchType)
        }
    }
    
    // MARK: - Bonuses
    
    private func recalculateBonuses() {
        cachedBonuses.removeAll()
        
        for research in completedResearch {
            for bonus in research.bonuses {
                cachedBonuses[bonus.type, default: 0] += bonus.value
            }
        }
        
        print("🔬 Recalculated research bonuses:")
        for (type, value) in cachedBonuses {
            print("   \(type.displayName): +\(Int(value * 100))%")
        }
    }
    
    func getBonus(_ type: ResearchBonusType) -> Double {
        return cachedBonuses[type] ?? 0.0
    }
    
    /// Returns the multiplier for a bonus type (1.0 + bonus)
    func getBonusMultiplier(_ type: ResearchBonusType) -> Double {
        return 1.0 + getBonus(type)
    }
    
    // Convenience methods for specific bonuses
    func getWoodGatheringMultiplier() -> Double {
        return getBonusMultiplier(.woodGatheringRate)
    }
    
    func getFoodGatheringMultiplier() -> Double {
        return getBonusMultiplier(.foodGatheringRate)
    }
    
    func getStoneGatheringMultiplier() -> Double {
        return getBonusMultiplier(.stoneGatheringRate)
    }
    
    func getOreGatheringMultiplier() -> Double {
        return getBonusMultiplier(.oreGatheringRate)
    }
    
    func getBuildingSpeedMultiplier() -> Double {
        return getBonusMultiplier(.buildingSpeed)
    }
    
    func getTrainingSpeedMultiplier() -> Double {
        return getBonusMultiplier(.trainingSpeed)
    }
    
    // MARK: - Save/Load Support
    
    struct ResearchSaveData: Codable {
        let completedResearch: [String]  // ResearchType raw values
        let activeResearchType: String?
        let activeResearchStartTime: TimeInterval?
    }
    
    func getSaveData() -> ResearchSaveData {
        return ResearchSaveData(
            completedResearch: completedResearch.map { $0.rawValue },
            activeResearchType: activeResearch?.researchType.rawValue,
            activeResearchStartTime: activeResearch?.startTime
        )
    }
    
    func loadSaveData(_ data: ResearchSaveData) {
        // Load completed research
        completedResearch.removeAll()
        for rawValue in data.completedResearch {
            if let researchType = ResearchType(rawValue: rawValue) {
                completedResearch.insert(researchType)
            }
        }
        
        // Load active research
        if let activeTypeRaw = data.activeResearchType,
           let activeType = ResearchType(rawValue: activeTypeRaw),
           let startTime = data.activeResearchStartTime {
            activeResearch = ActiveResearch(researchType: activeType, startTime: startTime)
        } else {
            activeResearch = nil
        }
        
        recalculateBonuses()
        
        print("📂 Loaded research state:")
        print("   Completed: \(completedResearch.count)")
        print("   Active: \(activeResearch?.researchType.displayName ?? "None")")
    }
    
    // MARK: - Debug
    
    func printStatus() {
        print("\n🔬 Research Status:")
        print("   Completed: \(completedResearch.map { $0.displayName }.joined(separator: ", "))")
        if let active = activeResearch {
            let progress = Int(active.getProgress() * 100)
            let remaining = Int(active.getRemainingTime())
            print("   Active: \(active.researchType.displayName) (\(progress)%, \(remaining)s remaining)")
        } else {
            print("   Active: None")
        }
        print("   Bonuses:")
        for (type, value) in cachedBonuses {
            print("      \(type.displayName): +\(Int(value * 100))%")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let researchDidComplete = Notification.Name("researchDidComplete")
    static let researchDidStart = Notification.Name("researchDidStart")
}
