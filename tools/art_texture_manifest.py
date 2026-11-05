"""Validate active native texture files and identify replaceable managed formats."""
from pathlib import Path
import hashlib
import json
import re
import struct
from blp_validation import validate_blp

def release_manifest(root, exports):
    """Public build inputs contain finished textures, never private source artwork."""
    catalog = (Path(root) / 'MyEpoch/ArtCatalog.lua').read_text(encoding='utf-8')
    return {
        'schema': 1,
        'catalogSHA256': hashlib.sha256(catalog.encode('utf-8')).hexdigest(),
        'exports': {key: {role: entry[role] for role in ('image', 'thumbnail')}
                    for key, entry in exports.items()},
    }

def load_release_manifest(root):
    root = Path(root)
    manifest = json.loads((root / 'tools/art-release.json').read_text(encoding='utf-8'))
    if manifest.get('schema') != 1 or manifest != release_manifest(root, manifest['exports']):
        raise ValueError('Artwork release manifest is stale; rebuild with the private design sources.')
    exports = manifest['exports']
    active_paths(exports)
    for entry in exports.values():
        for role in ('image', 'thumbnail'):
            validate_texture(root / 'MyEpoch', entry[role])
    return exports

def texture_path(addon, relative):
    if not re.fullmatch(r'Media/Illustrations/[a-z0-9-]+\.(tga|blp)', relative):
        raise ValueError('Invalid illustration path')
    base = Path(addon).resolve()
    directory = (base / 'Media/Illustrations').resolve()
    path = (base / relative).resolve()
    if not directory.is_relative_to(base) or path.parent != directory:
        raise ValueError('Illustration escapes its managed directory')
    return path

def validate_texture(addon, item):
    path = texture_path(addon, item['path'])
    data = path.read_bytes()
    if len(data) != item['bytes'] or hashlib.sha256(data).hexdigest() != item['sha256']:
        raise ValueError('Texture content differs from manifest: ' + item['path'])
    size = item['width'], item['height']
    if path.suffix == '.blp':
        validate_blp(data, expected_size=size, expected_sha256=item['sha256'])
    else:
        if len(data) < 18 or data[0] or data[1] or data[17] or data[2] != 2 or data[16] != 24:
            raise ValueError('Expected canonical RGB TGA')
        width, height = struct.unpack_from('<HH', data, 12)
        if (width, height) != size or len(data) != 18 + width * height * 3:
            raise ValueError('TGA dimensions/payload mismatch')
        if any(n < 1 or n > 4096 or n & (n - 1) for n in size):
            raise ValueError('Expected bounded power-of-two dimensions')
    return path

def active_paths(exports):
    paths = set()
    for asset_id, entry in exports.items():
        if not re.fullmatch('[a-z0-9-]+', asset_id):
            raise ValueError('Invalid artwork ID')
        for role, suffix in (('image', ''), ('thumbnail', '-thumb')):
            relative = entry[role]['path']
            if relative not in {f'Media/Illustrations/{asset_id}{suffix}.tga', f'Media/Illustrations/{asset_id}{suffix}.blp'}:
                raise ValueError('Texture path does not match artwork ID/role')
            if relative in paths:
                raise ValueError('A texture cannot represent multiple artwork roles')
            paths.add(relative)
    return paths

def retirement_plan(addon, previous, current, exports):
    """Only alternate formats of still-active artwork can be retired.

    previous is the installed hash manifest, never a filesystem discovery list.
    Preflight every candidate before the caller makes any installation writes.
    """
    active = active_paths(exports)
    if not active <= set(current):
        raise ValueError('Active artwork missing from current source files')
    replacements = {}
    for relative in active:
        path = Path(relative)
        other = path.with_suffix('.tga' if path.suffix == '.blp' else '.blp').as_posix()
        replacements[other] = relative
    result = []
    for relative in set(previous) - set(current):
        if relative not in replacements:
            continue  # Other obsolete files are not automatically removed.
        target = texture_path(addon, relative)
        if target.exists():
            if hashlib.sha256(target.read_bytes()).hexdigest() != previous[relative]:
                raise ValueError('Unexpected installed edit preserved: ' + relative)
            result.append(target)
    return sorted(result)
