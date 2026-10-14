import Foundation
import SQLite3

struct TCCEntry: Identifiable, Hashable, Sendable {
    var id: String { "\(service)|\(client)" }
    let service: String
    let client: String
    let authValue: Int
    let allowed: Bool
}

/// Read-only peek at the user TCC database when Full Disk Access allows it.
enum TCCInventory {
    static func loadUserEntries(limit: Int = 80) -> (entries: [TCCEntry], error: String?) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dbURL = home.appendingPathComponent(
            "Library/Application Support/com.apple.TCC/TCC.db",
            isDirectory: false
        )
        guard FileManager.default.isReadableFile(atPath: dbURL.path) else {
            return ([], L10n.string("privacy.tcc.need_fda"))
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return ([], L10n.string("privacy.tcc.open_failed"))
        }
        defer { sqlite3_close(db) }

        // Prefer modern `auth_value`; fall back to legacy `allowed`.
        let sqlModern = """
        SELECT service, client, auth_value FROM access
        ORDER BY service, client LIMIT \(limit);
        """
        let sqlLegacy = """
        SELECT service, client, allowed FROM access
        ORDER BY service, client LIMIT \(limit);
        """

        if let modern = query(db: db, sql: sqlModern, authIsModern: true) {
            return (modern, nil)
        }
        if let legacy = query(db: db, sql: sqlLegacy, authIsModern: false) {
            return (legacy, nil)
        }
        return ([], L10n.string("privacy.tcc.query_failed"))
    }

    private static func query(db: OpaquePointer, sql: String, authIsModern: Bool) -> [TCCEntry]? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        var rows: [TCCEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let service = String(cString: sqlite3_column_text(statement, 0))
            let client = String(cString: sqlite3_column_text(statement, 1))
            let auth = Int(sqlite3_column_int(statement, 2))
            let allowed = authIsModern ? (auth == 2) : (auth == 1)
            rows.append(TCCEntry(service: service, client: client, authValue: auth, allowed: allowed))
        }
        return rows
    }

    static func friendlyServiceName(_ service: String) -> String {
        let map: [String: String] = [
            "kTCCServiceCamera": "Camera",
            "kTCCServiceMicrophone": "Microphone",
            "kTCCServiceLocation": "Location",
            "kTCCServiceContacts": "Contacts",
            "kTCCServiceCalendar": "Calendar",
            "kTCCServiceReminders": "Reminders",
            "kTCCServicePhotos": "Photos",
            "kTCCServicePhotosAdd": "Photos (add)",
            "kTCCServiceAccessibility": "Accessibility",
            "kTCCServiceSystemPolicyAllFiles": "Full Disk Access",
            "kTCCServiceSystemPolicyDesktopFolder": "Desktop",
            "kTCCServiceSystemPolicyDocumentsFolder": "Documents",
            "kTCCServiceSystemPolicyDownloadsFolder": "Downloads",
            "kTCCServiceAppleEvents": "Automation",
            "kTCCServiceScreenCapture": "Screen Recording",
            "kTCCServiceListenEvent": "Input Monitoring"
        ]
        return map[service] ?? service.replacingOccurrences(of: "kTCCService", with: "")
    }
}
