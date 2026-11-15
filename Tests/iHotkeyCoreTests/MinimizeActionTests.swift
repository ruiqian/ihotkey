import Testing
import Foundation
import CoreGraphics
@testable import iHotkeyCore

@Suite struct MinimizeActionTests {
    @Test func minimizeIsAWindowActionWithSafeDefault() throws {
        let action = try #require(SnapAction(rawValue: "minimize"))
        #expect(action.group == .screen)
        #expect(SnapAction.Group.screen.actions.contains(action))
        #expect(action.defaultCombo == KeyCombo(keyCode: KeyCode.m, modifiers: [.control, .option]))
        #expect(action.defaultCombo?.isValidGlobalHotKey == true)
        #expect(action.defaultCombo?.systemReservedName == nil)
        #expect(!action.supportsCycling)
        #expect(action.unitRect == nil)
        #expect(SnapGeometry.target(for: action,
            current: CGRect(x: 20, y: 40, width: 600, height: 400),
            visible: CGRect(x: 0, y: 0, width: 1440, height: 900)) == nil)
    }

    @Test func freshConfigBindsMinimizeWithoutConflicts() throws {
        let action = try #require(SnapAction(rawValue: "minimize"))
        let config = AppConfig()
        #expect(config.combo(for: action) == action.defaultCombo)
        #expect(ConflictDetector.internalConflicts(in: config).isEmpty)
    }

    @Test func olderConfigDoesNotAcquireUnrequestedShortcut() throws {
        let action = try #require(SnapAction(rawValue: "minimize"))
        let combo = KeyCombo(keyCode: KeyCode.m, modifiers: [.control, .option])
        var legacy = AppConfig()
        legacy.snaps.removeValue(forKey: "minimize")
        let app = AppBinding(name: "Example", bundleIdentifier: "example.app", path: "/Example.app", combo: combo)
        legacy.apps = [app]
        let decoded = try AppConfig.decode(legacy.encoded())
        #expect(decoded.combo(for: action) == nil)
        #expect(decoded.apps == legacy.apps)
        #expect(decoded.snaps == legacy.snaps)
        #expect(ConflictDetector.internalConflicts(in: decoded).isEmpty)
    }

    @Test func customMinimizeBindingAndClearingPersist() throws {
        let action = try #require(SnapAction(rawValue: "minimize"))
        var config = AppConfig()
        let custom = KeyCombo(keyCode: KeyCode.m, modifiers: [.control, .command, .shift])
        config.setCombo(custom, for: action)
        let decoded = try AppConfig.decode(config.encoded())
        #expect(decoded.combo(for: action) == custom)
        config.setCombo(nil, for: action)
        #expect(try AppConfig.decode(config.encoded()).combo(for: action) == nil)
    }
}
