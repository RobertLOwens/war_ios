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
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .trees: return "🌲"
        case .forage: return "🍄"
        case .oreMine: return "⛏️"
        case .stoneQuarry: return "🪨"
        case .deer: return "🦌"
        case .wildBoar: return "🐗"
        }
    }
    
    var resourceYield: ResourceType {
        switch self {
        case .trees: return .wood
        case .forage: return .food
        case .oreMine: return .ore
        case .stoneQuarry: return .stone
        case .deer, .wildBoar: return .food
        }
    }
    
    var initialAmount: Int {
        switch self {
        case .trees: return 500
        case .forage: return 300
        case .oreMine: return 800
        case .stoneQuarry: return 600
        case .deer: return 200
        case .wildBoar: return 150
        }
    }
    
    var gatherRate: Double {
        switch self {
        case .trees: return 5.0 // 5 wood per second
        case .forage: return 3.0 // 3 food per second
        case .oreMine: return 2.0 // 2 ore per second
        case .stoneQuarry: return 2.5 // 2.5 stone per second
        case .deer: return 0 // Instant when hunted
        case .wildBoar: return 0 // Instant when hunted
        }
    }
    
    var requiredTerrain: TerrainType? {
        switch self {
        case .forage: return .forest
        case .oreMine, .stoneQuarry: return .mountain
        case .trees, .deer, .wildBoar: return nil // Can appear on any walkable terrain
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
         self.isUserInteractionEnabled = false  // ✅ ADD THIS LINE - allows touches to pass through
         
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
            case .deer:
                bgColor = UIColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0)
            case .wildBoar:
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
        amountLabel.addChild(shadow)
        
        addChild(amountLabel)
    }
    
    // Add method to set remaining amount (for loading saves)
    func setRemainingAmount(_ amount: Int) {
        remainingAmount = max(0, min(amount, resourceType.initialAmount))
        updateLabel()
    }

    // Add method to set current health (for loading saves)
    func setCurrentHealth(_ health: Double) {
        currentHealth = max(0, min(health, resourceType.health))
    }
    
    func updateLabel() {
        if let label = childNode(withName: "amountLabel") as? SKLabelNode {
            label.text = "\(remainingAmount)"
            if let shadow = label.childNode(withName: "//shadow") as? SKLabelNode {
                shadow.text = "\(remainingAmount)"
            }
        }
    }
    
    func gather(amount: Int) -> Int {
        let gathered = min(amount, remainingAmount)
        remainingAmount = max(0, remainingAmount - gathered)
        updateLabel()
        
        if remainingAmount == 0 {
            // Fade out and remove
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
        isBeingGathered = true
        assignedVillagerGroup = villagerGroup
    }
    
    func stopGathering() {
        isBeingGathered = false
        assignedVillagerGroup = nil
    }
    
    func getDescription() -> String {
        var desc = "\(resourceType.icon) \(resourceType.displayName)\n"
        desc += "Remaining: \(remainingAmount)/\(resourceType.initialAmount)\n"
        desc += "Yields: \(resourceType.resourceYield.icon) \(resourceType.resourceYield.displayName)"
        
        if resourceType.isHuntable {
            desc += "\n\nHealth: \(currentHealth)/\(resourceType.health)"
            desc += "\n⚔️ Attack: \(resourceType.attackPower)"
            desc += "\n🛡️ Defense: \(resourceType.defensePower)"
        } else {
            desc += "\nGather Rate: \(resourceType.gatherRate)/s"
        }
        
        if isBeingGathered {
            desc += "\n\n🔨 Being gathered by \(assignedVillagerGroup?.name ?? "villagers")"
        }
        
        return desc
    }
}
