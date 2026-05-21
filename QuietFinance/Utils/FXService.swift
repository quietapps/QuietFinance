import Foundation

enum FXService {
    struct Response: Decodable {
        let rates: [String: Double]
    }

    enum FXError: LocalizedError {
        case badURL
        case badResponse
        case missingRate

        var errorDescription: String? {
            switch self {
            case .badURL: return "Bad URL."
            case .badResponse: return "Server returned unexpected data."
            case .missingRate: return "INR rate missing in response."
            }
        }
    }

    static func fetchUSDtoINR(on date: Date? = nil) async throws -> Double {
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
        guard let url = URL(string: "https://api.frankfurter.app/\(path)?from=USD&to=INR") else {
            throw FXError.badURL
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FXError.badResponse
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let inr = decoded.rates["INR"] else { throw FXError.missingRate }
        return inr
    }
}
