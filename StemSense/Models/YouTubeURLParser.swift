import Foundation

enum YouTubeURLParser {
    static func videoID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if isValidID(trimmed) {
            return trimmed
        }

        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: normalized),
              let host = components.host?.lowercased() else { return nil }

        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            return validated(components.path.split(separator: "/").first.map(String.init))
        }

        guard host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }

        if let queryID = components.queryItems?.first(where: { $0.name == "v" })?.value,
           let valid = validated(queryID) {
            return valid
        }

        let parts = components.path.split(separator: "/").map(String.init)
        if let marker = parts.firstIndex(where: { ["embed", "shorts", "live"].contains($0) }),
           parts.indices.contains(marker + 1) {
            return validated(parts[marker + 1])
        }

        return nil
    }

    static func videoID(from url: URL) -> String? {
        if url.scheme?.lowercased() == "stemsense" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let value = components?.queryItems?.first(where: { $0.name == "v" })?.value {
                return validated(value)
            }
            return validated(url.host)
        }
        return videoID(from: url.absoluteString)
    }

    private static func validated(_ candidate: String?) -> String? {
        guard let candidate, isValidID(candidate) else { return nil }
        return candidate
    }

    private static func isValidID(_ candidate: String) -> Bool {
        candidate.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil
    }
}
