import Foundation

/// Keeping a MacBook awake with the lid closed (without an external display) needs
/// `pmset disablesleep 1`, which requires root. The first time the user turns it on,
/// Guarana asks for an admin password once and installs a tiny sudoers rule that allows
/// exactly these two commands — nothing else:
///
///     /usr/bin/pmset -a disablesleep 1
///     /usr/bin/pmset -a disablesleep 0
///
/// Removing it later: `sudo rm /etc/sudoers.d/guarana` (or the button in the app).
struct LidController {
    static let sudoersPath = "/etc/sudoers.d/guarana"
    private static let pmset = "/usr/bin/pmset"

    var isHelperInstalled: Bool { FileManager.default.fileExists(atPath: Self.sudoersPath) }

    /// Turns lid-closed sleep off (true) or back on (false). Returns false if it couldn't.
    @discardableResult
    func setSleepDisabled(_ disabled: Bool) -> Bool {
        let value = disabled ? "1" : "0"
        if isHelperInstalled, run("/usr/bin/sudo", ["-n", Self.pmset, "-a", "disablesleep", value]) {
            return true
        }
        // Not installed yet (or broken): ask for the password once, install the rule and apply.
        return runAsAdmin(installScript() + " && \(Self.pmset) -a disablesleep \(value)",
                          prompt: "Guarana needs your password once to keep your Mac awake with the lid closed.")
    }

    /// Called at launch: if an earlier run quit unexpectedly with lid mode on, restore normal sleep.
    func resetIfPossible() {
        guard isHelperInstalled else { return }
        _ = run("/usr/bin/sudo", ["-n", Self.pmset, "-a", "disablesleep", "0"])
    }

    /// Asks for the admin password once and installs the rule. Returns true when it's in place.
    func install() -> Bool {
        if isHelperInstalled { return true }
        return runAsAdmin(installScript(),
                          prompt: "Guarana needs your password once to keep your Mac awake with the lid closed.")
    }

    func uninstall() -> Bool {
        runAsAdmin("\(Self.pmset) -a disablesleep 0; /bin/rm -f \(Self.sudoersPath)",
                   prompt: "Guarana wants to remove its lid-closed permission.")
    }

    // MARK: -

    private func installScript() -> String {
        let user = NSUserName().replacingOccurrences(of: "\"", with: "")
        let rule = "\"\(user)\" ALL=(root) NOPASSWD: \(Self.pmset) -a disablesleep 1, \(Self.pmset) -a disablesleep 0"
        // Write to a temp file, validate with visudo, then install with the right owner/mode.
        return """
        tmp=$(/usr/bin/mktemp) && \
        /usr/bin/printf '%s\\n' '\(rule)' > "$tmp" && \
        /usr/sbin/visudo -cf "$tmp" >/dev/null && \
        /usr/bin/install -m 0440 -o root -g wheel "$tmp" \(Self.sudoersPath) && \
        /bin/rm -f "$tmp"
        """
    }

    private func run(_ path: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    private func runAsAdmin(_ shell: String, prompt: String) -> Bool {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        }
        let source = "do shell script \"\(esc(shell))\" with prompt \"\(esc(prompt))\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil
    }
}
