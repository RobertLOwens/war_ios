// ============================================================================
// FILE: AdjacencyBonusManager.swift
// LOCATION: Grow2 Shared/AdjacencyBonusManager.swift
// PURPOSE: Manages adjacency bonuses for buildings
//          - Mills boost adjacent farms (+25% gather rate)
//          - Warehouses boost adjacent camps/farms (+15% gather rate)
//          - Warehouses reduce training cost at adjacent military buildings (-10%)
//          - Roads extend camp coverage for resource gathering
// ============================================================================

import Foundation

// MARK: - Adjacency Bonus Data

struct AdjacencyBonusData {
    var gatherRateBonus: Double = 0.0       // Percentage bonus to gather rate
    var trainingCostReduction: Double = 0.0 // Percentage reduction in training cost
    var bonusSources: [String] = []          // Description of bonus sources for UI
}

// MARK: - Adjacency Bonus Manager

class AdjacencyBonusManager {

    static let shared = AdjacencyBonusManager()

    // MARK: - Bonus Constants

    /// Mill provides +25% gather rate to adjacent farms
    static let millFarmBonus: Double = 0.25

    /// Warehouse provides +15% gather rate to adjacent economic buildings (camps, farms)
    static let warehouseEconomicBonus: Double = 0.15

    /// Warehouse provides -10% training cost reduction to adjacent military buildings
    static let warehouseMilitaryReduction: Double = 0.10

    // MARK: - Cached Bonuses

    private var cachedBonuses: [UUID: AdjacencyBonusData] = [:]

    // Weak reference to hexMap for recalculation
    private weak var hexMap: HexMap?

    private init() {}

    // MARK: - Setup

    func setup(hexMap: HexMap) {
        self.hexMap = hexMap
        recalculateAllBonuses()
    }

    func reset() {
        cachedBonuses.removeAll()
        hexMap = nil
    }

    // MARK: - Get Bonuses

    /// Returns the gather rate bonus for a building (as a multiplier addition, e.g., 0.25 for +25%)
    func getGatherRateBonus(for buildingID: UUID) -> Double {
        return cachedBonuses[buildingID]?.gatherRateBonus ?? 0.0
    }

    /// Returns the training cost reduction for a building (as a percentage, e.g., 0.10 for -10%)
    func getTrainingCostReduction(for buildingID: UUID) -> Double {
        return cachedBonuses[buildingID]?.trainingCostReduction ?? 0.0
    }

    /// Returns the bonus sources description for UI display
    func getBonusSources(for buildingID: UUID) -> [String] {
        return cachedBonuses[buildingID]?.bonusSources ?? []
    }

    /// Returns full bonus data for a building
    func getBonusData(for buildingID: UUID) -> AdjacencyBonusData? {
        return cachedBonuses[buildingID]
    }

    // MARK: - Recalculation

    /// Recalculates bonuses for buildings near a specific coordinate
    /// Call this when a building is placed or removed
    func recalculateAffectedBuildings(near coordinate: HexCoordinate) {
        guard let hexMap = hexMap else { return }

        // Get all buildings within 2 tiles of the coordinate (to catch adjacency effects)
        let nearbyBuildings = hexMap.getBuildingsNear(coordinate: coordinate, radius: 2)

        for building in nearbyBuildings {
            recalculateBonusesForBuilding(building)
        }

        print("🔄 Recalculated adjacency bonuses for \(nearbyBuildings.count) buildings near (\(coordinate.q), \(coordinate.r))")
    }

    /// Recalculates all bonuses for all buildings
    func recalculateAllBonuses() {
        guard let hexMap = hexMap else { return }

        cachedBonuses.removeAll()

        for building in hexMap.buildings {
            recalculateBonusesForBuilding(building)
        }

        print("🔄 Recalculated all adjacency bonuses for \(hexMap.buildings.count) buildings")
    }

