import UIKit
import SpriteKit

class GameViewController: UIViewController {
    
    var skView: SKView!
    var gameScene: GameScene!
    var player: Player!
    var mapSize: MapSize = .medium
    var resourceDensity: ResourceDensity = .normal
    var autoSaveTimer: Timer?
    let autoSaveInterval: TimeInterval = 60.0 // Auto-save every 60 seconds
    var shouldLoadGame: Bool = false
    
    // UI Elements
    var resourcePanel: UIView!
    var resourceLabels: [ResourceType: UILabel] = [:]
    var commanderButton: UIButton!
    var combatHistoryButton: UIButton!
    
    private struct AssociatedKeys {
        static var unitLabels: UInt8 = 0
        static var garrisonData: UInt8 = 1
        static var villagerCountLabel: UInt8 = 2
        static var splitLabels: UInt8 = 3
        static var trainingLabels: UInt8 = 4  // ✅ Unified training slider labels
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize player
        player = Player(name: "Player 1", color: .blue)
        
        setupSKView()
        setupScene()
        setupUI()
        setupGameCallbacks()
        setupAutoSave()
        
        // Check if we should load a saved game
        if shouldLoadGame {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.loadGame()
            }
        } else {
            // Initial resource display update
            updateResourceDisplay()
        }
        
