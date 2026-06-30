import Foundation

struct ExtensionRegistrationStatus: Equatable, Sendable {
    enum QueryState: Equatable, Sendable {
        case notChecked
        case present
        case missing
        case error(String)

        var label: String {
            switch self {
            case .notChecked:
                return "not checked"
            case .present:
                return "present"
            case .missing:
                return "missing"
            case let .error(message):
                return "error: \(message)"
            }
        }
    }

    enum EffectiveStatus: Equatable, Sendable {
        case notChecked
        case registered
        case incompleteListing
        case missing
        case error

        var label: String {
            switch self {
            case .notChecked:
                return "not checked"
            case .registered:
                return "registered"
            case .incompleteListing:
                return "incomplete listing"
            case .missing:
                return "missing"
            case .error:
                return "error"
            }
        }
    }

    var displayName: String
    var bundleIdentifier: String
    var familyIdentifier: String
    var familyQueryState: QueryState
    var exactQueryState: QueryState

    var effectiveStatus: EffectiveStatus {
        switch (familyQueryState, exactQueryState) {
        case (.notChecked, .notChecked):
            return .notChecked
        case (.present, _):
            return .registered
        case (.missing, .present):
            return .incompleteListing
        case (.missing, .missing):
            return .missing
        case (.error, .present):
            return .registered
        case (.present, .error):
            return .registered
        case (.error, .missing), (.missing, .error), (.error, .error), (.notChecked, _), (_, .notChecked):
            return .error
        }
    }

    static let previewUnchecked = ExtensionRegistrationStatus(
        displayName: "Preview",
        bundleIdentifier: "com.91wan.MarkLook.Preview",
        familyIdentifier: "com.apple.quicklook.preview",
        familyQueryState: .notChecked,
        exactQueryState: .notChecked
    )

    static let thumbnailUnchecked = ExtensionRegistrationStatus(
        displayName: "Thumbnail",
        bundleIdentifier: "com.91wan.MarkLook.Thumbnail",
        familyIdentifier: "com.apple.quicklook.thumbnail",
        familyQueryState: .notChecked,
        exactQueryState: .notChecked
    )

    static func parse(
        displayName: String,
        bundleIdentifier: String,
        familyIdentifier: String,
        familyOutput: String,
        familyTerminationStatus: Int32?,
        exactOutput: String,
        exactTerminationStatus: Int32?
    ) -> ExtensionRegistrationStatus {
        ExtensionRegistrationStatus(
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            familyIdentifier: familyIdentifier,
            familyQueryState: queryState(
                output: familyOutput,
                terminationStatus: familyTerminationStatus,
                bundleIdentifier: bundleIdentifier
            ),
            exactQueryState: queryState(
                output: exactOutput,
                terminationStatus: exactTerminationStatus,
                bundleIdentifier: bundleIdentifier
            )
        )
    }

    private static func queryState(
        output: String,
        terminationStatus: Int32?,
        bundleIdentifier: String
    ) -> QueryState {
        if output.range(of: bundleIdentifier, options: [.caseInsensitive]) != nil {
            return .present
        }
        guard let terminationStatus else {
            return .error("launch failed")
        }
        guard terminationStatus == 0 else {
            return .error("exit \(terminationStatus)")
        }
        return .missing
    }
}
