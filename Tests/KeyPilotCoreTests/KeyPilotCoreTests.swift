import Testing
import Foundation
import CoreGraphics
@testable import KeyPilotCore

@Suite struct KeyComboTests {
    @Test func displayStringUsesCanonicalModifierOrder() {
        let c = KeyCombo(keyCode: KeyCode.leftArrow, modifiers: [.command, .shift, .option, .control])
        #expect(c.displayString == "⌃⌥⇧⌘←")
    }

    @Test func carbonFlags() {
        #expect(KeyModifiers.command.carbonFlags == 256)
        #expect(KeyModifiers.shift.carbonFlags == 512)
        #expect(KeyModifiers.option.carbonFlags == 2048)
        #expect(KeyModifiers.control.carbonFlags == 4096)
        #expect(KeyModifiers([.command, .control]).carbonFlags == 256 + 4096)
    }

    @Test func validity() {
        #expect(!KeyCombo(keyCode: KeyCode.a, modifiers: []).isValidGlobalHotKey)
        #expect(!KeyCombo(keyCode: KeyCode.a, modifiers: [.shift]).isValidGlobalHotKey)
        #expect(KeyCombo(keyCode: KeyCode.a, modifiers: [.option]).isValidGlobalHotKey)
        #expect(KeyCombo(keyCode: 0x7A, modifiers: []).isValidGlobalHotKey) // F1 bare
        #expect(!KeyCombo(keyCode: 0x37, modifiers: [.command]).isValidGlobalHotKey) // ⌘ alone
    }

    @Test func systemReserved() {
        #expect(KeyCombo(keyCode: KeyCode.space, modifiers: [.command]).systemReservedName != nil)
        #expect(KeyCombo(keyCode: KeyCode.space, modifiers: [.command, .option]).systemReservedName == nil)
    }

    @Test func codableRoundTrip() throws {
        let c = KeyCombo(keyCode: KeyCode.k, modifiers: [.control, .option])
        let data = try JSONEncoder().encode(c)
        #expect(try JSONDecoder().decode(KeyCombo.self, from: data) == c)
    }
}

@Suite struct SnapGeometryTests {
    // A 1440x900 screen with a 25pt menu bar: visible frame in Cocoa coords.
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

    @Test func leftHalf() {
        let r = SnapGeometry.target(for: .leftHalf, current: .zero, visible: visible)
        #expect(r == CGRect(x: 0, y: 0, width: 720, height: 875))
    }

    @Test func topHalfIsAtTopInCocoaSpace() {
        let r = SnapGeometry.target(for: .topHalf, current: .zero, visible: visible)!
        #expect(r.minY == 438 || r.minY == 437) // integral rounding of 437.5
        #expect(r.maxY == 875)
    }

    @Test func quarters() {
        let tl = SnapGeometry.target(for: .topLeft, current: .zero, visible: visible)!
        let br = SnapGeometry.target(for: .bottomRight, current: .zero, visible: visible)!
        #expect(tl.minX == 0 && tl.maxY == 875)
        #expect(br.maxX == 1440 && br.minY == 0)
    }

    @Test func halvesCycle() {
        let half = SnapGeometry.target(for: .leftHalf, current: .zero, visible: visible)!
        let twoThirds = SnapGeometry.target(for: .leftHalf, current: half, visible: visible)!
        #expect(twoThirds.width == 960)
        let third = SnapGeometry.target(for: .leftHalf, current: twoThirds, visible: visible)!
        #expect(third.width == 480)
        let back = SnapGeometry.target(for: .leftHalf, current: third, visible: visible)!
        #expect(back.width == 720)
    }

    @Test func cyclingCanBeDisabled() {
        let half = SnapGeometry.target(for: .leftHalf, current: .zero, visible: visible)!
        let again = SnapGeometry.target(for: .leftHalf, current: half, visible: visible, cycle: false)!
        #expect(again == half)
    }

    @Test func rightTwoThirdsWhenCycling() {
        let half = SnapGeometry.target(for: .rightHalf, current: .zero, visible: visible)!
        let twoThirds = SnapGeometry.target(for: .rightHalf, current: half, visible: visible)!
        #expect(twoThirds.maxX == 1440 && twoThirds.width == 960)
    }

    @Test func gapLeavesSpaceAround() {
        let r = SnapGeometry.target(for: .leftHalf, current: .zero, visible: visible, gap: 10)!
        #expect(r.minX == 10)
        #expect(r.minY == 10)
        #expect(r.maxX == 715) // 10 between halves → each side 5
        let right = SnapGeometry.target(for: .rightHalf, current: .zero, visible: visible, gap: 10)!
        #expect(right.minX - r.maxX == 10)
    }

