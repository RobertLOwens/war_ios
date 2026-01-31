// ============================================================================
// FILE: EntitiesOverviewViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/
// PURPOSE: Shows overview of all player entities (villager groups and armies)
// ============================================================================

import UIKit

class EntitiesOverviewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var player: Player?
    var hexMap: HexMap?
    var gameScene: GameScene?
    var tableView: UITableView!
    var closeButton: UIButton!
    var segmentedControl: UISegmentedControl!
    var capacityLabel: UILabel!
    var updateTimer: Timer?
    var gameViewController: GameViewController?
    var selectedCategory: Int = 0  // 0 = Economic (villagers), 1 = Military (armies)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        // Update every second for timers
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCapacityLabel()
            self?.tableView.reloadData()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)

        // Title
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 50, width: view.bounds.width - 40, height: 40))
        titleLabel.text = "Entities Overview"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)

        // Close button
        closeButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 50, width: 50, height: 40))
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        closeButton.addTarget(self, action: #selector(closeScreen), for: .touchUpInside)
        view.addSubview(closeButton)

        // Segmented control for Economic/Military tabs
        segmentedControl = UISegmentedControl(items: ["👷 Economic", "🛡️ Military"])
        segmentedControl.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 36)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        segmentedControl.selectedSegmentTintColor = UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1.0)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)
        view.addSubview(segmentedControl)

        // Capacity label
        capacityLabel = UILabel(frame: CGRect(x: 20, y: 145, width: view.bounds.width - 40, height: 25))
        capacityLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        capacityLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        capacityLabel.textAlignment = .center
        view.addSubview(capacityLabel)
        updateCapacityLabel()

        // Table view
        tableView = UITableView(frame: CGRect(x: 0, y: 175, width: view.bounds.width, height: view.bounds.height - 175), style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        tableView.separatorColor = UIColor(white: 0.3, alpha: 1.0)
        tableView.register(EntityOverviewCell.self, forCellReuseIdentifier: "EntityOverviewCell")
        view.addSubview(tableView)
    }

    @objc func categoryChanged() {
        selectedCategory = segmentedControl.selectedSegmentIndex
        updateCapacityLabel()
        tableView.reloadData()
    }

    func updateCapacityLabel() {
        guard let player = player else { return }

        if selectedCategory == 0 {
            let current = player.getVillagerGroups().count
            let max = player.getMaxVillagerGroups()
            capacityLabel.text = "Villager Groups: \(current)/\(max)"
            capacityLabel.textColor = current >= max ? .systemOrange : UIColor(white: 0.7, alpha: 1.0)
        } else {
            let current = player.getArmies().count
            let max = player.getMaxArmies()
            capacityLabel.text = "Armies: \(current)/\(max)"
            capacityLabel.textColor = current >= max ? .systemOrange : UIColor(white: 0.7, alpha: 1.0)
        }
    }

    // MARK: - TableView DataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let player = player else { return 0 }

        if selectedCategory == 0 {
            let count = player.getVillagerGroups().count
            return count > 0 ? count : 1
        } else {
            let count = player.getArmies().count
            return count > 0 ? count : 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EntityOverviewCell", for: indexPath) as! EntityOverviewCell

        guard let player = player else { return cell }

        if selectedCategory == 0 {
            let villagerGroups = player.getVillagerGroups()
            if villagerGroups.isEmpty {
                cell.configureEmpty(category: "villager groups")
            } else {
                let group = villagerGroups[indexPath.row]
                cell.configure(with: group, hexMap: hexMap)
            }
        } else {
            let armies = player.getArmies()
            if armies.isEmpty {
                cell.configureEmpty(category: "armies")
            } else {
                let army = armies[indexPath.row]
                cell.configure(with: army)
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let player = player else { return }

        let coordinate: HexCoordinate

        if selectedCategory == 0 {
            // Economic (villagers)
            let villagerGroups = player.getVillagerGroups()
            guard !villagerGroups.isEmpty else { return }
            coordinate = villagerGroups[indexPath.row].coordinate
        } else {
            // Military (armies)
            let armies = player.getArmies()
            guard !armies.isEmpty else { return }
            coordinate = armies[indexPath.row].coordinate
        }

        // Dismiss and focus on entity
        dismiss(animated: true) { [weak self] in
            self?.gameViewController?.focusOnCoordinate(coordinate, zoomIn: true)
        }
    }

    @objc func closeScreen() {
        dismiss(animated: true)
    }
}

// MARK: - Entity Overview Cell

class EntityOverviewCell: UITableViewCell {

    let nameLabel = UILabel()
    let countLabel = UILabel()
    let locationLabel = UILabel()
    let taskLabel = UILabel()
    let timerLabel = UILabel()

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

        // Entity name
        nameLabel.frame = CGRect(x: 15, y: 8, width: 200, height: 22)
        nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        nameLabel.textColor = .white
        contentView.addSubview(nameLabel)

        // Count label
        countLabel.frame = CGRect(x: 220, y: 8, width: 100, height: 22)
        countLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        countLabel.textColor = .yellow
        countLabel.textAlignment = .right
        contentView.addSubview(countLabel)

        // Location
        locationLabel.frame = CGRect(x: 15, y: 32, width: 305, height: 16)
        locationLabel.font = UIFont.systemFont(ofSize: 12)
        locationLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        contentView.addSubview(locationLabel)

        // Task
        taskLabel.frame = CGRect(x: 15, y: 52, width: 220, height: 18)
        taskLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        taskLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        contentView.addSubview(taskLabel)

        // Timer
        timerLabel.frame = CGRect(x: 240, y: 52, width: 80, height: 18)
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        timerLabel.textColor = .cyan
        timerLabel.textAlignment = .right
        contentView.addSubview(timerLabel)
    }

    func configure(with villagerGroup: VillagerGroup, hexMap: HexMap?) {
        nameLabel.text = "👷 \(villagerGroup.name)"
        countLabel.text = "\(villagerGroup.villagerCount) villagers"
        locationLabel.text = "📍 (\(villagerGroup.coordinate.q), \(villagerGroup.coordinate.r))"

        let currentTime = Date().timeIntervalSince1970

        // Task display
        switch villagerGroup.currentTask {
        case .idle:
            taskLabel.text = "💤 Idle"
            taskLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            timerLabel.text = ""

        case .moving(let coord):
            taskLabel.text = "🚶 Moving to (\(coord.q), \(coord.r))"
            taskLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
            timerLabel.text = ""

        case .building(let building):
            taskLabel.text = "🔨 Building \(building.buildingType.displayName)"
            taskLabel.textColor = .orange

            if let startTime = building.constructionStartTime {
                let elapsed = currentTime - startTime
                let remaining = max(0, building.buildingType.buildTime - elapsed)
                timerLabel.text = formatTime(remaining)
            } else {
                timerLabel.text = ""
            }

        case .upgrading(let building):
            taskLabel.text = "⬆️ Upgrading \(building.buildingType.displayName)"
            taskLabel.textColor = .cyan

            if let startTime = building.upgradeStartTime,
               let upgradeTime = building.getUpgradeTime() {
                let elapsed = currentTime - startTime
                let remaining = max(0, upgradeTime - elapsed)
                timerLabel.text = formatTime(remaining)
            } else {
                timerLabel.text = ""
            }

        case .demolishing(let building):
            taskLabel.text = "🏚️ Demolishing \(building.buildingType.displayName)"
            taskLabel.textColor = UIColor(red: 0.8, green: 0.4, blue: 0.4, alpha: 1.0)

            if let startTime = building.demolitionStartTime {
                let demolishTime = building.data.getDemolitionTime()
                let elapsed = currentTime - startTime
                let remaining = max(0, demolishTime - elapsed)
                timerLabel.text = formatTime(remaining)
            } else {
                timerLabel.text = ""
            }

        case .gathering(let resourceType):
            taskLabel.text = "⛏️ Gathering \(resourceType.displayName)"
            taskLabel.textColor = UIColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
            timerLabel.text = "In Progress"
            timerLabel.textColor = UIColor(white: 0.6, alpha: 1.0)

        case .gatheringResource(let resourcePoint):
            taskLabel.text = "⛏️ Gathering \(resourcePoint.resourceType.displayName)"
            taskLabel.textColor = UIColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
            timerLabel.text = "In Progress"
            timerLabel.textColor = UIColor(white: 0.6, alpha: 1.0)

        case .hunting(let resourcePoint):
            taskLabel.text = "🏹 Hunting \(resourcePoint.resourceType.displayName)"
            taskLabel.textColor = UIColor(red: 0.9, green: 0.6, blue: 0.3, alpha: 1.0)
            timerLabel.text = "In Progress"
            timerLabel.textColor = UIColor(white: 0.6, alpha: 1.0)

        case .repairing(let building):
            taskLabel.text = "🔧 Repairing \(building.buildingType.displayName)"
            taskLabel.textColor = UIColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1.0)
            timerLabel.text = "In Progress"
            timerLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        }
    }

    func configure(with army: Army) {
        let commanderName = army.commander?.name ?? "No Commander"
        nameLabel.text = "🛡️ \(army.name)"
        countLabel.text = "\(army.getTotalMilitaryUnits()) units"

        // Show stamina if commander exists
        if let commander = army.commander {
            let staminaText = "⚡\(Int(commander.stamina))/\(Int(Commander.maxStamina))"
            locationLabel.text = "📍 (\(army.coordinate.q), \(army.coordinate.r)) • 👤 \(commanderName) • \(staminaText)"
        } else {
            locationLabel.text = "📍 (\(army.coordinate.q), \(army.coordinate.r)) • 👤 \(commanderName)"
        }

        // Check if army is in combat
        if GameEngine.shared.combatEngine.isInCombat(armyID: army.id) {
            taskLabel.text = "⚔️ In Combat"
            taskLabel.textColor = .systemRed
            timerLabel.text = ""
        } else {
            taskLabel.text = "⚔️ Ready for combat"
            taskLabel.textColor = UIColor(red: 0.8, green: 0.6, blue: 0.3, alpha: 1.0)
            timerLabel.text = ""
        }
    }

    func configureEmpty(category: String) {
        nameLabel.text = "No \(category.capitalized)"
        countLabel.text = ""
        locationLabel.text = "Deploy units to see them here"
        taskLabel.text = ""
        timerLabel.text = ""
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        timerLabel.textColor = .cyan
    }
}
