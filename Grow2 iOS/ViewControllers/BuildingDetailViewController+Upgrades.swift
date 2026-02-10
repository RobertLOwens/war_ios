// ============================================================================
// FILE: BuildingDetailViewController+Upgrades.swift
// PURPOSE: Upgrade and demolition section UI and actions
//          for BuildingDetailViewController
// ============================================================================

import UIKit

// MARK: - Upgrade Actions

extension BuildingDetailViewController {

    @objc func upgradeTapped() {
        debugLog("⬆️ Upgrade button tapped for \(building.buildingType.displayName)")

        let availableVillagers = player.entities.compactMap { entity -> VillagerGroup? in
            guard let villagerGroup = entity as? VillagerGroup,
                  villagerGroup.currentTask == .idle else {
                return nil
            }
            return villagerGroup
        }

        if availableVillagers.isEmpty {
            showVillagerSelectionForUpgrade(availableVillagers: [])
        } else {
            showVillagerSelectionForUpgrade(availableVillagers: availableVillagers)
        }
    }

    func showVillagerSelectionForUpgrade(availableVillagers: [VillagerGroup]) {
        if availableVillagers.isEmpty {
            let alert = UIAlertController(
                title: "No Idle Villagers",
                message: "All your villagers are busy. Start upgrade anyway?",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Start Upgrade", style: .default) { [weak self] _ in
                self?.executeUpgrade(villagerEntity: nil)
            })

            present(alert, animated: true)
            return
        }

        let alert = UIAlertController(
            title: "👷 Select Villager",
            message: "Choose a villager group to perform the upgrade:",
            preferredStyle: .actionSheet
        )

        for villagerGroup in availableVillagers {
            if let entityNode = hexMap.entities.first(where: {
                ($0.entity as? VillagerGroup)?.id == villagerGroup.id
            }) {
                let distance = villagerGroup.coordinate.distance(to: building.coordinate)
                let title = "👷 \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) - Distance: \(distance)"

                alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    self?.executeUpgrade(villagerEntity: entityNode)
                })
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    func executeUpgrade(villagerEntity: EntityNode?) {
        guard let player = player else {
            showAlert(title: "Error", message: "Player not available.")
            return
        }

        let command = UpgradeCommand(
            playerID: player.id,
            buildingID: building.data.id,
            upgraderEntityID: villagerEntity?.entity.id
        )

        let result = CommandExecutor.shared.execute(command)

        if result.succeeded {
            showAlert(title: "✅ Upgrade Started", message: "Upgrading \(building.buildingType.displayName) to Level \(building.level + 1)")
            refreshContent()
            gameViewController?.updateResourceDisplay()
        } else if let reason = result.failureReason {
            showAlert(title: "Upgrade Failed", message: reason)
        }
    }

    // MARK: - Upgrade Benefits

