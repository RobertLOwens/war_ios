// ============================================================================
// FILE: GameOverViewController.swift
// PURPOSE: Shows victory/defeat screen with game statistics
// ============================================================================

import UIKit

class GameOverViewController: UIViewController {

    // MARK: - Properties

    /// Whether the player won or lost
    var isVictory: Bool = false

    /// The reason for game over
    var gameOverReason: GameOverReason = .resignation

    /// Game statistics to display
    var statistics: GameStatistics?

    // MARK: - UI Elements

    private var resultLabel: UILabel!
    private var reasonLabel: UILabel!
    private var statsContainerView: UIView!
    private var mainMenuButton: UIButton!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        displayResults()
    }

    // MARK: - Setup

    private func setupUI() {
        // Background based on victory/defeat
        if isVictory {
            view.backgroundColor = UIColor(red: 0.15, green: 0.25, blue: 0.15, alpha: 1.0)
        } else {
            view.backgroundColor = UIColor(red: 0.25, green: 0.15, blue: 0.15, alpha: 1.0)
        }

        // Result Label (Victory/Defeat)
        resultLabel = UILabel()
        resultLabel.font = UIFont.boldSystemFont(ofSize: 48)
        resultLabel.textColor = .white
        resultLabel.textAlignment = .center
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultLabel)

        // Reason Label
        reasonLabel = UILabel()
        reasonLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        reasonLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        reasonLabel.textAlignment = .center
        reasonLabel.numberOfLines = 0
        reasonLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(reasonLabel)

        // Stats Container
        statsContainerView = UIView()
        statsContainerView.backgroundColor = UIColor(white: 0.1, alpha: 0.8)
        statsContainerView.layer.cornerRadius = 16
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statsContainerView)

        // Main Menu Button
        mainMenuButton = UIButton(type: .system)
        mainMenuButton.setTitle("Return to Main Menu", for: .normal)
        mainMenuButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        mainMenuButton.setTitleColor(.white, for: .normal)
        mainMenuButton.backgroundColor = UIColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1.0)
        mainMenuButton.layer.cornerRadius = 12
        mainMenuButton.translatesAutoresizingMaskIntoConstraints = false
        mainMenuButton.addTarget(self, action: #selector(mainMenuTapped), for: .touchUpInside)
        view.addSubview(mainMenuButton)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Result Label
            resultLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Reason Label
            reasonLabel.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 16),
            reasonLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            reasonLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // Stats Container
            statsContainerView.topAnchor.constraint(equalTo: reasonLabel.bottomAnchor, constant: 40),
            statsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // Main Menu Button
            mainMenuButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            mainMenuButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainMenuButton.widthAnchor.constraint(equalToConstant: 280),
            mainMenuButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    private func displayResults() {
        // Set result text
        if isVictory {
            resultLabel.text = "Victory!"
            resultLabel.textColor = UIColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
        } else {
            resultLabel.text = "Defeat"
            resultLabel.textColor = UIColor(red: 0.8, green: 0.4, blue: 0.4, alpha: 1.0)
        }

        // Set reason text
        reasonLabel.text = gameOverReason.displayMessage

        // Build stats view
        buildStatsView()
    }

    private func buildStatsView() {
        guard let stats = statistics else {
            // If no statistics, just show a basic message
            let noStatsLabel = UILabel()
            noStatsLabel.text = "Game statistics unavailable"
            noStatsLabel.font = UIFont.systemFont(ofSize: 16)
            noStatsLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            noStatsLabel.textAlignment = .center
            noStatsLabel.translatesAutoresizingMaskIntoConstraints = false
            statsContainerView.addSubview(noStatsLabel)

            NSLayoutConstraint.activate([
                noStatsLabel.topAnchor.constraint(equalTo: statsContainerView.topAnchor, constant: 20),
                noStatsLabel.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: -20),
                noStatsLabel.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 20),
                noStatsLabel.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -20)
            ])
            return
        }

        // Create a stack view for stats
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: statsContainerView.topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: -20),
            stackView.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -20)
        ])

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Game Statistics"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)

        // Separator
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separator)

        // Add stat rows
        addStatRow(to: stackView, icon: "⏱️", label: "Time Played", value: formatDuration(stats.totalTimePlayed))
        addStatRow(to: stackView, icon: "⚔️", label: "Battles Fought", value: "\(stats.battlesWon + stats.battlesLost)")
        addStatRow(to: stackView, icon: "🏆", label: "Battles Won", value: "\(stats.battlesWon)")
        addStatRow(to: stackView, icon: "💀", label: "Battles Lost", value: "\(stats.battlesLost)")
        addStatRow(to: stackView, icon: "🗡️", label: "Units Killed", value: "\(stats.unitsKilled)")
        addStatRow(to: stackView, icon: "🩸", label: "Units Lost", value: "\(stats.unitsLost)")
        addStatRow(to: stackView, icon: "🏗️", label: "Buildings Built", value: "\(stats.buildingsBuilt)")
        addStatRow(to: stackView, icon: "📦", label: "Resources Gathered", value: formatNumber(stats.totalResourcesGathered))
        addStatRow(to: stackView, icon: "👥", label: "Max Population", value: "\(stats.maxPopulation)")
    }

    private func addStatRow(to stackView: UIStackView, icon: String, label: String, value: String) {
        let rowView = UIView()
        rowView.translatesAutoresizingMaskIntoConstraints = false

        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 18)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(iconLabel)

        let nameLabel = UILabel()
        nameLabel.text = label
        nameLabel.font = UIFont.systemFont(ofSize: 16)
        nameLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(nameLabel)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.boldSystemFont(ofSize: 16)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            rowView.heightAnchor.constraint(equalToConstant: 28),

            iconLabel.leadingAnchor.constraint(equalTo: rowView.leadingAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 30),

            nameLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: rowView.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 8)
        ])

        stackView.addArrangedSubview(rowView)
    }

    // MARK: - Formatting Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }

    // MARK: - Actions

    @objc private func mainMenuTapped() {
        // Delete the save file since the game is over
        _ = GameSaveManager.shared.deleteSave()

        // Clear combat history
        CombatSystem.shared.clearCombatHistory()

        // Dismiss all presented view controllers and return to main menu
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let mainMenuVC = MainMenuViewController()
            mainMenuVC.modalPresentationStyle = .fullScreen

            // Fade transition
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.rootViewController = mainMenuVC
            }
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - Game Statistics

