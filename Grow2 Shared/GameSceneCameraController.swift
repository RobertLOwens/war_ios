import UIKit
import SpriteKit

/// Manages camera controls for the GameScene including panning, zooming, and momentum
class GameSceneCameraController {

    // MARK: - Properties

    weak var scene: SKScene?
    weak var cameraNode: SKCameraNode?

    var cameraScale: CGFloat = 1.0
    private let minCameraScale: CGFloat = 0.5   // Zoomed in (closer)
    private let maxCameraScale: CGFloat = 2.5   // Zoomed out (further)

    var lastTouchPosition: CGPoint?
    var isPanning = false

    private var cameraVelocity: CGPoint = .zero
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var pinchGestureRecognizer: UIPinchGestureRecognizer?
    private var lastPanTranslation: CGPoint = .zero
    private var mapBounds: CGRect = .zero

    // MARK: - Initialization

    init(scene: SKScene, cameraNode: SKCameraNode) {
        self.scene = scene
        self.cameraNode = cameraNode
    }

    // MARK: - Setup

    func setupGestureRecognizers() {
        guard let view = scene?.view else { return }

        // Remove existing gesture recognizers if any
        if let panGR = panGestureRecognizer {
            view.removeGestureRecognizer(panGR)
        }
        if let pinchGR = pinchGestureRecognizer {
            view.removeGestureRecognizer(pinchGR)
        }

        // Pan gesture for smooth scrolling
        let panGR = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGR.minimumNumberOfTouches = 1
        panGR.maximumNumberOfTouches = 1
        view.addGestureRecognizer(panGR)
        panGestureRecognizer = panGR

        // Pinch gesture for zooming
        let pinchGR = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        view.addGestureRecognizer(pinchGR)
        pinchGestureRecognizer = pinchGR
    }

    func calculateMapBounds(hexMap: HexMap?) {
        // Calculate the bounds of the map in scene coordinates
        guard let hexMap = hexMap else { return }

        let hexRadius = HexTileNode.hexRadius

        // Use hexMap dimensions (handles both new and loaded games)
        let width = hexMap.width
        let height = hexMap.height

        // Get corner positions
        let minPos = HexMap.hexToPixel(q: 0, r: 0)
        let maxPos = HexMap.hexToPixel(q: width - 1, r: height - 1)

        // Add padding for hex size
        let padding = hexRadius * 2
        mapBounds = CGRect(
            x: minPos.x - padding,
            y: minPos.y - padding,
            width: (maxPos.x - minPos.x) + padding * 2,
            height: (maxPos.y - minPos.y) + padding * 2
        )
    }

    // MARK: - Gesture Handlers

    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let view = scene?.view,
              let cameraNode = cameraNode else { return }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .began:
            isPanning = true
            cameraVelocity = .zero
            lastPanTranslation = .zero

            // Cancel any in-progress entity drag
            if let gameScene = scene as? GameScene {
                gameScene.cancelDrag()
            }

        case .changed:
            // Calculate delta from last translation
            let delta = CGPoint(
                x: translation.x - lastPanTranslation.x,
                y: translation.y - lastPanTranslation.y
            )
            lastPanTranslation = translation

            // Apply movement (inverted and scaled)
            let scaledDelta = CGPoint(
                x: -delta.x * cameraScale,
                y: delta.y * cameraScale  // Inverted Y for SpriteKit coordinate system
            )
            cameraNode.position.x += scaledDelta.x
            cameraNode.position.y += scaledDelta.y

            // Constrain camera position
            constrainCameraPosition()

        case .ended, .cancelled:
            // Apply momentum based on velocity
            cameraVelocity = CGPoint(
                x: -velocity.x * cameraScale * 0.1,
                y: velocity.y * cameraScale * 0.1
            )

            // Limit maximum velocity
            let maxVelocity: CGFloat = 1500
            let speed = sqrt(cameraVelocity.x * cameraVelocity.x + cameraVelocity.y * cameraVelocity.y)
            if speed > maxVelocity {
                let scale = maxVelocity / speed
                cameraVelocity.x *= scale
                cameraVelocity.y *= scale
            }

