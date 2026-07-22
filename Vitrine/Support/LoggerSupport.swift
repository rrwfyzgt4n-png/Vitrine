import OSLog

enum VitrineLog {
    static let access = Logger(subsystem: "com.etienne.Vitrine", category: "Access")
    static let refresh = Logger(subsystem: "com.etienne.Vitrine", category: "Refresh")
    static let catalog = Logger(subsystem: "com.etienne.Vitrine", category: "Catalog")
}
