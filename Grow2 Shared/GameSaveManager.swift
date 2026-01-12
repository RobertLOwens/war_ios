// ============================================================================
// FILE: GameSaveManager.swift
// LOCATION: Create as new file
// ============================================================================

import Foundation
import UIKit

// MARK: - Save Data Structures

struct GameSaveData: Codable {
    let version: String
    let saveDate: Date
    let mapData: MapSaveData
    let playerData: PlayerSaveData
    let allPlayersData: [PlayerSaveData]

    
    init(version: String = "1.0", 
         saveDate: Date = Date(),
         mapData: MapSaveData,
         playerData: PlayerSaveData,
         allPlayersData: [PlayerSaveData]) {
        
        self.version = version
        self.saveDate = saveDate
        self.mapData = mapData
        self.playerData = playerData
        self.allPlayersData = allPlayersData
    }
}

struct MapSaveData: Codable {
    let width: Int
    let height: Int
    let tiles: [TileSaveData]
    let buildings: [BuildingSaveData]
    let resourcePoints: [ResourcePointSaveData]
    let exploredTiles: [TileSaveData]  // ✅ NEW: Save explored tiles
}

struct TileSaveData: Codable {
    let q: Int
    let r: Int
    let terrain: String  // TerrainType.rawValue
}

struct PlayerSaveData: Codable {
    let id: String
    let name: String
    let colorRed: CGFloat
    let colorGreen: CGFloat
    let colorBlue: CGFloat
    let colorAlpha: CGFloat
    
    let resources: [String: Int]  // ResourceType.rawValue: amount
    let collectionRates: [String: Double]
    
    let entities: [EntitySaveData]
    let armies: [ArmySaveData]
    let commanders: [CommanderSaveData]
    let diplomacyRelations: [String: String]  // Player UUID: DiplomacyStatus
}

struct EntitySaveData: Codable {
    let id: String
    let name: String
    let entityType: String
    let q: Int
    let r: Int
    let ownerID: String
    
    // VillagerGroup specific
    let villagerCount: Int?
    let currentTask: String?  // VillagerTask description
    let taskTargetQ: Int?
    let taskTargetR: Int?
}

struct ArmySaveData: Codable {
    let id: String
    let name: String
    let q: Int
    let r: Int
    let ownerID: String
    let commanderID: String?
    let unitComposition: [String: Int]  // UnitType: count
    let militaryComposition: [String: Int]  // MilitaryUnitType: count
}

struct CommanderSaveData: Codable {
    let id: String
    let name: String
    let rank: String
    let specialty: String
    let experience: Int
    let level: Int
    let baseLeadership: Int
    let baseTactics: Int
    let colorRed: CGFloat
    let colorGreen: CGFloat
    let colorBlue: CGFloat
    let colorAlpha: CGFloat
}

struct BuildingSaveData: Codable {
    let id: String
    let q: Int
    let r: Int
    let buildingType: String
    let ownerID: String
    let state: String
    let health: Double
    let maxHealth: Double
    let constructionProgress: Double
    let constructionStartTime: TimeInterval?
    let buildersAssigned: Int
    let level: Int
    let upgradeProgress: Double
    let upgradeStartTime: TimeInterval?
    
    // Garrison data
    let garrison: [String: Int]  // MilitaryUnitType: count
    let villagerGarrison: Int
    
    // Training queue data
    let trainingQueue: [TrainingQueueSaveData]
    let villagerTrainingQueue: [VillagerTrainingSaveData]
}

struct TrainingQueueSaveData: Codable {
    let id: String
    let unitType: String
    let quantity: Int
    let startTime: TimeInterval
    let progress: Double
}

struct VillagerTrainingSaveData: Codable {
    let id: String
    let quantity: Int
    let startTime: TimeInterval
    let progress: Double
}

struct ResourcePointSaveData: Codable {
    let q: Int
    let r: Int
    let resourceType: String
    let remainingAmount: Int
    let currentHealth: Double
    let isBeingGathered: Bool
    let assignedVillagerGroupIDs: [String]  // Changed from single ID to array
}

// MARK: - Game Save Manager

class GameSaveManager {
    
    static let shared = GameSaveManager()
    
    private let saveFileName = "game_save.json"
    
