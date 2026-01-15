import AVFoundation
import TIMCommon
import TUICore
import UIKit

/// Status for text-to-voice conversion
@objc public enum TUITextToVoiceStatus: Int {
    case hidden = 0
    case loading = 1
    case shown = 2
    case failed = 3
}

/// Data provider for text-to-voice functionality
public class TUITextToVoiceDataProvider: NSObject, TUIAudioPlaybackManagerDelegate {
    
    // MARK: - Singleton
    
    public static let shared: TUITextToVoiceDataProvider = {
        let instance = TUITextToVoiceDataProvider()
        // Add as delegate to audio playback manager
        TUIAudioPlaybackManager.shared.addDelegate(instance)
        return instance
    }()
    
    // MARK: - Properties
    
    /// Audio playback manager reference
    private var audioManager: TUIAudioPlaybackManager {
        return TUIAudioPlaybackManager.shared
    }
    
    /// State callbacks for each message
    private var playingStateCallbacks: [String: (Bool) -> Void] = [:]
    
    // MARK: - LocalCustomData Keys
    
    private static let kTextToVoiceUrlKey = "textToVoiceUrl"
    private static let kTextToVoiceStatusKey = "textToVoiceStatus"
    private static let kTextToVoiceDurationKey = "textToVoiceDuration"
    private static let kTextToVoiceLocalPathKey = "textToVoiceLocalPath"
    private static let kTextToVoicePlayedKey = "textToVoicePlayed"
    
    // MARK: - Local Storage
    
    /// Get local storage directory for text-to-voice audio files
    private class func getTextToVoiceDirectory() -> String {
        let path = "\(TUISwift.tuiKit_Voice_Path())tts/"
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }
    
    /// Generate local file path for a message
    private class func getLocalFilePath(for msgID: String) -> String {
        return "\(getTextToVoiceDirectory())\(msgID).wav"
    }
    
    /// Check if local file exists for a message
    public class func hasLocalFile(for message: V2TIMMessage) -> Bool {
        guard let msgID = message.msgID else { return false }
        let localPath = getLocalFilePath(for: msgID)
        return FileManager.default.fileExists(atPath: localPath)
    }
    
    /// Get local file path if exists
    public class func getLocalFilePath(for message: V2TIMMessage) -> String? {
        guard let msgID = message.msgID else { return nil }
        let localPath = getLocalFilePath(for: msgID)
        if FileManager.default.fileExists(atPath: localPath) {
            return localPath
        }
        // Also check saved path in localCustomData
        let customData = getLocalCustomData(message)
        if let savedPath = customData[kTextToVoiceLocalPathKey] as? String,
           FileManager.default.fileExists(atPath: savedPath) {
            return savedPath
        }
        return nil
    }
    
    /// Download audio from URL and save to local file
    public class func downloadAndSaveAudio(from url: String, for message: V2TIMMessage, completion: @escaping (Bool, String?) -> Void) {
        guard let msgID = message.msgID,
              let audioURL = URL(string: url) else {
            completion(false, nil)
            return
        }
        
        let localPath = getLocalFilePath(for: msgID)
        
        // Check if already downloaded
        if FileManager.default.fileExists(atPath: localPath) {
            print("[TUITextToVoiceDataProvider] Local file already exists: \(localPath)")
            completion(true, localPath)
            return
        }
        
        print("[TUITextToVoiceDataProvider] Downloading audio from: \(url)")
        
        let task = URLSession.shared.dataTask(with: audioURL) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    print("[TUITextToVoiceDataProvider] Download failed: \(error?.localizedDescription ?? "unknown")")
                    completion(false, nil)
                    return
                }
                
