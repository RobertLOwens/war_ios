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
    private var pathLine: SKShapeNode?

    
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

        // Get HexMap from GameScene for road checking
        let hexMap = (self.scene as? GameScene)?.hexMap

        // Calculate segment distances
        var segmentDistances: [CGFloat] = []
        let startPos = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        var previousPos = startPos

        for coord in path {
            let nextPos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let dx = nextPos.x - previousPos.x
            let dy = nextPos.y - previousPos.y
            let distance = sqrt(dx * dx + dy * dy)
            segmentDistances.append(distance)
            previousPos = nextPos
        }

        // Base move speed with research bonus
        var baseMoveSpeed = entityType.moveSpeed

        // Apply villager speed research bonus (lower moveSpeed = faster movement)
        if entityType == .villagerGroup {
            let speedMultiplier = ResearchManager.shared.getVillagerMarchSpeedMultiplier()
            baseMoveSpeed = baseMoveSpeed / speedMultiplier
        }

        // Get road speed research bonus
        let roadSpeedBonus = ResearchManager.shared.getRoadSpeedMultiplier()

        // Create movement actions with per-segment road speed bonus
        var actions: [SKAction] = []
        var remainingPath = path

        for (index, coord) in path.enumerated() {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let segmentDistance = segmentDistances[index]

            // Check if destination tile has a road
            let hasRoad = hexMap?.hasRoad(at: coord) ?? false

            // Calculate segment duration
            // Roads are faster: base speed * road bonus (1.5x faster on roads, plus research)
            var segmentSpeed = baseMoveSpeed
            if hasRoad {
                // Roads make movement 50% faster, plus any research bonus
                segmentSpeed = baseMoveSpeed / (1.5 * roadSpeedBonus)
            }

            let segmentDuration = TimeInterval(segmentDistance / 100.0) * segmentSpeed

            let moveAction = SKAction.move(to: position, duration: segmentDuration)
            moveAction.timingMode = .linear
            actions.append(moveAction)
            
            // ✅ Update coordinate and path visualization after reaching each waypoint
            let updateAction = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.coordinate = coord
                
                // Update the underlying entity's coordinate
                if let army = self.entity as? Army {
                    army.coordinate = coord
                } else if let villagers = self.entity as? VillagerGroup {
                    villagers.coordinate = coord
                }
                
                // ✅ Update path visualization - remove completed segment
                remainingPath.removeFirst()
                if let scene = self.scene as? GameScene {
                    if !remainingPath.isEmpty {
                        scene.updateMovementPath(from: coord, remainingPath: remainingPath)
                    } else {
                        scene.clearMovementPath()
                    }
                }
                
                // Trigger fog of war update
                if let owner = self.entity.owner {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UpdateFogOfWar"),
                        object: owner
                    )
                }
            }
            actions.append(updateAction)
        }
        
        let sequence = SKAction.sequence(actions)
        
        run(sequence) { [weak self] in
            guard let self = self else { return }
            if let lastCoord = path.last {
                self.coordinate = lastCoord
                
                if let army = self.entity as? Army {
                    army.coordinate = lastCoord
                    print("✅ Updated Army coordinate to (\(lastCoord.q), \(lastCoord.r))")
                } else if let villagers = self.entity as? VillagerGroup {
                    villagers.coordinate = lastCoord
                    print("✅ Updated VillagerGroup coordinate to (\(lastCoord.q), \(lastCoord.r))")
                    
                    // ✅ FIX: Check if villagers have a hunting task to execute
                    if case .hunting(let target) = villagers.currentTask {
                        print("🏹 Villagers arrived at hunting target!")
                        // Notify the scene to execute the hunt
                        if let gameScene = self.scene as? GameScene {
                            gameScene.villagerArrivedForHunt(villagerGroup: villagers, target: target, entityNode: self)
                        }
                    }
                }
            }
            self.isMoving = false
            self.movementPath = []
            completion()
        }
    }
    
    func updateVisibility(for player: Player) {
        if let fogOfWar = player.fogOfWar {
            let visibility = fogOfWar.getVisibilityLevel(at: coordinate)
            
            // ✅ FIX: Only show entity if tile is VISIBLE (not just explored)
            let shouldShow = visibility == .visible &&
                            fogOfWar.shouldShowEntity(entity, at: coordinate)
            
            self.isHidden = !shouldShow
        
        }
    }
    
    func drawMovementPath(_ path: [HexCoordinate]) {
        // Remove old path line
        pathLine?.removeFromParent()
        
        guard !path.isEmpty else { return }
        
        // Create path
        let bezierPath = UIBezierPath()
        
        // Start from current position
        bezierPath.move(to: .zero)
        
        // Draw line through each waypoint
        for coord in path {
            let worldPos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let localPos = CGPoint(
                x: worldPos.x - self.position.x,
                y: worldPos.y - self.position.y
            )
            bezierPath.addLine(to: localPos)
        }
        
        // Create shape node
        pathLine = SKShapeNode(path: bezierPath.cgPath)
        pathLine?.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.6) // Yellow with transparency
        pathLine?.lineWidth = 2
        pathLine?.lineCap = .round
        pathLine?.lineJoin = .round
        pathLine?.zPosition = -1 // Behind the entity
        
        // Add arrow at the end
        if let lastCoord = path.last {
            let worldPos = HexMap.hexToPixel(q: lastCoord.q, r: lastCoord.r)
            let localPos = CGPoint(
                x: worldPos.x - self.position.x,
                y: worldPos.y - self.position.y
            )
            
            // Calculate arrow direction
            let previousCoord = path.count > 1 ? path[path.count - 2] : coordinate
            let prevWorldPos = HexMap.hexToPixel(q: previousCoord.q, r: previousCoord.r)
            let prevLocalPos = CGPoint(
                x: prevWorldPos.x - self.position.x,
                y: prevWorldPos.y - self.position.y
            )
            
            let dx = localPos.x - prevLocalPos.x
            let dy = localPos.y - prevLocalPos.y
            let angle = atan2(dy, dx)
            
            // Create arrow head
            let arrowSize: CGFloat = 8
            let arrowPath = UIBezierPath()
            arrowPath.move(to: localPos)
            arrowPath.addLine(to: CGPoint(
                x: localPos.x - arrowSize * cos(angle - .pi / 6),
                y: localPos.y - arrowSize * sin(angle - .pi / 6)
            ))
            arrowPath.move(to: localPos)
            arrowPath.addLine(to: CGPoint(
                x: localPos.x - arrowSize * cos(angle + .pi / 6),
                y: localPos.y - arrowSize * sin(angle + .pi / 6)
            ))
            
            let arrowHead = SKShapeNode(path: arrowPath.cgPath)
            arrowHead.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.6)
            arrowHead.lineWidth = 2
            arrowHead.lineCap = .round
            pathLine?.addChild(arrowHead)
        }
        
        addChild(pathLine!)
    }
    
    func clearMovementPath() {
            pathLine?.removeFromParent()
            pathLine = nil
        }
        
    
}
