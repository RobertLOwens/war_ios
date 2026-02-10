import UIKit
import SpriteKit

class MainMenuViewController: UIViewController {

    var titleLabel: UILabel!
    var newGameButton: UIButton!
    var resumeGameButton: UIButton!
    var settingsButton: UIButton!
    var lastSaveLabel: UILabel!
    var accountLabel: UILabel!

    private var authObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateResumeButton()
        updateAccountLabel()

        authObserver = NotificationCenter.default.addObserver(
            forName: AuthService.authStateChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccountLabel()
        }
    }

    deinit {
        if let observer = authObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateResumeButton()
        updateAccountLabel()
    }

    func setupUI() {
        view.backgroundColor = UIColor(red: 0.15, green: 0.2, blue: 0.15, alpha: 1.0)

        // Container stack for centering content vertically
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])

        // Account Label (at top of stack)
        accountLabel = UILabel()
        accountLabel.font = UIFont.systemFont(ofSize: 13)
        accountLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        accountLabel.textAlignment = .center
        stackView.addArrangedSubview(accountLabel)

        // Spacer before title
        let spacerTop = UIView()
        spacerTop.translatesAutoresizingMaskIntoConstraints = false
        spacerTop.heightAnchor.constraint(equalToConstant: 10).isActive = true
        stackView.addArrangedSubview(spacerTop)

        // Title
        titleLabel = UILabel()
        titleLabel.text = "🏰 Hex RTS Game"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 42)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Strategy & Conquest"
        subtitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        subtitleLabel.textAlignment = .center
        stackView.addArrangedSubview(subtitleLabel)

        // Spacer before buttons
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        stackView.addArrangedSubview(spacer)

        // New Game Button
        newGameButton = createMenuButton(
            title: "🆕 New Game",
            action: #selector(newGameTapped)
        )
        stackView.addArrangedSubview(newGameButton)

        // Resume Game Button
        resumeGameButton = createMenuButton(
            title: "▶️ Resume Game",
            action: #selector(resumeGameTapped)
        )
        resumeGameButton.backgroundColor = UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0)
        stackView.addArrangedSubview(resumeGameButton)

        // Last Save Label
        lastSaveLabel = UILabel()
        lastSaveLabel.font = UIFont.systemFont(ofSize: 12)
        lastSaveLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        lastSaveLabel.textAlignment = .center
        stackView.addArrangedSubview(lastSaveLabel)

        // Spacer before settings
        let spacer2 = UIView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(spacer2)

        // Settings Button
        settingsButton = createMenuButton(
            title: "⚙️ Settings",
            action: #selector(settingsTapped)
        )
        settingsButton.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        stackView.addArrangedSubview(settingsButton)

        // My Online Games Button
        let onlineGamesButton = createMenuButton(
            title: "🌐 My Online Games",
            action: #selector(onlineGamesTapped)
        )
        onlineGamesButton.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.35, alpha: 1.0)
        stackView.addArrangedSubview(onlineGamesButton)

        // Cloud Saves Button
        let cloudSavesButton = createMenuButton(
            title: "☁️ Cloud Saves",
            action: #selector(cloudSavesTapped)
        )
        cloudSavesButton.backgroundColor = UIColor(red: 0.2, green: 0.35, blue: 0.5, alpha: 1.0)
        stackView.addArrangedSubview(cloudSavesButton)

        // Delete Save Button
        let deleteSaveButton = UIButton(type: .system)
        deleteSaveButton.setTitle("🗑️ Delete Save", for: .normal)
        deleteSaveButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        deleteSaveButton.setTitleColor(.red, for: .normal)
        deleteSaveButton.addTarget(self, action: #selector(deleteSaveTapped), for: .touchUpInside)
        stackView.addArrangedSubview(deleteSaveButton)

        // Sign Out Button
        let signOutButton = UIButton(type: .system)
        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        signOutButton.setTitleColor(UIColor(white: 0.5, alpha: 1.0), for: .normal)
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
        stackView.addArrangedSubview(signOutButton)

        // Version Label (pinned to bottom)
        let versionLabel = UILabel()
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.text = "v1.0.0"
        versionLabel.font = UIFont.systemFont(ofSize: 12)
        versionLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        versionLabel.textAlignment = .center
        view.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            versionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            versionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }

    func createMenuButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1.0)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 6
        button.addTarget(self, action: action, for: .touchUpInside)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 280),
            button.heightAnchor.constraint(equalToConstant: 60)
        ])

        return button
    }

    func updateResumeButton() {
        let saveExists = GameSaveManager.shared.saveExists()
        resumeGameButton.isEnabled = saveExists
        resumeGameButton.alpha = saveExists ? 1.0 : 0.5

        if let saveDate = GameSaveManager.shared.getSaveDate() {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relativeTime = formatter.localizedString(for: saveDate, relativeTo: Date())
            lastSaveLabel.text = "Last saved: \(relativeTime)"
        } else {
            lastSaveLabel.text = "No saved game"
        }
    }

    private func updateAccountLabel() {
        if let user = AuthService.shared.currentUser {
            let displayText = user.displayName ?? user.email ?? "Signed In"
            accountLabel.text = "Signed in as \(displayText)"
        } else {
            accountLabel.text = "Not signed in"
        }
    }

    @objc func newGameTapped() {
        if GameSaveManager.shared.saveExists() {
            showDestructiveConfirmation(
                title: "⚠️ Start New Game?",
                message: "This will overwrite your current saved game. Are you sure?",
                confirmTitle: "New Game",
                onConfirm: { [weak self] in
                    self?.startNewGame()
                }
            )
        } else {
            startNewGame()
        }
    }

    func startNewGame() {
        // Clear background time data so new game doesn't inherit old resources
        BackgroundTimeManager.shared.clearExitTime()

        _ = GameSaveManager.shared.deleteSave()

        // Clear combat history from previous games
        GameEngine.shared.combatEngine.clearCombatHistory()

        // Show game setup screen to allow configuration
        let setupVC = GameSetupViewController()
        setupVC.modalPresentationStyle = .fullScreen
        present(setupVC, animated: true)
    }

    @objc func resumeGameTapped() {
        guard GameSaveManager.shared.saveExists() else {
            return
        }

        let gameVC = GameViewController()
        gameVC.modalPresentationStyle = .fullScreen

        // Set flag to load game after view appears
        gameVC.shouldLoadGame = true

        present(gameVC, animated: true)
    }

    @objc func settingsTapped() {
        let settingsVC = SettingsViewController()
        settingsVC.modalPresentationStyle = .fullScreen
        present(settingsVC, animated: true)
    }

    @objc func onlineGamesTapped() {
        guard AuthService.shared.currentUser != nil else {
            showAlert(title: "Not Signed In", message: "You must be signed in to view online games.")
            return
        }
        let onlineVC = OnlineGamesViewController()
        onlineVC.modalPresentationStyle = .fullScreen
        present(onlineVC, animated: true)
    }

    @objc func cloudSavesTapped() {
        guard AuthService.shared.currentUser != nil else {
            showAlert(title: "Not Signed In", message: "You must be signed in to use cloud saves.")
            return
        }
        let cloudVC = CloudSaveViewController()
        cloudVC.modalPresentationStyle = .fullScreen
        present(cloudVC, animated: true)
    }

    @objc func deleteSaveTapped() {
        guard GameSaveManager.shared.saveExists() else { return }

        showDestructiveConfirmation(
            title: "🗑️ Delete Save?",
            message: "This cannot be undone. Are you sure you want to delete your saved game?",
            confirmTitle: "Delete",
            onConfirm: { [weak self] in
                if GameSaveManager.shared.deleteSave() {
                    self?.updateResumeButton()
                    self?.showAlert(title: "✅ Deleted", message: "Your saved game has been deleted.")
                }
            }
        )
    }

    @objc func signOutTapped() {
        showConfirmation(
            title: "Sign Out",
            message: "Are you sure you want to sign out?",
            confirmTitle: "Sign Out",
            onConfirm: {
                do {
                    try AuthService.shared.signOut()
                    debugLog("User signed out")
                } catch {
                    debugLog("Sign out error: \(error.localizedDescription)")
                }
            }
        )
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
