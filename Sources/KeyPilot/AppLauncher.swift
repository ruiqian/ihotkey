import AppKit
import KeyPilotCore

enum AppLauncher {

    static func url(for binding: AppBinding) -> URL? {
        let fm = FileManager.default
        if fm.fileExists(atPath: binding.path) { return URL(fileURLWithPath: binding.path) }
        if let bid = binding.bundleIdentifier {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)
        }
        return nil
    }

    static func isInstalled(_ binding: AppBinding) -> Bool { url(for: binding) != nil }

    /// App icon without the alias badge that symlinked bundles (e.g. Safari) get.
    static func icon(for binding: AppBinding) -> NSImage? {
        guard let url = url(for: binding) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.resolvingSymlinksInPath().path)
    }

    static func runningInstance(of binding: AppBinding) -> NSRunningApplication? {
        if let bid = binding.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first {
            return app
        }
        let path = (binding.path as NSString).standardizingPath
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.standardizedFileURL.path == path
        }
    }

    static func trigger(_ binding: AppBinding) {
        let running = runningInstance(of: binding)

        if binding.behavior == .toggle,
           let running,
           NSWorkspace.shared.frontmostApplication?.processIdentifier == running.processIdentifier {
            running.hide()
            return
        }

        guard let url = url(for: binding) else {
            NSSound.beep()
            return
        }
        running?.unhide()
        // openApplication on a running app behaves like a Dock click:
        // it activates the app and reopens a window if it has none.
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if error != nil { DispatchQueue.main.async { NSSound.beep() } }
        }
    }

    static func makeBinding(from url: URL) -> AppBinding? {
        guard url.pathExtension == "app" else { return nil }
        let bundle = Bundle(url: url)
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        return AppBinding(name: name, bundleIdentifier: bundle?.bundleIdentifier, path: url.path)
    }
}
