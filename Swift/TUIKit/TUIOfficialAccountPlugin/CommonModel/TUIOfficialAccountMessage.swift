import Foundation
import TIMCommon

/// Image info model (matches Android ImageInfo)
public class TUIOfficialAccountImageInfo: NSObject {
    /// Image URL
    public var url: String = ""
    
    /// Image width
    public var width: Int = 0
    
    /// Image height
    public var height: Int = 0
    
    public override init() {
        super.init()
    }
}

/// Official Account message model (matches Android OfficialAccountMessage)
public class TUIOfficialAccountMessage: NSObject, NSCopying {
    /// Business ID (must be "official_account_tweet")
    public var businessID: String = OfficialAccountMessageBusinessID
    
    /// Message title
    public var title: String = ""
    
    /// Text content (matches Android "content" field)
    public var contentText: String = ""
    
    /// Link URL
    public var link: String = ""
    
    /// Image info
    public var imageInfo: TUIOfficialAccountImageInfo?
    
    /// Version
    public var version: Int = 1
    
    /// Message ID (from V2TIMMessage)
    public var messageID: String = ""
    
    /// Official Account ID (from V2TIMMessage sender)
    public var accountID: String = ""
    
    /// Message timestamp (in milliseconds)
    public var timestampInMS: TimeInterval = 0
    
    /// Original V2TIMMessage
    public var message: V2TIMMessage?
    
    /// Whether the message is read
    public var isRead: Bool = false
    
    /// Message type (derived from content)
    public var messageType: TUIOfficialAccountMessageType {
        if imageInfo != nil && !imageInfo!.url.isEmpty {
            return .image
        } else if !link.isEmpty {
            return .link
        } else {
            return .text
        }
    }
    
    public override init() {
        super.init()
    }
    
    /// Initialize from dictionary (matches Android JSON format)
    /// - Parameter dict: Dictionary containing message data
    public convenience init?(dict: [String: Any]?) {
        guard let dict = dict else { return nil }
        self.init()
        
        self.businessID = dict["businessID"] as? String ?? OfficialAccountMessageBusinessID
        self.title = dict["title"] as? String ?? ""
        self.contentText = dict["content"] as? String ?? ""
        self.link = dict["link"] as? String ?? ""
        self.version = dict["version"] as? Int ?? 1
        
        // Parse imageInfo (matches Android format)
        if let imageInfoDict = dict["imageInfo"] as? [String: Any] {
            let info = TUIOfficialAccountImageInfo()
            info.url = imageInfoDict["url"] as? String ?? ""
            info.width = imageInfoDict["width"] as? Int ?? 0
            info.height = imageInfoDict["height"] as? Int ?? 0
            self.imageInfo = info
        }
    }
    
    /// Initialize from V2TIMMessage
    /// - Parameter message: V2TIMMessage containing official account message
    public convenience init?(message: V2TIMMessage?) {
        guard let dict = TUIOfficialAccountMessageParser.parseMessageData(message) else {
            return nil
        }
        
        self.init(dict: dict)
        self.message = message
        self.messageID = message?.msgID ?? ""
        self.accountID = message?.sender ?? ""
        self.timestampInMS = TimeInterval((message?.timestamp?.timeIntervalSince1970 ?? 0) * 1000)
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = TUIOfficialAccountMessage()
        copy.businessID = businessID
        copy.title = title
        copy.contentText = contentText
        copy.link = link
        copy.imageInfo = imageInfo
        copy.version = version
        copy.messageID = messageID
        copy.accountID = accountID
        copy.timestampInMS = timestampInMS
        copy.message = message
        copy.isRead = isRead
        return copy
    }
    
    /// Convert to dictionary (matches Android JSON format)
    /// - Returns: Dictionary representation of the message
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "businessID": businessID,
            "title": title,
            "content": contentText,
            "link": link,
            "version": version
        ]
        
        if let img = imageInfo {
            dict["imageInfo"] = [
                "url": img.url,
                "width": img.width,
                "height": img.height
            ]
        }
        
        return dict
    }
}

// MARK: - Display Helpers
extension TUIOfficialAccountMessage {
    /// Get formatted time string
    public var formattedTime: String {
        let date = Date(timeIntervalSince1970: timestampInMS / 1000)
        let formatter = DateFormatter()
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return (TUISwift.timCommonLocalizableString("TUIKitYesterday") ?? "Yesterday") + " " + {
                formatter.dateFormat = "HH:mm"
                return formatter.string(from: date)
            }()
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    /// Get preview text for message list (matches Android behavior)
    public var previewText: String {
        // If has text content, return it
        if !contentText.isEmpty {
            return contentText
        }
        
        // If has image, return image placeholder
        if imageInfo != nil && !imageInfo!.url.isEmpty {
            return TUISwift.timCommonLocalizableString("TUIKitMessageTypeImage") ?? "[Image]"
        }
        
        return ""
    }
}

