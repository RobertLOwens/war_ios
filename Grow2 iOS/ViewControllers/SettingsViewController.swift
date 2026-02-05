// ============================================================================
// FILE: SettingsViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/SettingsViewController.swift
// PURPOSE: Game settings screen with notification and gameplay preferences
// ============================================================================

import UIKit

// MARK: - Settings Keys

struct SettingsKeys {
    // In-game notification toggles
    static let notifyCombatAlerts = "settings.notify.combatAlerts"
    static let notifyScoutingAlerts = "settings.notify.scoutingAlerts"
    static let notifyBuildingComplete = "settings.notify.buildingComplete"
    static let notifyTrainingComplete = "settings.notify.trainingComplete"
    static let notifyResourceAlerts = "settings.notify.resourceAlerts"
    static let notifyResearchComplete = "settings.notify.researchComplete"

    // Push notification toggles
    static let pushEnabled = "settings.push.enabled"
    static let pushCombatAlerts = "settings.push.combatAlerts"
    static let pushScoutingAlerts = "settings.push.scoutingAlerts"
    static let pushBuildingComplete = "settings.push.buildingComplete"
    static let pushTrainingComplete = "settings.push.trainingComplete"
    static let pushResourceAlerts = "settings.push.resourceAlerts"
    static let pushResearchComplete = "settings.push.researchComplete"

    // Gameplay
    static let showTutorialHints = "settings.gameplay.tutorialHints"
    static let confirmDestructiveActions = "settings.gameplay.confirmDestructive"
}

// MARK: - Settings Manager

class GameSettings {
    static let shared = GameSettings()

    private let defaults = UserDefaults.standard

    private init() {
        // Set default values on first launch
        registerDefaults()
    }

    private func registerDefaults() {
        let defaultValues: [String: Any] = [
            // In-game notifications
            SettingsKeys.notifyCombatAlerts: true,
            SettingsKeys.notifyScoutingAlerts: true,
            SettingsKeys.notifyBuildingComplete: true,
            SettingsKeys.notifyTrainingComplete: true,
            SettingsKeys.notifyResourceAlerts: true,
            SettingsKeys.notifyResearchComplete: true,
            // Push notifications
            SettingsKeys.pushEnabled: true,
            SettingsKeys.pushCombatAlerts: true,
            SettingsKeys.pushScoutingAlerts: true,
            SettingsKeys.pushBuildingComplete: true,
            SettingsKeys.pushTrainingComplete: true,
            SettingsKeys.pushResourceAlerts: false,  // Resource alerts can be spammy
            SettingsKeys.pushResearchComplete: true,
            // Gameplay
            SettingsKeys.showTutorialHints: true,
            SettingsKeys.confirmDestructiveActions: true
        ]
        defaults.register(defaults: defaultValues)
    }

    func bool(forKey key: String) -> Bool {
        return defaults.bool(forKey: key)
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

// MARK: - Settings View Controller

class SettingsViewController: UIViewController {

    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var switches: [String: UISwitch] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.12, blue: 0.1, alpha: 1.0)

        // Header
        let headerView = createHeader()
        view.addSubview(headerView)

        // Scroll View
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)

        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Build settings sections
        var yOffset: CGFloat = 20

        // Notification Settings Section
        yOffset = addSectionHeader("Notifications", at: yOffset)
        yOffset = addToggle(
            title: "Combat Alerts",
            subtitle: "When your units are attacked",
            key: SettingsKeys.notifyCombatAlerts,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Scouting Alerts",
            subtitle: "When enemy units are spotted",
            key: SettingsKeys.notifyScoutingAlerts,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Building Complete",
            subtitle: "When construction finishes",
            key: SettingsKeys.notifyBuildingComplete,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Training Complete",
            subtitle: "When unit training finishes",
            key: SettingsKeys.notifyTrainingComplete,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Resource Alerts",
            subtitle: "Storage full or deposits depleted",
            key: SettingsKeys.notifyResourceAlerts,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Research Complete",
            subtitle: "When research finishes",
            key: SettingsKeys.notifyResearchComplete,
            at: yOffset
        )

