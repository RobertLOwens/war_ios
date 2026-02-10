// ============================================================================
// FILE: BuildEntityPanelViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/BuildEntityPanelViewController.swift
// PURPOSE: Left-side slide-out panel for selecting villager groups to build,
//          with route preview and task warnings
// ============================================================================

import UIKit
import SpriteKit

class BuildEntityPanelViewController: SidePanelViewController {

    // MARK: - Properties

    var buildingType: BuildingType!
    var buildCoordinate: HexCoordinate!
    var rotation: Int = 0
    var availableVillagers: [EntityNode] = []

    var onConfirm: ((EntityNode) -> Void)?

    private var selectedVillager: EntityNode?

    // UI Elements for custom sections
    private var buildingInfoView: UIView!

    // MARK: - SidePanelViewController Overrides

    override var panelTitle: String {
        "Select Builder"
    }

    override var panelSubtitle: String {
        "Location: (\(buildCoordinate.q), \(buildCoordinate.r))"
    }

    override var confirmButtonTitle: String {
        "Confirm Build"
    }

    override var theme: PanelTheme {
        .build()
    }

    override var initialTravelTimeText: String {
        "Select villagers to see travel time"
    }

    override var infoSectionHeight: CGFloat {
        PanelLayoutConstants.tallInfoSectionHeight
    }

    // MARK: - Additional Setup

    override func additionalSetup() {
        setupBuildingInfo()
    }

    private func setupBuildingInfo() {
        // Building info section
        let buildingInfoY: CGFloat = PanelLayoutConstants.headerHeight
        buildingInfoView = UIView(frame: CGRect(
            x: 0,
            y: buildingInfoY,
            width: panelWidth,
            height: PanelLayoutConstants.tallInfoSectionHeight
        ))
        buildingInfoView.backgroundColor = theme.previewSectionBackgroundColor
        panelView.addSubview(buildingInfoView)

        // Building icon and name
        let buildingLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 8,
            width: PanelLayoutConstants.contentWidth,
            height: 22
        ))
        buildingLabel.text = "\(buildingType.icon) \(buildingType.displayName)"
        buildingLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        buildingLabel.textColor = theme.primaryTextColor
        buildingInfoView.addSubview(buildingLabel)

        // Calculate terrain cost multiplier for mountain tiles
        let occupiedCoords = buildingType.getOccupiedCoordinates(anchor: buildCoordinate, rotation: rotation)
        let hasMountain = occupiedCoords.contains { coord in
            hexMap?.getTile(at: coord)?.terrain == .mountain
        }
        let terrainMultiplier = hasMountain ? GameConfig.Terrain.mountainBuildingCostMultiplier : 1.0

        // Build cost (adjusted for terrain)
        var costString = ""
        for (resourceType, baseAmount) in buildingType.buildCost {
            let adjustedAmount = Int(ceil(Double(baseAmount) * terrainMultiplier))
            let hasEnough = player?.hasResource(resourceType, amount: adjustedAmount) ?? false
            let checkmark = hasEnough ? "\u{2713}" : "\u{2717}"
            costString += "\(resourceType.icon)\(adjustedAmount)\(checkmark) "
        }

        let costLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 32,
            width: PanelLayoutConstants.contentWidth,
            height: 20
        ))
        costLabel.text = "Cost: \(costString)"
        costLabel.font = UIFont.systemFont(ofSize: 13)
        costLabel.textColor = theme.secondaryTextColor
        buildingInfoView.addSubview(costLabel)

        // Mountain cost indicator
        if hasMountain {
            let mountainLabel = UILabel(frame: CGRect(
                x: PanelLayoutConstants.horizontalPadding,
                y: 52,
                width: PanelLayoutConstants.contentWidth,
                height: 16
            ))
            mountainLabel.text = "Mountain terrain: +25% cost"
            mountainLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            mountainLabel.textColor = UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0)
            buildingInfoView.addSubview(mountainLabel)
        }

        // Build time
        let buildTimeMinutes = Int(buildingType.buildTime) / 60
        let buildTimeSecs = Int(buildingType.buildTime) % 60
        let timeString = buildTimeMinutes > 0 ? "\(buildTimeMinutes)m \(buildTimeSecs)s" : "\(buildTimeSecs)s"

        let timeY: CGFloat = hasMountain ? 70 : 54
        let timeLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: timeY,
            width: PanelLayoutConstants.contentWidth,
            height: 20
        ))
        timeLabel.text = "Build time: \(timeString)"
        timeLabel.font = UIFont.systemFont(ofSize: 13)
        timeLabel.textColor = theme.tertiaryTextColor
        buildingInfoView.addSubview(timeLabel)
    }

    // MARK: - Actions

    override func handleConfirm() {
        guard let villagerNode = selectedVillager,
              let villagers = villagerNode.entity as? VillagerGroup else { return }

        // Check if busy villager needs confirmation
        if villagers.currentTask != .idle {
            VillagerTaskWarningHelper.showBusyVillagerConfirmation(
                villagers: villagers,
                actionName: "build",
                actionButtonTitle: "Build Anyway",
                presenter: self
            ) { [weak self] in
                self?.executeBuild(entity: villagerNode)
            }
        } else {
            executeBuild(entity: villagerNode)
        }
    }

    private func executeBuild(entity: EntityNode) {
        completeAndDismiss { [weak self] in
            self?.onConfirm?(entity)
        }
    }

    // MARK: - Villager Selection

    private func selectVillager(_ entity: EntityNode, at indexPath: IndexPath) {
        handleSelection(at: indexPath)
        selectedVillager = entity

        // Show route preview
        showRoutePreview(from: entity.coordinate, to: buildCoordinate)

        // Update travel time
        updateTravelTime(for: entity, to: buildCoordinate)

        // Update warning for busy villagers
        if let villagers = entity.entity as? VillagerGroup {
            updateWarningLabel(for: villagers)
        } else {
            clearWarningLabel()
        }

        // Enable confirm button
        enableConfirmButton()
    }
}

// MARK: - UITableViewDelegate & DataSource

extension BuildEntityPanelViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableVillagers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntitySelectionCell.reuseIdentifier,
            for: indexPath
        ) as! EntitySelectionCell

        let entity = availableVillagers[indexPath.row]
        if let config = EntityCellConfiguration.villagerGroupFromEntity(entity, targetCoordinate: buildCoordinate) {
            cell.configure(with: config, theme: theme)
        }
        cell.setSelectedState(indexPath == selectedIndexPath)

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let entity = availableVillagers[indexPath.row]
        selectVillager(entity, at: indexPath)
    }
}
