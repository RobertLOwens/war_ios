// ============================================================================
// FILE: SidePanelViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/SidePanelViewController.swift
// PURPOSE: Base class for left-side slide-out panel view controllers.
//          Provides common UI structure, animations, and behavior.
// ============================================================================

import UIKit
import SpriteKit

/// Base class for side panel view controllers.
/// Subclasses must override the abstract properties and methods.
class SidePanelViewController: UIViewController {

    // MARK: - Abstract Properties (Must Override)

    /// The title displayed in the panel header
    var panelTitle: String { fatalError("Subclasses must override panelTitle") }

    /// The subtitle displayed in the panel header (e.g., coordinates)
    var panelSubtitle: String { fatalError("Subclasses must override panelSubtitle") }

    /// The title for the confirm button
    var confirmButtonTitle: String { fatalError("Subclasses must override confirmButtonTitle") }

    /// The theme for this panel
    var theme: PanelTheme { fatalError("Subclasses must override theme") }

    // MARK: - Optional Overrides

    /// Override to provide initial text for travel time label
    var initialTravelTimeText: String { "Select an item to see travel time" }

    /// Override to customize table view top offset (after header)
    var tableViewTopOffset: CGFloat { PanelLayoutConstants.headerHeight }

    /// Override to add an info section height to table offset
    var infoSectionHeight: CGFloat { 0 }

    // MARK: - Common Properties

    weak var hexMap: HexMap?
    weak var gameScene: GameScene?
    weak var player: Player?

    var onCancel: (() -> Void)?

    // MARK: - Selection State

    var selectedIndexPath: IndexPath?

    // MARK: - UI Elements

    private(set) var panelView: UIView!
    private(set) var dimmedBackgroundView: UIView!
    private(set) var headerView: UIView!
    private(set) var tableView: UITableView!
    private(set) var previewSection: UIView!
    private(set) var travelTimeLabel: UILabel!
    private(set) var warningLabel: UILabel!
    private(set) var confirmButton: UIButton!
    private(set) var cancelButton: UIButton!

    // MARK: - Constants

    let panelWidth: CGFloat = PanelLayoutConstants.panelWidth

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupPreviewSection()
        setupButtons()
        additionalSetup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .clear

        // Dimmed background
        dimmedBackgroundView = UIView(frame: view.bounds)
        dimmedBackgroundView.backgroundColor = theme.dimmedBackgroundColor
        dimmedBackgroundView.alpha = 0
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        dimmedBackgroundView.addGestureRecognizer(tapGesture)
        view.addSubview(dimmedBackgroundView)

        // Panel container
        panelView = UIView(frame: CGRect(x: -panelWidth, y: 0, width: panelWidth, height: view.bounds.height))
        panelView.backgroundColor = theme.panelBackgroundColor
        panelView.layer.cornerRadius = PanelLayoutConstants.panelCornerRadius
        panelView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        panelView.clipsToBounds = true
        view.addSubview(panelView)

