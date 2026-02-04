// ============================================================================
// FILE: ReinforcementNode.swift
// PURPOSE: Visual node for marching reinforcement units with timer and arrow
// ============================================================================

import Foundation
import SpriteKit
import UIKit

class ReinforcementNode: SKSpriteNode {
    /// The reinforcement group data
    let reinforcement: ReinforcementGroup

    /// Current coordinate
    var coordinate: HexCoordinate

    /// Whether currently moving
    var isMoving: Bool = false

    /// Movement path
    var movementPath: [HexCoordinate] = []

    /// Timer label showing remaining travel time
    private var timerLabel: SKLabelNode?

    /// Arrow pointing to target army
    private var directionArrow: SKShapeNode?

    /// Reference to the target army (for arrow direction)
    private weak var targetArmy: Army?

    /// Reference to current player (for visibility)
    private weak var currentPlayerReference: Player?

    init(reinforcement: ReinforcementGroup, currentPlayer: Player? = nil) {
        self.reinforcement = reinforcement
        self.coordinate = reinforcement.coordinate
        self.targetArmy = reinforcement.targetArmy
        self.currentPlayerReference = currentPlayer

        let texture = ReinforcementNode.createTexture(for: reinforcement, currentPlayer: currentPlayer)
        super.init(texture: texture, color: .clear, size: CGSize(width: 16, height: 16))

        // Set isometric z-position for depth sorting
        self.zPosition = HexTileNode.isometricZPosition(q: coordinate.q, r: coordinate.r, baseLayer: HexTileNode.ZLayer.entity)
        self.name = "reinforcement"

        setupTimerLabel()
        setupDirectionArrow()
        updateArrowDirection()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Texture Creation

    static func createTexture(for reinforcement: ReinforcementGroup, currentPlayer: Player?) -> SKTexture {
        let size = CGSize(width: 16, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Background color - military green
            let bgColor = UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1.0)
            bgColor.setFill()
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 1, dy: 1))

