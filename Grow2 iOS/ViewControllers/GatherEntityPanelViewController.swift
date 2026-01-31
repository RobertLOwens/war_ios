// ============================================================================
// FILE: GatherEntityPanelViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/GatherEntityPanelViewController.swift
// PURPOSE: Left-side slide-out panel for selecting villager groups to gather
//          resources or hunt animals, with route preview and task warnings
// ============================================================================

import UIKit
import SpriteKit

class GatherEntityPanelViewController: SidePanelViewController {

    // MARK: - Mode

    enum GatherMode {
        case gather
        case hunt
    }

    // MARK: - Properties

    var resourcePoint: ResourcePointNode!
    var availableVillagers: [VillagerGroup] = []
    var mode: GatherMode = .gather

    var onConfirm: ((VillagerGroup) -> Void)?

    private var selectedVillagers: VillagerGroup?

    // UI Elements for custom sections
    private var resourceInfoView: UIView!

    // MARK: - SidePanelViewController Overrides

    override var panelTitle: String {
        mode == .hunt ? "Select Villagers to Hunt" : "Select Villagers to Gather"
    }

    override var panelSubtitle: String {
        "Target: (\(resourcePoint.coordinate.q), \(resourcePoint.coordinate.r))"
    }

    override var confirmButtonTitle: String {
        mode == .hunt ? "Hunt" : "Gather"
    }

    override var theme: PanelTheme {
        mode == .hunt ? .hunt() : .gather()
    }

    override var initialTravelTimeText: String {
        "Select villagers to see travel time"
    }

    override var infoSectionHeight: CGFloat {
        PanelLayoutConstants.resourceInfoSectionHeight
    }

    // MARK: - Additional Setup

    override func additionalSetup() {
        setupResourceInfo()
    }

    private func setupResourceInfo() {
        // Resource info section
        let resourceInfoY: CGFloat = PanelLayoutConstants.headerHeight
        resourceInfoView = UIView(frame: CGRect(
            x: 0,
            y: resourceInfoY,
            width: panelWidth,
            height: PanelLayoutConstants.resourceInfoSectionHeight
        ))
        resourceInfoView.backgroundColor = theme.previewSectionBackgroundColor
        panelView.addSubview(resourceInfoView)

        // Resource icon and name
        let resourceLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 8,
            width: PanelLayoutConstants.contentWidth,
            height: 22
        ))
        resourceLabel.text = "\(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"
        resourceLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        resourceLabel.textColor = theme.primaryTextColor
        resourceInfoView.addSubview(resourceLabel)

        // Resource details
        let detailLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 32,
            width: PanelLayoutConstants.contentWidth,
            height: 32
        ))
        if mode == .hunt {
            detailLabel.text = "Health: \(Int(resourcePoint.currentHealth))/\(Int(resourcePoint.resourceType.health))\nFood: \(resourcePoint.remainingAmount)"
        } else {
            let gatherers = resourcePoint.getTotalVillagersGathering()
            let maxGatherers = ResourcePointNode.maxVillagersPerTile
            detailLabel.text = "Remaining: \(resourcePoint.remainingAmount)\nGatherers: \(gatherers)/\(maxGatherers)"
        }
        detailLabel.font = UIFont.systemFont(ofSize: 13)
        detailLabel.textColor = theme.secondaryTextColor
        detailLabel.numberOfLines = 2
        resourceInfoView.addSubview(detailLabel)
    }

    // MARK: - Actions

    override func handleConfirm() {
        guard let villagers = selectedVillagers else { return }

        // Check if busy villager needs confirmation
        if villagers.currentTask != .idle {
            let actionName = mode == .hunt ? "hunt" : "gather"
            let buttonTitle = mode == .hunt ? "Hunt Anyway" : "Gather Anyway"

            VillagerTaskWarningHelper.showBusyVillagerConfirmation(
                villagers: villagers,
                actionName: actionName,
                actionButtonTitle: buttonTitle,
                presenter: self
            ) { [weak self] in
                self?.executeGather(villagers: villagers)
            }
        } else {
            executeGather(villagers: villagers)
        }
    }

    private func executeGather(villagers: VillagerGroup) {
        completeAndDismiss { [weak self] in
            self?.onConfirm?(villagers)
        }
    }

    // MARK: - Villager Selection

    private func selectVillager(_ villager: VillagerGroup, at indexPath: IndexPath) {
        handleSelection(at: indexPath)
        selectedVillagers = villager

        // Show route preview
        showRoutePreview(from: villager.coordinate, to: resourcePoint.coordinate)

        // Update travel time
        updateTravelTimeForVillager(villager)

        // Update warning for busy villagers
        updateWarningLabel(for: villager)

        // Enable confirm button
        enableConfirmButton()
    }

    private func updateTravelTimeForVillager(_ villager: VillagerGroup) {
        guard let hexMap = hexMap else {
            travelTimeLabel.text = "Unable to calculate"
            return
        }

        // Find entity node for the villager
        guard let entityNode = hexMap.entities.first(where: {
            ($0.entity as? VillagerGroup)?.id == villager.id
        }) else {
            travelTimeLabel.text = "Unable to calculate"
            return
        }

        updateTravelTime(for: entityNode, to: resourcePoint.coordinate)
    }
}

// MARK: - UITableViewDelegate & DataSource

extension GatherEntityPanelViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableVillagers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntitySelectionCell.reuseIdentifier,
            for: indexPath
        ) as! EntitySelectionCell

        let villager = availableVillagers[indexPath.row]
        let config = EntityCellConfiguration.villagerGroup(villager, targetCoordinate: resourcePoint.coordinate)
        cell.configure(with: config, theme: theme)
        cell.setSelectedState(indexPath == selectedIndexPath)

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let villager = availableVillagers[indexPath.row]
        selectVillager(villager, at: indexPath)
    }
}
