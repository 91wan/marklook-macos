import Foundation

struct Version: Equatable, Sendable {
    let marketingVersion: String
    let buildNumber: String

    static let current = Version(bundle: .main)

    init(marketingVersion: String, buildNumber: String) {
        self.marketingVersion = marketingVersion
        self.buildNumber = buildNumber
    }

    init(bundle: Bundle) {
        marketingVersion = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
        buildNumber = bundle.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "unknown"
    }
}
