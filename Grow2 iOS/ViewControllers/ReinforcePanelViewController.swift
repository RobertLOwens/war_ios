// ============================================================================
// FILE: ReinforcePanelViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/ReinforcePanelViewController.swift
// PURPOSE: Left-side slide-out panel for selecting buildings to send
//          reinforcements to an army, with route preview and unit selection
// ============================================================================

import UIKit
import SpriteKit

class ReinforcePanelViewController: SidePanelViewController {

    // MARK: - Properties

    var targetArmy: Army!
    var availableBuildings: [BuildingNode] = []

    var onConfirm: ((BuildingNode, [MilitaryUnitType: Int]) -> Void)?

    private var selectedBuilding: BuildingNode?
    private var selectedUnits: [MilitaryUnitType: Int] = [:]

    // UI Elements for custom sections
    private var unitSelectionView: UIView!
    private var unitSliders: [MilitaryUnitType: UISlider] = [:]
    private var unitCountLabels: [MilitaryUnitType: UILabel] = [:]
    private var unitsToSendLabel: UILabel!

    // MARK: - SidePanelViewController Overrides

    override var panelTitle: String {
        "Request Reinforcements"
    }

    override var panelSubtitle: String {
        let totalUnits = targetArmy.getTotalMilitaryUnits()
        return "Army: \(targetArmy.name) (\(totalUnits) units)"
    }

    override var confirmButtonTitle: String {
        "Send Reinforcements"
    }

    override var theme: PanelTheme {
        .reinforce()
    }

    override var initialTravelTimeText: String {
        "Select a building to see travel time"
    }

    // Custom table view size for reinforce panel
    override var tableViewTopOffset: CGFloat {
        PanelLayoutConstants.headerHeight
    }

    // MARK: - Additional Setup

