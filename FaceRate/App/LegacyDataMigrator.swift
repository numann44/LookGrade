import Foundation

/// One-time migration of data written by the Flutter build. Flutter's
/// `shared_preferences` plugin stores values in `NSUserDefaults` on iOS
/// with a `flutter.` key prefix — e.g. `facerate.scan_history.v1` becomes
/// `flutter.facerate.scan_history.v1`. As long as the bundle id stays
/// `com.lokman.facerate`, that data is already sitting in this app's own
/// UserDefaults container even on a fresh native install (an app update
/// keeps the container; UserDefaults itself doesn't care which binary
/// wrote it). This copies it to the new (unprefixed) keys the native
/// stores read, once, idempotently.
enum LegacyDataMigrator {
    private static let didRunKey = "facerate.legacy_migration_done.v1"
    private static let legacyPrefix = "flutter."

    static func runOnce(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: didRunKey) else { return }

        migrateString(newKey: ScanHistoryStore.key, defaults: defaults)
        migrateString(newKey: EntitlementsStore.key, defaults: defaults)
        migrateBool(newKey: AppPrefsStore.key, defaults: defaults)

        defaults.set(true, forKey: didRunKey)
    }

    private static func migrateString(newKey: String, defaults: UserDefaults) {
        guard defaults.string(forKey: newKey) == nil,
              let legacyValue = defaults.string(forKey: legacyPrefix + newKey) else { return }
        defaults.set(legacyValue, forKey: newKey)
    }

    private static func migrateBool(newKey: String, defaults: UserDefaults) {
        guard defaults.object(forKey: newKey) == nil,
              defaults.object(forKey: legacyPrefix + newKey) != nil else { return }
        defaults.set(defaults.bool(forKey: legacyPrefix + newKey), forKey: newKey)
    }

    /// Removes the legacy `flutter.`-prefixed keys. Wired into "Delete all
    /// data" so a privacy wipe doesn't leave pre-migration scan history and
    /// entitlement state sitting in UserDefaults.
    static func clearLegacyData(defaults: UserDefaults = .standard) {
        for key in [ScanHistoryStore.key, EntitlementsStore.key, AppPrefsStore.key] {
            defaults.removeObject(forKey: legacyPrefix + key)
        }
    }
}
