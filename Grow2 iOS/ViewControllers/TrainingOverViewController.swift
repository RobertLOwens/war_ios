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

        // Header: buildingLabel + locationLabel + statusLabel + padding = ~70
        // Each queue item: unitLabel + progressBar + timeLabel + padding = ~60
        // Stack spacing: 8 per item
        let headerHeight: CGFloat = 80
        let itemHeight: CGFloat = 60
        let stackSpacing: CGFloat = 8

        if queueCount > 0 {
            return headerHeight + CGFloat(queueCount) * (itemHeight + stackSpacing)
        }
        return headerHeight
    }
    
    @objc func closeScreen() {
        dismiss(animated: true)
    }
}

class TrainingBuildingCell: UITableViewCell {

    let buildingLabel = UILabel()
    let locationLabel = UILabel()
    let statusLabel = UILabel()
    let queueStackView = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        queueStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        buildingLabel.translatesAutoresizingMaskIntoConstraints = false
        buildingLabel.font = UIFont.boldSystemFont(ofSize: 18)
        buildingLabel.textColor = .white
        contentView.addSubview(buildingLabel)

        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        locationLabel.font = UIFont.systemFont(ofSize: 13)
        locationLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        contentView.addSubview(locationLabel)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        contentView.addSubview(statusLabel)

        queueStackView.translatesAutoresizingMaskIntoConstraints = false
        queueStackView.axis = .vertical
        queueStackView.spacing = 8
        contentView.addSubview(queueStackView)

        NSLayoutConstraint.activate([
            buildingLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            buildingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            buildingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            locationLabel.topAnchor.constraint(equalTo: buildingLabel.bottomAnchor, constant: 4),
            locationLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            locationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            statusLabel.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            queueStackView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            queueStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            queueStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            queueStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    // MARK: - Time Calculation Helpers

    func getRemainingTime(for entry: TrainingQueueEntryData, currentTime: TimeInterval) -> TimeInterval {
        let baseTime = entry.unitType.trainingTime * Double(entry.quantity)
        let elapsed = currentTime - entry.startTime
        return max(0, baseTime - elapsed)
    }

    func getRemainingTime(for entry: VillagerTrainingEntryData, currentTime: TimeInterval) -> TimeInterval {
        let totalTime = VillagerTrainingEntryData.trainingTimePerVillager * Double(entry.quantity)
        let elapsed = currentTime - entry.startTime
        return max(0, totalTime - elapsed)
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }

    func calculateTotalRemaining(_ building: BuildingNode, currentTime: TimeInterval) -> TimeInterval {
        var total: TimeInterval = 0
        for entry in building.trainingQueue {
            total += getRemainingTime(for: entry, currentTime: currentTime)
        }
        for entry in building.villagerTrainingQueue {
            total += getRemainingTime(for: entry, currentTime: currentTime)
        }
        return total
    }

    // MARK: - Progress Bar Creation

    func createProgressBar(progress: Double, width: CGFloat) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        container.layer.cornerRadius = 3
        container.clipsToBounds = true

        let fill = UIView()
        fill.backgroundColor = progress > 0.75 ? .systemGreen : (progress > 0.4 ? .systemYellow : .systemOrange)
        fill.layer.cornerRadius = 3
        fill.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(fill)

        NSLayoutConstraint.activate([
            fill.topAnchor.constraint(equalTo: container.topAnchor),
            fill.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            fill.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            fill.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: max(0.02, min(1.0, progress)))
        ])

        return container
    }

    // MARK: - Queue Item View

    func addQueueItemView(index: Int, icon: String, name: String, quantity: Int, progress: Double, remainingTime: TimeInterval) {
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        container.layer.cornerRadius = 6

        // Unit info label
        let unitLabel = UILabel()
        unitLabel.translatesAutoresizingMaskIntoConstraints = false
        unitLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        unitLabel.textColor = .white
        unitLabel.text = "\(index). \(quantity)x \(icon) \(name)"
        container.addSubview(unitLabel)

        // Progress bar
        let progressBar = createProgressBar(progress: progress, width: 200)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(progressBar)

        // Time/percentage label
        let timeLabel = UILabel()
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        let percentText = Int(progress * 100)
        timeLabel.text = "\(formatTime(remainingTime)) remaining (\(percentText)%)"
        container.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            unitLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            unitLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            unitLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),

            progressBar.topAnchor.constraint(equalTo: unitLabel.bottomAnchor, constant: 6),
            progressBar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            progressBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            progressBar.heightAnchor.constraint(equalToConstant: 6),

            timeLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            timeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            timeLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        queueStackView.addArrangedSubview(container)
    }

    // MARK: - Configure

    func configure(with building: BuildingNode?) {
        queueStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let building = building else {
            buildingLabel.text = "No Training Buildings"
            locationLabel.text = "Build barracks, archery ranges, or city centers to train units"
            statusLabel.text = ""
            return
        }

        buildingLabel.text = "\(building.buildingType.icon) \(building.buildingType.displayName)"
        locationLabel.text = "Location: (\(building.coordinate.q), \(building.coordinate.r))"

        let currentTime = Date().timeIntervalSince1970

        // Process military queue
        for (index, entry) in building.trainingQueue.enumerated() {
            let progress = entry.getProgress(currentTime: currentTime)
            let remaining = getRemainingTime(for: entry, currentTime: currentTime)
            addQueueItemView(
                index: index + 1,
                icon: entry.unitType.icon,
                name: entry.unitType.displayName,
                quantity: entry.quantity,
                progress: progress,
                remainingTime: remaining
            )
        }

        // Process villager queue
        for (index, entry) in building.villagerTrainingQueue.enumerated() {
            let progress = entry.getProgress(currentTime: currentTime)
            let remaining = getRemainingTime(for: entry, currentTime: currentTime)
            addQueueItemView(
                index: building.trainingQueue.count + index + 1,
                icon: "👷",
                name: "Villager",
                quantity: entry.quantity,
                progress: progress,
                remainingTime: remaining
            )
        }

        // Update status
        if building.trainingQueue.isEmpty && building.villagerTrainingQueue.isEmpty {
            statusLabel.text = "✅ Ready to train"
            statusLabel.textColor = .systemGreen
        } else {
            let totalRemaining = calculateTotalRemaining(building, currentTime: currentTime)
            statusLabel.text = "⏳ \(formatTime(totalRemaining)) remaining"
            statusLabel.textColor = .systemYellow
        }
    }
}