            // Border with diplomacy color
            let diplomacyStatus = currentPlayer?.getDiplomacyStatus(with: reinforcement.owner) ?? .neutral
            diplomacyStatus.strokeColor.setStroke()
            context.cgContext.setLineWidth(1.25)
            context.cgContext.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))

            // Draw "R" icon for reinforcement
            let icon = "R"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 7),
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

    // MARK: - Timer Label

    private func setupTimerLabel() {
        timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        timerLabel?.fontSize = 6
        timerLabel?.fontColor = .yellow
        timerLabel?.position = CGPoint(x: 0, y: -12)
        timerLabel?.zPosition = 15
        timerLabel?.name = "reinforcementTimer"
        addChild(timerLabel!)
    }

    func updateTimer(remaining: TimeInterval) {
        guard let label = timerLabel else { return }

        if remaining > 60 {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            label.text = String(format: "%d:%02d", minutes, seconds)
        } else {
            let seconds = Int(remaining)
            label.text = String(format: "0:%02d", seconds)
        }
    }

    // MARK: - Direction Arrow

    private func setupDirectionArrow() {
        directionArrow = SKShapeNode()
        directionArrow?.strokeColor = .cyan
        directionArrow?.lineWidth = 1.0
        directionArrow?.lineCap = .round
        directionArrow?.zPosition = 14
        directionArrow?.name = "directionArrow"
        addChild(directionArrow!)
    }

    /// Updates the arrow to point toward the target army
    func updateArrowDirection() {
        guard let arrow = directionArrow,
              let targetCoord = targetArmy?.coordinate else {
            directionArrow?.isHidden = true
            return
        }

        // Calculate direction to target
        let targetPos = HexMap.hexToPixel(q: targetCoord.q, r: targetCoord.r)
        let myPos = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

        let dx = targetPos.x - myPos.x
        let dy = targetPos.y - myPos.y
        let angle = atan2(dy, dx)

        // Create arrow path
        let arrowLength: CGFloat = 10
        let arrowHeadSize: CGFloat = 3

        let path = UIBezierPath()

        // Arrow line (starting from edge of circle)
        let startOffset: CGFloat = 9  // Start just outside the circle
        let startPoint = CGPoint(
            x: cos(angle) * startOffset,
            y: sin(angle) * startOffset
        )
        let endPoint = CGPoint(
            x: cos(angle) * (startOffset + arrowLength),
            y: sin(angle) * (startOffset + arrowLength)
        )

        path.move(to: startPoint)
        path.addLine(to: endPoint)

        // Arrow head
        let headAngle1 = angle + .pi * 0.8
        let headAngle2 = angle - .pi * 0.8

        path.move(to: endPoint)
        path.addLine(to: CGPoint(
            x: endPoint.x + cos(headAngle1) * arrowHeadSize,
            y: endPoint.y + sin(headAngle1) * arrowHeadSize
        ))

        path.move(to: endPoint)
        path.addLine(to: CGPoint(
            x: endPoint.x + cos(headAngle2) * arrowHeadSize,
            y: endPoint.y + sin(headAngle2) * arrowHeadSize
        ))

        arrow.path = path.cgPath
        arrow.isHidden = false
    }

    // MARK: - Movement

    /// Calculate travel time for remaining path
    func calculateTravelTime(path: [HexCoordinate], hexMap: HexMap?) -> TimeInterval {
        guard !path.isEmpty else { return 0 }

        // Capture hexMap strongly for the duration of this calculation
        let map = hexMap

        var totalTime: TimeInterval = 0
        var previousCoord = coordinate

        let baseMoveSpeed = EntityType.reinforcement.moveSpeed
        let roadSpeedBonus = ResearchManager.shared.getRoadSpeedMultiplier()

        for coord in path {
            let prevPos = HexMap.hexToPixel(q: previousCoord.q, r: previousCoord.r)
            let nextPos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let dx = nextPos.x - prevPos.x
            let dy = nextPos.y - prevPos.y
            let distance = sqrt(dx * dx + dy * dy)

            let hasRoad = map?.hasRoad(at: coord) ?? false
            var segmentSpeed = baseMoveSpeed
            if hasRoad {
                segmentSpeed = baseMoveSpeed / (1.5 * roadSpeedBonus)
            }

            let segmentDuration = TimeInterval(distance / 100.0) * segmentSpeed
            totalTime += segmentDuration

            previousCoord = coord
        }

        return totalTime
    }

    /// Callback for when reinforcement enters a new tile (for interception checking)
    var onTileEntered: ((HexCoordinate) -> Bool)?  // Returns true to continue, false to stop

    /// Start moving along the path
    func moveTo(path: [HexCoordinate], hexMap: HexMap?, completion: @escaping () -> Void) {
        guard !path.isEmpty else {
            completion()
            return
        }

        // Capture hexMap strongly for the duration of the movement
        let map = hexMap

        isMoving = true
        movementPath = path

        // Calculate initial time estimate
        let totalTime = calculateTravelTime(path: path, hexMap: map)
        updateTimer(remaining: totalTime)

        // Calculate segment distances
        var segmentDistances: [CGFloat] = []
        var previousPos = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

        for coord in path {
            let nextPos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let dx = nextPos.x - previousPos.x
            let dy = nextPos.y - previousPos.y
            segmentDistances.append(sqrt(dx * dx + dy * dy))
            previousPos = nextPos
        }

        let baseMoveSpeed = EntityType.reinforcement.moveSpeed
        let roadSpeedBonus = ResearchManager.shared.getRoadSpeedMultiplier()

        var actions: [SKAction] = []
        var remainingPath = path

        for (index, coord) in path.enumerated() {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let segmentDistance = segmentDistances[index]

            let hasRoad = map?.hasRoad(at: coord) ?? false
            var segmentSpeed = baseMoveSpeed
            if hasRoad {
                segmentSpeed = baseMoveSpeed / (1.5 * roadSpeedBonus)
            }

            let segmentDuration = TimeInterval(segmentDistance / 100.0) * segmentSpeed

            let moveAction = SKAction.move(to: position, duration: segmentDuration)
            moveAction.timingMode = .linear
            actions.append(moveAction)

            // Update after reaching waypoint
            let updateAction = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.coordinate = coord
                self.reinforcement.updateCoordinate(coord)
                self.reinforcement.pathIndex += 1

                // Update isometric z-position for correct depth sorting during movement
                self.zPosition = HexTileNode.isometricZPosition(q: coord.q, r: coord.r, baseLayer: HexTileNode.ZLayer.entity)

                remainingPath.removeFirst()

                // Update timer
                let remaining = self.calculateTravelTime(path: remainingPath, hexMap: map)
                self.updateTimer(remaining: remaining)

                // Update arrow direction
                self.updateArrowDirection()

                // Check for interception (callback returns false to stop movement)
                if let onTileEntered = self.onTileEntered {
                    let shouldContinue = onTileEntered(coord)
                    if !shouldContinue {
                        // Movement will be stopped by the callback handler
                        return
                    }
                }
            }
            actions.append(updateAction)
        }

        let sequence = SKAction.sequence(actions)

        run(sequence) { [weak self] in
            guard let self = self else { return }
            self.isMoving = false
            self.movementPath = []
            self.timerLabel?.isHidden = true
            completion()
        }
    }

    // MARK: - Visibility

    func updateVisibility(for player: Player) {
        if let fogOfWar = player.fogOfWar {
            let visibility = fogOfWar.getVisibilityLevel(at: coordinate)
            let shouldShow = visibility == .visible &&
                            fogOfWar.shouldShowEntity(reinforcement, at: coordinate)
            self.isHidden = !shouldShow
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        timerLabel?.removeFromParent()
        directionArrow?.removeFromParent()
        self.removeFromParent()
    }
}
