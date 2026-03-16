import Foundation

/// Retrieves Claude Code OAuth token from macOS Keychain.
/// Uses `security` CLI (same approach as Rust binary) to avoid entitlement issues.
/// Token is held only in memory, never persisted.
public enum CredentialProvider {
    private static var cachedToken: String?
    private static var cacheTime: Date?
    private static let cacheTTL: TimeInterval = 300

    public static func getOAuthToken() -> String? {
        // Return cached token if fresh
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
            return cachedToken // stale fallback
        }

        guard process.terminationStatus == 0 else {
            return cachedToken
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return cachedToken
        }

        let token = extractAccessToken(from: raw)
        if let token {
            cachedToken = token
            cacheTime = Date()
        }
        return token
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
