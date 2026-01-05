// ============================================================================
// FILE: Create new file "Grow2 iOS/TrainingOverviewViewController.swift"
// ============================================================================

import UIKit

class TrainingOverviewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var player: Player?
    var hexMap: HexMap?
    var tableView: UITableView!
    var closeButton: UIButton!
    var updateTimer: Timer?
    var buildingsWithTraining: [BuildingNode] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadTrainingData()
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
        titleLabel.text = "🎓 Training Overview"
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
        tableView.register(TrainingBuildingCell.self, forCellReuseIdentifier: "TrainingBuildingCell")
        view.addSubview(tableView)
    }
    
    func loadTrainingData() {
        guard let hexMap = hexMap, let player = player else { return }
        
        buildingsWithTraining = hexMap.buildings.filter { building in
            building.owner?.id == player.id &&
            building.state == .completed &&
            (!building.trainingQueue.isEmpty || !building.villagerTrainingQueue.isEmpty || building.canTrainVillagers() || building.canTrain(.swordsman) || building.canTrain(.archer) || building.canTrain(.knight))
        }
        
        tableView.reloadData()
    }
    
    // MARK: - TableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if buildingsWithTraining.isEmpty {
            return 1 // Show "no training" message
        }
        return buildingsWithTraining.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrainingBuildingCell", for: indexPath) as! TrainingBuildingCell
        
        if buildingsWithTraining.isEmpty {
            cell.configure(with: nil)
        } else {
            let building = buildingsWithTraining[indexPath.row]
            cell.configure(with: building)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if buildingsWithTraining.isEmpty {
            return 100
        }
        
        let building = buildingsWithTraining[indexPath.row]
        let queueCount = building.trainingQueue.count + building.villagerTrainingQueue.count
        
        if queueCount > 0 {
            return 80 + CGFloat(queueCount * 25) // Base height + queue items
        }
        return 80
    }
    
    @objc func closeScreen() {
        dismiss(animated: true)
    }
}

class TrainingBuildingCell: UITableViewCell {
    
    let buildingLabel = UILabel()
    let locationLabel = UILabel()
    let queueLabel = UILabel()
    let statusLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        buildingLabel.frame = CGRect(x: 15, y: 10, width: 300, height: 22)
        buildingLabel.font = UIFont.boldSystemFont(ofSize: 16)
        buildingLabel.textColor = .white
        contentView.addSubview(buildingLabel)
        
        locationLabel.frame = CGRect(x: 15, y: 32, width: 350, height: 18)
        locationLabel.font = UIFont.systemFont(ofSize: 13)
        locationLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        contentView.addSubview(locationLabel)
        
        statusLabel.frame = CGRect(x: 15, y: 52, width: 350, height: 18)
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        contentView.addSubview(statusLabel)
        
        queueLabel.frame = CGRect(x: 15, y: 70, width: 350, height: 200)
        queueLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        queueLabel.textColor = UIColor(white: 0.75, alpha: 1.0)
        queueLabel.numberOfLines = 0
        contentView.addSubview(queueLabel)
    }
    
    func configure(with building: BuildingNode?) {
        guard let building = building else {
            buildingLabel.text = "No Training Buildings"
            locationLabel.text = "Build barracks, archery ranges, or city centers to train units"
            statusLabel.text = ""
            queueLabel.text = ""
            return
        }
        
        buildingLabel.text = "\(building.buildingType.icon) \(building.buildingType.displayName)"
        locationLabel.text = "📍 Location: (\(building.coordinate.q), \(building.coordinate.r))"
        
        let currentTime = Date().timeIntervalSince1970
        let militaryQueue = building.trainingQueue
        let villagerQueue = building.villagerTrainingQueue
        
        if militaryQueue.isEmpty && villagerQueue.isEmpty {
            statusLabel.text = "✅ Idle - Ready to train"
            queueLabel.text = ""
        } else {
            var totalRemaining: TimeInterval = 0
            var queueText = ""
            
            for (index, entry) in militaryQueue.enumerated() {
                let remaining = entry.getTimeRemaining(currentTime: currentTime)
                totalRemaining += remaining
                let minutes = Int(remaining) / 60
                let seconds = Int(remaining) % 60
                let progress = Int(entry.getProgress(currentTime: currentTime) * 100)
                queueText += "\n\(index + 1). \(entry.quantity)x \(entry.unitType.icon) \(entry.unitType.displayName) - \(minutes)m \(seconds)s (\(progress)%)"
            }
            
            for (index, entry) in villagerQueue.enumerated() {
                let remaining = entry.getTimeRemaining(currentTime: currentTime)
                totalRemaining += remaining
                let minutes = Int(remaining) / 60
                let seconds = Int(remaining) % 60
                let progress = Int(entry.getProgress(currentTime: currentTime) * 100)
                queueText += "\n\(militaryQueue.count + index + 1). \(entry.quantity)x 👷 Villager - \(minutes)m \(seconds)s (\(progress)%)"
            }
            
            let totalMinutes = Int(totalRemaining) / 60
            let totalSeconds = Int(totalRemaining) % 60
            statusLabel.text = "🔨 Training - Total: \(totalMinutes)m \(totalSeconds)s"
            queueLabel.text = queueText
        }
    }
}
