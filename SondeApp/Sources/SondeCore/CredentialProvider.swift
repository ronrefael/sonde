import Foundation
import os.log

private let logger = Logger(subsystem: "dev.sonde.app", category: "CredentialProvider")

/// Retrieves Claude Code OAuth token from macOS Keychain.
/// Uses `security` CLI (same approach as Rust binary) to avoid entitlement issues.
/// Token is held only in memory, never persisted.
public enum CredentialProvider {
    private static let lock = NSLock()
    private static var cachedToken: String?
    private static var cacheTime: Date?
    private static let cacheTTL: TimeInterval = 300

    public static func getOAuthToken() -> String? {
        #if os(macOS)
        lock.lock()
        defer { lock.unlock() }

        if let token = cachedToken,
           let time = cacheTime,
           Date().timeIntervalSince(time) < cacheTTL
        {
            return token
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.warning("Keychain process failed to launch: \(error.localizedDescription)")
            return cachedToken
        }

        guard process.terminationStatus == 0 else {
            logger.warning("Keychain lookup failed (status \(process.terminationStatus)) — credential may not exist")
            return cachedToken
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            logger.warning("Keychain returned empty data")
            return cachedToken
        }

        let token = extractAccessToken(from: raw)
        if let token {
            cachedToken = token
            cacheTime = Date()
            logger.info("OAuth token refreshed from Keychain")
        } else {
            logger.warning("Failed to extract accessToken from Keychain JSON")
        }
        return token
        #else
        return nil
        #endif
    }

    /// Invalidate the cached token (e.g. after a 401 response).
    public static func invalidateCachedToken() {
        lock.lock()
        defer { lock.unlock() }
        cachedToken = nil
        cacheTime = nil
        logger.info("Cached OAuth token invalidated")
    }

    private static func extractAccessToken(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else {
            return nil
        }
        return token
    }
}
