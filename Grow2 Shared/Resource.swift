// ============================================================================
// FILE: Resource.swift
// LOCATION: Create as new file
// ============================================================================

import Foundation
import SpriteKit
import UIKit

// MARK: - Resource Point Type

enum ResourcePointType: String, CaseIterable {
    
    case trees = "Trees"
    case forage = "Forage"
    case oreMine = "Ore Mine"
    case stoneQuarry = "Stone Quarry"
    case deer = "Deer"
    case wildBoar = "Wild Boar"
    case deerCarcass = "Deer Carcass"
    case boarCarcass = "Boar Carcass"
    case farmland = "Farmland"  // ✅ NEW

    
    var displayName: String {
        return rawValue
    }
    
    // MARK: - UPDATE: icon computed property
    // LOCATION: Inside ResourcePointType enum, add cases to icon

    var icon: String {
        switch self {
        case .trees: return "🌲"
        case .forage: return "🍄"
        case .oreMine: return "⛏️"
        case .stoneQuarry: return "🪨"
        case .deer: return "🦌"
        case .wildBoar: return "🐗"
        case .deerCarcass: return "🥩"
        case .boarCarcass: return "🥩"
        case .farmland: return "🌾"

        }
    }

    // MARK: - UPDATE: resourceYield computed property
    // LOCATION: Inside ResourcePointType enum, add cases

    var resourceYield: ResourceType {
        switch self {
        case .trees: return .wood
        case .forage: return .food
        case .oreMine: return .ore
        case .stoneQuarry: return .stone
        case .deer, .wildBoar, .deerCarcass, .boarCarcass, .farmland: return .food
        }
    }

    // MARK: - UPDATE: initialAmount computed property
    // LOCATION: Inside ResourcePointType enum, add cases

    var initialAmount: Int {
        switch self {
        case .trees: return 5000
        case .forage: return 3000
        case .oreMine: return 8000
        case .stoneQuarry: return 6000
        case .deer: return 2000
        case .wildBoar: return 1500
        case .deerCarcass: return 2000  // Same as deer
        case .boarCarcass: return 1500
        case .farmland: return 999999
        }
    }

    // MARK: - UPDATE: gatherRate computed property (BASE rate - will be modified by villager count)
    // LOCATION: Inside ResourcePointType enum

    var baseGatherRate: Double {
        switch self {
        case .trees: return 0.5          // Base rate, multiplied by villagers
        case .forage: return 0.5
        case .oreMine: return 0.5
        case .stoneQuarry: return 0.5
        case .deer: return 0.0           // Can't gather live animals
        case .wildBoar: return 0.0
        case .deerCarcass: return 0.5    // Gather rate for carcasses
        case .boarCarcass: return 0.5
        case .farmland: return 0.1
        }
    }

    // MARK: - ADD: New property to check if resource requires a camp
    // LOCATION: Inside ResourcePointType enum, after isHuntable

    var requiresCamp: Bool {
        switch self {
        case .trees, .oreMine, .stoneQuarry: return true
        case .forage, .deer, .wildBoar, .deerCarcass, .boarCarcass, .farmland: return false
        }
    }
        
    var isCarcass: Bool {
        switch self {
        case .deerCarcass, .boarCarcass: return true
        default: return false
        }
    }
        
    var isGatherable: Bool {
        switch self {
        case .deer, .wildBoar: return false  // Must hunt first
        default: return true
        }
    }

    // MARK: - ADD: Required camp type for this resource
    // LOCATION: Inside ResourcePointType enum

    var requiredCampType: BuildingType? {
        switch self {
        case .trees: return .lumberCamp
        case .oreMine, .stoneQuarry: return .miningCamp
        default: return nil
        }
    }
    
    var requiredTerrain: TerrainType? {
        switch self {
        case .forage: return .plains  // Forage now spawns on plains (was forest)
        case .oreMine, .stoneQuarry: return .mountain
        case .trees, .deer, .wildBoar, .boarCarcass, .deerCarcass, .farmland: return nil // Can appear on any walkable terrain
        }
    }
    
    var isHuntable: Bool {
        switch self {
        case .deer, .wildBoar: return true
        default: return false
        }
    }
    
    // Combat stats for huntable animals
    var attackPower: Double {
        switch self {
        case .deer: return 2
        case .wildBoar: return 8
        default: return 0
        }
    }
    
    var defensePower: Double {
        switch self {
        case .deer: return 3
        case .wildBoar: return 5
        default: return 0
        }
    }
    
    var health: Double {
        switch self {
        case .deer: return 30
        case .wildBoar: return 50
        default: return 0
        }
    }
}

// MARK: - Resource Point Node

