import Foundation
import os.log

private let logger = Logger(subsystem: "dev.sonde.app", category: "CredentialProvider")

/// Retrieves the Claude Code OAuth token from the macOS Keychain.
///
/// SECURITY:
/// - The token is fetched on every request via `/usr/bin/security` and
///   returned by value to the caller. It is **not** cached in process memory.
/// - The previous 5-minute heap cache (`cachedToken` + `cacheTime`) was
///   removed because it created a long-lived attack window where a crash
///   dump, swap file, or another process scraping the heap could recover
///   the token. The keychain itself is the cache.
/// - On macOS the keychain ACL pops a one-time consent dialog the first
///   time `security` accesses the credential; subsequent calls in the same
///   session do not. Perceived cost of removing the in-process cache is
///   sub-millisecond per request.
/// - The token never touches disk, log files, stdout, or stderr.
public enum CredentialProvider {
    private static let lock = NSLock()

    public static func getOAuthToken() -> String? {
        #if os(macOS)
        lock.lock()
        defer { lock.unlock() }

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
            return nil
        }

        guard process.terminationStatus == 0 else {
            logger.warning("Keychain lookup failed (status \(process.terminationStatus)) — credential may not exist")
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            logger.warning("Keychain returned empty data")
            return nil
        }

        return extractAccessToken(from: raw)
        #else
        return nil
        #endif
    }

    /// No-op kept for API compatibility with the previous in-process cache.
    /// The token is now fetched fresh on every call; there is nothing to invalidate.
    public static func invalidateCachedToken() {
        // Intentionally empty. See SECURITY note at the top of this file.
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