        setupHeader()
    }

    private func setupHeader() {
        headerView = UIView(frame: CGRect(
            x: 0,
            y: 0,
            width: panelWidth,
            height: PanelLayoutConstants.headerHeight
        ))
        headerView.backgroundColor = theme.headerBackgroundColor
        panelView.addSubview(headerView)

        // Title
        let titleLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: PanelLayoutConstants.headerTitleTopOffset,
            width: PanelLayoutConstants.headerLabelWidth,
            height: PanelLayoutConstants.singleLineHeight
        ))
        titleLabel.text = panelTitle
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = theme.primaryTextColor
        headerView.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: PanelLayoutConstants.headerSubtitleTopOffset,
            width: PanelLayoutConstants.headerLabelWidth,
            height: PanelLayoutConstants.subtitleHeight
        ))
        subtitleLabel.text = panelSubtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = theme.secondaryTextColor
        headerView.addSubview(subtitleLabel)

        // Close button
        let closeButton = UIButton(frame: CGRect(
            x: panelWidth - PanelLayoutConstants.closeButtonTrailingMargin,
            y: PanelLayoutConstants.headerTitleTopOffset,
            width: PanelLayoutConstants.closeButtonSize,
            height: PanelLayoutConstants.closeButtonSize
        ))
        closeButton.setTitle("\u{2715}", for: .normal) // X symbol
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerView.addSubview(closeButton)
    }

    private func setupTableView() {
        let tableTop = tableViewTopOffset + infoSectionHeight
        let tableHeight = view.bounds.height - tableTop - PanelLayoutConstants.tableBottomPadding

        tableView = UITableView(frame: CGRect(
            x: 0,
            y: tableTop,
            width: panelWidth,
            height: tableHeight
        ), style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorColor = theme.separatorColor
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(EntitySelectionCell.self, forCellReuseIdentifier: EntitySelectionCell.reuseIdentifier)
        panelView.addSubview(tableView)
    }

    private func setupPreviewSection() {
        let previewY = view.bounds.height - PanelLayoutConstants.previewSectionBottomOffset

        previewSection = UIView(frame: CGRect(
            x: 0,
            y: previewY,
            width: panelWidth,
            height: PanelLayoutConstants.previewSectionHeight
        ))
        previewSection.backgroundColor = theme.previewSectionBackgroundColor
        panelView.addSubview(previewSection)

        // Travel time label
        travelTimeLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: PanelLayoutConstants.verticalSpacing,
            width: PanelLayoutConstants.contentWidth,
            height: PanelLayoutConstants.singleLineHeight
        ))
        travelTimeLabel.text = initialTravelTimeText
        travelTimeLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        travelTimeLabel.textColor = theme.secondaryTextColor
        previewSection.addSubview(travelTimeLabel)

        // Warning label
        warningLabel = UILabel(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: 40,
            width: PanelLayoutConstants.contentWidth,
            height: PanelLayoutConstants.multiLineHeight
        ))
        warningLabel.text = ""
        warningLabel.font = UIFont.systemFont(ofSize: 13)
        warningLabel.textColor = theme.warningTextColor
        warningLabel.numberOfLines = 2
        previewSection.addSubview(warningLabel)
    }

    private func setupButtons() {
        let buttonY = view.bounds.height - PanelLayoutConstants.confirmButtonBottomOffset

        // Confirm button
        confirmButton = UIButton(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: buttonY,
            width: PanelLayoutConstants.contentWidth,
            height: PanelLayoutConstants.confirmButtonHeight
        ))
        confirmButton.setTitle(confirmButtonTitle, for: .normal)
        confirmButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        confirmButton.backgroundColor = theme.confirmButtonDisabledColor
        confirmButton.layer.cornerRadius = PanelLayoutConstants.buttonCornerRadius
        confirmButton.isEnabled = false
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        panelView.addSubview(confirmButton)

        // Cancel button
        cancelButton = UIButton(frame: CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: buttonY + PanelLayoutConstants.buttonSpacing,
            width: PanelLayoutConstants.contentWidth,
            height: PanelLayoutConstants.cancelButtonHeight
        ))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.setTitleColor(theme.cancelButtonTextColor, for: .normal)
        cancelButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        panelView.addSubview(cancelButton)
    }

    /// Override in subclasses to add additional UI setup after base setup
    func additionalSetup() {
        // Subclasses can override this to add custom UI elements
    }

    // MARK: - Animation

    func animateIn() {
        UIView.animate(
            withDuration: PanelLayoutConstants.animateInDuration,
            delay: 0,
            options: .curveEaseOut
        ) {
            self.panelView.frame.origin.x = 0
            self.dimmedBackgroundView.alpha = 1
        }
    }

    func animateOut(completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: PanelLayoutConstants.animateOutDuration,
            delay: 0,
            options: .curveEaseIn
        ) {
            self.panelView.frame.origin.x = -self.panelWidth
            self.dimmedBackgroundView.alpha = 0
        } completion: { _ in
            completion()
        }
    }

    // MARK: - Actions

    @objc private func backgroundTapped() {
        dismissPanel()
    }

    @objc private func closeTapped() {
        dismissPanel()
    }

    @objc private func confirmTapped() {
        handleConfirm()
    }

    /// Override in subclasses to handle confirm button tap
    func handleConfirm() {
        fatalError("Subclasses must override handleConfirm()")
    }

    /// Dismisses the panel with animation
    func dismissPanel() {
        clearPathPreview()
        animateOut { [weak self] in
            self?.onCancel?()
            self?.dismiss(animated: false)
        }
    }

    /// Completes an action and dismisses the panel
    func completeAndDismiss(action: @escaping () -> Void) {
        clearPathPreview()
        animateOut { [weak self] in
            action()
            self?.dismiss(animated: false)
        }
    }

    // MARK: - Selection Handling

    /// Call this when an item is selected at the given index path
    func handleSelection(at indexPath: IndexPath) {
        // Deselect previous
        if let previousIndex = selectedIndexPath,
           let previousCell = tableView.cellForRow(at: previousIndex) as? EntitySelectionCell {
            previousCell.setSelectedState(false)
        }

        selectedIndexPath = indexPath

        // Highlight selected cell
        if let cell = tableView.cellForRow(at: indexPath) as? EntitySelectionCell {
            cell.setSelectedState(true)
        }
    }

    /// Enables the confirm button with the theme's enabled color
    func enableConfirmButton() {
        confirmButton.isEnabled = true
        confirmButton.backgroundColor = theme.confirmButtonEnabledColor
    }

    /// Disables the confirm button with the theme's disabled color
    func disableConfirmButton() {
        confirmButton.isEnabled = false
        confirmButton.backgroundColor = theme.confirmButtonDisabledColor
    }

    // MARK: - Path Preview

    /// Shows a route preview from the given coordinate to the destination
    func showRoutePreview(from startCoordinate: HexCoordinate, to destinationCoordinate: HexCoordinate) {
        guard let hexMap = hexMap,
              let gameScene = gameScene else { return }

        if let path = hexMap.findPath(from: startCoordinate, to: destinationCoordinate) {
            gameScene.movementPathRenderer.drawStaticMovementPath(from: startCoordinate, path: path)
        }
    }

    /// Shows a route preview using findPath with player parameter
    func showRoutePreview(from startCoordinate: HexCoordinate, to destinationCoordinate: HexCoordinate, for player: Player?) {
        guard let hexMap = hexMap,
              let gameScene = gameScene else { return }

        if let path = hexMap.findPath(from: startCoordinate, to: destinationCoordinate, for: player) {
            gameScene.movementPathRenderer.drawStaticMovementPath(from: startCoordinate, path: path)
        }
    }

    /// Clears any visible path preview
    func clearPathPreview() {
        gameScene?.movementPathRenderer.clearMovementPath()
    }

    // MARK: - Travel Time

    /// Updates the travel time label for the given entity and destination
    func updateTravelTime(for entity: EntityNode, to destination: HexCoordinate) {
        guard let hexMap = hexMap else {
            travelTimeLabel.text = "Unable to calculate"
            return
        }

        if let path = hexMap.findPath(from: entity.coordinate, to: destination) {
            let travelTime = entity.calculateTravelTime(from: entity.coordinate, path: path, hexMap: hexMap)
            travelTimeLabel.text = "Travel time: \(formatTravelTime(travelTime))"
            travelTimeLabel.textColor = theme.primaryTextColor
        } else {
            travelTimeLabel.text = "No path available"
            travelTimeLabel.textColor = theme.errorTextColor
        }
    }

    /// Updates the travel time label for a path length with a base time per tile
    func updateTravelTime(pathLength: Int, baseTimePerTile: TimeInterval) {
        let travelTime = TimeInterval(pathLength) * baseTimePerTile
        travelTimeLabel.text = "Travel time: \(formatTravelTime(travelTime))"
        travelTimeLabel.textColor = theme.primaryTextColor
    }

    /// Sets the travel time label to show no path available
    func setNoPathAvailable() {
        travelTimeLabel.text = "No path available"
        travelTimeLabel.textColor = theme.errorTextColor
    }

    /// Formats a time interval as "Xm Ys"
    func formatTravelTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return "\(minutes)m \(secs)s"
    }

    // MARK: - Warning Label

    /// Updates the warning label for a villager group's current task
    func updateWarningLabel(for villagers: VillagerGroup) {
        if villagers.currentTask == .idle {
            warningLabel.text = ""
        } else {
            warningLabel.text = VillagerTaskWarningHelper.warningMessage(for: villagers.currentTask)
        }
    }

    /// Updates the warning label with move-specific warning text
    func updateMoveWarningLabel(for villagers: VillagerGroup) {
        if villagers.currentTask == .idle {
            warningLabel.text = ""
        } else {
            warningLabel.text = VillagerTaskWarningHelper.moveWarningMessage(for: villagers.currentTask)
        }
    }

    /// Updates the warning label with custom text and optional color
    func updateWarningLabel(text: String, color: UIColor? = nil) {
        warningLabel.text = text
        if let color = color {
            warningLabel.textColor = color
        } else {
            warningLabel.textColor = UIColor.systemOrange
        }
    }

    /// Clears the warning label
    func clearWarningLabel() {
        warningLabel.text = ""
    }

    // MARK: - Layout

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Update frames for rotation
        dimmedBackgroundView.frame = view.bounds
        panelView.frame = CGRect(
            x: panelView.frame.origin.x,
            y: 0,
            width: panelWidth,
            height: view.bounds.height
        )

        // Recalculate table view height
        let tableTop = tableViewTopOffset + infoSectionHeight
        let tableHeight = view.bounds.height - tableTop - PanelLayoutConstants.tableBottomPadding
        tableView.frame = CGRect(
            x: 0,
            y: tableTop,
            width: panelWidth,
            height: tableHeight
        )

        // Update preview and button positions
        previewSection.frame = CGRect(
            x: 0,
            y: view.bounds.height - PanelLayoutConstants.previewSectionBottomOffset,
            width: panelWidth,
            height: PanelLayoutConstants.previewSectionHeight
        )

        let buttonY = view.bounds.height - PanelLayoutConstants.confirmButtonBottomOffset
        confirmButton.frame = CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: buttonY,
            width: PanelLayoutConstants.contentWidth,
            height: PanelLayoutConstants.confirmButtonHeight
        )
        cancelButton.frame = CGRect(
            x: PanelLayoutConstants.horizontalPadding,
            y: buttonY + PanelLayoutConstants.buttonSpacing,
            width: PanelLayoutConstants.contentWidth,
            height: PanelLayoutConstants.cancelButtonHeight
        )

        // Allow subclasses to update their custom layouts
        updateCustomLayouts()
    }

    /// Override in subclasses to update custom UI element layouts
    func updateCustomLayouts() {
        // Subclasses can override this to update custom layout positions
    }
}

// MARK: - UITableViewDelegate & DataSource

extension SidePanelViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fatalError("Subclasses must override tableView(_:numberOfRowsInSection:)")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fatalError("Subclasses must override tableView(_:cellForRowAt:)")
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        // Subclasses should override this to handle selection
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return PanelLayoutConstants.cellHeight
    }
}
