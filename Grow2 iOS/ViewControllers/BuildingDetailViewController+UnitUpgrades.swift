// ============================================================================
// FILE: BuildingDetailViewController+UnitUpgrades.swift
// PURPOSE: Unit upgrade section UI for military building detail views
// ============================================================================

import UIKit

extension BuildingDetailViewController {

    // MARK: - Unit Upgrade Section

    func setupUnitUpgradeSection(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        var currentY = yOffset

        let upgrades = UnitUpgradeType.upgradesForBuilding(building.buildingType)
        guard !upgrades.isEmpty else { return currentY }

        // Section separator
        let separator = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 1))
        separator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        contentView.addSubview(separator)
        currentY += 15

        // Section header
        let header = createLabel(
            text: "Unit Upgrades",
            fontSize: 18,
            weight: .bold,
            color: UIColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1.0)
        )
        header.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(header)
        currentY += 35

        // Active upgrade progress (if any)
        if let activeUpgradeRaw = player.state.activeUnitUpgrade,
           let activeUpgrade = UnitUpgradeType(rawValue: activeUpgradeRaw),
           player.state.activeUnitUpgradeBuildingID == building.data.id {
            currentY = setupActiveUnitUpgradeProgress(
                upgrade: activeUpgrade,
                yOffset: currentY,
                contentWidth: contentWidth,
                leftMargin: leftMargin
            )
            return currentY
        }

        // Group upgrades by unit type
        let unitTypes = Array(Set(upgrades.map { $0.unitType }))
        let sortedUnitTypes = unitTypes.sorted { $0.rawValue < $1.rawValue }

        for unitType in sortedUnitTypes {
            let unitUpgrades = upgrades.filter { $0.unitType == unitType }.sorted { $0.tier < $1.tier }
            currentY = setupUnitUpgradeRow(
                unitType: unitType,
                upgrades: unitUpgrades,
                yOffset: currentY,
                contentWidth: contentWidth,
                leftMargin: leftMargin
            )
        }

        return currentY
    }

    // MARK: - Per-Unit Upgrade Row

    private func setupUnitUpgradeRow(
        unitType: MilitaryUnitTypeData,
        upgrades: [UnitUpgradeType],
        yOffset: CGFloat,
        contentWidth: CGFloat,
        leftMargin: CGFloat
    ) -> CGFloat {
        var currentY = yOffset

        // Unit type header
        let currentTier = player.state.getUnitUpgradeTier(for: unitType)
        let tierText = currentTier > 0 ? " (Tier \(currentTier))" : ""
        let unitHeader = createLabel(
            text: "\(unitType.icon) \(unitType.displayName)\(tierText)",
            fontSize: 15,
            weight: .semibold,
            color: .white
        )
        unitHeader.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 22)
        contentView.addSubview(unitHeader)
        currentY += 26

        for upgrade in upgrades {
            let isCompleted = player.state.hasCompletedUnitUpgrade(upgrade.rawValue)
            let isActive = player.state.activeUnitUpgrade == upgrade.rawValue

            if isCompleted {
                // Completed badge
                let completedLabel = createLabel(
                    text: "  Tier \(upgrade.tier): \(upgrade.upgradeDescription) - Completed",
                    fontSize: 13,
                    color: UIColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
                )
                completedLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
                contentView.addSubview(completedLabel)
                currentY += 22
            } else if isActive {
                // Active progress
                let activeLabel = createLabel(
                    text: "  Tier \(upgrade.tier): In progress...",
                    fontSize: 13,
                    color: .cyan
                )
                activeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
                contentView.addSubview(activeLabel)
                currentY += 22
            } else {
                // Available or locked
                let hasPrereq = upgrade.prerequisite == nil ||
                    player.state.hasCompletedUnitUpgrade(upgrade.prerequisite!.rawValue)
                let hasLevel = building.level >= upgrade.requiredBuildingLevel
                let canAfford = player.state.canAfford(upgrade.cost)
                let isUpgradeActive = player.state.isUnitUpgradeActive()
                let canStart = hasPrereq && hasLevel && canAfford && !isUpgradeActive

                if !hasLevel {
                    // Level locked
                    let lockedLabel = createLabel(
                        text: "  Tier \(upgrade.tier): Requires building level \(upgrade.requiredBuildingLevel)",
                        fontSize: 13,
                        color: UIColor(white: 0.5, alpha: 1.0)
                    )
                    lockedLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
                    contentView.addSubview(lockedLabel)
                    currentY += 22
                } else if !hasPrereq {
                    // Prerequisite locked
                    let lockedLabel = createLabel(
                        text: "  Tier \(upgrade.tier): Complete Tier \(upgrade.tier - 1) first",
                        fontSize: 13,
                        color: UIColor(white: 0.5, alpha: 1.0)
                    )
                    lockedLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
                    contentView.addSubview(lockedLabel)
                    currentY += 22
                } else {
                    // Show cost and upgrade button
                    let bonusLabel = createLabel(
                        text: "  Tier \(upgrade.tier): \(upgrade.upgradeDescription)",
                        fontSize: 13,
                        color: UIColor(white: 0.8, alpha: 1.0)
                    )
                    bonusLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
                    contentView.addSubview(bonusLabel)
                    currentY += 22

                    let costText = "  Cost: \(formatCost(upgrade.cost))  Time: \(Int(upgrade.upgradeTime))s"
                    let costLabel = createLabel(
                        text: costText,
                        fontSize: 12,
                        color: canAfford ? UIColor(white: 0.7, alpha: 1.0) : .systemRed
                    )
                    costLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth - 90, height: 18)
                    contentView.addSubview(costLabel)

                    // Upgrade button
                    let button = UIButton(type: .system)
                    button.frame = CGRect(x: leftMargin + contentWidth - 85, y: currentY - 2, width: 80, height: 28)
                    button.setTitle("Upgrade", for: .normal)
                    button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 13)
                    button.setTitleColor(.white, for: .normal)
                    button.backgroundColor = canStart ?
                        UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0) :
                        UIColor(white: 0.4, alpha: 1.0)
                    button.layer.cornerRadius = 6
                    button.isEnabled = canStart
                    button.tag = unitUpgradeButtonTag(for: upgrade)
                    button.addTarget(self, action: #selector(unitUpgradeTapped(_:)), for: .touchUpInside)
                    contentView.addSubview(button)
                    currentY += 24
                }
            }
        }

        currentY += 8
        return currentY
    }

    // MARK: - Active Upgrade Progress

    private func setupActiveUnitUpgradeProgress(
        upgrade: UnitUpgradeType,
        yOffset: CGFloat,
        contentWidth: CGFloat,
        leftMargin: CGFloat
    ) -> CGFloat {
        var currentY = yOffset

        let progressLabel = createLabel(
            text: "\(upgrade.icon) Upgrading \(upgrade.displayName)...",
            fontSize: 15,
            weight: .semibold,
            color: .cyan
        )
        progressLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 22)
        contentView.addSubview(progressLabel)
        currentY += 28

        // Progress bar
        let currentTime = GameEngine.shared.gameState?.currentTime ?? Date().timeIntervalSince1970
        let startTime = player.state.activeUnitUpgradeStartTime ?? currentTime
        let elapsed = currentTime - startTime
        let progress = min(1.0, elapsed / upgrade.upgradeTime)

        let progressBarBg = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 16))
        progressBarBg.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        progressBarBg.layer.cornerRadius = 8
        contentView.addSubview(progressBarBg)

        let fillWidth = max(0, contentWidth * CGFloat(progress))
        let progressBarFill = UIView(frame: CGRect(x: leftMargin, y: currentY, width: fillWidth, height: 16))
        progressBarFill.backgroundColor = UIColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1.0)
        progressBarFill.layer.cornerRadius = 8
        progressBarFill.tag = 9101
        contentView.addSubview(progressBarFill)
        currentY += 22

        let remaining = max(0, upgrade.upgradeTime - elapsed)
        let seconds = Int(remaining)
        let statusLabel = createLabel(
            text: "\(Int(progress * 100))% - \(seconds)s remaining",
            fontSize: 13,
            color: UIColor(white: 0.7, alpha: 1.0)
        )
        statusLabel.tag = 9102
        statusLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 18)
        contentView.addSubview(statusLabel)
        currentY += 28

        return currentY
    }

    // MARK: - Progress Update (called by timer)

    func updateUnitUpgradeProgressDisplay() {
        guard let activeUpgradeRaw = player.state.activeUnitUpgrade,
              let activeUpgrade = UnitUpgradeType(rawValue: activeUpgradeRaw),
              player.state.activeUnitUpgradeBuildingID == building.data.id else { return }

        let currentTime = GameEngine.shared.gameState?.currentTime ?? Date().timeIntervalSince1970
        let startTime = player.state.activeUnitUpgradeStartTime ?? currentTime
        let elapsed = currentTime - startTime
        let progress = min(1.0, elapsed / activeUpgrade.upgradeTime)

        // Update progress bar fill (tag 9101)
        if let progressBarFill = contentView.viewWithTag(9101) {
            let contentWidth = view.bounds.width - 40
            let fillWidth = max(0, contentWidth * CGFloat(progress))
            progressBarFill.frame.size.width = fillWidth
        }

        // Update status label (tag 9102)
        if let statusLabel = contentView.viewWithTag(9102) as? UILabel {
            let remaining = max(0, activeUpgrade.upgradeTime - elapsed)
            let seconds = Int(remaining)
            statusLabel.text = "\(Int(progress * 100))% - \(seconds)s remaining"
        }

        // Refresh when complete
        if progress >= 1.0 {
            refreshContent()
        }
    }

    // MARK: - Button Tag System

    /// Encodes upgrade index into button tag (offset by 10000 to avoid conflicts)
    private func unitUpgradeButtonTag(for upgrade: UnitUpgradeType) -> Int {
        guard let index = UnitUpgradeType.allCases.firstIndex(of: upgrade) else { return 0 }
        return 10000 + index
    }

    private func unitUpgradeFromTag(_ tag: Int) -> UnitUpgradeType? {
        let index = tag - 10000
        let allCases = UnitUpgradeType.allCases
        guard index >= 0 && index < allCases.count else { return nil }
        return allCases[allCases.index(allCases.startIndex, offsetBy: index)]
    }

    // MARK: - Actions

    @objc func unitUpgradeTapped(_ sender: UIButton) {
        guard let upgrade = unitUpgradeFromTag(sender.tag) else { return }

        let costText = formatCost(upgrade.cost)
        let alert = UIAlertController(
            title: "Start \(upgrade.displayName)?",
            message: "\(upgrade.upgradeDescription)\nCost: \(costText)\nTime: \(Int(upgrade.upgradeTime))s",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Start Upgrade", style: .default) { [weak self] _ in
            self?.executeUnitUpgrade(upgrade)
        })

        present(alert, animated: true)
    }

    private func executeUnitUpgrade(_ upgrade: UnitUpgradeType) {
        let command = UpgradeUnitCommand(
            playerID: player.id,
            upgradeTypeRawValue: upgrade.rawValue,
            buildingID: building.data.id
        )

        let result = CommandExecutor.shared.execute(command)

        if result.succeeded {
            refreshContent()
            gameViewController?.updateResourceDisplay()
        } else if let reason = result.failureReason {
            showAlert(title: "Upgrade Failed", message: reason)
        }
    }
}
