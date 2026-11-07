"""Build an installable, versioned Forever ZIP from the TOC and finished assets."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
import subprocess
import sys
from art_texture_manifest import active_paths, load_release_manifest
from release import version, filename

ROOT = Path(__file__).resolve().parents[1]


def package_files(addon):
    addon = addon.resolve()
    toc = addon / 'MyEpoch.toc'
    files = [toc]
    bindings = addon / 'Bindings.xml'
    if bindings.is_file():
        files.append(bindings)
    for line in toc.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            path = addon / line.replace('\\', '/')
            if not path.is_file() or not path.resolve().is_relative_to(addon):
                raise ValueError(f'Invalid TOC include: {line}')
            files.append(path)
    for directory in ('Media', 'Licenses'):
        for path in sorted((addon / directory).rglob('*')):
            if path.is_file():
                if not path.resolve().is_relative_to(addon):
                    raise ValueError(f'Asset escapes addon directory: {path}')
                files.append(path)
    names = [path.relative_to(addon).as_posix() for path in files]
    if len(set(name.lower() for name in names)) != len(names):
        raise ValueError('Duplicate or case-conflicting package paths.')
    # The game reads this texture before the addon's Lua is loaded.
    icons = [line.split(':', 1)[1].strip() for line in toc.read_text(encoding='utf-8').splitlines()
             if line.startswith('## IconTexture:')]
    prefix = 'Interface\\AddOns\\MyEpoch\\'
    if len(icons) != 1 or not icons[0].startswith(prefix):
        raise ValueError('Expected one bundled My Epoch AddOns-menu icon.')
    if icons[0][len(prefix):].replace('\\', '/') not in names:
        raise ValueError('AddOns-menu icon is missing from the package.')
    return files


def write_package(root, current):
    addon = root / 'MyEpoch'
    files = package_files(addon)
    destination = root / 'dist' / filename(current)
    destination.parent.mkdir(exist_ok=True)
    with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, 'MyEpoch/' + path.relative_to(addon).as_posix())
    with ZipFile(destination) as archive:
        assert archive.testzip() is None
        assert all(name.startswith('MyEpoch/') for name in archive.namelist())
    with destination.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    destination.with_suffix('.zip.sha256').write_text(f'{digest}  {destination.name}\n', encoding='utf-8')
    print(f'Packaged {len(files)} files: {destination}')
    return destination


def main():
    current = version(ROOT)
    if (ROOT / 'design/art-matrix.json').is_file():
        subprocess.run([sys.executable, str(ROOT / 'tools/build-art-catalog.py'), '--check'], check=True)
    for tool in ('build-quest-catalog.py', 'build_auction_readers.py', 'build_craft_projection_readers.py', 'build_controller_unicode.py'):
        subprocess.run([sys.executable, str(ROOT / 'tools' / tool), '--check'], check=True)
    active_art = active_paths(load_release_manifest(ROOT))
    actual_art = {p.relative_to(ROOT / 'MyEpoch').as_posix()
                  for p in (ROOT / 'MyEpoch/Media/Illustrations').rglob('*') if p.is_file()}
    if actual_art != active_art:
        raise SystemExit('Illustration directory differs from the active export manifest.')
    write_package(ROOT, current)


if __name__ == '__main__':
    main()
