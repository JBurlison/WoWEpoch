"""Corrupt-file regressions for the proposed BLP exporter, independent of a GPU."""
import hashlib
import importlib.util
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('blp_validation', ROOT/'tools/blp_validation.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
validate = module.validate_blp

# Explicit 4x2 -> 2x1 -> 1x1 golden chain. Each tiny mip still occupies a
# complete 8-byte BC1 block; no compressor or implementation helper is used.
golden = (struct.pack('<4sIBBBBII', b'BLP2', 1, 2, 0, 0, 1, 4, 2)
          + struct.pack('<16I', 1172, 1180, 1188, *([0]*13))
          + struct.pack('<16I', 8, 8, 8, *([0]*13)) + bytes(1024)
          + bytes.fromhex('00f81f0000000000')*3)
result = validate(golden, expected_size=(4, 2), expected_sha256=hashlib.sha256(golden).hexdigest())
assert result['bytes'] == 1196 and result['mipCount'] == 3 and result['fullMipChain']

def change(offset, value, fmt='<I', source=golden):
    data = bytearray(source); struct.pack_into(fmt, data, offset, value); return bytes(data)

def rejected(data, **kwargs):
    try:
        validate(data, **kwargs)
    except ValueError:
        return
    raise AssertionError('Malformed or mismatched texture accepted')

for data in [golden[:19], golden[:1180], golden[:-1], golden+b'X',
             change(0, 0), change(4, 0), change(8, 1, '<B'),
             change(9, 8, '<B'), change(10, 7, '<B'), change(11, 2, '<B'),
             change(11, 0, '<B'), change(12, 0), change(12, 3), change(12, 8192),
             change(24, 1172), change(24, 1184), change(84, 7), change(88, 0),
             change(20, 0), change(148, 1, '<B'), change(32, 1196),
             change(28, 0), change(92, 0)]:
    rejected(data)
rejected(golden, expected_size=(8, 4))
rejected(golden, expected_sha256='0'*64)
# A base-only image is an explicit opt-in, never silently treated as full mips.
base = bytearray(golden[:1180]);base[11]=0
struct.pack_into('<15I',base,24,*([0]*15));struct.pack_into('<15I',base,88,*([0]*15))
rejected(bytes(base))
assert validate(bytes(base),allow_base_only=True)['mipCount']==1
assert not validate(bytes(base),allow_base_only=True)['fullMipChain']
print('PASS BLP profile: explicit tiny mip blocks, full/base policy, truncation, offsets, overlaps, flags, dimensions and manifest identity')