    func getUpgradeBenefitsText() -> [String] {
        let currentLevel = building.level
        let nextLevel = currentLevel + 1
        let type = building.buildingType
        var benefits: [String] = []

        switch type {
        case .cityCenter:
            let currentPop = type.populationCapacity(forLevel: currentLevel)
            let nextPop = type.populationCapacity(forLevel: nextLevel)
            benefits.append("Population: \(currentPop) \u{2192} \(nextPop) (+\(nextPop - currentPop))")

            let currentStorage = type.storageCapacityPerResource(forLevel: currentLevel)
            let nextStorage = type.storageCapacityPerResource(forLevel: nextLevel)
            benefits.append("Storage: \(currentStorage) \u{2192} \(nextStorage) (+\(nextStorage - currentStorage) per resource)")

            let currentVG = 2 + currentLevel
            let nextVG = 2 + nextLevel
            benefits.append("Max Villager Groups: \(currentVG) \u{2192} \(nextVG)")

            let currentArmies = 1 + (currentLevel / 2)
            let nextArmies = 1 + (nextLevel / 2)
            if nextArmies > currentArmies {
                benefits.append("Max Armies: \(currentArmies) \u{2192} \(nextArmies)")
            }

            let currentWH = BuildingType.maxWarehousesAllowed(forCityCenterLevel: currentLevel)
            let nextWH = BuildingType.maxWarehousesAllowed(forCityCenterLevel: nextLevel)
            if nextWH > currentWH {
                benefits.append("Warehouse Slots: \(currentWH) \u{2192} \(nextWH)")
            }

            // Building unlocks at next level
            let unlocked = BuildingType.allCases.filter {
                $0.requiredCityCenterLevel == nextLevel && $0 != .cityCenter
            }
            if !unlocked.isEmpty {
                let names = unlocked.map { $0.displayName }.joined(separator: ", ")
                benefits.append("Unlocks: \(names)")
            }

        case .neighborhood:
            let currentPop = type.populationCapacity(forLevel: currentLevel)
            let nextPop = type.populationCapacity(forLevel: nextLevel)
            benefits.append("Population: \(currentPop) \u{2192} \(nextPop) (+\(nextPop - currentPop))")

        case .warehouse:
            let currentStorage = type.storageCapacityPerResource(forLevel: currentLevel)
            let nextStorage = type.storageCapacityPerResource(forLevel: nextLevel)
            benefits.append("Storage: \(currentStorage) \u{2192} \(nextStorage) (+\(nextStorage - currentStorage) per resource)")

        case .barracks, .archeryRange, .stable, .siegeWorkshop:
            let currentBonus = Int(Double(currentLevel - 1) * GameConfig.Training.buildingLevelSpeedBonusPerLevel * 100)
            let nextBonus = Int(Double(nextLevel - 1) * GameConfig.Training.buildingLevelSpeedBonusPerLevel * 100)
            benefits.append("Training Speed: +\(currentBonus)% \u{2192} +\(nextBonus)%")

            // Unit upgrade tier unlocks at level 2, 3, 5
            switch nextLevel {
            case 2: benefits.append("Unlocks Unit Upgrade Tier I")
            case 3: benefits.append("Unlocks Unit Upgrade Tier II")
            case 5: benefits.append("Unlocks Unit Upgrade Tier III")
            default: break
            }

        case .tower:
            let currentBonus = Int(Double(currentLevel - 1) * GameConfig.Defense.hpBonusPerLevel * 100)
            let nextBonus = Int(Double(nextLevel - 1) * GameConfig.Defense.hpBonusPerLevel * 100)
            benefits.append("HP Bonus: +\(currentBonus)% \u{2192} +\(nextBonus)%")

        case .woodenFort:
            let currentBonus = Int(Double(currentLevel - 1) * GameConfig.Defense.hpBonusPerLevel * 100)
            let nextBonus = Int(Double(nextLevel - 1) * GameConfig.Defense.hpBonusPerLevel * 100)
            benefits.append("HP Bonus: +\(currentBonus)% \u{2192} +\(nextBonus)%")

            let currentCap = GameConfig.Defense.fortBaseArmyCapacity + (currentLevel - 1) * GameConfig.Defense.fortArmyCapacityPerLevel
            let nextCap = GameConfig.Defense.fortBaseArmyCapacity + (nextLevel - 1) * GameConfig.Defense.fortArmyCapacityPerLevel
            benefits.append("Army Home Base Capacity: \(currentCap) \u{2192} \(nextCap)")

        case .castle:
            let currentBonus = Int(Double(currentLevel - 1) * GameConfig.Defense.hpBonusPerLevel * 100)
            let nextBonus = Int(Double(nextLevel - 1) * GameConfig.Defense.hpBonusPerLevel * 100)
            benefits.append("HP Bonus: +\(currentBonus)% \u{2192} +\(nextBonus)%")

            let currentCap = GameConfig.Defense.castleBaseArmyCapacity + (currentLevel - 1) * GameConfig.Defense.castleArmyCapacityPerLevel
            let nextCap = GameConfig.Defense.castleBaseArmyCapacity + (nextLevel - 1) * GameConfig.Defense.castleArmyCapacityPerLevel
            benefits.append("Army Home Base Capacity: \(currentCap) \u{2192} \(nextCap)")

        case .library:
            let currentBonus = Int(Double(currentLevel) * GameConfig.Library.researchSpeedBonusPerLevel * 100)
            let nextBonus = Int(Double(nextLevel) * GameConfig.Library.researchSpeedBonusPerLevel * 100)
            benefits.append("Research Speed: +\(currentBonus)% \u{2192} +\(nextBonus)%")

        case .farm, .miningCamp, .lumberCamp:
            let currentBonus = Int(Double(currentLevel - 1) * GameConfig.Resources.campLevelBonusPerLevel * 100)
            let nextBonus = Int(Double(nextLevel - 1) * GameConfig.Resources.campLevelBonusPerLevel * 100)
            benefits.append("Gather Rate Bonus: +\(currentBonus)% \u{2192} +\(nextBonus)%")

        default:
            benefits.append("Increased effectiveness")
        }

        return benefits
    }

    func addBenefitsLabels(benefits: [String], at yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset
        let benefitColor = UIColor(red: 0.4, green: 0.85, blue: 0.4, alpha: 1.0)

        for benefit in benefits {
            let label = createLabel(text: "\u{2022} \(benefit)", fontSize: 13, color: benefitColor)
            label.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 18)
            contentView.addSubview(label)
            currentY += 18
        }

