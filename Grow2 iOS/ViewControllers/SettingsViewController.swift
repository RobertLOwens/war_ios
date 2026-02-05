// ============================================================================
// FILE: SettingsViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/SettingsViewController.swift
// PURPOSE: Settings screen for notification preferences
// ============================================================================

import UIKit

class SettingsViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Push notification toggles
    private var pushMasterSwitch: UISwitch!
    private var pushCombatSwitch: UISwitch!
    private var pushEnemySightingsSwitch: UISwitch!
    private var pushBuildingSwitch: UISwitch!
    private var pushTrainingSwitch: UISwitch!
    private var pushResearchSwitch: UISwitch!
    private var pushResourceSwitch: UISwitch!

    // Container for category toggles (to enable/disable based on master)
    private var pushCategoryTogglesContainer: UIStackView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)

        setupScrollView()
        setupHeader()
        setupPushNotificationToggles()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupHeader() {
        // Back Button
        let backButton = UIButton(type: .system)
        backButton.setTitle("< Back", for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        backButton.setTitleColor(.white, for: .normal)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backButton)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Settings"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    private func setupPushNotificationToggles() {
        // Section Header
        let sectionHeader = createSectionHeader(title: "Push Notifications")
        sectionHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sectionHeader)

        NSLayoutConstraint.activate([
            sectionHeader.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 80),
            sectionHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sectionHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])

        // Master Toggle Container
        let masterContainer = UIStackView()
        masterContainer.axis = .vertical
        masterContainer.spacing = 0
        masterContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(masterContainer)

        NSLayoutConstraint.activate([
            masterContainer.topAnchor.constraint(equalTo: sectionHeader.bottomAnchor, constant: 12),
            masterContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            masterContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])

        // Master toggle row
        let masterRow: UIView
        (masterRow, pushMasterSwitch) = createToggleRow(
            icon: "bell.fill",
            title: "Enable Push Notifications",
            description: "Receive alerts when app is backgrounded"
        )
        pushMasterSwitch.addTarget(self, action: #selector(pushMasterSwitchChanged), for: .valueChanged)
        masterContainer.addArrangedSubview(masterRow)

        // Category toggles section header
        let categoryHeader = createSectionHeader(title: "Notification Categories")
        categoryHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(categoryHeader)

        NSLayoutConstraint.activate([
            categoryHeader.topAnchor.constraint(equalTo: masterContainer.bottomAnchor, constant: 24),
            categoryHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            categoryHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])

        // Category Toggle Rows Container
        pushCategoryTogglesContainer = UIStackView()
        pushCategoryTogglesContainer.axis = .vertical
        pushCategoryTogglesContainer.spacing = 0
        pushCategoryTogglesContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pushCategoryTogglesContainer)

        NSLayoutConstraint.activate([
            pushCategoryTogglesContainer.topAnchor.constraint(equalTo: categoryHeader.bottomAnchor, constant: 12),
            pushCategoryTogglesContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            pushCategoryTogglesContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            pushCategoryTogglesContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])

        // Create category toggle rows
        let combatRow: UIView
        (combatRow, pushCombatSwitch) = createToggleRow(
            icon: "crossed.swords.fill",
            title: "Combat Alerts",
            description: "Army and villager attacks"
        )
        pushCombatSwitch.addTarget(self, action: #selector(pushCombatSwitchChanged), for: .valueChanged)
        pushCategoryTogglesContainer.addArrangedSubview(combatRow)

        let enemyRow: UIView
        (enemyRow, pushEnemySightingsSwitch) = createToggleRow(
            icon: "eye.fill",
            title: "Enemy Sightings",
            description: "Spotted enemy armies"
        )
        pushEnemySightingsSwitch.addTarget(self, action: #selector(pushEnemySightingsSwitchChanged), for: .valueChanged)
        pushCategoryTogglesContainer.addArrangedSubview(enemyRow)

        let buildingRow: UIView
        (buildingRow, pushBuildingSwitch) = createToggleRow(
            icon: "building.2.fill",
            title: "Building Updates",
            description: "Construction and upgrades"
        )
        pushBuildingSwitch.addTarget(self, action: #selector(pushBuildingSwitchChanged), for: .valueChanged)
        pushCategoryTogglesContainer.addArrangedSubview(buildingRow)

        let trainingRow: UIView
        (trainingRow, pushTrainingSwitch) = createToggleRow(
            icon: "person.3.fill",
            title: "Training Updates",
            description: "Unit training completed"
        )
        pushTrainingSwitch.addTarget(self, action: #selector(pushTrainingSwitchChanged), for: .valueChanged)
        pushCategoryTogglesContainer.addArrangedSubview(trainingRow)

        let researchRow: UIView
        (researchRow, pushResearchSwitch) = createToggleRow(
            icon: "book.fill",
            title: "Research Updates",
            description: "Research completed"
        )
        pushResearchSwitch.addTarget(self, action: #selector(pushResearchSwitchChanged), for: .valueChanged)
        pushCategoryTogglesContainer.addArrangedSubview(researchRow)

        let resourceRow: UIView
        (resourceRow, pushResourceSwitch) = createToggleRow(
            icon: "cube.box.fill",
            title: "Resource Alerts",
            description: "Gathering, storage full, depleted"
        )
        pushResourceSwitch.addTarget(self, action: #selector(pushResourceSwitchChanged), for: .valueChanged)
        pushCategoryTogglesContainer.addArrangedSubview(resourceRow)
    }

    private func createSectionHeader(title: String) -> UIView {
        let label = UILabel()
        label.text = title.uppercased()
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.textColor = UIColor(white: 0.5, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func createToggleRow(icon: String, title: String, description: String) -> (UIView, UISwitch) {
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        // Description
        let descLabel = UILabel()
        descLabel.text = description
        descLabel.font = UIFont.systemFont(ofSize: 12)
        descLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descLabel)

        // Switch
        let toggle = UISwitch()
        toggle.onTintColor = UIColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1.0)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toggle)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 70),

            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        // Add separator at bottom (except last row)
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])

        return (container, toggle)
    }

    // MARK: - Settings Management

    private func loadSettings() {
        // Load push notification settings
        pushMasterSwitch.isOn = NotificationSettings.pushNotificationsEnabled
        pushCombatSwitch.isOn = NotificationSettings.pushCombatAlertsEnabled
        pushEnemySightingsSwitch.isOn = NotificationSettings.pushEnemySightingsEnabled
        pushBuildingSwitch.isOn = NotificationSettings.pushBuildingUpdatesEnabled
        pushTrainingSwitch.isOn = NotificationSettings.pushTrainingUpdatesEnabled
        pushResearchSwitch.isOn = NotificationSettings.pushResearchUpdatesEnabled
        pushResourceSwitch.isOn = NotificationSettings.pushResourceAlertsEnabled

        // Update category toggles enabled state based on master toggle
        updateCategoryTogglesState()
    }

    private func updateCategoryTogglesState() {
        let enabled = pushMasterSwitch.isOn
        pushCategoryTogglesContainer.alpha = enabled ? 1.0 : 0.5
        pushCategoryTogglesContainer.isUserInteractionEnabled = enabled
    }

    // MARK: - Push Notification Switch Actions

    @objc private func pushMasterSwitchChanged(_ sender: UISwitch) {
        NotificationSettings.pushNotificationsEnabled = sender.isOn
        updateCategoryTogglesState()
    }

    @objc private func pushCombatSwitchChanged(_ sender: UISwitch) {
        NotificationSettings.pushCombatAlertsEnabled = sender.isOn
    }

    @objc private func pushEnemySightingsSwitchChanged(_ sender: UISwitch) {
        NotificationSettings.pushEnemySightingsEnabled = sender.isOn
    }

    @objc private func pushBuildingSwitchChanged(_ sender: UISwitch) {
        NotificationSettings.pushBuildingUpdatesEnabled = sender.isOn
    }

    @objc private func pushTrainingSwitchChanged(_ sender: UISwitch) {
        NotificationSettings.pushTrainingUpdatesEnabled = sender.isOn
    }

    @objc private func pushResearchSwitchChanged(_ sender: UISwitch) {
        NotificationSettings.pushResearchUpdatesEnabled = sender.isOn
    }

    @objc private func pushResourceSwitchChanged(_ sender: UISwitch) {
        NotificationSettings.pushResourceAlertsEnabled = sender.isOn
    }

    // MARK: - Navigation

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
