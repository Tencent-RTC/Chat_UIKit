import AVFoundation
import Foundation
import TIMCommon
import TUICore

@objc public protocol TUIAudioRecorderDelegate: NSObjectProtocol {
    @objc optional func didCheckPermission(_ recorder: TUIAudioRecorder, _ isGranted: Bool, _ isFirstTime: Bool)
    @objc optional func didPowerChanged(_ recorder: TUIAudioRecorder, _ power: Float)
    @objc optional func didRecordTimeChanged(_ recorder: TUIAudioRecorder, _ time: TimeInterval)
}

// public typealias TUICallServiceResultCallback = (Int32, String, [AnyHashable: Any]?) -> Void

public extension Notification.Name {
    /// Posted right before a voice recording actually starts, so that any
    /// ongoing playback (e.g. "listen from here") can stop itself.
    static let TUIAudioRecordingDidStart = Notification.Name("TUIAudioRecordingDidStart")
}

public class TUIAudioRecorder: NSObject, AVAudioRecorderDelegate, TUINotificationProtocol {
    public weak var delegate: TUIAudioRecorderDelegate?
    public private(set) var recordedFilePath: String = ""
    
    private var recorder: AVAudioRecorder?
    private var recordTimer: Timer?
    private var isUsingCallKitRecorder = false
    private var currentRecordTime: TimeInterval = 0
    
    override public init() {
        super.init()
        configNotify()
    }
    
    deinit {
        TUICore.unRegisterEvent(byObject: self)
    }
    
    private func configNotify() {
        TUICore.registerEvent("TUICore_RecordAudioMessageNotify", subKey: "TUICore_RecordAudioMessageNotify_RecordAudioVoiceVolumeSubKey", object: self)
    }
    
    // MARK: - Public Methods

    public func record() {
        checkMicPermission { [weak self] isGranted, isFirstCheck in
            guard let self = self else { return }
            if TUILogin.getCurrentBusinessScene() != .None {
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitMessageTypeOtherUseMic"), duration: 3)
                return
            }
            if isFirstCheck {
                self.delegate?.didCheckPermission?(self, isGranted, true)
                return
            }
            self.delegate?.didCheckPermission?(self, isGranted, false)
            if isGranted {
                NotificationCenter.default.post(name: .TUIAudioRecordingDidStart, object: self)
                self.createRecordedFilePath()
                if !self.startCallKitRecording() {
                    self.startSystemRecording()
                }
            }
        }
    }
    
    public func stop() {
        stopRecordTimer()
        if isUsingCallKitRecorder {
            stopCallKitRecording()
        } else {
            stopSystemRecording()
        }
    }
    
    public func cancel() {
        stopRecordTimer()
        if isUsingCallKitRecorder {
            stopCallKitRecording()
        } else {
            cancelSystemRecording()
        }
    }

    private func createRecordedFilePath() {
        recordedFilePath = TUISwift.tuiKit_Voice_Path().appending(TUITool.genVoiceName(nil, withExtension: "m4a"))
    }
    
