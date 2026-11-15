import GuaranaArt
import ServiceManagement
import SwiftUI

// MARK: Theme

enum Theme {
    static let red = Color(cgColor: Palette.red)
    static let redDeep = Color(cgColor: Palette.redDeep)
    static let blush = Color(cgColor: Palette.blush)
    static let leaf = Color(cgColor: Palette.leaf)
    static let sun = Color(cgColor: Palette.sun)
    static let ink = Color(cgColor: Palette.ink)
    static let muted = Color(red: 0.47, green: 0.44, blue: 0.44)
    static let chip = Color(red: 0.97, green: 0.96, blue: 0.95)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: Popover

struct PopoverView: View {
    @EnvironmentObject var awake: AwakeController
    @State private var showEditor: Bool

    init(showEditor: Bool = false) { _showEditor = State(initialValue: showEditor) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header()

            Block(title: "Keep awake for") {
                ChipGrid(items: AwakeDuration.presets)
            }

            Block(title: "Your times") {
                if !awake.customDurations.isEmpty {
                    ChipGrid(items: awake.customDurations, deletable: true)
                }
                if showEditor {
                    CustomTimeEditor(isPresented: $showEditor)
                        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                } else {
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { showEditor = true } } label: {
                        Label("Add a custom time", systemImage: "plus")
                            .font(Theme.font(13))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .overlay(Capsule().strokeBorder(Theme.red.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])))
                            .foregroundStyle(Theme.red)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(Squishy())
                }
            }

            VStack(spacing: 10) {
                OptionRow(title: "Lid closed", subtitle: "Stay awake with the lid shut",
                          value: Binding(get: { awake.lidClosedAllowed }, set: setLid))
                OptionRow(title: "Screen on", subtitle: "Don't let the display dim",
                          value: $awake.keepDisplayOn)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.chip))

            if let error = awake.lastError {
                Text(error).font(Theme.font(11, .medium)).foregroundStyle(Theme.redDeep)
                    .onTapGesture { awake.lastError = nil }
            }

            Footer()
        }
        .padding(18)
        .frame(width: 304)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func setLid(_ on: Bool) {
        awake.lastError = nil
        if on && !awake.lid.isHelperInstalled {
            guard awake.lid.install() else {
                awake.lastError = "Lid-closed mode needs your admin password once."
                return
            }
        }
        awake.lidClosedAllowed = on
    }
}

// MARK: Header

private struct Header: View {
    @EnvironmentObject var awake: AwakeController
    @State private var blink = false

    var body: some View {
        HStack(spacing: 12) {
            FruitView(openness: awake.isActive ? (blink ? 0.05 : 1) : 0)
                .frame(width: 52, height: 52)
                .animation(.spring(response: 0.28, dampingFraction: 0.6), value: awake.isActive)
                .animation(.easeInOut(duration: 0.09), value: blink)
                .onReceive(Timer.publish(every: 3.6, on: .main, in: .common).autoconnect()) { _ in
                    guard awake.isActive else { return }
                    blink = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { blink = false }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(awake.isActive ? "Wide awake!" : "Guarana")
                    .font(Theme.font(20, .bold))
                    .foregroundStyle(Theme.ink)
                StatusLine()
            }
            Spacer(minLength: 0)
            if awake.isActive {
                Button { withAnimation { awake.stop() } } label: {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.ink))
                        .foregroundStyle(.white)
                }
                .buttonStyle(Squishy())
                .help("Let it sleep")
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

private struct StatusLine: View {
    @EnvironmentObject var awake: AwakeController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            Text(text(now: ctx.date))
                .font(Theme.font(12.5, .medium))
                .foregroundStyle(awake.isActive ? Theme.red : Theme.muted)
                .monospacedDigit()
        }
    }

    private func text(now: Date) -> String {
        guard awake.isActive else { return "Sleepy… pick a time below" }
        guard let end = awake.endDate else { return "Until you say so" }
        let s = max(0, Int(end.timeIntervalSince(now)))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d left", h, m, sec) : String(format: "%d:%02d left", m, sec)
    }
}

// MARK: Chips

private struct ChipGrid: View {
    @EnvironmentObject var awake: AwakeController
    let items: [AwakeDuration]
    var deletable = false

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(items) { d in
                Chip(duration: d, selected: awake.isActive && awake.current == d, deletable: deletable)
            }
        }
    }
}

private struct Chip: View {
    @EnvironmentObject var awake: AwakeController
    let duration: AwakeDuration
    let selected: Bool
    let deletable: Bool
    @State private var hovering = false