        // Push Notification Settings Section
        yOffset += 20
        yOffset = addSectionHeader("Push Notifications (Background)", at: yOffset)
        yOffset = addToggle(
            title: "Enable Push Notifications",
            subtitle: "Receive alerts when app is in background",
            key: SettingsKeys.pushEnabled,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Combat Alerts",
            subtitle: "Push when units are attacked",
            key: SettingsKeys.pushCombatAlerts,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Scouting Alerts",
            subtitle: "Push when enemies are spotted",
            key: SettingsKeys.pushScoutingAlerts,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Building Complete",
            subtitle: "Push when construction finishes",
            key: SettingsKeys.pushBuildingComplete,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Training Complete",
            subtitle: "Push when unit training finishes",
            key: SettingsKeys.pushTrainingComplete,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Resource Alerts",
            subtitle: "Push for storage full or deposits depleted",
            key: SettingsKeys.pushResourceAlerts,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Research Complete",
            subtitle: "Push when research finishes",
            key: SettingsKeys.pushResearchComplete,
            at: yOffset
        )

        // Gameplay Settings Section
        yOffset += 20
        yOffset = addSectionHeader("Gameplay", at: yOffset)
        yOffset = addToggle(
            title: "Tutorial Hints",
            subtitle: "Show helpful hints during gameplay",
            key: SettingsKeys.showTutorialHints,
            at: yOffset
        )
        yOffset = addToggle(
            title: "Confirm Destructive Actions",
            subtitle: "Ask before deleting saves or surrendering",
            key: SettingsKeys.confirmDestructiveActions,
            at: yOffset
        )

        // Add bottom padding
        yOffset += 40

        // Set content size
        contentView.heightAnchor.constraint(equalToConstant: yOffset).isActive = true
    }

    private func createHeader() -> UIView {
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 0.15, green: 0.18, blue: 0.15, alpha: 1.0)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        let backButton = UIButton(type: .system)
        backButton.setTitle("Done", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(backButton)

        let titleLabel = UILabel()
        titleLabel.text = "Settings"
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

    private func addSectionHeader(_ title: String, at yOffset: CGFloat) -> CGFloat {
        let label = UILabel()
        label.text = title.uppercased()
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor(red: 0.5, green: 0.7, blue: 0.5, alpha: 1.0)
        label.frame = CGRect(x: 20, y: yOffset, width: view.bounds.width - 40, height: 20)
        contentView.addSubview(label)

        return yOffset + 30
    }

    private func addToggle(title: String, subtitle: String, key: String, at yOffset: CGFloat) -> CGFloat {
        let rowHeight: CGFloat = 70

        let containerView = UIView()
        containerView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        containerView.layer.cornerRadius = 10
        containerView.frame = CGRect(x: 16, y: yOffset, width: view.bounds.width - 32, height: rowHeight)
        contentView.addSubview(containerView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.frame = CGRect(x: 16, y: 14, width: containerView.bounds.width - 90, height: 22)
        containerView.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        subtitleLabel.frame = CGRect(x: 16, y: 38, width: containerView.bounds.width - 90, height: 18)
        containerView.addSubview(subtitleLabel)

        let toggle = UISwitch()
        toggle.isOn = GameSettings.shared.bool(forKey: key)
        toggle.onTintColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)
        toggle.frame = CGRect(x: containerView.bounds.width - 67, y: (rowHeight - 31) / 2, width: 51, height: 31)
        toggle.accessibilityIdentifier = key
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        containerView.addSubview(toggle)

        switches[key] = toggle

        return yOffset + rowHeight + 8
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        guard let key = sender.accessibilityIdentifier else { return }
        GameSettings.shared.set(sender.isOn, forKey: key)
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