        return currentY
    }

    // MARK: - Upgrade Progress Section

    func setupUpgradingProgressSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset

        let upgradeHeader = createLabel(
            text: "⬆️ Upgrading to Level \(building.level + 1)",
            fontSize: 18,
            weight: .bold,
            color: .cyan
        )
        upgradeHeader.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(upgradeHeader)
        currentY += 30

        let benefits = getUpgradeBenefitsText()
        currentY = addBenefitsLabels(benefits: benefits, at: currentY, leftMargin: leftMargin, contentWidth: contentWidth)
        currentY += 5

        let currentTime = Date().timeIntervalSince1970
        let progress = building.upgradeProgress
        let progressPercent = Int(progress * 100)

        let progressBarBg = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20))
        progressBarBg.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        progressBarBg.layer.cornerRadius = 10
        contentView.addSubview(progressBarBg)

        let fillWidth = max(0, contentWidth * CGFloat(progress))
        let progressBarFill = UIView(frame: CGRect(x: leftMargin, y: currentY, width: fillWidth, height: 20))
        progressBarFill.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1.0)
        progressBarFill.layer.cornerRadius = 10
        progressBarFill.tag = 9001
        contentView.addSubview(progressBarFill)
        currentY += 30

        let progressLabel = createLabel(
            text: "Progress: \(progressPercent)%",
            fontSize: 14,
            color: UIColor(white: 0.8, alpha: 1.0)
        )
        progressLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        progressLabel.tag = 9002
        contentView.addSubview(progressLabel)
        currentY += 25

        if let remainingTime = building.data.getRemainingUpgradeTime(currentTime: currentTime) {
            let minutes = Int(remainingTime) / 60
            let seconds = Int(remainingTime) % 60

            let timeLabel = createLabel(
                text: "⏱️ Time Remaining: \(minutes)m \(seconds)s",
                fontSize: 14,
                color: UIColor(white: 0.7, alpha: 1.0)
            )
            timeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
            timeLabel.tag = 9003
            contentView.addSubview(timeLabel)
            currentY += 30
        }

        let cancelButton = UIButton(type: .system)
        cancelButton.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 50)
        cancelButton.setTitle("🚫 Cancel Upgrade", for: .normal)
        cancelButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
        cancelButton.layer.cornerRadius = 10
        cancelButton.addTarget(self, action: #selector(cancelUpgradeTapped), for: .touchUpInside)
        contentView.addSubview(cancelButton)
        currentY += 60

        return currentY
    }

    @objc func cancelUpgradeTapped() {
        let alert = UIAlertController(
            title: "Cancel Upgrade?",
            message: "Are you sure you want to cancel the upgrade? Resources will be refunded.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Keep Upgrading", style: .cancel))
        alert.addAction(UIAlertAction(title: "Cancel Upgrade", style: .destructive) { [weak self] _ in
            self?.performCancelUpgrade()
        })

        present(alert, animated: true)
    }

    func setupUpgradeSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset

        let upgradeHeader = createLabel(text: "⬆️ Upgrade to Level \(building.level + 1)",
                                       fontSize: 18,
                                       weight: .bold,
                                       color: .cyan)

        if let blockedReason = building.upgradeBlockedReason {
            let blockedLabel = createLabel(text: "🔒 \(blockedReason)",
                                           fontSize: 14,
                                           color: UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0))
            blockedLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
            contentView.addSubview(blockedLabel)
            currentY += 35

            return currentY
        }

        upgradeHeader.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(upgradeHeader)
        currentY += 30

        let benefits = getUpgradeBenefitsText()
        currentY = addBenefitsLabels(benefits: benefits, at: currentY, leftMargin: leftMargin, contentWidth: contentWidth)
        currentY += 5

        if let upgradeCost = building.getUpgradeCost() {
            // Check terrain cost multiplier for mountain tiles
            let occupiedCoords = building.data.occupiedCoordinates
            let hasMountain = occupiedCoords.contains { hexMap?.getTile(at: $0)?.terrain == .mountain }
            let terrainMultiplier = hasMountain ? GameConfig.Terrain.mountainBuildingCostMultiplier : 1.0

            var costText = "Cost: "
            var canAfford = true

            for (resourceType, baseAmount) in upgradeCost {
                let adjustedAmount = Int(ceil(Double(baseAmount) * terrainMultiplier))
                let hasEnough = player.hasResource(resourceType, amount: adjustedAmount)
                let currentAmount = player.getResource(resourceType)
                if !hasEnough { canAfford = false }
                let checkmark = hasEnough ? "✅" : "❌"
                costText += "\(checkmark) \(resourceType.icon)\(adjustedAmount) (\(currentAmount)) "
            }

            let costLabel = createLabel(text: costText,
                                       fontSize: 14,
                                       color: canAfford ? UIColor(white: 0.8, alpha: 1.0) : UIColor.systemRed)
            costLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
            contentView.addSubview(costLabel)
            currentY += 25

            if hasMountain {
                let mountainLabel = createLabel(text: "Mountain terrain: +25% cost",
                                               fontSize: 12,
                                               color: UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0))
                mountainLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 18)
                contentView.addSubview(mountainLabel)
                currentY += 22
            }

            if let upgradeTime = building.getUpgradeTime() {
                let minutes = Int(upgradeTime) / 60
                let seconds = Int(upgradeTime) % 60
                let timeLabel = createLabel(text: "⏱️ Time: \(minutes)m \(seconds)s",
                                           fontSize: 14,
                                           color: UIColor(white: 0.7, alpha: 1.0))
                timeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
                contentView.addSubview(timeLabel)
                currentY += 30
            }

            let upgradeButton = UIButton(type: .system)
            upgradeButton.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 50)
            upgradeButton.setTitle("⬆️ Start Upgrade", for: .normal)
            upgradeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            upgradeButton.setTitleColor(.white, for: .normal)
            upgradeButton.backgroundColor = canAfford ? UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0) : UIColor.gray
            upgradeButton.layer.cornerRadius = 10
            upgradeButton.isEnabled = canAfford
            upgradeButton.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)
            contentView.addSubview(upgradeButton)
            currentY += 60
        }

        return currentY
    }
}

