// ============================================================================
// FILE: ResearchViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/ResearchViewController.swift
// PURPOSE: Research tree UI with branching visual layout and dependency lines
// ============================================================================

import UIKit

class ResearchViewController: UIViewController {

    // MARK: - Properties

    weak var player: Player?

    // UI Elements
    private var headerView: UIView!
    private var segmentedControl: UISegmentedControl!
    private var activeResearchView: UIView!
    private var activeResearchLabel: UILabel!
    private var activeProgressBar: UIView!
    private var activeProgressFill: UIView!
    private var activeTimeLabel: UILabel!
    private var cancelButton: UIButton!
    private var treeScrollView: UIScrollView!
    private var treeContentView: UIView!

    private var updateTimer: Timer?
    private var selectedCategory: ResearchCategory = .economic

    // Tree layout storage
    private var nodeViews: [ResearchType: ResearchNodeView] = [:]
    private var lineLayer: CAShapeLayer?
    private var crossLineLayer: CAShapeLayer?

    // Layout constants
    private let nodeWidth: CGFloat = 110
    private let nodeHeight: CGFloat = 45
    private let tierSpacing: CGFloat = 20   // horizontal gap between tiers
    private let lineSpacing: CGFloat = 12   // vertical gap between lines in a branch
    private let branchSpacing: CGFloat = 18 // vertical gap between branches
    private let branchHeaderHeight: CGFloat = 36
    private let treeLeftPadding: CGFloat = 15
    private let treeTopPadding: CGFloat = 10

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        buildTree()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateActiveResearchDisplay()
            self?.updateNodeStates()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)

        // Header
        headerView = UIView()
        headerView.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        let titleLabel = UILabel()
        titleLabel.text = "Research"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("X", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor(white: 0.3, alpha: 0.8)
        closeButton.layer.cornerRadius = 8
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(closeButton)

        // Segmented Control
        let economicTitle = "\(ResearchCategory.economic.icon) Economic"
        let militaryTitle = "\(ResearchCategory.military.icon) Military"
        segmentedControl = UISegmentedControl(items: [economicTitle, militaryTitle])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        segmentedControl.selectedSegmentTintColor = UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1.0)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        // Active Research Panel
        setupActiveResearchPanel()

        // Tree scroll view
        treeScrollView = UIScrollView()
        treeScrollView.backgroundColor = .clear
        treeScrollView.showsHorizontalScrollIndicator = true
        treeScrollView.showsVerticalScrollIndicator = true
        treeScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(treeScrollView)

        treeContentView = UIView()
        treeContentView.backgroundColor = .clear
        treeScrollView.addSubview(treeContentView)

        // Layout constraints
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -15),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 36),

            segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            segmentedControl.heightAnchor.constraint(equalToConstant: 32),

            activeResearchView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            activeResearchView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            activeResearchView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            activeResearchView.heightAnchor.constraint(equalToConstant: 80),

            treeScrollView.topAnchor.constraint(equalTo: activeResearchView.bottomAnchor, constant: 8),
            treeScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            treeScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            treeScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupActiveResearchPanel() {
        activeResearchView = UIView()
        activeResearchView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        activeResearchView.layer.cornerRadius = 10
        activeResearchView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activeResearchView)

        let currentLabel = UILabel()
        currentLabel.text = "Current Research"
        currentLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        currentLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        currentLabel.translatesAutoresizingMaskIntoConstraints = false
        activeResearchView.addSubview(currentLabel)

        activeResearchLabel = UILabel()
        activeResearchLabel.font = UIFont.boldSystemFont(ofSize: 16)
        activeResearchLabel.textColor = .white
        activeResearchLabel.text = "None"
        activeResearchLabel.translatesAutoresizingMaskIntoConstraints = false
        activeResearchView.addSubview(activeResearchLabel)

        let progressBg = UIView()
        progressBg.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        progressBg.layer.cornerRadius = 4
        progressBg.translatesAutoresizingMaskIntoConstraints = false
        activeResearchView.addSubview(progressBg)

        activeProgressFill = UIView()
        activeProgressFill.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1.0)
        activeProgressFill.layer.cornerRadius = 4
        progressBg.addSubview(activeProgressFill)
        activeProgressBar = progressBg

        activeTimeLabel = UILabel()
        activeTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        activeTimeLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        activeTimeLabel.textAlignment = .center
        activeTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        activeResearchView.addSubview(activeTimeLabel)

        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = UIColor(red: 0.7, green: 0.3, blue: 0.3, alpha: 1.0)
        cancelButton.layer.cornerRadius = 5
        cancelButton.addTarget(self, action: #selector(cancelResearchTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        activeResearchView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            currentLabel.topAnchor.constraint(equalTo: activeResearchView.topAnchor, constant: 8),
            currentLabel.leadingAnchor.constraint(equalTo: activeResearchView.leadingAnchor, constant: 12),

            activeResearchLabel.topAnchor.constraint(equalTo: currentLabel.bottomAnchor, constant: 2),
            activeResearchLabel.leadingAnchor.constraint(equalTo: activeResearchView.leadingAnchor, constant: 12),
            activeResearchLabel.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -8),

            cancelButton.trailingAnchor.constraint(equalTo: activeResearchView.trailingAnchor, constant: -12),
            cancelButton.centerYAnchor.constraint(equalTo: activeResearchLabel.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 60),
            cancelButton.heightAnchor.constraint(equalToConstant: 26),

            progressBg.topAnchor.constraint(equalTo: activeResearchLabel.bottomAnchor, constant: 6),
            progressBg.leadingAnchor.constraint(equalTo: activeResearchView.leadingAnchor, constant: 12),
            progressBg.trailingAnchor.constraint(equalTo: activeResearchView.trailingAnchor, constant: -12),
            progressBg.heightAnchor.constraint(equalToConstant: 8),

            activeTimeLabel.topAnchor.constraint(equalTo: progressBg.bottomAnchor, constant: 3),
            activeTimeLabel.centerXAnchor.constraint(equalTo: activeResearchView.centerXAnchor),
        ])

        updateActiveResearchDisplay()
    }

    // MARK: - Tree Building

    private func buildTree() {
        // Clear old nodes and layers
        for (_, nodeView) in nodeViews {
            nodeView.removeFromSuperview()
        }
        nodeViews.removeAll()
        lineLayer?.removeFromSuperlayer()
        crossLineLayer?.removeFromSuperlayer()

        // Remove old branch headers
        for sub in treeContentView.subviews {
            sub.removeFromSuperview()
        }

        let branches = ResearchBranch.allCases.filter { $0.category == selectedCategory }

        var cursorY: CGFloat = treeTopPadding

        for branch in branches {
            // Branch header
            let headerView = ResearchBranchHeaderView(branch: branch, player: player)
            headerView.frame = CGRect(x: treeLeftPadding, y: cursorY, width: 3 * nodeWidth + 2 * tierSpacing + 10, height: branchHeaderHeight)
            treeContentView.addSubview(headerView)
            cursorY += branchHeaderHeight + 4

            // Layout lines in this branch
            for line in branch.researchLines {
                for (tierIndex, research) in line.enumerated() {
                    let x = treeLeftPadding + CGFloat(tierIndex) * (nodeWidth + tierSpacing)
                    let nodeView = ResearchNodeView(researchType: research, player: player)
                    nodeView.frame = CGRect(x: x, y: cursorY, width: nodeWidth, height: nodeHeight)
                    nodeView.onTap = { [weak self] rt in
                        self?.handleNodeTap(rt)
                    }
                    treeContentView.addSubview(nodeView)
                    nodeViews[research] = nodeView
                }
                cursorY += nodeHeight + lineSpacing
            }
            cursorY += branchSpacing
        }

        let contentWidth = treeLeftPadding + 3 * nodeWidth + 2 * tierSpacing + 20
        let contentHeight = cursorY + 20
        treeContentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        treeScrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)

        drawDependencyLines()
    }

    private func drawDependencyLines() {
        lineLayer?.removeFromSuperlayer()
        crossLineLayer?.removeFromSuperlayer()

        let linePath = UIBezierPath()
        let crossPath = UIBezierPath()

        let branches = ResearchBranch.allCases.filter { $0.category == selectedCategory }

        for branch in branches {
            for line in branch.researchLines {
                // Within-line connections (straight horizontal)
                for i in 0..<(line.count - 1) {
                    guard let fromView = nodeViews[line[i]],
                          let toView = nodeViews[line[i + 1]] else { continue }
                    let from = CGPoint(x: fromView.frame.maxX, y: fromView.frame.midY)
                    let to = CGPoint(x: toView.frame.minX, y: toView.frame.midY)
                    linePath.move(to: from)
                    linePath.addLine(to: to)
                }
            }
        }

        // Cross-dependencies (curved bezier, dashed)
        for researchType in ResearchType.allCases where researchType.category == selectedCategory {
            guard let toView = nodeViews[researchType] else { continue }

            for prereq in researchType.prerequisites {
                guard let fromView = nodeViews[prereq] else { continue }

                // Skip within-line (same row) connections - already drawn as straight lines
                if isSameLineConnection(prereq, researchType) { continue }

                let from = CGPoint(x: fromView.frame.maxX, y: fromView.frame.midY)
                let to = CGPoint(x: toView.frame.minX, y: toView.frame.midY)

                let controlX = (from.x + to.x) / 2
                crossPath.move(to: from)
                crossPath.addCurve(to: to,
                                   controlPoint1: CGPoint(x: controlX, y: from.y),
                                   controlPoint2: CGPoint(x: controlX, y: to.y))
            }
        }

        // Solid lines for within-line
        let solidLayer = CAShapeLayer()
        solidLayer.path = linePath.cgPath
        solidLayer.strokeColor = UIColor(white: 0.5, alpha: 0.7).cgColor
        solidLayer.fillColor = UIColor.clear.cgColor
        solidLayer.lineWidth = 1.5
        treeContentView.layer.addSublayer(solidLayer)
        lineLayer = solidLayer

        // Dashed lines for cross-dependencies
        let dashedLayer = CAShapeLayer()
        dashedLayer.path = crossPath.cgPath
        dashedLayer.strokeColor = UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 0.7).cgColor
        dashedLayer.fillColor = UIColor.clear.cgColor
        dashedLayer.lineWidth = 1.5
        dashedLayer.lineDashPattern = [4, 3]
        treeContentView.layer.addSublayer(dashedLayer)
        crossLineLayer = dashedLayer
    }

    private func isSameLineConnection(_ a: ResearchType, _ b: ResearchType) -> Bool {
        // Check if a and b are adjacent in the same research line
        let branch = b.branch
        for line in branch.researchLines {
            for i in 0..<(line.count - 1) {
                if line[i] == a && line[i + 1] == b {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Update Display

    private func updateActiveResearchDisplay() {
        let manager = ResearchManager.shared

        if let active = manager.activeResearch {
            let speedMultiplier = manager.getResearchSpeedMultiplier()
            let progress = active.getProgress(speedMultiplier: speedMultiplier)
            let remaining = active.getRemainingTime(speedMultiplier: speedMultiplier)

            activeResearchLabel.text = "\(active.researchType.icon) \(active.researchType.displayName)"

            let maxWidth = activeProgressBar.bounds.width
            activeProgressFill.frame = CGRect(x: 0, y: 0, width: maxWidth * CGFloat(progress), height: activeProgressBar.bounds.height)

            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            activeTimeLabel.text = String(format: "%d:%02d remaining", minutes, seconds)

            cancelButton.isHidden = false
        } else {
            activeResearchLabel.text = "No active research"
            activeProgressFill.frame = CGRect(x: 0, y: 0, width: 0, height: activeProgressBar.bounds.height)
            activeTimeLabel.text = "Select research below to begin"
            cancelButton.isHidden = true
        }
    }

    private func updateNodeStates() {
        for (_, nodeView) in nodeViews {
            nodeView.updateState(player: player)
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func segmentChanged() {
        selectedCategory = segmentedControl.selectedSegmentIndex == 0 ? .economic : .military
        buildTree()
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
                self?.updateNodeStates()
            }
        })

        alert.addAction(UIAlertAction(title: "Keep Researching", style: .cancel))

        present(alert, animated: true)
    }

    private func handleNodeTap(_ researchType: ResearchType) {
        let manager = ResearchManager.shared

        if manager.isResearched(researchType) {
            showAlert(title: "Already Researched",
                      message: "\(researchType.displayName) has already been completed.\n\n\(researchType.bonusString)")
        } else if manager.isResearching(researchType) {
            // Do nothing, already in progress
        } else {
            startResearch(researchType)
        }
    }

    private func startResearch(_ researchType: ResearchType) {
        let manager = ResearchManager.shared

        if manager.activeResearch != nil {
            showAlert(title: "Already Researching", message: "Complete or cancel current research first.")
            return
        }

        if !manager.isAvailable(researchType) {
            if let reason = manager.getLockedReason(researchType) {
                showAlert(title: "Locked", message: reason)
            } else {
                showAlert(title: "Locked", message: "This research is not available yet.")
            }
            return
        }

        if !manager.canAfford(researchType) {
            let missing = manager.getMissingResources(for: researchType)
            var message = "Missing resources:\n"
            for (type, amount) in missing {
                message += "\(type.icon) \(amount) \(type.displayName)\n"
            }
            showAlert(title: "Insufficient Resources", message: message)
            return
        }

        var confirmMessage = "\(researchType.icon) \(researchType.displayName)\n\n"
        confirmMessage += "Cost: \(researchType.costString)\n"
        confirmMessage += "Time: \(researchType.timeString)\n\n"
        confirmMessage += "Benefits:\n\(researchType.bonusString)"

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
                self?.updateNodeStates()
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
}

// MARK: - Research Node View

class ResearchNodeView: UIView {

    let researchType: ResearchType
    var onTap: ((ResearchType) -> Void)?

    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    private let statusIndicator = UIView()

    init(researchType: ResearchType, player: Player?) {
        self.researchType = researchType
        super.init(frame: .zero)
        setupUI()
        updateState(player: player)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        layer.cornerRadius = 8
        layer.borderWidth = 1.5
        clipsToBounds = true

        iconLabel.font = UIFont.systemFont(ofSize: 16)
        iconLabel.textAlignment = .center
        iconLabel.text = researchType.icon
        addSubview(iconLabel)

        nameLabel.font = UIFont.systemFont(ofSize: 9, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.text = researchType.displayName
        addSubview(nameLabel)

        statusIndicator.layer.cornerRadius = 4
        addSubview(statusIndicator)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        let w = bounds.width
        iconLabel.frame = CGRect(x: 3, y: 3, width: 22, height: 22)
        statusIndicator.frame = CGRect(x: w - 12, y: 4, width: 8, height: 8)
        nameLabel.frame = CGRect(x: 26, y: 3, width: w - 42, height: h - 6)
    }

    @objc private func tapped() {
        onTap?(researchType)
    }

    func updateState(player: Player?) {
        let manager = ResearchManager.shared

        if manager.isResearched(researchType) {
            // Completed: green tint
            backgroundColor = UIColor(red: 0.15, green: 0.3, blue: 0.15, alpha: 1.0)
            layer.borderColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0).cgColor
            statusIndicator.backgroundColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
            nameLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
            alpha = 0.85
            layer.shadowColor = nil
            layer.shadowRadius = 0
        } else if manager.isResearching(researchType) {
            // Researching: blue tint with glow
            backgroundColor = UIColor(red: 0.15, green: 0.25, blue: 0.4, alpha: 1.0)
            layer.borderColor = UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0).cgColor
            statusIndicator.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1.0)
            nameLabel.textColor = .white
            alpha = 1.0
            clipsToBounds = false
            layer.shadowColor = UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.6).cgColor
            layer.shadowRadius = 6
            layer.shadowOpacity = 0.8
            layer.shadowOffset = .zero
        } else if !manager.isAvailable(researchType) {
            // Locked
            let reason = manager.getLockedReason(researchType)
            let isBuildingLocked = reason?.contains("Requires") == true && !(reason?.contains("City Center") == true)

            if isBuildingLocked {
                // Building gate locked: dark with distinct indicator
                backgroundColor = UIColor(white: 0.12, alpha: 1.0)
                layer.borderColor = UIColor(red: 0.5, green: 0.3, blue: 0.1, alpha: 0.6).cgColor
                statusIndicator.backgroundColor = UIColor(red: 0.7, green: 0.4, blue: 0.1, alpha: 1.0)
                nameLabel.textColor = UIColor(white: 0.4, alpha: 1.0)
                alpha = 0.5
            } else {
                // Prereq locked: dark with reduced alpha
                backgroundColor = UIColor(white: 0.15, alpha: 1.0)
                layer.borderColor = UIColor(white: 0.3, alpha: 0.5).cgColor
                statusIndicator.backgroundColor = UIColor(white: 0.4, alpha: 1.0)
                nameLabel.textColor = UIColor(white: 0.45, alpha: 1.0)
                alpha = 0.5
            }
            layer.shadowColor = nil
            layer.shadowRadius = 0
        } else if !manager.canAfford(researchType) {
            // Available but can't afford: dimmed
            backgroundColor = UIColor(white: 0.22, alpha: 1.0)
            layer.borderColor = UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 0.6).cgColor
            statusIndicator.backgroundColor = UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0)
            nameLabel.textColor = UIColor(white: 0.75, alpha: 1.0)
            alpha = 0.8
            layer.shadowColor = nil
            layer.shadowRadius = 0
        } else {
            // Available: bright
            backgroundColor = UIColor(white: 0.28, alpha: 1.0)
            layer.borderColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 0.8).cgColor
            statusIndicator.backgroundColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
            nameLabel.textColor = .white
            alpha = 1.0
            layer.shadowColor = nil
            layer.shadowRadius = 0
        }
    }
}

