// ============================================================================
// FILE: OnlineGamesViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/OnlineGamesViewController.swift
// PURPOSE: Lists user's online game sessions with resume/delete actions
// ============================================================================

import UIKit

class OnlineGamesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private var tableView: UITableView!
    private var games: [GameSession] = []
    private var loadingIndicator: UIActivityIndicatorView!
    private var emptyLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadGames()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.15, green: 0.2, blue: 0.15, alpha: 1.0)

        // Header
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        let titleLabel = UILabel()
        titleLabel.text = "My Online Games"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        let backButton = UIButton(type: .system)
        backButton.setTitle("Back", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(backButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])

        // Table View
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(OnlineGameCell.self, forCellReuseIdentifier: "OnlineGameCell")
        tableView.separatorColor = UIColor(white: 0.3, alpha: 1.0)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Loading indicator
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Empty state label
        emptyLabel = UILabel()
        emptyLabel.text = "No online games yet.\nStart a new Arabia game to create one."
        emptyLabel.font = UIFont.systemFont(ofSize: 16)
        emptyLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }

    // MARK: - Data Loading

    private func loadGames() {
        loadingIndicator.startAnimating()
        tableView.isHidden = true
        emptyLabel.isHidden = true

        GameSessionService.shared.listMyGames { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.loadingIndicator.stopAnimating()

                switch result {
                case .success(let sessions):
                    self.games = sessions
                    self.tableView.isHidden = sessions.isEmpty
                    self.emptyLabel.isHidden = !sessions.isEmpty
                    self.tableView.reloadData()

                case .failure(let error):
                    self.emptyLabel.text = "Failed to load games:\n\(error.localizedDescription)"
                    self.emptyLabel.isHidden = false
                }
            }
        }
    }

    // MARK: - Table View Data Source

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return games.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OnlineGameCell", for: indexPath) as! OnlineGameCell
        let session = games[indexPath.row]
        cell.configure(with: session)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    // MARK: - Table View Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let session = games[indexPath.row]
        resumeGame(session: session)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let session = games[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.deleteGame(session: session, at: indexPath)
            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    // MARK: - Actions

    private func resumeGame(session: GameSession) {
        let loadingAlert = UIAlertController(title: "Loading...", message: "Restoring game session", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        GameSessionService.shared.loadLatestSnapshot(gameID: session.gameID) { [weak self] result in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    guard let self = self else { return }

                    switch result {
                    case .success(let (snapshot, commands)):
                        debugLog("Loaded snapshot (seq: \(snapshot.commandSequence)) + \(commands.count) commands")

                        // For now, use the local save flow — snapshot-based restore
                        // will be fully integrated once GameState → visual rebuild is implemented
                        let gameVC = GameViewController()
                        gameVC.mapType = .arabia
                        gameVC.mapSeed = session.mapConfig.seed
                        gameVC.onlineGameID = session.gameID
                        gameVC.shouldLoadGame = true
                        gameVC.modalPresentationStyle = .fullScreen
                        self.present(gameVC, animated: true)

                    case .failure(let error):
                        debugLog("Failed to load snapshot: \(error.localizedDescription)")
                        // Fall back to local save
                        let gameVC = GameViewController()
                        gameVC.shouldLoadGame = true
                        gameVC.onlineGameID = session.gameID
                        gameVC.modalPresentationStyle = .fullScreen
                        self.present(gameVC, animated: true)
                    }
                }
            }
        }
    }

    private func deleteGame(session: GameSession, at indexPath: IndexPath) {
        GameSessionService.shared.deleteGame(gameID: session.gameID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.games.remove(at: indexPath.row)
                    self?.tableView.deleteRows(at: [indexPath], with: .fade)
                    if self?.games.isEmpty == true {
                        self?.emptyLabel.isHidden = false
                        self?.tableView.isHidden = true
                    }
                case .failure(let error):
                    debugLog("Failed to delete game: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - Online Game Cell

class OnlineGameCell: UITableViewCell {

    private let statusLabel = UILabel()
    private let opponentLabel = UILabel()
    private let dateLabel = UILabel()
    private let detailLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .gray

        let selectedView = UIView()
        selectedView.backgroundColor = UIColor(white: 0.3, alpha: 0.5)
        selectedBackgroundView = selectedView

        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)

        opponentLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        opponentLabel.textColor = .white
        opponentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(opponentLabel)

        dateLabel.font = UIFont.systemFont(ofSize: 12)
        dateLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dateLabel)

        detailLabel.font = UIFont.systemFont(ofSize: 12)
        detailLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            opponentLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            opponentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            opponentLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -8),

            detailLabel.topAnchor.constraint(equalTo: opponentLabel.bottomAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

            dateLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        ])
    }

    func configure(with session: GameSession) {
        // Find opponent name
        let opponents = session.players.values.filter { $0.uid != session.hostUID }
        let opponentName = opponents.first?.displayName ?? "Unknown"
        opponentLabel.text = "vs \(opponentName)"

        // Status badge
        switch session.status {
        case .playing:
            statusLabel.text = "PLAYING"
            statusLabel.textColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        case .paused:
            statusLabel.text = "PAUSED"
            statusLabel.textColor = UIColor(red: 0.8, green: 0.7, blue: 0.2, alpha: 1.0)
        case .finished:
            statusLabel.text = "FINISHED"
            statusLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        case .lobby:
            statusLabel.text = "LOBBY"
            statusLabel.textColor = UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1.0)
        }

        // Detail
        detailLabel.text = "Map: Arabia | Commands: \(session.currentCommandSequence)"

        // Date
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        dateLabel.text = formatter.localizedString(for: session.createdAt, relativeTo: Date())
    }
}
