// ============================================================================
// FILE: ResearchViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/ResearchViewController.swift (new file)
// ============================================================================

import UIKit

class ResearchViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties
    
    weak var player: Player?
    
    // UI Elements
    private var tableView: UITableView!
    private var headerView: UIView!
    private var segmentedControl: UISegmentedControl!
    private var activeResearchView: UIView!
    private var activeResearchLabel: UILabel!
    private var activeProgressBar: UIView!
    private var activeProgressFill: UIView!
    private var activeTimeLabel: UILabel!
    private var cancelButton: UIButton!

    private var updateTimer: Timer?

    // Group research by category
    private var researchByCategory: [ResearchCategory: [ResearchType]] = [:]
    private var selectedCategory: ResearchCategory = .economic
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        organizeResearch()
        setupUI()
        
        // Start update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateActiveResearchDisplay()
            self?.tableView.reloadData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Setup
    
    private func organizeResearch() {
        researchByCategory.removeAll()

        for research in ResearchType.allCases {
            let category = research.category
            if researchByCategory[category] == nil {
                researchByCategory[category] = []
            }
            researchByCategory[category]?.append(research)
        }

        // Sort research within each category by tier, then by name
        for category in researchByCategory.keys {
            researchByCategory[category]?.sort { r1, r2 in
                if r1.tier != r2.tier {
                    return r1.tier < r2.tier
                }
                return r1.displayName < r2.displayName
            }
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        
        // Header
        headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 60))
        headerView.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        view.addSubview(headerView)
        
        // Title
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 15, width: 200, height: 30))
        titleLabel.text = "🔬 Research"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        headerView.addSubview(titleLabel)
        
        // Close button
        let closeButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 10, width: 50, height: 40))
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor(white: 0.3, alpha: 0.8)
        closeButton.layer.cornerRadius = 8
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerView.addSubview(closeButton)
        
        // Segmented Control for tabs
        setupSegmentedControl()

        // Active Research Panel
        setupActiveResearchPanel()

        // Table View
        let tableY = activeResearchView.frame.maxY + 10
        tableView = UITableView(frame: CGRect(x: 0, y: tableY, width: view.bounds.width, height: view.bounds.height - tableY), style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(ResearchCell.self, forCellReuseIdentifier: "ResearchCell")
        view.addSubview(tableView)
    }
    
    private func setupSegmentedControl() {
        let economicTitle = "\(ResearchCategory.economic.icon) Economic"
        let militaryTitle = "\(ResearchCategory.military.icon) Military"
        segmentedControl = UISegmentedControl(items: [economicTitle, militaryTitle])
        segmentedControl.frame = CGRect(x: 15, y: 70, width: view.bounds.width - 30, height: 36)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        segmentedControl.selectedSegmentTintColor = UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1.0)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        view.addSubview(segmentedControl)
    }

    @objc private func segmentChanged() {
        selectedCategory = segmentedControl.selectedSegmentIndex == 0 ? .economic : .military
        tableView.reloadData()
    }

    private func setupActiveResearchPanel() {
        activeResearchView = UIView(frame: CGRect(x: 15, y: 116, width: view.bounds.width - 30, height: 100))
        activeResearchView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        activeResearchView.layer.cornerRadius = 12
        view.addSubview(activeResearchView)
        
        // "Current Research" label
        let currentLabel = UILabel(frame: CGRect(x: 15, y: 10, width: 200, height: 20))
        currentLabel.text = "Current Research"
        currentLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        currentLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        activeResearchView.addSubview(currentLabel)
        
        // Active research name
        activeResearchLabel = UILabel(frame: CGRect(x: 15, y: 32, width: activeResearchView.bounds.width - 100, height: 25))
        activeResearchLabel.font = UIFont.boldSystemFont(ofSize: 18)
        activeResearchLabel.textColor = .white
        activeResearchLabel.text = "None"
        activeResearchView.addSubview(activeResearchLabel)
        
        // Progress bar background
        let progressBarBg = UIView(frame: CGRect(x: 15, y: 62, width: activeResearchView.bounds.width - 30, height: 12))
        progressBarBg.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        progressBarBg.layer.cornerRadius = 6
        activeResearchView.addSubview(progressBarBg)
        
        // Progress bar fill
        activeProgressFill = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 12))
        activeProgressFill.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1.0)
        activeProgressFill.layer.cornerRadius = 6
        progressBarBg.addSubview(activeProgressFill)
        
        activeProgressBar = progressBarBg
        
        // Time remaining label
        activeTimeLabel = UILabel(frame: CGRect(x: 15, y: 78, width: activeResearchView.bounds.width - 30, height: 18))
        activeTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        activeTimeLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        activeTimeLabel.textAlignment = .center
        activeResearchView.addSubview(activeTimeLabel)
        
        // Cancel button
        cancelButton = UIButton(frame: CGRect(x: activeResearchView.bounds.width - 80, y: 25, width: 65, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        cancelButton.backgroundColor = UIColor(red: 0.7, green: 0.3, blue: 0.3, alpha: 1.0)
        cancelButton.layer.cornerRadius = 6
        cancelButton.addTarget(self, action: #selector(cancelResearchTapped), for: .touchUpInside)
        activeResearchView.addSubview(cancelButton)
        
        updateActiveResearchDisplay()
    }
    
    // MARK: - Update Display
    
    private func updateActiveResearchDisplay() {
        let manager = ResearchManager.shared
        
        if let active = manager.activeResearch {
            let progress = active.getProgress()
            let remaining = active.getRemainingTime()
            
            activeResearchLabel.text = "\(active.researchType.icon) \(active.researchType.displayName)"
            
            // Update progress bar
            let maxWidth = activeProgressBar.bounds.width
            activeProgressFill.frame.size.width = maxWidth * CGFloat(progress)
            
            // Update time label
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            activeTimeLabel.text = String(format: "%d:%02d remaining", minutes, seconds)
            
            cancelButton.isHidden = false
        } else {
            activeResearchLabel.text = "No active research"
            activeProgressFill.frame.size.width = 0
            activeTimeLabel.text = "Select research below to begin"
            cancelButton.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func cancelResearchTapped() {
        let alert = UIAlertController(
            title: "Cancel Research?",
            message: "You will receive a 50% refund of resources.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel Research", style: .destructive) { [weak self] _ in
            if ResearchManager.shared.cancelResearch() {
                self?.updateActiveResearchDisplay()
                self?.tableView.reloadData()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Keep Researching", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func startResearch(_ researchType: ResearchType) {
        let manager = ResearchManager.shared

        // Check if already researching
        if manager.activeResearch != nil {
            showAlert(title: "Already Researching", message: "Complete or cancel current research first.")
            return
        }

        // Check if available (prerequisites and City Center level)
        if !manager.isAvailable(researchType) {
            if let reason = manager.getLockedReason(researchType) {
                showAlert(title: "Locked", message: reason)
            } else {
                showAlert(title: "Locked", message: "This research is not available yet.")
            }
            return
        }

        // Check resources
        if !manager.canAfford(researchType) {
            let missing = manager.getMissingResources(for: researchType)
            var message = "Missing resources:\n"
            for (type, amount) in missing {
                message += "\(type.icon) \(amount) \(type.displayName)\n"
            }
            showAlert(title: "Insufficient Resources", message: message)
            return
        }

        // Build confirmation message
        var confirmMessage = "\(researchType.icon) \(researchType.displayName)\n\n"
        confirmMessage += "Cost: \(researchType.costString)\n"
        confirmMessage += "Time: \(researchType.timeString)\n\n"
        confirmMessage += "Benefits:\n\(researchType.bonusString)"

        // Show prerequisites if any
        if !researchType.prerequisites.isEmpty {
            confirmMessage += "\n\nPrereqs: \(researchType.prerequisitesString)"
        }

        let alert = UIAlertController(
            title: "Start Research?",
            message: confirmMessage,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Research", style: .default) { [weak self] _ in
            if ResearchManager.shared.startResearch(researchType) {
                self?.updateActiveResearchDisplay()
                self?.tableView.reloadData()
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - TableView DataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return researchByCategory[selectedCategory]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ResearchCell", for: indexPath) as! ResearchCell

        if let research = researchByCategory[selectedCategory]?[indexPath.row] {
            cell.configure(with: research, player: player)
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    // MARK: - TableView Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let research = researchByCategory[selectedCategory]?[indexPath.row] {
            let manager = ResearchManager.shared

            if manager.isResearched(research) {
                showAlert(title: "Already Researched", message: "\(research.displayName) has already been completed.\n\n\(research.bonusString)")
            } else if manager.isResearching(research) {
                // Do nothing, already in progress
            } else {
                startResearch(research)
            }
        }
    }
}

// MARK: - Research Cell

class ResearchCell: UITableViewCell {
    
    private let containerView = UIView()
    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let costLabel = UILabel()
    private let timeLabel = UILabel()
    private let statusLabel = UILabel()
    private let bonusLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Container
        containerView.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        containerView.layer.cornerRadius = 10
        contentView.addSubview(containerView)
        
        // Icon
        iconLabel.font = UIFont.systemFont(ofSize: 28)
        iconLabel.textAlignment = .center
        containerView.addSubview(iconLabel)
        
        // Name
        nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        nameLabel.textColor = .white
        containerView.addSubview(nameLabel)
        
        // Bonus label
        bonusLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        bonusLabel.textColor = UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0)
        containerView.addSubview(bonusLabel)
        
        // Cost
        costLabel.font = UIFont.systemFont(ofSize: 13)
        costLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        containerView.addSubview(costLabel)
        
        // Time
        timeLabel.font = UIFont.systemFont(ofSize: 13)
        timeLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        containerView.addSubview(timeLabel)
        
        // Status
        statusLabel.font = UIFont.boldSystemFont(ofSize: 12)
        statusLabel.textAlignment = .right
        containerView.addSubview(statusLabel)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let padding: CGFloat = 10
        containerView.frame = CGRect(x: 15, y: 5, width: contentView.bounds.width - 30, height: contentView.bounds.height - 10)
        
        iconLabel.frame = CGRect(x: padding, y: padding, width: 40, height: 40)
        nameLabel.frame = CGRect(x: 60, y: padding, width: containerView.bounds.width - 150, height: 22)
        bonusLabel.frame = CGRect(x: 60, y: padding + 22, width: containerView.bounds.width - 150, height: 18)
        costLabel.frame = CGRect(x: 60, y: padding + 42, width: 150, height: 18)
        timeLabel.frame = CGRect(x: 210, y: padding + 42, width: 100, height: 18)
        statusLabel.frame = CGRect(x: containerView.bounds.width - 110, y: padding, width: 100, height: 25)
    }
    
    func configure(with research: ResearchType, player: Player?) {
        let manager = ResearchManager.shared

        iconLabel.text = research.icon
        nameLabel.text = "\(research.displayName) (Tier \(research.tier))"
        bonusLabel.text = research.bonuses.map { $0.displayString }.joined(separator: ", ")
        costLabel.text = research.costString
        timeLabel.text = "⏱️ \(research.timeString)"

        // Determine status
        if manager.isResearched(research) {
            statusLabel.text = "✅ Done"
            statusLabel.textColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
            containerView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            containerView.alpha = 0.7
        } else if manager.isResearching(research) {
            let progress = Int((manager.activeResearch?.getProgress() ?? 0) * 100)
            statusLabel.text = "🔬 \(progress)%"
            statusLabel.textColor = UIColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1.0)
            containerView.backgroundColor = UIColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1.0)
            containerView.alpha = 1.0
        } else if !manager.isAvailable(research) {
            // Show specific lock reason
            if let reason = manager.getLockedReason(research) {
                if reason.contains("City Center") {
                    statusLabel.text = "🏛️ CC Lv\(research.cityCenterLevelRequirement)"
                } else {
                    statusLabel.text = "🔒 Locked"
                }
            } else {
                statusLabel.text = "🔒 Locked"
            }
            statusLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            containerView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
            containerView.alpha = 0.5
        } else if !manager.canAfford(research) {
            statusLabel.text = "💰 Need $"
            statusLabel.textColor = UIColor(red: 0.9, green: 0.6, blue: 0.3, alpha: 1.0)
            containerView.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
            containerView.alpha = 0.8
        } else {
            statusLabel.text = "▶️ Available"
            statusLabel.textColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
            containerView.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
            containerView.alpha = 1.0
        }
    }
}