            isPanning = false

        default:
            break
        }
    }

    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let view = scene?.view,
              let scene = scene,
              let cameraNode = cameraNode else { return }

        switch gesture.state {
        case .began, .changed:
            // Get the pinch center in scene coordinates
            let pinchCenter = gesture.location(in: view)
            let scenePoint = scene.convertPoint(fromView: pinchCenter)

            // Calculate new scale
            let newScale = cameraScale / gesture.scale
            let clampedScale = min(max(newScale, minCameraScale), maxCameraScale)

            // Only apply if scale actually changed
            if clampedScale != cameraScale {
                // Calculate the offset to zoom towards the pinch point
                let scaleDiff = clampedScale / cameraScale
                let offsetX = (scenePoint.x - cameraNode.position.x) * (1 - scaleDiff)
                let offsetY = (scenePoint.y - cameraNode.position.y) * (1 - scaleDiff)

                cameraScale = clampedScale
                cameraNode.setScale(cameraScale)

                // Adjust camera position to zoom towards pinch point
                cameraNode.position.x += offsetX
                cameraNode.position.y += offsetY

                // Constrain camera position
                constrainCameraPosition()
            }

            // Reset gesture scale to 1 to get incremental changes
            gesture.scale = 1.0

        case .ended, .cancelled:
            break

        default:
            break
        }
    }

    // MARK: - Camera Constraints

    func constrainCameraPosition() {
        guard mapBounds != .zero,
              let scene = scene,
              let cameraNode = cameraNode else { return }

        // Calculate the visible area based on current scale
        let visibleWidth = scene.size.width * cameraScale
        let visibleHeight = scene.size.height * cameraScale

        // Calculate allowed camera position range
        // Add vertical padding for better north/south edge visibility
        let verticalPadding: CGFloat = 200
        let minX = mapBounds.minX + visibleWidth / 2
        let maxX = mapBounds.maxX - visibleWidth / 2
        let minY = mapBounds.minY + visibleHeight / 2 - verticalPadding
        let maxY = mapBounds.maxY - visibleHeight / 2 + verticalPadding

        // If the map is smaller than the view, center it
        if minX > maxX {
            cameraNode.position.x = mapBounds.midX
        } else {
            cameraNode.position.x = min(max(cameraNode.position.x, minX), maxX)
        }

        if minY > maxY {
            cameraNode.position.y = mapBounds.midY
        } else {
            cameraNode.position.y = min(max(cameraNode.position.y, minY), maxY)
        }
    }

    // MARK: - Update Loop

    func applyCameraMomentum() {
        guard let cameraNode = cameraNode else { return }

        // Apply velocity with friction
        let friction: CGFloat = 0.92

        if abs(cameraVelocity.x) > 0.5 || abs(cameraVelocity.y) > 0.5 {
            cameraNode.position.x += cameraVelocity.x * 0.016  // Approximate frame time
            cameraNode.position.y += cameraVelocity.y * 0.016

            cameraVelocity.x *= friction
            cameraVelocity.y *= friction

            // Constrain after momentum
            constrainCameraPosition()
        } else {
            cameraVelocity = .zero
        }
    }

    // MARK: - Camera Focus

    /// Centers and zooms the camera to a specific coordinate
    func focusCamera(on coordinate: HexCoordinate, zoom: CGFloat? = nil, animated: Bool = true) {
        guard let cameraNode = cameraNode else { return }

        let targetPosition = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)

        if animated {
            let moveAction = SKAction.move(to: targetPosition, duration: 0.3)
            moveAction.timingMode = .easeInEaseOut
            cameraNode.run(moveAction)

            if let targetZoom = zoom {
                let zoomAction = SKAction.scale(to: targetZoom, duration: 0.3)
                zoomAction.timingMode = .easeInEaseOut
                cameraNode.run(zoomAction) { [weak self] in
                    self?.cameraScale = targetZoom
                }
            }
        } else {
            cameraNode.position = targetPosition
            if let targetZoom = zoom {
                cameraScale = targetZoom
                cameraNode.setScale(cameraScale)
            }
        }

        constrainCameraPosition()
    }
}
