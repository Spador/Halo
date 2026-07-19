import Foundation
import Observation

/// A chosen city: name plus coordinates from the geocoding search. The
/// coordinates are the only thing that ever leaves the machine, and only
/// while the weather feature is enabled.
struct WeatherCity: Codable, Hashable {
    var name: String
    var country: String?
    var latitude: Double
    var longitude: Double
}

struct WeatherNow: Equatable {
    var temperatureC: Double
    var code: Int
    var windKmh: Double
}

struct DailyForecast: Identifiable, Equatable {
    var day: Date
    var code: Int
    var highC: Double
    var lowC: Double

    var id: Date { day }
}

/// Weather from Open-Meteo, the keyless open weather API. All requests go
/// through HaloNetwork (gated by the weather flag), fetch only when the
/// card opens and the data is stale — never in the background.
@Observable
final class WeatherService {
    private(set) var city: WeatherCity?
    private(set) var now: WeatherNow?
    private(set) var daily: [DailyForecast] = []
    private(set) var isLoading = false
    private(set) var failed = false

    var usesFahrenheit: Bool {
        didSet { defaults.set(usesFahrenheit, forKey: Keys.fahrenheit) }
    }

    @ObservationIgnored private var lastFetched: Date?
    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let city = "weather.city"
        static let fahrenheit = "weather.usesFahrenheit"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        usesFahrenheit = defaults.bool(forKey: Keys.fahrenheit)
        if let data = defaults.data(forKey: Keys.city),
           let saved = try? JSONDecoder().decode(WeatherCity.self, from: data) {
            city = saved
        }
    }

    func setCity(_ newCity: WeatherCity) {
        city = newCity
        if let data = try? JSONEncoder().encode(newCity) {
            defaults.set(data, forKey: Keys.city)
        }
        now = nil
        daily = []
        lastFetched = nil
        Task { await refresh() }
    }

    /// Called when the card appears; refetches only after 15 minutes.
    func refreshIfStale() {
        guard city != nil else { return }
        if let lastFetched, Date().timeIntervalSince(lastFetched) < 15 * 60 { return }
        Task { await refresh() }
    }

    func refresh() async {
        guard let city, !isLoading else { return }
        isLoading = true
        failed = false
        defer { isLoading = false }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code"),
            URLQueryItem(name: "forecast_days", value: "5"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components.url else { return }

        do {
            let data = try await HaloNetwork.shared.fetch(url, gatedBy: .weather)
            let decoded = try JSONDecoder().decode(ForecastResponse.self, from: data)
            apply(decoded)
            lastFetched = Date()
        } catch {
            failed = now == nil
        }
    }

    static func searchCities(_ query: String) async -> [WeatherCity] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: "8"),
        ]
        guard let url = components.url,
              let data = try? await HaloNetwork.shared.fetch(url, gatedBy: .weather),
              let decoded = try? JSONDecoder().decode(GeocodingResponse.self, from: data)
        else { return [] }
        return (decoded.results ?? []).map {
            WeatherCity(
                name: $0.name,
                country: $0.country,
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }
    }

    // MARK: - Display helpers

    func temperatureText(_ celsius: Double) -> String {
        let value = usesFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }

    /// WMO weather codes to SF Symbols.
    static func symbol(for code: Int) -> String {
        switch code {
        case 0: "sun.max.fill"
        case 1, 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67: "cloud.rain.fill"
        case 71...77: "cloud.snow.fill"
        case 80...82: "cloud.heavyrain.fill"
        case 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    // MARK: - Decoding

    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let wind_speed_10m: Double
        }
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let weather_code: [Int]
        }
        let current: Current
        let daily: Daily
    }

    private struct GeocodingResponse: Decodable {
        struct Result: Decodable {
            let name: String
            let country: String?
            let latitude: Double
            let longitude: Double
        }
        let results: [Result]?
    }

    private func apply(_ response: ForecastResponse) {
        now = WeatherNow(
            temperatureC: response.current.temperature_2m,
            code: response.current.weather_code,
            windKmh: response.current.wind_speed_10m
        )
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        daily = zip(
            response.daily.time.indices, response.daily.time
        ).compactMap { index, dayString in
            guard let day = formatter.date(from: dayString),
                  index < response.daily.temperature_2m_max.count,
                  index < response.daily.temperature_2m_min.count,
                  index < response.daily.weather_code.count
            else { return nil }
            return DailyForecast(
                day: day,
                code: response.daily.weather_code[index],
                highC: response.daily.temperature_2m_max[index],
                lowC: response.daily.temperature_2m_min[index]
            )
        }
    }
}
