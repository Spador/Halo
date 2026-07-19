import SwiftUI

/// The weather card. Only reachable when the weather feature is switched
/// on in Settings; shows which host it talks to, right on the page.
struct WeatherPageView: View {
    let weather: WeatherService
    let settings: SettingsStore

    @State private var isChoosingCity = false
    @State private var search = ""
    @State private var results: [WeatherCity] = []

    var body: some View {
        if weather.city == nil || isChoosingCity {
            cityPicker
        } else {
            forecast
                .onAppear { weather.refreshIfStale() }
        }
    }

    // MARK: - Forecast

    private var forecast: some View {
        VStack(spacing: 10) {
            if let now = weather.now {
                HStack(spacing: 14) {
                    Image(systemName: WeatherService.symbol(for: now.code))
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.white.opacity(0.9))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(weather.temperatureText(now.temperatureC))
                            .font(.system(size: 30, weight: .medium).monospacedDigit())
                            .foregroundStyle(.white)
                        Text(weather.city?.name ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    if let today = weather.daily.first {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("H \(weather.temperatureText(today.highC))  L \(weather.temperatureText(today.lowC))")
                                .font(.system(size: 11).monospacedDigit())
                            Text("wind \(Int(now.windKmh)) km/h")
                                .font(.system(size: 10).monospacedDigit())
                        }
                        .foregroundStyle(.white.opacity(0.55))
                    }
                }

                HStack(spacing: 0) {
                    ForEach(weather.daily) { day in
                        VStack(spacing: 3) {
                            Text(day.day, format: .dateTime.weekday(.abbreviated))
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.45))
                            Image(systemName: WeatherService.symbol(for: day.code))
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(weather.temperatureText(day.highC))
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.8))
                            Text(weather.temperatureText(day.lowC))
                                .font(.system(size: 9).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else if weather.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if weather.failed {
                Text("Could not reach api.open-meteo.com")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            footer
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("Data from Open-Meteo")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
            Button(weather.usesFahrenheit ? "°F" : "°C") {
                weather.usesFahrenheit.toggle()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
            Button("Change city") {
                search = ""
                results = []
                isChoosingCity = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - City picker

    private var cityPicker: some View {
        VStack(spacing: 8) {
            Text("Weather contacts api.open-meteo.com with your chosen city's coordinates. Nothing else leaves this Mac.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Search for a city", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                if weather.city != nil {
                    Button("Cancel") { isChoosingCity = false }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(.white.opacity(0.1)))
            .task(id: search) {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                results = await WeatherService.searchCities(search)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(results, id: \.self) { candidate in
                        Button {
                            weather.setCity(candidate)
                            isChoosingCity = false
                        } label: {
                            HStack {
                                Text(candidate.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.85))
                                if let country = candidate.country {
                                    Text(country)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 10)
    }
}
