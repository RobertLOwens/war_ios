// ============================================================================
// FILE: AICommandData.swift
// LOCATION: Grow2 Shared/Data/AICommandData.swift
// PURPOSE: Serializable envelope for AI commands in online sessions
// ============================================================================

import Foundation

// MARK: - AI Command Type

enum AICommandType: String, Codable {
    case aiBuild
    case aiTrainMilitary
    case aiTrainVillager
    case aiDeployArmy
    case aiDeployVillagers
    case aiGather
    case aiMove
    case aiStartResearch
    case aiEntrench
    case aiUpgradeUnit
}

// MARK: - AI Command Parameter Structs

struct AIBuildParams: Codable {
    let buildingType: String
    let coordinateQ: Int
    let coordinateR: Int
    let rotation: Int
}

struct AITrainMilitaryParams: Codable {
    let buildingID: String
    let unitType: String
    let quantity: Int
}

struct AITrainVillagerParams: Codable {
    let buildingID: String
    let quantity: Int
}

struct AIDeployArmyParams: Codable {
    let buildingID: String
    let composition: [String: Int]  // unitType.rawValue -> count
}

struct AIDeployVillagersParams: Codable {
    let buildingID: String
    let quantity: Int
}

struct AIGatherParams: Codable {
    let villagerGroupID: String
    let resourcePointID: String
}

struct AIMoveParams: Codable {
    let entityID: String
    let destinationQ: Int
    let destinationR: Int
    let isArmy: Bool
}

struct AIStartResearchParams: Codable {
    let researchType: String
}

struct AIEntrenchParams: Codable {
    let armyID: String
}

struct AIUpgradeUnitParams: Codable {
    let upgradeType: String
    let buildingID: String
}

// MARK: - AI Command Envelope

struct AICommandEnvelope: Codable {
    let aiCommandType: AICommandType
    let commandID: String
    let playerID: String
    let timestamp: TimeInterval
    let parameters: Data  // JSON-encoded parameter struct

    // MARK: - Serialize from BaseEngineCommand

    static func from(_ command: BaseEngineCommand) -> AICommandEnvelope? {
        let encoder = JSONEncoder()

        do {
            let aiType: AICommandType
            let paramData: Data

            switch command {
            case let cmd as AIBuildCommand:
                aiType = .aiBuild
                paramData = try encoder.encode(AIBuildParams(
                    buildingType: cmd.buildingType.rawValue,
                    coordinateQ: cmd.coordinate.q,
                    coordinateR: cmd.coordinate.r,
                    rotation: cmd.rotation
                ))

            case let cmd as AITrainMilitaryCommand:
                aiType = .aiTrainMilitary
                paramData = try encoder.encode(AITrainMilitaryParams(
                    buildingID: cmd.buildingID.uuidString,
                    unitType: cmd.unitType.rawValue,
                    quantity: cmd.quantity
                ))

            case let cmd as AITrainVillagerCommand:
                aiType = .aiTrainVillager
                paramData = try encoder.encode(AITrainVillagerParams(
                    buildingID: cmd.buildingID.uuidString,
                    quantity: cmd.quantity
                ))

            case let cmd as AIDeployArmyCommand:
                aiType = .aiDeployArmy
                var comp: [String: Int] = [:]
                for (unitType, count) in cmd.composition {
                    comp[unitType.rawValue] = count
                }
                paramData = try encoder.encode(AIDeployArmyParams(
                    buildingID: cmd.buildingID.uuidString,
                    composition: comp
                ))

            case let cmd as AIDeployVillagersCommand:
                aiType = .aiDeployVillagers
                paramData = try encoder.encode(AIDeployVillagersParams(
                    buildingID: cmd.buildingID.uuidString,
                    quantity: cmd.quantity
                ))

            case let cmd as AIGatherCommand:
                aiType = .aiGather
                paramData = try encoder.encode(AIGatherParams(
                    villagerGroupID: cmd.villagerGroupID.uuidString,
                    resourcePointID: cmd.resourcePointID.uuidString
                ))

            case let cmd as AIMoveCommand:
                aiType = .aiMove
                paramData = try encoder.encode(AIMoveParams(
                    entityID: cmd.entityID.uuidString,
                    destinationQ: cmd.destination.q,
                    destinationR: cmd.destination.r,
                    isArmy: cmd.isArmy
                ))

            case let cmd as AIStartResearchCommand:
                aiType = .aiStartResearch
                paramData = try encoder.encode(AIStartResearchParams(
                    researchType: cmd.researchType.rawValue
                ))

            case let cmd as AIEntrenchCommand:
                aiType = .aiEntrench
                paramData = try encoder.encode(AIEntrenchParams(
                    armyID: cmd.armyID.uuidString
                ))

            case let cmd as AIUpgradeUnitCommand:
                aiType = .aiUpgradeUnit
                paramData = try encoder.encode(AIUpgradeUnitParams(
                    upgradeType: cmd.upgradeType.rawValue,
                    buildingID: cmd.buildingID.uuidString
                ))

            default:
                debugLog("Unknown AI command type: \(type(of: command))")
                return nil
            }

            return AICommandEnvelope(
                aiCommandType: aiType,
                commandID: command.id.uuidString,
                playerID: command.playerID.uuidString,
                timestamp: command.timestamp,
                parameters: paramData
            )
        } catch {
            debugLog("Failed to serialize AI command: \(error)")
            return nil
        }
    }

