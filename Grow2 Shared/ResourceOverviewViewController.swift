// ============================================================================
// FILE: ResourceOverviewViewController.swift
// LOCATION: Grow2 iOS/ViewControllers/
// PURPOSE: Shows overview of resource collection statistics for each resource type
// ============================================================================

import UIKit

class ResourceOverviewViewController: UIViewController {

    var player: Player!
    var hexMap: HexMap!
    var gameScene: GameScene!
    var gameViewController: GameViewController?

    var scrollView: UIScrollView!
    var contentView: UIView!
    var closeButton: UIButton!
    var updateTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateContent()

        // Update every second for live rates
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateContent()
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
        titleLabel.text = "Resource Overview"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)

        // Close button
        closeButton = UIButton(frame: CGRect(x: view.bounds.width - 70, y: 50, width: 50, height: 40))
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        closeButton.addTarget(self, action: #selector(closeScreen), for: .touchUpInside)
        view.addSubview(closeButton)

        // Scroll view
        scrollView = UIScrollView(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: view.bounds.height - 100))
        scrollView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        view.addSubview(scrollView)

        // Content view
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    func updateContent() {
        // Clear existing content
        contentView.subviews.forEach { $0.removeFromSuperview() }

        var yOffset: CGFloat = 16

        // Create card for each resource type
        let resourceTypes: [ResourceType] = [.wood, .food, .stone, .ore]

        for resourceType in resourceTypes {
            let cardHeight = createResourceCard(for: resourceType, at: yOffset)
            yOffset += cardHeight + 16
        }

        // Update content size
        let contentHeight = yOffset + 20
        contentView.heightAnchor.constraint(equalToConstant: contentHeight).isActive = true
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: contentHeight)
    }

    func createResourceCard(for resourceType: ResourceType, at yOffset: CGFloat) -> CGFloat {
        let cardWidth = view.bounds.width - 32
        let cardX: CGFloat = 16

        // Card background
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        // Gather data
        let gatheringData = getGatheringData(for: resourceType)
        let researchBonus = getResearchBonus(for: resourceType)
        let adjacencyBonuses = getAdjacencyBonuses(for: resourceType)
        let rate = player.getCollectionRate(resourceType)
        let currentAmount = player.getResource(resourceType)
        let capacity = player.getStorageCapacity(for: resourceType)

        var cardHeight: CGFloat = 16

        // Header: Resource icon and name
        let headerLabel = UILabel()
        headerLabel.text = "\(resourceType.icon) \(resourceType.displayName)"
        headerLabel.font = UIFont.boldSystemFont(ofSize: 20)
        headerLabel.textColor = .white
        headerLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 28)
        card.addSubview(headerLabel)
        cardHeight += 32

        // Storage info
        let storageLabel = UILabel()
        let storagePercent = player.getStoragePercent(for: resourceType)
        let storageColor: UIColor = storagePercent >= 1.0 ? .systemRed : (storagePercent >= 0.9 ? .systemOrange : .white)
        storageLabel.text = "Storage: \(currentAmount)/\(capacity)"
        storageLabel.font = UIFont.systemFont(ofSize: 14)
        storageLabel.textColor = storageColor
        storageLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 20)
        card.addSubview(storageLabel)
        cardHeight += 24

        // Collection rate
        let rateLabel = UILabel()
        let rateColor: UIColor = rate > 0 ? .systemGreen : UIColor(white: 0.5, alpha: 1.0)
        rateLabel.text = "Collection Rate: \(String(format: "%.1f", rate))/sec"
        rateLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        rateLabel.textColor = rateColor
        rateLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 22)
        card.addSubview(rateLabel)
        cardHeight += 28

        // Separator
        let separator1 = UIView()
        separator1.backgroundColor = UIColor(white: 0.35, alpha: 1.0)
        separator1.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 1)
        card.addSubview(separator1)
        cardHeight += 12

        // Gathering stats section
        let gatheringTitle = UILabel()
        gatheringTitle.text = "Gathering"
        gatheringTitle.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        gatheringTitle.textColor = UIColor(white: 0.7, alpha: 1.0)
        gatheringTitle.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
        card.addSubview(gatheringTitle)
        cardHeight += 22

        let groupsLabel = UILabel()
        groupsLabel.text = "Groups: \(gatheringData.groupCount)"
        groupsLabel.font = UIFont.systemFont(ofSize: 14)
        groupsLabel.textColor = .white
        groupsLabel.frame = CGRect(x: 16, y: cardHeight, width: (cardWidth - 32) / 2, height: 18)
        card.addSubview(groupsLabel)

        let villagersLabel = UILabel()
        villagersLabel.text = "Villagers: \(gatheringData.totalVillagers)"
        villagersLabel.font = UIFont.systemFont(ofSize: 14)
        villagersLabel.textColor = .white
        villagersLabel.frame = CGRect(x: (cardWidth - 32) / 2 + 16, y: cardHeight, width: (cardWidth - 32) / 2, height: 18)
        card.addSubview(villagersLabel)
        cardHeight += 24

        // Separator
        let separator2 = UIView()
        separator2.backgroundColor = UIColor(white: 0.35, alpha: 1.0)
        separator2.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 1)
        card.addSubview(separator2)
        cardHeight += 12

        // Bonuses section
        let bonusesTitle = UILabel()
        bonusesTitle.text = "Active Bonuses"
        bonusesTitle.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        bonusesTitle.textColor = UIColor(white: 0.7, alpha: 1.0)
        bonusesTitle.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
        card.addSubview(bonusesTitle)
        cardHeight += 22

        var hasBonuses = false

        // Research bonus
        if researchBonus > 0 {
            hasBonuses = true
            let researchLabel = UILabel()
            let bonusName = getResearchBonusName(for: resourceType)
            researchLabel.text = "🔬 \(bonusName): +\(Int(researchBonus * 100))%"
            researchLabel.font = UIFont.systemFont(ofSize: 13)
            researchLabel.textColor = .systemCyan
            researchLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
            card.addSubview(researchLabel)
            cardHeight += 20
        }

        // Adjacency bonuses
        for bonusDescription in adjacencyBonuses {
            hasBonuses = true
            let adjacencyLabel = UILabel()
            adjacencyLabel.text = bonusDescription
            adjacencyLabel.font = UIFont.systemFont(ofSize: 13)
            adjacencyLabel.textColor = .systemYellow
            adjacencyLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
            card.addSubview(adjacencyLabel)
            cardHeight += 20
        }

        if !hasBonuses {
            let noBonusLabel = UILabel()
            noBonusLabel.text = "No active bonuses"
            noBonusLabel.font = UIFont.systemFont(ofSize: 13)
            noBonusLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            noBonusLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
            card.addSubview(noBonusLabel)
            cardHeight += 20
        }

        cardHeight += 16

        // Set card constraints
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: cardX),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -cardX),
            card.heightAnchor.constraint(equalToConstant: cardHeight)
        ])

        return cardHeight
    }

    // MARK: - Data Collection

    struct GatheringData {
        var groupCount: Int = 0
        var totalVillagers: Int = 0
    }

    func getGatheringData(for resourceType: ResourceType) -> GatheringData {
        var data = GatheringData()

        for group in player.getVillagerGroups() {
            switch group.currentTask {
            case .gatheringResource(let resourcePoint):
                if resourcePoint.resourceType.resourceYield == resourceType {
                    data.groupCount += 1
                    data.totalVillagers += group.villagerCount
                }
            case .gathering(let gatheringType):
                if gatheringType == resourceType {
                    data.groupCount += 1
                    data.totalVillagers += group.villagerCount
                }
            default:
                break
            }
        }

        return data
    }

    func getResearchBonus(for resourceType: ResourceType) -> Double {
        let researchManager = ResearchManager.shared

        switch resourceType {
        case .wood:
            return researchManager.getLumberCampGatheringMultiplier() - 1.0
        case .food:
            return researchManager.getFarmGatheringMultiplier() - 1.0
        case .stone, .ore:
            return researchManager.getMiningCampGatheringMultiplier() - 1.0
        }
    }

    func getResearchBonusName(for resourceType: ResourceType) -> String {
        switch resourceType {
        case .wood:
            return "Lumber Camp Efficiency"
        case .food:
            return "Farm Efficiency"
        case .stone, .ore:
            return "Mining Camp Efficiency"
        }
    }

    func getAdjacencyBonuses(for resourceType: ResourceType) -> [String] {
        var bonuses: [String] = []
        let adjacencyManager = AdjacencyBonusManager.shared

        // Find relevant buildings based on resource type
        let relevantBuildingTypes: [BuildingType]
        switch resourceType {
        case .wood:
            relevantBuildingTypes = [.lumberCamp]
        case .food:
            relevantBuildingTypes = [.farm]
        case .stone, .ore:
            relevantBuildingTypes = [.miningCamp]
        }

        // Track unique bonus sources to avoid duplicates
        var seenBonuses: Set<String> = []

        for building in player.buildings where relevantBuildingTypes.contains(building.buildingType) {
            if let bonusData = adjacencyManager.getBonusData(for: building.data.id) {
                for source in bonusData.bonusSources {
                    if !seenBonuses.contains(source) {
                        seenBonuses.insert(source)
                        bonuses.append(source)
                    }
                }
            }
        }

        return bonuses
    }

    @objc func closeScreen() {
        dismiss(animated: true)
    }
}
