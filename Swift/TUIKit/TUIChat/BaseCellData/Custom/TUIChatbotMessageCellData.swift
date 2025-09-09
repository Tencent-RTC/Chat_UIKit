//
//  TUIChatbotMessageCellData.swift
//  TUIChat
//
//  Created by yiliangwang on 2025/1/20.
//  Copyright © 2023 Tencent. All rights reserved.
//

import Foundation
import ImSDK_Plus
import TIMCommon
import TUICore

class TUIChatbotMessageCellData: TUITextMessageCellData {
    
    // MARK: - Properties
    
    /// Timer for streaming text animation
    var timer: DispatchSourceTimer?
    
    /// Font used for content display
    var contentFont: UIFont?
    
    /// Attributed string for content
    var contentString: NSAttributedString?
    
    /// Length of currently displayed content (for streaming effect)
    var displayedContentLength: Int = 0
    
    /// Whether the AI response is finished
    var isFinished: Bool = false
    
    /// Source type of the message
    var src: Int = 0
    
    // MARK: - Class Methods
    
    /// Create cell data from V2TIMMessage
    override class func getCellData( message: V2TIMMessage) -> TUIMessageCellData {
        guard let customElem = message.customElem,
              let data = customElem.data,
              let param = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            return TUIChatbotMessageCellData(direction: .incoming)
        }
        
        let cellData = TUIChatbotMessageCellData(direction: message.isSelf ? .outgoing : .incoming)
        cellData.innerMessage = message
        cellData.content = getDisplayString(message: message)
        cellData.displayedContentLength = 0
        cellData.reuseId = TTextMessageCell_ReuseId
        cellData.status = .initStatus
        cellData.isFinished = getFinishedStatus(message)
        cellData.src = Int(param["src"] as? Double ?? 0)
        
        if (cellData.isFinished) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                DispatchQueue.main.async {
                    // Notify plugin view change
                    let param: [String: Any] = [
                        TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data: cellData,
                        "isFinished": cellData.isFinished ? "1" : "0",
                        "TUICore_TUIPluginNotify_DidChangePluginViewSubKey_isAllowScroll2Bottom": "0"
                    ]
                    TUICore.notifyEvent(TUICore_TUIPluginNotify,
                                       subKey: TUICore_TUIPluginNotify_DidChangePluginViewSubKey,
                                       object: nil,
                                       param: param)
                }
            }
        }
        return cellData
    }
    
    /// Get display string from message
    override class func getDisplayString(message: V2TIMMessage) -> String {
        guard let customElem = message.customElem,
              let data = customElem.data,
              let param = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            return ""
        }
        
        // Handle error case
        if Int(param["src"] as? Double ?? 0) == 23 {
            let errorInfo = param["errorInfo"] as? String ?? ""
            return errorInfo.isEmpty ? "" : errorInfo
        }
        
        // Combine chunks for display
        var displayString = ""
        if let chunks = param["chunks"] as? [String] {
            for chunk in chunks {
                displayString += chunk
            }
        }
        
        return displayString
    }
    
    /// Get finished status from message
    public class func getFinishedStatus(_ message: V2TIMMessage) -> Bool {
        guard let customElem = message.customElem,
              let data = customElem.data,
              let param = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            return false
        }
        
        // Error case is always finished
        if Int(param["src"] as? Double ?? 0) == 23 {
            return true
        }
        
        // Check isFinished flag
        let isFinishedValue = param["isFinished"] as? Double ?? 0
        return abs(isFinishedValue - 1.0) < 0.00001
    }
    
    // MARK: - Instance Methods
    
    /// Custom reload cell with new message
    override  func customReloadCell(withNewMsg newMessage: V2TIMMessage) -> Bool {
        guard let customElem = newMessage.customElem,
              let data = customElem.data,
              let _ = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            return true
        }
        
        innerMessage = newMessage
        content = type(of: self).getDisplayString(message: newMessage)
        isFinished = type(of: self).getFinishedStatus(newMessage)
        
        // Notify plugin view change
        let param: [String: Any] = [
            TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data: self,
            "isFinished": isFinished ? "1" : "0",
            "TUICore_TUIPluginNotify_DidChangePluginViewSubKey_isAllowScroll2Bottom": "0"
        ]
        TUICore.notifyEvent(TUICore_TUIPluginNotify,
                           subKey: TUICore_TUIPluginNotify_DidChangePluginViewSubKey,
                           object: nil,
                           param: param)
        
        return true
    }
    
    /// Get content attributed string with streaming effect
    override func getContentAttributedString(textFont: UIFont) -> NSAttributedString {
        contentFont = textFont
        contentString = super.getContentAttributedString(textFont: textFont)
        
        // Apply streaming effect for online push messages
        if source == .onlinePush {
            if let contentString = contentString, displayedContentLength < contentString.length {
                let range = NSRange(location: 0, length: min(displayedContentLength + 1, contentString.length))
                return contentString.attributedSubstring(from: range)
            }
        }
        
        return contentString ?? NSAttributedString()
    }
    
    /// Get content attributed string size
    override func getContentAttributedStringSize(attributeString: NSAttributedString, maxTextSize: CGSize) -> CGSize {
        let size = super.getContentAttributedStringSize(attributeString: attributeString, maxTextSize: maxTextSize)
        
        if let contentFont = contentFont, size.height > ceil(contentFont.lineHeight) {
            return CGSize(width: TUISwift.tTextMessageCell_Text_Width_Max(), height: size.height)
        } else {
            return size
        }
    }
}
