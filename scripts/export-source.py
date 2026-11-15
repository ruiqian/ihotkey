#!/usr/bin/env python3
"""Export the current Git index, without history or generated/private files.
Review git diff --cached first. Output refuses to overwrite an existing archive.
"""
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT/'VERSION').read_text().strip()
OUTPUT = ROOT/'dist'/('iHotkey-'+VERSION+'-source.zip')
files = [n for n in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0') if n]
for name in files:
    parts = Path(name).parts
    if any(x in ('.git','.build','build','dist','__pycache__') for x in parts):
        raise SystemExit('Unsafe source export entry: '+name)
    if re.search(r'\.(?:p12|p8|key|keychain|keychain-db|pyc)$',name) or Path(name).name.startswith('.env'):
        raise SystemExit('Private/generated material must not be tracked: '+name)
OUTPUT.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(OUTPUT,'x',compression=zipfile.ZIP_DEFLATED) as z:
    for name in files:
        # Read index contents, not potentially untracked or changed filesystem files.
        data = subprocess.check_output(['git','show',':'+name],cwd=ROOT)
        mode = int(subprocess.check_output(['git','ls-files','--stage','--',name],cwd=ROOT).decode().split()[0], 8)
        entry = zipfile.ZipInfo('iHotkey/'+name)
        entry.create_system = 3
        entry.external_attr = mode << 16
        entry.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(entry,data)
with zipfile.ZipFile(OUTPUT) as z:
    if z.testzip() is not None: raise SystemExit('Archive integrity failure')
    if len(z.namelist()) != len(files): raise SystemExit('Entry count mismatch')
print(f'Exported {len(files)} index files: {OUTPUT}')
