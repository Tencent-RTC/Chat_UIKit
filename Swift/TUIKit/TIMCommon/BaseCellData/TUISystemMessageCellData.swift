import UIKit

public enum TUISystemMessageType: Int {
    case unknown = 0
    case date = 1
}

open class TUISystemMessageCellData: TUIMessageCellData {
    public var content: String?
    public var supportReEdit: Bool = false
    private var _attributedString: NSMutableAttributedString?

    public var replacedUserIDList: [String]?
    public var contentFont: UIFont?
    public var contentColor: UIColor?
    public var type: TUISystemMessageType = .unknown
    
    public static var textFont: UIFont?
    public static var textColor: UIColor?
    public static var textBackgroundColor: UIColor?
    
    open var attributedString: NSMutableAttributedString? {
        get {
            var forceRefresh = false
            for (key, obj) in additionalUserInfoResult {
                let str = "{\(key)}"
                var showName = obj.userID
                if let nameCard = obj.nameCard, !nameCard.isEmpty {
                    showName = nameCard
                } else if let friendRemark = obj.friendRemark, !friendRemark.isEmpty {
                    showName = friendRemark
                } else if let nickName = obj.nickName, !nickName.isEmpty {
                    showName = nickName
                }
                if let c = content, c.contains(str) {
                    content = content?.replacingOccurrences(of: str, with: showName)
                    forceRefresh = true
                }
            }
                
            if let content = content {
                if forceRefresh || (_attributedString == nil && content.count > 0) {
                    let attributeString = NSMutableAttributedString(string: content)
                    let attributeDict: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.systemGray]
                    attributeString.addAttributes(attributeDict, range: NSRange(location: 0, length: attributeString.length))
                    if supportReEdit {
                        let reEditStr = TUISwift.timCommonLocalizableString("TUIKitMessageTipsReEditMessage")
                        attributeString.append(NSAttributedString(string: " \(reEditStr)"))
                        
                        let reEditAttributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: UIColor.systemBlue,
                        ]
                        let reEditStartLocation = content.count + 1
                        let reEditRange = NSRange(location: reEditStartLocation, length: reEditStr.count)
                        
                        if reEditStartLocation + reEditStr.count <= attributeString.length {
                            attributeString.addAttributes(reEditAttributes, range: reEditRange)
                        }
                    }
                    _attributedString = attributeString
                }
            }
                
            return _attributedString
        }
        set {
            _attributedString = newValue
        }
    }
    
    override public init(direction: TMsgDirection) {
        super.init(direction: direction)
        self.showAvatar = false
        self.contentFont = UIFont.systemFont(ofSize: 13)
        self.contentColor = UIColor.systemGray
        self.cellLayout = TUIMessageCellLayout.systemMessageLayout
    }
    
    public required init() {
        fatalError("init() has not been implemented")
    }
    
    override public func requestForAdditionalUserInfo() -> [String] {
        var result = super.requestForAdditionalUserInfo()
        if let userList = replacedUserIDList {
            result.append(contentsOf: userList)
        }
        
        return result
    }
}
