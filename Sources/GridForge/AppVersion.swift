/// AppVersion.swift — reads CFBundleShortVersionString from the main bundle.
/// Used by UpdateChecker and AboutView. No import required; Foundation is
/// available in the app target via GridForgeApp.swift.
import Foundation

enum AppVersion {
    /// Running version string, e.g. "1.0.0". Falls back gracefully.
    static let current: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()
}
