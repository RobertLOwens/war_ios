// ============================================================================
// FILE: CombatHistoryViewController.swift
// LOCATION: Create this as a NEW FILE
// ============================================================================

import UIKit

class CombatHistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var tableView: UITableView!
    var closeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
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
        tableView = UITableView(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: view.bounds.height - 100), style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        tableView.separatorColor = UIColor(white: 0.3, alpha: 1.0)
        tableView.register(CombatHistoryCell.self, forCellReuseIdentifier: "CombatHistoryCell")
        view.addSubview(tableView)
    }
    
    // MARK: - TableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CombatSystem.shared.combatHistory.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CombatHistoryCell", for: indexPath) as! CombatHistoryCell
        let record = CombatSystem.shared.combatHistory[indexPath.row]
        cell.configure(with: record)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let record = CombatSystem.shared.combatHistory[indexPath.row]
        showDetailedRecord(record)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func showDetailedRecord(_ record: CombatRecord) {
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

