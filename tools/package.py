"""Build a Forever ZIP using the TOC as the authoritative load manifest."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import subprocess
import sys
from art_texture_manifest import active_paths, load_release_manifest
ROOT = Path(__file__).resolve().parents[1]
if (ROOT / 'design/art-matrix.json').is_file():
    subprocess.run([sys.executable, str(ROOT / 'tools/build-art-catalog.py'), '--check'], check=True)
subprocess.run([sys.executable, str(ROOT / 'tools/build-quest-catalog.py'), '--check'], check=True)
subprocess.run([sys.executable, str(ROOT / 'tools/build_auction_readers.py'), '--check'], check=True)
subprocess.run([sys.executable, str(ROOT / 'tools/build_craft_projection_readers.py'), '--check'], check=True)
ADDON = ROOT / 'MyEpoch'
active_art = active_paths(load_release_manifest(ROOT))
actual_art = {p.relative_to(ADDON).as_posix() for p in (ADDON/'Media/Illustrations').rglob('*') if p.is_file()}
if actual_art != active_art:
    raise SystemExit('Illustration directory differs from active export manifest; preserve and resolve untracked/obsolete files before packaging.')
toc = ADDON / 'MyEpoch.toc'
files = [toc]
# WoW discovers addon Bindings.xml separately from the Lua/XML TOC load list.
bindings = ADDON / 'Bindings.xml'
if bindings.is_file(): files.append(bindings)
for line in toc.read_text().splitlines():
    if line and not line.startswith('#'):
        path = ADDON / line.replace('\\', '/')
        if not path.is_file() or not path.resolve().is_relative_to(ADDON.resolve()):
            raise SystemExit(f'Invalid TOC include: {line}')
        files.append(path)
for path in (ADDON / 'Media').rglob('*') if (ADDON / 'Media').exists() else []:
    if path.is_file(): files.append(path)
for path in (ADDON / 'Licenses').rglob('*'):
    if path.is_file(): files.append(path)
destination = ROOT / 'dist/MyEpoch-Forever-dev.zip'
destination.parent.mkdir(exist_ok=True)
with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
    for path in files:
        archive.write(path, path.relative_to(ROOT).as_posix())
with ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert all(name.startswith('MyEpoch/') for name in archive.namelist())
print(f'Packaged {len(files)} files: {destination}')
