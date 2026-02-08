import Foundation
import SpriteKit
import UIKit

// MARK: - Entity Type

enum EntityType {
    case army
    case villagerGroup
    case reinforcement

    var displayName: String {
        switch self {
        case .army: return "Army"
        case .villagerGroup: return "Villager Group"
        case .reinforcement: return "Reinforcements"
        }
    }

    var icon: String {
        switch self {
        case .army: return "A"
        case .villagerGroup: return "V"
        case .reinforcement: return "R"
        }
    }

    var moveSpeed: TimeInterval {
        switch self {
        case .army: return 1.6
        case .villagerGroup: return 2.0
        case .reinforcement: return 1.4  // Slightly faster than armies
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


    // Stack badge UI elements
    private var stackBadge: SKShapeNode?
    private var stackLabel: SKLabelNode?

    // Entrenchment badge UI elements
    private var entrenchmentBadge: SKShapeNode?
    private var entrenchmentLabel: SKLabelNode?

    // Movement timer UI elements
    private var movementTimerLabel: SKLabelNode?
    private var estimatedRemainingTime: TimeInterval = 0
    private var movementStartTime: TimeInterval = 0

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

        // Warn if army created without proper reference
        if entityType == .army && self.armyReference == nil {
            debugLog("⚠️ WARNING: EntityNode for army but armyReference is nil. Entity type: \(type(of: entity))")
        }

        let texture = EntityNode.createEntityTexture(for: entityType, entity: entity, currentPlayer: currentPlayer)
        super.init(texture: texture, color: .clear, size: CGSize(width: 24, height: 24))

        // Set isometric z-position for depth sorting
        self.zPosition = HexTileNode.isometricZPosition(q: coordinate.q, r: coordinate.r, baseLayer: HexTileNode.ZLayer.entity)

        self.name = "entity"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func createEntityTexture(for type: EntityType, entity: MapEntity, currentPlayer: Player?) -> SKTexture {
        let size = CGSize(width: 24, height: 24)
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
            case .reinforcement:
                bgColor = UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1.0)
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
                .font: UIFont.systemFont(ofSize: 12),
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
        // Capture strongly to avoid bad access during movement
        let map = (self.scene as? GameScene)?.hexMap

        // Start movement timer
        startMovementTimer(path: path, hexMap: map)

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

        // For armies, use the slowest unit in the composition
        if entityType == .army, let army = armyReference {
            baseMoveSpeed = army.data.slowestUnitMoveSpeed
        }

        // Apply villager speed research bonus (lower moveSpeed = faster movement)
        if entityType == .villagerGroup {
            let speedMultiplier = ResearchManager.shared.getVillagerMarchSpeedMultiplier()
            baseMoveSpeed = baseMoveSpeed / speedMultiplier
        }

        // Apply army march speed research bonus
        if entityType == .army {
            let marchSpeedMultiplier = ResearchManager.shared.getMilitaryMarchSpeedMultiplier()
            baseMoveSpeed = baseMoveSpeed / marchSpeedMultiplier
        }

        // Apply retreat speed research bonus when retreating
        if let army = armyReference, army.isRetreating {
            let retreatSpeedMultiplier = ResearchManager.shared.getMilitaryRetreatSpeedMultiplier()
            baseMoveSpeed = baseMoveSpeed / retreatSpeedMultiplier
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
            let hasRoad = map?.hasRoad(at: coord) ?? false

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

                // Update isometric z-position for correct depth sorting during movement
                self.zPosition = HexTileNode.isometricZPosition(q: coord.q, r: coord.r, baseLayer: HexTileNode.ZLayer.entity)

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

                    // Update movement timer with remaining path (use captured map)
                    self.updateMovementTimer(remainingPath: remainingPath, hexMap: map)
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
                    debugLog("✅ Updated Army coordinate to (\(lastCoord.q), \(lastCoord.r))")

                    // Clear retreating flag when movement completes
                    if army.isRetreating {
                        army.isRetreating = false
                        debugLog("🏠 Army \(army.name) retreat completed")
                    }

                    // Check if arrived at a valid home base building and update
                    if let gameScene = self.scene as? GameScene {
                        gameScene.checkAndUpdateHomeBase(for: army, at: lastCoord)
                    }
                } else if let villagers = self.entity as? VillagerGroup {
                    villagers.coordinate = lastCoord
                    debugLog("✅ Updated VillagerGroup coordinate to (\(lastCoord.q), \(lastCoord.r))")

                    // ✅ FIX: Check if villagers have a hunting task to execute
                    if case .hunting(let target) = villagers.currentTask {
                        debugLog("🏹 Villagers arrived at hunting target!")
                        // Notify the scene to execute the hunt
                        if let gameScene = self.scene as? GameScene {
                            gameScene.villagerArrivedForHunt(villagerGroup: villagers, target: target, entityNode: self)
                        } else {
                            debugLog("❌ ERROR: Could not get GameScene for hunt execution (scene: \(String(describing: self.scene)))")
                        }
                    } else if case .upgrading = villagers.currentTask {
                        debugLog("🔨 Villagers arrived at building for upgrade!")
                        if let gameScene = self.scene as? GameScene {
                            gameScene.checkPendingUpgradeArrival(entity: self)
                        }
                    }
                }
            }

            // Only set isMoving to false if not transitioned to a gathering task
            // (e.g., after a successful hunt, villagers start gathering from carcass)
            if let villagers = self.entity as? VillagerGroup,
               case .gatheringResource = villagers.currentTask {
                // Keep isMoving = true since villagers are now gathering
                debugLog("🥩 Villagers transitioned to gathering, staying busy")
            } else {
                self.isMoving = false
            }
            self.movementPath = []
            self.removeMovementTimer()
            completion()
        }
    }

    func updateVisibility(for player: Player) {
        // Own entities should always be visible to their owner.
        // Check both weak owner reference AND data-layer ownerID for reliability,
        // since owner is a weak ref that may be nil for engine-created entities.
        if entity.owner?.id == player.id {
            self.isHidden = false
            return
        }
        if let army = entity as? Army, army.data.ownerID == player.id {
            self.isHidden = false
            return
        }
        if let villagers = entity as? VillagerGroup, villagers.data.ownerID == player.id {
            self.isHidden = false
            return
        }

        if let fogOfWar = player.fogOfWar {
            let visibility = fogOfWar.getVisibilityLevel(at: coordinate)
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

    // MARK: - Movement Timer

    /// Calculate travel time for a path considering terrain, roads, and research bonuses
    func calculateTravelTime(from startCoord: HexCoordinate, path: [HexCoordinate], hexMap: HexMap?) -> TimeInterval {
        guard !path.isEmpty else { return 0 }

        var totalTime: TimeInterval = 0
        var previousCoord = startCoord

        // Base move speed with research bonus
        var baseMoveSpeed = entityType.moveSpeed

        // For armies, use the slowest unit in the composition
        if entityType == .army, let army = armyReference {
            baseMoveSpeed = army.data.slowestUnitMoveSpeed
        }

        // Apply villager speed research bonus (lower moveSpeed = faster movement)
        if entityType == .villagerGroup {
            let speedMultiplier = ResearchManager.shared.getVillagerMarchSpeedMultiplier()
            baseMoveSpeed = baseMoveSpeed / speedMultiplier
        }

        // Apply army march speed research bonus
        if entityType == .army {
            let marchSpeedMultiplier = ResearchManager.shared.getMilitaryMarchSpeedMultiplier()
            baseMoveSpeed = baseMoveSpeed / marchSpeedMultiplier
        }

        // Apply retreat speed research bonus when retreating
        if let army = armyReference, army.isRetreating {
            let retreatSpeedMultiplier = ResearchManager.shared.getMilitaryRetreatSpeedMultiplier()
            baseMoveSpeed = baseMoveSpeed / retreatSpeedMultiplier
        }

        // Get road speed research bonus
        let roadSpeedBonus = ResearchManager.shared.getRoadSpeedMultiplier()

        for coord in path {
            // Calculate segment distance
            let prevPos = HexMap.hexToPixel(q: previousCoord.q, r: previousCoord.r)
            let nextPos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let dx = nextPos.x - prevPos.x
            let dy = nextPos.y - prevPos.y
            let distance = sqrt(dx * dx + dy * dy)

            // Check if destination tile has a road
            let hasRoad = hexMap?.hasRoad(at: coord) ?? false

            // Calculate segment duration
            var segmentSpeed = baseMoveSpeed
            if hasRoad {
                // Roads make movement 50% faster, plus any research bonus
                segmentSpeed = baseMoveSpeed / (1.5 * roadSpeedBonus)
            }

            let segmentDuration = TimeInterval(distance / 100.0) * segmentSpeed
            totalTime += segmentDuration

            previousCoord = coord
        }

        return totalTime
    }

    /// Sets up the movement timer label
    private func setupMovementTimer() {
        guard movementTimerLabel == nil else { return }

        movementTimerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        movementTimerLabel?.fontSize = 8
        movementTimerLabel?.fontColor = .yellow
        movementTimerLabel?.position = CGPoint(x: 0, y: -18)
        movementTimerLabel?.zPosition = 15
        movementTimerLabel?.name = "movementTimerLabel"
        addChild(movementTimerLabel!)
    }

    /// Updates the movement timer display with remaining time
    private func updateMovementTimerDisplay(remaining: TimeInterval) {
        guard let label = movementTimerLabel else { return }

        if remaining > 60 {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            label.text = String(format: "%d:%02d", minutes, seconds)
        } else {
            let seconds = Int(remaining)
            label.text = String(format: "0:%02d", seconds)
        }
    }

    /// Removes the movement timer label
    private func removeMovementTimer() {
        movementTimerLabel?.removeFromParent()
        movementTimerLabel = nil
        estimatedRemainingTime = 0
    }

    /// Starts the movement timer for the given path
    func startMovementTimer(path: [HexCoordinate], hexMap: HexMap?) {
        setupMovementTimer()
        movementStartTime = Date().timeIntervalSince1970
        estimatedRemainingTime = calculateTravelTime(from: coordinate, path: path, hexMap: hexMap)
        updateMovementTimerDisplay(remaining: estimatedRemainingTime)
    }

    /// Updates the movement timer after reaching a waypoint
    func updateMovementTimer(remainingPath: [HexCoordinate], hexMap: HexMap?) {
        guard !remainingPath.isEmpty else {
            removeMovementTimer()
            return
        }

        estimatedRemainingTime = calculateTravelTime(from: coordinate, path: remainingPath, hexMap: hexMap)
        updateMovementTimerDisplay(remaining: estimatedRemainingTime)
    }

    // MARK: - Entrenchment Progress Bar

    private var entrenchmentBarBackground: SKShapeNode?
    private var entrenchmentBarFill: SKShapeNode?

    /// Sets up the entrenchment progress bar below the entity
    func setupEntrenchmentBar() {
        guard entrenchmentBarBackground == nil else { return }

        let barWidth: CGFloat = 30
        let barHeight: CGFloat = 3
        let yPos: CGFloat = -18

        let background = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 1)
        background.fillColor = UIColor(white: 0.2, alpha: 0.8)
        background.strokeColor = UIColor(white: 0.4, alpha: 0.6)
        background.lineWidth = 0.5
        background.position = CGPoint(x: 0, y: yPos)
        background.zPosition = 15
        addChild(background)
        entrenchmentBarBackground = background

        let fill = SKShapeNode(rectOf: CGSize(width: 0.1, height: barHeight - 1), cornerRadius: 0.5)
        fill.fillColor = UIColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1.0)
        fill.strokeColor = .clear
        fill.position = CGPoint(x: -barWidth / 2, y: yPos)
        fill.zPosition = 16
        addChild(fill)
        entrenchmentBarFill = fill
    }

    /// Updates the entrenchment bar fill based on progress (0.0 to 1.0)
    func updateEntrenchmentBar(progress: Double) {
        let barWidth: CGFloat = 30
        let barHeight: CGFloat = 3
        let yPos: CGFloat = -18
        let clampedProgress = CGFloat(min(max(progress, 0), 1))
        let fillWidth = max(0.1, barWidth * clampedProgress)

        entrenchmentBarFill?.removeFromParent()
        let fill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: barHeight - 1), cornerRadius: 0.5)
        fill.fillColor = UIColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1.0)
        fill.strokeColor = .clear
        fill.position = CGPoint(x: (-barWidth + fillWidth) / 2, y: yPos)
        fill.zPosition = 16
        addChild(fill)
        entrenchmentBarFill = fill
    }

    /// Removes the entrenchment progress bar
    func removeEntrenchmentBar() {
        entrenchmentBarBackground?.removeFromParent()
        entrenchmentBarBackground = nil
        entrenchmentBarFill?.removeFromParent()
        entrenchmentBarFill = nil
    }

    // MARK: - Entrenchment Badge

    /// Shows a brown "E" badge on the entity to indicate it is entrenched
    func showEntrenchmentBadge() {
        guard entrenchmentBadge == nil else { return }

        let badgeRadius: CGFloat = 7
        let badge = SKShapeNode(circleOfRadius: badgeRadius)
        badge.fillColor = UIColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1.0)
        badge.strokeColor = .white
        badge.lineWidth = 1.0
        badge.position = CGPoint(x: -10, y: -10)
        badge.zPosition = 16
        addChild(badge)
        entrenchmentBadge = badge

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 8
        label.fontColor = .white
        label.text = "E"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: -10, y: -10)
        label.zPosition = 17
        addChild(label)
        entrenchmentLabel = label

        // Subtle pulse animation
        let fadeOut = SKAction.fadeAlpha(to: 0.6, duration: 0.5)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        let pulse = SKAction.sequence([fadeOut, fadeIn])
        badge.run(SKAction.repeatForever(pulse))
        label.run(SKAction.repeatForever(pulse))
    }

    /// Removes the entrenchment badge
    func removeEntrenchmentBadge() {
        entrenchmentBadge?.removeFromParent()
        entrenchmentBadge = nil
        entrenchmentLabel?.removeFromParent()
        entrenchmentLabel = nil
    }

    // MARK: - Stack Badge

    private func setupStackBadge() {
        guard stackBadge == nil else { return }

        let badgeRadius: CGFloat = 8
        let badge = SKShapeNode(circleOfRadius: badgeRadius)
        badge.fillColor = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1.0)
        badge.strokeColor = .white
        badge.lineWidth = 1.0
        badge.position = CGPoint(x: 10, y: 10)
        badge.zPosition = 16
        badge.isHidden = true
        addChild(badge)
        stackBadge = badge

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 9
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 10, y: 10)
        label.zPosition = 17
        label.isHidden = true
        addChild(label)
        stackLabel = label
    }

    func updateStackBadge(count: Int) {
        if count > 1 {
            if stackBadge == nil {
                setupStackBadge()
            }
            stackBadge?.isHidden = false
            stackLabel?.isHidden = false
            stackLabel?.text = "\(count)"
        } else {
            stackBadge?.isHidden = true
            stackLabel?.isHidden = true
        }
    }
}
