// ============================================================================
// FILE: FogOverlayNode.swift
// LOCATION: Create new file
// ============================================================================

import SpriteKit
import UIKit

class FogOverlayNode: SKShapeNode {
    
    let coordinate: HexCoordinate
    private var visibilityLevel: VisibilityLevel = .unexplored
    
    init(coordinate: HexCoordinate) {
        self.coordinate = coordinate
        super.init()

        self.path = HexTileNode.createHexagonPath(radius: HexTileNode.hexRadius)
        // Use isometric z-position for fog (still on top layer, but with depth sorting)
        self.zPosition = HexTileNode.isometricZPosition(q: coordinate.q, r: coordinate.r, baseLayer: HexTileNode.ZLayer.fog)
        self.lineWidth = 0
        self.isUserInteractionEnabled = false

        updateAppearance()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setVisibility(_ level: VisibilityLevel) {
        guard level != visibilityLevel else { return }
        visibilityLevel = level
        updateAppearance()
    }
    
    private func updateAppearance() {
        self.fillColor = visibilityLevel.fogColor
        self.alpha = visibilityLevel.fogAlpha

        // Add stroke for unexplored tiles to show map edges
        switch visibilityLevel {
        case .unexplored:
            self.strokeColor = UIColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 0.25)
            self.lineWidth = 1
        case .explored, .visible:
            self.strokeColor = .clear
            self.lineWidth = 0
        }

        // Completely hide the node if visible (performance optimization)
        self.isHidden = (visibilityLevel == .visible)
    }
}