    var body: some View {
        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { awake.toggle(duration) } } label: {
            Text(duration.label)
                .font(Theme.font(duration.minutes == nil ? 18 : 14, .bold))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Capsule().fill(selected ? Theme.red : (hovering ? Theme.blush : Theme.chip)))
                .foregroundStyle(selected ? .white : Theme.ink)
                .contentShape(Capsule())
        }
        .buttonStyle(Squishy())
        .overlay(alignment: .topTrailing) {
            if deletable && hovering && !selected {
                Button { withAnimation { awake.removeCustom(duration) } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .black))
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Theme.ink))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .offset(x: 3, y: -4)
                .help("Forget this time")
            }
        }
        .onHover { hovering = $0 }
        .help(duration.minutes == nil ? "Keep awake until you turn it off" : "Keep awake for \(duration.label)")
    }
}

// MARK: Custom time editor

private struct CustomTimeEditor: View {
    @EnvironmentObject var awake: AwakeController
    @Binding var isPresented: Bool
    @State private var hours = 0
    @State private var minutes = 45

    private var total: Int { hours * 60 + minutes }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Dial(value: $hours, range: 0...23, step: 1, unit: "h")
                Dial(value: $minutes, range: 0...55, step: 5, unit: "m")
            }
            HStack(spacing: 8) {
                PillButton(title: "Cancel", fill: .white, text: Theme.muted) { close() }
                PillButton(title: "Save", fill: Theme.blush, text: Theme.redDeep) {
                    awake.saveCustom(minutes: total); close()
                }
                .disabled(total == 0)
                PillButton(title: "Start", fill: Theme.red, text: .white) {
                    awake.saveCustom(minutes: total)
                    awake.start(AwakeDuration(minutes: total)); close()
                }
                .disabled(total == 0)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.chip))
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isPresented = false }
    }
}

/// A round "−  12h  +" stepper.
private struct Dial: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        HStack(spacing: 6) {
            round("minus") { value = max(range.lowerBound, value - step) }
            Text("\(value)\(unit)")
                .font(Theme.font(17, .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 40)
                .contentTransition(.numericText())
            round("plus") { value = min(range.upperBound, value + step) }
        }
    }

    private func round(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { action() } } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .heavy))
                .frame(width: 26, height: 26)
                .background(Circle().fill(.white))
                .foregroundStyle(Theme.red)
        }
        .buttonStyle(Squishy())
    }
}

// MARK: Options

private struct OptionRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.font(13.5, .bold)).foregroundStyle(Theme.ink)
                Text(subtitle).font(Theme.font(11, .medium)).foregroundStyle(Theme.muted)
            }
            Spacer()
            YesNo(value: $value)
        }
    }
}

/// Two round buttons in a capsule: Yes / No.
private struct YesNo: View {
    @Binding var value: Bool
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            option("Yes", true)
            option("No", false)
        }
        .padding(3)
        .background(Capsule().fill(.white))
    }

    private func option(_ label: String, _ v: Bool) -> some View {
        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { value = v } } label: {
            Text(label)
                .font(Theme.font(12, .bold))
                .frame(width: 40, height: 26)
                .background {
                    if value == v {
                        Capsule().fill(v ? Theme.leaf : Theme.ink).matchedGeometryEffect(id: "pill", in: ns)
                    }
                }
                .foregroundStyle(value == v ? .white : Theme.muted)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Footer

private struct Footer: View {
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack {
            Button { setLogin(!openAtLogin) } label: {
                HStack(spacing: 8) {
                    ZStack(alignment: openAtLogin ? .trailing : .leading) {
                        Capsule().fill(openAtLogin ? Theme.leaf : Color(white: 0.86))
                        Circle().fill(.white).padding(2.5).shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                    }
                    .frame(width: 34, height: 20)
                    Text("Open at login").font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(Squishy())
            Spacer()
            PillButton(title: "Quit", fill: Theme.chip, text: Theme.ink, compact: true) {
                NSApp.terminate(nil)
            }
        }
    }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { openAtLogin = on }
        } catch {
            openAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: Building blocks

struct PillButton: View {
    let title: String
    let fill: Color
    let text: Color
    var compact = false
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.font(compact ? 12 : 13, .bold))
                .padding(.horizontal, compact ? 14 : 0)
                .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 28 : 34)
                .background(Capsule().fill(fill))
                .foregroundStyle(text)
                .opacity(enabled ? 1 : 0.4)
                .contentShape(Capsule())
        }
        .buttonStyle(Squishy())
    }
}

/// A playful press: buttons squish a little.
struct Squishy: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

private struct Block<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(Theme.font(10.5, .heavy))
                .kerning(0.8)
                .foregroundStyle(Theme.muted)
            content
        }
    }
}

/// The fruit, drawn live so the eye can open, close and blink.
struct FruitView: View, Animatable {
    var openness: CGFloat
    var animatableData: CGFloat {
        get { openness }
        set { openness = newValue }
    }

    var body: some View {
        Canvas { ctx, size in
            ctx.withCGContext { cg in
                FruitArt.draw(in: cg, rect: CGRect(origin: .zero, size: size), openness: openness, style: .color, yDown: true)
            }
        }
    }
}
