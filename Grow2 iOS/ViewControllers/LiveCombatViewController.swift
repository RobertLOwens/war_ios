// ============================================================================
// FILE: LiveCombatViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/
// PURPOSE: Real-time battle viewer showing live combat statistics
// ============================================================================

import UIKit

class LiveCombatViewController: UIViewController {

    var combat: ActiveCombat?
    var stackCombat: StackCombat?  // Set when viewing a pairing within a stack combat
    var updateTimer: Timer?

    // UI Elements
    var headerLabel: UILabel!
    var stackStatusLabel: UILabel!
    var timerLabel: UILabel!
    var phaseLabel: UILabel!
    var attackerView: CombatSideView!
    var defenderView: CombatSideView!
    var vsLabel: UILabel!
    var closeButton: UIButton!
    var locationLabel: UILabel!
    var terrainLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUI()
        startUpdateTimer()
        setupNotifications()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    func setupUI() {
        view.backgroundColor = UIColor(white: 0.12, alpha: 1.0)

        // Header
        headerLabel = UILabel()
        headerLabel.text = "LIVE BATTLE"
        headerLabel.font = UIFont.boldSystemFont(ofSize: 24)
        headerLabel.textColor = .systemRed
        headerLabel.textAlignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)

        // Stack status label (shown only during stack combat)
        stackStatusLabel = UILabel()
        stackStatusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        stackStatusLabel.textColor = .systemPurple
        stackStatusLabel.textAlignment = .center
        stackStatusLabel.isHidden = true
        stackStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackStatusLabel)

        // Close button
        closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        // Timer
        timerLabel = UILabel()
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .bold)
        timerLabel.textColor = .white
        timerLabel.textAlignment = .center
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerLabel)

        // Phase
        phaseLabel = UILabel()
        phaseLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        phaseLabel.textColor = .systemOrange
        phaseLabel.textAlignment = .center
        phaseLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(phaseLabel)

        // Location
        locationLabel = UILabel()
        locationLabel.font = UIFont.systemFont(ofSize: 14)
        locationLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        locationLabel.textAlignment = .center
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(locationLabel)

        // Terrain info
        terrainLabel = UILabel()
        terrainLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        terrainLabel.textColor = .systemYellow
        terrainLabel.textAlignment = .center
        terrainLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(terrainLabel)

        // Attacker side view
        attackerView = CombatSideView(isAttacker: true)
        attackerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(attackerView)

        // VS label
        vsLabel = UILabel()
        vsLabel.text = "VS"
        vsLabel.font = UIFont.boldSystemFont(ofSize: 28)
        vsLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        vsLabel.textAlignment = .center
        vsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vsLabel)

        // Defender side view
        defenderView = CombatSideView(isAttacker: false)
        defenderView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(defenderView)

        setupConstraints()
    }

    func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Stack status
            stackStatusLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            stackStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Timer
            timerLabel.topAnchor.constraint(equalTo: stackStatusLabel.bottomAnchor, constant: 4),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Phase
            phaseLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 5),
            phaseLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Location
            locationLabel.topAnchor.constraint(equalTo: phaseLabel.bottomAnchor, constant: 5),
            locationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Terrain
            terrainLabel.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 3),
            terrainLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Attacker view
            attackerView.topAnchor.constraint(equalTo: terrainLabel.bottomAnchor, constant: 15),
            attackerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            attackerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            attackerView.heightAnchor.constraint(equalToConstant: 240),

            // VS label
            vsLabel.topAnchor.constraint(equalTo: attackerView.bottomAnchor, constant: 10),
            vsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Defender view
            defenderView.topAnchor.constraint(equalTo: vsLabel.bottomAnchor, constant: 10),
            defenderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            defenderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            defenderView.heightAnchor.constraint(equalToConstant: 240),
        ])
    }

    // MARK: - Timer

    func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateUI()
        }
    }

    // MARK: - Notifications

    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(combatUpdated),
            name: .phasedCombatUpdated,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(combatEnded),
            name: .phasedCombatEnded,
            object: nil
        )
    }

    @objc func combatUpdated(_ notification: Notification) {
        if let updatedCombat = notification.object as? ActiveCombat,
           updatedCombat.id == combat?.id {
            updateUI()
        }
    }

    @objc func combatEnded(_ notification: Notification) {
        if let endedCombat = notification.object as? ActiveCombat,
           endedCombat.id == combat?.id {
            updateTimer?.invalidate()
            updateTimer = nil
            showCombatEnded()
        }
    }

    // MARK: - UI Updates

    func updateUI() {
        guard let combat = combat else { return }

        // Timer
        let mins = Int(combat.elapsedTime) / 60
        let secs = Int(combat.elapsedTime) % 60
        timerLabel.text = String(format: "%d:%02d", mins, secs)

        // Phase
        phaseLabel.text = combat.phase.displayName

        // Stack combat status
        if let stack = stackCombat {
            stackStatusLabel.isHidden = false
            let activePairings = stack.activePairings.filter { !$0.isComplete }.count
            let totalPairings = stack.activePairings.count
            let tier = stack.currentTier.displayName
            stackStatusLabel.text = "Stack Battle - Tier: \(tier) | Pairings: \(activePairings)/\(totalPairings)"
        } else {
            stackStatusLabel.isHidden = true
        }

        // Location
        locationLabel.text = "Location: (\(combat.location.q), \(combat.location.r))"

        // Terrain info
        var terrainText = "\(combat.terrainType.displayName)"
        var modifiers: [String] = []
        if combat.terrainDefenseBonus > 0 {
            modifiers.append("Defender +\(Int(combat.terrainDefenseBonus * 100))%")
        }
        if combat.terrainAttackPenalty > 0 {
            modifiers.append("Attacker -\(Int(combat.terrainAttackPenalty * 100))%")
        }
        if combat.entrenchmentDefenseBonus > 0 {
            modifiers.append("Entrenched +\(Int(combat.entrenchmentDefenseBonus * 100))%")
        }
        if let atkCmdr = combat.attackerCommanderData, atkCmdr.specialty.isAggressive,
           let cat = atkCmdr.specialty.unitCategory {
            let bonus = Int(atkCmdr.getAttackBonus(for: cat) * 100)
            modifiers.append("Atk Cmdr +\(bonus)% \(cat.rawValue.capitalized)")
        }
        if let defCmdr = combat.defenderCommanderData, defCmdr.specialty.armorBonus > 0 {
            let bonus = Int(defCmdr.getDefenseBonus() * 100)
            modifiers.append("Def Cmdr +\(bonus)% Armor")
        }
        if !modifiers.isEmpty {
            let modifierStr = modifiers.joined(separator: ", ")
            if combat.terrainDefenseBonus > 0 && combat.entrenchmentDefenseBonus > 0 {
                let total = Int((combat.terrainDefenseBonus + combat.entrenchmentDefenseBonus) * 100)
                terrainText += " (\(modifierStr) = +\(total)% total)"
            } else {
                terrainText += " (\(modifierStr))"
            }
            terrainLabel.textColor = .systemYellow
        } else {
            terrainLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        }
        terrainLabel.text = terrainText

        // Compute shared HP scale so the weaker army's bar starts shorter
        let maxHP = max(combat.attackerState.initialTotalHP, combat.defenderState.initialTotalHP)

        // Update side views
        attackerView.configure(
            name: combat.attackerArmy?.name ?? combat.attackerArmies.first?.armyName ?? "Attacker",
            commanderData: combat.attackerCommanderData ?? combat.attackerArmy?.commander?.data,
            state: combat.attackerState,
            maxHP: maxHP
        )

        defenderView.configure(
            name: combat.defenderArmy?.name ?? combat.defenderArmies.first?.armyName ?? "Defender",
            commanderData: combat.defenderCommanderData ?? combat.defenderArmy?.commander?.data,
            state: combat.defenderState,
            maxHP: maxHP
        )

        // Check if combat ended
        if combat.phase == .ended {
            showCombatEnded()
        }
    }

    func showCombatEnded() {
        headerLabel.text = "BATTLE ENDED"
        headerLabel.textColor = .systemGreen

        guard let combat = combat else { return }

        let winnerText: String
        switch combat.winner {
        case .attackerVictory:
            winnerText = "\(combat.attackerArmy?.name ?? combat.attackerArmies.first?.armyName ?? "Attacker") Wins!"
            attackerView.showWinner()
        case .defenderVictory:
            winnerText = "\(combat.defenderArmy?.name ?? combat.defenderArmies.first?.armyName ?? "Defender") Wins!"
            defenderView.showWinner()
        case .draw:
            winnerText = "Draw!"
        }

        phaseLabel.text = winnerText
        phaseLabel.textColor = .systemGreen
    }

    @objc func closeTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Combat Side View

