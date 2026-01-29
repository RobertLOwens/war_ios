// ============================================================================
// FILE: LiveCombatViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/
// PURPOSE: Real-time battle viewer showing live combat statistics
// ============================================================================

import UIKit

class LiveCombatViewController: UIViewController {

    var combat: ActiveCombat?
    var updateTimer: Timer?

    // UI Elements
    var headerLabel: UILabel!
    var timerLabel: UILabel!
    var phaseLabel: UILabel!
    var attackerView: CombatSideView!
    var defenderView: CombatSideView!
    var vsLabel: UILabel!
    var closeButton: UIButton!
    var locationLabel: UILabel!

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

            // Timer
            timerLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Phase
            phaseLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 5),
            phaseLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Location
            locationLabel.topAnchor.constraint(equalTo: phaseLabel.bottomAnchor, constant: 5),
            locationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Attacker view
            attackerView.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 20),
            attackerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            attackerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            attackerView.heightAnchor.constraint(equalToConstant: 180),

            // VS label
            vsLabel.topAnchor.constraint(equalTo: attackerView.bottomAnchor, constant: 10),
            vsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Defender view
            defenderView.topAnchor.constraint(equalTo: vsLabel.bottomAnchor, constant: 10),
            defenderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            defenderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            defenderView.heightAnchor.constraint(equalToConstant: 180),
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

        // Location
        locationLabel.text = "Location: (\(combat.location.q), \(combat.location.r))"

        // Update side views
        attackerView.configure(
            name: combat.attackerArmy?.name ?? "Attacker",
            commander: combat.attackerArmy?.commander?.name,
            state: combat.attackerState
        )

        defenderView.configure(
            name: combat.defenderArmy?.name ?? "Defender",
            commander: combat.defenderArmy?.commander?.name,
            state: combat.defenderState
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
            winnerText = "\(combat.attackerArmy?.name ?? "Attacker") Wins!"
            attackerView.showWinner()
        case .defenderVictory:
            winnerText = "\(combat.defenderArmy?.name ?? "Defender") Wins!"
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
    let totalUnitsLabel = UILabel()
    let hpBarBackground = UIView()
    let hpBarFill = UIView()
    let unitBreakdownLabel = UILabel()
    let damageLabel = UILabel()
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

        // Total units label
        totalUnitsLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .bold)
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

        // Unit breakdown
        unitBreakdownLabel.font = UIFont.systemFont(ofSize: 12)
        unitBreakdownLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        unitBreakdownLabel.numberOfLines = 3
        unitBreakdownLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(unitBreakdownLabel)

        // Damage label
        damageLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        damageLabel.textColor = .systemOrange
        damageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(damageLabel)

        setupConstraints()
    }

    func setupConstraints() {
        hpBarFillWidthConstraint = hpBarFill.widthAnchor.constraint(equalTo: hpBarBackground.widthAnchor, multiplier: 1.0)

        NSLayoutConstraint.activate([
            // Name
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),

            // Commander
            commanderLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            commanderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),

            // Total units
            totalUnitsLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            totalUnitsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),

            // HP bar background
            hpBarBackground.topAnchor.constraint(equalTo: commanderLabel.bottomAnchor, constant: 12),
            hpBarBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            hpBarBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
            hpBarBackground.heightAnchor.constraint(equalToConstant: 12),

            // HP bar fill
            hpBarFill.topAnchor.constraint(equalTo: hpBarBackground.topAnchor),
            hpBarFill.bottomAnchor.constraint(equalTo: hpBarBackground.bottomAnchor),
            hpBarFill.leadingAnchor.constraint(equalTo: hpBarBackground.leadingAnchor),
            hpBarFillWidthConstraint!,

            // Unit breakdown
            unitBreakdownLabel.topAnchor.constraint(equalTo: hpBarBackground.bottomAnchor, constant: 10),
            unitBreakdownLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            unitBreakdownLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),

            // Damage
            damageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            damageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
        ])
    }

    func configure(name: String, commander: String?, state: SideCombatState) {
        nameLabel.text = isAttacker ? "Attacker: \(name)" : "Defender: \(name)"
        commanderLabel.text = commander != nil ? "Commander: \(commander!)" : "No Commander"

        totalUnitsLabel.text = "\(state.totalUnits)"

        // Calculate HP percentage
        let percentage = state.initialUnitCount > 0 ? CGFloat(state.totalUnits) / CGFloat(state.initialUnitCount) : 0

        // Update HP bar with animation
        hpBarFillWidthConstraint?.isActive = false
        hpBarFillWidthConstraint = hpBarFill.widthAnchor.constraint(equalTo: hpBarBackground.widthAnchor, multiplier: max(0.01, percentage))
        hpBarFillWidthConstraint?.isActive = true

        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }

        // Change color based on HP percentage
        if percentage < 0.25 {
            hpBarFill.backgroundColor = .systemRed
        } else if percentage < 0.5 {
            hpBarFill.backgroundColor = .systemOrange
        } else {
            hpBarFill.backgroundColor = isAttacker ? .systemRed : .systemBlue
        }

        // Unit breakdown
        var breakdown = ""
        let sortedUnits = state.unitCounts.sorted { $0.value > $1.value }
        for (unitType, count) in sortedUnits.prefix(4) {
            if count > 0 {
                breakdown += "\(unitType.icon) \(unitType.displayName): \(count)  "
            }
        }
        unitBreakdownLabel.text = breakdown.isEmpty ? "No units remaining" : breakdown

        // Total damage dealt
        let totalDamage = state.damageDealtByType.values.reduce(0, +)
        damageLabel.text = "Damage Dealt: \(Int(totalDamage))"
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
