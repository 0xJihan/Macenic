import Foundation
import IOKit.pwr_mgt

@Observable
final class KeepAwakeService {
    var isActive = false

    @ObservationIgnored private var assertionID: IOPMAssertionID = 0

    func toggle() {
        isActive ? deactivate() : activate()
    }

    private func activate() {
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Macenic Keep Awake" as CFString,
            &assertionID
        )
        isActive = result == kIOReturnSuccess
    }

    private func deactivate() {
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }
}
