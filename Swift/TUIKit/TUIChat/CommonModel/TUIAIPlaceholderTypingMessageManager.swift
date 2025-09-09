//
//  TUIAIPlaceholderTypingMessageManager.swift
//  TUIChat
//
//  Created by yiliangwang on 2025/1/20.
//  Copyright © 2023 Tencent. All rights reserved.
//

import Foundation
import TIMCommon

/// Global manager for AI placeholder typing messages
/// Manages AI placeholder messages across different chat sessions
public class TUIAIPlaceholderTypingMessageManager {
    
    // MARK: - Properties
    
    /// Shared instance
    public static let shared = TUIAIPlaceholderTypingMessageManager()
    
    /// Dictionary to store AI placeholder typing messages by conversation ID
    private var aiPlaceholderTypingMessages: [String: TUIMessageCellData] = [:]
    
    /// Concurrent queue for thread-safe access
    private let accessQueue = DispatchQueue(label: "com.tencent.tuichat.ai.placeholder.typing.queue", attributes: .concurrent)
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Set AI placeholder typing message for a specific conversation
    /// - Parameters:
    ///   - message: The AI placeholder typing message
    ///   - conversationID: The conversation identifier
    public func setAIPlaceholderTypingMessage(_ message: TUIMessageCellData?, forConversation conversationID: String) {
        guard !conversationID.isEmpty else {
            return
        }
        
        accessQueue.async(flags: .barrier) {
            if let message = message {
                self.aiPlaceholderTypingMessages[conversationID] = message
            } else {
                self.aiPlaceholderTypingMessages.removeValue(forKey: conversationID)
            }
        }
    }
    
    /// Get AI placeholder typing message for a specific conversation
    /// - Parameter conversationID: The conversation identifier
    /// - Returns: The AI placeholder typing message if exists, nil otherwise
    public func getAIPlaceholderTypingMessage(forConversation conversationID: String) -> TUIMessageCellData? {
        guard !conversationID.isEmpty else {
            return nil
        }
        
        return accessQueue.sync {
            return aiPlaceholderTypingMessages[conversationID]
        }
    }
    
    /// Remove AI placeholder typing message for a specific conversation
    /// - Parameter conversationID: The conversation identifier
    public func removeAIPlaceholderTypingMessage(forConversation conversationID: String) {
        guard !conversationID.isEmpty else {
            return
        }
        
        accessQueue.async(flags: .barrier) {
            self.aiPlaceholderTypingMessages.removeValue(forKey: conversationID)
        }
    }
    
    /// Check if there's an AI placeholder typing message for a specific conversation
    /// - Parameter conversationID: The conversation identifier
    /// - Returns: true if there's an AI placeholder typing message, false otherwise
    public func hasAIPlaceholderTypingMessage(forConversation conversationID: String) -> Bool {
        guard !conversationID.isEmpty else {
            return false
        }
        
        return accessQueue.sync {
            return aiPlaceholderTypingMessages[conversationID] != nil
        }
    }
    
    /// Clear all AI placeholder typing messages
    public func clearAllAIPlaceholderTypingMessages() {
        accessQueue.async(flags: .barrier) {
            self.aiPlaceholderTypingMessages.removeAll()
        }
    }
}
