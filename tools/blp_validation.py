"""Validate My Epoch's canonical opaque BC1 BLP2 export profile.

This is a bounded container/payload validator, not a decoder or general BLP
reader. Pixel quality and client rendering require separate checks. Existing
TGA production exports are not migrated by this tool.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

HEADER_BYTES = 1172


def validate_blp(data, *, expected_size=None, expected_sha256=None, allow_base_only=False):
    if len(data) < HEADER_BYTES:
        raise ValueError('Truncated BLP2 header')
    magic, content, encoding, alpha_depth, alpha_encoding, has_mips, width, height = struct.unpack_from('<4sIBBBBII', data)
    if (magic, content, encoding, alpha_depth, alpha_encoding) != (b'BLP2', 1, 2, 0, 0):
        raise ValueError('Expected direct, opaque BC1 BLP2')
    if has_mips not in (0, 1):
        raise ValueError('Invalid mip flag')
    if any(n < 1 or n > 4096 or n & (n - 1) for n in (width, height)):
        raise ValueError('Expected power-of-two dimensions in 1..4096')
    if expected_size is not None and (width, height) != tuple(expected_size):
        raise ValueError('Dimensions differ from the export manifest')
    # Our encoder writes an unused, zero palette. Other valid BLP profiles
    # may differ; they must not silently enter this canonical export path.
    if any(data[148:HEADER_BYTES]):
        raise ValueError('Unexpected palette data in canonical BC1 export')
    offsets = struct.unpack_from('<16I', data, 20)
    lengths = struct.unpack_from('<16I', data, 84)
    expected = []
    w, h = width, height
    while True:
        expected.append(((w + 3) // 4) * ((h + 3) // 4) * 8)
        if w == h == 1:
            break
        w, h = max(1, w // 2), max(1, h // 2)
    used = 0
    end = HEADER_BYTES
    for level, (offset, length) in enumerate(zip(offsets, lengths)):
        if offset == length == 0:
            if any(offsets[level:]) or any(lengths[level:]):
                raise ValueError('Mip table contains a hole')
            break
        if not offset or not length or level >= len(expected):
            raise ValueError('Invalid mip entry or excess mip level')
        if offset != end:
            raise ValueError('Mip payloads overlap or are not contiguous')
        if length != expected[level]:
            raise ValueError('Incorrect BC1 block length')
        end += length
        if end > len(data):
            raise ValueError('Mip payload extends past end of file')
        used += 1
    permitted = {len(expected)}
    if allow_base_only:
        permitted.add(1)
    if used not in permitted:
        raise ValueError('Expected a complete mip chain' + (' or a base-only image' if allow_base_only else ''))
    if has_mips != int(used > 1):
        raise ValueError('Mip flag disagrees with the table')
    if end != len(data):
        raise ValueError('Unexpected trailing bytes')
    digest = hashlib.sha256(data).hexdigest()
    if expected_sha256 is not None and digest != expected_sha256:
        raise ValueError('Texture hash differs from the export manifest')
    return dict(format='BLP2', encoding='BC1', alphaDepth=0, width=width,
                height=height, mipCount=used, fullMipChain=used == len(expected),
                offsets=list(offsets[:used]), lengths=list(lengths[:used]),
                bytes=len(data), sha256=digest)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path', type=Path)
    parser.add_argument('--size', nargs=2, type=int, metavar=('WIDTH', 'HEIGHT'))
    parser.add_argument('--sha256')
    parser.add_argument('--allow-base-only', action='store_true')
    args = parser.parse_args()
    try:
        result = validate_blp(args.path.read_bytes(), expected_size=args.size,
                              expected_sha256=args.sha256, allow_base_only=args.allow_base_only)
    except (OSError, ValueError) as error:
        parser.exit(1, f'{args.path}: {error}\n')
    print(json.dumps(result, indent=2))
