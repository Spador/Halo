import Foundation
import os

extension Logger {
    /// Every outbound request logs here. `log show --predicate
    /// 'subsystem == "com.spador.Halo"'` shows exactly who was contacted.
    static let network = Logger(subsystem: "com.spador.Halo", category: "network")
}

enum NetworkError: Error {
    case featureDisabled
    case hostNotAllowed
    case badResponse
}

/// THE only place Halo touches the network.
///
/// The privacy model is enforced here rather than promised elsewhere:
/// - Every request names the feature flag that justifies it, and the
///   request is refused when that flag is off. Off means off.
/// - Only allowlisted hosts can be contacted; a stray URL anywhere else
///   in the codebase cannot leave the machine through this layer, and no
///   other layer exists.
/// - The session is ephemeral: no cookies, no persistent cache, nothing
///   written to disk.
/// - Every contact is logged, so the claim is checkable from outside.
final class HaloNetwork {
    static let shared = HaloNetwork()

    private let session: URLSession

    private static let allowedHosts: Set<String> = [
        "api.open-meteo.com",           // weather
        "geocoding-api.open-meteo.com", // weather city search
    ]

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.httpAdditionalHeaders = ["User-Agent": "Halo"]
        session = URLSession(configuration: configuration)
    }

    func fetch(_ url: URL, gatedBy feature: FeatureID) async throws -> Data {
        guard SettingsStore.shared.isEnabled(feature) else {
            throw NetworkError.featureDisabled
        }
        guard let host = url.host(), Self.allowedHosts.contains(host) else {
            throw NetworkError.hostNotAllowed
        }
        Logger.network.notice("GET \(host, privacy: .public) for \(feature.rawValue, privacy: .public)")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NetworkError.badResponse
        }
        return data
    }
}
