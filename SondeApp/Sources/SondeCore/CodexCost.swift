import Foundation

/// Reads Codex session cost from ~/.codex/sessions/ JSONL files.
/// Mirrors the logic from the Rust codex_cost module.
public actor CodexCostReader {
    private var cachedCost: Double?
    private var lastRead: Date?
    private let cacheTTL: TimeInterval = 30

    public init() {}

    public func getSessionCost() async -> Double? {
        if let cached = cachedCost,
           let lastRead,
           Date().timeIntervalSince(lastRead) < cacheTTL
        {
            return cached
        }

        let cost = readLatestSessionCost()
        cachedCost = cost
        lastRead = Date()
        return cost
    }

    private func readLatestSessionCost() -> Double? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sessionsDir = home.appendingPathComponent(".codex/sessions")

        guard FileManager.default.fileExists(atPath: sessionsDir.path) else {
            return nil
        }

        guard let latestFile = latestSession(in: sessionsDir) else {
            return nil
        }

        return calculateSessionCost(path: latestFile)
    }

    /// Find the most recently modified .jsonl file, searching subdirectories.
    private func latestSession(in dir: URL) -> URL? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var best: (url: URL, date: Date)?

        for url in contents {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])

            if values?.isDirectory == true {
                if let sub = latestSession(in: url),
                   let subValues = try? sub.resourceValues(forKeys: [.contentModificationDateKey]),
                   let subDate = subValues.contentModificationDate
                {
                    if best == nil || subDate > best!.date {
                        best = (sub, subDate)
                    }
                }
                continue
            }

            guard url.pathExtension == "jsonl" else { continue }

            if let modDate = values?.contentModificationDate {
                if best == nil || modDate > best!.date {
                    best = (url, modDate)
                }
            }
        }

        return best?.url
    }

    /// Calculate total cost from a Codex JSONL session file.
    private func calculateSessionCost(path: URL) -> Double? {
        guard let content = try? String(contentsOf: path, encoding: .utf8) else {
            return nil
        }

        var model = "gpt-5"
        var prevInput: UInt64 = 0
        var prevOutput: UInt64 = 0
        var totalCost = 0.0

        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            guard let eventType = obj["type"] as? String else { continue }

            if eventType == "turn_context" {
                if let m = obj["model"] as? String {
                    model = m
                }
            } else if eventType == "event_msg" {
                guard let payload = obj["payload"] as? [String: Any],
                      payload["type"] as? String == "token_count"
                else { continue }

                let currInput = (payload["input_tokens"] as? UInt64)
                    ?? (payload["input_tokens"] as? Int).map { UInt64($0) }
                    ?? 0
                let currOutput = (payload["output_tokens"] as? UInt64)
                    ?? (payload["output_tokens"] as? Int).map { UInt64($0) }
                    ?? 0

                let deltaInput = currInput > prevInput ? currInput - prevInput : 0
                let deltaOutput = currOutput > prevOutput ? currOutput - prevOutput : 0

                let (inputPrice, outputPrice) = pricePerMillion(model: model)
                totalCost += Double(deltaInput) / 1_000_000.0 * inputPrice
                totalCost += Double(deltaOutput) / 1_000_000.0 * outputPrice

                prevInput = currInput
                prevOutput = currOutput
            }
        }

        return totalCost > 0.0 ? totalCost : nil
    }

    /// Simple pricing table for Codex models (per 1M tokens).
    private func pricePerMillion(model: String) -> (input: Double, output: Double) {
        if model.contains("gpt-4o") { return (2.50, 10.00) }
        if model.contains("gpt-4") { return (10.00, 30.00) }
        if model.contains("gpt-5") { return (2.50, 10.00) }
        if model.contains("o3") { return (2.00, 8.00) }
        if model.contains("o4-mini") { return (1.10, 4.40) }
        return (2.50, 10.00) // default to gpt-5 pricing
    }
}
