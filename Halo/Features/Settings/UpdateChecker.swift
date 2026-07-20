import AppKit
import Observation

/// The manual update check: one button in Settings that asks GitHub for
/// the newest release tag and compares it to the running version.
/// Strictly opt-in: the button only works while the update check feature
/// is on, and nothing ever checks in the background.
@Observable
final class UpdateChecker {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case failed
    }

    private(set) var state: State = .idle

    private static let releasePage = URL(
        string: "https://github.com/Spador/Halo/releases/latest"
    )!

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0"
    }

    func check() {
        guard state != .checking else { return }
        state = .checking
        Task { [weak self] in
            await self?.performCheck()
        }
    }

    func openReleasePage() {
        NSWorkspace.shared.open(Self.releasePage)
    }

    private func performCheck() async {
        guard let url = URL(
            string: "https://api.github.com/repos/Spador/Halo/releases/latest"
        ) else {
            state = .failed
            return
        }
        do {
            let data = try await HaloNetwork.shared.fetch(url, gatedBy: .updateCheck)
            struct Release: Decodable { let tag_name: String }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let latest = release.tag_name.hasPrefix("v")
                ? String(release.tag_name.dropFirst())
                : release.tag_name
            state = Self.isNewer(latest, than: currentVersion)
                ? .available(version: latest)
                : .upToDate
        } catch {
            state = .failed
        }
    }

    /// Numeric component-wise comparison: 2.10.0 beats 2.9.1.
    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").compactMap { Int($0) }
        let b = current.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
