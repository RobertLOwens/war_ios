import Foundation
import SpriteKit
import UIKit

// MARK: - Entity Type

enum EntityType {
    case army
    case villagerGroup
    
    var displayName: String {
        switch self {
        case .army: return "Army"
        case .villagerGroup: return "Villager Group"
        }
    }
    
    var icon: String {
        switch self {
        case .army: return "A"
        case .villagerGroup: return "V"
        }
    }
    
    var moveSpeed: TimeInterval {
        switch self {
        case .army: return 0.4
        case .villagerGroup: return 0.5
        }
    }
}

// MARK: - Entity Node

class EntityNode: SKSpriteNode {
    var coordinate: HexCoordinate
    let entityType: EntityType
    let entity: MapEntity
    var isMoving: Bool = false
    var movementPath: [HexCoordinate] = []
    
    // ✅ ADD: Store the actual typed entity
    weak var armyReference: Army?
    weak var villagerReference: VillagerGroup?
    
    init(coordinate: HexCoordinate, entityType: EntityType, entity: MapEntity, currentPlayer: Player? = nil) {
          self.coordinate = coordinate
          self.entityType = entityType
          self.entity = entity
          
          // ✅ Store typed reference based on entity type
          if entityType == .army, let army = entity as? Army {
              self.armyReference = army
          } else if entityType == .villagerGroup, let villagers = entity as? VillagerGroup {
              self.villagerReference = villagers
          }
          
          let texture = EntityNode.createEntityTexture(for: entityType, entity: entity, currentPlayer: currentPlayer)
          super.init(texture: texture, color: .clear, size: CGSize(width: 36, height: 36))
          
          self.zPosition = 10
          self.name = "entity"
      }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func createEntityTexture(for type: EntityType, entity: MapEntity, currentPlayer: Player?) -> SKTexture {
        let size = CGSize(width: 36, height: 36)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Background color based on entity type
            let bgColor: UIColor
            switch type {
            case .army:
                bgColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
            case .villagerGroup:
                bgColor = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
            }
            
            // Draw circle
            bgColor.setFill()
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
            
            // Draw border with diplomacy color
            let diplomacyStatus = currentPlayer?.getDiplomacyStatus(with: entity.owner) ?? .neutral
            diplomacyStatus.strokeColor.setStroke()
            context.cgContext.setLineWidth(2.5)
            context.cgContext.strokeEllipse(in: rect.insetBy(dx: 2, dy: 2))
            
            // Draw icon
            let icon = type.icon
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18),
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

    func updateTexture(currentPlayer: Player? = nil) {
        self.texture = EntityNode.createEntityTexture(for: entityType, entity: entity, currentPlayer: currentPlayer)
    }
    
    func moveTo(path: [HexCoordinate], completion: @escaping () -> Void) {
        guard !path.isEmpty else {
            completion()
            return
        }
        
        isMoving = true
        movementPath = path
        
        var actions: [SKAction] = []
        
        for coord in path {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let moveAction = SKAction.move(to: position, duration: entityType.moveSpeed)
            moveAction.timingMode = .easeInEaseOut
            actions.append(moveAction)
            
            // ✅ ADD: Update coordinate and trigger vision update after each step
            let updateCoordAction = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.coordinate = coord
                
                // Update the underlying entity's coordinate
                if let army = self.entity as? Army {
                    army.coordinate = coord
                } else if let villagers = self.entity as? VillagerGroup {
                    villagers.coordinate = coord
                }
                
                // ✅ NEW: Trigger fog of war update during movement
                if let owner = self.entity.owner {
                    // This will be called each step, allowing fog to follow the entity
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UpdateFogOfWar"),
                        object: owner
                    )
                }
            }
            actions.append(updateCoordAction)
        }
        
        let sequence = SKAction.sequence(actions)
        
        run(sequence) { [weak self] in
            guard let self = self else { return }
            if let lastCoord = path.last {
                self.coordinate = lastCoord
                
                // Final coordinate update
                if let army = self.entity as? Army {
                    army.coordinate = lastCoord
                    print("✅ Updated Army coordinate to (\(lastCoord.q), \(lastCoord.r))")
                } else if let villagers = self.entity as? VillagerGroup {
                    villagers.coordinate = lastCoord
                    print("✅ Updated VillagerGroup coordinate to (\(lastCoord.q), \(lastCoord.r))")
                }
            }
            self.isMoving = false
            self.movementPath = []
            completion()
        }
    }

    
    func updateVisibility(for player: Player) {
        if let fogOfWar = player.fogOfWar {
            let shouldShow = fogOfWar.shouldShowEntity(entity, at: coordinate)
            self.isHidden = !shouldShow
        }
    }
    
}
