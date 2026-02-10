import Foundation
import UIKit

public extension String {
    static let kSplitStringResultKey = "result"
    static let kSplitStringTextKey = "text"
    static let kSplitStringTextIndexKey = "textIndex"
    
    func getLocalizableStringWithFaceContent() -> String {
        var content = self
        let regexEmoji = String.getRegexEmoji()
        do {
            let regex = try NSRegularExpression(pattern: regexEmoji, options: .caseInsensitive)
            // Use NSString for consistent UTF-16 based range calculation
            let nsString = content as NSString
            let results = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            let group = TIMConfig.shared.faceGroups?[0]
            var waitingReplace = [(range: NSRange, localizableStr: String)]()
            
            for match in results {
                let range = match.range
                let subStr = (content as NSString).substring(with: range)
                if let faces = group?.faces {
                    for face in faces {
                        if face.name == subStr {
                            let localizableStr = face.localizableName ?? face.name ?? ""
                            waitingReplace.append((range, localizableStr))
                            break
                        }
                    }
                }
            }
            
            for item in waitingReplace.reversed() {
                content = (content as NSString).replacingCharacters(in: item.range, with: item.localizableStr)
            }
        } catch {
            print("Regex error: \(error.localizedDescription)")
        }
        return content
    }
    
    func getInternationalStringWithFaceContent() -> String {
        var content = self
        let regexEmoji = String.getRegexEmoji()
        do {
            let regex = try NSRegularExpression(pattern: regexEmoji, options: .caseInsensitive)
            // Use NSString for consistent UTF-16 based range calculation
            let nsString = content as NSString
            let results = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            let group = TIMConfig.shared.faceGroups?[0]
            var faceDict = [String: String]()
            
            if let faces = group?.faces {
                for face in faces {
                    let key = face.localizableName ?? face.name ?? ""
                    let value = face.name
                    faceDict[key] = value
                }
            }
            
            var waitingReplace = [(range: NSRange, localizableStr: String)]()
            for match in results {
                let range = match.range
                let subStr = (content as NSString).substring(with: range)
                let localizableStr = faceDict[subStr] ?? subStr
                waitingReplace.append((range, localizableStr))
            }
            
            for item in waitingReplace.reversed() {
                content = (content as NSString).replacingCharacters(in: item.range, with: item.localizableStr)
            }
        } catch {
            print("Regex error: \(error.localizedDescription)")
        }
        return content
    }
    
