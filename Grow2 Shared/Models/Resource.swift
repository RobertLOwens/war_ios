// ============================================================================
// FILE: Resource.swift
// PURPOSE: Visual layer for resource points (SpriteKit-based)
// NOTE: ResourcePointType is now defined in Data/ResourcePointData.swift
//       and accessed via TypeAliases.swift
// ============================================================================

import Foundation
import SpriteKit
import UIKit

// MARK: - Resource Point Node

class ResourcePointNode: SKSpriteNode {
    // MARK: - Data Layer (Single Source of Truth)
    let data: ResourcePointData

    // MARK: - Visual Layer Only
    private(set) var assignedVillagerGroups: [VillagerGroup] = []
    weak var assignedVillagerGroup: VillagerGroup?

    static let maxVillagersPerTile = 20

    // MARK: - Delegated Properties
    var id: UUID { data.id }

    var resourceType: ResourcePointType { data.resourceType }

    var coordinate: HexCoordinate {
        get { data.coordinate }
        set { data.coordinate = newValue }
    }

    var remainingAmount: Int { data.remainingAmount }

    var currentHealth: Double { data.currentHealth }

    var isBeingGathered: Bool { data.isBeingGathered() }

    // MARK: - Initialization

    init(coordinate: HexCoordinate, resourceType: ResourcePointType, data: ResourcePointData? = nil) {
        // Use provided data or create new
        if let existingData = data {
            self.data = existingData
        } else {
            self.data = ResourcePointData(coordinate: coordinate, resourceType: resourceType)
        }

        let texture = ResourcePointNode.createResourceTexture(for: resourceType)
        super.init(texture: texture, color: .clear, size: CGSize(width: 16, height: 16))

        // Set isometric z-position for depth sorting
        self.zPosition = HexTileNode.isometricZPosition(q: coordinate.q, r: coordinate.r, baseLayer: HexTileNode.ZLayer.resource)
        self.name = "resourcePoint"

        setupLabel()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func createResourceTexture(for type: ResourcePointType) -> SKTexture {
        let size = CGSize(width: 16, height: 16)
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
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 1, dy: 1))

            // Draw border
            UIColor.white.setStroke()
            context.cgContext.setLineWidth(1)
            context.cgContext.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))

            // Draw icon
            let icon = type.icon
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
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
        // Resource amount label removed from map display
    }
    
    var currentGatherRate: Double {
        let villagerCount = getTotalVillagersGathering()
        let perVillagerRate = 0.2  // Each villager adds 0.2 per second
        let baseRate = Double(villagerCount) * perVillagerRate

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
        return data.canAddVillagers(count)
    }

    func getRemainingCapacity() -> Int {
        return data.getRemainingCapacity()
    }

    func getTotalVillagersGathering() -> Int {
        // Use visual layer count (keeps track of actual VillagerGroup objects)
        return assignedVillagerGroups.reduce(0) { $0 + $1.villagerCount }
    }

    // Set remaining amount (for loading saves)
    func setRemainingAmount(_ amount: Int) {
        let oldAmount = remainingAmount
        data.setRemainingAmount(amount)

        // Update label immediately
        updateLabel()

        // Debug logging for significant changes
        if abs(oldAmount - data.remainingAmount) > 10 {
            debugLog("📦 Resource \(resourceType.displayName): \(oldAmount) → \(data.remainingAmount)")
        }

        // Check for depletion
        if data.remainingAmount <= 0 && oldAmount > 0 {
            debugLog("⚠️ Resource depleted!")
        }
    }

    // Set current health (for loading saves)
    func setCurrentHealth(_ health: Double) {
        data.setCurrentHealth(health)
    }
    
    func updateLabel() {
        // Resource amount label removed from map display
    }
    
    func gather(amount: Int) -> Int {
        let gathered = data.gather(amount: amount)
        updateLabel()
        // Note: Resource depletion cleanup is handled by GameVisualLayer.handleResourceDepleted()
        // to ensure consistent removal from both the scene and hexMap.resourcePoints array
        return gathered
    }

    func takeDamage(_ damage: Double) -> Bool {
        return data.takeDamage(damage)
    }

    func isDepleted() -> Bool {
        return data.isDepleted()
    }

    func canBeGathered() -> Bool {
        return !data.isDepleted() && !isBeingGathered
    }

    func startGathering(by villagerGroup: VillagerGroup) {
        guard !assignedVillagerGroups.contains(where: { $0.id == villagerGroup.id }) else {
            debugLog("⚠️ Villager group already gathering here")
            return
        }

        guard canAddVillagers(villagerGroup.villagerCount) else {
            debugLog("❌ Too many villagers at this resource (max: \(ResourcePointNode.maxVillagersPerTile))")
            return
        }

        // Update data layer
        _ = data.assignVillagerGroup(villagerGroup.data.id, villagerCount: villagerGroup.villagerCount)

        // Update visual layer
        assignedVillagerGroups.append(villagerGroup)
        updateLabel()

        // Register with engine for resource depletion tracking
        let engineRegistered = GameEngine.shared.resourceEngine.startGathering(
            villagerGroupID: villagerGroup.id,
            resourcePointID: self.id
        )
        if engineRegistered {
            debugLog("🔧 Engine: Registered gathering for \(villagerGroup.name)")
        }

        debugLog("✅ Added \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) to gather \(resourceType.displayName)")
        debugLog("   Total villagers gathering: \(getTotalVillagersGathering())/\(ResourcePointNode.maxVillagersPerTile)")
    }

    func stopGathering(by villagerGroup: VillagerGroup? = nil) {
        if let group = villagerGroup {
            // Update data layer
            data.unassignVillagerGroup(group.data.id, villagerCount: group.villagerCount)

            // Update visual layer
            assignedVillagerGroups.removeAll { $0.id == group.id }
            // Clear the villager's task when they stop gathering
            if case .gatheringResource = group.currentTask {
                group.clearTask()
            }

            // Notify engine
            GameEngine.shared.resourceEngine.stopGathering(villagerGroupID: group.id)

            debugLog("✅ Removed \(group.name) from gathering")
        } else {
            // Clear all assigned villagers
            for group in assignedVillagerGroups {
                data.unassignVillagerGroup(group.data.id, villagerCount: group.villagerCount)
                if case .gatheringResource = group.currentTask {
                    group.clearTask()
                }
                // Notify engine for each group
                GameEngine.shared.resourceEngine.stopGathering(villagerGroupID: group.id)
            }
            assignedVillagerGroups.removeAll()
        }

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
                    let campName = resourceType.requiredCampType?.capitalized.replacingOccurrences(of: "Camp", with: " Camp") ?? "Camp"
                    desc += "\n⚠️ Requires \(campName) nearby"
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