class CombatSideView: UIView {

    let isAttacker: Bool

    let nameLabel = UILabel()
    let commanderLabel = UILabel()
    let commanderBonusLabel = UILabel()
    let totalUnitsLabel = UILabel()
    let hpBarBackground = UIView()
    let hpBarFill = UIView()
    let unitTableStack = UIStackView()
    var hpBarFillWidthConstraint: NSLayoutConstraint?

    init(isAttacker: Bool) {
        self.isAttacker = isAttacker
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        layer.cornerRadius = 12
        layer.borderWidth = 2
        layer.borderColor = isAttacker ? UIColor.systemRed.cgColor : UIColor.systemBlue.cgColor

        // Name label
        nameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        // Commander label
        commanderLabel.font = UIFont.systemFont(ofSize: 13)
        commanderLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        commanderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(commanderLabel)

        // Commander bonus label
        commanderBonusLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        commanderBonusLabel.textColor = UIColor.systemYellow
        commanderBonusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(commanderBonusLabel)

        // Total units label (now shows HP)
        totalUnitsLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        totalUnitsLabel.textColor = .white
        totalUnitsLabel.textAlignment = .right
        totalUnitsLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(totalUnitsLabel)

        // HP bar background
        hpBarBackground.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        hpBarBackground.layer.cornerRadius = 6
        hpBarBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hpBarBackground)

