import Foundation

final class CurrencyRateService {
    static let shared = CurrencyRateService()

    private var rates: [String: Double] = [:]
    private var lastFetch: Date?
    private let cacheKey = "snything.currencyRates"
    private let lastFetchKey = "snything.currencyRatesTimestamp"
    private let session = URLSession.shared
    private let queue = DispatchQueue(label: "snything.currency", qos: .utility)

    private init() {
        loadCachedRates()
        // Kick off a background fetch on init
        Task {
            await fetchLatestRates()
        }
    }

    func rate(from: String, to: String) -> Double? {
        let fromLower = from.lowercased()
        let toLower = to.lowercased()

        // If cache is stale (> 6 hours), trigger background refresh
        if let last = lastFetch, Date().timeIntervalSince(last) > 21600 {
            Task { await fetchLatestRates() }
        }

        if fromLower == toLower { return 1.0 }
        guard !rates.isEmpty else { return nil }

        // frankfurter rates are EUR-based
        guard let fromRate = rates[fromLower], let toRate = rates[toLower] else {
            return nil
        }
        return toRate / fromRate
    }

    func fetchLatestRates() async {
        guard let url = URL(string: "https://api.frankfurter.app/latest") else { return }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            struct Response: Codable {
                let rates: [String: Double]
            }
            let decoded = try JSONDecoder().decode(Response.self, from: data)

            queue.sync {
                self.rates = Dictionary(uniqueKeysWithValues: decoded.rates.map {
                    ($0.key.lowercased(), $0.value)
                })
                // EUR is the base in frankfurter but not listed in rates
                self.rates["eur"] = 1.0
                self.lastFetch = Date()
                self.saveCachedRates()
            }
        } catch {
            print("[Currency] Fetch failed: \(error)")
        }
    }

    private func loadCachedRates() {
        queue.sync {
            if let data = UserDefaults.standard.data(forKey: cacheKey),
               let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
                rates = decoded
            }
            if let ts = UserDefaults.standard.object(forKey: lastFetchKey) as? Date {
                lastFetch = ts
            }
        }
    }

    private func saveCachedRates() {
        if let data = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: lastFetchKey)
        }
    }
}