                do {
                    try data.write(to: URL(fileURLWithPath: localPath))
                    print("[TUITextToVoiceDataProvider] Audio saved to: \(localPath)")
                    
                    // Save local path to message's localCustomData
                    var customData = getLocalCustomData(message)
                    customData[kTextToVoiceLocalPathKey] = localPath
                    setLocalCustomData(message, data: customData)
                    
                    completion(true, localPath)
                } catch {
                    print("[TUITextToVoiceDataProvider] Failed to save audio: \(error)")
                    completion(false, nil)
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Public Methods
    
    /// Convert text to voice using experimental API
    /// - Parameters:
    ///   - text: Text to convert
    ///   - voiceId: Optional voice ID. If nil or empty, uses system default voice.
    ///   - completion: Completion callback with (code, errorDesc, audioUrl)
    public class func convertTextToVoice(text: String, voiceId: String? = nil, completion: @escaping (Int, String?, String?) -> Void) {
        var params: [String: Any] = [:]
        params["text"] = text
        params["audioFormat"] = "wav"       // Audio format: pcm or wav
        
        // Add voiceId if provided and not empty
        if let voiceId = voiceId, !voiceId.isEmpty {
            params["voiceId"] = voiceId
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: params, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            completion(-1, "Failed to create request", nil)
            return
        }
        
        print("[TUITextToVoiceDataProvider] Request params: \(jsonString)")
        
        V2TIMManager.sharedInstance().callExperimentalAPI(api: "convertTextToVoice", param: jsonString as NSObject, succ: { result in
            print("[TUITextToVoiceDataProvider] API response: \(String(describing: result))")
            
            var audioUrl: String?
            if let resultString = result as? String,
               let resultData = resultString.data(using: .utf8),
               let resultDict = try? JSONSerialization.jsonObject(with: resultData, options: []) as? [String: Any]
            {
                audioUrl = resultDict["audioUrl"] as? String
            } else if let resultDict = result as? [String: Any] {
                audioUrl = resultDict["audioUrl"] as? String
            }
            
            print("[TUITextToVoiceDataProvider] Parsed audioUrl: \(audioUrl ?? "nil")")
            
            if let audioUrl = audioUrl, !audioUrl.isEmpty {
                completion(0, nil, audioUrl)
            } else {
                completion(-1, "No audio URL in response", nil)
            }
        }, fail: { code, desc in
            print("[TUITextToVoiceDataProvider] API failed: code=\(code), desc=\(desc ?? "nil")")
            completion(Int(code), desc, nil)
        })
    }
    
    /// Get effective voice ID for a conversation
    /// Priority: Conversation setting > Global setting
    /// - Parameter conversationID: Conversation ID (optional)
    /// - Returns: Effective voice ID (empty string means use system default)
    public class func getEffectiveVoiceId(for conversationID: String?) -> String {
        if let convID = conversationID, !convID.isEmpty {
            // Check conversation-level setting first
            if let setting = TUITextToVoiceConversationConfig.shared.getVoiceSetting(for: convID) {
                return setting.voiceId
            }
        }
        // Fall back to global setting
        return TUITextToVoiceConfig.shared.selectedVoiceId
    }
    
    /// Save text-to-voice URL to message's localCustomData and download to local
    public class func saveTextToVoiceUrl(_ message: V2TIMMessage, url: String, duration: TimeInterval) {
        var customData = getLocalCustomData(message)
        customData[kTextToVoiceUrlKey] = url
        customData[kTextToVoiceStatusKey] = TUITextToVoiceStatus.shown.rawValue
        customData[kTextToVoiceDurationKey] = duration
        setLocalCustomData(message, data: customData)
        
        // Download and save to local file (async, no callback needed)
        downloadAndSaveAudio(from: url, for: message) { success, localPath in
            if success, let localPath = localPath {
                print("[TUITextToVoiceDataProvider] Audio cached locally: \(localPath)")
            }
        }
    }
    
    /// Get text-to-voice URL from message
    public class func getTextToVoiceUrl(_ message: V2TIMMessage) -> String? {
        let customData = getLocalCustomData(message)
        return customData[kTextToVoiceUrlKey] as? String
    }
    
    /// Get text-to-voice status from message
    public class func getTextToVoiceStatus(_ message: V2TIMMessage) -> TUITextToVoiceStatus {
        let customData = getLocalCustomData(message)
        if let rawValue = customData[kTextToVoiceStatusKey] as? Int {
            return TUITextToVoiceStatus(rawValue: rawValue) ?? .hidden
        }
        return .hidden
    }
    
    /// Get text-to-voice duration from message
    public class func getTextToVoiceDuration(_ message: V2TIMMessage) -> TimeInterval {
        let customData = getLocalCustomData(message)
        return customData[kTextToVoiceDurationKey] as? TimeInterval ?? 0
    }
    
    /// Check if should show text-to-voice view
    public class func shouldShowTextToVoice(_ message: V2TIMMessage) -> Bool {
        let status = getTextToVoiceStatus(message)
        return status == .shown || status == .loading
    }
    
    /// Set loading status
    public class func setLoadingStatus(_ message: V2TIMMessage) {
        var customData = getLocalCustomData(message)
        customData[kTextToVoiceStatusKey] = TUITextToVoiceStatus.loading.rawValue
        setLocalCustomData(message, data: customData)
    }
    
    /// Clear text-to-voice data
    public class func clearTextToVoice(_ message: V2TIMMessage) {
        var customData = getLocalCustomData(message)
        customData.removeValue(forKey: kTextToVoiceUrlKey)
        customData.removeValue(forKey: kTextToVoiceStatusKey)
        customData.removeValue(forKey: kTextToVoiceDurationKey)
        customData.removeValue(forKey: kTextToVoiceLocalPathKey)
        setLocalCustomData(message, data: customData)
    }
    
    /// Set failed status
    public class func setFailedStatus(_ message: V2TIMMessage) {
        var customData = getLocalCustomData(message)
        customData[kTextToVoiceStatusKey] = TUITextToVoiceStatus.failed.rawValue
        setLocalCustomData(message, data: customData)
    }
    
    // MARK: - Played Status
    
    /// Check if text-to-voice has been played
    public class func isTextToVoicePlayed(_ message: V2TIMMessage) -> Bool {
        let customData = getLocalCustomData(message)
        return customData[kTextToVoicePlayedKey] as? Bool ?? false
    }
    
    /// Mark text-to-voice as played
    public class func markTextToVoiceAsPlayed(_ message: V2TIMMessage) {
        var customData = getLocalCustomData(message)
        customData[kTextToVoicePlayedKey] = true
        setLocalCustomData(message, data: customData)
    }
    
    // MARK: - Audio Playback Notification
    
    /// Notification name for stopping all audio playback (legacy, use TUIStopAllAudioPlayback instead)
    public static let stopAllAudioPlaybackNotification = Notification.Name.TUIStopAllAudioPlayback
    
    // MARK: - Audio Playback
    
    /// Play audio for a message (prefer local file, fallback to URL)
    public func playAudio(for message: V2TIMMessage, stateCallback: @escaping (Bool) -> Void) {
        guard let msgID = message.msgID else {
            stateCallback(false)
            return
        }
        
        // Store callback
        playingStateCallbacks[msgID] = stateCallback
        
        // Mark as played when starting playback
        TUITextToVoiceDataProvider.markTextToVoiceAsPlayed(message)
        
        // Try local file first
        if let localPath = TUITextToVoiceDataProvider.getLocalFilePath(for: message) {
            print("[TUITextToVoiceDataProvider] Playing from local file: \(localPath)")
            audioManager.playAudio(fromPath: localPath, msgID: msgID) { [weak self] playing in
                self?.playingStateCallbacks[msgID]?(playing)
            }
            return
        }
        
        // Fallback to URL - need to download first to save locally
        if let urlString = TUITextToVoiceDataProvider.getTextToVoiceUrl(message),
           let url = URL(string: urlString) {
            print("[TUITextToVoiceDataProvider] Playing from URL: \(urlString)")
            downloadAndPlay(url: urlString, msgID: msgID, message: message)
        } else {
            stateCallback(false)
        }
    }
    
    /// Play audio from URL (legacy method for compatibility)
    public func playAudio(url: String, msgID: String, stateCallback: @escaping (Bool) -> Void) {
        playingStateCallbacks[msgID] = stateCallback
        
        guard let audioURL = URL(string: url) else {
            stateCallback(false)
            return
        }
        
        audioManager.playAudio(fromURL: audioURL, msgID: msgID) { [weak self] playing in
            self?.playingStateCallbacks[msgID]?(playing)
        }
    }
    
    /// Stop current audio
    public func stopCurrentAudio() {
        audioManager.stopCurrentAudio()
    }
    
    /// Check if specific message is playing
    public func isPlaying(msgID: String) -> Bool {
        return audioManager.isPlaying(msgID: msgID)
    }
    
    // MARK: - Private Methods
    
    private func downloadAndPlay(url: String, msgID: String, message: V2TIMMessage?) {
        guard let audioURL = URL(string: url) else {
            playingStateCallbacks[msgID]?(false)
            return
        }
        
        // Download first to save locally, then play
        let task = URLSession.shared.dataTask(with: audioURL) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self, let data = data, error == nil else {
                    self?.playingStateCallbacks[msgID]?(false)
                    return
                }
                
                // Save to local file if message is provided
                if let message = message {
                    TUITextToVoiceDataProvider.saveDataToLocalFile(data, for: message)
                }
                
                // Play using audio manager
                self.audioManager.playAudio(fromData: data, msgID: msgID) { [weak self] playing in
                    self?.playingStateCallbacks[msgID]?(playing)
                }
            }
        }
        task.resume()
    }
    
    /// Save audio data to local file
    private class func saveDataToLocalFile(_ data: Data, for message: V2TIMMessage) {
        guard let msgID = message.msgID else { return }
        
        let localPath = getLocalFilePath(for: msgID)
        
        // Skip if already exists
        if FileManager.default.fileExists(atPath: localPath) {
            return
        }
        
        do {
            try data.write(to: URL(fileURLWithPath: localPath))
            print("[TUITextToVoiceDataProvider] Audio saved during playback: \(localPath)")
            
            // Update localCustomData
            var customData = getLocalCustomData(message)
            customData[kTextToVoiceLocalPathKey] = localPath
            setLocalCustomData(message, data: customData)
        } catch {
            print("[TUITextToVoiceDataProvider] Failed to save audio during playback: \(error)")
        }
    }
    
    // MARK: - TUIAudioPlaybackManagerDelegate
    
    public func audioPlaybackManager(_ manager: TUIAudioPlaybackManager, didChangePlayingState isPlaying: Bool, forMsgID msgID: String) {
        print("[TUITextToVoiceDataProvider] didChangePlayingState - msgID: \(msgID), isPlaying: \(isPlaying)")
        // Forward to legacy notification for backward compatibility
        NotificationCenter.default.post(
            name: NSNotification.Name("TUITextToVoicePlaybackStateChanged"),
            object: nil,
            userInfo: ["msgID": msgID, "isPlaying": isPlaying]
        )
    }
    
    public func audioPlaybackManager(_ manager: TUIAudioPlaybackManager, didFinishPlayingForMsgID msgID: String) {
        print("[TUITextToVoiceDataProvider] didFinishPlayingForMsgID - msgID: \(msgID)")
        // Forward to legacy notification for backward compatibility
        NotificationCenter.default.post(
            name: NSNotification.Name("TUITextToVoicePlaybackFinished"),
            object: nil,
            userInfo: ["msgID": msgID]
        )
    }
    
    // MARK: - LocalCustomData Helpers
    
    private class func getLocalCustomData(_ message: V2TIMMessage) -> [String: Any] {
        guard let data = message.localCustomData as Data?,
              let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            return [:]
        }
        return dict
    }
    
    private class func setLocalCustomData(_ message: V2TIMMessage, data: [String: Any]) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) {
            message.localCustomData = jsonData
        }
    }
    
    // MARK: - Fetch Audio Duration
    
    /// Fetch audio duration from URL asynchronously
    public class func fetchAudioDuration(from urlString: String, completion: @escaping (TimeInterval) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(0)
            return
        }
        
        let asset = AVURLAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError?
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            
            DispatchQueue.main.async {
                if status == .loaded {
                    let duration = CMTimeGetSeconds(asset.duration)
                    if duration.isFinite && duration > 0 {
                        completion(duration)
                    } else {
                        completion(0)
                    }
                } else {
                    completion(0)
                }
            }
        }
    }
    
    // MARK: - Voice Clone APIs
    
    /// Error types for voice clone operations
    public enum VoiceCloneError: Error, LocalizedError {
        case invalidParameter
        case uploadFailed(code: Int32, message: String?)
        case cloneFailed(code: Int32, message: String?)
        case listFailed(code: Int32, message: String?)
        case deleteFailed(code: Int32, message: String?)
        case parseError
        
        public var errorDescription: String? {
            switch self {
            case .invalidParameter:
                return "Invalid parameter"
            case .uploadFailed(let code, let message):
                return "Upload failed: \(message ?? "code \(code)")"
            case .cloneFailed(let code, let message):
                return "Clone failed: \(message ?? "code \(code)")"
            case .listFailed(let code, let message):
                return "Get list failed: \(message ?? "code \(code)")"
            case .deleteFailed(let code, let message):
                return "Delete failed: \(message ?? "code \(code)")"
            case .parseError:
                return "Failed to parse response"
            }
        }
    }
    
    /// Upload voice file for cloning
    /// - Parameters:
    ///   - filePath: Local file path of the voice recording
    ///   - completion: Completion callback with uploaded URL or error
    public func uploadVoiceFile(filePath: String, completion: @escaping (Result<String, VoiceCloneError>) -> Void) {
        let params: [String: Any] = [
            "filePath": filePath,
            "fileType": 3  // Audio type
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: params, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(.failure(.invalidParameter))
            return
        }
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "uploadFile",
            param: jsonString as NSObject,
            succ: { result in
                if let url = result as? String, !url.isEmpty {
                    completion(.success(url))
                } else {
                    completion(.failure(.parseError))
                }
            },
            fail: { code, desc in
                completion(.failure(.uploadFailed(code: code, message: desc)))
            }
        )
    }
    
    /// Clone voice using uploaded voice URL
    /// - Parameters:
    ///   - voiceUrl: URL of the uploaded voice file
    ///   - voiceName: Name for the cloned voice
    ///   - completion: Completion callback with voice ID or error
    public func cloneVoice(audioUrl: String, voiceName: String, completion: @escaping (Result<String, VoiceCloneError>) -> Void) {
        let params: [String: Any] = [
            "audioUrl": audioUrl,
            "voiceName": voiceName
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: params, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(.failure(.invalidParameter))
            return
        }
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "voiceClone",
            param: jsonString as NSObject,
            succ: { result in
                var voiceId: String?
                
                // Parse response - may be JSON string or dictionary
                if let resultString = result as? String {
                    if let resultData = resultString.data(using: .utf8),
                       let resultDict = try? JSONSerialization.jsonObject(with: resultData, options: []) as? [String: Any] {
                        voiceId = resultDict["voiceId"] as? String
                    } else {
                        // Result might be the voiceId directly
                        voiceId = resultString
                    }
                } else if let resultDict = result as? [String: Any] {
                    voiceId = resultDict["voiceId"] as? String
                }
                
                if let voiceId = voiceId, !voiceId.isEmpty {
                    completion(.success(voiceId))
                } else {
                    completion(.failure(.parseError))
                }
            },
            fail: { code, desc in
                completion(.failure(.cloneFailed(code: code, message: desc)))
            }
        )
    }
    
    /// Get custom voice list
    /// - Parameters:
    ///   - completion: Completion callback with voice list, or error
    public func getCustomVoiceList(completion: @escaping (Result<[TUICustomVoiceItem], VoiceCloneError>) -> Void) {
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "getCustomVoiceList",
            param: "{}" as NSObject,
            succ: { result in
                var voiceList: [TUICustomVoiceItem] = []
                
                // Parse response
                var resultDict: [String: Any]?
                if let resultString = result as? String,
                   let resultData = resultString.data(using: .utf8) {
                    resultDict = try? JSONSerialization.jsonObject(with: resultData, options: []) as? [String: Any]
                } else if let dict = result as? [String: Any] {
                    resultDict = dict
                }
                
                if let dict = resultDict {
                    if let voiceListArray = dict["voiceList"] as? [[String: Any]] {
                        for voiceDict in voiceListArray {
                            if let voiceId = voiceDict["voiceId"] as? String,
                               let name = voiceDict["voiceName"] as? String {
                                let item = TUICustomVoiceItem(voiceId: voiceId, name: name, isDefault: false)
                                voiceList.append(item)
                            }
                        }
                    }
                }
                
                completion(.success(voiceList))
            },
            fail: { code, desc in
                completion(.failure(.listFailed(code: code, message: desc)))
            }
        )
    }
    
    /// Delete custom voice
    /// - Parameters:
    ///   - voiceId: ID of the voice to delete
    ///   - completion: Completion callback with success or error
    public func deleteCustomVoice(voiceId: String, completion: @escaping (Result<Void, VoiceCloneError>) -> Void) {
        let params: [String: Any] = [
            "voiceId": voiceId
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: params, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(.failure(.invalidParameter))
            return
        }
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "deleteCustomVoice",
            param: jsonString as NSObject,
            succ: { _ in
                completion(.success(()))
            },
            fail: { code, desc in
                completion(.failure(.deleteFailed(code: code, message: desc)))
            }
        )
    }
}
