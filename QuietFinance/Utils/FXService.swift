import Foundation

enum FXService {
    struct Response: Decodable {
        let rates: [String: Double]
    }

    enum FXError: LocalizedError {
        case badURL
        case badResponse
        case serverError(Int)
        case missingRate(String)

        var errorDescription: String? {
            switch self {
            case .badURL: return "Bad URL."
            case .badResponse: return "Server returned unexpected data."
            case .serverError(let code): return "Rate server error (\(code)). Try again shortly."
            case .missingRate(let code): return "\(code) rate missing in response."
            }
        }
    }

    /// Fetch rates for several currencies in one request, expressed as units
    /// of each currency per 1 USD (frankfurter `from=USD` semantics). Returns
    /// whatever pairs the server provides — callers treat absent keys as
    /// "enter manually". USD itself is never requested.
    ///
    /// Retries transient failures (transport errors, 5xx, 429) up to three
    /// attempts with short backoff; 4xx client errors fail immediately.
    static func fetchRates(for currencies: [Currency], on date: Date? = nil) async throws -> [String: Double] {
        let codes = Array(Set(currencies.map(\.rawValue)).subtracting(["USD"])).sorted()
        guard !codes.isEmpty else { return [:] }

        let path: String
        if let date {
            let fmt = DateFormatter()
            fmt.calendar = Calendar(identifier: .iso8601)
            fmt.timeZone = TimeZone(identifier: "UTC")
            fmt.dateFormat = "yyyy-MM-dd"
            path = fmt.string(from: date)
        } else {
            path = "latest"
        }
        guard let url = URL(string: "https://api.frankfurter.app/\(path)?from=USD&to=\(codes.joined(separator: ","))") else {
            throw FXError.badURL
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8

        let backoffs: [UInt64] = [0, 500_000_000, 1_500_000_000]  // 0s, 0.5s, 1.5s
        var lastError: Error = FXError.badResponse
        for delay in backoffs {
            if delay > 0 { try await Task.sleep(nanoseconds: delay) }
            try Task.checkCancellation()
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw FXError.badResponse }
                switch http.statusCode {
                case 200..<300:
                    let decoded = try JSONDecoder().decode(Response.self, from: data)
                    return decoded.rates
                case 429, 500...:
                    lastError = FXError.serverError(http.statusCode)
                    continue  // transient — retry
                default:
                    throw FXError.serverError(http.statusCode)
                }
            } catch let urlError as URLError {
                if urlError.code == .cancelled { throw urlError }
                lastError = urlError
                continue  // transport hiccup — retry
            }
        }
        throw lastError
    }

    static func fetchUSDtoINR(on date: Date? = nil) async throws -> Double {
        let rates = try await fetchRates(for: [.INR], on: date)
        guard let inr = rates["INR"] else { throw FXError.missingRate("INR") }
        return inr
    }
}
