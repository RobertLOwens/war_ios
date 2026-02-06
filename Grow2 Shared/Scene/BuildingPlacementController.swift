import UIKit
import SpriteKit

/// Protocol for building placement events
protocol BuildingPlacementDelegate: AnyObject {
    func buildingPlacementController(_ controller: BuildingPlacementController, didSelectLocation coordinate: HexCoordinate)
    func buildingPlacementController(_ controller: BuildingPlacementController, didEnterRotationPreviewFor buildingType: BuildingType, at coordinate: HexCoordinate)
    func buildingPlacementControllerDidExitRotationPreview(_ controller: BuildingPlacementController)
    func buildingPlacementController(_ contwroller: BuildingPlacementController, showAlertWithTitle title: String, message: String)
    func buildingPlacementController(_ controller: BuildingPlacementController, didConfirmRotation coordinate: HexCoordinate, rotation: Int)
}

/// Manages building placement mode and rotation preview for multi-tile buildings
class BuildingPlacementController {

    // MARK: - Properties

    weak var scene: SKScene?
    weak var hexMap: HexMap?
    weak var player: Player?
    weak var delegate: BuildingPlacementDelegate?

    // Building placement mode
    var isInBuildingPlacementMode: Bool = false
    var placementBuildingType: BuildingType?
    var placementVillagerGroup: VillagerGroup?
    private var highlightedTiles: [SKShapeNode] = []
    private var validPlacementCoordinates: [HexCoordinate] = []

    // Rotation preview mode for multi-tile buildings
    var isInRotationPreviewMode: Bool = false
    var rotationPreviewAnchor: HexCoordinate?
    var rotationPreviewType: BuildingType?
    var rotationPreviewRotation: Int = 0
    private var rotationPreviewHighlights: [SKShapeNode] = []

    // MARK: - Initialization

    init(scene: SKScene, hexMap: HexMap?, player: Player?) {
        self.scene = scene
        self.hexMap = hexMap
        self.player = player
    }

    // MARK: - Building Placement Mode

    /// Enters building placement mode and highlights valid tiles
    func enterBuildingPlacementMode(buildingType: BuildingType, villagerGroup: VillagerGroup?) {
        isInBuildingPlacementMode = true
        placementBuildingType = buildingType
        placementVillagerGroup = villagerGroup

        // Find all valid placement coordinates
        validPlacementCoordinates = findValidBuildingLocations(for: buildingType)

        // Highlight valid tiles
        highlightValidPlacementTiles()

        debugLog("Entered building placement mode for \(buildingType.displayName)")
        debugLog("   Found \(validPlacementCoordinates.count) valid locations")
    }

    /// Exits building placement mode and clears highlights
    func exitBuildingPlacementMode() {
        isInBuildingPlacementMode = false
        placementBuildingType = nil
        placementVillagerGroup = nil
        validPlacementCoordinates = []
        clearPlacementHighlights()

        debugLog("Exited building placement mode")
    }

    /// Finds all valid locations for a building type
    private func findValidBuildingLocations(for buildingType: BuildingType) -> [HexCoordinate] {
        guard let player = player, let hexMap = hexMap else { return [] }

        var validCoordinates: [HexCoordinate] = []

        for (coord, tile) in hexMap.tiles {
            // Check visibility
            let visibility = player.getVisibilityLevel(at: coord)
            guard visibility == .visible else { continue }

            // Check if building can be placed (basic terrain check)
            guard hexMap.canPlaceBuilding(at: coord, buildingType: buildingType) else { continue }

            // For multi-tile buildings, we need to check all rotations
            if buildingType.requiresRotation {
                // For now, just check if ANY rotation works
                for rotation in 0..<6 {
                    let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: coord, rotation: rotation)
                    let allValid = occupiedCoords.allSatisfy { occupied in
                        hexMap.canPlaceBuildingOnTile(at: occupied)
                    }
                    if allValid {
                        validCoordinates.append(coord)
                        break
                    }
                }
            } else {
                validCoordinates.append(coord)
            }
        }