    @Test func centerKeepsSize() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let r = SnapGeometry.target(for: .center, current: frame, visible: visible)!
        #expect(r.size == frame.size)
        #expect(r.midX == 720)
    }

    @Test func repeatedCenterDoesNotGrowWindow() {
        var frame = CGRect(x: 3, y: 7, width: 801, height: 599)
        for _ in 0..<5 { frame = SnapGeometry.target(for: .center, current: frame, visible: visible)! }
        #expect(frame.size == CGSize(width: 801, height: 599))
    }

    @Test func centerClampsOversizedWindow() {
        let frame = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let r = SnapGeometry.centered(frame, in: visible)
        #expect(r == visible)
    }

    @Test func maximizeHeightKeepsX() {
        let frame = CGRect(x: 100, y: 200, width: 500, height: 300)
        let r = SnapGeometry.target(for: .maximizeHeight, current: frame, visible: visible)!
        #expect(r.minX == 100 && r.width == 500 && r.height == 875)
    }

    @Test func thirdsTile() {
        let a = SnapGeometry.target(for: .firstThird, current: .zero, visible: visible)!
        let b = SnapGeometry.target(for: .centerThird, current: .zero, visible: visible)!
        let c = SnapGeometry.target(for: .lastThird, current: .zero, visible: visible)!
        #expect(a.maxX == b.minX && b.maxX == c.minX && c.maxX == 1440)
    }

    @Test func flipIsInvolution() {
        let r = CGRect(x: 10, y: 20, width: 300, height: 400)
        let once = SnapGeometry.flip(r, primaryScreenHeight: 900)
        #expect(once == CGRect(x: 10, y: 480, width: 300, height: 400))
        #expect(SnapGeometry.flip(once, primaryScreenHeight: 900) == r)
    }

    @Test func moveBetweenScreensPreservesRelativePlacement() {
        let src = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let dst = CGRect(x: 1000, y: 0, width: 2000, height: 1600)
        let frame = CGRect(x: 0, y: 0, width: 500, height: 400) // bottom-left quarter
        let r = SnapGeometry.move(frame, from: src, to: dst)
        #expect(r == CGRect(x: 1000, y: 0, width: 1000, height: 800))
    }

    @Test func bestScreen() {
        let screens = [CGRect(x: 0, y: 0, width: 1000, height: 800), CGRect(x: 1000, y: 0, width: 1000, height: 800)]
        #expect(SnapGeometry.bestScreenIndex(for: CGRect(x: 900, y: 0, width: 400, height: 300), screens: screens) == 1)
        #expect(SnapGeometry.bestScreenIndex(for: CGRect(x: 5000, y: 5000, width: 10, height: 10), screens: screens) == 1)
    }

    @Test func everyRegionActionFitsInsideVisible() {
        for action in SnapAction.allCases where action.unitRect != nil {
            let r = SnapGeometry.target(for: action, current: .zero, visible: visible, gap: 8)!
            #expect(visible.contains(r), "\(action) escaped the screen: \(r)")
        }
    }
}

@Suite struct ConfigTests {
    @Test func defaultsHaveNoInternalConflicts() {
        let cfg = AppConfig()
        #expect(ConflictDetector.internalConflicts(in: cfg).isEmpty)
        let combos = SnapAction.allCases.compactMap(\.defaultCombo)
        #expect(Set(combos).count == combos.count)
    }

    @Test func defaultsAvoidSystemReservedAndAreValid() {
        for c in SnapAction.allCases.compactMap(\.defaultCombo) {
            #expect(c.isValidGlobalHotKey)
            #expect(c.systemReservedName == nil)
            // Avoid the macOS 15 ⌥-only restriction.
            #expect(!c.modifiers.intersection([.command, .control]).isEmpty)
        }
    }

    @Test func roundTrip() throws {
        var cfg = AppConfig()
        cfg.apps.append(AppBinding(name: "Safari", bundleIdentifier: "com.apple.Safari",
                                   path: "/Applications/Safari.app",
                                   combo: KeyCombo(keyCode: KeyCode.s, modifiers: [.control, .command])))
        cfg.setCombo(nil, for: .center)
        cfg.settings.snapGap = 6
        let back = try AppConfig.decode(cfg.encoded())
        #expect(back == cfg)
        #expect(back.combo(for: .center) == nil)
    }

    @Test func tolerantDecodingOfPartialAndUnknownKeys() throws {
        let json = """
        {"apps":[{"name":"X","path":"/Applications/X.app"}],
         "snaps":{"leftHalf":{"keyCode":123,"modifiers":6},"futureAction":{"keyCode":1,"modifiers":1}},
         "settings":{"snapGap":4,"someNewSetting":true}}
        """
        let cfg = try AppConfig.decode(Data(json.utf8))
        #expect(cfg.apps.count == 1)
        #expect(cfg.apps[0].enabled)
        #expect(cfg.apps[0].behavior == .toggle)
        #expect(cfg.snaps["futureAction"] == nil)
        #expect(cfg.combo(for: .leftHalf) == KeyCombo(keyCode: 123, modifiers: [.option, .control]))
        #expect(cfg.settings.snapGap == 4)
        #expect(cfg.settings.hotkeysEnabled)
    }

    @Test func detectsConflictsAndIgnoresDisabledApps() {
        var cfg = AppConfig()
        let clash = cfg.combo(for: .leftHalf)!
        var app = AppBinding(name: "Notes", bundleIdentifier: nil, path: "/x", combo: clash)
        cfg.apps = [app]
        let conflicts = ConflictDetector.internalConflicts(in: cfg)
        #expect(conflicts[.app(app.id)] == [SnapAction.leftHalf.title])
        #expect(conflicts[.snap(.leftHalf)] == ["Notes"])
        #expect(ConflictDetector.owner(of: clash, in: cfg, excluding: .snap(.leftHalf))?.owner == .app(app.id))

        app.enabled = false
        cfg.apps = [app]
        #expect(ConflictDetector.internalConflicts(in: cfg).isEmpty)
    }
}
