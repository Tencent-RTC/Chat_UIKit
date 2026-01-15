import AVFoundation
import Foundation
import TIMCommon

public class TUIVoiceMessageCellData: TUIBubbleMessageCellData {
    public var path: String?
    public var uuid: String?
    public var duration: Int = 0
    public var length: Int = 0
    public var isDownloading: Bool = false
    @objc public dynamic var isPlaying: Bool = false
    public var voiceHeight: CGFloat = 21.0
    @objc public dynamic var currentTime: TimeInterval = 0.0
    public var voiceAnimationImages: [UIImage] = []
    public var voiceImage: UIImage?
    public var voiceTop: CGFloat = 12.0

    private var wavPath: String?

    public static var incommingVoiceTop: CGFloat = 12.0
    public static var outgoingVoiceTop: CGFloat = 12.0

    public var audioPlayerDidFinishPlayingBlock: (() -> Void)?

    public override class func getCellData(message: V2TIMMessage) -> TUIMessageCellData {
        guard let elem = message.soundElem else {
            return TUIVoiceMessageCellData(direction: .incoming)
        }

        let direction: TMsgDirection = message.isSelf ? .outgoing : .incoming
        let soundData = TUIVoiceMessageCellData(direction: direction)
        soundData.duration = Int(elem.duration)
        soundData.length = Int(elem.dataSize)
        soundData.uuid = elem.uuid
        soundData.reuseId = "TVoiceMessaageCell"
        soundData.path = elem.path
        return soundData
    }

    public override class func getDisplayString(message: V2TIMMessage) -> String {
        return TUISwift.timCommonLocalizableString("TUIKitMessageTypeVoice")
    }

    public override func getReplyQuoteViewDataClass() -> AnyClass? {
        return NSClassFromString("TUIChat.TUIVoiceReplyQuoteViewData")
    }

    public override func getReplyQuoteViewClass() -> AnyClass? {
        return NSClassFromString("TUIChat.TUIVoiceReplyQuoteView")
    }

    public override init(direction: TMsgDirection) {
        super.init(direction: direction)
        
        // Listen for stop audio notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onStopAllAudioPlayback),
            name: .TUIStopAllAudioPlayback,
            object: nil
        )
        
