import Foundation
import ImSDK_Plus

// MARK: - Result Types

/// Voice processing result for progress callback
public enum TUIAIMediaProcessResult {
    case uploadSuccess(url: String)
    case voiceToTextSuccess(text: String)
    case translationSuccess(translatedText: String)
    case failure(code: Int32, message: String?)
}

/// Translation result containing original and translated text
public struct TUIAITranslationResult {
    public let originalText: String
    public let translatedText: String
}

// MARK: - Error Types

/// Media process error with code and message
public struct TUIAIMediaProcessError: Error {
    public let code: Int32
    public let message: String?
    
    public init(code: Int32, message: String?) {
        self.code = code
        self.message = message
    }
    
    public var localizedDescription: String {
        return "Error: code=\(code), message=\(message ?? "unknown")"
    }
}

// MARK: - File Type

/// File type for upload
public enum TUIAIMediaFileType: Int {
    case unknown = 0
    case image = 1
    case video = 2
    case audio = 3
    case log = 4
}

// MARK: - TUIAIMediaProcessManager

/// AI Media Processing Manager
/// Handles voice upload, voice-to-text conversion, text translation, and other AI services
public class TUIAIMediaProcessManager {
    
    // MARK: - Singleton
    
    public static let shared = TUIAIMediaProcessManager()
    
    private init() {}
    
    // MARK: - Public Methods - Individual APIs
    
