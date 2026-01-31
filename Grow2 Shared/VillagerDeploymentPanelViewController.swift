// ============================================================================
// FILE: VillagerDeploymentPanelViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/VillagerDeploymentPanelViewController.swift
// PURPOSE: Left-side slide-out panel for deploying villagers from a building
//          Offers two options: Deploy New (create new group) or Join Existing
// ============================================================================

import UIKit
import SpriteKit

class VillagerDeploymentPanelViewController: SidePanelViewController {

    // MARK: - Properties

    var building: BuildingNode!

    var onDeployNew: ((Int) -> Void)?
    var onJoinExisting: ((VillagerGroup, Int) -> Void)?

    private var selectedVillagerGroup: VillagerGroup?
    private var deployCount: Int = 1

    // Mode
    private enum DeployMode: Int {
        case deployNew = 0
        case joinExisting = 1
    }
    private var currentMode: DeployMode = .deployNew

    // Available villager groups for joining
    private var availableVillagerGroups: [VillagerGroup] = []

    // Custom UI Elements
    private var segmentedControl: UISegmentedControl!
    private var contentContainerView: UIView!

    // Deploy New mode views
    private var deployNewContentView: UIView!
    private var deploySlider: UISlider!
    private var deployCountLabel: UILabel!
    private var limitWarningLabel: UILabel!
    private var spawnInfoLabel: UILabel!

    // Join Existing mode views
    private var joinExistingContentView: UIView!
    private var joinTableView: UITableView!
    private var noGroupsLabel: UILabel!
    private var sendSlider: UISlider!
    private var sendCountLabel: UILabel!
    private var resultPreviewLabel: UILabel!
    private var joinTravelTimeLabel: UILabel!

    // MARK: - SidePanelViewController Overrides

    override var panelTitle: String {
        "\(building.buildingType.icon) \(building.buildingType.displayName)"
    }

    override var panelSubtitle: String {
        "Villagers in garrison: \(building.villagerGarrison)"
    }

    override var confirmButtonTitle: String {
        currentMode == .deployNew ? "Deploy Villagers" : "Send Villagers"
    }

    override var theme: PanelTheme {
        .villagerDeploy()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        loadAvailableVillagerGroups()
        super.viewDidLoad()
    }

    // MARK: - Data Loading

    private func loadAvailableVillagerGroups() {
        guard let player = player else { return }

        // Get all villager groups owned by the player
        availableVillagerGroups = player.entities.compactMap { entity -> VillagerGroup? in
            guard let villagerGroup = entity as? VillagerGroup else { return nil }
            return villagerGroup
        }

        // Sort by distance to building
        availableVillagerGroups.sort { group1, group2 in
            let dist1 = group1.coordinate.distance(to: building.coordinate)
            let dist2 = group2.coordinate.distance(to: building.coordinate)
            return dist1 < dist2
        }
    }

    // MARK: - Additional Setup

    override func additionalSetup() {
        // Hide the default table view and preview section - we'll use custom layouts
        tableView.isHidden = true
        previewSection.isHidden = true

        setupSegmentedControl()
        setupContentContainer()
        setupDeployNewContent()
        setupJoinExistingContent()
        updateModeContent()
        updateConfirmButtonForMode()
    }

