// ============================================================================
// FILE: BuildingsOverviewViewController.swift
// LOCATION: Create as NEW FILE in Grow2 iOS/ViewControllers/
// ============================================================================

import UIKit

class BuildingsOverviewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var player: Player?
    var hexMap: HexMap?
    var gameScene: GameScene?
    var tableView: UITableView!
    var closeButton: UIButton!
    var segmentedControl: UISegmentedControl!
    var updateTimer: Timer?
    var playerBuildings: [BuildingNode] = []
    var filteredBuildings: [BuildingNode] = []
    var gameViewController: GameViewController?
    var selectedCategory: Int = 0  // 0 = Economic, 1 = Military


    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadBuildingsData()

        // Update every second for timers
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
        titleLabel.text = "Buildings Overview"
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
        segmentedControl = UISegmentedControl(items: ["🏠 Economic", "⚔️ Military"])
        segmentedControl.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 36)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        segmentedControl.selectedSegmentTintColor = UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1.0)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)
        view.addSubview(segmentedControl)

        // Table view
        tableView = UITableView(frame: CGRect(x: 0, y: 145, width: view.bounds.width, height: view.bounds.height - 145), style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        tableView.separatorColor = UIColor(white: 0.3, alpha: 1.0)
        tableView.register(BuildingOverviewCell.self, forCellReuseIdentifier: "BuildingOverviewCell")
        view.addSubview(tableView)
    }

    @objc func categoryChanged() {
        selectedCategory = segmentedControl.selectedSegmentIndex
        filterBuildings()
        tableView.reloadData()
    }

    func loadBuildingsData() {
        guard let hexMap = hexMap, let player = player else { return }

        // Filter out roads and only include player's buildings
        playerBuildings = hexMap.buildings.filter { building in
            building.owner?.id == player.id && !building.buildingType.isRoad
        }.sorted { b1, b2 in
            // Sort: upgrading first, then constructing, then by type
            if b1.state == .upgrading && b2.state != .upgrading { return true }
            if b2.state == .upgrading && b1.state != .upgrading { return false }
            if b1.state == .constructing && b2.state != .constructing { return true }
            if b2.state == .constructing && b1.state != .constructing { return false }
            return b1.buildingType.displayName < b2.buildingType.displayName
        }

        filterBuildings()
        tableView.reloadData()
    }

    func filterBuildings() {
        let targetCategory: BuildingCategory = selectedCategory == 0 ? .economic : .military
        filteredBuildings = playerBuildings.filter { $0.buildingType.category == targetCategory }
    }
    
    // MARK: - TableView DataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if filteredBuildings.isEmpty {
            return 1  // Show "no buildings" message
        }
        return filteredBuildings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BuildingOverviewCell", for: indexPath) as? BuildingOverviewCell else {
            return UITableViewCell()
        }

        if filteredBuildings.isEmpty {
            let categoryName = selectedCategory == 0 ? "economic" : "military"
            cell.configureEmpty(category: categoryName)
        } else {
            let building = filteredBuildings[indexPath.row]
            cell.configure(with: building, player: player, hexMap: hexMap)
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if filteredBuildings.isEmpty {
            return 100
        }
        return 100  // Increased height for HP bar
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard !filteredBuildings.isEmpty else { return }

        let building = filteredBuildings[indexPath.row]
        debugLog("Selected building: \(building.buildingType.displayName) at (\(building.coordinate.q), \(building.coordinate.r))")

        // Open BuildingDetailViewController
        let detailVC = BuildingDetailViewController()
        detailVC.building = building
        detailVC.player = player
        detailVC.hexMap = hexMap
        detailVC.gameScene = gameScene
        detailVC.gameViewController = gameViewController
        detailVC.modalPresentationStyle = .fullScreen

        present(detailVC, animated: true)
    }

    @objc func closeScreen() {
        dismiss(animated: true)
    }
}

// MARK: - Building Overview Cell

class BuildingOverviewCell: UITableViewCell {

    let buildingLabel = UILabel()
    let levelLabel = UILabel()
    let locationLabel = UILabel()
    let statusLabel = UILabel()
    let hpLabel = UILabel()
    let progressBar = UIView()
    let progressFill = UIView()
    let hpBar = UIView()
    let hpFill = UIView()

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

        // Building name
        buildingLabel.frame = CGRect(x: 15, y: 8, width: 200, height: 22)
        buildingLabel.font = UIFont.boldSystemFont(ofSize: 16)
        buildingLabel.textColor = .white
        contentView.addSubview(buildingLabel)

        // Level label
        levelLabel.frame = CGRect(x: 220, y: 8, width: 100, height: 22)
        levelLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        levelLabel.textColor = .yellow
        levelLabel.textAlignment = .right
        contentView.addSubview(levelLabel)

        // Location
        locationLabel.frame = CGRect(x: 15, y: 30, width: 150, height: 16)
        locationLabel.font = UIFont.systemFont(ofSize: 12)
        locationLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        contentView.addSubview(locationLabel)

        // HP label
        hpLabel.frame = CGRect(x: 170, y: 30, width: 150, height: 16)
        hpLabel.font = UIFont.systemFont(ofSize: 12)
        hpLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        hpLabel.textAlignment = .right
        contentView.addSubview(hpLabel)

        // HP bar background
        hpBar.frame = CGRect(x: 15, y: 48, width: 305, height: 6)
        hpBar.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        hpBar.layer.cornerRadius = 3
        contentView.addSubview(hpBar)