    /// Recalculates bonuses for a specific building
    private func recalculateBonusesForBuilding(_ building: BuildingNode) {
        guard let hexMap = hexMap else { return }
        guard building.state == .completed else {
            // Remove cached bonuses for non-completed buildings
            cachedBonuses.removeValue(forKey: building.data.id)
            return
        }

        var bonusData = AdjacencyBonusData()

        // Get adjacent buildings
        let adjacentBuildings = getAdjacentBuildings(for: building, in: hexMap)

        // Calculate bonuses based on building type
        switch building.buildingType {
        case .farm:
            // Farms get bonuses from adjacent mills and warehouses
            for adjacent in adjacentBuildings {
                guard adjacent.state == .completed else { continue }

                if adjacent.buildingType == .mill {
                    bonusData.gatherRateBonus += AdjacencyBonusManager.millFarmBonus
                    bonusData.bonusSources.append("⚙️ Mill: +\(Int(AdjacencyBonusManager.millFarmBonus * 100))% gather rate")
                }

                if adjacent.buildingType == .warehouse {
                    bonusData.gatherRateBonus += AdjacencyBonusManager.warehouseEconomicBonus
                    bonusData.bonusSources.append("📦 Warehouse: +\(Int(AdjacencyBonusManager.warehouseEconomicBonus * 100))% gather rate")
                }
            }

        case .lumberCamp, .miningCamp:
            // Camps get bonuses from adjacent warehouses
            for adjacent in adjacentBuildings {
                guard adjacent.state == .completed else { continue }

                if adjacent.buildingType == .warehouse {
                    bonusData.gatherRateBonus += AdjacencyBonusManager.warehouseEconomicBonus
                    bonusData.bonusSources.append("📦 Warehouse: +\(Int(AdjacencyBonusManager.warehouseEconomicBonus * 100))% gather rate")
                }
            }

        case .barracks, .archeryRange, .stable, .siegeWorkshop:
            // Military buildings get training cost reduction from adjacent warehouses
            for adjacent in adjacentBuildings {
                guard adjacent.state == .completed else { continue }

                if adjacent.buildingType == .warehouse {
                    bonusData.trainingCostReduction += AdjacencyBonusManager.warehouseMilitaryReduction
                    bonusData.bonusSources.append("📦 Warehouse: -\(Int(AdjacencyBonusManager.warehouseMilitaryReduction * 100))% training cost")
                }
            }

        default:
            break
        }

        // Store the calculated bonuses
        if bonusData.gatherRateBonus > 0 || bonusData.trainingCostReduction > 0 {
            cachedBonuses[building.data.id] = bonusData
        } else {
            cachedBonuses.removeValue(forKey: building.data.id)
        }
    }

    /// Gets all buildings adjacent to a building (considering multi-tile buildings)
    private func getAdjacentBuildings(for building: BuildingNode, in hexMap: HexMap) -> [BuildingNode] {
        var adjacentBuildings: [BuildingNode] = []
        var checkedCoordinates: Set<HexCoordinate> = []

        // Get all coordinates this building occupies
        let occupiedCoords = building.buildingType.getOccupiedCoordinates(
            anchor: building.coordinate,
            rotation: building.data.rotation
        )
        let occupiedSet = Set(occupiedCoords)

        // For each occupied tile, check all neighbors
        for coord in occupiedCoords {
            let neighbors = coord.neighbors()

            for neighbor in neighbors {
                // Skip if we've already checked this coordinate
                guard !checkedCoordinates.contains(neighbor) else { continue }
                checkedCoordinates.insert(neighbor)

                // Skip if this neighbor is part of our own building
                guard !occupiedSet.contains(neighbor) else { continue }

                // Check if there's a building at this neighbor
                if let adjacentBuilding = hexMap.getBuilding(at: neighbor) {
                    // Don't add the same building twice
                    if !adjacentBuildings.contains(where: { $0.data.id == adjacentBuilding.data.id }) {
                        adjacentBuildings.append(adjacentBuilding)
                    }
                }
            }
        }

        return adjacentBuildings
    }

    // MARK: - Debug

    func printStatus() {
        print("\n🏘️ Adjacency Bonus Status:")
        for (buildingID, bonusData) in cachedBonuses {
            print("   Building \(buildingID.uuidString.prefix(8)):")
            print("      Gather Rate Bonus: +\(Int(bonusData.gatherRateBonus * 100))%")
            print("      Training Cost Reduction: -\(Int(bonusData.trainingCostReduction * 100))%")
            for source in bonusData.bonusSources {
                print("      - \(source)")
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let adjacencyBonusesDidChange = Notification.Name("adjacencyBonusesDidChange")
}
