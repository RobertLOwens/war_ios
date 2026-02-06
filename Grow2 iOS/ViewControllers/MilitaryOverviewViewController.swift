// ============================================================================
// FILE: MilitaryOverviewViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/
// PURPOSE: Shows overview of all military unit types, their stats, and player's current unit counts
// ============================================================================

import UIKit

class MilitaryOverviewViewController: UIViewController {

    var player: Player!
    var hexMap: HexMap!
    var gameScene: GameScene!
    var gameViewController: GameViewController?

    var scrollView: UIScrollView!
    var contentView: UIView!
    var closeButton: UIButton!
    var updateTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateContent()

        // Update every second for live counts
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateContent()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)

        // Title
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 50, width: view.bounds.width - 40, height: 40))
        titleLabel.text = "Military Overview"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)

        // Close button
        closeButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 50, width: 50, height: 40))
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        closeButton.addTarget(self, action: #selector(closeScreen), for: .touchUpInside)
        view.addSubview(closeButton)

        // Scroll view
        scrollView = UIScrollView(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: view.bounds.height - 100))
        scrollView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        view.addSubview(scrollView)

        // Content view
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    func updateContent() {
        // Clear existing content
        contentView.subviews.forEach { $0.removeFromSuperview() }

        var yOffset: CGFloat = 16

        // Get unit counts
        let unitCounts = getUnitCounts()

        // Create summary card
        let summaryHeight = createSummaryCard(at: yOffset, unitCounts: unitCounts)
        yOffset += summaryHeight + 16

        // Group units by category
        let categorizedUnits: [(category: UnitCategoryData, units: [MilitaryUnitTypeData])] = [
            (.infantry, MilitaryUnitTypeData.allCases.filter { $0.category == .infantry }),
            (.ranged, MilitaryUnitTypeData.allCases.filter { $0.category == .ranged }),
            (.cavalry, MilitaryUnitTypeData.allCases.filter { $0.category == .cavalry }),
            (.siege, MilitaryUnitTypeData.allCases.filter { $0.category == .siege })
        ]

        for (category, units) in categorizedUnits {
            // Section header
            let headerHeight = createSectionHeader(category: category, at: yOffset)
            yOffset += headerHeight + 8

            // Create card for each unit type in this category
            for unitType in units {
                let count = unitCounts[unitType] ?? 0
                let cardHeight = createUnitCard(for: unitType, count: count, at: yOffset)
                yOffset += cardHeight + 12
            }

            yOffset += 8 // Extra spacing between categories
        }

        // Update content size
        let contentHeight = yOffset + 20
        contentView.heightAnchor.constraint(equalToConstant: contentHeight).isActive = true
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: contentHeight)
    }

    // MARK: - Summary Card

    func createSummaryCard(at yOffset: CGFloat, unitCounts: [MilitaryUnitTypeData: Int]) -> CGFloat {
        let cardWidth = view.bounds.width - 32
        let cardX: CGFloat = 16

        // Card background
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        var cardHeight: CGFloat = 16

        // Calculate totals
        let totalUnits = unitCounts.values.reduce(0, +)
        let infantryCount = MilitaryUnitTypeData.allCases
            .filter { $0.category == .infantry }
            .reduce(0) { $0 + (unitCounts[$1] ?? 0) }
        let rangedCount = MilitaryUnitTypeData.allCases
            .filter { $0.category == .ranged }
            .reduce(0) { $0 + (unitCounts[$1] ?? 0) }
        let cavalryCount = MilitaryUnitTypeData.allCases
            .filter { $0.category == .cavalry }
            .reduce(0) { $0 + (unitCounts[$1] ?? 0) }
        let siegeCount = MilitaryUnitTypeData.allCases
            .filter { $0.category == .siege }
            .reduce(0) { $0 + (unitCounts[$1] ?? 0) }

        // Header
        let headerLabel = UILabel()
        headerLabel.text = "⚔️ ARMY SUMMARY"
        headerLabel.font = UIFont.boldSystemFont(ofSize: 18)
        headerLabel.textColor = .white
        headerLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 24)
        card.addSubview(headerLabel)
        cardHeight += 28

        // Total units (large display)
        let totalLabel = UILabel()
        totalLabel.text = "Total Units: \(totalUnits)"
        totalLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        totalLabel.textColor = totalUnits > 0 ? .systemGreen : UIColor(white: 0.5, alpha: 1.0)
        totalLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 26)
        card.addSubview(totalLabel)
        cardHeight += 30

        // Separator
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.35, alpha: 1.0)
        separator.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 1)
        card.addSubview(separator)
        cardHeight += 12

        // Category breakdown (2 columns)
        let halfWidth = (cardWidth - 48) / 2

        // Row 1: Infantry and Ranged
        let infantryLabel = UILabel()
        infantryLabel.text = "🗡️ Infantry: \(infantryCount)"
        infantryLabel.font = UIFont.systemFont(ofSize: 16)
        infantryLabel.textColor = .white
        infantryLabel.frame = CGRect(x: 16, y: cardHeight, width: halfWidth, height: 22)
        card.addSubview(infantryLabel)

        let rangedLabel = UILabel()
        rangedLabel.text = "🏹 Ranged: \(rangedCount)"
        rangedLabel.font = UIFont.systemFont(ofSize: 16)
        rangedLabel.textColor = .white
        rangedLabel.frame = CGRect(x: 16 + halfWidth + 16, y: cardHeight, width: halfWidth, height: 22)
        card.addSubview(rangedLabel)
        cardHeight += 26

        // Row 2: Cavalry and Siege
        let cavalryLabel = UILabel()
        cavalryLabel.text = "🐴 Cavalry: \(cavalryCount)"
        cavalryLabel.font = UIFont.systemFont(ofSize: 16)
        cavalryLabel.textColor = .white
        cavalryLabel.frame = CGRect(x: 16, y: cardHeight, width: halfWidth, height: 22)
        card.addSubview(cavalryLabel)

        let siegeLabel = UILabel()
        siegeLabel.text = "⚙️ Siege: \(siegeCount)"
        siegeLabel.font = UIFont.systemFont(ofSize: 16)
        siegeLabel.textColor = .white
        siegeLabel.frame = CGRect(x: 16 + halfWidth + 16, y: cardHeight, width: halfWidth, height: 22)
        card.addSubview(siegeLabel)
        cardHeight += 26

        cardHeight += 16

        // Set card constraints
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: cardX),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -cardX),
            card.heightAnchor.constraint(equalToConstant: cardHeight)
        ])

        return cardHeight
    }

    // MARK: - Section Header

    func createSectionHeader(category: UnitCategoryData, at yOffset: CGFloat) -> CGFloat {
        let headerLabel = UILabel()

        let categoryIcon: String
        let categoryName: String
        switch category {
        case .infantry:
            categoryIcon = "🗡️"
            categoryName = "INFANTRY"
        case .ranged:
            categoryIcon = "🏹"
            categoryName = "RANGED"
        case .cavalry:
            categoryIcon = "🐴"
            categoryName = "CAVALRY"
        case .siege:
            categoryIcon = "⚙️"
            categoryName = "SIEGE"
        }

        headerLabel.text = "\(categoryIcon) \(categoryName)"
        headerLabel.font = UIFont.boldSystemFont(ofSize: 18)
        headerLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerLabel)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerLabel.heightAnchor.constraint(equalToConstant: 24)
        ])

        return 24
    }

    // MARK: - Unit Card

    func createUnitCard(for unitType: MilitaryUnitTypeData, count: Int, at yOffset: CGFloat) -> CGFloat {
        let cardWidth = view.bounds.width - 32
        let cardX: CGFloat = 16

        // Card background
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        let stats = unitType.combatStats
        let playerState = player.state
        var cardHeight: CGFloat = 12

        // Header row: Unit name and count
        let headerLabel = UILabel()
        headerLabel.text = "\(unitType.icon) \(unitType.displayName)"
        headerLabel.font = UIFont.boldSystemFont(ofSize: 18)
        headerLabel.textColor = .white
        headerLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 120, height: 24)
        card.addSubview(headerLabel)

        let countLabel = UILabel()
        countLabel.text = "Count: \(count)"
        countLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        countLabel.textColor = count > 0 ? .systemGreen : UIColor(white: 0.5, alpha: 1.0)
        countLabel.textAlignment = .right
        countLabel.frame = CGRect(x: cardWidth - 120, y: cardHeight, width: 104, height: 24)
        card.addSubview(countLabel)
        cardHeight += 28

        // HP and Category row
        let hpLabel = UILabel()
        hpLabel.text = "HP: \(Int(unitType.hp))  |  \(unitType.category.rawValue.capitalized)"
        hpLabel.font = UIFont.systemFont(ofSize: 14)
        hpLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        hpLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
        card.addSubview(hpLabel)
        cardHeight += 22

        // Damage row with research bonuses
        let damageBonus = DamageCalculator.getResearchDamageBonus(for: unitType, playerState: playerState)
        let damageLabel = UILabel()
        let damageFont = UIFont.systemFont(ofSize: 14)
        let damageAttr = NSMutableAttributedString()
        damageAttr.append(NSAttributedString(string: "Damage: ", attributes: [.foregroundColor: UIColor.systemOrange, .font: damageFont]))

        var damageComponents: [NSAttributedString] = []
        if stats.meleeDamage > 0 {
            let comp = NSMutableAttributedString(string: "Melee \(Int(stats.meleeDamage))", attributes: [.foregroundColor: UIColor.systemOrange, .font: damageFont])
            if damageBonus > 0 {
                comp.append(NSAttributedString(string: " (+\(Int(damageBonus)))", attributes: [.foregroundColor: UIColor.systemGreen, .font: damageFont]))
            }
            damageComponents.append(comp)
        }
        if stats.pierceDamage > 0 {
            let comp = NSMutableAttributedString(string: "Pierce \(Int(stats.pierceDamage))", attributes: [.foregroundColor: UIColor.systemOrange, .font: damageFont])
            if damageBonus > 0 {
                comp.append(NSAttributedString(string: " (+\(Int(damageBonus)))", attributes: [.foregroundColor: UIColor.systemGreen, .font: damageFont]))
            }
            damageComponents.append(comp)
        }
        if stats.bludgeonDamage > 0 {
            let comp = NSMutableAttributedString(string: "Bludgeon \(Int(stats.bludgeonDamage))", attributes: [.foregroundColor: UIColor.systemOrange, .font: damageFont])
            if damageBonus > 0 {
                comp.append(NSAttributedString(string: " (+\(Int(damageBonus)))", attributes: [.foregroundColor: UIColor.systemGreen, .font: damageFont]))
            }
            damageComponents.append(comp)
        }

        if damageComponents.isEmpty {
            damageAttr.append(NSAttributedString(string: "None", attributes: [.foregroundColor: UIColor.systemOrange, .font: damageFont]))
        } else {
            for (i, comp) in damageComponents.enumerated() {
                if i > 0 {
                    damageAttr.append(NSAttributedString(string: ", ", attributes: [.foregroundColor: UIColor.systemOrange, .font: damageFont]))
                }
                damageAttr.append(comp)
            }
        }

        damageLabel.attributedText = damageAttr
        damageLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
        card.addSubview(damageLabel)
        cardHeight += 20

        // Armor row with research bonuses
        let meleeArmorBonus = DamageCalculator.getResearchMeleeArmorBonus(for: unitType.category, playerState: playerState)
        let pierceArmorBonus = DamageCalculator.getResearchPierceArmorBonus(for: unitType.category, playerState: playerState)
        let armorLabel = UILabel()
        let armorFont = UIFont.systemFont(ofSize: 14)
        let armorAttr = NSMutableAttributedString()
        armorAttr.append(NSAttributedString(string: "Armor: Melee \(Int(stats.meleeArmor))", attributes: [.foregroundColor: UIColor.systemBlue, .font: armorFont]))
        if meleeArmorBonus > 0 {
            armorAttr.append(NSAttributedString(string: " (+\(Int(meleeArmorBonus)))", attributes: [.foregroundColor: UIColor.systemGreen, .font: armorFont]))
        }
        armorAttr.append(NSAttributedString(string: " / Pierce \(Int(stats.pierceArmor))", attributes: [.foregroundColor: UIColor.systemBlue, .font: armorFont]))
        if pierceArmorBonus > 0 {
            armorAttr.append(NSAttributedString(string: " (+\(Int(pierceArmorBonus)))", attributes: [.foregroundColor: UIColor.systemGreen, .font: armorFont]))
        }
        armorAttr.append(NSAttributedString(string: " / Bludgeon \(Int(stats.bludgeonArmor))", attributes: [.foregroundColor: UIColor.systemBlue, .font: armorFont]))

        armorLabel.attributedText = armorAttr
        armorLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
        card.addSubview(armorLabel)
        cardHeight += 20

        // Speed row with march speed research bonus
        let marchSpeedBonus = playerState.getResearchBonus(ResearchBonusType.militaryMarchSpeed.rawValue)
        let speedLabel = UILabel()
        let speedFont = UIFont.systemFont(ofSize: 14)
        let speedAttr = NSMutableAttributedString()
        speedAttr.append(NSAttributedString(string: "Speed: Move \(String(format: "%.2f", unitType.moveSpeed))s", attributes: [.foregroundColor: UIColor.systemCyan, .font: speedFont]))
        if marchSpeedBonus > 0 {
            let pct = Int(marchSpeedBonus * 100)
            speedAttr.append(NSAttributedString(string: " (-\(pct)%)", attributes: [.foregroundColor: UIColor.systemGreen, .font: speedFont]))
        }
        speedAttr.append(NSAttributedString(string: "  |  Attack \(String(format: "%.1f", unitType.attackSpeed))s", attributes: [.foregroundColor: UIColor.systemCyan, .font: speedFont]))

        speedLabel.attributedText = speedAttr
        speedLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
        card.addSubview(speedLabel)
        cardHeight += 20

        // Bonuses row (if any)
        var bonusComponents: [String] = []
        if stats.bonusVsInfantry > 0 { bonusComponents.append("+\(Int(stats.bonusVsInfantry)) vs Infantry") }
        if stats.bonusVsCavalry > 0 { bonusComponents.append("+\(Int(stats.bonusVsCavalry)) vs Cavalry") }
        if stats.bonusVsRanged > 0 { bonusComponents.append("+\(Int(stats.bonusVsRanged)) vs Ranged") }
        if stats.bonusVsSiege > 0 { bonusComponents.append("+\(Int(stats.bonusVsSiege)) vs Siege") }
        if stats.bonusVsBuildings > 0 { bonusComponents.append("+\(Int(stats.bonusVsBuildings)) vs Buildings") }

        if !bonusComponents.isEmpty {
            let bonusLabel = UILabel()
            bonusLabel.text = "Bonus: " + bonusComponents.joined(separator: ", ")
            bonusLabel.font = UIFont.systemFont(ofSize: 14)
            bonusLabel.textColor = .systemYellow
            bonusLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
            card.addSubview(bonusLabel)
            cardHeight += 20
        }

        // Separator
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.35, alpha: 1.0)
        separator.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 1)
        card.addSubview(separator)
        cardHeight += 8

        // Training row with training speed research bonus
        let trainingSpeedBonus = playerState.getResearchBonus(ResearchBonusType.militaryTrainingSpeed.rawValue)
        let trainingLabel = UILabel()
        let trainingFont = UIFont.systemFont(ofSize: 14)
        let trainingAttr = NSMutableAttributedString()
        trainingAttr.append(NSAttributedString(string: "Training: \(Int(unitType.trainingTime))s", attributes: [.foregroundColor: UIColor(white: 0.6, alpha: 1.0), .font: trainingFont]))
        if trainingSpeedBonus > 0 {
            let pct = Int(trainingSpeedBonus * 100)
            trainingAttr.append(NSAttributedString(string: " (-\(pct)%)", attributes: [.foregroundColor: UIColor.systemGreen, .font: trainingFont]))
        }
        trainingAttr.append(NSAttributedString(string: "  |  \(formatCost(unitType.trainingCost))", attributes: [.foregroundColor: UIColor(white: 0.6, alpha: 1.0), .font: trainingFont]))

        trainingLabel.attributedText = trainingAttr
        trainingLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
        card.addSubview(trainingLabel)
        cardHeight += 20

        // Training building row
        let buildingLabel = UILabel()
        buildingLabel.text = "Trained at: \(unitType.trainingBuilding.icon) \(unitType.trainingBuilding.displayName)"
        buildingLabel.font = UIFont.systemFont(ofSize: 13)
        buildingLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        buildingLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 16)
        card.addSubview(buildingLabel)
        cardHeight += 18

        cardHeight += 12

        // Set card constraints
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: cardX),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -cardX),
            card.heightAnchor.constraint(equalToConstant: cardHeight)
        ])

        return cardHeight
    }

    // MARK: - Data Collection

    func getUnitCounts() -> [MilitaryUnitTypeData: Int] {
        var counts: [MilitaryUnitTypeData: Int] = [:]

        // Initialize all unit types to 0
        for unitType in MilitaryUnitTypeData.allCases {
            counts[unitType] = 0
        }

        // Count units in field armies
        for army in player.getArmies() {
            for (unitType, count) in army.data.militaryComposition {
                counts[unitType, default: 0] += count
            }

            // Count pending reinforcements
            for reinforcement in army.data.pendingReinforcements {
                for (unitType, count) in reinforcement.unitComposition {
                    counts[unitType, default: 0] += count
                }
            }
        }

        // Count garrisoned units in buildings
        for building in player.buildings {
            for (unitType, count) in building.garrison {
                // Convert from MilitaryUnitType to MilitaryUnitTypeData
                if let dataType = MilitaryUnitTypeData(rawValue: unitType.rawValue) {
                    counts[dataType, default: 0] += count
                }
            }
        }

        return counts
    }

    // MARK: - Helpers

    func formatCost(_ cost: [ResourceTypeData: Int]) -> String {
        var components: [String] = []
        for (resource, amount) in cost.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let icon: String
            switch resource {
            case .food: icon = "🌾"
            case .wood: icon = "🪵"
            case .stone: icon = "🪨"
            case .ore: icon = "⛏️"
            }
            components.append("\(icon) \(amount)")
        }
        return components.joined(separator: "  ")
    }

    @objc func closeScreen() {
        dismiss(animated: true)
    }
}