        // Listen for progress updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onProgressUpdate(_:)),
            name: Notification.Name("TUIAudioPlaybackProgressChanged"),
            object: nil
        )

        if direction == .incoming {
            self.cellLayout = TUIMessageCellLayout.incomingVoiceMessageLayout
            self.voiceImage = TUISwift.tuiChatDynamicImage("chat_voice_message_receiver_voice_normal_img", defaultImage: TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("message_voice_receiver_normal")) ?? UIImage())
            self.voiceImage = voiceImage?.rtlImageFlippedForRightToLeftLayoutDirection()
            self.voiceAnimationImages = [
                Self.formatImageByName("message_voice_receiver_playing_1"),
                Self.formatImageByName("message_voice_receiver_playing_2"),
                Self.formatImageByName("message_voice_receiver_playing_3")
            ]
            self.voiceTop = Self.incommingVoiceTop
        } else {
            self.cellLayout = TUIMessageCellLayout.outgoingVoiceMessageLayout
            self.voiceImage = TUISwift.tuiChatDynamicImage("chat_voice_message_sender_voice_normal_img", defaultImage: TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("message_voice_sender_normal")) ?? UIImage())
            self.voiceImage = voiceImage?.rtlImageFlippedForRightToLeftLayoutDirection()
            self.voiceAnimationImages = [
                Self.formatImageByName("message_voice_sender_playing_1"),
                Self.formatImageByName("message_voice_sender_playing_2"),
                Self.formatImageByName("message_voice_sender_playing_3")
            ]
            self.voiceTop = Self.outgoingVoiceTop
        }
    }

    static func formatImageByName(_ imgName: String) -> UIImage {
        let path = TUISwift.tuiChatImagePath(imgName)
        let img = TUIImageCache.sharedInstance().getResourceFromCache(path) ?? UIImage()
        return img.rtlImageFlippedForRightToLeftLayoutDirection()
    }

    func getVoicePath(isExist: inout Bool) -> String {
        var voicePath = ""
        var isDir = ObjCBool(false)
        isExist = false

        if let path = path, let lastComp = URL(string: path)?.lastPathComponent, direction == .outgoing {
            voicePath = "\(TUISwift.tuiKit_Voice_Path())\(lastComp)"
            if FileManager.default.fileExists(atPath: voicePath, isDirectory: &isDir), !isDir.boolValue {
                isExist = true
            }
        }

        if !isExist, let uuid = uuid, !uuid.isEmpty {
            voicePath = "\(TUISwift.tuiKit_Voice_Path())\(uuid).amr"
            if FileManager.default.fileExists(atPath: voicePath, isDirectory: &isDir), !isDir.boolValue {
                isExist = true
            }
        }

        return voicePath
    }

    func getIMSoundElem() -> V2TIMSoundElem? {
        let message: V2TIMMessage? = innerMessage
        guard let imMsg = message, imMsg.elemType == .ELEM_TYPE_SOUND else { return nil }
        return imMsg.soundElem
    }

    func playVoiceMessage() {
        if isPlaying {
            stopVoiceMessage()
            return
        }
        isPlaying = true

        if (innerMessage?.localCustomInt ?? 0) == 0 {
            innerMessage?.localCustomInt = 1
        }

        guard let imSound = getIMSoundElem() else {
            stopVoiceMessage()
            return
        }
        var isExist = false
        if uuid == nil || uuid!.isEmpty {
            uuid = imSound.uuid
        }
        let path = getVoicePath(isExist: &isExist)
        if isExist {
            playInternal(path: path)
        } else {
            if isDownloading {
                return
            }
            isDownloading = true
            imSound.downloadSound(
                path: path,
                progress: { _, _ in },
                succ: { [weak self] in
                    self?.isDownloading = false
                    self?.playInternal(path: path)
                },
                fail: { [weak self] _, _ in
                    self?.isDownloading = false
                    self?.stopVoiceMessage()
                }
            )
        }
    }

    private func playInternal(path: String) {
        guard isPlaying else { return }
        guard let msgID = innerMessage?.msgID else {
            stopVoiceMessage()
            return
        }
        
        // Use centralized audio manager
        TUIAudioPlaybackManager.shared.playAudio(
            fromPath: path,
            msgID: msgID,
            stateCallback: { [weak self] playing in
                DispatchQueue.main.async {
                    if !playing {
                        self?.isPlaying = false
                    }
                }
            },
            finishCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.onPlaybackFinished()
                }
            }
        )
    }
    
    private func onPlaybackFinished() {
        isPlaying = false
        if let wavPath = wavPath {
            try? FileManager.default.removeItem(atPath: wavPath)
        }
        audioPlayerDidFinishPlayingBlock?()
    }
    
    @objc private func onProgressUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let msgID = userInfo["msgID"] as? String,
              msgID == innerMessage?.msgID,
              let time = userInfo["currentTime"] as? TimeInterval else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.currentTime = time
        }
    }

    static func getAudioplaybackStyle() -> TUIAudioPlaybackStyle {
        return TUIAudioPlaybackManager.getAudioPlaybackStyle()
    }

    static func changeAudioPlaybackStyle() {
        TUIAudioPlaybackManager.toggleAudioPlaybackStyle()
    }
    
    /// Handle stop all audio notification
    @objc private func onStopAllAudioPlayback(_ notification: Notification) {
        // Don't stop if we triggered the notification via TUIAudioPlaybackManager
        if notification.object is TUIAudioPlaybackManager {
            // Check if this is our message
            guard let msgID = innerMessage?.msgID,
                  TUIAudioPlaybackManager.shared.currentPlayingMsgID != msgID else {
                return
            }
        }
        if isPlaying {
            isPlaying = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func stopVoiceMessage() {
        if let msgID = innerMessage?.msgID {
            TUIAudioPlaybackManager.shared.stopAudio(forMsgID: msgID)
        }
        isPlaying = false
    }
}