    func getFormatEmojiString(withFont textFont: UIFont, emojiLocations: inout [[NSValue: NSAttributedString]]?) -> NSMutableAttributedString {
        guard !self.isEmpty else {
            print("getFormatEmojiStringWithFont failed, current text is nil")
            return NSMutableAttributedString(string: "")
        }
        
        let attributeString = NSMutableAttributedString(string: self)
        guard let faceGroups = TIMConfig.shared.faceGroups, !faceGroups.isEmpty else {
            attributeString.addAttribute(.font, value: textFont, range: NSRange(location: 0, length: attributeString.length))
            return attributeString
        }
        
        let regexEmoji = String.getRegexEmoji()
        do {
            let regex = try NSRegularExpression(pattern: regexEmoji, options: .caseInsensitive)
            // Use NSString for consistent UTF-16 based range calculation
            let nsString = self as NSString
            let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
            let group = faceGroups[0]
            var imageArray = [(range: NSRange, imageStr: NSAttributedString)]()
            
            for match in results {
                let range = match.range
                let subStr = nsString.substring(with: range)
                
                if let faces = group.faces {
                    for face in faces {
                        if face.name == subStr {
                            let emojiTextAttachment = TUIEmojiTextAttachment()
                            emojiTextAttachment.faceCellData = face
                            emojiTextAttachment.emojiTag = face.name
                            if let path = face.path {
                                emojiTextAttachment.image = TUIImageCache.sharedInstance().getFaceFromCache(path)
                            }
                            emojiTextAttachment.emojiSize = kTIMDefaultEmojiSize
                            let imageStr = NSAttributedString(attachment: emojiTextAttachment)
                            imageArray.append((range, imageStr))
                            break
                        }
                    }
                }
            }
            
            var locations = [(originRange: NSRange, originStr: NSAttributedString, currentStr: NSAttributedString)]()
            for item in imageArray.reversed() {
                let originRange = item.range
                let originStr = attributeString.attributedSubstring(from: originRange)
                let currentStr = item.imageStr
                locations.insert((originRange, originStr, currentStr), at: 0)
                attributeString.replaceCharacters(in: originRange, with: currentStr)
            }
            
            var offsetLocation = 0
            for location in locations {
                var currentRange = location.originRange
                currentRange.location += offsetLocation
                currentRange.length = location.currentStr.length
                offsetLocation += location.currentStr.length - location.originStr.length
                emojiLocations?.append([NSValue(range: currentRange): location.originStr])
            }
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byCharWrapping
            attributeString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributeString.length))
            attributeString.addAttribute(.font, value: textFont, range: NSRange(location: 0, length: attributeString.length))
            
        } catch {
            print("Regex error: \(error.localizedDescription)")
        }
        
        return attributeString
    }
    
    func getEmojiImagePath() -> String? {
        guard let group = TIMConfig.shared.faceGroups?[0], let faces = group.faces else { return nil }
        let localName = self.getLocalizableStringWithFaceContent()
        for face in faces {
            if face.localizableName == localName {
                return face.path
            }
        }
        return nil
    }
    
    func getEmojiImage() -> UIImage? {
        guard let group = TIMConfig.shared.faceGroups?[0], let faces = group.faces else { return nil }
        for face in faces {
            if face.name == self, face.path != nil {
                return TUIImageCache.sharedInstance().getFaceFromCache(face.path!)
            }
        }
        return nil
    }
    
    func getAdvancedFormatEmojiString(withFont textFont: UIFont, textColor: UIColor, emojiLocations: inout [[NSValue: NSAttributedString]]?) -> NSMutableAttributedString {
        guard !self.isEmpty else {
            print("getAdvancedFormatEmojiStringWithFont failed, current text is nil")
            return NSMutableAttributedString(string: "")
        }
        
        let attributeString = NSMutableAttributedString(string: self)
        guard let faceGroups = TIMConfig.shared.faceGroups, !faceGroups.isEmpty else {
            attributeString.addAttribute(.font, value: textFont, range: NSRange(location: 0, length: attributeString.length))
            return attributeString
        }
        
        let regexEmoji = String.getRegexEmoji()
        do {
            let regex = try NSRegularExpression(pattern: regexEmoji, options: .caseInsensitive)
            // Use NSString for consistent UTF-16 based range calculation
            let nsString = self as NSString
            let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
            let group = faceGroups[0]
            var imageArray = [(range: NSRange, imageStr: NSAttributedString)]()
            
            for match in results {
                let range = match.range
                let subStr = nsString.substring(with: range)
                
                if let faces = group.faces {
                    for face in faces {
                        if face.name == subStr || face.localizableName == subStr {
                            let emojiTextAttachment = TUIEmojiTextAttachment()
                            emojiTextAttachment.faceCellData = face
                            emojiTextAttachment.emojiTag = face.name
                            if let path = face.path {
                                emojiTextAttachment.image = TUIImageCache.sharedInstance().getFaceFromCache(path)
                            }
                            emojiTextAttachment.emojiSize = kTIMDefaultEmojiSize
                            let imageStr = NSAttributedString(attachment: emojiTextAttachment)
                            imageArray.append((range, imageStr))
                            break
                        }
                    }
                }
            }
            
            var locations = [(originRange: NSRange, originStr: NSAttributedString, currentStr: NSAttributedString)]()
            for item in imageArray.reversed() {
                let originRange = item.range
                let originStr = attributeString.attributedSubstring(from: originRange)
                let currentStr = item.imageStr
                locations.insert((originRange, originStr, currentStr), at: 0)
                attributeString.replaceCharacters(in: originRange, with: currentStr)
            }
            
            var offsetLocation = 0
            for location in locations {
                var currentRange = location.originRange
                currentRange.location += offsetLocation
                currentRange.length = location.currentStr.length
                offsetLocation += location.currentStr.length - location.originStr.length
                emojiLocations?.append([NSValue(range: currentRange): location.originStr])
            }
            
            attributeString.addAttribute(.font, value: textFont, range: NSRange(location: 0, length: attributeString.length))
            attributeString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: attributeString.length))
            
        } catch {
            print("Regex error: \(error.localizedDescription)")
        }
        
        return attributeString
    }
    
    /**
     * Steps:
     * 1. Match @user infos in string.
     * 2. Split origin string into array(A) by @user info's ranges.
     * 3. Iterate the array(A) to match emoji one by one.
     * 4. Add all parsed elements(emoji, @user, pure text) into result.
     * 5. Process the text and textIndex by the way.
     * 6. Encapsulate all arrays in a dict and return it.
     */
    func splitTextByEmojiAndAtUsers(_ users: [String]?) -> [String: Any]? {
        guard !self.isEmpty else { return nil }
        var result = [String]()
        
        // Find @user info's ranges in string.
        var atUsers = [String]()
        users?.forEach { user in
            // Add an whitespace after the user's name due to the special format of @ content.
            let atUser = "@\(user) "
            atUsers.append(atUser)
        }
        let atUserRanges = self.rangeOfAtUsers(atUsers, in: self)
        
        // Split text using @user info's ranges.
        let splitResult = self.splitArrayWithRanges(atUserRanges, in: self)
        guard let splitArrayByAtUser = splitResult?.first as? [String] else {
            return nil
        }
        guard let last = splitResult?.last as? [Int] else {
            return nil
        }
        let atUserIndex: Set<Int> = Set(last)
        
        // Iterate the split array after finding @user, aimed to match emoji.
        var k = -1
        var textIndexArray = [Int]()
        for (i, str) in splitArrayByAtUser.enumerated() {
            if atUserIndex.contains(i) {
                // str is @user info.
                result.append(str)
                k += 1
            } else {
                // str is not @user info, try to parse emoji in the same way as above.
                let emojiRanges = self.matchTextByEmoji(str)
                let splitResult = self.splitArrayWithRanges(emojiRanges, in: str)
                if let splitArrayByEmoji = splitResult?.first as? [String],
                   let emojiIndex = splitResult?.last as? [Int] {
                    for j in 0 ..< splitArrayByEmoji.count {
                        let tmp = splitArrayByEmoji[j]
                        result.append(tmp)
                        k += 1
                        if !emojiIndex.contains(j) {
                            // str is text.
                            textIndexArray.append(k)
                        }
                    }
                }
            }
        }
        
        var textArray = [String]()
        for n in textIndexArray {
            textArray.append(result[n])
        }
        
        return [String.kSplitStringResultKey: result, String.kSplitStringTextKey: textArray, String.kSplitStringTextIndexKey: textIndexArray]
    }
    
    private func rangeOfAtUsers(_ atUsers: [String], in string: String) -> [NSValue] {
        var atIndex = IndexSet()
        for (i, char) in string.enumerated() {
            if char == "@" {
                atIndex.insert(i)
            }
        }
        
        var result = [NSValue]()
        for user in atUsers {
            for idx in atIndex {
                if string.count >= user.count, idx <= string.count - user.count {
                    let range = NSRange(location: idx, length: user.count)
                    if (string as NSString).substring(with: range) == user {
                        result.append(NSValue(range: range))
                        atIndex.remove(idx)
                    }
                }
            }
        }
        return result
    }
    
    /// Split string into multi substrings by given ranges.
    /// Return value's structure is [result, indexes], in which indexs means position of content within ranges located in result after spliting.
    private func splitArrayWithRanges(_ ranges: [NSValue], in string: String) -> [Any]? {
        guard !ranges.isEmpty else { return [[string], []] }
        guard !string.isEmpty else { return nil }
        
        let sortedRanges = ranges.sorted { $0.rangeValue.location < $1.rangeValue.location }
        
        var result = [String]()
        var indexes = [Int]()
        var prev = 0
        var j = -1
        var i = 0
        
        while i < sortedRanges.count {
            let cur = sortedRanges[i].rangeValue
            var str = ""
            if cur.location > prev {
                // Add the str in [prev, cur.location).
                str = (string as NSString).substring(with: NSRange(location: prev, length: cur.location - prev))
                result.append(str)
                j += 1
            }
            
            // Add the str in cur range.
            str = (string as NSString).substring(with: cur)
            result.append(str)
            j += 1
            indexes.append(j)
            
            // Update prev to support calculation of next round.
            prev = cur.location + cur.length
            
            // Text exists after the last emoji.
            if i == sortedRanges.count - 1, prev < string.utf16.count - 1 {
                let last = (string as NSString).substring(with: NSRange(location: prev, length: string.utf16.count - prev))
                result.append(last)
            }
            
            i += 1
        }
        
        return [result, indexes]
    }
    
    private func matchTextByEmoji(_ text: String) -> [NSValue] {
        guard let faceGroups = TIMConfig.shared.faceGroups else { return [] }
        var result = [NSValue]()
        
        // TUIKit customized emoji.
        let regexOfCustomEmoji = String.getRegexEmoji()
        do {
            let regex = try NSRegularExpression(pattern: regexOfCustomEmoji, options: .caseInsensitive)
            // Use NSString for consistent UTF-16 based range calculation
            let nsString = text as NSString
            let matchResult = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            let group = faceGroups[0]
            
            for match in matchResult {
                let substring = nsString.substring(with: match.range)
                if let faces = group.faces {
                    for face in faces {
                        if face.name == substring || face.localizableName == substring {
                            result.append(NSValue(range: match.range))
                            break
                        }
                    }
                } else {
                    return []
                }
            }
        } catch {
            print("TUIKit Emoji Regex error: \(error.localizedDescription)")
        }
        
        // Unicode emoji.
        let regexOfUnicodeEmoji = String.unicodeEmojiReString()
        do {
            let regex = try NSRegularExpression(pattern: regexOfUnicodeEmoji, options: .caseInsensitive)
            // Use NSString for consistent UTF-16 based range calculation
            let nsString = text as NSString
            let matchResult = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matchResult {
                result.append(NSValue(range: match.range))
            }
        } catch {
            print("Unicode Emoji Regex error: \(error.localizedDescription)")
        }
        
        return result
    }
    
    static func replacedStringWithArray(_ array: [String], index indexArray: [Int], replaceDict: [String: String]?) -> String? {
        guard let replaceDict = replaceDict else { return nil }
        var mutableArray = array
        for value in indexArray {
            if value < 0 || value > mutableArray.count - 1 {
                continue
            }
            if let replacement = replaceDict[mutableArray[value]] {
                mutableArray[value] = replacement
            }
        }
        return mutableArray.joined()
    }
    
    static func getRegexEmoji() -> String {
        return "\\[[a-zA-Z0-9_\\u4e00-\\u9fa5]+\\]"
    }
    
    static func unicodeEmojiReString() -> String {
        let ri = "[\u{0001F1E6}-\u{0001F1FF}]"
        
        /// \u0023(#), \u002A(*), \u0030(keycap 0), \u0039(keycap 9), \u00A9(©), \u00AE(®) couldn't be added to NSString directly, need to transform a little bit.
        let unsupport = String(format: "%C|%C|[%C-%C]|", 0x0023, 0x002a, 0x0030, 0x0039)
        let support =
            "\u{000000A9}|\u{000000AE}|\u{203C}|\u{2049}|\u{2122}|\u{2139}|[\u{2194}-\u{2199}]|[\u{21A9}-\u{21AA}]|[\u{231A}-\u{231B}]|\u{2328}|\u{23CF}|[\u{23E9}-\u{23EF}]|[\u{23F0}-\u{23F3}]|[\u{23F8}-\u{23FA}]|\u{24C2}|[\u{25AA}-\u{25AB}]|\u{25B6}|\u{25C0}|[\u{25FB}-\u{25FE}]|[\u{2600}-\u{2604}]|\u{260E}|\u{2611}|[\u{2614}-\u{2615}]|\u{2618}|\u{261D}|\u{2620}|[\u{2622}-\u{2623}]|\u{2626}|\u{262A}|[\u{262E}-\u{262F}]|[\u{2638}-\u{263A}]|\u{2640}|\u{2642}|[\u{2648}-\u{264F}]|[\u{2650}-\u{2653}]|\u{265F}|\u{2660}|\u{2663}|[\u{2665}-\u{2666}]|\u{2668}|\u{267B}|[\u{267E}-\u{267F}]|[\u{2692}-\u{2697}]|\u{2699}|[\u{269B}-\u{269C}]|[\u{26A0}-\u{26A1}]|\u{26A7}|[\u{26AA}-\u{26AB}]|[\u{26B0}-\u{26B1}]|[\u{26BD}-\u{26BE}]|[\u{26C4}-\u{26C5}]|\u{26C8}|[\u{26CE}-\u{26CF}]|\u{26D1}|[\u{26D3}-\u{26D4}]|[\u{26E9}-\u{26EA}]|[\u{26F0}-\u{26F5}]|[\u{26F7}-\u{26FA}]|\u{26FD}|\u{2702}|\u{2705}|[\u{2708}-\u{270D}]|\u{270F}|\u{2712}|\u{2714}|\u{2716}|\u{271D}|\u{2721}|\u{2728}|[\u{2733}-\u{2734}]|\u{2744}|\u{2747}|\u{274C}|\u{274E}|[\u{2753}-\u{2755}]|\u{2757}|[\u{2763}-\u{2764}]|[\u{2795}-\u{2797}]|\u{27A1}|\u{27B0}|\u{27BF}|[\u{2934}-\u{2935}]|[\u{2B05}-\u{2B07}]|[\u{2B1B}-\u{2B1C}]|\u{2B50}|\u{2B55}|\u{3030}|\u{303D}|\u{3297}|\u{3299}|\u{1F004}|\u{1F0CF}|[\u{1F170}-\u{1F171}]|[\u{1F17E}-\u{1F17F}]|\u{1F18E}|[\u{1F191}-\u{1F19A}]|[\u{1F1E6}-\u{1F1FF}]|[\u{1F201}-\u{1F202}]|\u{1F21A}|\u{1F22F}|[\u{1F232}-\u{1F23A}]|[\u{1F250}-\u{1F251}]|[\u{1F300}-\u{1F30F}]|[\u{1F310}-\u{1F31F}]|[\u{1F320}-\u{1F321}]|[\u{1F324}-\u{1F32F}]|[\u{1F330}-\u{1F33F}]|[\u{1F340}-\u{1F34F}]|[\u{1F350}-\u{1F35F}]|[\u{1F360}-\u{1F36F}]|[\u{1F370}-\u{1F37F}]|[\u{1F380}-\u{1F38F}]|[\u{1F390}-\u{1F393}]|[\u{1F396}-\u{1F397}]|[\u{1F399}-\u{1F39B}]|[\u{1F39E}-\u{1F39F}]|[\u{1F3A0}-\u{1F3AF}]|[\u{1F3B0}-\u{1F3BF}]|[\u{1F3C0}-\u{1F3CF}]|[\u{1F3D0}-\u{1F3DF}]|[\u{1F3E0}-\u{1F3EF}]|\u{1F3F0}|[\u{1F3F3}-\u{1F3F5}]|[\u{1F3F7}-\u{1F3FF}]|[\u{1F400}-\u{1F40F}]|[\u{1F410}-\u{1F41F}]|[\u{1F420}-\u{1F42F}]|[\u{1F430}-\u{1F43F}]|[\u{1F440}-\u{1F44F}]|[\u{1F450}-\u{1F45F}]|[\u{1F460}-\u{1F46F}]|[\u{1F470}-\u{1F47F}]|[\u{1F480}-\u{1F48F}]|[\u{1F490}-\u{1F49F}]|[\u{1F4A0}-\u{1F4AF}]|[\u{1F4B0}-\u{1F4BF}]|[\u{1F4C0}-\u{1F4CF}]|[\u{1F4D0}-\u{1F4DF}]|[\u{1F4E0}-\u{1F4EF}]|[\u{1F4F0}-\u{1F4FF}]|[\u{1F500}-\u{1F50F}]|[\u{1F510}-\u{1F51F}]|[\u{1F520}-\u{1F52F}]|[\u{1F530}-\u{1F53D}]|[\u{1F549}-\u{1F54E}]|[\u{1F550}-\u{1F55F}]|[\u{1F560}-\u{1F567}]|\u{1F56F}|\u{1F570}|[\u{1F573}-\u{1F57A}]|\u{1F587}|[\u{1F58A}-\u{1F58D}]|\u{1F590}|[\u{1F595}-\u{1F596}]|[\u{1F5A4}-\u{1F5A5}]|\u{1F5A8}|[\u{1F5B1}-\u{1F5B2}]|\u{1F5BC}|[\u{1F5C2}-\u{1F5C4}]|[\u{1F5D1}-\u{1F5D3}]|[\u{1F5DC}-\u{1F5DE}]|\u{1F5E1}|\u{1F5E3}|\u{1F5E8}|\u{1F5EF}|\u{1F5F3}|[\u{1F5FA}-\u{1F5FF}]|[\u{1F600}-\u{1F60F}]|[\u{1F610}-\u{1F61F}]|[\u{1F620}-\u{1F62F}]|[\u{1F630}-\u{1F63F}]|[\u{1F640}-\u{1F64F}]|[\u{1F650}-\u{1F65F}]|[\u{1F660}-\u{1F66F}]|[\u{1F670}-\u{1F67F}]|[\u{1F680}-\u{1F68F}]|[\u{1F690}-\u{1F69F}]|[\u{1F6A0}-\u{1F6AF}]|[\u{1F6B0}-\u{1F6BF}]|[\u{1F6C0}-\u{1F6C5}]|[\u{1F6CB}-\u{1F6CF}]|[\u{1F6D0}-\u{1F6D2}]|[\u{1F6D5}-\u{1F6D7}]|[\u{1F6DD}-\u{1F6DF}]|[\u{1F6E0}-\u{1F6E5}]|\u{1F6E9}|[\u{1F6EB}-\u{1F6EC}]|\u{1F6F0}|[\u{1F6F3}-\u{1F6FC}]|[\u{1F7E0}-\u{1F7EB}]|\u{1F7F0}|[\u{1F90C}-\u{1F90F}]|[\u{1F910}-\u{1F91F}]|[\u{1F920}-\u{1F92F}]|[\u{1F930}-\u{1F93A}]|[\u{1F93C}-\u{1F93F}]|[\u{1F940}-\u{1F945}]|[\u{1F947}-\u{1F94C}]|[\u{1F94D}-\u{1F94F}]|[\u{1F950}-\u{1F95F}]|[\u{1F960}-\u{1F96F}]|[\u{1F970}-\u{1F97F}]|[\u{1F980}-\u{1F98F}]|[\u{1F990}-\u{1F99F}]|[\u{1F9A0}-\u{1F9AF}]|[\u{1F9B0}-\u{1F9BF}]|[\u{1F9C0}-\u{1F9CF}]|[\u{1F9D0}-\u{1F9DF}]|[\u{1F9E0}-\u{1F9EF}]|[\u{1F9F0}-\u{1F9FF}]|[\u{1FA70}-\u{1FA74}]|[\u{1FA78}-\u{1FA7C}]|[\u{1FA80}-\u{1FA86}]|[\u{1FA90}-\u{1FA9F}]|[\u{1FAA0}-\u{1FAAC}]|[\u{1FAB0}-\u{1FABA}]|[\u{1FAC0}-\u{1FAC5}]|[\u{1FAD0}-\u{1FAD9}]|[\u{1FAE0}-\u{1FAE7}]|[\u{1FAF0}-\u{1FAF6}]"
        let emoji = "[\(unsupport)\(support)]"
        
        let eMod = "[\u{0001F3FB}-\u{0001F3FF}]"
        let variationSelector = "\u{FE0F}"
        let keycap = "\u{20E3}"
        let tags = "[\u{000E0020}-\u{000E007E}]"
        let termTag = "\u{000E007F}"
        let zwj = "\u{200D}"

        // Assuming `ri` and `emoji` are defined elsewhere in your code
        let riSequence = "[\(ri)][\(ri)]"
        let element = "[\(emoji)]([\(eMod)]|\(variationSelector)\(keycap)?|[\(tags)]+\(termTag))?"

        let regexEmoji = "\(riSequence)|\(element)(\(zwj)(\(riSequence)|\(element)))*"
        return regexEmoji
    }
}

public extension NSAttributedString {
    func tui_getPlainString() -> String {
        let plainString = NSMutableString(string: self.string)
        var base = 0
        
        self.enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.length), options: []) { value, range, _ in
            if let attachment = value as? TUIEmojiTextAttachment, let emojiTag = attachment.emojiTag {
                plainString.replaceCharacters(in: NSRange(location: range.location + base, length: range.length), with: emojiTag)
                base += emojiTag.count - 1
            }
        }
        
        return plainString as String
    }
}
