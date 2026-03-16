import Foundation
import Security

/// Retrieves Claude Code OAuth token from macOS Keychain.
/// Token is held only in memory, never persisted.
public enum CredentialProvider {
    public static func getOAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let jsonStr = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return extractAccessToken(from: jsonStr)
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
