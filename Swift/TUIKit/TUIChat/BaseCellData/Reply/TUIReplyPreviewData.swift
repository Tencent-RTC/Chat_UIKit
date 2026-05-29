import Foundation
import ImSDK_Plus
import TIMCommon

class TUIReplyPreviewData {
    var msgID: String? = ""
    var msgAbstract: String? = ""
    var sender: String? = ""
    var faceURL: String? = ""
    var type: V2TIMElemType = .ELEM_TYPE_NONE
    var originMessage: V2TIMMessage?

    static func displayAbstract(type: V2TIMElemType, abstract: String, withFileName: Bool, isRisk: Bool) -> String {
        var text = abstract
        switch type {
        case .ELEM_TYPE_IMAGE:
            text = isRisk ? TUISwift.timCommonLocalizableString("TUIkitMessageTypeRiskImage") : TUISwift.timCommonLocalizableString("TUIkitMessageTypeImage")
        case .ELEM_TYPE_VIDEO:
            text = isRisk ? TUISwift.timCommonLocalizableString("TUIkitMessageTypeRiskVideo") : TUISwift.timCommonLocalizableString("TUIkitMessageTypeVideo")
        case .ELEM_TYPE_SOUND:
            text = isRisk ? TUISwift.timCommonLocalizableString("TUIkitMessageTypeRiskVoice") : TUISwift.timCommonLocalizableString("TUIKitMessageTypeVoice")
        case .ELEM_TYPE_FACE:
            text = TUISwift.timCommonLocalizableString("TUIKitMessageTypeAnimateEmoji")
        case .ELEM_TYPE_FILE:
            if withFileName {
                text = "\(TUISwift.timCommonLocalizableString("TUIkitMessageTypeFile"))\(abstract)"
            } else {
                text = TUISwift.timCommonLocalizableString("TUIkitMessageTypeFile")
            }
        default:
            break
        }
        return text
    }
}

class TUIReferencePreviewData: TUIReplyPreviewData {}