    private func stopRecordTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
    }
    
    // MARK: - Timer

    private func triggerRecordTimer() {
        currentRecordTime = 0
        recordTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(onRecordTimerTriggered), userInfo: nil, repeats: true)
    }
    
    @objc private func onRecordTimerTriggered() {
        recorder?.updateMeters()
        
        if isUsingCallKitRecorder {
            currentRecordTime += 0.2
            delegate?.didRecordTimeChanged?(self, currentRecordTime)
        } else {
            let power = recorder?.averagePower(forChannel: 0) ?? 0
            let currentTime = recorder?.currentTime ?? 0
            delegate?.didPowerChanged?(self, power)
            delegate?.didRecordTimeChanged?(self, currentTime)
        }
    }
    
    private func checkMicPermission(completion: @escaping (Bool, Bool) -> Void) {
        let permission = AVAudioSession.sharedInstance().recordPermission
        
        if permission == .denied || permission == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted, true)
                }
            }
            return
        }
        
        let isGranted = permission == .granted
        completion(isGranted, false)
    }
    
    // MARK: - Record audio using system framework

    private func startSystemRecording() {
        isUsingCallKitRecorder = false
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord)
            try session.setActive(true)
        } catch {
            print("Failed to set audio session category or activate session: \(error)")
        }
        
        let recordSetting: [String: Any] = [
            AVSampleRateKey: 16000.0,
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVLinearPCMBitDepthKey: 16,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        createRecordedFilePath()
        
        let url = URL(fileURLWithPath: recordedFilePath)
        do {
            recorder = try AVAudioRecorder(url: url, settings: recordSetting)
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()
            recorder?.record()
            recorder?.updateMeters()
        } catch {
            print("Failed to initialize AVAudioRecorder: \(error)")
        }
        
        triggerRecordTimer()
        print("start system recording")
    }
    
    private func stopSystemRecording() {
        guard AVAudioSession.sharedInstance().recordPermission != .denied else {
            return
        }
        
        if recorder?.isRecording == true {
            recorder?.stop()
        }
        
        recorder = nil
        print("stop system recording")
    }
    
    private func cancelSystemRecording() {
        if recorder?.isRecording == true {
            recorder?.stop()
        }
        
        if let path = recorder?.url.path, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        
        recorder = nil
        print("cancel system recording")
    }
    
    // MARK: - Record audio using TUICallKit framework

    private func startCallKitRecording() -> Bool {
        guard TUICore.getService("TUIAudioMessageRecordService") != nil else {
            print("TUICallKit audio recording service does not exist")
            return false
        }
        
        guard let signature = TUIAIDenoiseSignatureManager.sharedInstance.signature, !signature.isEmpty else {
            print("denoise signature is empty")
            return false
        }
        
        var audioRecordParam: [String: Any] = [:]
        audioRecordParam["signature"] = signature
        audioRecordParam["sdkappid"] = TUILogin.getSdkAppID()
        audioRecordParam["path"] = recordedFilePath
        
        let startCallBack: TUICallServiceResultCallback = { [weak self] errorCode, _, param in
            guard let self = self else { return }
            if let method = param["method"] as? String, method == "TUICore_RecordAudioMessageNotify_StartRecordAudioMessageSubKey" {
                self.onTUICallKitRecordStarted(Int32(errorCode))
            }
        }
        
        TUICore.callService("TUIAudioMessageRecordService",
                            method: "TUICore_TUIAudioMessageRecordService_StartRecordAudioMessageMethod",
                            param: audioRecordParam,
                            resultCallback: startCallBack)
        
        isUsingCallKitRecorder = true
        print("start TUICallKit recording")
        return true
    }
    
    private func stopCallKitRecording() {
        let stopCallBack: TUICallServiceResultCallback = { [weak self] errorCode, _, param in
            guard let self = self else { return }
            if let method = param["method"] as? String, method == "TUICore_RecordAudioMessageNotify_StopRecordAudioMessageSubKey" {
                self.onTUICallKitRecordCompleted(Int32(errorCode))
            }
        }
        
        TUICore.callService("TUIAudioMessageRecordService",
                            method: "TUICore_TUIAudioMessageRecordService_StopRecordAudioMessageMethod",
                            param: nil,
                            resultCallback: stopCallBack)
        
        print("stop TUICallKit recording")
    }
    
    // MARK: - TUINotificationProtocol
    
    public func onNotifyEvent(_ key: String, subKey: String, object anObject: Any?, param: [AnyHashable: Any]?) {
        guard key == "TUICore_RecordAudioMessageNotify", let param = param else {
            print("TUICallKit notify param is invalid")
            return
        }
        
        if subKey == "TUICore_RecordAudioMessageNotify_RecordAudioVoiceVolumeSubKey" {
            if let volume = param["volume"] as? UInt {
                onTUICallKitVolumeChanged(volume)
            }
        }
    }
    
    private func onTUICallKitRecordStarted(_ errorCode: Int32) {
        switch errorCode {
        case TUICore_RecordAudioMessageNotifyError_None:
            triggerRecordTimer()
        case TUICore_RecordAudioMessageNotifyError_MicPermissionRefused:
            break
        case TUICore_RecordAudioMessageNotifyError_StatusInCall:
            TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitInputRecordRejectedInCall"))
        case TUICore_RecordAudioMessageNotifyError_StatusIsAudioRecording:
            TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitInputRecordRejectedIsRecording"))
        case TUICore_RecordAudioMessageNotifyError_RequestAudioFocusFailed,
             TUICore_RecordAudioMessageNotifyError_RecordInitFailed,
             TUICore_RecordAudioMessageNotifyError_PathFormatNotSupport,
             TUICore_RecordAudioMessageNotifyError_MicStartFail,
             TUICore_RecordAudioMessageNotifyError_MicNotAuthorized,
             TUICore_RecordAudioMessageNotifyError_MicSetParamFail,
             TUICore_RecordAudioMessageNotifyError_MicOccupy:
            stopCallKitRecording()
            print("start TUICallKit recording failed, errorCode: \(errorCode)")
        case TUICore_RecordAudioMessageNotifyError_InvalidParam,
             TUICore_RecordAudioMessageNotifyError_SignatureError,
             TUICore_RecordAudioMessageNotifyError_SignatureExpired:
            fallthrough
        default:
            stopCallKitRecording()
            startSystemRecording()
            print("start TUICallKit recording failed, errorCode: \(errorCode), switch to system recorder")
        }
    }
    
    private func onTUICallKitRecordCompleted(_ errorCode: Int32) {
        switch errorCode {
        case TUICore_RecordAudioMessageNotifyError_None:
            stopRecordTimer()
        case TUICore_RecordAudioMessageNotifyError_NoMessageToRecord,
             TUICore_RecordAudioMessageNotifyError_RecordFailed:
            print("stop TUICallKit recording failed, errorCode: \(errorCode)")
        default:
            break
        }
    }
    
    private func onTUICallKitVolumeChanged(_ volume: UInt) {
        let power = Float(volume) - 90
        delegate?.didPowerChanged?(self, power)
    }
}
