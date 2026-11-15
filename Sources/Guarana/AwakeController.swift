import Foundation
import IOKit.pwr_mgt
import SwiftUI

/// A duration the user can pick. `minutes == nil` means "until I turn it off".
struct AwakeDuration: Codable, Hashable, Identifiable {
    var minutes: Int?
    var id: String { minutes.map(String.init) ?? "forever" }

    static let forever = AwakeDuration(minutes: nil)
    static let presets: [AwakeDuration] = [15, 30, 60, 120, 240].map { AwakeDuration(minutes: $0) } + [.forever]

    var label: String {
        guard let m = minutes else { return "∞" }
        let h = m / 60, r = m % 60
        switch (h, r) {
        case (0, _): return "\(r)m"
        case (_, 0): return "\(h)h"
        default: return "\(h)h \(r)m"
        }
    }
}

/// Keeps the Mac awake using IOKit power assertions (the same mechanism `caffeinate` uses),
/// optionally also while the lid is closed.
@MainActor
final class AwakeController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var current: AwakeDuration?
    @Published private(set) var endDate: Date?
    @Published var lastError: String?

    @Published var customDurations: [AwakeDuration] { didSet { saveCustom() } }
    @Published var keepDisplayOn: Bool {
        didSet {
            UserDefaults.standard.set(keepDisplayOn, forKey: Keys.display)
            if isActive { reassert() }
        }
    }
    @Published var lidClosedAllowed: Bool {
        didSet {
            UserDefaults.standard.set(lidClosedAllowed, forKey: Keys.lid)
            if isActive { applyLidSetting() }
        }
    }

    private var assertionIDs: [IOPMAssertionID] = []
    private var timer: Timer?
    private var lidSleepDisabledByUs = false
    let lid = LidController()

    private enum Keys {
        static let custom = "customDurations"
        static let display = "keepDisplayOn"
        static let lid = "lidClosedAllowed"
    }

    init() {
        let d = UserDefaults.standard
        customDurations = (d.data(forKey: Keys.custom)).flatMap { try? JSONDecoder().decode([AwakeDuration].self, from: $0) } ?? []
        keepDisplayOn = d.object(forKey: Keys.display) as? Bool ?? true
        lidClosedAllowed = d.bool(forKey: Keys.lid)
        // If a previous run crashed while lid mode was on, put normal sleep back.
        lid.resetIfPossible()
    }

    // MARK: Sessions

    func start(_ duration: AwakeDuration) {
        stop()
        guard createAssertions() else { return }
        isActive = true
        current = duration
        if let m = duration.minutes {
            let end = Date().addingTimeInterval(TimeInterval(m * 60))
            endDate = end
            timer = Timer.scheduledTimer(withTimeInterval: end.timeIntervalSinceNow, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.stop() }
            }
        }
        applyLidSetting()
    }

    func toggle(_ duration: AwakeDuration) {
        if isActive && current == duration { stop() } else { start(duration) }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        releaseAssertions()
        if lidSleepDisabledByUs {
            lid.setSleepDisabled(false)
            lidSleepDisabledByUs = false
        }
        isActive = false
        current = nil
        endDate = nil
    }

    // MARK: Custom times

    func saveCustom(minutes: Int) {
        guard minutes > 0 else { return }
        let d = AwakeDuration(minutes: minutes)
        if !customDurations.contains(d) && !AwakeDuration.presets.contains(d) {
            customDurations.append(d)
            customDurations.sort { ($0.minutes ?? .max) < ($1.minutes ?? .max) }
        }
    }

    func removeCustom(_ d: AwakeDuration) {
        customDurations.removeAll { $0 == d }
    }

    private func saveCustom() {
        if let data = try? JSONEncoder().encode(customDurations) {
            UserDefaults.standard.set(data, forKey: Keys.custom)
        }
    }

    // MARK: Power assertions

    private func createAssertions() -> Bool {
        var types = [kIOPMAssertionTypePreventUserIdleSystemSleep]
        if keepDisplayOn { types.append(kIOPMAssertionTypePreventUserIdleDisplaySleep) }
        for type in types {
            var id: IOPMAssertionID = 0
            let r = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                "Guarana is keeping your Mac awake" as CFString, &id)
            if r == kIOReturnSuccess { assertionIDs.append(id) } else {
                lastError = "Couldn't keep the Mac awake (IOKit error \(r))."
                releaseAssertions()
                return false
            }
        }
        return true
    }

    private func releaseAssertions() {
        assertionIDs.forEach { IOPMAssertionRelease($0) }
        assertionIDs.removeAll()
    }

    private func reassert() {
        releaseAssertions()
        _ = createAssertions()
    }

    // MARK: Lid

    private func applyLidSetting() {
        if lidClosedAllowed && !lidSleepDisabledByUs {
            if lid.setSleepDisabled(true) {
                lidSleepDisabledByUs = true
            } else {
                lastError = "Lid-closed mode needs your admin password."
                lidClosedAllowed = false
            }
        } else if !lidClosedAllowed && lidSleepDisabledByUs {
            lid.setSleepDisabled(false)
            lidSleepDisabledByUs = false
        }
    }
}
