// ============================================================================
// FILE: Grow2 Shared/Commands/CommandExecutor.swift
// PURPOSE: Manages command execution, validation, and history
// ============================================================================

import Foundation

// MARK: - Command Executor

class CommandExecutor {
    
    // MARK: - Singleton
    static let shared = CommandExecutor()
    
    // MARK: - Properties
    
    private var context: CommandContext?
    private var commandHistory: [AnyCommand] = []
    private let maxHistorySize = 1000
    
    /// Enable/disable command logging
    var loggingEnabled: Bool = true
    
    // MARK: - Setup
    
    func setup(hexMap: HexMap, player: Player, allPlayers: [Player]) {
        self.context = CommandContext(hexMap: hexMap, player: player, allPlayers: allPlayers)
    }
    
    func setCallbacks(onResourcesChanged: @escaping () -> Void, onAlert: @escaping (String, String) -> Void) {
        context?.onResourcesChanged = onResourcesChanged
        context?.onAlert = onAlert
    }
    
    // MARK: - Execute Commands
    
    /// Validates and executes a command
    @discardableResult
    func execute<T: GameCommand>(_ command: T) -> CommandResult {
        guard let context = context else {
            return .failure(reason: "CommandExecutor not initialized")
        }
        
        // Validate
        let validationResult = command.validate(in: context)
        guard validationResult.succeeded else {
            if loggingEnabled {
                print("❌ Command \(T.commandType) validation failed: \(validationResult.failureReason ?? "unknown")")
            }
            return validationResult
        }
        
        // Execute
        let executeResult = command.execute(in: context)
        
        if executeResult.succeeded {
            // Add to history
            if let wrapped = try? AnyCommand(command) {
                commandHistory.append(wrapped)
                
                // Trim history if needed
                if commandHistory.count > maxHistorySize {
                    commandHistory.removeFirst(commandHistory.count - maxHistorySize)
                }
            }
            
            if loggingEnabled {
                print("✅ Command \(T.commandType) executed successfully")
            }
        } else {
            if loggingEnabled {
                print("❌ Command \(T.commandType) execution failed: \(executeResult.failureReason ?? "unknown")")
            }
        }
        
        return executeResult
    }
    
    // MARK: - History
    
    /// Get command history for replay or debugging
    func getHistory() -> [AnyCommand] {
        return commandHistory
    }
    
    /// Clear command history
    func clearHistory() {
        commandHistory.removeAll()
    }
    
    /// Export history as JSON data (for replay files)
    func exportHistory() -> Data? {
        return try? JSONEncoder().encode(commandHistory)
    }
    
    /// Import history from JSON data
    func importHistory(from data: Data) -> Bool {
        guard let history = try? JSONDecoder().decode([AnyCommand].self, from: data) else {
            return false
        }
        commandHistory = history
        return true
    }
}
