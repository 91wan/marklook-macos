import Foundation

enum UTF8PrefixDecoder {
    static func decode(_ data: Data) -> String? {
        let maxTrimCount = min(3, data.count)

        for trimCount in 0...maxTrimCount {
            let candidate = data.prefix(data.count - trimCount)
            if let source = String(data: candidate, encoding: .utf8) {
                return source
            }
        }

        return nil
    }
}
