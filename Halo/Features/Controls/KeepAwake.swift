import IOKit.pwr_mgt
import Observation

/// Keeps the Mac (display included) awake while active, via a power
/// management assertion — the public API behind every caffeine-style
/// utility. macOS ties the assertion to the process, so it can never
/// outlive Halo: quitting or crashing always returns normal sleep.
@Observable
final class KeepAwake {
    private(set) var isActive = false

    @ObservationIgnored private var assertionID: IOPMAssertionID = 0

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        if active {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Halo keep awake toggle" as CFString,
                &assertionID
            )
            isActive = result == kIOReturnSuccess
        } else {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
            isActive = false
        }
    }
}
