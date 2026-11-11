import Foundation
import CryptoKit
import Security

struct JWTMetadata {
    let issuedAt: Date?
    let expiresAt: Date?
    let isExpired: Bool
}

@Observable
final class DevToolkitService {

    // MARK: - Data: JSON Tools
    func formatJSON(_ input: String, indentStyle: String = "2") -> (result: String?, error: String?) {
        guard let data = input.data(using: .utf8) else {
            return (nil, "Invalid UTF-8 input")
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let formatted = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            guard var str = String(data: formatted, encoding: .utf8) else {
                return (nil, "Could not convert JSON to string")
            }
            switch indentStyle {
            case "4":
                str = str.replacingOccurrences(of: "\n  ", with: "\n    ")
            case "tab":
                str = str.replacingOccurrences(of: "\n  ", with: "\n\t")
            default:
                break
            }
            return (str, nil)
        } catch {
            return (nil, parseJSONError(error, in: input))
        }
    }

    func minifyJSON(_ input: String) -> (result: String?, error: String?) {
        guard let data = input.data(using: .utf8) else {
            return (nil, "Invalid UTF-8 input")
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let minified = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            guard let str = String(data: minified, encoding: .utf8) else {
                return (nil, "Could not convert JSON to string")
            }
            return (str, nil)
        } catch {
            return (nil, parseJSONError(error, in: input))
        }
    }

