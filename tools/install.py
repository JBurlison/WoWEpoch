"""Update only managed addon files; preserve unexpected edits and all SavedVariables."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
from art_texture_manifest import retirement_plan, active_paths, load_release_manifest

ROOT = Path(__file__).resolve().parents[1]
manifest_path = ROOT / '.tools/installed-build.json'
manifest = json.loads(manifest_path.read_text())
target = Path(manifest['installation'])
addons = Path('C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns')
if target.resolve() != addons.resolve() / 'MyEpoch':
    raise SystemExit('Installation target is not the explicitly selected MyEpoch folder.')
source = ROOT / 'MyEpoch'
paths = [p for p in source.rglob('*') if p.is_file()]
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
expected = manifest.get('files', {})
exports = load_release_manifest(ROOT)
active_art = active_paths(exports)
actual_art = {p.relative_to(source).as_posix() for p in (source/'Media/Illustrations').rglob('*') if p.is_file()}
if actual_art != active_art:
    raise SystemExit('Source illustration files differ from the active export manifest.')
retired = retirement_plan(target, expected, {p.relative_to(source).as_posix() for p in paths}, exports)
for path in paths:
    relative = path.relative_to(source).as_posix()
    installed = target / relative
    if installed.exists() and digest(installed) not in (expected.get(relative), digest(path)):
        raise SystemExit(f'Unexpected installed edit preserved: {installed}')
backup = ROOT / 'dist/backups' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
changed = [p for p in paths if not (target / p.relative_to(source)).exists() or digest(p) != digest(target / p.relative_to(source))]
# TOC is updated last so the complete new module set is present before it is referenced.
changed.sort(key=lambda p: p.suffix == '.toc')
for path in changed:
    relative = path.relative_to(source)
    installed = target / relative
    if installed.exists():
        saved = backup / relative
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(installed, saved)
    installed.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, installed)
for path in paths:
    assert digest(path) == digest(target / path.relative_to(source)), f'Copy verification failed: {path.name}'
for path in retired:
    relative = path.relative_to(target)
    saved = backup / relative
    saved.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, saved)
    assert digest(saved) == expected[relative.as_posix()], 'Retirement backup verification failed'
    path.unlink()
manifest['files'] = {p.relative_to(source).as_posix(): digest(p) for p in paths}
manifest['version'] = next(line.split(':', 1)[1].strip() for line in (source / 'MyEpoch.toc').read_text().splitlines() if line.startswith('## Version:'))
manifest['installedAtUTC'] = datetime.now(timezone.utc).isoformat()
manifest_path.write_text(json.dumps(manifest, indent=2))
print(f'Installed and hash-verified {len(paths)} files; {len(changed)} updated. SavedVariables untouched.')
if retired: print(f'Retired {len(retired)} superseded managed illustration files after verified backups.')
if changed: print(f'Previous managed files backed up under {backup}')
