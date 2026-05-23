import Foundation
import Security
import Observation

@MainActor
@Observable
final class UsageMonitor {
    var sessionPercent: Double = 0   // five_hour utilization
    var weekPercent: Double    = 0   // seven_day utilization
    var sessionResetsAt: Date  = Date()

    init() {
        Task { @MainActor in
            while true {
                await refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private func refresh() async {
        guard let result = try? await fetchUsage() else { return }
        sessionPercent  = result.sessionPercent
        weekPercent     = result.weekPercent
        sessionResetsAt = result.sessionResetsAt
    }

    private struct UsageResult {
        var sessionPercent: Double
        var weekPercent: Double
        var sessionResetsAt: Date
    }

    private func fetchUsage() async throws -> UsageResult {
        guard let token = readOAuthToken() else { throw URLError(.userAuthenticationRequired) }

        let url = URL(string: "https://claude.ai/api/oauth/usage")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json      = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fiveHour  = json["five_hour"]  as? [String: Any],
              let sevenDay  = json["seven_day"]  as? [String: Any]
        else { throw URLError(.cannotParseResponse) }

        let sessionPct = fiveHour["utilization"] as? Double ?? 0
        let weekPct    = sevenDay["utilization"] as? Double ?? 0

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let resetsAt = (fiveHour["resets_at"] as? String).flatMap { fmt.date(from: $0) } ?? Date()

        return UsageResult(sessionPercent: sessionPct, weekPercent: weekPct, sessionResetsAt: resetsAt)
    }

    private func readOAuthToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: "Claude Code-credentials",
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data   = item as? Data,
              let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth  = json["claudeAiOauth"] as? [String: Any],
              let token  = oauth["accessToken"] as? String
        else { return nil }
        return token
    }

    func timeUntilReset() -> String {
        let remaining = sessionResetsAt.timeIntervalSinceNow
        guard remaining > 0 else { return "0m" }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
