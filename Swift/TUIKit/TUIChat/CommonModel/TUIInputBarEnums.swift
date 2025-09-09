//
//  TUIInputBarEnums.swift
//  TUIChat
//
//  Created by yiliangwang on 2025/1/20.
//  Copyright © 2023 Tencent. All rights reserved.
//

import Foundation

/// Input bar style enumeration
public enum TUIInputBarStyle: Int {
    case `default` = 0    // Default style
    case ai = 1           // AI chat style
}

/// AI state enumeration for Classic version
public enum TUIInputBarAIState: Int {
    case `default` = 0    // AI default state: large input box only
    case active = 1       // AI active state: input box + interrupt/send button
}

/// Input bar style enumeration for Minimalist version
public enum TUIInputBarStyle_Minimalist: Int {
    case `default` = 0    // Default style
    case ai = 1           // AI chat style
}

/// AI state enumeration for Minimalist version
public enum TUIInputBarAIState_Minimalist: Int {
    case `default` = 0    // AI default state: large input box only
    case active = 1       // AI active state: input box + interrupt/send button
}