        // HP bar fill
        hpBarFill.backgroundColor = isAttacker ? .systemRed : .systemBlue
        hpBarFill.layer.cornerRadius = 6
        hpBarFill.translatesAutoresizingMaskIntoConstraints = false
        hpBarBackground.addSubview(hpBarFill)

        // Unit table stack
        unitTableStack.axis = .vertical
        unitTableStack.spacing = 2
        unitTableStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(unitTableStack)

        setupConstraints()
    }

    func setupConstraints() {
        hpBarFillWidthConstraint = hpBarFill.widthAnchor.constraint(equalTo: hpBarBackground.widthAnchor, multiplier: 1.0)

        NSLayoutConstraint.activate([
            // Total HP at top right
            totalUnitsLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            totalUnitsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),

            // HP bar at top (most prominent, leaving room for HP count)
            hpBarBackground.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            hpBarBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            hpBarBackground.trailingAnchor.constraint(equalTo: totalUnitsLabel.leadingAnchor, constant: -12),
            hpBarBackground.heightAnchor.constraint(equalToConstant: 14),

            // HP bar fill
            hpBarFill.topAnchor.constraint(equalTo: hpBarBackground.topAnchor),
            hpBarFill.bottomAnchor.constraint(equalTo: hpBarBackground.bottomAnchor),
            hpBarFill.leadingAnchor.constraint(equalTo: hpBarBackground.leadingAnchor),
            hpBarFillWidthConstraint!,

            // Name below HP bar
            nameLabel.topAnchor.constraint(equalTo: hpBarBackground.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),

            // Commander below name
            commanderLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            commanderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            commanderLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),

            // Commander bonus below commander
            commanderBonusLabel.topAnchor.constraint(equalTo: commanderLabel.bottomAnchor, constant: 1),
            commanderBonusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            commanderBonusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),

            // Unit table below commander bonus
            unitTableStack.topAnchor.constraint(equalTo: commanderBonusLabel.bottomAnchor, constant: 4),
            unitTableStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            unitTableStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
        ])
    }

    func configure(name: String, commanderData: CommanderData?, state: SideCombatState, maxHP: Double) {
        nameLabel.text = isAttacker ? "Attacker: \(name)" : "Defender: \(name)"

        if let cmdr = commanderData {
            let icon = cmdr.specialty.icon
            commanderLabel.text = "\(icon) \(cmdr.name) (\(cmdr.specialty.displayName))"
            commanderLabel.textColor = UIColor(white: 0.75, alpha: 1.0)

            // Build bonus description
            var bonusParts: [String] = []
            if cmdr.specialty.isAggressive, let cat = cmdr.specialty.unitCategory {
                let atkPct = Int(cmdr.getAttackBonus(for: cat) * 100)
                bonusParts.append("+\(atkPct)% \(cat.rawValue.capitalized) ATK")
            }
            if cmdr.specialty.armorBonus > 0 {
                let defPct = Int(cmdr.getDefenseBonus() * 100)
                bonusParts.append("+\(defPct)% DEF")
            }
            let levelBonus = Int(Double(cmdr.level) * 0.01 * 100)
            if levelBonus > 0 && !cmdr.specialty.isAggressive && cmdr.specialty.armorBonus == 0 {
                bonusParts.append("+\(levelBonus)% ATK/DEF (level)")
            }
            commanderBonusLabel.text = bonusParts.isEmpty ? "" : bonusParts.joined(separator: "  ")
            commanderBonusLabel.isHidden = bonusParts.isEmpty
        } else {
            commanderLabel.text = "No Commander"
            commanderLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
            commanderBonusLabel.text = ""
            commanderBonusLabel.isHidden = true
        }

        // Show total HP remaining
        let currentHP = Int(state.currentTotalHP)
        totalUnitsLabel.text = "\(currentHP) HP"

        // Calculate HP percentage using shared maxHP scale
        let percentage: CGFloat = maxHP > 0 ? CGFloat(state.currentTotalHP / maxHP) : 0

        // Update HP bar with animation
        hpBarFillWidthConstraint?.isActive = false
        hpBarFillWidthConstraint = hpBarFill.widthAnchor.constraint(equalTo: hpBarBackground.widthAnchor, multiplier: max(0.01, percentage))
        hpBarFillWidthConstraint?.isActive = true

        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }

        // Color based on this side's own HP ratio
        let ownRatio = state.initialTotalHP > 0 ? state.currentTotalHP / state.initialTotalHP : 0
        if ownRatio < 0.25 {
            hpBarFill.backgroundColor = .systemRed
        } else if ownRatio < 0.5 {
            hpBarFill.backgroundColor = .systemOrange
        } else {
            hpBarFill.backgroundColor = isAttacker ? .systemRed : .systemBlue
        }

        // Rebuild unit table
        unitTableStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Sort by initial composition (show all unit types that participated)
        let allTypes = state.initialComposition.sorted { $0.key.displayName < $1.key.displayName }

        if allTypes.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No units remaining"
            emptyLabel.font = UIFont.systemFont(ofSize: 12)
            emptyLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            unitTableStack.addArrangedSubview(emptyLabel)
        } else {
            for (unitType, initialCount) in allTypes {
                let currentCount = state.unitCounts[unitType] ?? 0
                let damage = state.damageDealtByType[unitType] ?? 0

                let row = UILabel()
                row.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                row.textColor = currentCount > 0 ? UIColor(white: 0.8, alpha: 1.0) : UIColor(white: 0.4, alpha: 1.0)

                let nameStr = unitType.displayName.padding(toLength: 12, withPad: " ", startingAt: 0)
                row.text = "\(unitType.icon) \(nameStr) \(currentCount)/\(initialCount)  DMG: \(Int(damage))"
                unitTableStack.addArrangedSubview(row)
            }
        }
    }

    func showWinner() {
        layer.borderColor = UIColor.systemGreen.cgColor
        layer.borderWidth = 3

        let winnerBadge = UILabel()
        winnerBadge.text = "WINNER"
        winnerBadge.font = UIFont.boldSystemFont(ofSize: 12)
        winnerBadge.textColor = .black
        winnerBadge.backgroundColor = .systemGreen
        winnerBadge.textAlignment = .center
        winnerBadge.layer.cornerRadius = 4
        winnerBadge.clipsToBounds = true
        winnerBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(winnerBadge)

        NSLayoutConstraint.activate([
            winnerBadge.topAnchor.constraint(equalTo: topAnchor, constant: -8),
            winnerBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            winnerBadge.widthAnchor.constraint(equalToConstant: 60),
            winnerBadge.heightAnchor.constraint(equalToConstant: 18),
        ])
    }
}
