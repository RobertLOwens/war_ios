// ============================================================================
// FILE: UserStatsViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/UserStatsViewController.swift
// PURPOSE: Display lifetime user statistics and recent game history
// ============================================================================

import UIKit

class UserStatsViewController: UIViewController {

    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var loadingSpinner: UIActivityIndicatorView!
    private var contentHeightConstraint: NSLayoutConstraint?
    private var recentGames: [GameHistoryEntry] = []
    private var expandedGameIndex: Int? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchStats()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.12, blue: 0.1, alpha: 1.0)

        _ = createHeader()

        loadingSpinner = UIActivityIndicatorView(style: .large)
        loadingSpinner.color = .white
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingSpinner)

        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        loadingSpinner.startAnimating()
    }

    private func createHeader() -> UIView {
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 0.15, green: 0.18, blue: 0.15, alpha: 1.0)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        let backButton = UIButton(type: .system)
        backButton.setTitle("Back", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(backButton)

        let titleLabel = UILabel()
        titleLabel.text = "My Statistics"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 100),

            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            backButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12)
        ])

        return headerView
    }

    // MARK: - Fetch Stats

    private func fetchStats() {
        guard AuthService.shared.currentUser != nil else {
            loadingSpinner.stopAnimating()
            showNotSignedIn()
            return
        }

        UserStatsService.shared.fetchStats { [weak self] result in
            DispatchQueue.main.async {
                self?.loadingSpinner.stopAnimating()
                switch result {
                case .success(let stats):
                    self?.displayStats(stats)
                    self?.fetchRecentGames()
                case .failure(let error):
                    self?.showError(message: error.localizedDescription)
                }
            }
        }
    }

    private func fetchRecentGames() {
        UserStatsService.shared.fetchRecentGames { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let games):
                    self?.recentGames = games
                    self?.displayRecentGames()
                case .failure(let error):
                    debugLog("Failed to fetch recent games: \(error)")
                }
            }
        }
    }

    // MARK: - Display Stats

    private var lifetimeEndY: CGFloat = 0

    private func displayStats(_ stats: UserStats) {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)

        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 110),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        var yOffset: CGFloat = 10

        // Games Section
        let winRate: String
        if stats.gamesPlayed > 0 {
            let pct = Double(stats.gamesWon) / Double(stats.gamesPlayed) * 100
            winRate = String(format: "%.0f%%", pct)
        } else {
            winRate = "—"
        }
        yOffset = addSectionHeader("Games", at: yOffset)
        yOffset = addStatGroup([
            ("Games Played", "\(stats.gamesPlayed)"),
            ("Games Won", "\(stats.gamesWon)"),
            ("Games Lost", "\(stats.gamesLost)"),
            ("Win Rate", winRate)
        ], at: yOffset)

        // Combat Section
        let kdRatio: String
        if stats.unitsLost > 0 {
            let kd = Double(stats.unitsKilled) / Double(stats.unitsLost)
            kdRatio = String(format: "%.2f", kd)
        } else if stats.unitsKilled > 0 {
            kdRatio = "Perfect"
        } else {
            kdRatio = "—"
        }
        yOffset += 12
        yOffset = addSectionHeader("Combat", at: yOffset)
        yOffset = addStatGroup([
            ("Battles Won", "\(stats.battlesWon)"),
            ("Battles Lost", "\(stats.battlesLost)"),
            ("Units Killed", "\(stats.unitsKilled)"),
            ("Units Lost", "\(stats.unitsLost)"),
            ("K/D Ratio", kdRatio)
        ], at: yOffset)

        // Economy Section
        yOffset += 12
        yOffset = addSectionHeader("Economy", at: yOffset)
        yOffset = addStatGroup([
            ("Buildings Built", "\(stats.buildingsBuilt)"),
            ("Resources Gathered", "\(stats.totalResourcesGathered)"),
            ("Highest Population", "\(stats.highestPopulation)")
        ], at: yOffset)

        // Time Section
        yOffset += 12
        yOffset = addSectionHeader("Time", at: yOffset)
        yOffset = addStatGroup([
            ("Total Play Time", formatPlayTime(stats.totalPlayTime))
        ], at: yOffset)

        yOffset += 20
        lifetimeEndY = yOffset

        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: yOffset + 40)
        contentHeightConstraint?.isActive = true
    }

    // MARK: - Recent Games

    private func displayRecentGames() {
        guard !recentGames.isEmpty else { return }

        // Remove old recent games views (tag 9000+)
        for subview in contentView.subviews where subview.tag >= 9000 {
            subview.removeFromSuperview()
        }

        var yOffset = lifetimeEndY

        // Section header
        let headerLabel = UILabel()
        headerLabel.text = "RECENT GAMES"
        headerLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = UIColor(red: 0.5, green: 0.7, blue: 0.5, alpha: 1.0)
        headerLabel.frame = CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 20)
        headerLabel.tag = 9000
        contentView.addSubview(headerLabel)
        yOffset += 30

        for (index, game) in recentGames.enumerated() {
            let isExpanded = expandedGameIndex == index
            let cardView = createGameCard(game: game, index: index, isExpanded: isExpanded)
            cardView.frame.origin = CGPoint(x: 16, y: yOffset)
            cardView.tag = 9001 + index
            contentView.addSubview(cardView)
            yOffset += cardView.bounds.height + 8
        }

        yOffset += 40
        contentHeightConstraint?.constant = yOffset
    }

    private func createGameCard(game: GameHistoryEntry, index: Int, isExpanded: Bool) -> UIView {
        let cardWidth = view.bounds.width - 32

        // Summary row height
        let summaryHeight: CGFloat = 52
        // Detail rows
        let detailRowHeight: CGFloat = 28
        let detailRows = 7
        let detailHeight: CGFloat = isExpanded ? CGFloat(detailRows) * detailRowHeight + 12 : 0
        let totalHeight = summaryHeight + detailHeight

        let card = UIView()
        card.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        card.layer.cornerRadius = 10
        card.clipsToBounds = true
        card.frame = CGRect(x: 0, y: 0, width: cardWidth, height: totalHeight)

        // Tap gesture for expand/collapse
        let tap = UITapGestureRecognizer(target: self, action: #selector(gameCardTapped(_:)))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true

        // Outcome indicator (colored bar on left)
        let indicatorBar = UIView()
        indicatorBar.backgroundColor = game.isVictory
            ? UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
            : UIColor(red: 0.8, green: 0.25, blue: 0.25, alpha: 1.0)
        indicatorBar.frame = CGRect(x: 0, y: 0, width: 4, height: totalHeight)
        card.addSubview(indicatorBar)

        // Outcome label
        let outcomeLabel = UILabel()
        outcomeLabel.text = game.isVictory ? "Victory" : "Defeat"
        outcomeLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        outcomeLabel.textColor = game.isVictory
            ? UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
            : UIColor(red: 0.8, green: 0.25, blue: 0.25, alpha: 1.0)
        outcomeLabel.frame = CGRect(x: 14, y: 8, width: 80, height: 20)
        card.addSubview(outcomeLabel)

        // Reason label
        let reasonLabel = UILabel()
        reasonLabel.text = displayReason(game.reason)
        reasonLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        reasonLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        reasonLabel.frame = CGRect(x: 14, y: 28, width: 140, height: 18)
        card.addSubview(reasonLabel)

        // Date label (relative)
        let dateLabel = UILabel()
        dateLabel.text = relativeDate(game.date)
        dateLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        dateLabel.textColor = UIColor(white: 0.45, alpha: 1.0)
        dateLabel.textAlignment = .right
        dateLabel.frame = CGRect(x: cardWidth - 170, y: 8, width: 150, height: 18)
        card.addSubview(dateLabel)

        // Duration label
        let durationLabel = UILabel()
        durationLabel.text = formatPlayTime(game.duration)
        durationLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        durationLabel.textColor = UIColor(white: 0.45, alpha: 1.0)
        durationLabel.textAlignment = .right
        durationLabel.frame = CGRect(x: cardWidth - 170, y: 28, width: 150, height: 18)
        card.addSubview(durationLabel)

        // Chevron
        let chevron = UILabel()
        chevron.text = isExpanded ? "▾" : "▸"
        chevron.font = UIFont.systemFont(ofSize: 14)
        chevron.textColor = UIColor(white: 0.4, alpha: 1.0)
        chevron.frame = CGRect(x: cardWidth - 24, y: 16, width: 16, height: 20)
        card.addSubview(chevron)

        // Expanded detail rows
        if isExpanded {
            var detailY = summaryHeight + 4
            let detailData: [(String, String)] = [
                ("Battles Won", "\(game.battlesWon)"),
                ("Battles Lost", "\(game.battlesLost)"),
                ("Units Killed", "\(game.unitsKilled)"),
                ("Units Lost", "\(game.unitsLost)"),
                ("Buildings Built", "\(game.buildingsBuilt)"),
                ("Resources Gathered", "\(game.resourcesGathered)"),
                ("Max Population", "\(game.maxPopulation)")
            ]

            for row in detailData {
                let keyLabel = UILabel()
                keyLabel.text = row.0
                keyLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
                keyLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
                keyLabel.frame = CGRect(x: 14, y: detailY, width: 160, height: detailRowHeight)
                card.addSubview(keyLabel)

                let valLabel = UILabel()
                valLabel.text = row.1
                valLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                valLabel.textColor = .white
                valLabel.textAlignment = .right
                valLabel.frame = CGRect(x: cardWidth - 170, y: detailY, width: 150, height: detailRowHeight)
                card.addSubview(valLabel)

                detailY += detailRowHeight
            }
        }

        return card
    }

    @objc private func gameCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let tappedView = gesture.view, tappedView.tag >= 9001 else { return }
        let index = tappedView.tag - 9001

        if expandedGameIndex == index {
            expandedGameIndex = nil
        } else {
            expandedGameIndex = index
        }

        displayRecentGames()
    }

    // MARK: - Stat Row Helpers

    private func addSectionHeader(_ title: String, at yOffset: CGFloat) -> CGFloat {
        let label = UILabel()
        label.text = title.uppercased()
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor(red: 0.5, green: 0.7, blue: 0.5, alpha: 1.0)
        label.frame = CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 20)
        contentView.addSubview(label)
        return yOffset + 30
    }

    private func addStatGroup(_ rows: [(String, String)], at yOffset: CGFloat) -> CGFloat {
        let rowHeight: CGFloat = 36
        let padding: CGFloat = 14

        let containerView = UIView()
        containerView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        containerView.layer.cornerRadius = 10
        let totalHeight = CGFloat(rows.count) * rowHeight + padding * 2
        containerView.frame = CGRect(x: 16, y: yOffset, width: view.bounds.width - 32, height: totalHeight)
        contentView.addSubview(containerView)

        for (index, row) in rows.enumerated() {
            let y = padding + CGFloat(index) * rowHeight

            let keyLabel = UILabel()
            keyLabel.text = row.0
            keyLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            keyLabel.textColor = UIColor(white: 0.55, alpha: 1.0)
            keyLabel.frame = CGRect(x: 16, y: y, width: 180, height: rowHeight)
            containerView.addSubview(keyLabel)

            let valueLabel = UILabel()
            valueLabel.text = row.1
            valueLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            valueLabel.textColor = .white
            valueLabel.textAlignment = .right
            valueLabel.frame = CGRect(x: containerView.bounds.width - 196, y: y, width: 180, height: rowHeight)
            containerView.addSubview(valueLabel)
        }

        return yOffset + totalHeight + 8
    }

    // MARK: - Not Signed In

    private func showNotSignedIn() {
        let label = UILabel()
        label.text = "Sign in to track your statistics."
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textColor = UIColor(white: 0.5, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Helpers

    private func formatPlayTime(_ seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }

    private func displayReason(_ reason: String) -> String {
        switch reason {
        case "conquest": return "Conquest"
        case "starvation": return "Starvation"
        case "resignation": return "Resignation"
        case "cityCenterDestroyed": return "City Destroyed"
        default: return reason.capitalized
        }
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