struct GameStatistics {
    var totalTimePlayed: TimeInterval = 0
    var battlesWon: Int = 0
    var battlesLost: Int = 0
    var unitsKilled: Int = 0
    var unitsLost: Int = 0
    var buildingsBuilt: Int = 0
    var totalResourcesGathered: Int = 0
    var maxPopulation: Int = 0

    static func gather(from player: Player, gameStartTime: TimeInterval) -> GameStatistics {
        var stats = GameStatistics()

        // Calculate time played
        stats.totalTimePlayed = Date().timeIntervalSince1970 - gameStartTime

        // Combat statistics from CombatSystem
        let combatHistory = CombatSystem.shared.getCombatHistory()
        for record in combatHistory {
            // Match by owner name since CombatRecord uses names
            if record.attacker.ownerName == player.name {
                // Player was attacker
                if record.winner == .attackerVictory {
                    stats.battlesWon += 1
                } else {
                    stats.battlesLost += 1
                }
                stats.unitsKilled += record.defenderCasualties
                stats.unitsLost += record.attackerCasualties
            } else if record.defender.ownerName == player.name {
                // Player was defender
                if record.winner == .defenderVictory {
                    stats.battlesWon += 1
                } else {
                    stats.battlesLost += 1
                }
                stats.unitsKilled += record.attackerCasualties
                stats.unitsLost += record.defenderCasualties
            }
        }

        // Buildings
        stats.buildingsBuilt = player.buildings.count

        // Resources (sum of current resources as approximation)
        for (_, amount) in player.resources {
            stats.totalResourcesGathered += amount
        }

        // Population
        stats.maxPopulation = player.getCurrentPopulation()

        return stats
    }
}
