// ============================================================================
// FILE: CombatDetailViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/CombatDetailViewController.swift
// PURPOSE: Shows detailed battle report with phase-by-phase breakdown and
//          unit-by-unit statistics
// ============================================================================

import UIKit

class CombatDetailViewController: UIViewController {

    // MARK: - Properties

    var detailedRecord: DetailedCombatRecord!

    var scrollView: UIScrollView!
    var contentView: UIView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let topOverlay = view.subviews.first(where: { $0 is UIView && $0.frame.height == 60 }) {
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
        titleLabel.text = "Battle Report"
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

        // MARK: - Battle Summary Header

        let winnerIcon = detailedRecord.winner == .attackerVictory ? "🏆" : (detailedRecord.winner == .defenderVictory ? "🛡️" : "🤝")
        let titleLabel = createLabel(
            text: "\(winnerIcon) \(detailedRecord.winner.displayName)",
            fontSize: 24,
            weight: .bold,
            color: getResultColor()
        )
        titleLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 30)
        contentView.addSubview(titleLabel)
        yOffset += 35

        // Location and date
        let infoLabel = createLabel(
            text: "📍 (\(detailedRecord.location.q), \(detailedRecord.location.r)) • \(detailedRecord.getFormattedDate()) • Duration: \(detailedRecord.getFormattedDuration())",
            fontSize: 14,
            color: UIColor(white: 0.7, alpha: 1.0)
        )
        infoLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 20)
        contentView.addSubview(infoLabel)
        yOffset += 25

        // Terrain info
        let terrainIcon = getTerrainIcon(detailedRecord.terrainType)
        let terrainLabel = createLabel(
            text: "\(terrainIcon) Terrain: \(detailedRecord.getTerrainDisplayName())",
            fontSize: 14,
            color: UIColor(white: 0.7, alpha: 1.0)
        )
        terrainLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 20)
        contentView.addSubview(terrainLabel)
        yOffset += 22

        // Terrain modifiers (if any)
        if detailedRecord.hasTerrainModifiers {
            let modifierLabel = createLabel(
                text: "⚡ \(detailedRecord.getTerrainModifierDescription())",
                fontSize: 13,
                color: UIColor.systemYellow
            )
            modifierLabel.frame = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 20)
            contentView.addSubview(modifierLabel)
            yOffset += 25
        }

        yOffset += 10

        // MARK: - Participant Cards

        yOffset = setupParticipantCard(
            yOffset: yOffset,
            contentWidth: contentWidth,
            leftMargin: leftMargin,
            isAttacker: true
        )

        yOffset += 10

        yOffset = setupParticipantCard(
            yOffset: yOffset,
            contentWidth: contentWidth,
            leftMargin: leftMargin,
            isAttacker: false
        )

        // Separator
        yOffset += 10
        let separator1 = createSeparator(y: yOffset, width: contentWidth, leftMargin: leftMargin)
        contentView.addSubview(separator1)
        yOffset += 20

        // MARK: - Phase Timeline

        yOffset = setupPhaseTimeline(yOffset: yOffset, contentWidth: contentWidth, leftMargin: leftMargin)

        // Separator
        let separator2 = createSeparator(y: yOffset, width: contentWidth, leftMargin: leftMargin)
        contentView.addSubview(separator2)
        yOffset += 20

        // MARK: - Unit Breakdown Tables

        yOffset = setupUnitBreakdown(
            yOffset: yOffset,
            contentWidth: contentWidth,
            leftMargin: leftMargin,
            isAttacker: true
        )

        yOffset += 10

        yOffset = setupUnitBreakdown(
            yOffset: yOffset,
            contentWidth: contentWidth,
            leftMargin: leftMargin,
            isAttacker: false
        )

        // MARK: - Close Button

        yOffset += 20
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

    // MARK: - Participant Card

    func setupParticipantCard(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat, isAttacker: Bool) -> CGFloat {
        var currentY = yOffset

        let name = isAttacker ? detailedRecord.attackerName : detailedRecord.defenderName
        let owner = isAttacker ? detailedRecord.attackerOwner : detailedRecord.defenderOwner
        let commander = isAttacker ? detailedRecord.attackerCommander : detailedRecord.defenderCommander
        let initialComp = isAttacker ? detailedRecord.getAttackerInitialComposition() : detailedRecord.getDefenderInitialComposition()
        let finalComp = isAttacker ? detailedRecord.getAttackerFinalComposition() : detailedRecord.getDefenderFinalComposition()
        let casualties = isAttacker ? detailedRecord.attackerTotalCasualties : detailedRecord.defenderTotalCasualties
        let initialStrength = isAttacker ? detailedRecord.attackerInitialStrength : detailedRecord.defenderInitialStrength
        let finalStrength = isAttacker ? detailedRecord.attackerFinalStrength : detailedRecord.defenderFinalStrength

        let isWinner = (isAttacker && detailedRecord.winner == .attackerVictory) ||
                       (!isAttacker && detailedRecord.winner == .defenderVictory)

        // Card container
        let card = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 120))
        card.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        card.layer.cornerRadius = 12
        if isWinner {
            card.layer.borderColor = UIColor.systemGreen.cgColor
            card.layer.borderWidth = 2
        }
        contentView.addSubview(card)

        // Role label
        let roleIcon = isAttacker ? "⚔️" : "🛡️"
        let roleLabel = UILabel(frame: CGRect(x: 15, y: 10, width: contentWidth - 30, height: 20))
        roleLabel.text = "\(roleIcon) \(isAttacker ? "Attacker" : "Defender")"
        roleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        roleLabel.textColor = isAttacker ? UIColor.systemOrange : UIColor.systemBlue
        card.addSubview(roleLabel)

        // Name
        let nameLabel = UILabel(frame: CGRect(x: 15, y: 30, width: contentWidth - 30, height: 25))
        nameLabel.text = "\(name) (\(owner))"
        nameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        nameLabel.textColor = .white
        card.addSubview(nameLabel)

        // Commander
        if let cmd = commander {
            let cmdLabel = UILabel(frame: CGRect(x: 15, y: 55, width: contentWidth - 30, height: 18))
            cmdLabel.text = "👤 Commander: \(cmd)"
            cmdLabel.font = UIFont.systemFont(ofSize: 13)
            cmdLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
            card.addSubview(cmdLabel)
        }

        // Units
        let unitsLabel = UILabel(frame: CGRect(x: 15, y: 75, width: contentWidth - 30, height: 18))
        unitsLabel.text = "Units: \(initialStrength) → \(finalStrength) (💀 \(casualties) casualties)"
        unitsLabel.font = UIFont.systemFont(ofSize: 13)
        unitsLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        card.addSubview(unitsLabel)

        // Winner badge
        if isWinner {
            let winnerBadge = UILabel(frame: CGRect(x: contentWidth - 85, y: 10, width: 70, height: 20))
            winnerBadge.text = "🏆 Winner"
            winnerBadge.font = UIFont.boldSystemFont(ofSize: 12)
            winnerBadge.textColor = UIColor.systemGreen
            winnerBadge.textAlignment = .right
            card.addSubview(winnerBadge)
        }

        return currentY + 130
    }

    // MARK: - Phase Timeline

    func setupPhaseTimeline(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        var currentY = yOffset

        let sectionLabel = createLabel(
            text: "⏱️ Phase Timeline",
            fontSize: 18,
            weight: .semibold,
            color: .white
        )
        sectionLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(sectionLabel)
        currentY += 35

        if detailedRecord.phaseRecords.isEmpty {
            let emptyLabel = createLabel(
                text: "No phase data available",
                fontSize: 14,
                color: UIColor(white: 0.6, alpha: 1.0)
            )
            emptyLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
            contentView.addSubview(emptyLabel)
            currentY += 35
        } else {
            for (index, phaseRecord) in detailedRecord.phaseRecords.enumerated() {
                currentY = createPhaseRow(
                    phaseRecord: phaseRecord,
                    index: index,
                    yOffset: currentY,
                    contentWidth: contentWidth,
                    leftMargin: leftMargin
                )
            }
        }

        return currentY
    }

    func createPhaseRow(phaseRecord: CombatPhaseRecord, index: Int, yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        let rowHeight: CGFloat = 70

        let container = UIView(frame: CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: rowHeight))
        container.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        container.layer.cornerRadius = 10
        contentView.addSubview(container)

        // Phase number and name
        let phaseLabel = UILabel(frame: CGRect(x: 15, y: 10, width: contentWidth - 30, height: 20))
        phaseLabel.text = "Phase \(index + 1): \(phaseRecord.phase.displayName)"
        phaseLabel.font = UIFont.boldSystemFont(ofSize: 15)
        phaseLabel.textColor = .white
        container.addSubview(phaseLabel)

        // Duration
        let durationLabel = UILabel(frame: CGRect(x: contentWidth - 85, y: 10, width: 70, height: 20))
        durationLabel.text = formatDuration(phaseRecord.duration)
        durationLabel.font = UIFont.systemFont(ofSize: 12)
        durationLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        durationLabel.textAlignment = .right
        container.addSubview(durationLabel)

        // Damage dealt
        let damageLabel = UILabel(frame: CGRect(x: 15, y: 32, width: contentWidth - 30, height: 16))
        damageLabel.text = "Damage: ⚔️ \(Int(phaseRecord.attackerDamageDealt)) | 🛡️ \(Int(phaseRecord.defenderDamageDealt))"
        damageLabel.font = UIFont.systemFont(ofSize: 12)
        damageLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        container.addSubview(damageLabel)

        // Casualties
        let attackerCasualties = phaseRecord.getAttackerCasualties().values.reduce(0, +)
        let defenderCasualties = phaseRecord.getDefenderCasualties().values.reduce(0, +)
        let casualtiesLabel = UILabel(frame: CGRect(x: 15, y: 50, width: contentWidth - 30, height: 16))
        casualtiesLabel.text = "Casualties: ⚔️ \(attackerCasualties) | 🛡️ \(defenderCasualties)"
        casualtiesLabel.font = UIFont.systemFont(ofSize: 12)
        casualtiesLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        container.addSubview(casualtiesLabel)

        return yOffset + rowHeight + 10
    }

    // MARK: - Unit Breakdown

    func setupUnitBreakdown(yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat, isAttacker: Bool) -> CGFloat {
        var currentY = yOffset

        let roleIcon = isAttacker ? "⚔️" : "🛡️"
        let name = isAttacker ? detailedRecord.attackerName : detailedRecord.defenderName

        let sectionLabel = createLabel(
            text: "\(roleIcon) \(name) Unit Breakdown",
            fontSize: 16,
            weight: .semibold,
            color: .white
        )
        sectionLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
        contentView.addSubview(sectionLabel)
        currentY += 30

        let breakdowns = isAttacker ? detailedRecord.attackerUnitBreakdowns : detailedRecord.defenderUnitBreakdowns

        if breakdowns.isEmpty {
            let emptyLabel = createLabel(
                text: "No unit data available",
                fontSize: 14,
                color: UIColor(white: 0.6, alpha: 1.0)
            )
            emptyLabel.frame = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25)
            contentView.addSubview(emptyLabel)
            currentY += 30
        } else {
            // Header row
            let headerContainer = UIView(frame: CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 25))
            headerContainer.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
            headerContainer.layer.cornerRadius = 5
            contentView.addSubview(headerContainer)

            let headers = ["Unit", "Start", "End", "Lost", "Dmg"]
            let widths: [CGFloat] = [0.35, 0.15, 0.15, 0.15, 0.20]
            var xOffset: CGFloat = 10
            for (i, header) in headers.enumerated() {
                let w = contentWidth * widths[i]
                let label = UILabel(frame: CGRect(x: xOffset, y: 3, width: w - 10, height: 20))
                label.text = header
                label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
                label.textColor = UIColor(white: 0.7, alpha: 1.0)
                headerContainer.addSubview(label)
                xOffset += w
            }
            currentY += 30

            // Data rows
            for breakdown in breakdowns {
                currentY = createUnitBreakdownRow(
                    breakdown: breakdown,
                    yOffset: currentY,
                    contentWidth: contentWidth,
                    leftMargin: leftMargin
                )
            }
        }

        return currentY
    }

    func createUnitBreakdownRow(breakdown: UnitCombatBreakdown, yOffset: CGFloat, contentWidth: CGFloat, leftMargin: CGFloat) -> CGFloat {
        let rowHeight: CGFloat = 30

        let container = UIView(frame: CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: rowHeight))
        container.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        container.layer.cornerRadius = 5
        contentView.addSubview(container)

        let unitType = breakdown.unitType
        let widths: [CGFloat] = [0.35, 0.15, 0.15, 0.15, 0.20]
        var xOffset: CGFloat = 10

        // Unit name
        let nameLabel = UILabel(frame: CGRect(x: xOffset, y: 5, width: contentWidth * widths[0] - 10, height: 20))
        nameLabel.text = "\(unitType?.icon ?? "?") \(unitType?.displayName ?? "Unknown")"
        nameLabel.font = UIFont.systemFont(ofSize: 12)
        nameLabel.textColor = .white
        container.addSubview(nameLabel)
        xOffset += contentWidth * widths[0]

        // Start count
        let startLabel = UILabel(frame: CGRect(x: xOffset, y: 5, width: contentWidth * widths[1] - 10, height: 20))
        startLabel.text = "\(breakdown.initialCount)"
        startLabel.font = UIFont.systemFont(ofSize: 12)
        startLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        container.addSubview(startLabel)
        xOffset += contentWidth * widths[1]

        // End count
        let endLabel = UILabel(frame: CGRect(x: xOffset, y: 5, width: contentWidth * widths[2] - 10, height: 20))
        endLabel.text = "\(breakdown.finalCount)"
        endLabel.font = UIFont.systemFont(ofSize: 12)
        endLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        container.addSubview(endLabel)
        xOffset += contentWidth * widths[2]

        // Lost
        let lostLabel = UILabel(frame: CGRect(x: xOffset, y: 5, width: contentWidth * widths[3] - 10, height: 20))
        lostLabel.text = "\(breakdown.casualties)"
        lostLabel.font = UIFont.systemFont(ofSize: 12)
        lostLabel.textColor = breakdown.casualties > 0 ? UIColor.systemRed : UIColor(white: 0.8, alpha: 1.0)
        container.addSubview(lostLabel)
        xOffset += contentWidth * widths[3]

        // Damage dealt
        let dmgLabel = UILabel(frame: CGRect(x: xOffset, y: 5, width: contentWidth * widths[4] - 10, height: 20))
        dmgLabel.text = "\(Int(breakdown.damageDealt))"
        dmgLabel.font = UIFont.systemFont(ofSize: 12)
        dmgLabel.textColor = UIColor.systemOrange
        container.addSubview(dmgLabel)

        return yOffset + rowHeight + 5
    }

    // MARK: - Helper Methods

    func createLabel(text: String, fontSize: CGFloat, weight: UIFont.Weight = .regular, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        return label
    }

    func createSeparator(y: CGFloat, width: CGFloat, leftMargin: CGFloat) -> UIView {
        let separator = UIView(frame: CGRect(x: leftMargin, y: y, width: width, height: 1))
        separator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        return separator
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

    func getResultColor() -> UIColor {
        switch detailedRecord.winner {
        case .attackerVictory:
            return UIColor.systemOrange
        case .defenderVictory:
            return UIColor.systemBlue
        case .draw:
            return UIColor(white: 0.7, alpha: 1.0)
        }
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }

    func getTerrainIcon(_ terrainType: String) -> String {
        switch terrainType.lowercased() {
        case "plains": return "🌾"
        case "hill": return "⛰️"
        case "mountain": return "🏔️"
        case "desert": return "🏜️"
        case "water": return "🌊"
        default: return "🗺️"
        }
    }

    @objc func closeTapped() {
        dismiss(animated: true)
    }
}
