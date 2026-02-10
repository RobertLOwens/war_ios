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
        let rateColor: UIColor = rate > 0 ? .systemGreen : (rate < 0 ? .systemRed : UIColor(white: 0.5, alpha: 1.0))
        let rateSign = rate >= 0 ? "" : ""
        rateLabel.text = "Collection Rate: \(rateSign)\(String(format: "%.1f", rate))/sec"
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

        // Gathering Entities section (per-group breakdown)
        let gatherDetails = getVillagerGroupGatherDetails(for: resourceType)
        if !gatherDetails.isEmpty {
            // Separator before gathering entities
            let separatorGather = UIView()
            separatorGather.backgroundColor = UIColor(white: 0.35, alpha: 1.0)
            separatorGather.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 1)
            card.addSubview(separatorGather)
            cardHeight += 12

            let gatherEntitiesTitle = UILabel()
            gatherEntitiesTitle.text = "Gathering Entities"
            gatherEntitiesTitle.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            gatherEntitiesTitle.textColor = UIColor(white: 0.7, alpha: 1.0)
            gatherEntitiesTitle.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
            card.addSubview(gatherEntitiesTitle)
            cardHeight += 22

            for detail in gatherDetails {
                // Group name and villager count (White)
                let groupNameLabel = UILabel()
                groupNameLabel.text = "\(detail.group.name) (\(detail.group.villagerCount) villagers)"
                groupNameLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                groupNameLabel.textColor = .white
                groupNameLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
                card.addSubview(groupNameLabel)
                cardHeight += 20

                // Base Rate (Gray)
                let baseRateLabel = UILabel()
                baseRateLabel.text = "   Base Rate: \(String(format: "%.2f", detail.baseRate))/s"
                baseRateLabel.font = UIFont.systemFont(ofSize: 13)
                baseRateLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
                baseRateLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 16)
                card.addSubview(baseRateLabel)
                cardHeight += 18

                // Adjacency bonus (Yellow) - if applicable
                if detail.adjacencyMultiplier > 1.0 {
                    let adjacencyPercent = Int((detail.adjacencyMultiplier - 1.0) * 100)
                    let adjacencyLabel = UILabel()
                    adjacencyLabel.text = "   Adjacency: +\(adjacencyPercent)%"
                    adjacencyLabel.font = UIFont.systemFont(ofSize: 13)
                    adjacencyLabel.textColor = .systemYellow
                    adjacencyLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 16)
                    card.addSubview(adjacencyLabel)
                    cardHeight += 18

                    // List adjacency sources
                    for source in detail.adjacencySources {
                        let sourceLabel = UILabel()
                        sourceLabel.text = "      - \(source)"
                        sourceLabel.font = UIFont.systemFont(ofSize: 12)
                        sourceLabel.textColor = UIColor.systemYellow.withAlphaComponent(0.8)
                        sourceLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 15)
                        card.addSubview(sourceLabel)
                        cardHeight += 16
                    }
                }

                // Research bonus (Cyan) - if applicable
                if detail.researchMultiplier > 1.0 {
                    let researchPercent = Int((detail.researchMultiplier - 1.0) * 100)
                    let researchLabel = UILabel()
                    researchLabel.text = "   Research: +\(researchPercent)%"
                    researchLabel.font = UIFont.systemFont(ofSize: 13)
                    researchLabel.textColor = .systemCyan
                    researchLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 16)
                    card.addSubview(researchLabel)
                    cardHeight += 18
                }

                // Building level bonus (Orange) - if applicable
                if detail.campLevelMultiplier > 1.0 {
                    let levelPercent = Int((detail.campLevelMultiplier - 1.0) * 100)
                    let levelLabel = UILabel()
                    levelLabel.text = "   Building Level: +\(levelPercent)%"
                    levelLabel.font = UIFont.systemFont(ofSize: 13)
                    levelLabel.textColor = .systemOrange
                    levelLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 16)
                    card.addSubview(levelLabel)
                    cardHeight += 18
                }

                // Final Rate (Green)
                let finalRateLabel = UILabel()
                finalRateLabel.text = "   Final Rate: \(String(format: "%.2f", detail.finalRate))/s"
                finalRateLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
                finalRateLabel.textColor = .systemGreen
                finalRateLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 16)
                card.addSubview(finalRateLabel)
                cardHeight += 18

                // Separator line between groups
                let groupSeparator = UIView()
                groupSeparator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
                groupSeparator.frame = CGRect(x: 24, y: cardHeight, width: cardWidth - 48, height: 1)
                card.addSubview(groupSeparator)
                cardHeight += 8
            }
        }

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

        // Farm wood upkeep (show on wood card)
        if resourceType == .wood {
            let activeFarmCount = getActiveFarmGatheringCount()
            if activeFarmCount > 0 {
                let totalDrain = Double(activeFarmCount) * GameConfig.Resources.farmWoodConsumptionRate
                let separator3 = UIView()
                separator3.backgroundColor = UIColor(white: 0.35, alpha: 1.0)
                separator3.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 1)
                card.addSubview(separator3)
                cardHeight += 12

                let upkeepTitle = UILabel()
                upkeepTitle.text = "Farm Upkeep"
                upkeepTitle.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
                upkeepTitle.textColor = UIColor(white: 0.7, alpha: 1.0)
                upkeepTitle.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
                card.addSubview(upkeepTitle)
                cardHeight += 22

                let upkeepLabel = UILabel()
                upkeepLabel.text = "🌾 \(activeFarmCount) active farm\(activeFarmCount == 1 ? "" : "s"): -\(String(format: "%.1f", totalDrain))/s"
                upkeepLabel.font = UIFont.systemFont(ofSize: 13)
                upkeepLabel.textColor = .systemRed
                upkeepLabel.frame = CGRect(x: 16, y: cardHeight, width: cardWidth - 32, height: 18)
                card.addSubview(upkeepLabel)
                cardHeight += 20
            }
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

    func getActiveFarmGatheringCount() -> Int {
        var count = 0
        for group in player.getVillagerGroups() {
            if case .gatheringResource(let resourcePoint) = group.currentTask {
                if resourcePoint.resourceType == .farmland {
                    count += 1
                }
            }
        }
        return count
    }

    struct GatheringData {
        var groupCount: Int = 0
        var totalVillagers: Int = 0
    }

    struct VillagerGroupGatherDetails {
        let group: VillagerGroup
        let resourcePoint: ResourcePointNode
        let baseRate: Double              // resourceType.baseGatherRate + (villagerCount * 0.2)
        let adjacencyMultiplier: Double   // 1.0 + sum of adjacency bonuses
        let researchMultiplier: Double    // from ResearchManager
        let campLevelMultiplier: Double   // building level bonus (e.g., farm Lv.2 = +10%)
        let finalRate: Double             // baseRate * adjacencyMultiplier * researchMultiplier * campLevelMultiplier
        let adjacencySources: [String]    // e.g., "Warehouse at (3,4): +25%"
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

    // MARK: - Villager Group Gather Details

    func getVillagerGroupGatherDetails(for resourceType: ResourceType) -> [VillagerGroupGatherDetails] {
        var details: [VillagerGroupGatherDetails] = []

        for group in player.getVillagerGroups() {
            // Check if the group is gathering a resource point that yields this resource type
            if case .gatheringResource(let resourcePoint) = group.currentTask {
                if resourcePoint.resourceType.resourceYield == resourceType {
                    let detail = calculateGatherDetails(for: group, at: resourcePoint)
                    details.append(detail)
                }
            }
        }

        return details
    }

    func calculateGatherDetails(for group: VillagerGroup, at resourcePoint: ResourcePointNode) -> VillagerGroupGatherDetails {
        let baseGatherRatePerVillager = 0.2
        let adjacencyBonusPercent = 0.25

        // Base rate = resourceType.baseGatherRate + (villagerCount * 0.2)
        let baseRate = resourcePoint.resourceType.baseGatherRate + (Double(group.villagerCount) * baseGatherRatePerVillager)

        // Calculate adjacency bonus for the resource point
        let (adjacencyMultiplier, adjacencySources) = calculateResourcePointAdjacency(
            resourcePoint: resourcePoint,
            bonusPercent: adjacencyBonusPercent
        )

        // Get research multiplier based on resource type
        let researchMultiplier = getResearchMultiplier(for: resourcePoint.resourceType)

        // Calculate camp/farm level bonus (mirrors ResourceEngine.calculateCampLevelBonus)
        let campLevelMultiplier = calculateCampLevelBonus(for: resourcePoint)

        // Final rate = baseRate * adjacencyMultiplier * researchMultiplier * campLevelMultiplier
        let finalRate = baseRate * adjacencyMultiplier * researchMultiplier * campLevelMultiplier

        return VillagerGroupGatherDetails(
            group: group,
            resourcePoint: resourcePoint,
            baseRate: baseRate,
            adjacencyMultiplier: adjacencyMultiplier,
            researchMultiplier: researchMultiplier,
            campLevelMultiplier: campLevelMultiplier,
            finalRate: finalRate,
            adjacencySources: adjacencySources
        )
    }

    func calculateCampLevelBonus(for resourcePoint: ResourcePointNode) -> Double {
        // Determine which building type boosts this resource
        let matchingType: BuildingType
        switch resourcePoint.resourceType {
        case .farmland:
            matchingType = .farm
        case .trees:
            matchingType = .lumberCamp
        case .oreMine, .stoneQuarry:
            matchingType = .miningCamp
        default:
            return 1.0
        }

        // Check the tile itself and all neighbors for the highest-level matching building
        let tilesToCheck = [resourcePoint.coordinate] + resourcePoint.coordinate.neighbors()
        var highestLevel = 0

        for coord in tilesToCheck {
            if let building = hexMap.buildings.first(where: {
                $0.coordinate == coord && $0.buildingType == matchingType && $0.isOperational && $0.level > highestLevel
            }) {
                highestLevel = building.level
            }
        }

        guard highestLevel > 1 else { return 1.0 }
        return 1.0 + Double(highestLevel - 1) * GameConfig.Resources.campLevelBonusPerLevel
    }

    func calculateResourcePointAdjacency(resourcePoint: ResourcePointNode, bonusPercent: Double) -> (multiplier: Double, sources: [String]) {
        var multiplier = 1.0
        var sources: [String] = []

        let neighbors = resourcePoint.coordinate.neighbors()

        for neighborCoord in neighbors {
            // Check if there's a building at this neighbor coordinate
            if let building = hexMap.buildings.first(where: { $0.coordinate == neighborCoord && $0.isOperational }) {
                // Match logic from ResourceEngine.calculateAdjacencyBonus()
                switch resourcePoint.resourceType {
                case .farmland:
                    if building.buildingType == .mill {
                        multiplier += bonusPercent
                        sources.append("Mill at (\(neighborCoord.q),\(neighborCoord.r)): +25%")
                    }
                case .trees:
                    if building.buildingType == .warehouse {
                        multiplier += bonusPercent
                        sources.append("Warehouse at (\(neighborCoord.q),\(neighborCoord.r)): +25%")
                    }
                case .oreMine, .stoneQuarry:
                    if building.buildingType == .warehouse {
                        multiplier += bonusPercent
                        sources.append("Warehouse at (\(neighborCoord.q),\(neighborCoord.r)): +25%")
                    }
                default:
                    break
                }
            }
        }

        return (multiplier, sources)
    }

    func getResearchMultiplier(for resourcePointType: ResourcePointType) -> Double {
        let researchManager = ResearchManager.shared

        switch resourcePointType {
        case .farmland:
            return researchManager.getFarmGatheringMultiplier()
        case .trees:
            return researchManager.getLumberCampGatheringMultiplier()
        case .oreMine, .stoneQuarry:
            return researchManager.getMiningCampGatheringMultiplier()
        default:
            return 1.0
        }
    }

    @objc func closeScreen() {
        dismiss(animated: true)
    }
}
