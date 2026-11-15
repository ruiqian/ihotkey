#!/usr/bin/env python3
"""Offline repository readiness checks; does not claim CI/notarization success."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

class RepositoryTests(unittest.TestCase):
    def test_swift_targets_and_layout(self):
        manifest = (ROOT/'Package.swift').read_text()
        self.assertIn('name: "iHotkey"', manifest)
        self.assertIn('name: "iHotkeyCore"', manifest)
        for folder in ('App', 'Applications', 'Diagnostics', 'Hotkeys', 'System', 'Views', 'Windows'):
            self.assertTrue((ROOT/'Sources/iHotkey'/folder).is_dir(), folder)

    def test_active_sources_have_only_current_brand(self):
        for base in ('Sources', 'Tests'):
            for path in (ROOT/base).rglob('*.swift'):
                self.assertNotIn('keypilot', path.read_text().lower(), str(path))
                self.assertNotIn('0x4B50_4C54', path.read_text(), str(path))

    def test_secrets_and_builds_are_ignored(self):
        ignore = (ROOT/'.gitignore').read_text()
        for item in ('.build/', 'build/', 'dist/', '*.p12', '*.p8', '*.keychain-db', '.env', '__pycache__/'):
            self.assertIn(item, ignore)

    def test_release_does_not_automatically_publish(self):
        workflow = (ROOT/'.github/workflows/release.yml').read_text()
        self.assertRegex(workflow, r'draft:\s*true')
        self.assertIn('SHA256SUMS', workflow)
        self.assertIn('contents: write', workflow)

    def test_documentation_and_version(self):
        for name in ('README.md', 'README.zh-CN.md', 'CONTRIBUTING.md', 'SECURITY.md',
                     'CHANGELOG.md', 'docs/DEVELOPMENT.md', 'docs/RELEASING.md', 'docs/KNOWN_ISSUES.md'):
            self.assertTrue((ROOT/name).is_file(), name)
        self.assertRegex((ROOT/'VERSION').read_text().strip(), r'^\d+\.\d+\.\d+(?:-rc\.\d+)?$')

    def test_release_version_is_visible_in_about(self):
        source = (ROOT/'Sources/iHotkey/Views/GeneralView.swift').read_text()
        self.assertIn('forInfoDictionaryKey: "IHReleaseVersion"', source)

    def test_build_is_explicit_and_non_destructive(self):
        build = (ROOT/'scripts/build-app.sh').read_text()
        self.assertIn('com.ihotkey.app', build)
        self.assertIn('iHotkey.app', build)
        self.assertNotRegex(build, r'\brm\s+-')
        self.assertIn('SIGN_MODE', build)

if __name__ == '__main__':
    unittest.main()