        // HP bar fill
        hpFill.frame = CGRect(x: 0, y: 0, width: 305, height: 6)
        hpFill.backgroundColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        hpFill.layer.cornerRadius = 3
        hpBar.addSubview(hpFill)

        // Status
        statusLabel.frame = CGRect(x: 15, y: 58, width: 350, height: 18)
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        contentView.addSubview(statusLabel)

        // Progress bar background
        progressBar.frame = CGRect(x: 15, y: 78, width: 305, height: 10)
        progressBar.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        progressBar.layer.cornerRadius = 5
        progressBar.isHidden = true
        contentView.addSubview(progressBar)

        // Progress bar fill
        progressFill.frame = CGRect(x: 0, y: 0, width: 0, height: 10)
        progressFill.layer.cornerRadius = 5
        progressBar.addSubview(progressFill)
    }

    func configure(with building: BuildingNode, player: Player?, hexMap: HexMap? = nil) {
        buildingLabel.text = "\(building.buildingType.icon) \(building.buildingType.displayName)"
        levelLabel.text = "Lv.\(building.level)"
        locationLabel.text = "(\(building.coordinate.q), \(building.coordinate.r))"

        // HP display
        let currentHP = Int(building.health)
        let maxHP = Int(building.maxHealth)
        let hpPercent = maxHP > 0 ? CGFloat(building.health / building.maxHealth) : 1.0
        hpLabel.text = "❤️ \(currentHP)/\(maxHP)"
        hpFill.frame.size.width = 305 * hpPercent

        // HP bar color based on percentage
        if hpPercent > 0.6 {
            hpFill.backgroundColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        } else if hpPercent > 0.3 {
            hpFill.backgroundColor = UIColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
        } else {
            hpFill.backgroundColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        }

        let currentTime = Date().timeIntervalSince1970

        switch building.state {
        case .planning:
            statusLabel.text = "📋 Planning"
            statusLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
            progressBar.isHidden = true

        case .constructing:
            let progress = Int(building.constructionProgress * 100)
            var statusText = "🔨 Constructing: \(progress)%"

            if let startTime = building.constructionStartTime {
                let elapsed = currentTime - startTime
                let remaining = max(0, building.buildingType.buildTime - elapsed)
                let mins = Int(remaining) / 60
                let secs = Int(remaining) % 60
                statusText += " (\(mins)m \(secs)s)"
            }

            statusLabel.text = statusText
            statusLabel.textColor = .orange
            progressBar.isHidden = false
            progressFill.backgroundColor = .orange
            progressFill.frame.size.width = 305 * CGFloat(building.constructionProgress)

        case .completed:
            if building.canUpgrade {
                // Check if player can afford the upgrade (with terrain multiplier)
                var canAfford = true
                if let upgradeCost = building.getUpgradeCost(), let player = player {
                    let occupiedCoords = building.data.occupiedCoordinates
                    let hasMountain = occupiedCoords.contains { hexMap?.getTile(at: $0)?.terrain == .mountain }
                    let terrainMultiplier = hasMountain ? GameConfig.Terrain.mountainBuildingCostMultiplier : 1.0
                    for (resourceType, baseAmount) in upgradeCost {
                        let adjustedAmount = Int(ceil(Double(baseAmount) * terrainMultiplier))
                        if !player.hasResource(resourceType, amount: adjustedAmount) {
                            canAfford = false
                            break
                        }
                    }
                }

                if canAfford {
                    statusLabel.text = "✅ Can Upgrade"
                    statusLabel.textColor = UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)
                } else {
                    statusLabel.text = "💰 Upgrade (Need Resources)"
                    statusLabel.textColor = UIColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1.0)
                }
            } else {
                statusLabel.text = "✨ Max Level"
                statusLabel.textColor = UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
            }
            progressBar.isHidden = true

        case .upgrading:
            let progress = building.upgradeProgress
            let progressPercent = Int(progress * 100)
            var statusText = "⬆️ Upgrading to Lv.\(building.level + 1): \(progressPercent)%"

            if let startTime = building.upgradeStartTime,
               let upgradeTime = building.getUpgradeTime() {
                let elapsed = currentTime - startTime
                let remaining = max(0, upgradeTime - elapsed)
                let mins = Int(remaining) / 60
                let secs = Int(remaining) % 60
                statusText += " (\(mins)m \(secs)s)"
            }

            statusLabel.text = statusText
            statusLabel.textColor = .cyan
            progressBar.isHidden = false
            progressFill.backgroundColor = .cyan
            progressFill.frame.size.width = 305 * CGFloat(progress)

        case .damaged:
            statusLabel.text = "⚠️ Damaged"
            statusLabel.textColor = .red
            progressBar.isHidden = true

        case .destroyed:
            statusLabel.text = "❌ Destroyed"
            statusLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            progressBar.isHidden = true

        case .demolishing:
            let progress = building.demolitionProgress
            let progressPercent = Int(progress * 100)
            statusLabel.text = "🏚️ Demolishing: \(progressPercent)%"
            statusLabel.textColor = .orange
            progressBar.isHidden = false
            progressFill.backgroundColor = .orange
            progressFill.frame.size.width = 305 * CGFloat(progress)
        }
    }

    func configureEmpty(category: String = "economic") {
        buildingLabel.text = "No \(category.capitalized) Buildings"
        levelLabel.text = ""
        locationLabel.text = "Build structures to see them here"
        hpLabel.text = ""
        hpBar.isHidden = true
        statusLabel.text = ""
        progressBar.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hpBar.isHidden = false
        progressBar.isHidden = true
    }
}
