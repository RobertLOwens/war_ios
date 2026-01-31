// ============================================================================
// FILE: CombatHistoryViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/
// PURPOSE: Shows battle history and active combats with real-time updates
// ============================================================================

import UIKit

class CombatHistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var tableView: UITableView!
    var closeButton: UIButton!
    var updateTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNotifications()
        startUpdateTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)

        // Title
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 50, width: view.bounds.width - 40, height: 40))
        titleLabel.text = "⚔️ Battle History"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)

        // Close button
        closeButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 50, width: 50, height: 40))
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        closeButton.addTarget(self, action: #selector(closeScreen), for: .touchUpInside)
        view.addSubview(closeButton)

        // Table view
        tableView = UITableView(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: view.bounds.height - 100), style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        tableView.separatorColor = UIColor(white: 0.3, alpha: 1.0)
        tableView.register(CombatHistoryCell.self, forCellReuseIdentifier: "CombatHistoryCell")
        tableView.register(ActiveCombatCell.self, forCellReuseIdentifier: "ActiveCombatCell")
        view.addSubview(tableView)
    }

    // MARK: - Timer for Live Updates

    func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    // MARK: - Combat Notifications

    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(combatChanged),
            name: .phasedCombatStarted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(combatChanged),
            name: .phasedCombatEnded,
            object: nil
        )
    }

    @objc func combatChanged() {
        tableView.reloadData()
    }

    // MARK: - TableView DataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            let count = GameEngine.shared.combatEngine.activeCombats.count
            return count > 0 ? "ACTIVE BATTLES (\(count))" : nil
        }
        return "BATTLE HISTORY"
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = section == 0 ? .systemRed : .systemGray
            header.textLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return GameEngine.shared.combatEngine.activeCombats.count
        }
        return GameEngine.shared.combatEngine.getCombatHistory().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            // Active combat cell
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActiveCombatCell", for: indexPath) as! ActiveCombatCell
            let combats = Array(GameEngine.shared.combatEngine.activeCombats.values)
            if indexPath.row < combats.count {
                cell.configure(with: combats[indexPath.row])
            }
            return cell
        } else {
            // History cell
            let cell = tableView.dequeueReusableCell(withIdentifier: "CombatHistoryCell", for: indexPath) as! CombatHistoryCell
            let history = GameEngine.shared.combatEngine.getCombatHistory()
            if indexPath.row < history.count {
                cell.configure(with: history[indexPath.row])
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            // Tapped on active combat - show basic info (no live viewer with new engine)
            let combats = Array(GameEngine.shared.combatEngine.activeCombats.values)
            if indexPath.row < combats.count {
                showActiveCombatInfo(combats[indexPath.row])
            }
        } else {
            // Tapped on history - show basic record
            let history = GameEngine.shared.combatEngine.getCombatHistory()
            if indexPath.row < history.count {
                showBasicRecord(history[indexPath.row])
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 110 : 100
    }

    // MARK: - Combat Detail Views

    func showActiveCombatInfo(_ combat: ActiveCombatData) {
        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - combat.startTime

        var message = "📍 Location: (\(combat.coordinate.q), \(combat.coordinate.r))\n\n"
        message += "⏱️ Duration: \(formatTime(elapsed))\n"
        message += "📊 Phase: \(combat.currentPhase)\n"

        let alert = UIAlertController(
            title: "⚔️ Active Combat",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Close", style: .default))
        present(alert, animated: true)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func showBasicRecord(_ record: CombatRecord) {
        var message = "\(record.getFormattedDate()) at \(record.getFormattedTime())\n\n"
        message += "📍 Location: (\(record.location.q), \(record.location.r))\n\n"
        message += "⚔️ \(record.attacker.name) (\(record.attacker.ownerName))\n"
        if let commander = record.attacker.commanderName {
            message += "   Commander: \(commander)\n"
        }
        message += "   Initial: \(record.attackerInitialStrength) → Final: \(record.attackerFinalStrength)\n"
        message += "   Casualties: \(record.attackerCasualties)\n\n"
        message += "🛡️ \(record.defender.name) (\(record.defender.ownerName))\n"
        if let commander = record.defender.commanderName {
            message += "   Commander: \(commander)\n"
        }
        message += "   Initial: \(record.defenderInitialStrength) → Final: \(record.defenderFinalStrength)\n"
        message += "   Casualties: \(record.defenderCasualties)\n\n"
        message += "🏆 Result: \(record.winner.displayName)"

        let alert = UIAlertController(
            title: "Battle Details",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Close", style: .default))
        present(alert, animated: true)
    }

    @objc func closeScreen() {
        dismiss(animated: true)
    }
}

// MARK: - Active Combat Cell

class ActiveCombatCell: UITableViewCell {

    let statusLabel = UILabel()
    let participantsLabel = UILabel()
    let phaseLabel = UILabel()
    let timerLabel = UILabel()
    let unitsLabel = UILabel()
    let pulseView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        backgroundColor = UIColor(red: 0.2, green: 0.1, blue: 0.1, alpha: 1.0)
        selectionStyle = .default

        // Pulsing indicator
        pulseView.frame = CGRect(x: 15, y: 12, width: 10, height: 10)
        pulseView.backgroundColor = .systemRed
        pulseView.layer.cornerRadius = 5
        contentView.addSubview(pulseView)

        // LIVE status
        statusLabel.frame = CGRect(x: 32, y: 10, width: 50, height: 16)
        statusLabel.font = UIFont.boldSystemFont(ofSize: 11)
        statusLabel.textColor = .systemRed
        statusLabel.text = "LIVE"
        contentView.addSubview(statusLabel)

        // Timer (position will be adjusted in layoutSubviews)
        timerLabel.frame = CGRect(x: 250, y: 10, width: 80, height: 20)
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        timerLabel.textColor = .systemRed
        timerLabel.textAlignment = .right
        contentView.addSubview(timerLabel)

        // Participants
        participantsLabel.frame = CGRect(x: 15, y: 30, width: 350, height: 22)
        participantsLabel.font = UIFont.boldSystemFont(ofSize: 16)
        participantsLabel.textColor = .white
        contentView.addSubview(participantsLabel)

        // Units
        unitsLabel.frame = CGRect(x: 15, y: 54, width: 350, height: 18)
        unitsLabel.font = UIFont.systemFont(ofSize: 14)
        unitsLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        contentView.addSubview(unitsLabel)

        // Phase
        phaseLabel.frame = CGRect(x: 15, y: 76, width: 350, height: 18)
        phaseLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        phaseLabel.textColor = .systemOrange
        contentView.addSubview(phaseLabel)

        // Start pulse animation
        startPulseAnimation()
    }

    func startPulseAnimation() {
        UIView.animate(withDuration: 0.8, delay: 0, options: [.repeat, .autoreverse], animations: {
            self.pulseView.alpha = 0.3
        })
    }

    func configure(with combat: ActiveCombatData) {
        participantsLabel.text = "Combat in progress"

        let currentTime = Date().timeIntervalSince1970
        let elapsed = currentTime - combat.startTime
        let mins = Int(elapsed) / 60
        let secs = Int(elapsed) % 60
        timerLabel.text = String(format: "%d:%02d", mins, secs)

        unitsLabel.text = "📍 Location: (\(combat.coordinate.q), \(combat.coordinate.r))"

        phaseLabel.text = "Phase: \(combat.currentPhase)"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Adjust timer label position based on cell width
        timerLabel.frame = CGRect(x: contentView.bounds.width - 95, y: 10, width: 80, height: 20)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        pulseView.layer.removeAllAnimations()
        pulseView.alpha = 1.0
        startPulseAnimation()
    }
}

// MARK: - Combat History Cell

class CombatHistoryCell: UITableViewCell {

    let resultLabel = UILabel()
    let participantsLabel = UILabel()
    let timeLabel = UILabel()
    let statsLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        backgroundColor = .clear
        selectionStyle = .default

        resultLabel.frame = CGRect(x: 15, y: 10, width: 300, height: 22)
        resultLabel.font = UIFont.boldSystemFont(ofSize: 16)
        resultLabel.textColor = .white
        contentView.addSubview(resultLabel)

        participantsLabel.frame = CGRect(x: 15, y: 32, width: 350, height: 18)
        participantsLabel.font = UIFont.systemFont(ofSize: 14)
        participantsLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        contentView.addSubview(participantsLabel)

        statsLabel.frame = CGRect(x: 15, y: 52, width: 350, height: 18)
        statsLabel.font = UIFont.systemFont(ofSize: 13)
        statsLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        contentView.addSubview(statsLabel)

        timeLabel.frame = CGRect(x: 15, y: 72, width: 350, height: 16)
        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        contentView.addSubview(timeLabel)
    }

    func configure(with record: CombatRecord) {
        let winnerIcon = record.winner == .attackerVictory ? "🏆" : (record.winner == .defenderVictory ? "🛡️" : "🤝")
        resultLabel.text = "\(winnerIcon) \(record.winner.displayName)"

        participantsLabel.text = "\(record.attacker.type.icon) \(record.attacker.name) vs \(record.defender.type.icon) \(record.defender.name)"

        statsLabel.text = "Casualties: ⚔️\(record.attackerCasualties) | 🛡️\(record.defenderCasualties) • Location: (\(record.location.q), \(record.location.r))"

        timeLabel.text = "\(record.getFormattedDate()) at \(record.getFormattedTime())"
    }
}
