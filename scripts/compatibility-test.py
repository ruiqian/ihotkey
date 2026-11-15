#!/usr/bin/env python3
"""Audit real release binaries and typecheck deployment targets. No VM simulation.
Usage: python3 scripts/compatibility-test.py [--runtime] [--snap] [--out DIR]
Runtime tests briefly close/reopen iHotkey and focus a scratch TextEdit window.
They do not toggle login items, reset TCC, or install Rosetta.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--app', default='/Applications/iHotkey.app')
p.add_argument('--out')
p.add_argument('--runtime', action='store_true')
p.add_argument('--snap', action='store_true')
a = p.parse_args()
OUT = Path(a.out or ROOT / 'build' / ('compatibility-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))).resolve()
OUT.mkdir(parents=True, exist_ok=False)
APP = Path(a.app).resolve()
BIN = APP / 'Contents/MacOS/iHotkey'
results = []

def run(name, cmd, timeout=180, expected=None):
    start = time.monotonic()
    try:
        r = subprocess.run([str(c) for c in cmd], cwd=ROOT, text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout)
        text, code = r.stdout, r.returncode
        passed = code == 0 and (expected is None or expected in text)
        state = ('PASS' if passed else
                 ('BLOCKED' if code != 0 and 'Bad CPU type' in text else 'FAIL'))
    except (OSError, subprocess.TimeoutExpired) as e:
        text, code, state = str(e), None, 'BLOCKED'
    (OUT / (name + '.log')).write_text(text)
    row = dict(test=name, status=state, returncode=code, seconds=round(time.monotonic()-start, 2),
               command=[str(c) for c in cmd], log=name+'.log')
    results.append(row)
    print(f'{state:7} {name}', flush=True)
    return text, row

def record(name, ok, detail):
    results.append(dict(test=name, status='PASS' if ok else 'FAIL', detail=detail))
    print(f'{results[-1]["status"]:7} {name}', flush=True)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None

host, _ = run('host-os', ['sw_vers'])
arch, _ = run('host-arch', ['uname', '-m'])
run('toolchain', ['swift', '--version'])
run('source-commit', ['git', 'rev-parse', 'HEAD'])
run('source-diff', ['git', 'diff', '--stat'])
run('artifact-signature', ['codesign', '--verify', '--strict', '--verbose=2', APP])
run('artifact-requirement', ['codesign', '-d', '-r-', APP])
arches, _ = run('artifact-architectures', ['lipo', '-archs', BIN])
record('artifact-universal', all(x in arches.split() for x in ['arm64', 'x86_64']), arches.strip())
import plistlib
info = plistlib.loads((APP/'Contents/Info.plist').read_bytes())
record('bundle-minimum-os', info.get('LSMinimumSystemVersion') == '12.0', info.get('LSMinimumSystemVersion'))
for cpu in ['arm64', 'x86_64']:
    loads, _ = run('artifact-loads-'+cpu, ['otool', '-arch', cpu, '-l', BIN])
    minimum = re.search(r'cmd LC_BUILD_VERSION\s+cmdsize \d+\s+platform \d+\s+minos ([\d.]+)', loads)
    record('binary-minimum-os-'+cpu, minimum is not None and minimum[1] == '12.0', minimum[1] if minimum else 'not found')
    run('artifact-dependencies-'+cpu, ['otool', '-arch', cpu, '-L', BIN])
    chunks = loads.split('Load command')
    sm = [c for c in chunks if '/ServiceManagement.framework/' in c]
    record('service-management-link-'+cpu, len(sm)==1 and 'LC_LOAD_WEAK_DYLIB' in sm[0], ''.join(sm))

run('unit-tests', ['bash', 'scripts/test.sh'], timeout=300, expected='passed')
sdk = subprocess.check_output(['xcrun', '--show-sdk-path'], text=True).strip()
core = sorted((ROOT/'Sources/iHotkeyCore').glob('*.swift'))
sources = sorted((ROOT/'Sources/iHotkey').rglob('*.swift'))
for cpu in ['arm64', 'x86_64']:
    modules = OUT / ('modules-'+cpu)
    modules.mkdir()
    _, emitted = run('compile-core-'+cpu, ['xcrun', 'swiftc', '-emit-module', '-module-name', 'iHotkeyCore',
        '-swift-version', '5', '-target', cpu+'-apple-macosx12.0', '-sdk', sdk,
        '-emit-module-path', modules/'iHotkeyCore.swiftmodule', *core], timeout=300)
    if emitted['status'] != 'PASS':
        continue
    for version in ['12.0', '13.0', '14.0', '15.0', '26.0']:
        run('typecheck-'+cpu+'-macos'+version,
            ['xcrun', 'swiftc', '-typecheck', '-module-name', 'iHotkey', '-swift-version', '5',
             '-target', cpu+'-apple-macosx'+version, '-sdk', sdk, '-I', modules, *sources], timeout=300)

config = Path.home()/'Library/Application Support/iHotkey/config.json'
config_before = digest(config)
bin_sha = digest(BIN)
installed_sha = digest(ROOT/'dist/iHotkey.app/Contents/MacOS/iHotkey')
record('installed-matches-dist', bin_sha == installed_sha, {'installed': bin_sha, 'dist': installed_sha})

if a.runtime:
    # Terminate only the exact tested app, never an unrelated app with a similar name.
    ps = subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True)
    pids = [int(line.strip().split(None,1)[0]) for line in ps.splitlines()
            if len(line.strip().split(None,1))==2 and line.strip().split(None,1)[1] == str(BIN)]
    for pid in pids:
        os.kill(pid, signal.SIGTERM)
    time.sleep(1)
    try:
        for cpu in ['arm64', 'x86_64']:
            _, row = run('runtime-basic-'+cpu, ['/usr/bin/arch', '-'+cpu, BIN, '--self-test'], expected='SELF-TEST OK')
            if row['returncode'] == 1 and 'Bad CPU type' in (OUT/row['log']).read_text():
                row['status'] = 'BLOCKED'
                row['detail'] = 'CPU slice cannot execute here (Rosetta unavailable). Not an Intel machine test.'
                continue
            if row['status'] == 'PASS':
                run('runtime-ui-'+cpu, ['/usr/bin/arch', '-'+cpu, BIN, '--self-test-ui'], expected='UI SELF-TEST OK')
        if a.snap:
            report = OUT/'snap-native.txt'
            run('runtime-snap-launch', ['open', '-n', APP, '--args', '--self-test-snap', report])
            for _ in range(40):
                if report.exists(): break
                time.sleep(1)
            text = report.read_text() if report.exists() else 'No report within 40 seconds'
            trusted = 'FAIL AXIsProcessTrusted' not in text
            status = 'PASS' if 'SNAP-TEST OK' in text else ('BLOCKED' if not trusted else 'FAIL')
            results.append(dict(test='runtime-snap-native', status=status, detail=text))
            print(status+' runtime-snap-native', flush=True)
    finally:
        # Restore normal app launch; never reset permissions or login settings.
        subprocess.run(['open', APP], check=False)
record('user-config-preserved', digest(config)==config_before, 'SHA256 only; no config contents included')
summary = dict(host=host.strip(), host_arch=arch.strip(), app=str(APP), binary_sha256=bin_sha,
               generated_at=datetime.datetime.now().astimezone().isoformat(), results=results,
               limitations=['Typechecking deployment targets does NOT run older macOS versions.',
                            'Rosetta execution, if available, does NOT replace real Intel hardware testing.',
                            'No reboot/login, multi-display, old-OS or clean-machine Gatekeeper testing performed.'])
(OUT/'results.json').write_text(json.dumps(summary, indent=2, ensure_ascii=False))
counts = {s:sum(r['status']==s for r in results) for s in ['PASS','FAIL','BLOCKED']}
print(json.dumps(counts), flush=True)
print('Report: '+str(OUT/'results.json'))
raise SystemExit(1 if counts['FAIL'] else 0)
