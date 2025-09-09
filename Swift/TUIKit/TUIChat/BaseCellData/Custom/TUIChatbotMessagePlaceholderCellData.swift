//
//  TUIChatbotMessagePlaceholderCellData.swift
//  TUIChat
//
//  Created by yiliangwang on 2025/1/20.
//  Copyright © 2023 Tencent. All rights reserved.
//

import Foundation
import ImSDK_Plus
import TIMCommon

class TUIChatbotMessagePlaceholderCellData: TUITextMessageCellData {
    
    // MARK: - Properties
    
    /// Whether the AI is currently typing/generating response
    /// When true, shows loading animation
    /// When false, hides the cell or shows completed state
    var isAITyping: Bool = false
    
    // MARK: - Class Methods
    
    /// Create placeholder cell data for AI typing state
    class func createAIPlaceholderCellData() -> TUIChatbotMessagePlaceholderCellData {
        let cellData = TUIChatbotMessagePlaceholderCellData(direction: .incoming)
        cellData.content = "" // Empty content for placeholder
        cellData.isAITyping = true // Start in typing state
        cellData.reuseId = "TUIChatbotMessagePlaceholderCellData"
        return cellData
    }
    
    /// This placeholder cell data is not created from V2TIMMessage
    /// It's created programmatically using createAIPlaceholderCellData
    override class func getCellData(message: V2TIMMessage) -> TUIMessageCellData {
        // Return a dummy instance since this should not be called
        return TUIChatbotMessagePlaceholderCellData(direction: .incoming)
    }
    
    /// No display string for placeholder
    override class func getDisplayString(message: V2TIMMessage) -> String {
        return ""
    }
    
    // MARK: - Instance Methods
    
    /// Small size for placeholder - just enough for loading animation
    func contentSize() -> CGSize {
        return CGSize(width: 40, height: 20)
    }
}