    func validateJSON(_ input: String) -> (isValid: Bool, message: String) {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (false, "Input is empty")
        }
        guard let data = input.data(using: .utf8) else {
            return (false, "Invalid UTF-8 encoding")
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return (true, "Valid JSON")
        } catch {
            return (false, parseJSONError(error, in: input))
        }
    }

    private func parseJSONError(_ error: Error, in input: String) -> String {
        let ns = error as NSError
        if let desc = ns.userInfo["NSDebugDescription"] as? String {
            return desc
        }
        return error.localizedDescription
    }

    // MARK: - Data: Base64
    func base64Encode(_ input: String, urlSafe: Bool = false) -> String {
        let encoded = Data(input.utf8).base64EncodedString()
        guard urlSafe else { return encoded }
        return encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func base64Decode(_ input: String, urlSafe: Bool = false) -> (result: String?, error: String?) {
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlSafe || cleaned.contains("-") || cleaned.contains("_") {
            cleaned = cleaned
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
        }
        let remainder = cleaned.count % 4
        if remainder > 0 {
            cleaned.append(String(repeating: "=", count: 4 - remainder))
        }
        guard let data = Data(base64Encoded: cleaned) else {
            return (nil, "Invalid Base64 string")
        }
        if let string = String(data: data, encoding: .utf8) {
            return (string, nil)
        }
        // If binary, return hex representation
        let hex = data.map { String(format: "%02X", $0) }.joined()
        return ("Binary (Hex): \(hex)", nil)
    }

    // MARK: - Data: URL Encode / Decode
    func urlEncode(_ input: String, keepURLReserved: Bool = false) -> String {
        let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        let reserved = ":/?#[]@!$&'()*+,;="
        let allowed = CharacterSet(charactersIn: keepURLReserved ? unreserved + reserved : unreserved)
        return input.addingPercentEncoding(withAllowedCharacters: allowed) ?? input
    }

    func urlDecode(_ input: String) -> String {
        input.removingPercentEncoding ?? input
    }

    func parseQueryParameters(_ input: String) -> [(name: String, value: String)] {
        var query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let questionIndex = query.firstIndex(of: "?") {
            query = String(query[query.index(after: questionIndex)...])
        }
        if let fragmentIndex = query.firstIndex(of: "#") {
            query = String(query[..<fragmentIndex])
        }
        guard !query.isEmpty else { return [] }

        return query.split(separator: "&").compactMap { pair in
            let pieces = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let rawName = pieces.first, !rawName.isEmpty else { return nil }
            let rawValue = pieces.count > 1 ? String(pieces[1]) : ""
            let name = urlDecodeForm(rawName.replacingOccurrences(of: "+", with: " "))
            let value = urlDecodeForm(rawValue.replacingOccurrences(of: "+", with: " "))
            return (name, value)
        }
    }

    private func urlDecodeForm(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }

    // MARK: - Data: JWT Decoder
    func decodeJWT(_ token: String) -> (header: String?, payload: String?, error: String?) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: ".")
        guard parts.count >= 2 else {
            return (nil, nil, "Invalid JWT: Expected at least 2 dot-separated parts (Header.Payload).")
        }

        func decodeBase64URL(_ str: String) -> (json: String?, error: String?) {
            var base64 = str.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let pad = 4 - (base64.count % 4)
            if pad < 4 {
                base64.append(String(repeating: "=", count: pad))
            }
            guard let data = Data(base64Encoded: base64) else {
                return (nil, "Invalid Base64URL segment")
            }
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let prettyStr = String(data: prettyData, encoding: .utf8) {
                return (prettyStr, nil)
            }
            if let plain = String(data: data, encoding: .utf8) {
                return (plain, nil)
            }
            return (nil, "Could not decode segment as UTF-8")
        }

        let headerRes = decodeBase64URL(parts[0])
        guard let headerStr = headerRes.json else {
            return (nil, nil, "Header Decode Error: \(headerRes.error ?? "unknown")")
        }

        let payloadRes = decodeBase64URL(parts[1])
        guard let payloadStr = payloadRes.json else {
            return (nil, nil, "Payload Decode Error: \(payloadRes.error ?? "unknown")")
        }

        return (headerStr, payloadStr, nil)
    }

    func jwtMetadata(from payloadJSON: String) -> JWTMetadata {
        guard let data = payloadJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return JWTMetadata(issuedAt: nil, expiresAt: nil, isExpired: false)
        }

        func date(for key: String) -> Date? {
            guard let number = object[key] as? NSNumber else { return nil }
            return Date(timeIntervalSince1970: number.doubleValue)
        }

        let expiresAt = date(for: "exp")
        return JWTMetadata(
            issuedAt: date(for: "iat"),
            expiresAt: expiresAt,
            isExpired: expiresAt.map { $0 < Date() } ?? false
        )
    }

    // MARK: - Generators
    func generateUUIDv4() -> String {
        UUID().uuidString.uppercased()
    }

    func generateUUIDv7() -> String {
        // RFC 9562 UUIDv7
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)
        var bytes = [UInt8](repeating: 0, count: 16)

        // 48-bit timestamp
        bytes[0] = UInt8((ms >> 40) & 0xFF)
        bytes[1] = UInt8((ms >> 32) & 0xFF)
        bytes[2] = UInt8((ms >> 24) & 0xFF)
        bytes[3] = UInt8((ms >> 16) & 0xFF)
        bytes[4] = UInt8((ms >> 8) & 0xFF)
        bytes[5] = UInt8(ms & 0xFF)

        // Random bytes
        _ = SecRandomCopyBytes(kSecRandomDefault, 10, &bytes[6])

        // Version 7 in high 4 bits of byte 6 (0x70)
        bytes[6] = (bytes[6] & 0x0F) | 0x70

        // Variant 10xx in high 2 bits of byte 8 (0x80)
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return String(
            format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
    }

    func generateULID() -> String {
        let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)

        // 10 characters for the 48-bit timestamp (2 leading padding bits).
        var result = ""
        for index in 0..<10 {
            let shift = 45 - index * 5
            let value: UInt64
            if shift >= 0 {
                value = (ms >> UInt64(shift)) & 0x1F
            } else {
                value = 0
            }
            result.append(alphabet[Int(value)])
        }

        // 80 bits of randomness encoded as 16 Crockford Base32 characters.
        var randomBytes = [UInt8](repeating: 0, count: 10)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        var buffer: UInt32 = 0
        var bitCount = 0
        for byte in randomBytes {
            buffer = (buffer << 8) | UInt32(byte)
            bitCount += 8
            while bitCount >= 5 {
                let value = (buffer >> UInt32(bitCount - 5)) & 0x1F
                result.append(alphabet[Int(value)])
                bitCount -= 5
            }
        }

        return result
    }

    func generateRandomString(
        length: Int = 16,
        includeSymbols: Bool = false,
        includeDigits: Bool = true,
        excludeAmbiguous: Bool = false
    ) -> String {
        var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        if includeDigits {
            letters += "0123456789"
        }
        if excludeAmbiguous {
            for character in ["O", "0", "I", "1"] {
                letters = letters.replacingOccurrences(of: character, with: "")
            }
        }
        let symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?"
        let charset = Array(includeSymbols ? (letters + symbols) : letters)
        guard length > 0, !charset.isEmpty else { return "" }

        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)

        var result = ""
        for byte in bytes {
            let idx = Int(byte) % charset.count
            result.append(charset[idx])
        }
        return result
    }

    func generateSecureToken(byteCount: Int = 32, format: String = "hex") -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        let data = Data(bytes)

        if format == "base64" {
            return data.base64EncodedString()
        } else if format == "urlSafe" {
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        }
        // default hex
        return bytes.map { String(format: "%02X", $0) }.joined()
    }

    // MARK: - Text Utilities
    func convertCase(_ input: String, to targetCase: String) -> String {
        // Split words by transitions, underscores, hyphens, and whitespace
        let words = extractWords(from: input)
        guard !words.isEmpty else { return input }

        switch targetCase {
        case "camelCase":
            return words.enumerated().map { i, w in
                i == 0 ? w.lowercased() : w.prefix(1).uppercased() + w.dropFirst().lowercased()
            }.joined()
        case "PascalCase":
            return words.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
        case "snake_case":
            return words.map { $0.lowercased() }.joined(separator: "_")
        case "kebab-case":
            return words.map { $0.lowercased() }.joined(separator: "-")
        case "CONSTANT_CASE":
            return words.map { $0.uppercased() }.joined(separator: "_")
        case "Title Case":
            return words.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
        case "lowercase":
            return input.lowercased()
        case "UPPERCASE":
            return input.uppercased()
        default:
            return input
        }
    }

    private func extractWords(from text: String) -> [String] {
        var words: [String] = []
        var current = ""

        for char in text {
            if char.isWhitespace || char == "_" || char == "-" {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
            } else if char.isUppercase && !current.isEmpty && current.last?.isLowercase == true {
                words.append(current)
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words
    }

    func calculateTextStats(_ text: String) -> (chars: Int, charsNoSpaces: Int, words: Int, lines: Int, bytes: Int) {
        let chars = text.count
        let charsNoSpaces = text.filter { !$0.isWhitespace }.count
        let words = text.split { $0.isWhitespace }.count
        let lines = text.isEmpty ? 0 : text.components(separatedBy: .newlines).count
        let bytes = text.utf8.count
        return (chars, charsNoSpaces, words, lines, bytes)
    }

    func testRegex(pattern: String, text: String, isCaseInsensitive: Bool = false) -> (matchCount: Int, matches: [String], error: String?) {
        guard !pattern.isEmpty else {
            return (0, [], nil)
        }

        var options: NSRegularExpression.Options = []
        if isCaseInsensitive { options.insert(.caseInsensitive) }

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let results = regex.matches(in: text, options: [], range: nsRange)

            let matchedStrings = results.compactMap { res -> String? in
                guard let range = Range(res.range, in: text) else { return nil }
                return String(text[range])
            }
            return (results.count, matchedStrings, nil)
        } catch {
            return (0, [], error.localizedDescription)
        }
    }

    func replaceRegex(
        pattern: String,
        replacement: String,
        text: String,
        isCaseInsensitive: Bool = false
    ) -> (result: String?, error: String?) {
        guard !pattern.isEmpty else {
            return (nil, "Pattern is empty")
        }

        var options: NSRegularExpression.Options = []
        if isCaseInsensitive { options.insert(.caseInsensitive) }

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let output = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: nsRange,
                withTemplate: replacement
            )
            return (output, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    func transformLines(_ input: String, operation: String) -> String {
        let lines = input.components(separatedBy: .newlines)
        switch operation {
        case "Trim":
            return input.trimmingCharacters(in: .whitespacesAndNewlines)
        case "Remove Empty Lines":
            return lines
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: "\n")
        case "Sort A-Z":
            return lines
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .joined(separator: "\n")
        case "Sort Z-A":
            return lines
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending }
                .joined(separator: "\n")
        case "Remove Duplicates":
            var seen = Set<String>()
            return lines
                .filter { seen.insert($0).inserted }
                .joined(separator: "\n")
        case "Reverse":
            return String(input.reversed())
        case "UPPERCASE":
            return input.uppercased()
        case "lowercase":
            return input.lowercased()
        default:
            return input
        }
    }

    func escapeText(_ input: String, type: String) -> String {
        switch type {
        case "JSON":
            let escaped = input
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            return "\"\(escaped)\""
        case "HTML":
            return input
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&#39;")
        case "URL":
            return input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
        default:
            return input
        }
    }

    func unescapeText(_ input: String, type: String) -> String {
        switch type {
        case "JSON":
            var str = input
            if str.hasPrefix("\"") && str.hasSuffix("\"") && str.count >= 2 {
                str = String(str.dropFirst().dropLast())
            }
            return str
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\r", with: "\r")
                .replacingOccurrences(of: "\\t", with: "\t")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        case "HTML":
            return input
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&amp;", with: "&")
        case "URL":
            return input.removingPercentEncoding ?? input
        default:
            return input
        }
    }

    // MARK: - Hashing & HMAC
    func hashSHA1(_ input: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func hashSHA256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func hashSHA512(_ input: String) -> String {
        let digest = SHA512.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func hashMD5(_ input: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func hmacSHA256(_ input: String, secretKey: String) -> String {
        let key = SymmetricKey(data: Data(secretKey.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(input.utf8), using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }
}
