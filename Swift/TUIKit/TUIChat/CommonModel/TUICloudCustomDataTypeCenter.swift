import Foundation
import ImSDK_Plus
import TIMCommon

typealias TUICustomType = String

let messageFeature: TUICustomType = "messageFeature"

public struct TUICloudCustomDataType: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let none = TUICloudCustomDataType(rawValue: 1 << 0)
    public static let messageReply = TUICloudCustomDataType(rawValue: 1 << 1)
    public static let messageReplies = TUICloudCustomDataType(rawValue: 1 << 3)
    public static let messageReference = TUICloudCustomDataType(rawValue: 1 << 4)
}

extension V2TIMMessage {
    func doThingsInContainsCloudCustom(of type: TUICloudCustomDataType, callback: @escaping (Bool, Any?) -> Void) {
        callback(false, nil)
    }

    func isContainsCloudCustom(of type: TUICloudCustomDataType) -> Bool {
        return false
    }

    func parseCloudCustomData(_ customType: TUICustomType) -> Any? {
        guard let cloudCustomData = self.cloudCustomData, !customType.isEmpty else {
            return nil
        }

        do {
            if let dict = try JSONSerialization.jsonObject(with: cloudCustomData, options: []) as? [String: Any],
               dict.keys.contains(customType)
            {
                return dict[customType]
            }
        } catch {
            return nil
        }

        return nil
    }

    func setCloudCustomData(_ jsonData: Any, forType customType: TUICustomType) {
        guard !customType.isEmpty else {
            return
        }

        var dict: [String: Any] = [:]

        if let cloudCustomData = self.cloudCustomData {
            do {
                if let existingDict = try JSONSerialization.jsonObject(with: cloudCustomData, options: []) as? [String: Any] {
                    dict = existingDict
                }
            } catch {
                dict = [:]
            }
        }

        dict[customType] = jsonData

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            self.cloudCustomData = data
        }
    }

    func modifyIfNeeded(callback: @escaping V2TIMMessageModifyCompletion) {
       V2TIMManager.sharedInstance().modifyMessage(msg: self, completion: callback)
    }
}

class TUICloudCustomDataTypeCenter {
    static func convertType2String(_ type: TUICloudCustomDataType) -> String? {
        return nil
    }
}