class ResourcePointNode: SKSpriteNode {
    let resourceType: ResourcePointType
    var coordinate: HexCoordinate
    private(set) var remainingAmount: Int
    private(set) var isBeingGathered: Bool = false
    private(set) var currentHealth: Double
    static let maxVillagersPerTile = 20
    private(set) var assignedVillagerGroups: [VillagerGroup] = []
    
    weak var assignedVillagerGroup: VillagerGroup?
    
    init(coordinate: HexCoordinate, resourceType: ResourcePointType) {
         self.coordinate = coordinate
         self.resourceType = resourceType
         self.remainingAmount = resourceType.initialAmount
         self.currentHealth = resourceType.health
         
         let texture = ResourcePointNode.createResourceTexture(for: resourceType)
         super.init(texture: texture, color: .clear, size: CGSize(width: 32, height: 32))
         
         self.zPosition = 3
         self.name = "resourcePoint"
         
         setupLabel()
     }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func createResourceTexture(for type: ResourcePointType) -> SKTexture {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Background color based on resource type
            let bgColor: UIColor
            switch type {
            case .trees:
                bgColor = UIColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)
            case .forage:
                bgColor = UIColor(red: 0.6, green: 0.4, blue: 0.3, alpha: 1.0)
            case .oreMine:
                bgColor = UIColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0)
            case .stoneQuarry:
                bgColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            case .deer, .deerCarcass:
                bgColor = UIColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0)
            case .wildBoar, .boarCarcass:
                bgColor = UIColor(red: 0.5, green: 0.3, blue: 0.2, alpha: 1.0)
            case .farmland:
                bgColor = UIColor(red: 0.5, green: 0.3, blue: 0.2, alpha: 1.0)
            }
            
            // Draw circle
            bgColor.setFill()
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
            
            // Draw border
            UIColor.white.setStroke()
            context.cgContext.setLineWidth(2)
            context.cgContext.strokeEllipse(in: rect.insetBy(dx: 2, dy: 2))
            
            // Draw icon
            let icon = type.icon
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.white
            ]
            let iconString = NSAttributedString(string: icon, attributes: attributes)
            let iconSize = iconString.size()
            let iconRect = CGRect(
                x: (size.width - iconSize.width) / 2,
                y: (size.height - iconSize.height) / 2,
                width: iconSize.width,
                height: iconSize.height
            )
            iconString.draw(in: iconRect)
        }
        
        return SKTexture(image: image)
    }
    
    private func setupLabel() {
        let amountLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        amountLabel.fontSize = 10
        amountLabel.fontColor = .white
        amountLabel.text = "\(remainingAmount)"
        amountLabel.position = CGPoint(x: 0, y: -20)
        amountLabel.zPosition = 1
        amountLabel.name = "amountLabel"
        
        // Add shadow
        let shadow = SKLabelNode(fontNamed: "Menlo-Bold")
        shadow.fontSize = 10
        shadow.fontColor = UIColor(white: 0, alpha: 0.7)
        shadow.text = "\(remainingAmount)"
        shadow.position = CGPoint(x: 1, y: -1)
        shadow.zPosition = -1
        shadow.name = "shadow"  // Name required for updateLabel() to find and update it
        amountLabel.addChild(shadow)
        
        addChild(amountLabel)
    }
    
    var currentGatherRate: Double {
        let villagerCount = getTotalVillagersGathering()
        let perVillagerRate = 0.2  // Each villager adds 0.2 per second
        let baseRate = resourceType.baseGatherRate + (Double(villagerCount) * perVillagerRate)

        // Apply research bonuses based on resource type
        let researchManager = ResearchManager.shared
        var multiplier = 1.0

        switch resourceType {
        case .farmland:
            // Farm Efficiency research
            multiplier = researchManager.getFarmGatheringMultiplier()
        case .trees:
            // Lumber Camp Efficiency research
            multiplier = researchManager.getLumberCampGatheringMultiplier()
        case .oreMine, .stoneQuarry:
            // Mining Camp Efficiency research
            multiplier = researchManager.getMiningCampGatheringMultiplier()
        default:
            break
        }

        return baseRate * multiplier
    }
    
    func canAddVillagers(_ count: Int) -> Bool {
        return getTotalVillagersGathering() + count <= ResourcePointNode.maxVillagersPerTile
    }
    
    func getRemainingCapacity() -> Int {
        return max(0, ResourcePointNode.maxVillagersPerTile - getTotalVillagersGathering())
    }

    
    func getTotalVillagersGathering() -> Int {
        return assignedVillagerGroups.reduce(0) { $0 + $1.villagerCount }
    }
    
    // Add method to set remaining amount (for loading saves)
    func setRemainingAmount(_ amount: Int) {
        let oldAmount = remainingAmount
        remainingAmount = max(0, amount)

        // Update label immediately (game loop already runs on main thread)
        updateLabel()

        // Debug logging for significant changes
        if abs(oldAmount - remainingAmount) > 10 {
            print("📦 Resource \(resourceType.displayName): \(oldAmount) → \(remainingAmount)")
        }

        // Check for depletion
        if remainingAmount <= 0 && oldAmount > 0 {
            print("⚠️ Resource depleted!")
        }
    }

    // Add method to set current health (for loading saves)
    func setCurrentHealth(_ health: Double) {
        currentHealth = max(0, min(health, resourceType.health))
    }
    
    func updateLabel() {
        if let label = children.first(where: { $0 is SKLabelNode }) as? SKLabelNode {
            let villagerCount = getTotalVillagersGathering()
            if villagerCount > 0 {
                label.text = "\(remainingAmount) 👷\(villagerCount)"
            } else {
                label.text = "\(remainingAmount)"
            }
            // Update shadow label (direct child of the main label)
            if let shadow = label.childNode(withName: "shadow") as? SKLabelNode {
                shadow.text = label.text
            }
        }
    }
    
    func gather(amount: Int) -> Int {
        let gathered = min(amount, remainingAmount)
        remainingAmount = max(0, remainingAmount - gathered)
        updateLabel()  // ✅ This should already exist - verify it's being called
        
        if remainingAmount == 0 {
            // Resource depleted - cleanup will be handled by GameScene update loop
            let fadeOut = SKAction.fadeOut(withDuration: 1.0)
            run(fadeOut) { [weak self] in
                self?.removeFromParent()
            }
        }
        
        return gathered
    }

    
    func takeDamage(_ damage: Double) -> Bool {
        guard resourceType.isHuntable else { return false }
        
        currentHealth = max(0, currentHealth - damage)
        
        if currentHealth <= 0 {
            // Animal killed - return true to indicate death
            return true
        }
        
        return false
    }
    
    func isDepleted() -> Bool {
        return remainingAmount <= 0
    }
    
    func canBeGathered() -> Bool {
        return remainingAmount > 0 && !isBeingGathered
    }
    
    func startGathering(by villagerGroup: VillagerGroup) {
            guard !assignedVillagerGroups.contains(where: { $0.id == villagerGroup.id }) else {
                print("⚠️ Villager group already gathering here")
                return
            }
            
            guard canAddVillagers(villagerGroup.villagerCount) else {
                print("❌ Too many villagers at this resource (max: \(ResourcePointNode.maxVillagersPerTile))")
                return
            }
            
            isBeingGathered = true
            assignedVillagerGroups.append(villagerGroup)
            updateLabel()
            
            print("✅ Added \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) to gather \(resourceType.displayName)")
            print("   Total villagers gathering: \(getTotalVillagersGathering())/\(ResourcePointNode.maxVillagersPerTile)")
        }

    
    func stopGathering(by villagerGroup: VillagerGroup? = nil) {
        if let group = villagerGroup {
            assignedVillagerGroups.removeAll { $0.id == group.id }
            print("✅ Removed \(group.name) from gathering")
        } else {
            assignedVillagerGroups.removeAll()
        }
        
        isBeingGathered = !assignedVillagerGroups.isEmpty
        updateLabel()
    }
    
    func getDescription() -> String {
            var desc = "\(resourceType.icon) \(resourceType.displayName)\n"
            desc += "Remaining: \(remainingAmount)/\(resourceType.initialAmount)\n"
            desc += "Yields: \(resourceType.resourceYield.icon) \(resourceType.resourceYield.displayName)"
            
            if resourceType.isHuntable {
                desc += "\n\nHealth: \(Int(currentHealth))/\(Int(resourceType.health))"
                desc += "\n⚔️ Attack: \(Int(resourceType.attackPower))"
                desc += "\n🛡️ Defense: \(Int(resourceType.defensePower))"
            } else if resourceType.isGatherable {
                let villagerCount = getTotalVillagersGathering()
                desc += "\n\n📊 Gather Rate: \(String(format: "%.1f", currentGatherRate))/s"
                desc += "\n👷 Villagers: \(villagerCount)/\(ResourcePointNode.maxVillagersPerTile)"
                
                if resourceType.requiresCamp {
                    desc += "\n⚠️ Requires \(resourceType.requiredCampType?.displayName ?? "Camp") nearby"
                }
            }
            
            if isBeingGathered && !assignedVillagerGroups.isEmpty {
                desc += "\n\n🔨 Being gathered by:"
                for group in assignedVillagerGroups {
                    desc += "\n  • \(group.name) (\(group.villagerCount))"
                }
            }
            
            return desc
        }
    
}
