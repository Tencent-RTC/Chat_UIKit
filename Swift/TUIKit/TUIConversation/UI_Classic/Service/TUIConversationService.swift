import Foundation
import TIMCommon
import TUICore

public class TUIConversationService: NSObject {
    @objc public class func swiftLoad() {
        TUISwift.tuiRegisterThemeResourcePath(TUISwift.tuiBundlePath("TUIConversationTheme", key: "TUIConversationService"), themeModule: TUIThemeModule.conversation)
    }

    static let shared: TUIConversationService = {
        let instance = TUIConversationService()
        return instance
    }()
}
