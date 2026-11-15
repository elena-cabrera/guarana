import AppKit
import GuaranaArt
import SwiftUI

@main
struct GuaranaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var awake = AwakeController.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(awake)
        } label: {
            Image(nsImage: FruitImage.menuBar(awake: awake.isActive))
                .accessibilityLabel(awake.isActive ? "Guarana: awake" : "Guarana: asleep")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // `Guarana --snapshot <dir>` renders the popover to PNGs (used for docs and the website).
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            MainActor.assumeIsolated { Snapshots.render(to: URL(fileURLWithPath: args[i + 1])) }
            exit(0)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Always hand sleep back to macOS when we quit.
        MainActor.assumeIsolated { AwakeController.shared.stop() }
    }
}

extension AwakeController {
    static let shared = AwakeController()
}

enum FruitImage {
    /// 18pt menu bar icon. Asleep: a monochrome template that matches the menu bar.
    /// Awake: the full-colour red fruit with its eye wide open, so you can tell at a glance.
    static func menuBar(awake: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            FruitArt.draw(in: ctx, rect: rect.insetBy(dx: 0.5, dy: 0.5), openness: awake ? 1 : 0,
                          style: awake ? .color : .template)
            return true
        }
        image.isTemplate = !awake
        return image
    }
}

@MainActor
enum Snapshots {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let awake = AwakeController.shared
        let saved = awake.customDurations
        awake.customDurations = [AwakeDuration(minutes: 45), AwakeDuration(minutes: 90), AwakeDuration(minutes: 480)]

        func shot(_ name: String, editor: Bool = false) {
            let view = PopoverView(showEditor: editor).environmentObject(awake)
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appendingPathComponent(name + ".png"))
            }
        }
        shot("popover-asleep")
        shot("popover-editor", editor: true)
        awake.start(AwakeDuration(minutes: 60))
        shot("popover-awake")
        awake.stop()
        awake.customDurations = saved
    }
}
