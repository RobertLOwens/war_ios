import UIKit
import SpriteKit

/// Renders movement paths for entities on the game map
class MovementPathRenderer {

    // MARK: - Properties

    weak var scene: SKScene?
    private var movementPathLine: SKShapeNode?

    // MARK: - Initialization

    init(scene: SKScene) {
        self.scene = scene
    }

    // MARK: - Path Drawing

    /// Draws a static movement path from a start coordinate through a series of waypoints
    func drawStaticMovementPath(from start: HexCoordinate, path: [HexCoordinate]) {
        // Remove old path line
        clearMovementPath()

        guard !path.isEmpty else { return }

        // Create path in world coordinates
        let bezierPath = UIBezierPath()

        // Start from entity's current position
        let startPos = HexMap.hexToPixel(q: start.q, r: start.r)
        bezierPath.move(to: startPos)

        // Draw line through each waypoint
        for coord in path {
            let worldPos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            bezierPath.addLine(to: worldPos)
        }

        // Create shape node
        movementPathLine = SKShapeNode(path: bezierPath.cgPath)
        movementPathLine?.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.7)
        movementPathLine?.lineWidth = 3
        movementPathLine?.lineCap = .round
        movementPathLine?.lineJoin = .round
        movementPathLine?.zPosition = 8 // Between tiles and entities

        // Add arrow at the end
        if let lastCoord = path.last {
            addArrowHead(to: path, from: start)
        }

        if let pathLine = movementPathLine {
            scene?.addChild(pathLine)
        }
    }

    /// Clears the current movement path from the scene
    func clearMovementPath() {
        movementPathLine?.removeFromParent()
        movementPathLine = nil
    }

    /// Updates the movement path as an entity moves, showing remaining waypoints
    func updateMovementPath(from currentPos: HexCoordinate, remainingPath: [HexCoordinate]) {
        // Remove old path
        clearMovementPath()

        guard !remainingPath.isEmpty else { return }

        // Draw path from current position to remaining waypoints
        let bezierPath = UIBezierPath()
        let startPos = HexMap.hexToPixel(q: currentPos.q, r: currentPos.r)
        bezierPath.move(to: startPos)

        for coord in remainingPath {
            let worldPos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            bezierPath.addLine(to: worldPos)
        }

        // Create new path line
        movementPathLine = SKShapeNode(path: bezierPath.cgPath)
        movementPathLine?.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.7)
        movementPathLine?.lineWidth = 3
        movementPathLine?.lineCap = .round
        movementPathLine?.lineJoin = .round
        movementPathLine?.zPosition = 8
        movementPathLine?.name = "movementPath"

        // Add arrow at the end
        if let lastCoord = remainingPath.last {
            let endPos = HexMap.hexToPixel(q: lastCoord.q, r: lastCoord.r)

            let previousCoord = remainingPath.count > 1 ? remainingPath[remainingPath.count - 2] : currentPos
            let prevPos = HexMap.hexToPixel(q: previousCoord.q, r: previousCoord.r)

            let dx = endPos.x - prevPos.x
            let dy = endPos.y - prevPos.y
            let angle = atan2(dy, dx)

            let arrowSize: CGFloat = 12
            let arrowPath = UIBezierPath()
            arrowPath.move(to: endPos)
            arrowPath.addLine(to: CGPoint(
                x: endPos.x - arrowSize * cos(angle - .pi / 6),
                y: endPos.y - arrowSize * sin(angle - .pi / 6)
            ))
            arrowPath.move(to: endPos)
            arrowPath.addLine(to: CGPoint(
                x: endPos.x - arrowSize * cos(angle + .pi / 6),
                y: endPos.y - arrowSize * sin(angle + .pi / 6)
            ))

            let arrowHead = SKShapeNode(path: arrowPath.cgPath)
            arrowHead.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.7)
            arrowHead.lineWidth = 3
            arrowHead.lineCap = .round
            movementPathLine?.addChild(arrowHead)
        }

        if let pathLine = movementPathLine {
            scene?.addChild(pathLine)
        }
    }

    // MARK: - Private Helpers

    private func addArrowHead(to path: [HexCoordinate], from start: HexCoordinate) {
        guard let lastCoord = path.last else { return }

        let endPos = HexMap.hexToPixel(q: lastCoord.q, r: lastCoord.r)

        // Calculate arrow direction from second-to-last point
        let previousCoord = path.count > 1 ? path[path.count - 2] : start
        let prevPos = HexMap.hexToPixel(q: previousCoord.q, r: previousCoord.r)

        let dx = endPos.x - prevPos.x
        let dy = endPos.y - prevPos.y
        let angle = atan2(dy, dx)

        // Create arrow head
        let arrowSize: CGFloat = 12
        let arrowPath = UIBezierPath()
        arrowPath.move(to: endPos)
        arrowPath.addLine(to: CGPoint(
            x: endPos.x - arrowSize * cos(angle - .pi / 6),
            y: endPos.y - arrowSize * sin(angle - .pi / 6)
        ))
        arrowPath.move(to: endPos)
        arrowPath.addLine(to: CGPoint(
            x: endPos.x - arrowSize * cos(angle + .pi / 6),
            y: endPos.y - arrowSize * sin(angle + .pi / 6)
        ))

        let arrowHead = SKShapeNode(path: arrowPath.cgPath)
        arrowHead.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.7)
        arrowHead.lineWidth = 3
        arrowHead.lineCap = .round
        movementPathLine?.addChild(arrowHead)
    }
}
