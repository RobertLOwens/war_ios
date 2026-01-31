import UIKit
import SpriteKit

class MainMenuViewController: UIViewController {
    
    var titleLabel: UILabel!
    var newGameButton: UIButton!
    var resumeGameButton: UIButton!
    var settingsButton: UIButton!
    var lastSaveLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateResumeButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateResumeButton()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor(red: 0.15, green: 0.2, blue: 0.15, alpha: 1.0)
        
        // Title
        titleLabel = UILabel(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: 80))
        titleLabel.text = "🏰 Hex RTS Game"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 42)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = UILabel(frame: CGRect(x: 0, y: 180, width: view.bounds.width, height: 30))
        subtitleLabel.text = "Strategy & Conquest"
        subtitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        subtitleLabel.textAlignment = .center
        view.addSubview(subtitleLabel)
        
        // New Game Button
        newGameButton = createMenuButton(
            title: "🆕 New Game",
            y: 280,
            action: #selector(newGameTapped)
        )
        view.addSubview(newGameButton)
        
        // Resume Game Button
        resumeGameButton = createMenuButton(
            title: "▶️ Resume Game",
            y: 360,
            action: #selector(resumeGameTapped)
        )
        resumeGameButton.backgroundColor = UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0)
        view.addSubview(resumeGameButton)
        
        // Last Save Label
        lastSaveLabel = UILabel(frame: CGRect(x: 0, y: 430, width: view.bounds.width, height: 20))
        lastSaveLabel.font = UIFont.systemFont(ofSize: 12)
        lastSaveLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        lastSaveLabel.textAlignment = .center
        view.addSubview(lastSaveLabel)
        
        // Settings Button
        settingsButton = createMenuButton(
            title: "⚙️ Settings",
            y: 480,
            action: #selector(settingsTapped)
        )
        settingsButton.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        view.addSubview(settingsButton)
        
        // Delete Save Button
        let deleteSaveButton = UIButton(frame: CGRect(x: (view.bounds.width - 180) / 2, y: 560, width: 180, height: 40))
        deleteSaveButton.setTitle("🗑️ Delete Save", for: .normal)
        deleteSaveButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        deleteSaveButton.setTitleColor(.red, for: .normal)
        deleteSaveButton.addTarget(self, action: #selector(deleteSaveTapped), for: .touchUpInside)
        view.addSubview(deleteSaveButton)
        
        // Version Label
        let versionLabel = UILabel(frame: CGRect(x: 0, y: view.bounds.height - 40, width: view.bounds.width, height: 20))
        versionLabel.text = "v1.0.0"
        versionLabel.font = UIFont.systemFont(ofSize: 12)
        versionLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        versionLabel.textAlignment = .center
        view.addSubview(versionLabel)
    }
    
    func createMenuButton(title: String, y: CGFloat, action: Selector) -> UIButton {
        let button = UIButton(frame: CGRect(x: (view.bounds.width - 280) / 2, y: y, width: 280, height: 60))
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.backgroundColor = UIColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1.0)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 6
        button.addTarget(self, action: action, for: .touchUpInside)
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
        // ✅ FIX: Clear background time data so new game doesn't inherit old resources
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
        showAlert(title: "⚙️ Settings", message: "Settings coming soon!")

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
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

