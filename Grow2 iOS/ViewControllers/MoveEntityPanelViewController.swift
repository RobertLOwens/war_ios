// ============================================================================
// FILE: MoveEntityPanelViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/MoveEntityPanelViewController.swift
// PURPOSE: Left-side slide-out panel for selecting entities to move,
//          with route preview and travel time estimation
// ============================================================================

import UIKit
import SpriteKit

class MoveEntityPanelViewController: SidePanelViewController {

    // MARK: - Properties

    var destinationCoordinate: HexCoordinate!
    var availableEntities: [EntityNode] = []
    var isDestinationUnexplored: Bool = false

    var onConfirm: ((EntityNode) -> Void)?

    private var selectedEntity: EntityNode?

    // MARK: - SidePanelViewController Overrides

    override var panelTitle: String {
        "Select Unit to Move"
    }

    override var panelSubtitle: String {
        if isDestinationUnexplored {
            return "Scout: (\(destinationCoordinate.q), \(destinationCoordinate.r)) 🌫️"
        }
        return "Destination: (\(destinationCoordinate.q), \(destinationCoordinate.r))"
    }

    override var confirmButtonTitle: String {
        "Confirm Move"
    }

    override var theme: PanelTheme {
        .move()
    }

    override var initialTravelTimeText: String {
        "Select a unit to see travel time"
    }

    // MARK: - Actions

    override func handleConfirm() {
        guard let entity = selectedEntity else { return }

        // Check if busy villager needs confirmation
        if let villagers = entity.entity as? VillagerGroup,
           villagers.currentTask != .idle {
            VillagerTaskWarningHelper.showMoveConfirmation(
                villagers: villagers,
                presenter: self
            ) { [weak self] in
                self?.executeMove(entity: entity)
            }
        } else {
            executeMove(entity: entity)
        }
    }

    private func executeMove(entity: EntityNode) {
        completeAndDismiss { [weak self] in
            self?.onConfirm?(entity)
        }
    }

    // MARK: - Entity Selection

    private func selectEntity(_ entity: EntityNode, at indexPath: IndexPath) {
        handleSelection(at: indexPath)
        selectedEntity = entity

        // Show route preview
        showRoutePreview(from: entity.coordinate, to: destinationCoordinate)

        // Update travel time
        updateTravelTime(for: entity, to: destinationCoordinate)

        // Update warning for busy villagers or unexplored destination
        if isDestinationUnexplored {
            updateUnexploredWarningLabel()
        } else if let villagers = entity.entity as? VillagerGroup {
            updateMoveWarningLabel(for: villagers)
        } else {
            clearWarningLabel()
        }

        // Enable confirm button
        enableConfirmButton()
    }

    /// Updates the warning label for unexplored destination
    private func updateUnexploredWarningLabel() {
        updateWarningLabel(
            text: "🌫️ This area is unexplored. Your unit will reveal fog of war as it travels.",
            color: UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0)
        )
    }
}

// MARK: - UITableViewDelegate & DataSource

extension MoveEntityPanelViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableEntities.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntitySelectionCell.reuseIdentifier,
            for: indexPath
        ) as! EntitySelectionCell

        let entity = availableEntities[indexPath.row]
        let config = EntityCellConfiguration.entity(entity, targetCoordinate: destinationCoordinate)
        cell.configure(with: config, theme: theme)
        cell.setSelectedState(indexPath == selectedIndexPath)

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let entity = availableEntities[indexPath.row]
        selectEntity(entity, at: indexPath)
    }
}