        return validCoordinates
    }

    /// Highlights valid placement tiles with a green stroke
    private func highlightValidPlacementTiles() {
        guard let scene = scene else { return }
        clearPlacementHighlights()

        for coord in validPlacementCoordinates {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)

            // Create a hexagon highlight shape
            let highlight = createHexHighlight(at: position, color: UIColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 0.8))
            highlight.name = "placementHighlight_\(coord.q)_\(coord.r)"
            highlight.zPosition = 50

            scene.addChild(highlight)
            highlightedTiles.append(highlight)

            // Add pulsing animation
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 0.5),
                SKAction.fadeAlpha(to: 0.8, duration: 0.5)
            ])
            highlight.run(SKAction.repeatForever(pulse))
        }
    }

    /// Creates a hexagon-shaped highlight node (isometric)
    private func createHexHighlight(at position: CGPoint, color: UIColor) -> SKShapeNode {
        let radius: CGFloat = HexTileNode.hexRadius - 2
        let isoRatio = HexTileNode.isoRatio
        let path = UIBezierPath()

        for i in 0..<6 {
            let angle = CGFloat(i) * CGFloat.pi / 3 - CGFloat.pi / 6
            let x = radius * cos(angle)
            let y = radius * sin(angle) * isoRatio  // Apply isometric compression

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.close()

        let shape = SKShapeNode(path: path.cgPath)
        shape.position = position
        shape.strokeColor = color
        shape.lineWidth = 4
        shape.fillColor = color.withAlphaComponent(0.2)
        shape.glowWidth = 2

        return shape
    }

    /// Clears all placement highlight nodes
    private func clearPlacementHighlights() {
        for highlight in highlightedTiles {
            highlight.removeFromParent()
        }
        highlightedTiles.removeAll()
    }

    /// Handles touch during building placement mode
    func handleBuildingPlacementTouch(at location: CGPoint, nodesAtPoint: [SKNode]) {
        // Find the hex coordinate at this location
        let hexCoord = HexMap.pixelToHex(point: location)

        // Check if this is a valid placement location
        if validPlacementCoordinates.contains(hexCoord) {
            debugLog("Valid placement location selected: (\(hexCoord.q), \(hexCoord.r))")

            // Notify delegate with selected coordinate
            delegate?.buildingPlacementController(self, didSelectLocation: hexCoord)

            // Exit placement mode
            exitBuildingPlacementMode()
        } else {
            debugLog("Invalid placement location: (\(hexCoord.q), \(hexCoord.r))")
            // Optionally show feedback that this isn't valid
        }
    }

    // MARK: - Rotation Preview Mode for Multi-Tile Buildings

    /// Enters rotation preview mode for multi-tile buildings (Castle, Fort)
    func enterRotationPreviewMode(buildingType: BuildingType, anchor: HexCoordinate) {
        // Exit any existing placement mode
        exitBuildingPlacementMode()

        isInRotationPreviewMode = true
        rotationPreviewAnchor = anchor
        rotationPreviewType = buildingType
        rotationPreviewRotation = 0

        // Show initial preview at rotation 0
        updateRotationPreview()

        // Notify delegate to show UI buttons
        delegate?.buildingPlacementController(self, didEnterRotationPreviewFor: buildingType, at: anchor)

        debugLog("Entered rotation preview mode for \(buildingType.displayName) at (\(anchor.q), \(anchor.r))")
    }

    /// Updates the rotation preview highlights to show current rotation
    func updateRotationPreview() {
        guard let scene = scene, let hexMap = hexMap else { return }

        // Remove previous highlights
        clearRotationPreviewHighlights()

        guard let anchor = rotationPreviewAnchor,
              let buildingType = rotationPreviewType else { return }

        // Get the coordinates this rotation would occupy
        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: anchor, rotation: rotationPreviewRotation)

        // Check if all tiles are valid (use single-tile check, not multi-tile recalculation)
        let allValid = occupiedCoords.allSatisfy { coord in
            hexMap.canPlaceBuildingOnTile(at: coord)
        }

        // Create highlight for each tile
        for (index, coord) in occupiedCoords.enumerated() {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            let isValid = hexMap.canPlaceBuildingOnTile(at: coord)

            // Color based on validity
            let highlightColor: UIColor
            if isValid {
                if buildingType == .castle {
                    highlightColor = UIColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 0.8)  // Gray for castle
                } else {
                    highlightColor = UIColor(red: 0.6, green: 0.45, blue: 0.3, alpha: 0.8)  // Brown for fort
                }
            } else {
                highlightColor = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.8)  // Red for blocked
            }

            let highlight = createHexFillShape(at: position, fillColor: highlightColor, isAnchor: index == 0, buildingType: buildingType)
            highlight.name = "rotationPreview_\(coord.q)_\(coord.r)"
            highlight.zPosition = 50

            scene.addChild(highlight)
            rotationPreviewHighlights.append(highlight)
        }

        // Add direction arrow on anchor tile to show rotation orientation
        if let anchorPosition = occupiedCoords.first.map({ HexMap.hexToPixel(q: $0.q, r: $0.r) }) {
            let arrow = createRotationArrow(at: anchorPosition, rotation: rotationPreviewRotation)
            arrow.name = "rotationArrow"
            arrow.zPosition = 55
            scene.addChild(arrow)
            rotationPreviewHighlights.append(arrow)
        }

        // Add pulsing animation to all highlights
        for highlight in rotationPreviewHighlights {
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.4),
                SKAction.fadeAlpha(to: 1.0, duration: 0.4)
            ])
            highlight.run(SKAction.repeatForever(pulse))
        }
    }

    /// Creates a filled hexagon shape for rotation preview (isometric)
    private func createHexFillShape(at position: CGPoint, fillColor: UIColor, isAnchor: Bool, buildingType: BuildingType?) -> SKShapeNode {
        let radius: CGFloat = HexTileNode.hexRadius - 2
        let isoRatio = HexTileNode.isoRatio
        let path = CGMutablePath()

        for i in 0..<6 {
            let angle = CGFloat(i) * CGFloat.pi / 3 - CGFloat.pi / 6
            let x = radius * cos(angle)
            let y = radius * sin(angle) * isoRatio  // Apply isometric compression

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        let shape = SKShapeNode(path: path)
        shape.position = position
        shape.fillColor = fillColor
        shape.strokeColor = isAnchor ? .white : fillColor.withAlphaComponent(0.5)
        shape.lineWidth = isAnchor ? 3 : 2
        shape.glowWidth = isAnchor ? 2 : 0

        // Add label on anchor tile
        if isAnchor, let buildingType = buildingType {
            let label = SKLabelNode(fontNamed: "Helvetica-Bold")
            label.text = buildingType == .castle ? "CASTLE" : "FORT"
            label.fontSize = 10
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 5
            shape.addChild(label)
        }

        return shape
    }

    /// Creates an arrow showing the rotation direction
    private func createRotationArrow(at position: CGPoint, rotation: Int) -> SKShapeNode {
        let arrowPath = CGMutablePath()
        let arrowLength: CGFloat = 15
        let arrowWidth: CGFloat = 8

        // Arrow points in the rotation direction
        arrowPath.move(to: CGPoint(x: 0, y: arrowLength))
        arrowPath.addLine(to: CGPoint(x: -arrowWidth, y: 0))
        arrowPath.addLine(to: CGPoint(x: arrowWidth, y: 0))
        arrowPath.closeSubpath()

        let arrow = SKShapeNode(path: arrowPath)
        arrow.position = position
        arrow.fillColor = .white
        arrow.strokeColor = .black
        arrow.lineWidth = 1

        // Rotate arrow based on rotation value (0-5 maps to 60-degree increments)
        // Direction 0 = East, 1 = Northeast, etc.
        let angles: [CGFloat] = [0, CGFloat.pi / 3, 2 * CGFloat.pi / 3, CGFloat.pi, -2 * CGFloat.pi / 3, -CGFloat.pi / 3]
        arrow.zRotation = angles[rotation % 6] - CGFloat.pi / 2  // Adjust for arrow pointing up

        return arrow
    }

    /// Cycles to the next rotation (0-5)
    func cycleRotationPreview() {
        guard isInRotationPreviewMode else { return }

        rotationPreviewRotation = (rotationPreviewRotation + 1) % 6
        updateRotationPreview()

        let directions = ["East", "Southeast", "Southwest", "West", "Northwest", "Northeast"]
        debugLog("Rotation changed to \(directions[rotationPreviewRotation]) (\(rotationPreviewRotation))")
    }

    /// Confirms the current rotation and executes the build
    func confirmRotationPreview() -> Bool {
        guard isInRotationPreviewMode,
              let anchor = rotationPreviewAnchor,
              let buildingType = rotationPreviewType,
              let hexMap = hexMap else {
            return false
        }

        // Validate all tiles are clear (use single-tile check, not multi-tile recalculation)
        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: anchor, rotation: rotationPreviewRotation)
        let allValid = occupiedCoords.allSatisfy { coord in
            hexMap.canPlaceBuildingOnTile(at: coord)
        }

        guard allValid else {
            debugLog("Cannot build - some tiles are blocked")
            delegate?.buildingPlacementController(self, showAlertWithTitle: "Cannot Build", message: "Some tiles in this rotation are blocked. Rotate to find a valid position.")
            return false
        }

        // Notify delegate
        delegate?.buildingPlacementController(self, didConfirmRotation: anchor, rotation: rotationPreviewRotation)

        // Exit preview mode
        exitRotationPreviewMode()

        return true
    }

    /// Exits rotation preview mode and cleans up
    func exitRotationPreviewMode() {
        isInRotationPreviewMode = false
        rotationPreviewAnchor = nil
        rotationPreviewType = nil
        rotationPreviewRotation = 0

        clearRotationPreviewHighlights()

        // Notify delegate to hide UI
        delegate?.buildingPlacementControllerDidExitRotationPreview(self)

        debugLog("Exited rotation preview mode")
    }

    /// Clears all rotation preview highlight nodes
    private func clearRotationPreviewHighlights() {
        for highlight in rotationPreviewHighlights {
            highlight.removeFromParent()
        }
        rotationPreviewHighlights.removeAll()
    }

    /// Returns whether the current rotation preview is valid for building
    func isCurrentRotationValid() -> Bool {
        guard let anchor = rotationPreviewAnchor,
              let buildingType = rotationPreviewType,
              let hexMap = hexMap else {
            return false
        }

        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: anchor, rotation: rotationPreviewRotation)
        return occupiedCoords.allSatisfy { coord in
            hexMap.canPlaceBuildingOnTile(at: coord)
        }
    }
}
