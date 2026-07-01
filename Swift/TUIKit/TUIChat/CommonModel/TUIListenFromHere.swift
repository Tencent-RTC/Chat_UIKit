import Foundation
import TIMCommon

/// A single unit of the "listen from here" playback queue.
public enum TUIListenItemKind {
    /// Pure text-to-speech. The string already contains the sender prefix.
    case tts(String)
    /// A voice message: read `prefix` with TTS, then play the original audio.
    case voice(prefix: String, data: TUIVoiceMessageCellData)
}

public struct TUIListenItem {
    public let kind: TUIListenItemKind
    /// Text shown in the expanded playback bar.
    public let displayText: String
}

/// Builds the "listen from here" playback plan from a message list.
///
/// Rules (see `message-listen-from-here` spec):
/// - From the tapped message downward (toward the newest) in list order.
/// - Sender prefix: self -> "我说：", others -> "{昵称}说：".
/// - Consecutive messages from the same sender omit the prefix.
/// - Text reads its content (emoji filtered); image/video/file/merge read a
///   type description; voice reads the prefix then plays the raw audio.
/// - Reply / reference messages read their reply body text (emoji filtered).
/// - System / unsupported types and pure-emoji text are skipped.
public enum TUIListenPlanBuilder {
    public static func buildPlan(from cellDatas: [TUIMessageCellData], startIndex: Int) -> [TUIListenItem] {
        guard startIndex >= 0, startIndex < cellDatas.count else { return [] }

        var items: [TUIListenItem] = []
        var previousSenderID: String?
        for index in startIndex ..< cellDatas.count {
            let data = cellDatas[index]
            guard let item = makeItem(for: data, previousSenderID: previousSenderID) else { continue }
            items.append(item)
            previousSenderID = data.identifier
        }
        return items
    }

    // MARK: - Item Construction

    private static func makeItem(for data: TUIMessageCellData, previousSenderID: String?) -> TUIListenItem? {
        if data is TUISystemMessageCellData {
            return nil
        }

        let omitPrefix = (data.identifier != nil && data.identifier == previousSenderID)
        let prefix = omitPrefix ? "" : prefixText(for: data)

        if let replyData = data as? TUIReplyMessageCellData {
            let filtered = stripEmoji(replyData.content)
            if filtered.isEmpty { return nil }
            let speech = prefix + filtered
            return TUIListenItem(kind: .tts(speech), displayText: speech)
        } else if let textData = data as? TUITextMessageCellData {
            let filtered = stripEmoji(textData.content)
            if filtered.isEmpty { return nil }
            let speech = prefix + filtered
            return TUIListenItem(kind: .tts(speech), displayText: speech)
        } else if let voiceData = data as? TUIVoiceMessageCellData {
            let display = prefix.isEmpty ? voicePlaceholder : prefix + voicePlaceholder
            return TUIListenItem(kind: .voice(prefix: prefix, data: voiceData), displayText: display)
        } else if let mergeData = data as? TUIMergeMessageCellData {
            let body = String(format: sentMergeFormat, mergeData.title ?? "")
            let speech = prefix + body
            return TUIListenItem(kind: .tts(speech), displayText: speech)
        } else if data is TUIImageMessageCellData {
            return ttsItem(prefix: prefix, body: sentImageText)
        } else if data is TUIVideoMessageCellData {
            return ttsItem(prefix: prefix, body: sentVideoText)
        } else if data is TUIFileMessageCellData {
            return ttsItem(prefix: prefix, body: sentFileText)
        }

        return nil
    }

    private static func ttsItem(prefix: String, body: String) -> TUIListenItem {
        let speech = prefix + body
        return TUIListenItem(kind: .tts(speech), displayText: speech)
    }

    private static func prefixText(for data: TUIMessageCellData) -> String {
        if data.direction == .outgoing {
            return TUISwift.timCommonLocalizableString("TUIKitListenSelfPrefix")
        }
        return String(format: TUISwift.timCommonLocalizableString("TUIKitListenOtherPrefixFormat"), data.senderName)
    }

    // MARK: - Emoji Filtering

    /// Removes IM custom faces (`[xxx]`) and unicode emoji from `text`.
    public static func stripEmoji(_ text: String) -> String {
        let withoutFaces = text.replacingOccurrences(
            of: "\\[[^\\[\\]]{1,30}\\]",
            with: "",
            options: .regularExpression
        )
        let withoutEmoji = withoutFaces.filter { character in
            !character.unicodeScalars.contains { scalar in
                scalar.properties.isEmojiPresentation ||
                    (scalar.properties.isEmoji && scalar.value > 0x2122) ||
                    scalar.value == 0x200D ||
                    scalar.value == 0xFE0F
            }
        }
        return withoutEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Localized Text

    private static var voicePlaceholder: String {
        TUISwift.timCommonLocalizableString("TUIKitListenVoicePlaceholder")
    }

    private static var sentImageText: String {
        TUISwift.timCommonLocalizableString("TUIKitListenSentImage")
    }

    private static var sentVideoText: String {
        TUISwift.timCommonLocalizableString("TUIKitListenSentVideo")
    }

    private static var sentFileText: String {
        TUISwift.timCommonLocalizableString("TUIKitListenSentFile")
    }

    private static var sentMergeFormat: String {
        TUISwift.timCommonLocalizableString("TUIKitListenSentMergeFormat")
    }
}
