import Foundation
import TIMCommon

/// Logger for TUIOfficialAccountPlugin
public class TUIOfficialAccountLog {
    
    // MARK: - Log Level
    
    public enum Level: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        var prefix: String {
            switch self {
            case .debug: return "[DEBUG]"
            case .info: return "[INFO]"
            case .warning: return "[WARN]"
            case .error: return "[ERROR]"
            }
        }
        
        var v2timLevel: V2TIMLogLevel {
            switch self {
            case .debug: return .LOG_DEBUG
            case .info: return .LOG_INFO
            case .warning: return .LOG_WARN
            case .error: return .LOG_ERROR
            }
        }
    }
    
    // MARK: - Properties
    
    private static let tag = "TUIOfficialAccount"
    private static var isEnabled = true
    private static var minLevel: Level = .debug
    
    // MARK: - Configuration
    
    /// Enable or disable logging
    /// - Parameter enabled: Whether logging is enabled
    public static func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    /// Set minimum log level
    /// - Parameter level: Minimum level to log
    public static func setMinLevel(_ level: Level) {
        minLevel = level
    }
    
    // MARK: - Logging Methods
    
    /// Log debug message
    /// - Parameters:
    ///   - message: Message to log
    ///   - file: Source file (auto-filled)
    ///   - function: Function name (auto-filled)
    ///   - line: Line number (auto-filled)
    public static func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    /// Log info message
    /// - Parameters:
    ///   - message: Message to log
    ///   - file: Source file (auto-filled)
    ///   - function: Function name (auto-filled)
    ///   - line: Line number (auto-filled)
    public static func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    /// Log warning message
    /// - Parameters:
    ///   - message: Message to log
    ///   - file: Source file (auto-filled)
    ///   - function: Function name (auto-filled)
    ///   - line: Line number (auto-filled)
    public static func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    /// Log error message
    /// - Parameters:
    ///   - message: Message to log
    ///   - file: Source file (auto-filled)
    ///   - function: Function name (auto-filled)
    ///   - line: Line number (auto-filled)
    public static func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private static func log(
        level: Level,
        message: String,
        file: String,
        function: String,
        line: Int
    ) {
        guard isEnabled, level.rawValue >= minLevel.rawValue else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(level.prefix) [\(tag)] [\(fileName):\(line)] \(function) - \(message)"
        
        #if DEBUG
        print(logMessage)
        #endif
        
        // Also log to IM SDK
        writeToIMLog(level: level, message: message, fileName: fileName, function: function, line: line)
    }
    
    private static func writeToIMLog(
        level: Level,
        message: String,
        fileName: String,
        function: String,
        line: Int
    ) {
        let param: [String: Any] = [
            "logLevel": level.v2timLevel.rawValue,
            "fileName": fileName,
            "funcName": function,
            "lineNumber": line,
            "logContent": "[\(tag)] \(message)"
        ]
        
        guard let dataParam = try? JSONSerialization.data(withJSONObject: param, options: []),
              let strParam = String(data: dataParam, encoding: .utf8) as? NSObject else {
            return
        }
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "writeLog",
            param: strParam,
            succ: nil,
            fail: nil
        )
    }
}

// MARK: - Convenience Extensions

extension TUIOfficialAccountLog {
    
    /// Log API call
    /// - Parameters:
    ///   - api: API name
    ///   - params: API parameters
    public static func logAPI(_ api: String, params: [String: Any]? = nil) {
        var message = "API Call: \(api)"
        if let params = params {
            message += " params: \(params)"
        }
        info(message)
    }
    
    /// Log API response
    /// - Parameters:
    ///   - api: API name
    ///   - success: Whether call succeeded
    ///   - error: Error if failed
    public static func logAPIResponse(_ api: String, success: Bool, error: Error? = nil) {
        if success {
            info("API Response: \(api) succeeded")
        } else {
            let errorMessage = error?.localizedDescription ?? "Unknown error"
            self.error("API Response: \(api) failed - \(errorMessage)")
        }
    }
    
    /// Log user action
    /// - Parameters:
    ///   - action: Action name
    ///   - details: Action details
    public static func logAction(_ action: String, details: String? = nil) {
        var message = "User Action: \(action)"
        if let details = details {
            message += " - \(details)"
        }
        info(message)
    }
}
