// ============================================================================
// FILE: GameScene+InputHandling.swift
// PURPOSE: Touch handling, drag-to-move, entity selection, and tile selection
//          for GameScene
// ============================================================================

import UIKit
import SpriteKit

// MARK: - Touch Handling

extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        lastTouchPosition = location

        // Check if touch starts on a tile with player-owned entities
        if let coordinate = getTileCoordinate(at: location) {
            let entitiesAtCoord = hexMap?.getEntities(at: coordinate) ?? []

            // Filter to player-owned, non-moving entities
            let ownedEntities = entitiesAtCoord.filter { entity in
                guard entity.entity.owner?.id == player?.id, !entity.isMoving else { return false }
                // For armies, check not in combat
                if let army = entity.armyReference {
                    return !GameEngine.shared.combatEngine.isInCombat(armyID: army.id)
                }
                return true
            }

            if ownedEntities.count == 1 {
                dragStartCoordinate = coordinate
                dragSourceEntity = ownedEntities[0]
            } else if ownedEntities.count > 1 {
                gameDelegate?.gameScene(self, showAlertWithTitle: "Multiple Units",
                    message: "There are multiple units on this tile. Tap to select one first.")
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let startPos = lastTouchPosition,
              let sourceEntity = dragSourceEntity,
              let startCoord = dragStartCoordinate else { return }

        let currentPos = touch.location(in: self)
        let distance = hypot(currentPos.x - startPos.x, currentPos.y - startPos.y)

        // Enter drag mode if distance exceeds threshold
        if distance > dragThreshold && !isDragging {
            isDragging = true
        }

        if isDragging {
            if let destCoord = getTileCoordinate(at: currentPos),
               destCoord != startCoord {
                if let path = hexMap?.findPath(from: startCoord, to: destCoord) {
                    updateDragPathPreview(from: startCoord, path: path)
                } else {
                    clearDragPathPreview()
                }
            } else {
                clearDragPathPreview()
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Handle drag-to-move completion
        if isDragging, let sourceEntity = dragSourceEntity, let startCoord = dragStartCoordinate {
            clearDragPathPreview()

            if let destCoord = getTileCoordinate(at: location), destCoord != startCoord {
                executeDragMove(entity: sourceEntity, to: destCoord)
            }

            isDragging = false
            dragSourceEntity = nil
            dragStartCoordinate = nil
            lastTouchPosition = nil
            return
        }

        // Reset drag state
        isDragging = false
        dragSourceEntity = nil
        dragStartCoordinate = nil

        // Only handle as tap if not panning (gesture recognizer sets isPanning)
        if !isPanning {
            handleTouch(at: location)
        }

        lastTouchPosition = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearDragPathPreview()
        isDragging = false
        dragSourceEntity = nil
        dragStartCoordinate = nil
        lastTouchPosition = nil
    }
}

// MARK: - Drag-to-Move Helpers

extension GameScene {

    /// Converts a touch point to a hex coordinate
    func getTileCoordinate(at point: CGPoint) -> HexCoordinate? {
        let nodesAtPoint = nodes(at: point)
        for node in nodesAtPoint {
            if let hexTile = node as? HexTileNode {
                return hexTile.coordinate
            }
        }
        return nil
    }

    /// Draws a cyan path preview line during drag
    func updateDragPathPreview(from start: HexCoordinate, path: [HexCoordinate]) {
        clearDragPathPreview()

        guard !path.isEmpty else { return }

        let bezierPath = UIBezierPath()
        let startPos = HexMap.hexToPixel(q: start.q, r: start.r)
        bezierPath.move(to: startPos)

        for coord in path {
            let pos = HexMap.hexToPixel(q: coord.q, r: coord.r)
            bezierPath.addLine(to: pos)
        }

        let shapeNode = SKShapeNode(path: bezierPath.cgPath)
        shapeNode.strokeColor = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.8)
        shapeNode.lineWidth = 4
        shapeNode.lineCap = .round
        shapeNode.lineJoin = .round
        shapeNode.zPosition = 150
        shapeNode.name = "dragPathPreview"
        shapeNode.glowWidth = 2

        addChild(shapeNode)
        dragPathPreview = shapeNode
    }

    /// Removes the drag path preview node
    func clearDragPathPreview() {
        dragPathPreview?.removeFromParent()
        dragPathPreview = nil
    }

    /// Cancels any in-progress drag (called by camera controller)
    func cancelDrag() {
        clearDragPathPreview()
        isDragging = false
        dragSourceEntity = nil
        dragStartCoordinate = nil
    }

    /// Executes a move command from a drag gesture
    func executeDragMove(entity: EntityNode, to destination: HexCoordinate) {
        guard let player = player else { return }

        let visibility = player.getVisibilityLevel(at: destination)
        if visibility == .unexplored {
            gameDelegate?.gameScene(self, showAlertWithTitle: "Scout Unknown Area?",
                message: "Moving to unexplored territory. Your unit will reveal the fog of war as it travels.")
        }

        if let army = entity.armyReference, let commander = army.commander {
            let currentStamina = Int(commander.stamina)
            let cost = Int(Commander.staminaCostPerCommand)

            gameDelegate?.gameScene(self, showConfirmation: "Move Army?",
                message: "This will cost \(cost) stamina.\nCurrent stamina: \(currentStamina)/100",
                confirmTitle: "Move",
                onConfirm: { [weak self] in
                    self?.performMove(entity: entity, to: destination, player: player)
                })
        } else {
            performMove(entity: entity, to: destination, player: player)
        }
    }

    func performMove(entity: EntityNode, to destination: HexCoordinate, player: Player) {
        let command = MoveCommand(
            playerID: player.id,
            entityID: entity.entity.id,
            destination: destination
        )

        let result = CommandExecutor.shared.execute(command)

        if !result.succeeded, let reason = result.failureReason {
            gameDelegate?.gameScene(self, showAlertWithTitle: "Cannot Move", message: reason)
        }

        deselectAll()
    }
}

// MARK: - Touch-to-Tap Handling

extension GameScene {

    func handleTouch(at location: CGPoint) {
        let nodesAtPoint = nodes(at: location)

        debugLog("🔍 Touch at location: \(location)")
        debugLog("🔍 Found \(nodesAtPoint.count) nodes")
        for (index, node) in nodesAtPoint.enumerated() {
            debugLog("   [\(index)] \(type(of: node)) - name: '\(node.name ?? "nil")' - zPos: \(node.zPosition)")
        }

        // Check if we're in building placement mode
        if isInBuildingPlacementMode {
            handleBuildingPlacementTouch(at: location, nodesAtPoint: nodesAtPoint)
            return
        }

        // Normal touch handling - ONLY look for HexTileNode
        for node in nodesAtPoint {
            if node is EntityNode {
                debugLog("   ⏭️ Skipping EntityNode")
                continue
            }
            if node is ResourcePointNode {
                debugLog("   ⏭️ Skipping ResourcePointNode")
                continue
            }
            if node is BuildingNode {
                debugLog("   ⏭️ Skipping BuildingNode")
                continue
            }

            if let hexTile = node as? HexTileNode {
                debugLog("   ✅ Found HexTileNode at (\(hexTile.coordinate.q), \(hexTile.coordinate.r))")
                guard let player = player else {
                    debugLog("⚠️ No player reference")
                    return
                }

                let visibility = player.getVisibilityLevel(at: hexTile.coordinate)

                if visibility == .visible || visibility == .explored {
                    selectTile(hexTile)
                    return
                } else if visibility == .unexplored {
                    selectUnexploredTile(hexTile)
                    return
                }
            }
        }

        debugLog("❌ No HexTileNode found in touch")
    }

    /// Selects an unexplored tile for potential movement/scouting
    func selectUnexploredTile(_ tile: HexTileNode) {
        selectedTile?.isSelected = false
        selectedEntity = nil

        tile.isSelected = true
        selectedTile = tile

        debugLog("Selected unexplored tile at q:\(tile.coordinate.q), r:\(tile.coordinate.r)")

        gameDelegate?.gameScene(self, didRequestUnexploredTileMenu: tile.coordinate)
    }

    /// Handles touch during building placement mode
    func handleBuildingPlacementTouch(at location: CGPoint, nodesAtPoint: [SKNode]) {
        buildingPlacementController.handleBuildingPlacementTouch(at: location, nodesAtPoint: nodesAtPoint)
    }
}
