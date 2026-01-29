// ============================================================================
// FILE: ArmyDetailViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/ArmyDetailViewController.swift
// PURPOSE: Shows detailed army information including commander, unit composition,
//          and combat stats
// ============================================================================

import UIKit

class ArmyDetailViewController: UIViewController {

    // MARK: - Properties

    var army: Army!
    var player: Player!
    var hexMap: HexMap!
    var gameScene: GameScene!

    var scrollView: UIScrollView!
    var contentView: UIView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let topOverlay = view.subviews.first {
            topOverlay.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 60)
        }

        scrollView?.frame = CGRect(x: 0, y: 60, width: view.bounds.width, height: view.bounds.height - 60)

        if contentView.subviews.isEmpty {
            setupContent()
        }
    }

    // MARK: - UI Setup

    func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        view.isUserInteractionEnabled = true

        // Top bar
        let topOverlay = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 60))
        topOverlay.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        view.addSubview(topOverlay)

        // Title
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 15, width: view.bounds.width - 90, height: 30))
        titleLabel.text = "🛡️ \(army.name)"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .white
        topOverlay.addSubview(titleLabel)

        // Close button
        let closeButton = UIButton(frame: CGRect(x: view.bounds.width - 60, y: 10, width: 50, height: 40))
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topOverlay.addSubview(closeButton)

        // ScrollView
        scrollView = UIScrollView()
        scrollView.frame = CGRect(x: 0, y: 60, width: view.bounds.width, height: view.bounds.height - 60)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentView = UIView()
        scrollView.addSubview(contentView)
    }

    func setupContent() {
        let leftMargin: CGFloat = 20
        let contentWidth = view.bounds.width - 40
        var yOffset: CGFloat = 20

        // MARK: - Header Section

        // Army name
        let titleLabel = createLabel(
            text: "🛡️ \(army.name)",
            fontSize: 24,
            weight: .bold,
            color: .white
        )
        titleLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 30)
        contentView.addSubview(titleLabel)
        yOffset += 35

        // Location and capacity
        let totalUnits = army.getTotalMilitaryUnits()
        let maxUnits = army.getMaxArmySize()
        let locationLabel = createLabel(
            text: "📍 Location: (\(army.coordinate.q), \(army.coordinate.r)) • Units: \(totalUnits)/\(maxUnits)",
            fontSize: 14,
            color: UIColor(white: 0.7, alpha: 1.0)
        )
        locationLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 20)
        contentView.addSubview(locationLabel)
        yOffset += 30

        // MARK: - Commander Section

        yOffset = setupCommanderSection(yOffset: yOffset, contentWidth: contentWidth, leftMargin: leftMargin)

        // Separator
        let separator1 = UIView(frame: CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 1))
        separator1.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        contentView.addSubview(separator1)
        yOffset += 20

        // MARK: - Unit Composition Section

        yOffset = setupUnitCompositionSection(yOffset: yOffset, contentWidth: contentWidth, leftMargin: leftMargin)

        // Separator
        let separator2 = UIView(frame: CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 1))
        separator2.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        contentView.addSubview(separator2)
        yOffset += 20

        // MARK: - Combat Stats Section

        yOffset = setupCombatStatsSection(yOffset: yOffset, contentWidth: contentWidth, leftMargin: leftMargin)

        // Separator
        let separator3 = UIView(frame: CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 1))
        separator3.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        contentView.addSubview(separator3)
        yOffset += 20

        // MARK: - Home Base Section

        yOffset = setupHomeBaseSection(yOffset: yOffset, contentWidth: contentWidth, leftMargin: leftMargin)

        // MARK: - Close Button

        let closeButton = createActionButton(
            title: "Close",
            y: yOffset,
            width: contentWidth,
            leftMargin: leftMargin,
            color: UIColor(white: 0.3, alpha: 1.0),
            action: #selector(closeTapped)
        )
        contentView.addSubview(closeButton)
        yOffset += 80

        // Set content size
        contentView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: yOffset)
        scrollView.contentSize = CGSize(width: view.bounds.width, height: yOffset)
    }

    // MARK: - Commander Section

    func setupCommanderSection(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        var currentY = yOffset

        let sectionLabel = createLabel(
            text: "👤 Commander",
            fontSize: 18,
            weight: .semibold,
            color: .white
        )
        sectionLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(sectionLabel)
        currentY += 35

        if let commander = army.commander {
            // Commander card (expanded height for stamina)
            let commanderCard = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 175))
            commanderCard.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            commanderCard.layer.cornerRadius = 12
            contentView.addSubview(commanderCard)

            // Name and rank
            let nameLabel = UILabel(frame: CGRect(x: 15, y: 10, width: contentWidth - 30, height: 25))
            nameLabel.text = "\(commander.rank.icon) \(commander.name)"
            nameLabel.font = UIFont.boldSystemFont(ofSize: 18)
            nameLabel.textColor = .white
            commanderCard.addSubview(nameLabel)

            // Rank
            let rankLabel = UILabel(frame: CGRect(x: 15, y: 35, width: contentWidth - 30, height: 20))
            rankLabel.text = "Rank: \(commander.rank.displayName)"
            rankLabel.font = UIFont.systemFont(ofSize: 14)
            rankLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
            commanderCard.addSubview(rankLabel)

            // Specialty
            let specialtyLabel = UILabel(frame: CGRect(x: 15, y: 55, width: contentWidth - 30, height: 20))
            specialtyLabel.text = "\(commander.specialty.icon) Specialty: \(commander.specialty.displayName)"
            specialtyLabel.font = UIFont.systemFont(ofSize: 14)
            specialtyLabel.textColor = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
            commanderCard.addSubview(specialtyLabel)

            // Specialty bonus description
            let bonusLabel = UILabel(frame: CGRect(x: 15, y: 75, width: contentWidth - 30, height: 18))
            bonusLabel.text = commander.specialty.description
            bonusLabel.font = UIFont.systemFont(ofSize: 12)
            bonusLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
            commanderCard.addSubview(bonusLabel)

            // Leadership & Tactics
            let statsLabel = UILabel(frame: CGRect(x: 15, y: 95, width: contentWidth - 30, height: 20))
            statsLabel.text = "📊 Leadership: \(commander.leadership) • Tactics: \(commander.tactics)"
            statsLabel.font = UIFont.systemFont(ofSize: 14)
            statsLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
            commanderCard.addSubview(statsLabel)

            // Level and XP
            let requiredXP = commander.level * 100
            let xpProgress = Double(commander.experience) / Double(requiredXP)
            let levelLabel = UILabel(frame: CGRect(x: 15, y: 115, width: contentWidth - 30, height: 20))
            levelLabel.text = "⭐ Level \(commander.level) • XP: \(commander.experience)/\(requiredXP) (\(Int(xpProgress * 100))%)"
            levelLabel.font = UIFont.systemFont(ofSize: 14)
            levelLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
            commanderCard.addSubview(levelLabel)

            // Stamina bar background
            let staminaBarBg = UIView(frame: CGRect(x: 15, y: 140, width: contentWidth - 30, height: 8))
            staminaBarBg.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
            staminaBarBg.layer.cornerRadius = 4
            commanderCard.addSubview(staminaBarBg)

            // Stamina bar fill
            let staminaPercentage = commander.staminaPercentage
            let staminaBarFill = UIView(frame: CGRect(x: 15, y: 140, width: (contentWidth - 30) * staminaPercentage, height: 8))
            staminaBarFill.backgroundColor = staminaPercentage > 0.3 ?
                UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0) :
                UIColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0)
            staminaBarFill.layer.cornerRadius = 4
            commanderCard.addSubview(staminaBarFill)

            // Stamina label
            let staminaLabel = UILabel(frame: CGRect(x: 15, y: 150, width: contentWidth - 30, height: 18))
            staminaLabel.text = "⚡ Stamina: \(Int(commander.stamina))/\(Int(Commander.maxStamina)) (regen: 1/min)"
            staminaLabel.font = UIFont.systemFont(ofSize: 12)
            staminaLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
            commanderCard.addSubview(staminaLabel)

            currentY += 185
        } else {
            // No commander
            let noCommanderLabel = createLabel(
                text: "⚠️ No Commander Assigned",
                fontSize: 16,
                color: UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
            )
            noCommanderLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
            contentView.addSubview(noCommanderLabel)
            currentY += 35

            let warningLabel = createLabel(
                text: "Armies without commanders have reduced effectiveness",
                fontSize: 12,
                color: UIColor(white: 0.6, alpha: 1.0)
            )
            warningLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
            contentView.addSubview(warningLabel)
            currentY += 30
        }

        return currentY
    }

    // MARK: - Unit Composition Section

    func setupUnitCompositionSection(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        var currentY = yOffset

        let sectionLabel = createLabel(
            text: "⚔️ Unit Composition",
            fontSize: 18,
            weight: .semibold,
            color: .white
        )
        sectionLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(sectionLabel)
        currentY += 35

        let composition = army.militaryComposition.sorted { $0.key.displayName < $1.key.displayName }

        if composition.isEmpty {
            let emptyLabel = createLabel(
                text: "No units in this army",
                fontSize: 14,
                color: UIColor(white: 0.6, alpha: 1.0)
            )
            emptyLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
            contentView.addSubview(emptyLabel)
            currentY += 35
        } else {
            for (unitType, count) in composition {
                currentY = createUnitRow(
                    unitType: unitType,
                    count: count,
                    yOffset: currentY,
                    contentWidth: contentWidth,
                    leftMargin: leftMargin
                )
            }
        }

        return currentY
    }

    func createUnitRow(unitType: MilitaryUnitType, count: Int, yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        let rowHeight: CGFloat = 80

        let container = UIView(frame: CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: rowHeight))
        container.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        container.layer.cornerRadius = 10
        contentView.addSubview(container)

        // Unit icon and name
        let nameLabel = UILabel(frame: CGRect(x: 15, y: 8, width: contentWidth - 80, height: 22))
        nameLabel.text = "\(unitType.icon) \(unitType.displayName)"
        nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        nameLabel.textColor = .white
        container.addSubview(nameLabel)

        // Count badge
        let countLabel = UILabel(frame: CGRect(x: contentWidth - 65, y: 8, width: 50, height: 22))
        countLabel.text = "x\(count)"
        countLabel.font = UIFont.boldSystemFont(ofSize: 16)
        countLabel.textColor = UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)
        countLabel.textAlignment = .right
        container.addSubview(countLabel)

        // Stats line
        let stats = unitType.combatStats
        let statsText = "⚔️\(Int(stats.meleeDamage))/\(Int(stats.pierceDamage))/\(Int(stats.bludgeonDamage)) 🛡️\(Int(stats.meleeArmor))/\(Int(stats.pierceArmor))/\(Int(stats.bludgeonArmor)) ❤️\(Int(unitType.hp))"
        let statsLabel = UILabel(frame: CGRect(x: 15, y: 32, width: contentWidth - 30, height: 18))
        statsLabel.text = statsText
        statsLabel.font = UIFont.systemFont(ofSize: 12)
        statsLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        container.addSubview(statsLabel)

        // Category and special bonuses
        var bonusText = "Category: \(unitType.category.rawValue.capitalized)"
        if stats.bonusVsCavalry > 0 {
            bonusText += " • +\(Int(stats.bonusVsCavalry)) vs Cavalry"
        }
        if stats.bonusVsBuildings > 0 {
            bonusText += " • +\(Int(stats.bonusVsBuildings)) vs Buildings"
        }
        let bonusLabel = UILabel(frame: CGRect(x: 15, y: 52, width: contentWidth - 30, height: 18))
        bonusLabel.text = bonusText
        bonusLabel.font = UIFont.systemFont(ofSize: 11)
        bonusLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        container.addSubview(bonusLabel)

        return yOffset + rowHeight + 10
    }

    // MARK: - Combat Stats Section

    func setupCombatStatsSection(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        var currentY = yOffset

        let sectionLabel = createLabel(
            text: "📊 Army Summary",
            fontSize: 18,
            weight: .semibold,
            color: .white
        )
        sectionLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(sectionLabel)
        currentY += 35

        // Stats card
        let statsCard = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 140))
        statsCard.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        statsCard.layer.cornerRadius = 12
        contentView.addSubview(statsCard)

        // Aggregated stats
        let aggregatedStats = army.getAggregatedCombatStats()
        let modifiedStrength = army.getModifiedStrength()
        let modifiedDefense = army.getModifiedDefense()
        let baseStrength = army.getTotalStrength()
        let baseDefense = army.getTotalDefense()

        // Attack stats
        let attackLabel = UILabel(frame: CGRect(x: 15, y: 10, width: contentWidth - 30, height: 22))
        let strengthBonus = modifiedStrength - baseStrength
        let strengthBonusText = strengthBonus > 0 ? " (+\(Int(strengthBonus)) commander)" : ""
        attackLabel.text = "⚔️ Total Attack: \(Int(modifiedStrength))\(strengthBonusText)"
        attackLabel.font = UIFont.boldSystemFont(ofSize: 15)
        attackLabel.textColor = UIColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0)
        statsCard.addSubview(attackLabel)

        // Defense stats
        let defenseLabel = UILabel(frame: CGRect(x: 15, y: 35, width: contentWidth - 30, height: 22))
        let defenseBonus = modifiedDefense - baseDefense
        let defenseBonusText = defenseBonus > 0 ? " (+\(Int(defenseBonus)) commander)" : ""
        defenseLabel.text = "🛡️ Total Defense: \(Int(modifiedDefense))\(defenseBonusText)"
        defenseLabel.font = UIFont.boldSystemFont(ofSize: 15)
        defenseLabel.textColor = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        statsCard.addSubview(defenseLabel)

        // Damage breakdown
        let damageLabel = UILabel(frame: CGRect(x: 15, y: 60, width: contentWidth - 30, height: 20))
        damageLabel.text = "Damage Types: Melee \(Int(aggregatedStats.meleeDamage)) | Pierce \(Int(aggregatedStats.pierceDamage)) | Bludgeon \(Int(aggregatedStats.bludgeonDamage))"
        damageLabel.font = UIFont.systemFont(ofSize: 13)
        damageLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        statsCard.addSubview(damageLabel)

        // Armor breakdown
        let armorLabel = UILabel(frame: CGRect(x: 15, y: 82, width: contentWidth - 30, height: 20))
        armorLabel.text = "Armor Types: Melee \(Int(aggregatedStats.meleeArmor)) | Pierce \(Int(aggregatedStats.pierceArmor)) | Bludgeon \(Int(aggregatedStats.bludgeonArmor))"
        armorLabel.font = UIFont.systemFont(ofSize: 13)
        armorLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        statsCard.addSubview(armorLabel)

        // Primary category
        let primaryCategory = army.getPrimaryCategory()?.rawValue.capitalized ?? "Mixed"
        let categoryLabel = UILabel(frame: CGRect(x: 15, y: 105, width: contentWidth - 30, height: 20))
        categoryLabel.text = "🎯 Primary Type: \(primaryCategory)"
        categoryLabel.font = UIFont.systemFont(ofSize: 14)
        categoryLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        statsCard.addSubview(categoryLabel)

        currentY += 150

        // Unit category breakdown
        currentY = setupCategoryBreakdown(yOffset: currentY, contentWidth: contentWidth, leftMargin: leftMargin)

        return currentY
    }

    func setupCategoryBreakdown(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        var currentY = yOffset

        let categoryLabel = createLabel(
            text: "Unit Categories:",
            fontSize: 14,
            weight: .medium,
            color: UIColor(white: 0.8, alpha: 1.0)
        )
        categoryLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
        contentView.addSubview(categoryLabel)
        currentY += 25

        let categories: [UnitCategory] = [.infantry, .ranged, .cavalry, .siege]
        let categoryIcons: [UnitCategory: String] = [
            .infantry: "🗡️",
            .ranged: "🏹",
            .cavalry: "🐴",
            .siege: "🪨"
        ]

        let totalUnits = army.getTotalMilitaryUnits()

        for category in categories {
            let count = army.getUnitCountByCategory(category)
            if count > 0 {
                let percentage = totalUnits > 0 ? Int(Double(count) / Double(totalUnits) * 100) : 0
                let icon = categoryIcons[category] ?? "•"

                let label = createLabel(
                    text: "  \(icon) \(category.rawValue.capitalized): \(count) (\(percentage)%)",
                    fontSize: 13,
                    color: UIColor(white: 0.7, alpha: 1.0)
                )
                label.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 20)
                contentView.addSubview(label)
                currentY += 22
            }
        }

        return currentY + 10
    }

    // MARK: - Home Base Section

    func setupHomeBaseSection(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        var currentY = yOffset

        let sectionLabel = createLabel(
            text: "🏠 Home Base",
            fontSize: 18,
            weight: .semibold,
            color: .white
        )
        sectionLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(sectionLabel)
        currentY += 35

        // Check if army has a home base
        if let homeBaseID = army.homeBaseID,
           let homeBase = hexMap.buildings.first(where: { $0.data.id == homeBaseID }) {
            // Home base card
            let homeBaseCard = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 80))
            homeBaseCard.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            homeBaseCard.layer.cornerRadius = 12
            contentView.addSubview(homeBaseCard)

            // Building info
            let buildingLabel = UILabel(frame: CGRect(x: 15, y: 10, width: contentWidth - 30, height: 25))
            buildingLabel.text = "\(homeBase.buildingType.icon) \(homeBase.buildingType.displayName)"
            buildingLabel.font = UIFont.boldSystemFont(ofSize: 16)
            buildingLabel.textColor = .white
            homeBaseCard.addSubview(buildingLabel)

            // Location
            let locationLabel = UILabel(frame: CGRect(x: 15, y: 35, width: contentWidth - 30, height: 20))
            locationLabel.text = "📍 Location: (\(homeBase.coordinate.q), \(homeBase.coordinate.r))"
            locationLabel.font = UIFont.systemFont(ofSize: 14)
            locationLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
            homeBaseCard.addSubview(locationLabel)

            // Status
            let statusLabel = UILabel(frame: CGRect(x: 15, y: 55, width: contentWidth - 30, height: 20))
            statusLabel.text = homeBase.data.isOperational ? "✅ Operational" : "⚠️ Not Operational"
            statusLabel.font = UIFont.systemFont(ofSize: 14)
            statusLabel.textColor = homeBase.data.isOperational ?
                UIColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0) :
                UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
            homeBaseCard.addSubview(statusLabel)

            currentY += 90

            // Retreat button - check if in combat for different styling/text
            let isInCombat = CombatSystem.shared.isInCombat(army)
            let retreatTitle = isInCombat ?
                "⚔️🏃 Disengage & Retreat to Home Base" :
                "🏃 Retreat to Home Base (10% faster)"
            let retreatColor = isInCombat ?
                UIColor(red: 0.7, green: 0.3, blue: 0.3, alpha: 1.0) :
                UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1.0)

            let retreatButton = createActionButton(
                title: retreatTitle,
                y: currentY,
                width: contentWidth,
                leftMargin: leftMargin,
                color: retreatColor,
                action: #selector(retreatTapped)
            )
            contentView.addSubview(retreatButton)
            currentY += 65
        } else {
            // No home base
            let noHomeBaseCard = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 70))
            noHomeBaseCard.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            noHomeBaseCard.layer.cornerRadius = 12
            contentView.addSubview(noHomeBaseCard)

            let noHomeBaseLabel = createLabel(
                text: "⚠️ No Home Base Set",
                fontSize: 16,
                color: UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
            )
            noHomeBaseLabel.frame = CGRect(x: 15, y: 15, width: contentWidth - 30, height: 20)
            noHomeBaseCard.addSubview(noHomeBaseLabel)

            let hintLabel = createLabel(
                text: "Move to a City Center, Wooden Fort, or Castle to set home base",
                fontSize: 12,
                color: UIColor(white: 0.6, alpha: 1.0)
            )
            hintLabel.frame = CGRect(x: 15, y: 38, width: contentWidth - 30, height: 20)
            hintLabel.numberOfLines = 0
            noHomeBaseCard.addSubview(hintLabel)

            currentY += 80
        }

        return currentY
    }

    @objc func retreatTapped() {
        guard let player = player else { return }

        // Create and execute retreat command
        let command = RetreatCommand(playerID: player.id, armyID: army.id)
        let context = CommandContext(hexMap: hexMap, player: player, allPlayers: gameScene.allGamePlayers, gameScene: gameScene)

        let validationResult = command.validate(in: context)
        if !validationResult.succeeded {
            // Show error alert
            let alert = UIAlertController(
                title: "Cannot Retreat",
                message: validationResult.failureReason ?? "Unknown error",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let result = command.execute(in: context)
        if result.succeeded {
            dismiss(animated: true)
        } else {
            let alert = UIAlertController(
                title: "Retreat Failed",
                message: result.failureReason ?? "Unknown error",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - Helper Methods

    func createLabel(text: String, fontSize: CGFloat, weight: UIFont.Weight = .regular, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        return label
    }

    func createActionButton(title: String, y: CGFloat, width: CGFloat, leftMargin: CGFloat, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(frame: CGRect(x: leftMargin, y: y, width: width, height: 55))
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = color
        button.layer.cornerRadius = 12
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc func closeTapped() {
        dismiss(animated: true)
    }
}