// MARK: - Demolition Section

extension BuildingDetailViewController {

    func setupDemolishSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset

        let separator = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 1))
        separator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        contentView.addSubview(separator)
        currentY += 20

        let demolishHeader = createLabel(
            text: "🏚️ Demolish Building",
            fontSize: 18,
            weight: .bold,
            color: .orange
        )
        demolishHeader.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(demolishHeader)
        currentY += 30

        let refund = building.data.getDemolitionRefund()
        let refundText = refund.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
        let refundLabel = createLabel(
            text: "Refund: \(refundText)",
            fontSize: 14,
            color: UIColor(white: 0.7, alpha: 1.0)
        )
        refundLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        contentView.addSubview(refundLabel)
        currentY += 25

        let demolitionTime = building.data.getDemolitionTime()
        let minutes = Int(demolitionTime) / 60
        let seconds = Int(demolitionTime) % 60
        let timeLabel = createLabel(
            text: "⏱️ Time: \(minutes)m \(seconds)s",
            fontSize: 14,
            color: UIColor(white: 0.7, alpha: 1.0)
        )
        timeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        contentView.addSubview(timeLabel)
        currentY += 30

        let hasGarrison = building.getTotalGarrisonCount() > 0

        let demolishButton = createActionButton(
            title: "🏚️ Demolish",
            y: currentY,
            width: contentWidth,
            leftMargin: leftMargin,
            color: hasGarrison ? .gray : UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0),
            action: #selector(demolishTapped)
        )
        demolishButton.isEnabled = !hasGarrison
        contentView.addSubview(demolishButton)
        currentY += 60

        if hasGarrison {
            let warningLabel = createLabel(
                text: "⚠️ Remove garrisoned units before demolishing",
                fontSize: 12,
                color: .systemRed
            )
            warningLabel.frame = CGRect(x: leftMargin, y: currentY - 25, width: contentWidth, height: 20)
            contentView.addSubview(warningLabel)
        }

        return currentY
    }

    func setupDemolishingProgressSection(yOffset: CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var currentY = yOffset

        let demolishHeader = createLabel(
            text: "🏚️ Demolishing...",
            fontSize: 18,
            weight: .bold,
            color: .orange
        )
        demolishHeader.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(demolishHeader)
        currentY += 35

        let progress = building.demolitionProgress
        let progressBarBg = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20))
        progressBarBg.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        progressBarBg.layer.cornerRadius = 10
        contentView.addSubview(progressBarBg)

        let fillWidth = max(0, contentWidth * CGFloat(progress))
        let progressBarFill = UIView(frame: CGRect(x: leftMargin, y: currentY, width: fillWidth, height: 20))
        progressBarFill.backgroundColor = .orange
        progressBarFill.layer.cornerRadius = 10
        progressBarFill.tag = 9101
        contentView.addSubview(progressBarFill)
        currentY += 30

        let progressPercent = Int(progress * 100)
        let progressLabel = createLabel(
            text: "Progress: \(progressPercent)%",
            fontSize: 14,
            color: UIColor(white: 0.8, alpha: 1.0)
        )
        progressLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        progressLabel.tag = 9102
        contentView.addSubview(progressLabel)
        currentY += 25

        let currentTime = Date().timeIntervalSince1970
        if let remainingTime = building.data.getRemainingDemolitionTime(currentTime: currentTime) {
            let minutes = Int(remainingTime) / 60
            let seconds = Int(remainingTime) % 60
            let timeLabel = createLabel(
                text: "⏱️ Time Remaining: \(minutes)m \(seconds)s",
                fontSize: 14,
                color: UIColor(white: 0.7, alpha: 1.0)
            )
            timeLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
            timeLabel.tag = 9103
            contentView.addSubview(timeLabel)
            currentY += 30
        }

        let refund = building.data.getDemolitionRefund()
        let refundText = refund.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
        let refundLabel = createLabel(
            text: "Will refund: \(refundText)",
            fontSize: 14,
            color: UIColor(white: 0.6, alpha: 1.0)
        )
        refundLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        contentView.addSubview(refundLabel)
        currentY += 30

        let cancelButton = createActionButton(
            title: "🚫 Cancel Demolition",
            y: currentY,
            width: contentWidth,
            leftMargin: leftMargin,
            color: UIColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1.0),
            action: #selector(cancelDemolitionTapped)
        )
        contentView.addSubview(cancelButton)
        currentY += 60

        return currentY
    }

    @objc func demolishTapped() {
        let refund = building.data.getDemolitionRefund()
        let refundText = refund.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
        let demolitionTime = building.data.getDemolitionTime()
        let minutes = Int(demolitionTime) / 60
        let seconds = Int(demolitionTime) % 60

        let alert = UIAlertController(
            title: "🏚️ Demolish \(building.buildingType.displayName)?",
            message: "This will take \(minutes)m \(seconds)s and refund \(refundText).",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Demolish", style: .destructive) { [weak self] _ in
            self?.showVillagerSelectionForDemolition()
        })

        present(alert, animated: true)
    }

    func showVillagerSelectionForDemolition() {
        let availableVillagers = player.entities.compactMap { entity -> VillagerGroup? in
            guard let villagerGroup = entity as? VillagerGroup,
                  villagerGroup.currentTask == .idle else {
                return nil
            }
            return villagerGroup
        }

        if availableVillagers.isEmpty {
            executeDemolition(villagerEntity: nil)
        } else {
            let alert = UIAlertController(
                title: "👷 Select Villager",
                message: "Choose a villager group to perform the demolition:",
                preferredStyle: .actionSheet
            )

            for villagerGroup in availableVillagers {
                if let entityNode = hexMap.entities.first(where: {
                    ($0.entity as? VillagerGroup)?.id == villagerGroup.id
                }) {
                    let distance = villagerGroup.coordinate.distance(to: building.coordinate)
                    let title = "👷 \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) - Distance: \(distance)"

                    alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                        self?.executeDemolition(villagerEntity: entityNode)
                    })
                }
            }

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            if let popover = alert.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            }

            present(alert, animated: true)
        }
    }

    func executeDemolition(villagerEntity: EntityNode?) {
        let command = DemolishCommand(
            playerID: player.id,
            buildingID: building.data.id,
            demolisherEntityID: villagerEntity?.entity.id
        )

        let result = CommandExecutor.shared.execute(command)

        if result.succeeded {
            showAlert(title: "🏚️ Demolition Started", message: "Demolishing \(building.buildingType.displayName)")
            refreshContent()
            gameViewController?.updateResourceDisplay()
        } else if let reason = result.failureReason {
            showAlert(title: "Demolition Failed", message: reason)
        }
    }

    @objc func cancelDemolitionTapped() {
        let alert = UIAlertController(
            title: "Cancel Demolition?",
            message: "Are you sure you want to stop demolishing this building?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Keep Demolishing", style: .cancel))
        alert.addAction(UIAlertAction(title: "Cancel Demolition", style: .default) { [weak self] _ in
            self?.performCancelDemolition()
        })

        present(alert, animated: true)
    }

    func performCancelDemolition() {
        let command = CancelDemolitionCommand(
            playerID: player.id,
            buildingID: building.data.id
        )

        let result = CommandExecutor.shared.execute(command)

        if result.succeeded {
            showAlert(title: "🚫 Demolition Cancelled", message: "The building is no longer being demolished.")
            refreshContent()
        } else if let reason = result.failureReason {
            showAlert(title: "Cancel Failed", message: reason)
        }
    }
}