    private func setupSegmentedControl() {
        let segmentY: CGFloat = 90

        segmentedControl = UISegmentedControl(items: ["Deploy New", "Join Existing"])
        segmentedControl.frame = CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: segmentY,
            width: PanelLayoutConstants.contentWidth,
            height: 36
        )
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        segmentedControl.selectedSegmentTintColor = UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1.0)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        panelView.addSubview(segmentedControl)

        // Disable "Join Existing" if no villager groups exist
        if availableVillagerGroups.isEmpty {
            segmentedControl.setEnabled(false, forSegmentAt: 1)
        }
    }

    private func setupContentContainer() {
        let contentY: CGFloat = 140

        contentContainerView = UIView(frame: CGRect(
            x: 0,
            y: contentY,
            width: panelWidth,
            height: view.bounds.height - contentY - 120
        ))
        contentContainerView.backgroundColor = .clear
        panelView.addSubview(contentContainerView)
    }

    private func setupDeployNewContent() {
        deployNewContentView = UIView(frame: contentContainerView.bounds)
        deployNewContentView.backgroundColor = .clear
        contentContainerView.addSubview(deployNewContentView)

        var yOffset: CGFloat = 20

        // Deploy count label
        let deployLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: yOffset,
            width: PanelLayoutConstants.contentWidth,
            height: 24
        ))
        deployLabel.text = "Deploy count:"
        deployLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        deployLabel.textColor = theme.primaryTextColor
        deployNewContentView.addSubview(deployLabel)
        yOffset += 30

        // Slider
        let villagerCount = building.villagerGarrison
        deploySlider = UISlider(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: yOffset,
            width: panelWidth - 100,
            height: 30
        ))
        deploySlider.minimumValue = 1
        deploySlider.maximumValue = Float(max(1, villagerCount))
        deploySlider.value = Float(min(5, villagerCount))
        deploySlider.minimumTrackTintColor = UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0)
        deploySlider.maximumTrackTintColor = UIColor(white: 0.3, alpha: 1.0)
        deploySlider.addTarget(self, action: #selector(deploySliderChanged(_:)), for: .valueChanged)
        deployNewContentView.addSubview(deploySlider)

        // Count label
        deployCountLabel = UILabel(frame: CGRect(
            x: panelWidth - 80,
            y: yOffset,
            width: 60,
            height: 30
        ))
        deployCountLabel.text = "\(Int(deploySlider.value))"
        deployCountLabel.font = UIFont.boldSystemFont(ofSize: 18)
        deployCountLabel.textColor = theme.primaryTextColor
        deployCountLabel.textAlignment = .center
        deployNewContentView.addSubview(deployCountLabel)
        yOffset += 50

        // Spawn location info
        spawnInfoLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: yOffset,
            width: PanelLayoutConstants.contentWidth,
            height: 20
        ))
        spawnInfoLabel.text = "Spawn at nearest walkable tile"
        spawnInfoLabel.font = UIFont.systemFont(ofSize: 13)
        spawnInfoLabel.textColor = theme.tertiaryTextColor
        deployNewContentView.addSubview(spawnInfoLabel)
        yOffset += 40

        // Limit warning (shown if at entity limit)
        limitWarningLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: yOffset,
            width: PanelLayoutConstants.contentWidth,
            height: 60
        ))
        limitWarningLabel.numberOfLines = 0
        limitWarningLabel.font = UIFont.systemFont(ofSize: 14)
        limitWarningLabel.textColor = theme.warningTextColor
        limitWarningLabel.isHidden = true
        deployNewContentView.addSubview(limitWarningLabel)

        // Check if at limit
        if let error = player?.getVillagerGroupSpawnError() {
            limitWarningLabel.text = "Limit: \(error)"
            limitWarningLabel.isHidden = false
        }

        deployCount = Int(deploySlider.value)
    }

    private func setupJoinExistingContent() {
        joinExistingContentView = UIView(frame: contentContainerView.bounds)
        joinExistingContentView.backgroundColor = .clear
        joinExistingContentView.isHidden = true
        contentContainerView.addSubview(joinExistingContentView)

        var yOffset: CGFloat = 10

        // No groups label (shown if empty)
        noGroupsLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: yOffset,
            width: PanelLayoutConstants.contentWidth,
            height: 40
        ))
        noGroupsLabel.text = "No villager groups to join"
        noGroupsLabel.font = UIFont.systemFont(ofSize: 15)
        noGroupsLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        noGroupsLabel.textAlignment = .center
        noGroupsLabel.isHidden = !availableVillagerGroups.isEmpty
        joinExistingContentView.addSubview(noGroupsLabel)

        // Table view for existing villager groups
        let tableHeight: CGFloat = 180
        joinTableView = UITableView(frame: CGRect(
            x: 0,
            y: yOffset,
            width: panelWidth,
            height: tableHeight
        ), style: .plain)
        joinTableView.backgroundColor = .clear
        joinTableView.separatorColor = theme.separatorColor
        joinTableView.delegate = self
        joinTableView.dataSource = self
        joinTableView.register(EntitySelectionCell.self, forCellReuseIdentifier: EntitySelectionCell.reuseIdentifier)
        joinTableView.isHidden = availableVillagerGroups.isEmpty
        joinExistingContentView.addSubview(joinTableView)
        yOffset += tableHeight + 10

        // Send count section
        let sendLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: yOffset,
            width: PanelLayoutConstants.contentWidth,
            height: 24
        ))
        sendLabel.text = "Send villagers:"
        sendLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        sendLabel.textColor = theme.primaryTextColor
        joinExistingContentView.addSubview(sendLabel)
        yOffset += 30

        // Send slider
        let villagerCount = building.villagerGarrison
        sendSlider = UISlider(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: yOffset,
            width: panelWidth - 100,
            height: 30
        ))
        sendSlider.minimumValue = 1
        sendSlider.maximumValue = Float(max(1, villagerCount))
        sendSlider.value = Float(min(5, villagerCount))
        sendSlider.minimumTrackTintColor = UIColor(red: 0.3, green: 0.5, blue: 0.6, alpha: 1.0)
        sendSlider.maximumTrackTintColor = UIColor(white: 0.3, alpha: 1.0)
        sendSlider.addTarget(self, action: #selector(sendSliderChanged(_:)), for: .valueChanged)
        joinExistingContentView.addSubview(sendSlider)

        // Send count label
        sendCountLabel = UILabel(frame: CGRect(
            x: panelWidth - 80,
            y: yOffset,
            width: 60,
            height: 30
        ))
        sendCountLabel.text = "\(Int(sendSlider.value))"
        sendCountLabel.font = UIFont.boldSystemFont(ofSize: 18)
        sendCountLabel.textColor = theme.primaryTextColor
        sendCountLabel.textAlignment = .center
        joinExistingContentView.addSubview(sendCountLabel)
        yOffset += 45

        // Travel time label
        joinTravelTimeLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: yOffset,
            width: PanelLayoutConstants.contentWidth,
            height: 20
        ))
        joinTravelTimeLabel.text = "Select a group to see travel time"
        joinTravelTimeLabel.font = UIFont.systemFont(ofSize: 13)
        joinTravelTimeLabel.textColor = theme.tertiaryTextColor
        joinExistingContentView.addSubview(joinTravelTimeLabel)
        yOffset += 25

        // Result preview label
        resultPreviewLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: yOffset,
            width: PanelLayoutConstants.contentWidth,
            height: 20
        ))
        resultPreviewLabel.text = ""
        resultPreviewLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        resultPreviewLabel.textColor = UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)
        joinExistingContentView.addSubview(resultPreviewLabel)
    }

    // MARK: - Mode Switching

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        currentMode = DeployMode(rawValue: sender.selectedSegmentIndex) ?? .deployNew
        updateModeContent()
        clearPathPreview()

        // Update button title
        confirmButton.setTitle(confirmButtonTitle, for: .normal)
        updateConfirmButtonForMode()
    }

    private func updateModeContent() {
        switch currentMode {
        case .deployNew:
            deployNewContentView.isHidden = false
            joinExistingContentView.isHidden = true
        case .joinExisting:
            deployNewContentView.isHidden = true
            joinExistingContentView.isHidden = false
        }
    }

    private func updateConfirmButtonForMode() {
        switch currentMode {
        case .deployNew:
            // Check if can deploy new
            let canDeploy = player?.getVillagerGroupSpawnError() == nil
            if canDeploy {
                enableConfirmButton()
            } else {
                disableConfirmButton()
            }

        case .joinExisting:
            // Need a selected group
            if selectedVillagerGroup != nil {
                confirmButton.isEnabled = true
                confirmButton.backgroundColor = UIColor(red: 0.2, green: 0.5, blue: 0.6, alpha: 1.0)
            } else {
                disableConfirmButton()
            }
        }
    }

    // MARK: - Actions

    @objc private func deploySliderChanged(_ slider: UISlider) {
        deployCount = Int(slider.value)
        deployCountLabel.text = "\(deployCount)"
    }

    @objc private func sendSliderChanged(_ slider: UISlider) {
        deployCount = Int(slider.value)
        sendCountLabel.text = "\(deployCount)"
        updateResultPreview()
    }

    override func handleConfirm() {
        switch currentMode {
        case .deployNew:
            let count = Int(deploySlider.value)
            completeAndDismiss { [weak self] in
                self?.onDeployNew?(count)
            }

        case .joinExisting:
            guard let targetGroup = selectedVillagerGroup else { return }
            let count = Int(sendSlider.value)
            completeAndDismiss { [weak self] in
                self?.onJoinExisting?(targetGroup, count)
            }
        }
    }

    // MARK: - Group Selection

    private func selectVillagerGroup(_ group: VillagerGroup, at indexPath: IndexPath) {
        // Deselect previous
        if let previousIndex = selectedIndexPath,
           let previousCell = joinTableView.cellForRow(at: previousIndex) as? EntitySelectionCell {
            previousCell.setSelectedState(false)
        }

        selectedVillagerGroup = group
        selectedIndexPath = indexPath

        // Highlight selected cell
        if let cell = joinTableView.cellForRow(at: indexPath) as? EntitySelectionCell {
            cell.setSelectedState(true)
        }

        // Show path preview
        showRoutePreview(from: building.coordinate, to: group.coordinate, for: player)

        // Update travel time
        updateJoinTravelTime(for: group)

        // Update result preview
        updateResultPreview()

        // Update confirm button
        updateConfirmButtonForMode()
    }

    private func updateJoinTravelTime(for group: VillagerGroup) {
        guard let hexMap = hexMap else {
            joinTravelTimeLabel.text = "Unable to calculate"
            return
        }

        // Find path and calculate time
        if let path = hexMap.findPath(from: building.coordinate, to: group.coordinate, for: player) {
            // Calculate approximate travel time (base 0.5 seconds per tile for villagers)
            let baseTravelTimePerTile: TimeInterval = 0.5
            let travelTime = TimeInterval(path.count) * baseTravelTimePerTile

            let distance = path.count
            joinTravelTimeLabel.text = "\(distance) tiles, ~\(formatTravelTime(travelTime))"
            joinTravelTimeLabel.textColor = theme.primaryTextColor
        } else {
            joinTravelTimeLabel.text = "No path available"
            joinTravelTimeLabel.textColor = theme.errorTextColor
        }
    }

    private func updateResultPreview() {
        guard let group = selectedVillagerGroup else {
            resultPreviewLabel.text = ""
            return
        }

        let sendCount = Int(sendSlider.value)
        let currentCount = group.villagerCount
        let resultCount = currentCount + sendCount

        resultPreviewLabel.text = "Result: \(group.name) (\(currentCount) -> \(resultCount))"
    }

    // MARK: - Layout

    override func updateCustomLayouts() {
        // Update content container height
        let contentY: CGFloat = 140
        contentContainerView.frame = CGRect(
            x: 0,
            y: contentY,
            width: panelWidth,
            height: view.bounds.height - contentY - 120
        )
        deployNewContentView.frame = contentContainerView.bounds
        joinExistingContentView.frame = contentContainerView.bounds
    }
}

// MARK: - UITableViewDelegate & DataSource

extension VillagerDeploymentPanelViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Only the join existing table view uses this
        if tableView == joinTableView {
            return availableVillagerGroups.count
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntitySelectionCell.reuseIdentifier,
            for: indexPath
        ) as! EntitySelectionCell

        if tableView == joinTableView {
            let group = availableVillagerGroups[indexPath.row]
            let config = EntityCellConfiguration.villagerGroupForJoin(group, targetCoordinate: building.coordinate)
            cell.configure(with: config, theme: theme)
            cell.setSelectedState(indexPath == selectedIndexPath)
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if tableView == joinTableView {
            let group = availableVillagerGroups[indexPath.row]
            selectVillagerGroup(group, at: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return PanelLayoutConstants.compactCellHeight
    }
}
