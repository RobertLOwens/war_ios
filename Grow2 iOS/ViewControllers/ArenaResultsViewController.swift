// ============================================================================
// FILE: ArenaResultsViewController.swift
// PURPOSE: Display arena combat results (single-run detail or batch aggregate)
// ============================================================================

import UIKit

class ArenaResultsViewController: UIViewController {

    // MARK: - Input Data

    /// Single-run detailed records (from visual auto-sim)
    var detailedRecords: [DetailedCombatRecord]?

    /// Batch simulation results (from headless sim)
    var batchResults: [ArenaSimulator.SimulationResult]?

    /// Scenario config used (for showing modifiers)
    var scenarioConfig: ArenaScenarioConfig?

    // MARK: - UI

    private var scrollView: UIScrollView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        setupUI()
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Setup

    private func setupUI() {
        // Title
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 50, width: view.bounds.width, height: 40))
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        // Scroll view
        scrollView = UIScrollView(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: view.bounds.height - 170))
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)

        let contentView = UIView()
        scrollView.addSubview(contentView)

        var currentY: CGFloat = 10
        let padding: CGFloat = 20
        let contentWidth = view.bounds.width - padding * 2

        if let results = batchResults, results.count > 1 {
            // Batch results view
            titleLabel.text = "SIMULATION RESULTS (\(results.count) runs)"
            currentY = buildBatchView(in: contentView, results: results, y: currentY, width: contentWidth, padding: padding)
        } else if let records = detailedRecords, let record = records.first {
            // Single detailed result
            titleLabel.text = "COMBAT RESULTS"
            currentY = buildSingleDetailView(in: contentView, record: record, y: currentY, width: contentWidth, padding: padding)
        } else if let results = batchResults, results.count == 1, let result = results.first {
            // Single batch result (fallback)
            titleLabel.text = "COMBAT RESULTS"
            currentY = buildSingleSimView(in: contentView, result: result, y: currentY, width: contentWidth, padding: padding)
        } else {
            titleLabel.text = "NO RESULTS"
        }

        contentView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: currentY + 20)
        scrollView.contentSize = CGSize(width: view.bounds.width, height: currentY + 20)

        // Back button
        let backButton = UIButton(frame: CGRect(x: (view.bounds.width - 200) / 2, y: view.bounds.height - 65, width: 200, height: 50))
        backButton.setTitle("Back to Setup", for: .normal)
        backButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        backButton.backgroundColor = UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
        backButton.layer.cornerRadius = 10
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
    }

    // MARK: - Single Detailed Record View

    private func buildSingleDetailView(in container: UIView, record: DetailedCombatRecord, y: CGFloat, width: CGFloat, padding: CGFloat) -> CGFloat {
        var currentY = y

        // Winner banner
        let winnerText: String
        let winnerColor: UIColor
        switch record.winner {
        case .attackerVictory:
            winnerText = "ATTACKER VICTORY"
            winnerColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
        case .defenderVictory:
            winnerText = "DEFENDER VICTORY"
            winnerColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        case .draw:
            winnerText = "DRAW"
            winnerColor = UIColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
        }

        currentY = addLabel(to: container, text: winnerText, y: currentY, padding: padding, width: width,
                            font: .boldSystemFont(ofSize: 24), color: winnerColor, alignment: .center)

        currentY = addLabel(to: container, text: "Duration: \(String(format: "%.1f", record.totalDuration))s",
                            y: currentY, padding: padding, width: width,
                            font: .systemFont(ofSize: 16), color: .lightGray, alignment: .center)
        currentY += 15

        // Attacker section
        currentY = addSectionHeader(to: container, text: "ATTACKER", y: currentY, padding: padding, width: width,
                                    color: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0))
        for (unitType, initial) in record.attackerInitialComposition {
            let final = record.attackerFinalComposition[unitType] ?? 0
            let killed = initial - final
            let displayName = MilitaryUnitTypeData(rawValue: unitType)?.displayName ?? unitType
            currentY = addLabel(to: container, text: "\(displayName):  \(initial) -> \(final)  (\(killed) killed)",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .monospacedDigitSystemFont(ofSize: 14, weight: .regular), color: .white, alignment: .left)
        }
        let attackerTotal = record.attackerInitialComposition.values.reduce(0, +)
        let attackerFinalTotal = record.attackerFinalComposition.values.reduce(0, +)
        currentY = addLabel(to: container, text: "Total: \(attackerTotal) -> \(attackerFinalTotal)",
                            y: currentY, padding: padding + 10, width: width - 10,
                            font: .boldSystemFont(ofSize: 14), color: .white, alignment: .left)
        currentY += 15

        // Defender section
        currentY = addSectionHeader(to: container, text: "DEFENDER", y: currentY, padding: padding, width: width,
                                    color: UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0))
        for (unitType, initial) in record.defenderInitialComposition {
            let final = record.defenderFinalComposition[unitType] ?? 0
            let killed = initial - final
            let displayName = MilitaryUnitTypeData(rawValue: unitType)?.displayName ?? unitType
            currentY = addLabel(to: container, text: "\(displayName):  \(initial) -> \(final)  (\(killed) killed)",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .monospacedDigitSystemFont(ofSize: 14, weight: .regular), color: .white, alignment: .left)
        }
        let defenderTotal = record.defenderInitialComposition.values.reduce(0, +)
        let defenderFinalTotal = record.defenderFinalComposition.values.reduce(0, +)
        currentY = addLabel(to: container, text: "Total: \(defenderTotal) -> \(defenderFinalTotal)",
                            y: currentY, padding: padding + 10, width: width - 10,
                            font: .boldSystemFont(ofSize: 14), color: .white, alignment: .left)
        currentY += 15

        // Modifiers section
        currentY = addModifiersSection(to: container, y: currentY, padding: padding, width: width)

        return currentY
    }

    // MARK: - Single Sim Result View (from batch)

    private func buildSingleSimView(in container: UIView, result: ArenaSimulator.SimulationResult, y: CGFloat, width: CGFloat, padding: CGFloat) -> CGFloat {
        var currentY = y

        let winnerText: String
        let winnerColor: UIColor
        switch result.winner {
        case .attacker:
            winnerText = "ATTACKER VICTORY"
            winnerColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
        case .defender:
            winnerText = "DEFENDER VICTORY"
            winnerColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        case .draw:
            winnerText = "DRAW"
            winnerColor = UIColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
        }

        currentY = addLabel(to: container, text: winnerText, y: currentY, padding: padding, width: width,
                            font: .boldSystemFont(ofSize: 24), color: winnerColor, alignment: .center)
        currentY = addLabel(to: container, text: "Duration: \(String(format: "%.1f", result.combatDuration))s",
                            y: currentY, padding: padding, width: width,
                            font: .systemFont(ofSize: 16), color: .lightGray, alignment: .center)
        currentY += 15

        // Attacker
        currentY = addSectionHeader(to: container, text: "ATTACKER", y: currentY, padding: padding, width: width,
                                    color: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0))
        for (key, initial) in result.attackerInitial {
            let remaining = result.attackerRemaining[key] ?? 0
            let killed = initial - remaining
            let displayName = MilitaryUnitTypeData(rawValue: key)?.displayName ?? key
            currentY = addLabel(to: container, text: "\(displayName):  \(initial) -> \(remaining)  (\(killed) killed)",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .monospacedDigitSystemFont(ofSize: 14, weight: .regular), color: .white, alignment: .left)
        }
        currentY += 15

        // Defender
        currentY = addSectionHeader(to: container, text: "DEFENDER", y: currentY, padding: padding, width: width,
                                    color: UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0))
        for (key, initial) in result.defenderInitial {
            let remaining = result.defenderRemaining[key] ?? 0
            let killed = initial - remaining
            let displayName = MilitaryUnitTypeData(rawValue: key)?.displayName ?? key
            currentY = addLabel(to: container, text: "\(displayName):  \(initial) -> \(remaining)  (\(killed) killed)",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .monospacedDigitSystemFont(ofSize: 14, weight: .regular), color: .white, alignment: .left)
        }
        currentY += 15

        currentY = addModifiersSection(to: container, y: currentY, padding: padding, width: width)

        return currentY
    }

    // MARK: - Batch Results View

    private func buildBatchView(in container: UIView, results: [ArenaSimulator.SimulationResult], y: CGFloat, width: CGFloat, padding: CGFloat) -> CGFloat {
        var currentY = y

        // Win rate stats
        let attackerWins = results.filter { $0.winner == .attacker }.count
        let defenderWins = results.filter { $0.winner == .defender }.count
        let draws = results.filter { $0.winner == .draw }.count
        let total = results.count

        currentY = addSectionHeader(to: container, text: "WIN RATE", y: currentY, padding: padding, width: width,
                                    color: .white)

        // Attacker win bar
        currentY = addWinRateBar(to: container, label: "Attacker", count: attackerWins, total: total,
                                 color: UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0),
                                 y: currentY, padding: padding, width: width)

        // Defender win bar
        currentY = addWinRateBar(to: container, label: "Defender", count: defenderWins, total: total,
                                 color: UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0),
                                 y: currentY, padding: padding, width: width)

        // Draw bar
        currentY = addWinRateBar(to: container, label: "Draw", count: draws, total: total,
                                 color: UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0),
                                 y: currentY, padding: padding, width: width)
        currentY += 15

        // Averages
        currentY = addSectionHeader(to: container, text: "AVERAGES", y: currentY, padding: padding, width: width, color: .white)

        let avgDuration = results.map { $0.combatDuration }.reduce(0, +) / Double(total)
        currentY = addLabel(to: container, text: "Avg Duration: \(String(format: "%.1f", avgDuration))s",
                            y: currentY, padding: padding + 10, width: width - 10,
                            font: .systemFont(ofSize: 15), color: .lightGray, alignment: .left)

        let avgAttackerCas = results.map { $0.attackerCasualties.values.reduce(0, +) }.reduce(0, +) / total
        let avgDefenderCas = results.map { $0.defenderCasualties.values.reduce(0, +) }.reduce(0, +) / total
        currentY = addLabel(to: container, text: "Avg Attacker Casualties: \(avgAttackerCas)",
                            y: currentY, padding: padding + 10, width: width - 10,
                            font: .systemFont(ofSize: 15), color: .lightGray, alignment: .left)
        currentY = addLabel(to: container, text: "Avg Defender Casualties: \(avgDefenderCas)",
                            y: currentY, padding: padding + 10, width: width - 10,
                            font: .systemFont(ofSize: 15), color: .lightGray, alignment: .left)
        currentY += 15

        // Modifiers
        currentY = addModifiersSection(to: container, y: currentY, padding: padding, width: width)
        currentY += 10

        // Individual runs list
        currentY = addSectionHeader(to: container, text: "INDIVIDUAL RUNS", y: currentY, padding: padding, width: width, color: .white)

        for (index, result) in results.enumerated() {
            let winnerStr: String
            let color: UIColor
            switch result.winner {
            case .attacker:
                winnerStr = "Attacker Win"
                color = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
            case .defender:
                winnerStr = "Defender Win"
                color = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
            case .draw:
                winnerStr = "Draw"
                color = UIColor(red: 0.7, green: 0.7, blue: 0.3, alpha: 1.0)
            }
            currentY = addLabel(to: container,
                                text: "Run \(index + 1): \(winnerStr) - \(String(format: "%.1f", result.combatDuration))s",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .monospacedDigitSystemFont(ofSize: 13, weight: .regular), color: color, alignment: .left)
        }

        return currentY
    }

    // MARK: - Modifiers Section

    private func addModifiersSection(to container: UIView, y: CGFloat, padding: CGFloat, width: CGFloat) -> CGFloat {
        guard let config = scenarioConfig else { return y }
        var currentY = y

        currentY = addSectionHeader(to: container, text: "MODIFIERS", y: currentY, padding: padding, width: width,
                                    color: UIColor(white: 0.7, alpha: 1.0))

        let terrainName = config.enemyTerrain.displayName
        let defBonus = config.enemyTerrain.defenderDefenseBonus
        if defBonus > 0 {
            currentY = addLabel(to: container, text: "Terrain: \(terrainName) (+\(Int(defBonus * 100))% def)",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .systemFont(ofSize: 13), color: .lightGray, alignment: .left)
        } else {
            currentY = addLabel(to: container, text: "Terrain: \(terrainName)",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .systemFont(ofSize: 13), color: .lightGray, alignment: .left)
        }

        if config.enemyEntrenched {
            currentY = addLabel(to: container, text: "Entrenchment: +10% def",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .systemFont(ofSize: 13), color: .lightGray, alignment: .left)
        }

        // Player commander with bonus details
        let playerSpec = config.playerCommanderSpecialty
        let playerLvl = config.playerCommanderLevel
        let playerRank = CommanderRankData.rank(forLevel: playerLvl)
        var playerCmdrText = "Player Cmdr: \(playerSpec.icon) \(playerSpec.rawValue) Lv\(playerLvl) \(playerRank.displayName)"
        var playerBonusParts: [String] = []
        if playerSpec.isAggressive, let cat = playerSpec.unitCategory {
            let atkPct = Int(Double(playerSpec.attackBonus(for: cat)) * 0.1 * 100 + Double(playerLvl))
            playerBonusParts.append("+\(atkPct)% \(cat.rawValue.capitalized) ATK")
        }
        if playerSpec.armorBonus > 0 {
            let defPct = Int(Double(playerSpec.armorBonus) * 0.1 * 100 + Double(playerLvl))
            playerBonusParts.append("+\(defPct)% DEF")
        }
        if !playerBonusParts.isEmpty {
            playerCmdrText += " — " + playerBonusParts.joined(separator: ", ")
        }
        currentY = addLabel(to: container, text: playerCmdrText,
                            y: currentY, padding: padding + 10, width: width - 10,
                            font: .systemFont(ofSize: 13), color: .lightGray, alignment: .left)

        // Enemy commander with bonus details
        let enemySpec = config.enemyCommanderSpecialty
        let enemyLvl = config.enemyCommanderLevel
        let enemyRank = CommanderRankData.rank(forLevel: enemyLvl)
        var enemyCmdrText = "Enemy Cmdr: \(enemySpec.icon) \(enemySpec.rawValue) Lv\(enemyLvl) \(enemyRank.displayName)"
        var enemyBonusParts: [String] = []
        if enemySpec.isAggressive, let cat = enemySpec.unitCategory {
            let atkPct = Int(Double(enemySpec.attackBonus(for: cat)) * 0.1 * 100 + Double(enemyLvl))
            enemyBonusParts.append("+\(atkPct)% \(cat.rawValue.capitalized) ATK")
        }
        if enemySpec.armorBonus > 0 {
            let defPct = Int(Double(enemySpec.armorBonus) * 0.1 * 100 + Double(enemyLvl))
            enemyBonusParts.append("+\(defPct)% DEF")
        }
        if !enemyBonusParts.isEmpty {
            enemyCmdrText += " — " + enemyBonusParts.joined(separator: ", ")
        }
        currentY = addLabel(to: container, text: enemyCmdrText,
                            y: currentY, padding: padding + 10, width: width - 10,
                            font: .systemFont(ofSize: 13), color: .lightGray, alignment: .left)

        if !config.enemyUnitTiers.isEmpty {
            let tierStr = config.enemyUnitTiers.map { "\($0.key.displayName):T\($0.value)" }.joined(separator: ", ")
            currentY = addLabel(to: container, text: "Enemy Tiers: \(tierStr)",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .systemFont(ofSize: 13), color: .lightGray, alignment: .left)
        }
        if !config.playerUnitTiers.isEmpty {
            let tierStr = config.playerUnitTiers.map { "\($0.key.displayName):T\($0.value)" }.joined(separator: ", ")
            currentY = addLabel(to: container, text: "Player Tiers: \(tierStr)",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .systemFont(ofSize: 13), color: .lightGray, alignment: .left)
        }

        if let building = config.enemyBuilding {
            currentY = addLabel(to: container, text: "Building: \(building.displayName)",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .systemFont(ofSize: 13), color: .lightGray, alignment: .left)
        }

        if config.garrisonArchers > 0 {
            currentY = addLabel(to: container, text: "Garrison: \(config.garrisonArchers) archers",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .systemFont(ofSize: 13), color: .lightGray, alignment: .left)
        }

        if abs(config.enemyArmyCount) == 2 {
            let stackType = config.enemyArmyCount == 2 ? "Same tile" : "Adjacent"
            currentY = addLabel(to: container, text: "Stacking: \(stackType)",
                                y: currentY, padding: padding + 10, width: width - 10,
                                font: .systemFont(ofSize: 13), color: .lightGray, alignment: .left)
        }

        return currentY
    }

    // MARK: - UI Helpers

    @discardableResult
    private func addLabel(to container: UIView, text: String, y: CGFloat, padding: CGFloat, width: CGFloat,
                          font: UIFont, color: UIColor, alignment: NSTextAlignment) -> CGFloat {
        let label = UILabel(frame: CGRect(x: padding, y: y, width: width, height: 22))
        label.text = text
        label.font = font
        label.textColor = color
        label.textAlignment = alignment
        container.addSubview(label)
        return y + 24
    }

    @discardableResult
    private func addSectionHeader(to container: UIView, text: String, y: CGFloat, padding: CGFloat, width: CGFloat, color: UIColor) -> CGFloat {
        let label = UILabel(frame: CGRect(x: padding, y: y, width: width, height: 25))
        label.text = text
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.textColor = color
        container.addSubview(label)

        let separator = UIView(frame: CGRect(x: padding, y: y + 25, width: width, height: 1))
        separator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        container.addSubview(separator)

        return y + 32
    }

    private func addWinRateBar(to container: UIView, label: String, count: Int, total: Int,
                                color: UIColor, y: CGFloat, padding: CGFloat, width: CGFloat) -> CGFloat {
        let pct = total > 0 ? Double(count) / Double(total) : 0
        let barMaxWidth = width - 160

        let nameLabel = UILabel(frame: CGRect(x: padding + 10, y: y, width: 80, height: 28))
        nameLabel.text = label
        nameLabel.font = UIFont.systemFont(ofSize: 14)
        nameLabel.textColor = .white
        container.addSubview(nameLabel)

        let barBg = UIView(frame: CGRect(x: padding + 90, y: y + 4, width: barMaxWidth, height: 20))
        barBg.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        barBg.layer.cornerRadius = 4
        container.addSubview(barBg)

        let barFill = UIView(frame: CGRect(x: 0, y: 0, width: max(barMaxWidth * CGFloat(pct), 2), height: 20))
        barFill.backgroundColor = color
        barFill.layer.cornerRadius = 4
        barBg.addSubview(barFill)

        let countLabel = UILabel(frame: CGRect(x: padding + 90 + barMaxWidth + 5, y: y, width: 60, height: 28))
        countLabel.text = "\(count)/\(total) (\(Int(pct * 100))%)"
        countLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        countLabel.textColor = .lightGray
        container.addSubview(countLabel)

        return y + 34
    }

    // MARK: - Actions

    @objc func backTapped() {
        // Dismiss back to GameSetupViewController
        // Walk the presenting chain to find GameSetupViewController
        if let presenting = presentingViewController {
            if presenting is GameSetupViewController {
                dismiss(animated: true)
            } else {
                // Dismiss both this VC and the GameViewController
                presenting.dismiss(animated: false) {
                    // We're back at GameSetupViewController
                }
            }
        } else {
            dismiss(animated: true)
        }
    }
}
