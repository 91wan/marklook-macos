import OSLog

enum AppLog {
    static let subsystem = "com.91wan.MarkLook"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let preview = Logger(subsystem: subsystem, category: "preview")
    static let thumbnail = Logger(subsystem: subsystem, category: "thumbnail")
}