    /// Upload file to server
    /// - Parameters:
    ///   - filePath: Local file path
    ///   - fileType: File type (default: audio)
    ///   - completion: Completion callback with uploaded URL or error
    public func uploadFile(
        filePath: String,
        fileType: TUIAIMediaFileType = .audio,
        completion: @escaping (Result<String, TUIAIMediaProcessError>) -> Void
    ) {
        let param: [String: Any] = [
            "filePath": filePath,
            "fileType": fileType.rawValue
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: param, options: .prettyPrinted),
              let paramStr = String(data: data, encoding: .utf8) else {
            completion(.failure(TUIAIMediaProcessError(code: -1, message: "Invalid parameter")))
            return
        }
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "uploadFile",
            param: paramStr as NSObject,
            succ: { result in
                if let url = result as? String, !url.isEmpty {
                    completion(.success(url))
                } else {
                    completion(.failure(TUIAIMediaProcessError(code: -1, message: "Empty result")))
                }
            },
            fail: { code, desc in
                completion(.failure(TUIAIMediaProcessError(code: code, message: desc)))
            }
        )
    }
    
    /// Convert voice to text
    /// - Parameters:
    ///   - url: Voice file URL (must be uploaded first)
    ///   - language: Language code (empty string for auto-detect)
    ///   - completion: Completion callback with converted text or error
    public func convertVoiceToText(
        url: String,
        language: String = "",
        completion: @escaping (Result<String, TUIAIMediaProcessError>) -> Void
    ) {
        let param: [String: Any] = [
            "url": url,
            "language": language
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: param, options: .prettyPrinted),
              let paramStr = String(data: data, encoding: .utf8) else {
            completion(.failure(TUIAIMediaProcessError(code: -1, message: "Invalid parameter")))
            return
        }
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "convertVoiceToText",
            param: paramStr as NSObject,
            succ: { result in
                if let text = result as? String, !text.isEmpty {
                    completion(.success(text))
                } else {
                    completion(.failure(TUIAIMediaProcessError(code: -1, message: "Empty result")))
                }
            },
            fail: { code, desc in
                completion(.failure(TUIAIMediaProcessError(code: code, message: desc)))
            }
        )
    }
    
    /// Translate text
    /// - Parameters:
    ///   - texts: Array of texts to translate
    ///   - sourceLanguage: Source language code (empty for auto-detect)
    ///   - targetLanguage: Target language code
    ///   - completion: Completion callback with translated texts or error
    public func translateText(
        texts: [String],
        sourceLanguage: String = "",
        targetLanguage: String,
        completion: @escaping (Result<[String], TUIAIMediaProcessError>) -> Void
    ) {
        V2TIMManager.sharedInstance().translateText(
            sourceTextList: texts,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            completion: { code, desc, resultDict in
                if code != 0 {
                    completion(.failure(TUIAIMediaProcessError(code: code, message: desc)))
                    return
                }
                
                guard let dict = resultDict, !dict.isEmpty else {
                    completion(.failure(TUIAIMediaProcessError(code: -1, message: "Empty result")))
                    return
                }
                
                // Preserve order of input texts
                let translatedTexts = texts.compactMap { dict[$0] }
                if !translatedTexts.isEmpty {
                    completion(.success(translatedTexts))
                } else {
                    completion(.failure(TUIAIMediaProcessError(code: -1, message: "Empty result")))
                }
            }
        )
    }
    
    /// Translate single text (convenience method)
    /// - Parameters:
    ///   - text: Text to translate
    ///   - sourceLanguage: Source language code (empty for auto-detect)
    ///   - targetLanguage: Target language code
    ///   - completion: Completion callback with translated text or error
    public func translateText(
        text: String,
        sourceLanguage: String = "",
        targetLanguage: String,
        completion: @escaping (Result<String, TUIAIMediaProcessError>) -> Void
    ) {
        translateText(texts: [text], sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) { result in
            switch result {
            case .success(let texts):
                if let first = texts.first {
                    completion(.success(first))
                } else {
                    completion(.failure(TUIAIMediaProcessError(code: -1, message: "Empty result")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Public Methods - Workflow APIs
    
    /// Process voice file to text (upload + convert)
    /// - Parameters:
    ///   - filePath: Local voice file path
    ///   - language: Language code for voice recognition (empty for auto-detect)
    ///   - progressCallback: Optional callback for each step progress
    ///   - completion: Completion callback with converted text or error
    public func processVoiceToText(
        filePath: String,
        language: String = "",
        progressCallback: ((TUIAIMediaProcessResult) -> Void)? = nil,
        completion: @escaping (Result<String, TUIAIMediaProcessError>) -> Void
    ) {
        // Step 1: Upload file
        uploadFile(filePath: filePath, fileType: .audio) { [weak self] uploadResult in
            guard let self = self else { return }
            
            switch uploadResult {
            case .success(let url):
                progressCallback?(.uploadSuccess(url: url))
                
                // Step 2: Convert voice to text
                self.convertVoiceToText(url: url, language: language) { convertResult in
                    switch convertResult {
                    case .success(let text):
                        progressCallback?(.voiceToTextSuccess(text: text))
                        completion(.success(text))
                    case .failure(let error):
                        progressCallback?(.failure(code: -1, message: error.localizedDescription))
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                progressCallback?(.failure(code: -1, message: error.localizedDescription))
                completion(.failure(error))
            }
        }
    }
    
    /// Process voice file with translation (upload + convert + translate)
    /// - Parameters:
    ///   - filePath: Local voice file path
    ///   - sourceLanguage: Source language code for voice recognition (empty for auto-detect)
    ///   - targetLanguage: Target language code for translation
    ///   - progressCallback: Optional callback for each step progress
    ///   - completion: Completion callback with original and translated text or error
    public func processVoiceWithTranslation(
        filePath: String,
        sourceLanguage: String = "",
        targetLanguage: String,
        progressCallback: ((TUIAIMediaProcessResult) -> Void)? = nil,
        completion: @escaping (Result<TUIAITranslationResult, TUIAIMediaProcessError>) -> Void
    ) {
        // Step 1 & 2: Upload and convert voice to text
        processVoiceToText(filePath: filePath, language: sourceLanguage, progressCallback: progressCallback) { [weak self] voiceResult in
            guard let self = self else { return }
            
            switch voiceResult {
            case .success(let originalText):
                // Step 3: Translate text
                self.translateText(text: originalText, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) { translateResult in
                    switch translateResult {
                    case .success(let translatedText):
                        progressCallback?(.translationSuccess(translatedText: translatedText))
                        let result = TUIAITranslationResult(originalText: originalText, translatedText: translatedText)
                        completion(.success(result))
                    case .failure(let error):
                        progressCallback?(.failure(code: -1, message: error.localizedDescription))
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - TTS
    
    /// Convert text to voice
    /// - Parameters:
    ///   - text: Text to convert
    ///   - voiceId: Voice ID for TTS (optional, for voice cloning)
    ///   - completion: Completion callback with audio URL or error
    public func convertTextToVoice(
        text: String,
        voiceId: String? = nil,
        completion: @escaping (Result<String, TUIAIMediaProcessError>) -> Void
    ) {
        var param: [String: Any] = ["text": text]
        if let voiceId = voiceId, !voiceId.isEmpty {
            param["voiceId"] = voiceId
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: param, options: .prettyPrinted),
              let paramStr = String(data: data, encoding: .utf8) else {
            completion(.failure(TUIAIMediaProcessError(code: -1, message: "Invalid parameter")))
            return
        }
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "convertTextToVoice",
            param: paramStr as NSObject,
            succ: { result in
                if let url = result as? String, !url.isEmpty {
                    completion(.success(url))
                } else {
                    completion(.failure(TUIAIMediaProcessError(code: -1, message: "Empty result")))
                }
            },
            fail: { code, desc in
                completion(.failure(TUIAIMediaProcessError(code: code, message: desc)))
            }
        )
    }
    
    /// Clone voice from URL
    /// - Parameters:
    ///   - audioUrl: Source voice URL for cloning
    ///   - voiceName: Name for the cloned voice
    ///   - completion: Completion callback with voice ID or error
    public func voiceClone(
        audioUrl: String,
        voiceName: String,
        completion: @escaping (Result<String, TUIAIMediaProcessError>) -> Void
    ) {
        let param: [String: Any] = [
            "audioUrl": audioUrl,
            "voiceName": voiceName
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: param, options: .prettyPrinted),
              let paramStr = String(data: data, encoding: .utf8) else {
            completion(.failure(TUIAIMediaProcessError(code: -1, message: "Invalid parameter")))
            return
        }
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "voiceClone",
            param: paramStr as NSObject,
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
                    completion(.failure(TUIAIMediaProcessError(code: -1, message: "Empty result")))
                }
            },
            fail: { code, desc in
                completion(.failure(TUIAIMediaProcessError(code: code, message: desc)))
            }
        )
    }
    
    /// Clone voice from local file (upload + clone)
    /// - Parameters:
    ///   - filePath: Local voice file path
    ///   - voiceName: Name for the cloned voice
    ///   - completion: Completion callback with voice ID or error
    public func voiceClone(
        filePath: String,
        voiceName: String,
        completion: @escaping (Result<String, TUIAIMediaProcessError>) -> Void
    ) {
        // Step 1: Upload file
        uploadFile(filePath: filePath, fileType: .audio) { [weak self] uploadResult in
            guard let self = self else { return }
            
            switch uploadResult {
            case .success(let audioUrl):
                // Step 2: Clone voice
                self.voiceClone(audioUrl: audioUrl, voiceName: voiceName, completion: completion)
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
