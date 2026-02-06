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

    // Health bar UI elements
    private var healthBarBackground: SKShapeNode?
    private var healthBarFill: SKShapeNode?
    private weak var currentPlayerReference: Player?

    // Combat position tracking for HP bar
    private var combatPositionIsTop: Bool = false

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
            print("⚠️ WARNING: EntityNode for army but armyReference is nil. Entity type: \(type(of: entity))")
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

                    // Clear retreating flag when movement completes
                    if army.isRetreating {
                        army.isRetreating = false
                        print("🏠 Army \(army.name) retreat completed")
                    }

                    // Check if arrived at a valid home base building and update
                    if let gameScene = self.scene as? GameScene {
                        gameScene.checkAndUpdateHomeBase(for: army, at: lastCoord)
                    }
                } else if let villagers = self.entity as? VillagerGroup {
                    villagers.coordinate = lastCoord
                    print("✅ Updated VillagerGroup coordinate to (\(lastCoord.q), \(lastCoord.r))")

                    // ✅ FIX: Check if villagers have a hunting task to execute
                    if case .hunting(let target) = villagers.currentTask {
                        print("🏹 Villagers arrived at hunting target!")
                        // Notify the scene to execute the hunt
                        if let gameScene = self.scene as? GameScene {
                            gameScene.villagerArrivedForHunt(villagerGroup: villagers, target: target, entityNode: self)
                        } else {
                            print("❌ ERROR: Could not get GameScene for hunt execution (scene: \(String(describing: self.scene)))")
                        }
                    } else if case .upgrading = villagers.currentTask {
                        print("🔨 Villagers arrived at building for upgrade!")
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
                print("🥩 Villagers transitioned to gathering, staying busy")
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

    // MARK: - Health Bar

    func setupHealthBar(currentPlayer: Player?) {
        currentPlayerReference = currentPlayer

        // Only show health bars for armies
        guard entityType == .army else { return }

        // Guard against duplicate health bars - skip if already created
        if healthBarBackground != nil && healthBarFill != nil {
            return
        }

        let barWidth: CGFloat = 20
        let barHeight: CGFloat = 3

        // Default all HP bars to bottom position
        let yOffset: CGFloat = -14
        combatPositionIsTop = false

        // Background (dark)
        let bgRect = CGRect(x: -barWidth/2, y: yOffset, width: barWidth, height: barHeight)
        healthBarBackground = SKShapeNode(rect: bgRect, cornerRadius: 2)
        healthBarBackground?.fillColor = UIColor(white: 0.2, alpha: 0.8)
        healthBarBackground?.strokeColor = .clear
        healthBarBackground?.zPosition = 15
        addChild(healthBarBackground!)

        // Fill color based on diplomacy status
        let diplomacyStatus = currentPlayer?.getDiplomacyStatus(with: entity.owner) ?? .neutral
        healthBarFill = SKShapeNode(rect: bgRect, cornerRadius: 2)
        healthBarFill?.fillColor = diplomacyStatus.strokeColor
        healthBarFill?.strokeColor = .clear
        healthBarFill?.zPosition = 16
        addChild(healthBarFill!)
    }

    /// Updates HP bar position for combat visualization
    /// - Parameter isAttacker: If true, moves bar to top; if false, keeps at bottom
    func updateHealthBarCombatPosition(isAttacker: Bool) {
        combatPositionIsTop = isAttacker

        let barWidth: CGFloat = 20
        let barHeight: CGFloat = 3
        let yOffset: CGFloat = isAttacker ? 14 : -14

        // Update background position
        let bgRect = CGRect(x: -barWidth/2, y: yOffset, width: barWidth, height: barHeight)
        healthBarBackground?.path = CGPath(roundedRect: bgRect, cornerWidth: 2, cornerHeight: 2, transform: nil)

        // Update fill position (keeping current width ratio)
        updateHealthBar()
    }

    /// Resets HP bar to default bottom position after combat ends
    func resetHealthBarPosition() {
        combatPositionIsTop = false

        let barWidth: CGFloat = 20
        let barHeight: CGFloat = 3
        let yOffset: CGFloat = -14

        let bgRect = CGRect(x: -barWidth/2, y: yOffset, width: barWidth, height: barHeight)
        healthBarBackground?.path = CGPath(roundedRect: bgRect, cornerWidth: 2, cornerHeight: 2, transform: nil)

        updateHealthBar()
    }

    func updateHealthBar() {
        // Use armyReference instead of casting entity for correct identity comparison
        guard entityType == .army,
              let army = armyReference,
              let fill = healthBarFill else { return }

        let totalUnits = army.getTotalMilitaryUnits()
        guard totalUnits > 0 else {
            // Hide health bar if no units
            healthBarBackground?.isHidden = true
            healthBarFill?.isHidden = true
            return
        }

        healthBarBackground?.isHidden = false
        healthBarFill?.isHidden = false

        // Get current HP from active combat if in combat
        let currentHP: Double
        let maxHP: Double

        if let combat = GameEngine.shared.combatEngine.getCombat(involving: army.id) {
            // In active combat, use unit count as HP approximation
            currentHP = Double(totalUnits)
            maxHP = Double(totalUnits)  // Approximation since we don't track initial count in engine
        } else {
            currentHP = Double(totalUnits)
            maxHP = Double(totalUnits)
        }

        let percentage = CGFloat(currentHP / max(maxHP, 1))
        // Use combat position tracking instead of player ownership
        let yOffset: CGFloat = combatPositionIsTop ? 14 : -14

        let barWidth: CGFloat = 20 * max(0, min(1, percentage))
        let newRect = CGRect(x: -10, y: yOffset, width: barWidth, height: 3)
        fill.path = CGPath(roundedRect: newRect, cornerWidth: 2, cornerHeight: 2, transform: nil)
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

}