// MARK: - Research Branch Header View

class ResearchBranchHeaderView: UIView {

    init(branch: ResearchBranch, player: Player?) {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        layer.cornerRadius = 6

        let iconLabel = UILabel()
        iconLabel.text = branch.icon
        iconLabel.font = UIFont.systemFont(ofSize: 16)
        addSubview(iconLabel)

        let nameLabel = UILabel()
        nameLabel.text = branch.displayName
        nameLabel.font = UIFont.boldSystemFont(ofSize: 13)
        nameLabel.textColor = .white
        addSubview(nameLabel)

        let gateLabel = UILabel()
        gateLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)

        if let gate = branch.gateBuildingType {
            // Check if player has the gate building
            var hasGate = false
            if let p = player {
                hasGate = p.buildings.contains { $0.buildingType == gate && $0.isOperational }
            }
            if hasGate {
                gateLabel.text = "\(gate.displayName) (built)"
                gateLabel.textColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
            } else {
                gateLabel.text = "Requires \(gate.displayName)"
                gateLabel.textColor = UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1.0)
            }
        } else {
            gateLabel.text = "No building required"
            gateLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        }
        addSubview(gateLabel)

        iconLabel.frame = CGRect(x: 8, y: 8, width: 22, height: 22)
        nameLabel.frame = CGRect(x: 32, y: 4, width: 150, height: 18)
        gateLabel.frame = CGRect(x: 32, y: 20, width: 250, height: 14)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
