// ============================================================================
// FILE: Grow2 Shared/Engine/AIResearchPlanner.swift
// PURPOSE: AI research planning - research selection, scoring, and execution
// ============================================================================

import Foundation

/// Handles AI research decisions: selecting and starting research based on game state
struct AIResearchPlanner {

    // MARK: - Configuration

    private let researchCheckInterval = GameConfig.AI.Intervals.researchCheck

    // MARK: - Research Commands

    func generateResearchCommands(aiState: AIPlayerState, gameState: GameState, currentTime: TimeInterval) -> [EngineCommand] {
        var commands: [EngineCommand] = []
        let playerID = aiState.playerID

        guard currentTime - aiState.lastResearchCheckTime >= researchCheckInterval else { return [] }
        aiState.lastResearchCheckTime = currentTime

        guard let player = gameState.getPlayer(id: playerID) else { return [] }

        if player.isResearchActive() {
            return []
        }

        if let bestResearch = selectBestResearch(aiState: aiState, gameState: gameState) {
            if canAffordResearch(bestResearch, playerID: playerID, gameState: gameState) {
                commands.append(AIStartResearchCommand(playerID: playerID, researchType: bestResearch))
                debugLog("🤖 AI starting research: \(bestResearch.displayName)")
            }
        }

        return commands
    }

    // MARK: - Research Selection

    private func selectBestResearch(aiState: AIPlayerState, gameState: GameState) -> ResearchType? {
        let playerID = aiState.playerID
        let availableResearch = getAvailableResearch(for: playerID, gameState: gameState)

        guard !availableResearch.isEmpty else { return nil }

        var scoredResearch: [(ResearchType, Double)] = []
        for research in availableResearch {
            let score = scoreResearch(research, aiState: aiState, gameState: gameState)
            scoredResearch.append((research, score))
        }

        scoredResearch.sort { $0.1 > $1.1 }
        return scoredResearch.first?.0
    }

    // MARK: - Research Scoring

    private func scoreResearch(_ research: ResearchType, aiState: AIPlayerState, gameState: GameState) -> Double {
        var score = 0.0

        // Base score: prefer lower tier research (cheaper, faster)
        score += Double(4 - research.tier) * 10.0

        // State-based priorities
        switch aiState.currentState {
        case .peace:
            if research.category == .economic {
                score += 30.0
                switch research {
                case .farmGatheringI, .farmGatheringII, .farmGatheringIII:
                    score += 15.0
                case .lumberCampGatheringI, .lumberCampGatheringII, .lumberCampGatheringIII:
                    score += 12.0
                case .miningCampGatheringI, .miningCampGatheringII, .miningCampGatheringIII:
                    score += 10.0
                case .populationCapacityI, .populationCapacityII, .populationCapacityIII:
                    score += 8.0
                case .buildingSpeedI, .buildingSpeedII, .buildingSpeedIII:
                    score += 5.0
                default:
                    break
                }
            }

        case .alert:
            if research.category == .military {
                score += 25.0
                switch research {
                case .infantryMeleeArmorI, .infantryMeleeArmorII, .infantryMeleeArmorIII,
                     .infantryPierceArmorI, .infantryPierceArmorII, .infantryPierceArmorIII:
                    score += 10.0
                case .militaryTrainingSpeedI, .militaryTrainingSpeedII, .militaryTrainingSpeedIII:
                    score += 15.0
                default:
                    break
                }
            } else {
                score += 15.0
            }

        case .defense:
            if research.category == .military {
                score += 30.0
                switch research {
                case .fortifiedBuildingsI, .fortifiedBuildingsII, .fortifiedBuildingsIII:
                    score += 20.0
                case .buildingBludgeonArmorI, .buildingBludgeonArmorII, .buildingBludgeonArmorIII:
                    score += 18.0
                case .infantryMeleeArmorI, .infantryMeleeArmorII, .infantryMeleeArmorIII,
                     .cavalryMeleeArmorI, .cavalryMeleeArmorII, .cavalryMeleeArmorIII:
                    score += 12.0
                case .retreatSpeedI, .retreatSpeedII, .retreatSpeedIII:
                    score += 8.0
                default:
                    break
                }
            }

        case .attack:
            if research.category == .military {
                score += 30.0
                switch research {
                case .infantryMeleeAttackI, .infantryMeleeAttackII, .infantryMeleeAttackIII,
                     .cavalryMeleeAttackI, .cavalryMeleeAttackII, .cavalryMeleeAttackIII:
                    score += 15.0
                case .piercingDamageI, .piercingDamageII, .piercingDamageIII:
                    score += 12.0
                case .marchSpeedI, .marchSpeedII, .marchSpeedIII:
                    score += 10.0
                case .siegeBludgeonDamageI, .siegeBludgeonDamageII, .siegeBludgeonDamageIII:
                    score += 15.0
                default:
                    break
                }
            }

        case .retreat:
            if research.category == .military {
                switch research {
                case .retreatSpeedI, .retreatSpeedII, .retreatSpeedIII:
                    score += 25.0
                case .infantryMeleeArmorI, .infantryMeleeArmorII, .infantryMeleeArmorIII,
                     .cavalryMeleeArmorI, .cavalryMeleeArmorII, .cavalryMeleeArmorIII:
                    score += 15.0
                default:
                    break
                }
            }
        }

        return score
    }

    // MARK: - Research Availability

    private func getAvailableResearch(for playerID: UUID, gameState: GameState) -> [ResearchType] {
        guard let player = gameState.getPlayer(id: playerID) else { return [] }

        let ccLevel = gameState.getCityCenter(forPlayer: playerID)?.level ?? 1

        var available: [ResearchType] = []
        for research in ResearchType.allCases {
            if player.hasCompletedResearch(research.rawValue) {
                continue
            }

            if research.cityCenterLevelRequirement > ccLevel {
                continue
            }

            var prereqsMet = true
            for prereq in research.prerequisites {
                if !player.hasCompletedResearch(prereq.rawValue) {
                    prereqsMet = false
                    break
                }
            }

            if prereqsMet {
                available.append(research)
            }
        }

        return available
    }

    private func canAffordResearch(_ research: ResearchType, playerID: UUID, gameState: GameState) -> Bool {
        guard let player = gameState.getPlayer(id: playerID) else { return false }

        for (resourceType, amount) in research.cost {
            if !player.hasResource(resourceType, amount: amount) {
                return false
            }
        }
        return true
    }
}