    override func additionalSetup() {
        // Hide default warning label since we use preview section differently
        warningLabel.isHidden = true

        // Add units to send label to preview section
        unitsToSendLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 36,
            width: PanelLayoutConstants.contentWidth,
            height: 20
        ))
        unitsToSendLabel.text = "Units to send: 0"
        unitsToSendLabel.font = UIFont.systemFont(ofSize: 13)
        unitsToSendLabel.textColor = theme.tertiaryTextColor
        previewSection.addSubview(unitsToSendLabel)

        setupUnitSelectionSection()

        // Resize table view for this panel's unique layout
        let tableTop: CGFloat = PanelLayoutConstants.headerHeight
        let tableHeight: CGFloat = 200
        tableView.frame = CGRect(x: 0, y: tableTop, width: panelWidth, height: tableHeight)

        // Reposition preview section for this panel
        previewSection.frame = CGRect(x: 0, y: 280, width: panelWidth, height: 60)
        travelTimeLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
    }

    private func setupUnitSelectionSection() {
        let sectionY: CGFloat = 340

        unitSelectionView = UIView(frame: CGRect(
            x: 0,
            y: sectionY,
            width: panelWidth,
            height: view.bounds.height - sectionY - 120
        ))
        unitSelectionView.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        panelView.addSubview(unitSelectionView)

        // Header label
        let headerLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 8,
            width: PanelLayoutConstants.contentWidth,
            height: 24
        ))
        headerLabel.text = "Select Units to Send"
        headerLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        headerLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
        unitSelectionView.addSubview(headerLabel)

        // Placeholder label (shown when no building selected)
        let placeholderLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 40,
            width: PanelLayoutConstants.contentWidth,
            height: 30
        ))
        placeholderLabel.text = "Select a building first"
        placeholderLabel.font = UIFont.systemFont(ofSize: 14)
        placeholderLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        placeholderLabel.tag = 200
        unitSelectionView.addSubview(placeholderLabel)
    }

    // MARK: - Actions

    override func handleConfirm() {
        guard let building = selectedBuilding else { return }

        // Filter out zero values
        let unitsToSend = selectedUnits.filter { $0.value > 0 }

        guard !unitsToSend.isEmpty else {
            // Show alert if no units selected
            let alert = UIAlertController(
                title: "No Units Selected",
                message: "Please select at least one unit to send.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        completeAndDismiss { [weak self] in
            self?.onConfirm?(building, unitsToSend)
        }
    }

    // MARK: - Building Selection

    private func selectBuilding(_ building: BuildingNode, at indexPath: IndexPath) {
        handleSelection(at: indexPath)
        selectedBuilding = building
        selectedUnits = [:] // Reset unit selection

        // Show route preview
        showRoutePreview(from: building.coordinate, to: targetArmy.coordinate, for: player)

        // Update travel time
        updateTravelTimeForBuilding(building)

        // Show unit sliders for this building's garrison
        showUnitSliders(for: building)

        // Update confirm button (still disabled until units selected)
        updateConfirmButtonState()
    }

    private func updateTravelTimeForBuilding(_ building: BuildingNode) {
        guard let hexMap = hexMap else {
            travelTimeLabel.text = "Unable to calculate"
            return
        }

        // Find path and calculate time
        if let path = hexMap.findPath(from: building.coordinate, to: targetArmy.coordinate, for: player) {
            // Calculate approximate travel time (base 3 seconds per tile for infantry)
            updateTravelTime(pathLength: path.count, baseTimePerTile: 3.0)
        } else {
            setNoPathAvailable()
        }
    }

    private func showUnitSliders(for building: BuildingNode) {
        // Clear existing sliders
        for (_, slider) in unitSliders {
            slider.superview?.removeFromSuperview()
        }
        unitSliders.removeAll()
        unitCountLabels.removeAll()

        // Hide placeholder
        unitSelectionView.viewWithTag(200)?.isHidden = true

        // Create sliders for each unit type in garrison
        var yOffset: CGFloat = 40
        let sliderHeight: CGFloat = 50

        let garrison = building.garrison.filter { $0.value > 0 }
        let sortedGarrison = garrison.sorted { $0.key.displayName < $1.key.displayName }

        if sortedGarrison.isEmpty {
            // Show "No units in garrison" message
            let noUnitsLabel = UILabel(frame: CGRect(
                x: PanelLayoutConstants.horizontalPadding,
                y: yOffset,
                width: PanelLayoutConstants.contentWidth,
                height: 30
            ))
            noUnitsLabel.text = "No military units in garrison"
            noUnitsLabel.font = UIFont.systemFont(ofSize: 14)
            noUnitsLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            noUnitsLabel.tag = 201
            unitSelectionView.addSubview(noUnitsLabel)
            return
        }

        // Remove any "no units" label
        unitSelectionView.viewWithTag(201)?.removeFromSuperview()

        for (unitType, count) in sortedGarrison {
            let container = UIView(frame: CGRect(
                x: PanelLayoutConstants.horizontalPadding,
                y: yOffset,
                width: PanelLayoutConstants.contentWidth,
                height: sliderHeight
            ))
            container.tag = 300 // Mark as slider container

            // Unit type label
            let typeLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 150, height: 20))
            typeLabel.text = "\(unitType.icon) \(unitType.displayName)"
            typeLabel.font = UIFont.systemFont(ofSize: 14)
            typeLabel.textColor = .white
            container.addSubview(typeLabel)

            // Count label
            let countLabel = UILabel(frame: CGRect(
                x: panelWidth - 100,
                y: 0,
                width: 50,
                height: 20
            ))
            countLabel.text = "0/\(count)"
            countLabel.font = UIFont.systemFont(ofSize: 14)
            countLabel.textColor = UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)
            countLabel.textAlignment = .right
            container.addSubview(countLabel)
            unitCountLabels[unitType] = countLabel

            // Slider
            let slider = UISlider(frame: CGRect(
                x: 0,
                y: 24,
                width: PanelLayoutConstants.contentWidth - 32,
                height: 24
            ))
            slider.minimumValue = 0
            slider.maximumValue = Float(count)
            slider.value = 0
            slider.minimumTrackTintColor = theme.confirmButtonEnabledColor
            slider.maximumTrackTintColor = UIColor(white: 0.3, alpha: 1.0)
            slider.tag = unitType.hashValue
            slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
            container.addSubview(slider)
            unitSliders[unitType] = slider

            unitSelectionView.addSubview(container)
            yOffset += sliderHeight
        }
    }

    @objc private func sliderChanged(_ slider: UISlider) {
        // Find the unit type for this slider
        for (unitType, storedSlider) in unitSliders {
            if storedSlider === slider {
                let value = Int(slider.value)
                selectedUnits[unitType] = value

                // Update count label
                if let building = selectedBuilding,
                   let maxCount = building.garrison[unitType] {
                    unitCountLabels[unitType]?.text = "\(value)/\(maxCount)"
                }
                break
            }
        }

        // Update total units label
        let totalUnits = selectedUnits.values.reduce(0, +)
        unitsToSendLabel.text = "Units to send: \(totalUnits)"

        updateConfirmButtonState()
    }

    private func updateConfirmButtonState() {
        let totalUnits = selectedUnits.values.reduce(0, +)
        let hasUnits = totalUnits > 0
        let hasBuilding = selectedBuilding != nil
        let hasPath = selectedBuilding != nil && hexMap?.findPath(
            from: selectedBuilding!.coordinate,
            to: targetArmy.coordinate,
            for: player
        ) != nil

        if hasUnits && hasBuilding && hasPath {
            enableConfirmButton()
        } else {
            disableConfirmButton()
        }
    }

    // MARK: - Layout

    override func updateCustomLayouts() {
        // Update unit selection view height
        let sectionY: CGFloat = 340
        unitSelectionView.frame = CGRect(
            x: 0,
            y: sectionY,
            width: panelWidth,
            height: view.bounds.height - sectionY - 120
        )
    }
}

// MARK: - UITableViewDelegate & DataSource

extension ReinforcePanelViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableBuildings.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: EntitySelectionCell.reuseIdentifier,
            for: indexPath
        ) as! EntitySelectionCell

        let building = availableBuildings[indexPath.row]
        let config = EntityCellConfiguration.building(building, targetCoordinate: targetArmy.coordinate)
        cell.configure(with: config, theme: theme)
        cell.setSelectedState(indexPath == selectedIndexPath)

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let building = availableBuildings[indexPath.row]
        selectBuilding(building, at: indexPath)
    }
}
