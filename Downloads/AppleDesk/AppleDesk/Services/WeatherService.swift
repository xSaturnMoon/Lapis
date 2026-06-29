import SwiftUI
import CoreLocation

nonisolated(unsafe) private var delegateKey: UInt8 = 0

@MainActor
class WeatherService: ObservableObject {
    @Published var weather = WeatherData()

    init() {
        Task { await load() }
    }

    private func load() async {
        do {
            let location = try await requestLocation()
            let city = await reverseGeocode(location)
            await fetchWeather(lat: location.coordinate.latitude,
                               lon: location.coordinate.longitude,
                               city: city)
        } catch {
            await fetchWeather(lat: 44.80, lon: 10.33, city: "Parma")
        }
    }

    private func requestLocation() async throws -> CLLocation {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        // Wait briefly for auth to settle
        try await Task.sleep(nanoseconds: 500_000_000)
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = LocationDelegate(continuation: continuation)
            manager.delegate = delegate
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            manager.requestLocation()
            // Keep delegate alive
            objc_setAssociatedObject(manager, &delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> String {
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            return placemark.locality ?? placemark.administrativeArea ?? "—"
        }
        return "—"
    }

    private func fetchWeather(lat: Double, lon: Double, city: String) async {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            weather = WeatherData(
                temperature: json.current_weather.temperature,
                condition: conditionText(for: json.current_weather.weathercode),
                symbolName: symbolName(for: json.current_weather.weathercode),
                city: city
            )
        } catch {
            weather.city = city
        }
    }

    private func conditionText(for code: Int) -> String {
        switch code {
        case 0: return "Sereno"
        case 1, 2: return "Poco nuvoloso"
        case 3: return "Coperto"
        case 45, 48: return "Nebbia"
        case 51...67: return "Pioggia"
        case 71...77: return "Neve"
        case 80...82: return "Rovesci"
        case 95...99: return "Temporale"
        default: return "—"
        }
    }

    private func moonPhaseSymbol() -> String {
        let date = Date()
        let cycle = 29.530588853
        let knownNewMoon: Date
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 6
        components.hour = 18
        components.minute = 14
        knownNewMoon = Calendar.current.date(from: components) ?? Date()
        
        let secondsSinceNewMoon = date.timeIntervalSince(knownNewMoon)
        let daysSinceNewMoon = secondsSinceNewMoon / (24 * 3600)
        let phaseValue = daysSinceNewMoon.truncatingRemainder(dividingBy: cycle)
        
        if phaseValue < 1.845 || phaseValue >= 27.685 {
            return "moon.phase.new.moon"
        } else if phaseValue < 5.535 {
            return "moon.phase.waxing.crescent"
        } else if phaseValue < 9.225 {
            return "moon.phase.first.quarter"
        } else if phaseValue < 12.915 {
            return "moon.phase.waxing.gibbous"
        } else if phaseValue < 16.605 {
            return "moon.phase.full.moon"
        } else if phaseValue < 20.295 {
            return "moon.phase.waning.gibbous"
        } else if phaseValue < 23.985 {
            return "moon.phase.last.quarter"
        } else {
            return "moon.phase.waning.crescent"
        }
    }

    private func symbolName(for code: Int) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour < 6 || hour > 19

        switch code {
        case 0:
            return isNight ? moonPhaseSymbol() : "sun.max.fill"
        case 1, 2:
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51...67:
            return isNight ? "cloud.moon.rain.fill" : "cloud.rain.fill"
        case 71...77:
            return "cloud.snow.fill"
        case 80...82:
            return isNight ? "cloud.moon.rain.fill" : "cloud.heavyrain.fill"
        case 95...99:
            return isNight ? "cloud.moon.bolt.fill" : "cloud.bolt.rain.fill"
        default:
            return isNight ? "moon.fill" : "cloud"
        }
    }
}

// MARK: - Nonisolated delegate helper
private final class LocationDelegate: NSObject, CLLocationManagerDelegate, Sendable {
    private let continuation: CheckedContinuation<CLLocation, Error>

    init(continuation: CheckedContinuation<CLLocation, Error>) {
        self.continuation = continuation
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.first {
            continuation.resume(returning: loc)
        } else {
            continuation.resume(throwing: NSError(domain: "Location", code: 0))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation.resume(throwing: error)
    }
}

// MARK: - Codable
private struct OpenMeteoResponse: Codable {
    let current_weather: CurrentWeather
}
private struct CurrentWeather: Codable {
    let temperature: Double
    let weathercode: Int
}