    private var saveFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(saveFileName)
    }
    
    // MARK: - Save Game
    
    func saveGame(hexMap: HexMap, player: Player, allPlayers: [Player]) -> Bool {
        print("💾 Starting game save...")
        
        // Create save data
        let mapData = createMapSaveData(from: hexMap, player: player)
        let playerData = createPlayerSaveData(from: player)
        let allPlayersData = allPlayers.map { createPlayerSaveData(from: $0) }
            
        let saveData = GameSaveData(
            mapData: mapData,
            playerData: playerData,
            allPlayersData: allPlayersData
        )
        
        // Encode to JSON
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(saveData)
            
            // Write to file
            try jsonData.write(to: saveFileURL)
            
            print("✅ Game saved successfully to: \(saveFileURL.path)")
            print("📊 Save size: \(jsonData.count / 1024) KB")
            return true
            
        } catch {
            print("❌ Failed to save game: \(error)")
            return false
        }
    }
    
    // MARK: - Load Game
    
    func loadGame() -> (hexMap: HexMap, player: Player, allPlayers: [Player])? {
        print("📂 Loading game...")
        
        guard FileManager.default.fileExists(atPath: saveFileURL.path) else {
            print("❌ No save file found")
            return nil
        }
        
        do {
            let jsonData = try Data(contentsOf: saveFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let saveData = try decoder.decode(GameSaveData.self, from: jsonData)
            
            print("✅ Save file loaded - Version: \(saveData.version), Date: \(saveData.saveDate)")
            
            // Reconstruct all players
            let allPlayers = saveData.allPlayersData.map { reconstructPlayer(from: $0) }
            
            guard let player = allPlayers.first(where: { $0.id.uuidString == saveData.playerData.id }) else {
                print("❌ Could not find player in allPlayers array")
                return nil
            }
            
            let hexMap = reconstructHexMap(from: saveData.mapData, player: player)

            // ✅ DEBUG: Verify explored tiles were loaded
            print("\n🔍 FOG DEBUG after reconstructHexMap:")
            print("   exploredTiles in save data: \(saveData.mapData.exploredTiles.count)")
            if let fogOfWar = player.fogOfWar {
                fogOfWar.printFogStats()
                
                // Check first few explored tiles
                for (index, tile) in saveData.mapData.exploredTiles.prefix(5).enumerated() {
                    let coord = HexCoordinate(q: tile.q, r: tile.r)
                    let actualLevel = fogOfWar.getVisibilityLevel(at: coord)
                    print("   Sample tile \(index): (\(tile.q), \(tile.r)) -> \(actualLevel)")
                }
            }
            
            for playerData in saveData.allPlayersData {
                if let restoredPlayer = allPlayers.first(where: { $0.id.uuidString == playerData.id }) {
                    // ✅ FIX: Only initialize fog for players OTHER than the main player
                    // Main player's fog was already initialized and restored in reconstructHexMap
                    if restoredPlayer.id != player.id {
                        restoredPlayer.initializeFogOfWar(hexMap: hexMap)
                    }
                }
            }
            
            // Restore buildings to map and players
            for buildingData in saveData.mapData.buildings {
                if let building = reconstructBuilding(from: buildingData, allPlayers: allPlayers) {
                    hexMap.addBuilding(building)
                    if let owner = building.owner {
                        owner.addBuilding(building)
                    }
                }
            }
            
            for resourceData in saveData.mapData.resourcePoints {
                if let resource = reconstructResourcePoint(from: resourceData) {
                    hexMap.resourcePoints.append(resource)
                }
            }

            applyOfflineProgress(hexMap: hexMap, player: player, saveDate: saveData.saveDate)

            print("✅ Game loaded successfully")
            print("   Map: \(hexMap.width)x\(hexMap.height)")
            print("   Player: \(player.name)")
            print("   Player Buildings: \(player.buildings.count)")  // ✅ Now shows correct count
            print("   HexMap Buildings: \(hexMap.buildings.count)")
            print("   Entities: \(player.entities.count)")
            
            return (hexMap, player, allPlayers)
            
        } catch {
            print("❌ Failed to load game: \(error)")
            return nil
        }
    }

    
    // MARK: - Check Save Exists
    
    func saveExists() -> Bool {
        return FileManager.default.fileExists(atPath: saveFileURL.path)
    }
    
    func getSaveDate() -> Date? {
        guard saveExists() else { return nil }
        
        do {
            let jsonData = try Data(contentsOf: saveFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let saveData = try decoder.decode(GameSaveData.self, from: jsonData)
            return saveData.saveDate
        } catch {
            return nil
        }
    }
    
    // MARK: - Delete Save
    
    func deleteSave() -> Bool {
        guard saveExists() else { return false }
        
        do {
            try FileManager.default.removeItem(at: saveFileURL)
            print("🗑️ Save file deleted")
            return true
        } catch {
            print("❌ Failed to delete save: \(error)")
            return false
        }
    }
    
    // MARK: - Create Save Data
    
    private func createMapSaveData(from hexMap: HexMap, player: Player) -> MapSaveData {
        
        let tiles = hexMap.tiles.map { coord, tile in
               TileSaveData(q: coord.q, r: coord.r, terrain: terrainTypeToString(tile.terrain))
           }
        
        let buildings = hexMap.buildings.map { createBuildingSaveData(from: $0) }
        
        let resourcePoints = hexMap.resourcePoints.map { resource in
            ResourcePointSaveData(
                q: resource.coordinate.q,
                r: resource.coordinate.r,
                resourceType: resource.resourceType.rawValue,
                remainingAmount: resource.remainingAmount,
                currentHealth: resource.currentHealth,
                isBeingGathered: resource.isBeingGathered,
                assignedVillagerGroupIDs: resource.assignedVillagerGroups.map { $0.id.uuidString }
            )
        }

        var exploredTiles: [TileSaveData] = []
        if let fogOfWar = player.fogOfWar {
            for (coord, tile) in hexMap.tiles {
                let visibility = fogOfWar.getVisibilityLevel(at: coord)
                if visibility == .explored || visibility == .visible {
                    exploredTiles.append(TileSaveData(
                        q: coord.q,
                        r: coord.r,
                        terrain: terrainTypeToString(tile.terrain)
                    ))
                }
            }
        }
         
        return MapSaveData(
               width: hexMap.width,
               height: hexMap.height,
               tiles: tiles,
               buildings: buildings,
               resourcePoints: resourcePoints,
               exploredTiles: exploredTiles
           )

    }
    
    private func createPlayerSaveData(from player: Player) -> PlayerSaveData {
        var resources: [String: Int] = [:]
        for type in ResourceType.allCases {
            resources[type.rawValue] = player.getResource(type)
        }
        
        var rates: [String: Double] = [:]
        for type in ResourceType.allCases {
            rates[type.rawValue] = player.getCollectionRate(type)
        }
        
        // ✅ DEBUG: Print what we're saving
        print("💾 Saving player \(player.name):")
        for type in ResourceType.allCases {
            print("   \(type.displayName): \(player.getResource(type)) (rate: \(player.getCollectionRate(type))/s)")
        }
        
        let entities = player.entities.compactMap { entity -> EntitySaveData? in
            if let villagers = entity as? VillagerGroup {
                return createVillagerSaveData(from: villagers)
            } else if let army = entity as? Army {
                return createArmyEntitySaveData(from: army)
            }
            return nil
        }
        
        let armies = player.armies.map { createArmySaveData(from: $0) }
        let commanders = player.commanders.map { createCommanderSaveData(from: $0) }
        
        var diplomacy: [String: String] = [:]
        for (playerID, status) in player.diplomacyRelations {
            diplomacy[playerID.uuidString] = status.rawValue
        }
        
        let color = player.color
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return PlayerSaveData(
            id: player.id.uuidString,
            name: player.name,
            colorRed: red,
            colorGreen: green,
            colorBlue: blue,
            colorAlpha: alpha,
            resources: resources,
            collectionRates: rates,
            entities: entities,
            armies: armies,
            commanders: commanders,
            diplomacyRelations: diplomacy
        )
    }
    
    private func createVillagerSaveData(from villagers: VillagerGroup) -> EntitySaveData {
        var taskString: String? = nil
        var taskQ: Int? = nil
        var taskR: Int? = nil
        
        switch villagers.currentTask {
        case .idle:
            taskString = "idle"
        case .building(let building):
            taskString = "building"
            taskQ = building.coordinate.q
            taskR = building.coordinate.r
        case .gathering(let resourceType):
            taskString = "gathering_\(resourceType.rawValue)"
        case .gatheringResource(let resourcePoint):
            // ✅ Save the resource coordinate
            taskString = "gatheringResource"
            taskQ = resourcePoint.coordinate.q
            taskR = resourcePoint.coordinate.r
            print("💾 Saving villager \(villagers.name) gathering at (\(taskQ!), \(taskR!))")
        case .repairing(let building):
            taskString = "repairing"
            taskQ = building.coordinate.q
            taskR = building.coordinate.r
        case .moving(let coord):
            taskString = "moving"
            taskQ = coord.q
            taskR = coord.r
        case .hunting(let resourcePoint):
            taskString = "hunting"
            taskQ = resourcePoint.coordinate.q
            taskR = resourcePoint.coordinate.r
        case .upgrading:
            taskString = "upgrading"
        }
        
        // ✅ ALSO save taskTarget if it exists (belt and suspenders)
        if taskQ == nil, let target = villagers.taskTarget {
            taskQ = target.q
            taskR = target.r
            print("💾 Saving villager \(villagers.name) taskTarget at (\(taskQ!), \(taskR!))")
        }
        
        return EntitySaveData(
            id: villagers.id.uuidString,
            name: villagers.name,
            entityType: "villagerGroup",
            q: villagers.coordinate.q,
            r: villagers.coordinate.r,
            ownerID: villagers.owner?.id.uuidString ?? "",
            villagerCount: villagers.villagerCount,
            currentTask: taskString,
            taskTargetQ: taskQ,
            taskTargetR: taskR
        )
    }
    
    private func createArmyEntitySaveData(from army: Army) -> EntitySaveData {
        return EntitySaveData(
            id: army.id.uuidString,
            name: army.name,
            entityType: "army",
            q: army.coordinate.q,
            r: army.coordinate.r,
            ownerID: army.owner?.id.uuidString ?? "",
            villagerCount: nil,
            currentTask: nil,
            taskTargetQ: nil,
            taskTargetR: nil
        )
    }
    
    private func createArmySaveData(from army: Army) -> ArmySaveData {
        var unitComp: [String: Int] = [:]
        
        var militaryComp: [String: Int] = [:]
        for (unitType, count) in army.militaryComposition {
            militaryComp[unitType.rawValue] = count
        }
        
        return ArmySaveData(
            id: army.id.uuidString,
            name: army.name,
            q: army.coordinate.q,
            r: army.coordinate.r,
            ownerID: army.owner?.id.uuidString ?? "",
            commanderID: army.commander?.id.uuidString,
            unitComposition: unitComp,
            militaryComposition: militaryComp
        )
    }
    
    private func createCommanderSaveData(from commander: Commander) -> CommanderSaveData {
        let color = commander.portraitColor
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return CommanderSaveData(
            id: commander.id.uuidString,
            name: commander.name,
            rank: commander.rank.rawValue,
            specialty: commander.specialty.rawValue,
            experience: commander.experience,
            level: commander.level,
            baseLeadership: commander.getBaseLeadership(),
            baseTactics: commander.getBaseTactics(),
            colorRed: red,
            colorGreen: green,
            colorBlue: blue,
            colorAlpha: alpha
        )
    }

    
    private func createBuildingSaveData(from building: BuildingNode) -> BuildingSaveData {
        var garrison: [String: Int] = [:]
        for (unitType, count) in building.garrison {
            garrison[unitType.rawValue] = count
        }
        
        let trainingQueue = building.trainingQueue.map { entry in
            TrainingQueueSaveData(
                id: entry.id.uuidString,
                unitType: entry.unitType.rawValue,
                quantity: entry.quantity,
                startTime: entry.startTime,
                progress: entry.progress
            )
        }
        
        let villagerQueue = building.villagerTrainingQueue.map { entry in
            VillagerTrainingSaveData(
                id: entry.id.uuidString,
                quantity: entry.quantity,
                startTime: entry.startTime,
                progress: entry.progress
            )
        }
        
        return BuildingSaveData(
            id: UUID().uuidString,
            q: building.coordinate.q,
            r: building.coordinate.r,
            buildingType: building.buildingType.rawValue,
            ownerID: building.owner?.id.uuidString ?? "",
            state: buildingStateToString(building.state),
            health: building.health,
            maxHealth: building.maxHealth,
            constructionProgress: building.constructionProgress,
            constructionStartTime: building.constructionStartTime,
            buildersAssigned: building.buildersAssigned,
            level: building.level,
            upgradeProgress: building.upgradeProgress,
            upgradeStartTime: building.upgradeStartTime,
            garrison: garrison,
            villagerGarrison: building.villagerGarrison,
            trainingQueue: trainingQueue,
            villagerTrainingQueue: villagerQueue
        )
    }
    
    // MARK: - Reconstruct Objects
    
    private func reconstructHexMap(from data: MapSaveData, player: Player) -> HexMap {
        let hexMap = HexMap(width: data.width, height: data.height)
        hexMap.tiles.removeAll()
        
        for tileData in data.tiles {
            let coord = HexCoordinate(q: tileData.q, r: tileData.r)
            let terrain = stringToTerrainType(tileData.terrain)
            let tile = HexTileNode(coordinate: coord, terrain: terrain)
            hexMap.tiles[coord] = tile
        }
        
        print("📂 Loading \(data.exploredTiles.count) explored tiles...")
        
        // Initialize fog of war
        player.initializeFogOfWar(hexMap: hexMap)
        
        // Restore explored tiles
        if let fogOfWar = player.fogOfWar {
            var restoredCount = 0
            for exploredTile in data.exploredTiles {
                let coord = HexCoordinate(q: exploredTile.q, r: exploredTile.r)
                fogOfWar.markAsExplored(coord)
                restoredCount += 1
            }
            print("✅ Restored \(restoredCount) explored tiles")
            
            // ✅ DEBUG: Print fog stats after restoration
            fogOfWar.printFogStats()
        }
        
        return hexMap
    }

    private func reconstructPlayer(from data: PlayerSaveData) -> Player {
        let color = UIColor(
            red: data.colorRed,
            green: data.colorGreen,
            blue: data.colorBlue,
            alpha: data.colorAlpha
        )
        
        let player = Player(
            id: UUID(uuidString: data.id) ?? UUID(),
            name: data.name,
            color: color
        )
        
        // ✅ FIX: SET resources directly (don't ADD to defaults)
        for (resourceKey, amount) in data.resources {
            if let resourceType = ResourceType(rawValue: resourceKey) {
                player.setResource(resourceType, amount: amount)
            }
        }
        
        // ✅ FIX: SET collection rates directly (don't ADD to defaults)
        for (resourceKey, rate) in data.collectionRates {
            if let resourceType = ResourceType(rawValue: resourceKey) {
                player.setCollectionRate(resourceType, rate: rate)
            }
        }
        
        // ✅ DEBUG: Print restored values
        print("📊 Restored player \(player.name):")
        for type in ResourceType.allCases {
            print("   \(type.displayName): \(player.getResource(type)) (rate: \(player.getCollectionRate(type))/s)")
        }
        
        // Restore commanders
        for commanderData in data.commanders {
            if let commander = reconstructCommander(from: commanderData) {
                player.addCommander(commander)
            }
        }
        
        // Restore armies
        for armyData in data.armies {
            if let army = reconstructArmy(from: armyData, player: player) {
                player.addArmy(army)
                player.addEntity(army)
            }
        }
        
        // Restore other entities (villagers)
        for entityData in data.entities {
            if entityData.entityType == "villagerGroup" {
                if let villagers = reconstructVillagerGroup(from: entityData, player: player) {
                    player.addEntity(villagers)
                }
            }
        }
        
        // Restore diplomacy (will be connected after all players loaded)
        for (playerIDString, statusString) in data.diplomacyRelations {
            // Placeholder - diplomacy reconnection happens elsewhere if needed
        }
        
        return player
    }
    
    private func reconstructCommander(from data: CommanderSaveData) -> Commander? {
        guard let rank = CommanderRank(rawValue: data.rank),
              let specialty = CommanderSpecialty(rawValue: data.specialty) else {
            return nil
        }
        
        let color = UIColor(
            red: data.colorRed,
            green: data.colorGreen,
            blue: data.colorBlue,
            alpha: data.colorAlpha
        )
        
        let commander = Commander(
            id: UUID(uuidString: data.id) ?? UUID(),
            name: data.name,
            rank: rank,
            specialty: specialty,
            baseLeadership: data.baseLeadership,
            baseTactics: data.baseTactics,
            portraitColor: color
        )
        
        // Manually set experience and level (need to expose these as settable)
        // For now, add experience to reach the saved level
        let targetXP = data.level * 100 + data.experience
        commander.addExperience(targetXP)
        
        return commander
    }
    
    private func reconstructArmy(from data: ArmySaveData, player: Player) -> Army? {
        let coord = HexCoordinate(q: data.q, r: data.r)
        
        let commander: Commander?
        if let commanderID = data.commanderID {
            commander = player.commanders.first { $0.id.uuidString == commanderID }
        } else {
            commander = nil
        }
        
        let army = Army(
            id: UUID(uuidString: data.id) ?? UUID(),  // ✅ FIX: Preserve original army ID
            name: data.name,
            coordinate: coord,
            commander: commander,
            owner: player
        )
        
        // ✅ FIX: Re-establish the two-way commander-army linkage
        if let cmd = commander {
            cmd.assignedArmy = army
        }
        
        // Restore military composition
        for (unitKey, count) in data.militaryComposition {
            if let unitType = MilitaryUnitType(rawValue: unitKey) {
                army.addMilitaryUnits(unitType, count: count)
            }
        }
        
        return army
    }

    
    private func reconstructVillagerGroup(from data: EntitySaveData, player: Player) -> VillagerGroup? {
        let coord = HexCoordinate(q: data.q, r: data.r)
        let villagers = VillagerGroup(
            name: data.name,
            coordinate: coord,
            villagerCount: data.villagerCount ?? 0,
            owner: player
        )
        
        // Restore task
        if let taskString = data.currentTask {
            switch taskString {
            case "idle":
                villagers.currentTask = .idle
                
            case "moving":
                if let q = data.taskTargetQ, let r = data.taskTargetR {
                    villagers.currentTask = .moving(HexCoordinate(q: q, r: r))
                }
                
            case "gatheringResource":
                // ✅ Store target coordinate for offline processing
                if let q = data.taskTargetQ, let r = data.taskTargetR {
                    villagers.taskTarget = HexCoordinate(q: q, r: r)
                    villagers.currentTask = .idle  // Will be reconnected later
                    print("📂 Restored villager \(villagers.name) with taskTarget at (\(q), \(r))")
                } else {
                    print("⚠️ gatheringResource task but no coordinates for \(villagers.name)")
                }
                
            case "hunting":
                if let q = data.taskTargetQ, let r = data.taskTargetR {
                    villagers.taskTarget = HexCoordinate(q: q, r: r)
                    villagers.currentTask = .idle
                    print("📂 Restored villager \(villagers.name) hunting target at (\(q), \(r))")
                }
                
            case "building", "repairing":
                if let q = data.taskTargetQ, let r = data.taskTargetR {
                    villagers.taskTarget = HexCoordinate(q: q, r: r)
                }
                villagers.currentTask = .idle
                
            case "upgrading":
                villagers.currentTask = .idle  // Can't restore building reference, set to idle
                
            default:
                if taskString.starts(with: "gathering_") {
                    let resourceName = String(taskString.dropFirst("gathering_".count))
                    if let resourceType = ResourceType(rawValue: resourceName) {
                        villagers.currentTask = .gathering(resourceType)
                    }
                } else {
                    villagers.currentTask = .idle
                }
            }
        }
        
        return villagers
    }
    
    private func reconstructBuilding(from data: BuildingSaveData, allPlayers: [Player]) -> BuildingNode? {
        guard let buildingType = BuildingType(rawValue: data.buildingType) else {
            return nil
        }
        
        let owner = allPlayers.first { $0.id.uuidString == data.ownerID }
        let coord = HexCoordinate(q: data.q, r: data.r)
        
        let building = BuildingNode(coordinate: coord, buildingType: buildingType, owner: owner)
        building.state = stringToBuildingState(data.state)
        building.health = data.health
        building.constructionProgress = data.constructionProgress
        building.constructionStartTime = data.constructionStartTime
        building.buildersAssigned = data.buildersAssigned
        building.level = data.level
        building.upgradeProgress = data.upgradeProgress
        building.upgradeStartTime = data.upgradeStartTime
        
        // Restore garrison
        for (unitKey, count) in data.garrison {
            if let unitType = MilitaryUnitType(rawValue: unitKey) {
                building.addToGarrison(unitType: unitType, quantity: count)
            }
        }
        
        building.villagerGarrison = data.villagerGarrison
        
        // Restore training queues
        for queueData in data.trainingQueue {
            if let unitType = MilitaryUnitType(rawValue: queueData.unitType) {
                var entry = TrainingQueueEntry(
                    unitType: unitType,
                    quantity: queueData.quantity,
                    startTime: queueData.startTime
                )
                entry.progress = queueData.progress
                building.trainingQueue.append(entry)
            }
        }
        
        for queueData in data.villagerTrainingQueue {
            var entry = VillagerTrainingEntry(
                quantity: queueData.quantity,
                startTime: queueData.startTime
            )
            entry.progress = queueData.progress
            building.villagerTrainingQueue.append(entry)
        }
        
        return building
    }
    
    private func reconstructResourcePoint(from data: ResourcePointSaveData) -> ResourcePointNode? {
        guard let resourceType = ResourcePointType(rawValue: data.resourceType) else {
            print("❌ Unknown resource type: \(data.resourceType)")
            return nil
        }
        
        // ✅ FIX: Skip depleted resources
        if data.remainingAmount <= 0 {
            print("⏭️ Skipping depleted resource at (\(data.q), \(data.r))")
            return nil
        }
        
        let coord = HexCoordinate(q: data.q, r: data.r)
        let resource = ResourcePointNode(coordinate: coord, resourceType: resourceType)
        
        // ✅ FIX: Actually restore the saved values!
        resource.setRemainingAmount(data.remainingAmount)
        resource.setCurrentHealth(data.currentHealth)
        
        print("📦 Restored \(resourceType.displayName) at (\(coord.q), \(coord.r)) with \(data.remainingAmount) remaining")
        
        return resource
    }
    
    // MARK: - Helper Conversions
    
    private func terrainTypeToString(_ terrain: TerrainType) -> String {
        switch terrain {
        case .grass: return "grass"
        case .water: return "water"
        case .mountain: return "mountain"
        case .desert: return "desert"
        case .forest: return "forest"
        case .hill: return "hill"
        }
    }
    
    private func stringToTerrainType(_ string: String) -> TerrainType {
        switch string {
        case "grass": return .grass
        case "water": return .water
        case "mountain": return .mountain
        case "desert": return .desert
        case "forest": return .forest
        case "hill": return .hill
        default: return .grass
        }
    }
    
    private func buildingStateToString(_ state: BuildingState) -> String {
        switch state {
        case .planning: return "planning"
        case .constructing: return "constructing"
        case .completed: return "completed"
        case .damaged: return "damaged"
        case .destroyed: return "destroyed"
        case .upgrading: return "upgrading"
        }
    }
    
    private func stringToBuildingState(_ string: String) -> BuildingState {
        switch string {
        case "planning": return .planning
        case "constructing": return .constructing
        case "completed": return .completed
        case "damaged": return .damaged
        case "destroyed": return .destroyed
        case "upgrading": return .upgrading
        default: return .planning
        }
    }
    
    private func applyOfflineProgress(hexMap: HexMap, player: Player, saveDate: Date) {
        let elapsedSeconds = Date().timeIntervalSince(saveDate)
        
        // Cap offline time (e.g., max 8 hours)
        let maxOfflineSeconds: TimeInterval = 8 * 60 * 60
        let cappedElapsed = min(elapsedSeconds, maxOfflineSeconds)
        
        guard cappedElapsed > 1 else {
            print("⏰ Less than 1 second elapsed, skipping offline progress")
            return
        }
        
        print("⏰ Applying offline progress for \(Int(cappedElapsed)) seconds...")
        print("   📊 Player entities count: \(player.entities.count)")
        print("   📊 HexMap resource points count: \(hexMap.resourcePoints.count)")
        
        // Track which resources need rate adjustments due to depletion
        var rateReductions: [ResourceType: Double] = [:]
        var depletedResources: [ResourcePointNode] = []
        var villagersFoundGathering = 0
        
        // Step 1: Handle resource depletion from active villagers
        for entity in player.entities {
            guard let villagerGroup = entity as? VillagerGroup else {
                continue
            }
            
            // Debug: Print villager info
            print("   🔍 Checking villager: \(villagerGroup.name)")
            print("      currentTask: \(villagerGroup.currentTask.displayName)")
            
            guard let targetCoord = villagerGroup.taskTarget else {
                print("      ❌ No taskTarget, skipping")
                continue
            }
            
            // Find the resource they were gathering
            guard let resourcePoint = hexMap.resourcePoints.first(where: {
                $0.coordinate == targetCoord
            }) else {
                print("      ❌ No resource found at (\(targetCoord.q), \(targetCoord.r))")
                // List all resource coordinates for debugging
                print("      Available resources:")
                for rp in hexMap.resourcePoints.prefix(5) {
                    print("         - (\(rp.coordinate.q), \(rp.coordinate.r)): \(rp.resourceType.displayName)")
                }
                continue
            }
            
            villagersFoundGathering += 1
            print("      ✅ Found resource: \(resourcePoint.resourceType.displayName) at (\(targetCoord.q), \(targetCoord.r))")
            print("      📦 Resource before: \(resourcePoint.remainingAmount)")
            
            // Calculate how much they would gather
            let gatherRatePerSecond = 0.2 * Double(villagerGroup.villagerCount)
            let wouldGather = Int(gatherRatePerSecond * cappedElapsed)
            
            // Cap by what's actually available
            let actualGathered = min(wouldGather, resourcePoint.remainingAmount)
            let newRemaining = resourcePoint.remainingAmount - actualGathered
            
            print("      ⛏️ \(villagerGroup.name) (\(villagerGroup.villagerCount) villagers)")
            print("         Rate: \(gatherRatePerSecond)/s × \(Int(cappedElapsed))s = \(wouldGather) potential")
            print("         Actually depleted: \(actualGathered)")
            print("         Resource: \(resourcePoint.remainingAmount) → \(newRemaining)")
            
            // Update resource remaining amount
            resourcePoint.setRemainingAmount(newRemaining)
            
            // Verify it was set
            print("      📦 Resource after setRemainingAmount: \(resourcePoint.remainingAmount)")
            
            // Check if resource is now depleted
            if newRemaining <= 0 {
                depletedResources.append(resourcePoint)
                
                // Track rate reduction needed
                let resourceType = resourcePoint.resourceType.resourceYield
                let rateContribution = gatherRatePerSecond
                rateReductions[resourceType, default: 0] += rateContribution
                
                // Clear villager task
                villagerGroup.clearTask()
                
                print("      ⚠️ Resource DEPLETED! \(villagerGroup.name) is now idle")
            }
        }
        
        print("   📊 Found \(villagersFoundGathering) villager(s) that were gathering")
        
        // Step 2: Apply rate reductions for depleted resources BEFORE calculating accumulation
        for (resourceType, reduction) in rateReductions {
            player.decreaseCollectionRate(resourceType, amount: reduction)
            print("   📉 \(resourceType.displayName) rate reduced by \(reduction)/s due to depletion")
        }
        
        // Step 3: Calculate resource accumulation using (potentially adjusted) rates
        print("   💰 Resource accumulation:")
        for type in ResourceType.allCases {
            let rate = player.getCollectionRate(type)
            let accumulated = Int(rate * cappedElapsed)
            
            if accumulated > 0 {
                player.addResource(type, amount: accumulated)
                print("      \(type.displayName): +\(accumulated) (rate \(rate)/s × \(Int(cappedElapsed))s)")
            }
        }
        
        // Step 4: Remove depleted resources from map
        for resource in depletedResources {
            hexMap.resourcePoints.removeAll { $0.coordinate == resource.coordinate }
        }
        
        if !depletedResources.isEmpty {
            print("   🗑️ Removed \(depletedResources.count) depleted resource(s)")
        }
        
        // Final summary
        print("📊 Final resources after offline progress:")
        for type in ResourceType.allCases {
            print("   \(type.displayName): \(player.getResource(type)) (rate: \(player.getCollectionRate(type))/s)")
        }
    }
}
