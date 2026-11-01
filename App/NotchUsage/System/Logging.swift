import Foundation
import os

/// Règle de revue : jamais de valeur `sk-ant-…` ni de corps de réponse dans un log.
enum Log {
    static let subsystem = "com.notchusage"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let refresh = Logger(subsystem: subsystem, category: "refresh")
    static let notch = Logger(subsystem: subsystem, category: "notch")
}
