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
    var updateTimer: Timer?
    var playerBuildings: [BuildingNode] = []
    var gameViewController: GameViewController?

    
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
        titleLabel.text = "🏛️ Buildings Overview"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)
        
        // Close button
        closeButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 50, width: 50, height: 40))
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        closeButton.addTarget(self, action: #selector(closeScreen), for: .touchUpInside)
        view.addSubview(closeButton)
        
        // Table view
        tableView = UITableView(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: view.bounds.height - 100), style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        tableView.separatorColor = UIColor(white: 0.3, alpha: 1.0)
        tableView.register(BuildingOverviewCell.self, forCellReuseIdentifier: "BuildingOverviewCell")
        view.addSubview(tableView)
    }
    
    func loadBuildingsData() {
        guard let hexMap = hexMap, let player = player else { return }
        
        playerBuildings = hexMap.buildings.filter { building in
            building.owner?.id == player.id
        }.sorted { b1, b2 in
            // Sort: upgrading first, then constructing, then by type
            if b1.state == .upgrading && b2.state != .upgrading { return true }
            if b2.state == .upgrading && b1.state != .upgrading { return false }
            if b1.state == .constructing && b2.state != .constructing { return true }
            if b2.state == .constructing && b1.state != .constructing { return false }
            return b1.buildingType.displayName < b2.buildingType.displayName
        }
        
        tableView.reloadData()
    }
    
    // MARK: - TableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if playerBuildings.isEmpty {
            return 1  // Show "no buildings" message
        }
        return playerBuildings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BuildingOverviewCell", for: indexPath) as! BuildingOverviewCell
        
        if playerBuildings.isEmpty {
            cell.configureEmpty()
        } else {
            let building = playerBuildings[indexPath.row]
            cell.configure(with: building)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if playerBuildings.isEmpty {
            return 100
        }
        return 90
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard !playerBuildings.isEmpty else { return }
        
        let building = playerBuildings[indexPath.row]
        print("Selected building: \(building.buildingType.displayName) at (\(building.coordinate.q), \(building.coordinate.r))")
        
        // Open BuildingDetailViewController
        let detailVC = BuildingDetailViewController()
        detailVC.building = building
        detailVC.player = player
        detailVC.hexMap = hexMap
        detailVC.gameScene = gameScene
        detailVC.gameViewController = gameViewController  // ✅ Pass through
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
    let progressBar = UIView()
    let progressFill = UIView()
    
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
        buildingLabel.frame = CGRect(x: 15, y: 10, width: 200, height: 22)
        buildingLabel.font = UIFont.boldSystemFont(ofSize: 16)
        buildingLabel.textColor = .white
        contentView.addSubview(buildingLabel)
        
        // Level label
        levelLabel.frame = CGRect(x: 220, y: 10, width: 100, height: 22)
        levelLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        levelLabel.textColor = .yellow
        levelLabel.textAlignment = .right
        contentView.addSubview(levelLabel)
        
        // Location
        locationLabel.frame = CGRect(x: 15, y: 32, width: 300, height: 18)
        locationLabel.font = UIFont.systemFont(ofSize: 13)
        locationLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        contentView.addSubview(locationLabel)
        
        // Status
        statusLabel.frame = CGRect(x: 15, y: 52, width: 350, height: 18)
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        contentView.addSubview(statusLabel)
        
        // Progress bar background
        progressBar.frame = CGRect(x: 15, y: 72, width: 300, height: 10)
        progressBar.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        progressBar.layer.cornerRadius = 5
        progressBar.isHidden = true
        contentView.addSubview(progressBar)
        
        // Progress bar fill
        progressFill.frame = CGRect(x: 0, y: 0, width: 0, height: 10)
        progressFill.layer.cornerRadius = 5
        progressBar.addSubview(progressFill)
    }
    
    func configure(with building: BuildingNode) {
        buildingLabel.text = "\(building.buildingType.icon) \(building.buildingType.displayName)"
        levelLabel.text = "⭐ Lv.\(building.level)"
        locationLabel.text = "📍 (\(building.coordinate.q), \(building.coordinate.r))"
        
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
            progressFill.frame.size.width = 300 * CGFloat(building.constructionProgress)
            
        case .completed:
            if building.canUpgrade {
                statusLabel.text = "✅ Completed - Can Upgrade"
                statusLabel.textColor = UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)
            } else {
                statusLabel.text = "✅ Completed - Max Level"
                statusLabel.textColor = UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
            }
            progressBar.isHidden = true
            
        case .upgrading:
            let progress = Int(building.upgradeProgress * 100)
            var statusText = "⬆️ Upgrading to Lv.\(building.level + 1): \(progress)%"
            
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
            progressFill.frame.size.width = 300 * CGFloat(building.upgradeProgress)
            
        case .damaged:
            statusLabel.text = "⚠️ Damaged"
            statusLabel.textColor = .red
            progressBar.isHidden = true
            
        case .destroyed:
            statusLabel.text = "❌ Destroyed"
            statusLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            progressBar.isHidden = true
        }
    }
    
    func configureEmpty() {
        buildingLabel.text = "No Buildings"
        levelLabel.text = ""
        locationLabel.text = "Build structures to see them here"
        statusLabel.text = ""
        progressBar.isHidden = true
    }
}