        if shouldLoadGame || GameSaveManager.shared.saveExists() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.processBackgroundTime()
            }
        }
    }
    
    func initializePlayers() {
        // Create human player
        player = Player(name: "Player 1", color: .blue)
        
        // Create AI opponent
        let aiPlayer = Player(name: "AI Opponent", color: .red)
        player.setDiplomacyStatus(with: aiPlayer, status: .enemy)
        
        // Store for later use in game setup
        // We'll pass this to the scene in setupScene()
    }

    func setupSKView() {
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(skView)
        
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.ignoresSiblingOrder = true
    }
    
    func setupScene() {
        gameScene = GameScene(size: skView.bounds.size)
        gameScene.scaleMode = .resizeFill
        gameScene.player = player
        gameScene.mapSize = mapSize.rawValue
        gameScene.resourceDensity = resourceDensity.multiplier
        skView.presentScene(gameScene)
    }
    
    func setupGameCallbacks() {
        // Handle tile menu showing
        gameScene.showTileMenu = { [weak self] coordinate in
            self?.showTileActionMenu(for: coordinate)
        }
        
        // ✅ FIX: Point to the dedicated move selection menu
        gameScene.showEntitySelectionForMove = { [weak self] destination, entities in
            self?.showMoveSelectionMenu(to: destination, from: entities)
        }
        
        gameScene.showBuildingMenu = { [weak self] coordinate, entity in
            self?.showVillagerMenu(at: coordinate, villagerGroup: entity!)
        }
        
        // Handle resource display updates
        gameScene.updateResourceDisplay = { [weak self] in
            self?.updateResourceDisplay()
        }
    }
    
    func showEntityActionMenu(for entity: EntityNode, at coordinate: HexCoordinate) {
        var title = ""
        var message = ""
        
        // Get entity details
        if entity.entityType == .villagerGroup, let villagers = entity.entity as? VillagerGroup {
            title = "👷 \(villagers.name)"
            message = "Location: (\(coordinate.q), \(coordinate.r))\n"
            message += "Villagers: \(villagers.villagerCount)\n"
            message += "Task: \(villagers.currentTask.displayName)"
        } else if entity.entityType == .army, let army = entity.entity as? Army {
            title = "🛡️ \(army.name)"
            message = "Location: (\(coordinate.q), \(coordinate.r))\n"
            message += army.getDescription()
        }
        
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .actionSheet
        )
        
        // ✅ CHECK: Is this an enemy entity? Show Attack option
        if entity.entity.owner?.id != player.id {
            let ownerName = entity.entity.owner?.name ?? "Unknown"
            
            // Check if we have armies that can attack
            let playerArmies = player.getArmies().filter { $0.hasMilitaryUnits() }
            if !playerArmies.isEmpty {
                alert.addAction(UIAlertAction(title: "⚔️ Attack \(ownerName)", style: .destructive) { [weak self] _ in
                    self?.showAttackerSelection(target: entity, at: coordinate)
                })
            }
        }
        
        // ✅ VILLAGER ACTIONS (only for owned entities)
        if entity.entityType == .villagerGroup,
           let villagers = entity.entity as? VillagerGroup,
           villagers.owner?.id == player.id {
            
            print("✅ DEBUG: Villager group is owned by player - showing actions")
            
            // Build action - always show for owned villagers
            alert.addAction(UIAlertAction(title: "🏗️ Build", style: .default) { [weak self] _ in
                print("🏗️ Build button tapped!")
                self?.showBuildingMenu(at: coordinate, villagerGroup: entity)
            })
            
            // ✅ Gather action if resource exists at location
            if let resourcePoint = gameScene.hexMap.getResourcePoint(at: coordinate),
               resourcePoint.canBeGathered() {
                alert.addAction(UIAlertAction(title: "\(resourcePoint.resourceType.icon) Gather \(resourcePoint.resourceType.displayName)", style: .default) { [weak self] _ in
                    self?.assignVillagersToGather(villagerGroup: villagers, resourcePoint: resourcePoint)
                })
            }
            
            if villagers.villagerCount > 1 {
                alert.addAction(UIAlertAction(title: "✂️ Split Group", style: .default) { [weak self] _ in
                    self?.showSplitVillagerGroupMenu(villagerGroup: villagers, entity: entity)
                })
            }
            
        } else if entity.entityType == .villagerGroup {
            print("❌ DEBUG: Villager not owned by player")
            print("   Entity owner ID: \(entity.entity.owner?.id.uuidString ?? "nil")")
            print("   Player ID: \(player.id.uuidString)")
        }
        
        // ✅ ARMY ACTIONS (only for owned entities)
        if entity.entityType == .army,
           let army = entity.entity as? Army,
           army.owner?.id == player.id {
            
            // Reinforce action
            let buildingsWithGarrison = player.buildings.filter { $0.getTotalGarrisonedUnits() > 0 }
            if !buildingsWithGarrison.isEmpty {
                alert.addAction(UIAlertAction(title: "🔄 Reinforce Army", style: .default) { [weak self] _ in
                    self?.showReinforcementSourceSelection(for: army)
                })
            }
        }
        
        // Back to entity selection (if multiple entities on tile)
        let entitiesAtTile = gameScene.hexMap.entities.filter { $0.coordinate == coordinate }
        if entitiesAtTile.count > 1 {
            alert.addAction(UIAlertAction(title: "← Back to Entity List", style: .default) { [weak self] _ in
                self?.showEntitySelectionMenu(at: coordinate, entities: entitiesAtTile)
            })
        }
        
        // Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.gameScene.deselectAll()
        })
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Combat System
    
    /// Shows a menu to select which army to use for attacking a target
    func showAttackerSelection(target: EntityNode, at coordinate: HexCoordinate) {
        let playerArmies = player.getArmies().filter { $0.hasMilitaryUnits() }
        
        let targetName: String
        if let army = target.entity as? Army {
            targetName = army.name
        } else if let villagers = target.entity as? VillagerGroup {
            targetName = villagers.name
        } else {
            targetName = "Target"
        }
        
        let alert = UIAlertController(
            title: "⚔️ Select Attacking Army",
            message: "Choose which army to attack \(targetName) with:",
            preferredStyle: .actionSheet
        )
        
        for army in playerArmies {
            let unitCount = army.getTotalMilitaryUnits()
            let distance = army.coordinate.distance(to: coordinate)
            let title = "\(army.name) (\(unitCount) units) - Distance: \(distance)"
            
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.initiateAttack(attacker: army, target: target, at: coordinate)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    /// Initiates an attack from one army to another entity
    func initiateAttack(attacker: Army, target: EntityNode, at coordinate: HexCoordinate) {
        // Check if target is still valid
        guard let targetEntity = target.entity as? Army else {
            showSimpleAlert(title: "Invalid Target", message: "Target is not an army or no longer exists.")
            return
        }
        
        // Calculate combat outcome
        let attackerStrength = attacker.getModifiedStrength()
        let defenderStrength = targetEntity.getModifiedDefense()
        
        var resultMessage = "⚔️ Battle Report\n\n"
        resultMessage += "Attacker: \(attacker.name)\n"
        resultMessage += "Attack Power: \(attackerStrength)\n\n"
        resultMessage += "Defender: \(targetEntity.name)\n"
        resultMessage += "Defense Power: \(defenderStrength)\n\n"
        
        // Simple combat calculation
        if attackerStrength > defenderStrength {
            let casualties = calculateCasualties(army: attacker, lossPercent: 0.2)
            let defenderCasualties = calculateCasualties(army: targetEntity, lossPercent: 0.8)
            
            applyCasualties(to: attacker, casualties: casualties)
            applyCasualties(to: targetEntity, casualties: defenderCasualties)
            
            resultMessage += "Result: Victory! 🎉\n\n"
            resultMessage += "Your losses: \(casualties.values.reduce(0, +)) units\n"
            resultMessage += "Enemy losses: \(defenderCasualties.values.reduce(0, +)) units"
            
            // If defender is wiped out, remove from map
            if targetEntity.getTotalMilitaryUnits() == 0 {
                gameScene.hexMap.removeEntity(target)
                target.removeFromParent()
                targetEntity.owner?.removeArmy(targetEntity)
                resultMessage += "\n\n💀 Enemy army destroyed!"
            }
        } else {
            let casualties = calculateCasualties(army: attacker, lossPercent: 0.6)
            let defenderCasualties = calculateCasualties(army: targetEntity, lossPercent: 0.3)
            
            applyCasualties(to: attacker, casualties: casualties)
            applyCasualties(to: targetEntity, casualties: defenderCasualties)
            
            resultMessage += "Result: Defeat 😞\n\n"
            resultMessage += "Your losses: \(casualties.values.reduce(0, +)) units\n"
            resultMessage += "Enemy losses: \(defenderCasualties.values.reduce(0, +)) units"
            
            // If attacker is wiped out, remove from map
            if attacker.getTotalMilitaryUnits() == 0 {
                if let attackerNode = gameScene.hexMap.entities.first(where: { ($0.entity as? Army)?.id == attacker.id }) {
                    gameScene.hexMap.removeEntity(attackerNode)
                    attackerNode.removeFromParent()
                }
                player.removeArmy(attacker)
                resultMessage += "\n\n💀 Your army was destroyed!"
            }
        }
        
        showCombatResult(message: resultMessage)
    }
    
    /// Calculate casualties for an army based on loss percentage
    func calculateCasualties(army: Army, lossPercent: Double) -> [MilitaryUnitType: Int] {
        var casualties: [MilitaryUnitType: Int] = [:]
        
        for (unitType, count) in army.militaryComposition {
            let losses = Int(Double(count) * lossPercent)
            if losses > 0 {
                casualties[unitType] = losses
            }
        }
        
        return casualties
    }
    
    /// Apply casualties to an army
    func applyCasualties(to army: Army, casualties: [MilitaryUnitType: Int]) {
        for (unitType, count) in casualties {
            army.removeMilitaryUnits(unitType, count: count)
        }
    }
    
    /// Show combat result dialog
    func showCombatResult(message: String) {
        let alert = UIAlertController(
            title: "⚔️ Combat Complete",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Existing Methods
    
    func showTileInfoMenu(for coordinate: HexCoordinate) {
        var title = "Tile Info"
        var message = "Location: (\(coordinate.q), \(coordinate.r))"
        
        // Check if there's a building on this tile
        var buildingAtTile: BuildingNode? = nil

        let visibility = player.getVisibilityLevel(at: coordinate)
        
        switch visibility {
        case .unexplored:
            message = "Unexplored territory"
            
        case .explored:
            // Show last known information
            if let memory = player.fogOfWar?.getMemory(at: coordinate) {
                message += "\n\nTerrain: \(memory.terrain)"
                
                if let buildingSnapshot = memory.lastSeenBuilding {
                    title = "\(buildingSnapshot.buildingType.icon) \(buildingSnapshot.buildingType.displayName)"
                    message += "\n\n⚠️ Last Seen Information"
                    message += "\nThis building was here when you last explored this area."
                    message += "\nCurrent status unknown."
                }
            }
            
        case .visible:
            // Show current real-time information
            if let building = gameScene.hexMap.getBuilding(at: coordinate) {
                buildingAtTile = building
                
                // ✅ If there's a completed building owned by player, show custom view controller
                if building.state == .completed && building.owner?.id == player.id {
                    showBuildingDetailViewController(building: building)
                    return
                }
                
                // Otherwise show info in alert
                title = "\(building.buildingType.icon) \(building.buildingType.displayName)"
                message = ""
                
                switch building.state {
                case .planning:
                    message += "Status: Planning\n"
                case .constructing:
                    let progress = Int(building.constructionProgress * 100)
                    message += "Status: Under Construction (\(progress)%)\n"
                case .completed:
                    message += "Status: Completed ✅\n"
                    message += "Health: \(building.health)/\(building.maxHealth)\n"
                case .damaged:
                    message += "Status: Damaged ⚠️\n"
                    message += "Health: \(building.health)/\(building.maxHealth)\n"
                case .destroyed:
                    message += "Status: Destroyed ❌\n"
                }
                
                message += "\n\(building.buildingType.description)"
            }
            
            if buildingAtTile == nil, let resourcePoint = gameScene.hexMap.getResourcePoint(at: coordinate) {
                title = "\(resourcePoint.resourceType.icon) \(resourcePoint.resourceType.displayName)"
                message = resourcePoint.getDescription()
                
                if resourcePoint.isBeingGathered {
                    message += "\n\n🔨 Currently being gathered"
                }
            }
            
        }
        
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        let entitiesAtTile = gameScene.hexMap.entities.filter { $0.coordinate == coordinate }

        
        // Only allow actions on visible tiles
        if visibility == .visible {
            
            // ✅ FIX: Only show "Move Unit Here" if there are NO entities on this tile
            if entitiesAtTile.isEmpty {
                alert.addAction(UIAlertAction(title: "🚶 Move Unit Here", style: .default) { [weak self] _ in
                    self?.gameScene.initiateMove(to: coordinate)
                })
            }
        } else if visibility == .explored {
            if entitiesAtTile.isEmpty {
                alert.addAction(UIAlertAction(title: "🚶 Move Unit Here", style: .default) { [weak self] _ in
                    self?.gameScene.initiateMove(to: coordinate)
                })
            }
            
        }
        
        // Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.gameScene.deselectAll()
        })
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    func showBuildingDetailViewController(building: BuildingNode) {
        let detailVC = BuildingDetailViewController()
        detailVC.building = building
        detailVC.player = player
        detailVC.gameViewController = self
        detailVC.modalPresentationStyle = .pageSheet
        
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(detailVC, animated: true)
    }
    
    func showTileActionMenu(for coordinate: HexCoordinate) {
        // ✅ FIX: Get visibility level first
        let visibility = player.getVisibilityLevel(at: coordinate)
        
        // ✅ FIX: Filter entities - only show if tile is VISIBLE (not just explored)
        let entitiesAtTile = gameScene.hexMap.entities.filter { entity in
            entity.coordinate == coordinate && visibility == .visible
        }
        
        // If there are visible entities, show entity selection menu FIRST
        if !entitiesAtTile.isEmpty {
            showEntitySelectionMenu(at: coordinate, entities: entitiesAtTile)
            return
        }
        
        // Otherwise, show normal tile menu (building info, etc.)
        showTileInfoMenu(for: coordinate)
    }
    
    func formatArmyComposition(_ army: Army) -> String {
        var message = ""
        
        // Get total counts
        let oldSystemTotal = army.getUnitCount()
        let newSystemTotal = army.getTotalMilitaryUnits()
        let totalUnits = oldSystemTotal + newSystemTotal
        
        message += "Total Units: \(totalUnits)\n\n"
        
        // Show old unit system composition (if any)
        if oldSystemTotal > 0 {
            message += "📊 Unit Composition:\n"
            for (unitType, count) in army.unitComposition.sorted(by: { $0.key.displayName < $1.key.displayName }) {
                let percentage = totalUnits > 0 ? Int((Double(count) / Double(totalUnits)) * 100) : 0
                message += "\(unitType.icon) \(unitType.displayName): \(count) (\(percentage)%)\n"
            }
            message += "\n"
        }
        
        // Show new military system composition (if any)
        if newSystemTotal > 0 {
            message += "⚔️ Military Units:\n"
            for (unitType, count) in army.militaryComposition.sorted(by: { $0.key.displayName < $1.key.displayName }) {
                let percentage = totalUnits > 0 ? Int((Double(count) / Double(totalUnits)) * 100) : 0
                message += "\(unitType.icon) \(unitType.displayName): \(count) (\(percentage)%)\n"
            }
            message += "\n"
        }
        
        // Show combat stats
        message += "💪 Combat Stats:\n"
        message += "⚔️ Total Attack: \(army.getTotalStrength())\n"
        message += "🛡️ Total Defense: \(army.getTotalDefense())"
        
        return message
    }
    
    func showEntitySelectionMenu(at coordinate: HexCoordinate, entities: [EntityNode]) {
        // ✅ FIX: Double-check visibility and filter again
        let visibility = player.getVisibilityLevel(at: coordinate)
        
        guard visibility == .visible else {
            // Tile is explored but not visible - show tile info instead
            showTileInfoMenu(for: coordinate)
            return
        }
        
        // ✅ FIX: Only show entities that are actually visible
        let visibleEntities = entities.filter { entity in
            if let fogOfWar = player.fogOfWar {
                return fogOfWar.shouldShowEntity(entity.entity, at: coordinate)
            }
            return false
        }
        
        guard !visibleEntities.isEmpty else {
            // No visible entities - show tile info instead
            showTileInfoMenu(for: coordinate)
            return
        }
        
        var title = "Select Entity"
        var message = "Tile: (\(coordinate.q), \(coordinate.r))\n"
        
        // Check if there's also a building here
        if let building = gameScene.hexMap.getBuilding(at: coordinate) {
            message += "\n🏗️ Building: \(building.buildingType.displayName) (\(building.state))"
        }
        
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .actionSheet
        )
        
        // Add an action for each VISIBLE entity
        for entity in visibleEntities {
            var buttonTitle = ""
            var buttonStyle: UIAlertAction.Style = .default
            
            if entity.entityType == .villagerGroup {
                if let villagers = entity.entity as? VillagerGroup {
                    buttonTitle = "👷 \(villagers.name) (\(villagers.villagerCount) villagers)"
                } else {
                    buttonTitle = "👷 Villager Group"
                }
            } else if entity.entityType == .army {
                if let army = entity.entity as? Army {
                    let totalUnits = army.getTotalMilitaryUnits() + army.getUnitCount()
                    buttonTitle = "🛡️ \(army.name) (\(totalUnits) units)"
                } else {
                    buttonTitle = "🛡️ Army"
                }
            }
            
            alert.addAction(UIAlertAction(title: buttonTitle, style: buttonStyle) { [weak self] _ in
                self?.showEntityActionMenu(for: entity, at: coordinate)
            })
        }
        
        // Option to view tile/building info
        if let building = gameScene.hexMap.getBuilding(at: coordinate) {
            alert.addAction(UIAlertAction(title: "🏗️ View Building", style: .default) { [weak self] _ in
                self?.showTileInfoMenu(for: coordinate)
            })
        }
        
        // Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.gameScene.deselectAll()
        })
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    func showVillagerMenu(at coordinate: HexCoordinate, villagerGroup: EntityNode) {
        guard let villagers = villagerGroup.entity as? VillagerGroup else { return }
        
        var message = "Villagers: \(villagers.villagerCount)\n"
        message += "Status: \(villagers.currentTask.displayName)"
        
        let alert = UIAlertController(
            title: "👷 \(villagers.name)",
            message: message,
            preferredStyle: .actionSheet
        )
        
        // Check if there's already a building on this tile
        let buildingExists = gameScene.hexMap.getBuilding(at: coordinate) != nil
        
        // Build action
        let buildAction = UIAlertAction(title: "🗠️ Build", style: .default) { [weak self] _ in
            self?.showBuildingMenu(at: coordinate, villagerGroup: villagerGroup)
        }
        buildAction.isEnabled = !buildingExists
        alert.addAction(buildAction)
        
        // If building exists, show why it's disabled
        if buildingExists {
            alert.addAction(UIAlertAction(title: "ℹ️ Building Already Exists Here", style: .default, handler: nil))
        }
        
        // Move action
        alert.addAction(UIAlertAction(title: "🚶 Move", style: .default) { [weak self] _ in
            // Deselect and wait for next tile click to move
            self?.gameScene.deselectAll()
            // The user will now click another tile to move there
        })
        
        // Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.gameScene.deselectAll()
        })
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    func showBuildingMenu(at coordinate: HexCoordinate, villagerGroup: EntityNode?) {
        
        let alert = UIAlertController(
            title: "🗠️ Select Building",
            message: "Choose what to build at (\(coordinate.q), \(coordinate.r))",
            preferredStyle: .actionSheet
        )
        
        // Group buildings by category
        let economicBuildings = BuildingType.allCases.filter { $0.category == .economic }
        let militaryBuildings = BuildingType.allCases.filter { $0.category == .military }
        
        // Economic Buildings Section
        for buildingType in economicBuildings {
            let canAfford = player.canAfford(buildingType)
            let costString = formatBuildingCost(buildingType)
            let title = "\(buildingType.icon) \(buildingType.displayName) - \(costString)"
            
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.showBuildingConfirmation(buildingType: buildingType, at: coordinate)
            }
            
            // Disable if can't afford
            action.isEnabled = canAfford
            alert.addAction(action)
        }
        
        // Separator
        alert.addAction(UIAlertAction(title: "--- Military Buildings ---", style: .default, handler: nil))
        
        // Military Buildings Section
        for buildingType in militaryBuildings {
            let canAfford = player.canAfford(buildingType)
            let costString = formatBuildingCost(buildingType)
            let title = "\(buildingType.icon) \(buildingType.displayName) - \(costString)"
            
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.showBuildingConfirmation(buildingType: buildingType, at: coordinate)
            }
            
            // Disable if can't afford
            action.isEnabled = canAfford
            alert.addAction(action)
        }
        
        // Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.gameScene.deselectAll()
        })
        
        // For iPad - need to set source
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    func showBuildingConfirmation(buildingType: BuildingType, at coordinate: HexCoordinate) {
        let canAfford = player.canAfford(buildingType)
        
        var message = "\(buildingType.description)\n\n"
        message += "Cost:\n"
        
        for (resourceType, amount) in buildingType.buildCost.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let current = player.getResource(resourceType)
            let statusIcon = current >= amount ? "✓" : "✗"
            message += "\(statusIcon) \(resourceType.icon) \(resourceType.displayName): \(amount) (You have: \(current))\n"
        }
        
        message += "\nBuild Time: \(Int(buildingType.buildTime))s"
        
        if let bonus = buildingType.resourceBonus {
            message += "\n\nBonus:"
            for (resourceType, amount) in bonus {
                message += "\n+\(String(format: "%.1f", amount)) \(resourceType.displayName)/s"
            }
        }
        
        let alert = UIAlertController(
            title: "Build \(buildingType.displayName)?",
            message: message,
            preferredStyle: .alert
        )
        
        // Confirm action
        let confirmAction = UIAlertAction(title: "Build", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.gameScene.placeBuilding(type: buildingType, at: coordinate, owner: self.player)
            self.gameScene.deselectAll()
        }
        confirmAction.isEnabled = canAfford
        alert.addAction(confirmAction)
        
        // Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func formatBuildingCost(_ buildingType: BuildingType) -> String {
        let costs = buildingType.buildCost.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        return costs.map { "\($0.key.icon)\($0.value)" }.joined(separator: " ")
    }
    
    func updateResourceDisplay() {
        for (resourceType, label) in resourceLabels {
            let amount = player.getResource(resourceType)
            let rate = player.getCollectionRate(resourceType)
            label.text = "\(resourceType.icon) \(amount) (+\(String(format: "%.1f", rate))/s)"
        }
    }
    
    func setupUI() {
        // Resource Panel
        resourcePanel = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 120))
        resourcePanel.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        resourcePanel.autoresizingMask = [.flexibleWidth]
        
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 10, width: 250, height: 30))
        titleLabel.text = "Hex RTS Game"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .white
        resourcePanel.addSubview(titleLabel)
        
        // ✅ ADD: Commander Button (top right)
        commanderButton = UIButton(frame: CGRect(x: view.bounds.width - 160, y: 10, width: 140, height: 35))
        commanderButton.setTitle("👤 Commanders", for: .normal)
        commanderButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        commanderButton.backgroundColor = UIColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 1.0)
        commanderButton.layer.cornerRadius = 8
        commanderButton.addTarget(self, action: #selector(showCommandersScreen), for: .touchUpInside)
        commanderButton.autoresizingMask = [.flexibleLeftMargin]
        resourcePanel.addSubview(commanderButton)
        
        // ✅ ADD: Combat History Button (below commander button)
        combatHistoryButton = UIButton(frame: CGRect(x: view.bounds.width - 160, y: 55, width: 140, height: 35))
        combatHistoryButton.setTitle("⚔️ Battles", for: .normal)
        combatHistoryButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        combatHistoryButton.backgroundColor = UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
        combatHistoryButton.layer.cornerRadius = 8
        combatHistoryButton.addTarget(self, action: #selector(showCombatHistoryScreen), for: .touchUpInside)
        combatHistoryButton.autoresizingMask = [.flexibleLeftMargin]
        resourcePanel.addSubview(combatHistoryButton)
        
        // Resource labels (2x2 grid)
        let resourceTypes: [ResourceType] = [.wood, .food, .stone, .ore]
        let labelWidth: CGFloat = 150
        let labelHeight: CGFloat = 25
        let startY: CGFloat = 45
        let horizontalSpacing: CGFloat = 160
        let verticalSpacing: CGFloat = 30
        
        for (index, resourceType) in resourceTypes.enumerated() {
            let row = index / 2
            let col = index % 2
            let x: CGFloat = 20 + CGFloat(col) * horizontalSpacing
            let y: CGFloat = startY + CGFloat(row) * verticalSpacing
            
            let label = UILabel(frame: CGRect(x: x, y: y, width: labelWidth, height: labelHeight))
            label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            label.textColor = .white
            label.text = "\(resourceType.icon) 0 (+0.0/s)"
            resourcePanel.addSubview(label)
            resourceLabels[resourceType] = label
        }
        
        view.addSubview(resourcePanel)
        
        // Bottom instruction panel
        let bottomView = UIView(frame: CGRect(x: 0, y: view.bounds.height - 60, width: view.bounds.width, height: 60))
        bottomView.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        bottomView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        
        let instructionLabel = UILabel(frame: CGRect(x: 20, y: 15, width: view.bounds.width - 40, height: 30))
        instructionLabel.text = "Tap villager → Build | Tap tile → Move"
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 16)
        instructionLabel.textAlignment = .center
        instructionLabel.autoresizingMask = [.flexibleWidth]
        bottomView.addSubview(instructionLabel)
        
        view.addSubview(bottomView)
        
        let menuButton = UIButton(frame: CGRect(x: view.bounds.width - 120, y: 30, width: 100, height: 40))
        menuButton.setTitle("☰ Menu", for: .normal)
        menuButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        menuButton.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
        menuButton.layer.cornerRadius = 8
        menuButton.addTarget(self, action: #selector(showGameMenu), for: .touchUpInside)
        view.addSubview(menuButton)
        
        let trainingButton = UIButton(frame: CGRect(x: view.bounds.width - 310, y: 10, width: 140, height: 35))
        trainingButton.setTitle("🎓 Training", for: .normal)
        trainingButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        trainingButton.backgroundColor = UIColor(red: 0.4, green: 0.6, blue: 0.3, alpha: 1.0)
        trainingButton.layer.cornerRadius = 8
        trainingButton.addTarget(self, action: #selector(showTrainingOverview), for: .touchUpInside)
        trainingButton.autoresizingMask = [.flexibleLeftMargin]
        resourcePanel.addSubview(trainingButton)
    }
    
    @objc func showGameMenu() {
        let alert = UIAlertController(title: "⚙️ Game Menu", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "💾 Save Game", style: .default) { [weak self] _ in
            self?.manualSave()
        })
        
        alert.addAction(UIAlertAction(title: "📂 Load Game", style: .default) { [weak self] _ in
            self?.confirmLoad()
        })
        
        alert.addAction(UIAlertAction(title: "🏠 Main Menu", style: .default) { [weak self] _ in
            self?.returnToMainMenu()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.width - 70, y: 50, width: 0, height: 0)
            popover.permittedArrowDirections = .up
        }
        
        present(alert, animated: true)
    }

    func confirmLoad() {
        let alert = UIAlertController(
            title: "⚠️ Load Game?",
            message: "Any unsaved progress will be lost. Continue?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Load", style: .destructive) { [weak self] _ in
            self?.loadGame()
        })
        present(alert, animated: true)
    }

    func returnToMainMenu() {
        // Save before returning
        autoSaveGame()
        
        dismiss(animated: true)
    }
    
    func showTrainingMenu(for building: BuildingNode) {
        let alert = UIAlertController(
            title: "🎖️ Train Units",
            message: "Select unit type to train at \(building.buildingType.displayName)\n\n\(building.getGarrisonDescription())",
            preferredStyle: .actionSheet
        )
        
        // Get units that can be trained in this building
        let availableUnits = MilitaryUnitType.allCases.filter { $0.trainingBuilding == building.buildingType }
        
        for unitType in availableUnits {
            let title = "\(unitType.icon) \(unitType.displayName)"
            
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.showUnitTrainingSlider(unitType: unitType, building: building)
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    func showVillagerTrainingConfirmation(quantity: Int, building: BuildingNode) {
        let villagerCost: [ResourceType: Int] = [.food: 50]
        
        var message = "Train new villagers to gather resources and construct buildings.\n\n"
        message += "Quantity: \(quantity)\n\n"
        message += "Total Cost:\n"
        
        for (resourceType, unitCost) in villagerCost.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let totalCost = unitCost * quantity
            let current = player.getResource(resourceType)
            let statusIcon = current >= totalCost ? "✓" : "✗"
            message += "\(statusIcon) \(resourceType.icon) \(resourceType.displayName): \(totalCost) (You have: \(current))\n"
        }
        
        let totalTime = Int(15.0 * Double(quantity))
        let minutes = totalTime / 60
        let seconds = totalTime % 60
        message += "\nTotal Training Time: \(minutes)m \(seconds)s"
        
        message += "\n\n💡 Trained villagers will be added to the building's garrison."
        
        let alert = UIAlertController(
            title: "Train \(quantity)x Villagers?",
            message: message,
            preferredStyle: .alert
        )
        
        let canAfford = villagerCost.allSatisfy { resourceType, unitCost in
            player.hasResource(resourceType, amount: unitCost * quantity)
        }
        
        let confirmAction = UIAlertAction(title: "Train", style: .default) { [weak self] _ in
            self?.startVillagerTraining(quantity: quantity, building: building)
        }
        confirmAction.isEnabled = canAfford
        alert.addAction(confirmAction)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    func startVillagerTraining(quantity: Int, building: BuildingNode) {
        let villagerCost: [ResourceType: Int] = [.food: 50]
        
        // Deduct resources
        for (resourceType, unitCost) in villagerCost {
            let totalCost = unitCost * quantity
            player.removeResource(resourceType, amount: totalCost)
        }
        
        // Start training
        let currentTime = Date().timeIntervalSince1970
        building.startVillagerTraining(quantity: quantity, at: currentTime)
        
        updateResourceDisplay()
        
        showSimpleAlert(
            title: "✅ Training Started",
            message: "Training \(quantity) villagers at \(building.buildingType.displayName)"
        )
        
        print("✅ Started training \(quantity) villagers at \(building.buildingType.displayName)")
    }
    
    func startTraining(unitType: MilitaryUnitType, quantity: Int, building: BuildingNode) {
        // Deduct resources
        for (resourceType, unitCost) in unitType.trainingCost {
            let totalCost = unitCost * quantity
            player.removeResource(resourceType, amount: totalCost)
        }
        
        // Start training
        let currentTime = Date().timeIntervalSince1970
        building.startTraining(unitType: unitType, quantity: quantity, at: currentTime)
        
        updateResourceDisplay()
        
        print("Started training \(quantity)x \(unitType.displayName) at \(building.buildingType.displayName)")
    }
    
    func formatUnitCost(_ unitType: MilitaryUnitType, quantity: Int) -> String {
        let costs = unitType.trainingCost.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        return costs.map { "\($0.key.icon)\($0.value * quantity)" }.joined(separator: " ")
    }
    
    
    func deployArmy(from building: BuildingNode, units: [MilitaryUnitType: Int]) {
        guard let spawnCoord = gameScene.hexMap.findNearestWalkable(to: building.coordinate) else {
            print("No valid location to deploy army")
            return
        }
        
        // ✅ Create commander for new army
        let commander = Commander.createRandom()
        
        // ✅ Pass commander to Army init
        let army = Army(name: "Army", coordinate: spawnCoord, commander: commander, owner: player)
        
        // Transfer units from garrison
        for (unitType, count) in units {
            let removed = building.removeFromGarrison(unitType: unitType, quantity: count)
            if removed > 0 {
                army.addMilitaryUnits(unitType, count: removed)
            }
        }
        
        // Rest of function remains the same...
        let armyEntity = MapEntity(id: army.id, name: army.name, entityType: .army)
        let armyNode = EntityNode(coordinate: spawnCoord, entityType: .army, entity: armyEntity)
        let position = HexMap.hexToPixel(q: spawnCoord.q, r: spawnCoord.r)
        armyNode.position = position
        
        gameScene.hexMap.addEntity(armyNode)
        gameScene.entitiesNode.addChild(armyNode)
        player.addArmy(army)
        
        print("✅ Deployed army led by \(commander.name) with \(army.getTotalMilitaryUnits()) units")
    }
    
    func showArmyEditor(for army: Army, at coordinate: HexCoordinate) {
        // Check if there are garrisoned units at this location
        let building = gameScene.hexMap.getBuilding(at: coordinate)
        let garrisonedUnits = building?.garrisonedUnits ?? [:]
        let hasGarrison = !garrisonedUnits.isEmpty
        
        var messageText = "\(army.name)\nTotal Units: \(army.getUnitCount())/200"
        if hasGarrison {
            let garrisonCount = building?.getTotalGarrisonedUnits() ?? 0
            messageText += "\n\nGarrisoned Units: \(garrisonCount)"
            messageText += "\nTap unit counts to add/remove from army"
        }
        
        let alert = UIAlertController(
            title: "✏️ Edit Army",
            message: messageText,
            preferredStyle: .alert
        )
        
        // Get all military unit types
        let militaryUnits: [UnitType] = [.soldier, .archer, .cavalry, .scout, .tank, .catapult]
        
        // Add input fields for each unit type
        var textFields: [UnitType: UITextField] = [:]
        
        for unitType in militaryUnits {
            let currentCount = army.getUnitCount(ofType: unitType)
            let garrisonCount = garrisonedUnits[unitType] ?? 0
            
            let placeholderText: String
            if garrisonCount > 0 {
                placeholderText = "\(unitType.icon) \(unitType.displayName) (Garrison: \(garrisonCount))"
            } else {
                placeholderText = "\(unitType.icon) \(unitType.displayName)"
            }
            
            alert.addTextField { textField in
                textField.placeholder = placeholderText
                textField.text = "\(currentCount)"
                textField.keyboardType = .numberPad
                textFields[unitType] = textField
            }
        }
        
        // Save action
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            // Calculate new composition
            var newComposition: [UnitType: Int] = [:]
            var totalUnits = 0
            
            for unitType in militaryUnits {
                if let textField = textFields[unitType],
                   let text = textField.text,
                   let count = Int(text), count > 0 {
                    newComposition[unitType] = count
                    totalUnits += count
                }
            }
            
            if totalUnits > army.getMaxArmySize() {
                self.showArmySizeError(requested: totalUnits, maxSize: army.getMaxArmySize())
                return
            }
            
            // Check if player can afford the units (or can use garrison)
            if !self.canAffordArmyComposition(newComposition, currentArmy: army, garrisonedUnits: garrisonedUnits) {
                self.showInsufficientResourcesError()
                return
            }
            
            // Update army composition (with garrison support)
            self.updateArmyComposition(army, newComposition: newComposition, building: building)
            
            // Show success message
            self.showArmyUpdateSuccess(army: army)
            
            // Update resource display
            self.updateResourceDisplay()
        })
        
        // Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func canAffordArmyComposition(_ newComposition: [UnitType: Int], currentArmy: Army, garrisonedUnits: [UnitType: Int]) -> Bool {
        // Calculate units to add (difference between new and current)
        var unitsToAdd: [UnitType: Int] = [:]
        
        for (unitType, newCount) in newComposition {
            let currentCount = currentArmy.getUnitCount(ofType: unitType)
            if newCount > currentCount {
                unitsToAdd[unitType] = newCount - currentCount
            }
            
        }
        
        // Check if we can use garrisoned units first
        for (unitType, countNeeded) in unitsToAdd {
            let garrisonAvailable = garrisonedUnits[unitType] ?? 0
            let needToBuy = max(0, countNeeded - garrisonAvailable)
            
            if needToBuy > 0 {
                // Check if player can afford the additional units
                let cost = unitType.trainingCost
                for (resourceType, resourceAmount) in cost {
                    let totalCost = resourceAmount * needToBuy
                    if !player.hasResource(resourceType, amount: totalCost) {
                        return false
                    }
                }
            }
        }
        
        return true
    }
    
    private func updateArmyComposition(_ army: Army, newComposition: [UnitType: Int], building: BuildingNode?) {
        // Calculate changes and handle garrison/purchase
        for (unitType, newCount) in newComposition {
            let currentCount = army.getUnitCount(ofType: unitType)
            
            if newCount > currentCount {
                // Adding units - use garrison first, then purchase
                let unitsToAdd = newCount - currentCount
                var unitsAdded = 0
                
                // Try to ungarrison units first
                if let building = building {
                    let ungarrisoned = building.ungarrisonUnits(unitType, count: unitsToAdd)
                    unitsAdded += ungarrisoned
                }
                
                // Purchase remaining units if needed
                let unitsToBuy = unitsToAdd - unitsAdded
                if unitsToBuy > 0 {
                    let cost = unitType.trainingCost
                    for (resourceType, resourceAmount) in cost {
                        let totalCost = resourceAmount * unitsToBuy
                        player.removeResource(resourceType, amount: totalCost)
                    }
                }
                
                // Add all units to army
                army.addUnits(unitType, count: unitsToAdd)
                
            } else if newCount < currentCount {
                // Removing units - optionally garrison them
                let unitsToRemove = currentCount - newCount
                army.removeUnits(unitType, count: unitsToRemove)
                
                // Try to garrison removed units
                if let building = building, building.hasGarrisonSpace(for: unitsToRemove) {
                    building.garrisonUnits(unitType, count: unitsToRemove)
                }
            }
        }
        
        // Remove unit types that were reduced to 0
        let allMilitaryTypes: [UnitType] = [.soldier, .archer, .cavalry, .scout, .tank, .catapult]
        for unitType in allMilitaryTypes {
            if newComposition[unitType] == nil || newComposition[unitType] == 0 {
                let removed = army.removeUnits(unitType, count: army.getUnitCount(ofType: unitType))
                
                // Try to garrison removed units
                if removed > 0, let building = building, building.hasGarrisonSpace(for: removed) {
                    building.garrisonUnits(unitType, count: removed)
                }
            }
        }
    }
    
    private func showArmySizeError(requested: Int, maxSize: Int) {
        let alert = UIAlertController(
            title: "⚠️ Army Too Large",
            message: "Your army can have a maximum of \(maxSize) units (based on commander rank).\nYou requested \(requested) units.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showInsufficientResourcesError() {
        let alert = UIAlertController(
            title: "⚠️ Insufficient Resources",
            message: "You don't have enough resources to train these units.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showArmyUpdateSuccess(army: Army) {
        let alert = UIAlertController(
            title: "✅ Army Updated",
            message: "\(army.name) now has \(army.getUnitCount()) units.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Garrison Management
    
    func showGarrisonMenu(for building: BuildingNode) {
        let garrisonCount = building.getTotalGarrisonedUnits()
        let capacity = building.getGarrisonCapacity()
        
        var message = "Garrisoned Units: \(garrisonCount)/\(capacity)\n\n"
        
        if garrisonCount > 0 {
            for (unitType, count) in building.garrisonedUnits.sorted(by: { $0.key.displayName < $1.key.displayName }) {
                message += "\(unitType.icon) \(unitType.displayName): \(count)\n"
            }
            
            // ✅ ADD INFO: Explain how to use garrisoned units
            message += "\n💡 Use 'Reinforce Army' to add these units to an existing army."
        } else {
            message += "No units garrisoned."
        }
        
        let alert = UIAlertController(
            title: "🏰 Garrison",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func showArmyDetails(_ army: Army, at coordinate: HexCoordinate) {
        let message = formatArmyComposition(army)
        
        let alert = UIAlertController(
            title: "🛡️ \(army.name)",
            message: message,
            preferredStyle: .alert
        )
        
        // Edit army option
        alert.addAction(UIAlertAction(title: "✏️ Edit Army", style: .default) { [weak self] _ in
            self?.showArmyEditor(for: army, at: coordinate)
        })
        
        // Select for movement option
        alert.addAction(UIAlertAction(title: "🚶 Select to Move", style: .default) { [weak self] _ in
            guard let self = self else { return }
            // Find the entity node for this army
            if let entityNode = self.gameScene.hexMap.entities.first(where: {
                ($0.entity as? Army)?.id == army.id
            }) {
                self.gameScene.selectedEntity = entityNode
                self.showSimpleAlert(title: "Army Selected", message: "Tap a tile to move this army there")
            }
        })
        
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // Add this helper method too:
    func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    
    func showEntitySelectionForMove(to coordinate: HexCoordinate, availableEntities: [EntityNode]) {
        // ✅ FIX: Filter to only show entities owned by the player
        let playerEntities = availableEntities.filter { entity in
            entity.entity.owner?.id == player.id
        }
        
        guard !playerEntities.isEmpty else {
            showSimpleAlert(title: "No Units Available", message: "You don't have any units that can move.")
            return
        }
        
        let alert = UIAlertController(
            title: "Select Entity to Move",
            message: "Choose which entity to move to (\(coordinate.q), \(coordinate.r))",
            preferredStyle: .actionSheet
        )
        
        for entity in playerEntities {
            let distance = entity.coordinate.distance(to: coordinate)
            var title = "\(entity.entityType.icon) "
            
            if entity.entityType == .army, let army = entity.entity as? Army {
                let totalUnits = army.getUnitCount() + army.getTotalMilitaryUnits()
                title += "\(army.name) (\(totalUnits) units) - Distance: \(distance)"
            } else if entity.entityType == .villagerGroup, let villagers = entity.entity as? VillagerGroup {
                title += "\(villagers.name) (\(villagers.villagerCount) villagers) - Distance: \(distance)"
            }
            
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                // ✅ FIX: Directly move the entity instead of opening action menu
                self?.gameScene.moveEntity(entity, to: coordinate)
                self?.gameScene.deselectAll()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.gameScene.deselectAll()
        })
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    func showReinforcementSourceSelection(for army: Army) {
        let buildingsWithGarrison = player.buildings.filter { $0.getTotalGarrisonedUnits() > 0 }
        
        let alert = UIAlertController(
            title: "🔄 Select Garrison Source",
            message: "Choose which building to reinforce \(army.name) from:",
            preferredStyle: .actionSheet
        )
        
        for building in buildingsWithGarrison {
            let garrisonCount = building.getTotalGarrisonedUnits()
            let title = "\(building.buildingType.icon) \(building.buildingType.displayName) (\(garrisonCount) units) - (\(building.coordinate.q), \(building.coordinate.r))"
            
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.showReinforcementUnitSelection(from: building, to: army)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    func showReinforcementTargetSelection(from building: BuildingNode) {
        let armiesOnField = player.getArmies().filter { army in
            // Include all armies, even empty ones
            return true
        }
        
        guard !armiesOnField.isEmpty else {
            showSimpleAlert(title: "No Armies", message: "You don't have any armies to reinforce. Recruit a commander first!")
            return
        }
        
        let alert = UIAlertController(
            title: "⚔️ Select Army to Reinforce",
            message: "Choose which army to reinforce from \(building.buildingType.displayName):\n\nGarrison: \(building.getTotalGarrisonCount()) units available",
            preferredStyle: .actionSheet
        )
        
        for army in armiesOnField {
            let unitCount = army.getTotalMilitaryUnits()
            let commanderName = army.commander?.name ?? "No Commander"
            let distance = army.coordinate.distance(to: building.coordinate)
            
            let title = "🛡️ \(army.name) - \(commanderName) (\(unitCount) units) - Distance: \(distance)"
            
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.showReinforcementUnitSelection(from: building, to: army)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    /// Shows a detailed menu with sliders to select which units and how many to transfer
    func showReinforcementUnitSelection(from building: BuildingNode, to army: Army) {
        let alert = UIAlertController(
            title: "🔄 Reinforce \(army.name)",
            message: "Select units from \(building.buildingType.displayName) garrison\nCurrent Army Size: \(army.getTotalMilitaryUnits()) units",
            preferredStyle: .alert
        )
        
        // Create a container view controller for custom UI with sliders
        let containerVC = UIViewController()
        containerVC.preferredContentSize = CGSize(width: 270, height: 350)
        
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 270, height: 350))
        scrollView.backgroundColor = .clear
        
        let contentView = UIView()
        var yOffset: CGFloat = 10
        
        // Store slider references
        var unitSliders: [MilitaryUnitType: UISlider] = [:]
        var unitLabels: [MilitaryUnitType: UILabel] = [:]
        
        // Get garrison and create sliders for each unit type
        let sortedGarrison = building.garrison.sorted(by: { $0.key.displayName < $1.key.displayName })
        
        for (unitType, available) in sortedGarrison {
            // Unit type label
            let titleLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: 230, height: 20))
            titleLabel.text = "\(unitType.icon) \(unitType.displayName)"
            titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            titleLabel.textColor = .label
            contentView.addSubview(titleLabel)
            yOffset += 25
            
            // Slider
            let slider = UISlider(frame: CGRect(x: 20, y: yOffset, width: 230, height: 30))
            slider.minimumValue = 0
            slider.maximumValue = Float(available)
            slider.value = 0
            slider.isContinuous = true
            slider.tag = unitType.hashValue // Store unit type in tag
            contentView.addSubview(slider)
            unitSliders[unitType] = slider
            yOffset += 35
            
            // Count label
            let countLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: 230, height: 20))
            countLabel.text = "0 / \(available) units"
            countLabel.font = UIFont.systemFont(ofSize: 12)
            countLabel.textColor = .secondaryLabel
            countLabel.textAlignment = .center
            contentView.addSubview(countLabel)
            unitLabels[unitType] = countLabel
            yOffset += 30
            
            // Update label when slider moves
            slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        }
        
        // Store references in objc associated objects so we can access in selector
        objc_setAssociatedObject(self, &AssociatedKeys.unitLabels, unitLabels, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.garrisonData, building.garrison, .OBJC_ASSOCIATION_RETAIN)
        
        contentView.frame = CGRect(x: 0, y: 0, width: 270, height: yOffset)
        scrollView.addSubview(contentView)
        scrollView.contentSize = CGSize(width: 270, height: yOffset)
        
        containerVC.view.addSubview(scrollView)
        alert.setValue(containerVC, forKey: "contentViewController")
        
        // Reinforce action
        alert.addAction(UIAlertAction(title: "Reinforce", style: .default) { [weak self] _ in
            var unitsToTransfer: [MilitaryUnitType: Int] = [:]
            
            for (unitType, slider) in unitSliders {
                let count = Int(slider.value)
                if count > 0 {
                    unitsToTransfer[unitType] = count
                }
            }
            
            if !unitsToTransfer.isEmpty {
                self?.reinforceArmy(army, from: building, with: unitsToTransfer)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc func sliderValueChanged(_ slider: UISlider) {
        // Get the stored labels dictionary
        guard let labelsDict = objc_getAssociatedObject(self, &AssociatedKeys.unitLabels) as? [MilitaryUnitType: UILabel],
              let garrisonDict = objc_getAssociatedObject(self, &AssociatedKeys.garrisonData) as? [MilitaryUnitType: Int] else {
            return
        }
        
        // Find which unit type this slider corresponds to
        for (unitType, label) in labelsDict {
            let available = garrisonDict[unitType] ?? 0
            let sliderValue = Int(slider.value)
            label.text = "\(sliderValue) / \(available) units"
        }
    }
    
    /// Actually performs the reinforcement transfer
    func reinforceArmy(_ army: Army, from building: BuildingNode, with units: [MilitaryUnitType: Int]) {
        var totalTransferred = 0
        for (unitType, count) in units {
            let removed = building.removeFromGarrison(unitType: unitType, quantity: count)
            if removed > 0 {
                army.addMilitaryUnits(unitType, count: removed)
                totalTransferred += removed
            }
        }
        
        if totalTransferred > 0 {
            let alert = UIAlertController(
                title: "✅ Reinforcement Complete",
                message: "Transferred \(totalTransferred) units to \(army.name)\nNew Army Size: \(army.getTotalMilitaryUnits()) units",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            
            print("✅ Reinforced \(army.name) with \(totalTransferred) units from \(building.buildingType.displayName)")
        }
    }
    
    func showMoveSelectionMenu(to coordinate: HexCoordinate, from entities: [EntityNode]) {
        let alert = UIAlertController(
            title: "🚶 Select Unit to Move",
            message: "Choose which unit to move to (\(coordinate.q), \(coordinate.r))",
            preferredStyle: .actionSheet
        )
        
        // ✅ FIX: Filter to only show player-owned, visible entities
        let validEntities = entities.filter { entity in
            // Must be owned by player
            guard entity.entity.owner?.id == player.id else { return false }
            
            // Entity's current location must be visible
            let currentVisibility = player.getVisibilityLevel(at: entity.coordinate)
            return currentVisibility == .visible
        }
        
        guard !validEntities.isEmpty else {
            showSimpleAlert(title: "No Units Available", message: "You don't have any visible units that can move.")
            return
        }
        
        for entity in validEntities {
            let distance = entity.coordinate.distance(to: coordinate)
            var title = "\(entity.entityType.icon) "
            
            if entity.entityType == .army, let army = entity.entity as? Army {
                let totalUnits = army.getUnitCount() + army.getTotalMilitaryUnits()
                title += "\(army.name) (\(totalUnits) units) - Distance: \(distance)"
            } else if entity.entityType == .villagerGroup, let villagers = entity.entity as? VillagerGroup {
                title += "\(villagers.name) (\(villagers.villagerCount) villagers) - Distance: \(distance)"
            }
            
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.gameScene.moveEntity(entity, to: coordinate)
                self?.gameScene.deselectAll()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.gameScene.deselectAll()
        })
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    func showVillagerSelectionForGathering(resourcePoint: ResourcePointNode) {
        
        let availableVillagers = player.getVillagerGroups().filter {
            $0.coordinate.distance(to: resourcePoint.coordinate) <= 10
        }
        
        guard !availableVillagers.isEmpty else {
            showSimpleAlert(title: "No Villagers", message: "No idle villagers available nearby to gather resources.")
            return
        }
            
        let alert = UIAlertController(
            title: "Select Villagers",
            message: "Choose which villager group to gather \(resourcePoint.resourceType.displayName)\n\nRemaining: \(resourcePoint.remainingAmount)",
            preferredStyle: .actionSheet
        )
        
        for villagerGroup in availableVillagers {
            let distance = villagerGroup.coordinate.distance(to: resourcePoint.coordinate)
            let title = "👷 \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers) - Distance: \(distance)"
            
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.assignVillagersToGather(villagerGroup: villagerGroup, resourcePoint: resourcePoint)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
        
    func assignVillagersToGather(villagerGroup: VillagerGroup, resourcePoint: ResourcePointNode) {
        // Assign task
        villagerGroup.assignTask(.gatheringResource(resourcePoint), target: resourcePoint.coordinate)
        resourcePoint.startGathering(by: villagerGroup)
        
        // ✅ FIX: Apply collection rate bonus when starting to gather
        let resourceYield = resourcePoint.resourceType.resourceYield
        let gatherRate = resourcePoint.resourceType.gatherRate
        player.increaseCollectionRate(resourceYield, amount: gatherRate)
        print("✅ Increased \(resourceYield.displayName) collection rate by \(gatherRate)/s")
        
        // Find entity node and move to resource
        if let entityNode = gameScene.hexMap.entities.first(where: {
            ($0.entity as? VillagerGroup)?.id == villagerGroup.id
        }) {
            gameScene.moveEntity(entityNode, to: resourcePoint.coordinate)
        }
        
        showSimpleAlert(
            title: "✅ Gathering Started",
            message: "\(villagerGroup.name) will gather \(resourcePoint.resourceType.displayName) (\(resourcePoint.resourceType.resourceYield.icon) +\(Int(resourcePoint.resourceType.gatherRate))/s)"
        )
        
        print("✅ Assigned \(villagerGroup.name) to gather \(resourcePoint.resourceType.displayName)")
    }




    func showArmySelectionForHunting(resourcePoint: ResourcePointNode) {
        let availableArmies = player.getArmies().filter { $0.hasMilitaryUnits() }
        
        guard !availableArmies.isEmpty else {
            showSimpleAlert(title: "No Armies", message: "No armies available to hunt.")
            return
        }
        
        let alert = UIAlertController(
            title: "⚔️ Hunt \(resourcePoint.resourceType.displayName)",
            message: resourcePoint.getDescription(),
            preferredStyle: .actionSheet
        )
        
        for army in availableArmies {
            let distance = army.coordinate.distance(to: resourcePoint.coordinate)
            let totalUnits = army.getTotalMilitaryUnits()
            let title = "🛡️ \(army.name) (\(totalUnits) units) - Distance: \(distance)"
            
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.huntAnimal(army: army, resourcePoint: resourcePoint)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }

    func huntAnimal(army: Army, resourcePoint: ResourcePointNode) {
        guard resourcePoint.resourceType.isHuntable else { return }
        
        // Calculate combat
        let armyAttack = army.getModifiedStrength()
        let animalDefense = resourcePoint.resourceType.defensePower
        let animalAttack = resourcePoint.resourceType.attackPower
        let armyDefense = army.getModifiedDefense()
        
        // Simple combat calculation
        let netDamage = max(1, armyAttack - animalDefense)
        let isDead = resourcePoint.takeDamage(netDamage)
        
        if isDead {
            // Animal killed - award food
            let foodGained = resourcePoint.remainingAmount
            player.addResource(.food, amount: foodGained)
            updateResourceDisplay()
            
            // Remove resource point
            gameScene.hexMap.removeResourcePoint(resourcePoint)
            resourcePoint.removeFromParent()
            
            showSimpleAlert(
                title: "🎉 Hunt Successful",
                message: "\(army.name) hunted the \(resourcePoint.resourceType.displayName)\nGained: 🌾 \(foodGained) Food"
            )
            
            print("✅ Army hunted \(resourcePoint.resourceType.displayName) - gained \(foodGained) food")
        } else {
            showSimpleAlert(
                title: "⚔️ Combat",
                message: "The \(resourcePoint.resourceType.displayName) took \(netDamage) damage\nRemaining health: \(resourcePoint.currentHealth)/\(resourcePoint.resourceType.health)"
            )
        }
    }
    
    @objc func showCommandersScreen() {
        let commandersVC = CommandersViewController()
        commandersVC.player = player
        commandersVC.hexMap = gameScene.hexMap  // ✅ ADD THIS
        commandersVC.gameScene = gameScene      // ✅ ADD THIS
        commandersVC.modalPresentationStyle = .fullScreen
        present(commandersVC, animated: true)
        print("👤 Opening Commanders screen")
    }

    @objc func showCombatHistoryScreen() {
        let combatHistoryVC = CombatHistoryViewController()
        combatHistoryVC.modalPresentationStyle = .fullScreen
        present(combatHistoryVC, animated: true)
        print("⚔️ Opening Combat History screen")
    }
    
    func setupAutoSave() {
        // Start auto-save timer
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            self?.autoSaveGame()
        }
        print("⏰ Auto-save enabled (every \(Int(autoSaveInterval))s)")
    }

    func autoSaveGame() {
        guard let player = player,
              let hexMap = gameScene.hexMap,
              !gameScene.allGamePlayers.isEmpty else {
            print("⚠️ Cannot auto-save - game not ready")
            return
        }
        
        let success = GameSaveManager.shared.saveGame(
            hexMap: hexMap,
            player: player,
            allPlayers: gameScene.allGamePlayers
        )
        
        if success {
            print("✅ Auto-save complete")
        } else {
            print("❌ Auto-save failed")
        }
    }

    func manualSave() {
        guard let player = player,
              let hexMap = gameScene.hexMap,
              !gameScene.allGamePlayers.isEmpty else {
            showSimpleAlert(title: "Cannot Save", message: "Game is not ready to be saved.")
            return
        }
        
        let success = GameSaveManager.shared.saveGame(
            hexMap: hexMap,
            player: player,
            allPlayers: gameScene.allGamePlayers
        )
        
        if success {
            showSimpleAlert(title: "✅ Game Saved", message: "Your progress has been saved successfully.")
        } else {
            showSimpleAlert(title: "❌ Save Failed", message: "Could not save the game. Please try again.")
        }
    }

    func loadGame() {
        guard let loadedData = GameSaveManager.shared.loadGame() else {
            showSimpleAlert(title: "❌ Load Failed", message: "Could not load the saved game.")
            return
        }
        
        // Update references
        player = loadedData.player
        gameScene.player = loadedData.player
        gameScene.hexMap = loadedData.hexMap
        gameScene.allGamePlayers = loadedData.allPlayers
        
        // Rebuild the scene
        rebuildSceneWithLoadedData(hexMap: loadedData.hexMap, player: loadedData.player, allPlayers: loadedData.allPlayers)
        
        // ✅ DEBUG: Check fog stats after everything is loaded
        if let fogOfWar = player.fogOfWar {
            print("\n🔍 POST-LOAD FOG CHECK:")
            fogOfWar.printFogStats()
            
            // Check a few specific tiles
            let testCoords = [
                HexCoordinate(q: 3, r: 3),
                HexCoordinate(q: 5, r: 5),
                HexCoordinate(q: 10, r: 10)
            ]
            
            for coord in testCoords {
                let vis = player.getVisibilityLevel(at: coord)
                print("  Tile (\(coord.q), \(coord.r)): \(vis)")
            }
        }
        
        print("✅ Game loaded successfully")
        showSimpleAlert(title: "✅ Game Loaded", message: "Your saved game has been restored.")
    }

    func rebuildSceneWithLoadedData(hexMap: HexMap, player: Player, allPlayers: [Player]) {
        // Clear existing scene
        gameScene.mapNode.removeAllChildren()
        gameScene.buildingsNode.removeAllChildren()
        gameScene.entitiesNode.removeAllChildren()
        
        // Remove old fog node
        gameScene.childNode(withName: "fogNode")?.removeFromParent()
        
        // Rebuild map tiles
        for (coord, tile) in hexMap.tiles {
            let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
            tile.position = position
            gameScene.mapNode.addChild(tile)
        }
        
        // Rebuild resource points
        if let resourcesNode = gameScene.childNode(withName: "resourcesNode") {
            resourcesNode.removeAllChildren()
            for resource in hexMap.resourcePoints {
                let position = HexMap.hexToPixel(q: resource.coordinate.q, r: resource.coordinate.r)
                resource.position = position
                resourcesNode.addChild(resource)
            }
        }
        
        // Rebuild buildings
        for building in hexMap.buildings {
            let position = HexMap.hexToPixel(q: building.coordinate.q, r: building.coordinate.r)
            building.position = position
            gameScene.buildingsNode.addChild(building)
            
            // Re-apply texture and UI
            building.setupUI()
            building.updateAppearance()
            building.updateUIVisibility()
        }
        
        // Rebuild entities
        for playerData in allPlayers {
            for entity in playerData.entities {
                let coord: HexCoordinate
                let entityType: EntityType
                
                if let army = entity as? Army {
                    coord = army.coordinate
                    entityType = .army
                } else if let villagers = entity as? VillagerGroup {
                    coord = villagers.coordinate
                    entityType = .villagerGroup
                } else {
                    continue
                }
                
                let entityNode = EntityNode(
                    coordinate: coord,
                    entityType: entityType,
                    entity: entity,
                    currentPlayer: player
                )
                
                let position = HexMap.hexToPixel(q: coord.q, r: coord.r)
                entityNode.position = position
                gameScene.entitiesNode.addChild(entityNode)
                hexMap.addEntity(entityNode)
            }
        }
        
        // ✅ FIX: DON'T call initializeFogOfWar here - it's already done in reconstructHexMap
        // Instead, just setup the visual fog overlays
        
        // Create fresh fog node for overlays
        let fogNode = SKNode()
        fogNode.name = "fogNode"
        fogNode.zPosition = 100
        gameScene.addChild(fogNode)
        
        // Setup fog overlays (visual only)
        hexMap.setupFogOverlays(in: fogNode)
        
        // ✅ IMPORTANT: Update vision to reveal visible tiles (but keep explored tiles)
        player.updateVision(allPlayers: allPlayers)
        
        // Apply fog overlay visuals
        hexMap.updateFogOverlays(for: player)
        
        // Update entity visibility
        for entity in hexMap.entities {
            entity.updateVisibility(for: player)
        }
        
        // Update building visibility
        for building in hexMap.buildings {
            let displayMode = player.fogOfWar?.shouldShowBuilding(building, at: building.coordinate) ?? .hidden
            building.updateVisibility(displayMode: displayMode)
        }
        
        // Update resource display
        updateResourceDisplay()
        
        print("🔄 Scene rebuilt with loaded data")
        print("   Explored tiles: \(player.fogOfWar?.getExploredCount() ?? 0)")
    }


    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop auto-save timer
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        
        // Final save before leaving
        autoSaveGame()
        
        // Save background time
        BackgroundTimeManager.shared.saveExitTime()
    }
    
    func processBackgroundTime() {
        guard let player = player,
              let hexMap = gameScene.hexMap,
              !gameScene.allGamePlayers.isEmpty else {
            return
        }
        
        // Get summary before processing
        if let summary = BackgroundTimeManager.shared.getBackgroundSummary(
            player: player,
            hexMap: hexMap
        ) {
            // Show summary in alert
            let alert = UIAlertController(
                title: "Welcome Back!",
                message: summary,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
        
        // Process the background time
        BackgroundTimeManager.shared.processBackgroundTime(
            player: player,
            hexMap: hexMap,
            allPlayers: gameScene.allGamePlayers
        )
        
        // Update displays
        updateResourceDisplay()
    }
    
    
    func showDeployVillagersMenu(from building: BuildingNode) {
        let villagerCount = building.villagerGarrison
        
        guard villagerCount > 0 else {
            showSimpleAlert(title: "No Villagers", message: "This building has no villagers to deploy.")
            return
        }
        
        guard let spawnCoord = gameScene.hexMap.findNearestWalkable(to: building.coordinate) else {
            showSimpleAlert(title: "Cannot Deploy", message: "No valid location near building to deploy villagers.")
            return
        }
        
        // Create custom alert with slider
        let alert = UIAlertController(
            title: "👷 Deploy Villagers",
            message: "Select how many villagers to deploy from \(building.buildingType.displayName)\n\nAvailable: \(villagerCount) villagers",
            preferredStyle: .alert
        )
        
        // Create container for slider
        let containerVC = UIViewController()
        containerVC.preferredContentSize = CGSize(width: 270, height: 120)
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 270, height: 120))
        
        // Slider
        let slider = UISlider(frame: CGRect(x: 20, y: 20, width: 230, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = Float(villagerCount)
        slider.value = Float(min(5, villagerCount))
        slider.isContinuous = true
        containerView.addSubview(slider)
        
        // Count label
        let countLabel = UILabel(frame: CGRect(x: 20, y: 60, width: 230, height: 30))
        countLabel.text = "\(Int(slider.value)) villagers"
        countLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        countLabel.textColor = .label
        countLabel.textAlignment = .center
        containerView.addSubview(countLabel)
        
        // Update label when slider moves
        slider.addTarget(self, action: #selector(villagerSliderChanged(_:)), for: .valueChanged)
        objc_setAssociatedObject(self, &AssociatedKeys.villagerCountLabel, countLabel, .OBJC_ASSOCIATION_RETAIN)
        
        containerVC.view.addSubview(containerView)
        alert.setValue(containerVC, forKey: "contentViewController")
        
        // Deploy action
        alert.addAction(UIAlertAction(title: "Deploy", style: .default) { [weak self] _ in
            let deployCount = Int(slider.value)
            self?.deployVillagers(count: deployCount, from: building, at: spawnCoord)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    @objc func villagerSliderChanged(_ slider: UISlider) {
        if let label = objc_getAssociatedObject(self, &AssociatedKeys.villagerCountLabel) as? UILabel {
            label.text = "\(Int(slider.value)) villagers"
        }
    }

    func deployVillagers(count: Int, from building: BuildingNode, at coordinate: HexCoordinate) {
        // Remove villagers from garrison
        let removed = building.removeVillagersFromGarrison(quantity: count)
        
        guard removed > 0 else {
            showSimpleAlert(title: "Deploy Failed", message: "Could not remove villagers from garrison.")
            return
        }
        
        // Create new villager group
        let villagerGroup = VillagerGroup(
            name: "Villagers",
            coordinate: coordinate,
            villagerCount: removed,
            owner: player
        )
        
        let villagerNode = EntityNode(
            coordinate: coordinate,
            entityType: .villagerGroup,
            entity: villagerGroup,
            currentPlayer: player
        )
        
        let position = HexMap.hexToPixel(q: coordinate.q, r: coordinate.r)
        villagerNode.position = position
        
        gameScene.hexMap.addEntity(villagerNode)
        gameScene.entitiesNode.addChild(villagerNode)
        player.addEntity(villagerGroup)
        
        showSimpleAlert(
            title: "✅ Villagers Deployed",
            message: "Deployed \(removed) villagers from \(building.buildingType.displayName)"
        )
        
        print("✅ Deployed \(removed) villagers at (\(coordinate.q), \(coordinate.r))")
    }
    
    func showSplitVillagerGroupMenu(villagerGroup: VillagerGroup, entity: EntityNode) {
        let totalVillagers = villagerGroup.villagerCount
        
        guard totalVillagers > 1 else {
            showSimpleAlert(title: "Cannot Split", message: "Need at least 2 villagers to split the group.")
            return
        }
        
        // Create custom alert with slider
        let alert = UIAlertController(
            title: "✂️ Split Villager Group",
            message: "Select how many villagers to move to a new group\n\nTotal: \(totalVillagers) villagers",
            preferredStyle: .alert
        )
        
        // Create container for slider
        let containerVC = UIViewController()
        containerVC.preferredContentSize = CGSize(width: 270, height: 150)
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 270, height: 150))
        
        // Info label
        let infoLabel = UILabel(frame: CGRect(x: 20, y: 10, width: 230, height: 40))
        infoLabel.text = "Original group will keep the rest"
        infoLabel.font = UIFont.systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabel
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 2
        containerView.addSubview(infoLabel)
        
        // Slider
        let slider = UISlider(frame: CGRect(x: 20, y: 50, width: 230, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = Float(totalVillagers - 1)
        slider.value = Float(totalVillagers / 2)
        slider.isContinuous = true
        containerView.addSubview(slider)
        
        // Count labels
        let splitLabel = UILabel(frame: CGRect(x: 20, y: 90, width: 230, height: 25))
        splitLabel.text = "New group: \(Int(slider.value)) villagers"
        splitLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        splitLabel.textColor = .label
        splitLabel.textAlignment = .center
        containerView.addSubview(splitLabel)
        
        let remainLabel = UILabel(frame: CGRect(x: 20, y: 115, width: 230, height: 25))
        remainLabel.text = "Original: \(totalVillagers - Int(slider.value)) villagers"
        remainLabel.font = UIFont.systemFont(ofSize: 14)
        remainLabel.textColor = .secondaryLabel
        remainLabel.textAlignment = .center
        containerView.addSubview(remainLabel)
        
        // Update labels when slider moves
        slider.addTarget(self, action: #selector(splitSliderChanged(_:)), for: .valueChanged)
        
        // Store both labels
        let labelDict: [String: Any] = [
            "splitLabel": splitLabel,
            "remainLabel": remainLabel,
            "totalVillagers": totalVillagers
        ]
        objc_setAssociatedObject(self, &AssociatedKeys.splitLabels, labelDict, .OBJC_ASSOCIATION_RETAIN)
        
        containerVC.view.addSubview(containerView)
        alert.setValue(containerVC, forKey: "contentViewController")
        
        // Split action
        alert.addAction(UIAlertAction(title: "Split", style: .default) { [weak self] _ in
            let splitCount = Int(slider.value)
            self?.splitVillagerGroup(villagerGroup: villagerGroup, entity: entity, splitCount: splitCount)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    @objc func splitSliderChanged(_ slider: UISlider) {
        if let labelDict = objc_getAssociatedObject(self, &AssociatedKeys.splitLabels) as? [String: Any],
           let splitLabel = labelDict["splitLabel"] as? UILabel,
           let remainLabel = labelDict["remainLabel"] as? UILabel,
           let totalVillagers = labelDict["totalVillagers"] as? Int {
            
            let splitValue = Int(slider.value)
            splitLabel.text = "New group: \(splitValue) villagers"
            remainLabel.text = "Original: \(totalVillagers - splitValue) villagers"
        }
    }

    func splitVillagerGroup(villagerGroup: VillagerGroup, entity: EntityNode, splitCount: Int) {
        guard let newGroup = villagerGroup.split(count: splitCount) else {
            showSimpleAlert(title: "Split Failed", message: "Could not split villager group.")
            return
        }
        
        // Create entity node for new group
        let newEntityNode = EntityNode(
            coordinate: villagerGroup.coordinate,
            entityType: .villagerGroup,
            entity: newGroup,
            currentPlayer: player
        )
        
        let position = HexMap.hexToPixel(q: newGroup.coordinate.q, r: newGroup.coordinate.r)
        newEntityNode.position = position
        
        gameScene.hexMap.addEntity(newEntityNode)
        gameScene.entitiesNode.addChild(newEntityNode)
        player.addEntity(newGroup)
        
        showSimpleAlert(
            title: "✅ Group Split",
            message: "Created new group with \(splitCount) villagers\nOriginal group has \(villagerGroup.villagerCount) villagers remaining"
        )
        
        print("✅ Split villager group: \(splitCount) → new group, \(villagerGroup.villagerCount) → original")
    }
    
    func showVillagerTrainingMenu(for building: BuildingNode) {
        showTrainingSliderMenu(
            unitType: .villager,
            building: building,
            unitCost: [.food: 50],
            trainingTimePerUnit: 15.0,
            unitStats: "Gathers resources and constructs buildings"
        )
    }
    
    func showUnitTrainingSlider(unitType: MilitaryUnitType, building: BuildingNode) {
        let stats = "⚔️ Attack: \(unitType.attackPower)\n🛡️ Defense: \(unitType.defensePower)\n⏱️ Training: \(Int(unitType.trainingTime))s per unit"
        
        showTrainingSliderMenu(
            unitType: .military(unitType),
            building: building,
            unitCost: unitType.trainingCost,
            trainingTimePerUnit: unitType.trainingTime,
            unitStats: stats
        )
    }
    
    @objc func showTrainingOverview() {
        let trainingVC = TrainingOverviewViewController()
        trainingVC.player = player
        trainingVC.hexMap = gameScene.hexMap
        trainingVC.modalPresentationStyle = .fullScreen
        present(trainingVC, animated: true)
        print("🎓 Opening Training Overview screen")
    }

    func showTrainingSliderMenu(
        unitType: TrainableUnitType,
        building: BuildingNode,
        unitCost: [ResourceType: Int],
        trainingTimePerUnit: TimeInterval,
        unitStats: String? = nil
    ) {
        // Calculate max affordable units
        var maxAffordable = Int.max
        for (resourceType, costPerUnit) in unitCost {
            let available = player.getResource(resourceType)
            let canAfford = available / costPerUnit
            maxAffordable = min(maxAffordable, canAfford)
        }
        
        guard maxAffordable > 0 else {
            var costString = "You need: "
            for (resourceType, cost) in unitCost.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                costString += "\(resourceType.icon)\(cost) "
            }
            showSimpleAlert(title: "Cannot Afford", message: costString)
            return
        }
        
        // Create custom alert with slider
        let alert = UIAlertController(
            title: "Train \(unitType.icon) \(unitType.displayName)",
            message: unitType.description + "\n\nSelect quantity to train",
            preferredStyle: .alert
        )
        
        // Create container for slider
        let containerVC = UIViewController()
        let hasStats = unitStats != nil
        let containerHeight: CGFloat = hasStats ? 220 : 180
        containerVC.preferredContentSize = CGSize(width: 270, height: containerHeight)
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 270, height: containerHeight))
        
        var yOffset: CGFloat = 10
        
        // Stats labels (if provided)
        if let stats = unitStats {
            let statsLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: 230, height: 60))
            statsLabel.text = stats
            statsLabel.font = UIFont.systemFont(ofSize: 12)
            statsLabel.textColor = .secondaryLabel
            statsLabel.numberOfLines = 3
            containerView.addSubview(statsLabel)
            yOffset += 70
        }
        
        // Slider
        let slider = UISlider(frame: CGRect(x: 20, y: yOffset, width: 230, height: 30))
        slider.minimumValue = 1
        slider.maximumValue = Float(min(maxAffordable, 200)) // Cap at 200
        slider.value = Float(min(10, maxAffordable))
        slider.isContinuous = true
        containerView.addSubview(slider)
        yOffset += 40
        
        // Count label
        let countLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: 230, height: 25))
        let initialCount = Int(slider.value)
        countLabel.text = "\(initialCount) \(unitType.displayName.lowercased())\(initialCount > 1 ? "s" : "")"
        countLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        countLabel.textColor = .label
        countLabel.textAlignment = .center
        containerView.addSubview(countLabel)
        yOffset += 25
        
        // Cost label
        let costLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: 230, height: 25))
        let initialCost = unitCost.map { "\($0.key.icon)\($0.value * initialCount)" }.joined(separator: " ")
        costLabel.text = "Cost: \(initialCost)"
        costLabel.font = UIFont.systemFont(ofSize: 14)
        costLabel.textColor = .secondaryLabel
        costLabel.textAlignment = .center
        containerView.addSubview(costLabel)
        yOffset += 25
        
        // Time label
        let timeLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: 230, height: 25))
        let initialTime = trainingTimePerUnit * Double(initialCount)
        let initialMinutes = Int(initialTime) / 60
        let initialSeconds = Int(initialTime) % 60
        timeLabel.text = "Time: \(initialMinutes)m \(initialSeconds)s"
        timeLabel.font = UIFont.systemFont(ofSize: 14)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .center
        containerView.addSubview(timeLabel)
        
        // Update labels when slider moves
        slider.addTarget(self, action: #selector(trainingSliderChanged(_:)), for: .valueChanged)
        
        let labelDict: [String: Any] = [
            "countLabel": countLabel,
            "costLabel": costLabel,
            "timeLabel": timeLabel,
            "unitCost": unitCost,
            "trainingTime": trainingTimePerUnit,
            "unitType": unitType
        ]
        objc_setAssociatedObject(self, &AssociatedKeys.trainingLabels, labelDict, .OBJC_ASSOCIATION_RETAIN)
        
        containerVC.view.addSubview(containerView)
        alert.setValue(containerVC, forKey: "contentViewController")
        
        // Train action
        alert.addAction(UIAlertAction(title: "Train", style: .default) { [weak self] _ in
            let quantity = Int(slider.value)
            
            switch unitType {
            case .military(let militaryType):
                self?.startTraining(unitType: militaryType, quantity: quantity, building: building)
            case .villager:
                self?.startVillagerTraining(quantity: quantity, building: building)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    @objc func trainingSliderChanged(_ slider: UISlider) {
        if let labelDict = objc_getAssociatedObject(self, &AssociatedKeys.trainingLabels) as? [String: Any],
           let countLabel = labelDict["countLabel"] as? UILabel,
           let costLabel = labelDict["costLabel"] as? UILabel,
           let timeLabel = labelDict["timeLabel"] as? UILabel,
           let unitCost = labelDict["unitCost"] as? [ResourceType: Int],
           let trainingTime = labelDict["trainingTime"] as? TimeInterval,
           let unitType = labelDict["unitType"] as? TrainableUnitType {
            
            let count = Int(slider.value)
            countLabel.text = "\(count) \(unitType.displayName.lowercased())\(count > 1 ? "s" : "")"
            
            let totalCost = unitCost.map { "\($0.key.icon)\($0.value * count)" }.joined(separator: " ")
            costLabel.text = "Cost: \(totalCost)"
            
            let totalTime = trainingTime * Double(count)
            let minutes = Int(totalTime) / 60
            let seconds = Int(totalTime) % 60
            timeLabel.text = "Time: \(minutes)m \(seconds)s"
        }
    }

}