    // MARK: - Reconstruct to BaseEngineCommand

    func toEngineCommand() -> BaseEngineCommand? {
        guard let pid = UUID(uuidString: playerID) else { return nil }
        let decoder = JSONDecoder()

        do {
            switch aiCommandType {
            case .aiBuild:
                let params = try decoder.decode(AIBuildParams.self, from: parameters)
                guard let buildingType = BuildingType(rawValue: params.buildingType) else { return nil }
                let coord = HexCoordinate(q: params.coordinateQ, r: params.coordinateR)
                return AIBuildCommand(playerID: pid, buildingType: buildingType, coordinate: coord, rotation: params.rotation)

            case .aiTrainMilitary:
                let params = try decoder.decode(AITrainMilitaryParams.self, from: parameters)
                guard let buildingID = UUID(uuidString: params.buildingID),
                      let unitType = MilitaryUnitType(rawValue: params.unitType) else { return nil }
                return AITrainMilitaryCommand(playerID: pid, buildingID: buildingID, unitType: unitType, quantity: params.quantity)

            case .aiTrainVillager:
                let params = try decoder.decode(AITrainVillagerParams.self, from: parameters)
                guard let buildingID = UUID(uuidString: params.buildingID) else { return nil }
                return AITrainVillagerCommand(playerID: pid, buildingID: buildingID, quantity: params.quantity)

            case .aiDeployArmy:
                let params = try decoder.decode(AIDeployArmyParams.self, from: parameters)
                guard let buildingID = UUID(uuidString: params.buildingID) else { return nil }
                var composition: [MilitaryUnitType: Int] = [:]
                for (key, value) in params.composition {
                    if let unitType = MilitaryUnitType(rawValue: key) {
                        composition[unitType] = value
                    }
                }
                return AIDeployArmyCommand(playerID: pid, buildingID: buildingID, composition: composition)

            case .aiDeployVillagers:
                let params = try decoder.decode(AIDeployVillagersParams.self, from: parameters)
                guard let buildingID = UUID(uuidString: params.buildingID) else { return nil }
                return AIDeployVillagersCommand(playerID: pid, buildingID: buildingID, quantity: params.quantity)

            case .aiGather:
                let params = try decoder.decode(AIGatherParams.self, from: parameters)
                guard let villagerGroupID = UUID(uuidString: params.villagerGroupID),
                      let resourcePointID = UUID(uuidString: params.resourcePointID) else { return nil }
                return AIGatherCommand(playerID: pid, villagerGroupID: villagerGroupID, resourcePointID: resourcePointID)

            case .aiMove:
                let params = try decoder.decode(AIMoveParams.self, from: parameters)
                guard let entityID = UUID(uuidString: params.entityID) else { return nil }
                let dest = HexCoordinate(q: params.destinationQ, r: params.destinationR)
                return AIMoveCommand(playerID: pid, entityID: entityID, destination: dest, isArmy: params.isArmy)

            case .aiStartResearch:
                let params = try decoder.decode(AIStartResearchParams.self, from: parameters)
                guard let researchType = ResearchType(rawValue: params.researchType) else { return nil }
                return AIStartResearchCommand(playerID: pid, researchType: researchType)

            case .aiEntrench:
                let params = try decoder.decode(AIEntrenchParams.self, from: parameters)
                guard let armyID = UUID(uuidString: params.armyID) else { return nil }
                return AIEntrenchCommand(playerID: pid, armyID: armyID)

            case .aiUpgradeUnit:
                let params = try decoder.decode(AIUpgradeUnitParams.self, from: parameters)
                guard let upgradeType = UnitUpgradeType(rawValue: params.upgradeType),
                      let buildingID = UUID(uuidString: params.buildingID) else { return nil }
                return AIUpgradeUnitCommand(playerID: pid, upgradeType: upgradeType, buildingID: buildingID)
            }
        } catch {
            debugLog("Failed to deserialize AI command: \(error)")
            return nil
        }
    }
}
