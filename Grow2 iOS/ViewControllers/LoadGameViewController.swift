// ============================================================================
// FILE: LoadGameViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/LoadGameViewController.swift
// PURPOSE: Unified load game screen showing offline saves and online games
// ============================================================================

import UIKit

class LoadGameViewController: UIViewController {

    private var tableView: UITableView!
    private var activityIndicator: UIActivityIndicatorView!
    private var segmentedControl: UISegmentedControl!

    // Data
    private var onlineGames: [GameSession] = []
    private var isSignedIn: Bool { AuthService.shared.currentUser != nil }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    // MARK: - UI

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.12, blue: 0.1, alpha: 1.0)

        // Header
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
        titleLabel.text = "Load Game"
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

        // Segmented control: Offline / Online
        segmentedControl = UISegmentedControl(items: ["Offline Saves", "Online Games"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        view.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Table View
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Activity Indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Data Loading

    private func loadData() {
        activityIndicator.startAnimating()
        loadOnlineGames()
    }

    private func loadOnlineGames() {
        guard isSignedIn else {
            activityIndicator.stopAnimating()
            tableView.reloadData()
            return
        }

        GameSessionService.shared.listMyGames { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                switch result {
                case .success(let sessions):
                    self?.onlineGames = sessions.filter { $0.status != .finished }
                case .failure(let error):
                    debugLog("Failed to load online games: \(error.localizedDescription)")
                    self?.showTemporaryMessage("Failed to load online games")
                }
                self?.tableView.reloadData()
            }
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    @objc private func segmentChanged() {
        tableView.reloadData()
    }

    private var isOfflineTab: Bool {
        return segmentedControl.selectedSegmentIndex == 0
    }

    // MARK: - Offline Actions

    private func loadLocalSave() {
        guard GameSaveManager.shared.saveExists() else { return }

        let gameVC = GameViewController()
        gameVC.shouldLoadGame = true
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true)
    }

    private func deleteLocalSave() {
        showDestructiveConfirmation(
            title: "Delete Local Save?",
            message: "This cannot be undone.",
            confirmTitle: "Delete"
        ) { [weak self] in
            _ = GameSaveManager.shared.deleteSave()
            self?.tableView.reloadData()
            self?.showTemporaryMessage("Local save deleted")
        }
    }

    // MARK: - Online Actions

    private func resumeOnlineGame(session: GameSession) {
        let loadingAlert = UIAlertController(title: "Loading...", message: "Restoring game session", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        GameSessionService.shared.loadLatestSnapshot(gameID: session.gameID) { [weak self] result in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    guard let self = self else { return }

                    let gameVC = GameViewController()
                    gameVC.isOnlineMode = true

                    switch result {
                    case .success(let (snapshot, commands)):
                        debugLog("Loaded snapshot (seq: \(snapshot.commandSequence)) + \(commands.count) commands")
                        gameVC.mapType = .arabia
                        gameVC.mapSeed = session.mapConfig.seed
                        gameVC.onlineGameID = session.gameID
                        gameVC.onlineSnapshot = snapshot
                        gameVC.shouldLoadGame = true

                    case .failure(let error):
                        debugLog("Failed to load snapshot: \(error.localizedDescription)")
                        gameVC.shouldLoadGame = true
                        gameVC.onlineGameID = session.gameID
                    }

                    gameVC.modalPresentationStyle = .fullScreen
                    self.present(gameVC, animated: true)
                }
            }
        }
    }

    private func deleteOnlineGame(session: GameSession, index: Int) {
        showDestructiveConfirmation(
            title: "Delete Online Game?",
            message: "This will permanently remove the game session from the cloud.",
            confirmTitle: "Delete"
        ) { [weak self] in
            GameSessionService.shared.deleteGame(gameID: session.gameID) { [weak self] result in
                DispatchQueue.main.async {
                    if case .success = result {
                        self?.onlineGames.remove(at: index)
                        self?.tableView.reloadData()
                        self?.showTemporaryMessage("Online game deleted")
                    }
                }
            }
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - UITableViewDataSource

extension LoadGameViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isOfflineTab {
            return GameSaveManager.shared.saveExists() ? 1 : 0
        } else {
            return isSignedIn ? onlineGames.count : 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isOfflineTab {
            return "LOCAL SAVE"
        } else {
            if !isSignedIn {
                return "ONLINE GAMES (Sign in to access)"
            }
            return onlineGames.isEmpty ? "NO ONLINE GAMES" : "ONLINE GAMES (\(onlineGames.count))"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        cell.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = UIColor(white: 0.6, alpha: 1.0)
        cell.accessoryView = nil
        cell.accessoryType = .none

        if isOfflineTab {
            // Local save row
            let dateFormatter = RelativeDateTimeFormatter()
            dateFormatter.unitsStyle = .full
            let saveDate = GameSaveManager.shared.getSaveDate()
            let dateString = saveDate.map { dateFormatter.localizedString(for: $0, relativeTo: Date()) } ?? "Unknown"

            cell.textLabel?.text = "Current Game"
            cell.detailTextLabel?.text = "Last saved: \(dateString)"
            cell.accessoryType = .disclosureIndicator
        } else {
            // Online game row
            let session = onlineGames[indexPath.row]
            let opponents = session.players.values.filter { $0.uid != session.hostUID }
            let opponentName = opponents.first?.displayName ?? "AI"
            cell.textLabel?.text = "vs \(opponentName)"

            let statusText: String
            let statusColor: UIColor
            switch session.status {
            case .playing:
                statusText = "Playing"
                statusColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
            case .paused:
                statusText = "Paused"
                statusColor = UIColor(red: 0.8, green: 0.7, blue: 0.2, alpha: 1.0)
            case .finished:
                statusText = "Finished"
                statusColor = UIColor(white: 0.5, alpha: 1.0)
            case .lobby:
                statusText = "Lobby"
                statusColor = UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1.0)
            }

            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let dateString = formatter.localizedString(for: session.createdAt, relativeTo: Date())

            cell.detailTextLabel?.text = "\(statusText) | Cmds: \(session.currentCommandSequence) | \(dateString)"
            cell.detailTextLabel?.textColor = statusColor
            cell.accessoryType = .disclosureIndicator
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension LoadGameViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if isOfflineTab {
            loadLocalSave()
        } else {
            // Resume online game
            let session = onlineGames[indexPath.row]
            resumeOnlineGame(session: session)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if isOfflineTab {
            // Swipe to delete local save
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                self?.deleteLocalSave()
                completion(true)
            }
            return UISwipeActionsConfiguration(actions: [deleteAction])
        } else {
            // Swipe to delete online game
            let session = onlineGames[indexPath.row]
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                self?.deleteOnlineGame(session: session, index: indexPath.row)
                completion(true)
            }
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = UIColor(red: 0.5, green: 0.7, blue: 0.5, alpha: 1.0)
        header.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
    }
}
