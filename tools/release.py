"""Validate release versions and expose safe build metadata to GitHub Actions."""
import argparse
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STABLE = re.compile(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)')
DEVELOPMENT_BASELINE = '0.228.0-dev'


def toc_version(text):
    matches = re.findall(r'^## Version:\s*(\S+)\s*$', text, re.MULTILINE)
    if len(matches) != 1:
        raise ValueError('The TOC must contain exactly one Version field.')
    return matches[0]


def version(root=ROOT):
    current = toc_version((root / 'MyEpoch/MyEpoch.toc').read_text(encoding='utf-8'))
    core = (root / 'MyEpoch/Core.lua').read_text(encoding='utf-8')
    matches = re.findall(r'E\.name, E\.version, E\.schema = addonName, "([^"]+)",', core)
    if matches != [current]:
        raise ValueError('MyEpoch.toc and Core.lua must have the same version.')
    if not STABLE.fullmatch(current) and current != DEVELOPMENT_BASELINE:
        raise ValueError('Use MAJOR.MINOR.PATCH, for example 0.1.0.')
    return current


def transition(previous, current):
    if previous == current:
        return False
    match = STABLE.fullmatch(current)
    if not match:
        raise ValueError('New releases must use MAJOR.MINOR.PATCH without a v prefix.')
    # The original beta used internal build counters, not public release versions.
    if previous == DEVELOPMENT_BASELINE and current == '0.1.0':
        return True
    if previous is not None:
        old = STABLE.fullmatch(previous)
        if not old or tuple(map(int, match.groups())) <= tuple(map(int, old.groups())):
            raise ValueError(f'Release version {current} must be newer than {previous}.')
    return True


def filename(current):
    if not STABLE.fullmatch(current) and current != DEVELOPMENT_BASELINE:
        raise ValueError('Invalid package version.')
    return f'MyEpoch-{current}-Forever.zip'


def check(base, root=ROOT):
    if not re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}', base):
        raise ValueError('The base must be a full Git commit SHA.')
    previous = None
    if set(base) != {'0'}:
        text = subprocess.check_output(
            ['git', 'show', f'{base}:MyEpoch/MyEpoch.toc'], cwd=root, text=True, encoding='utf-8')
        previous = toc_version(text)
    current = version(root)
    return {'changed': str(transition(previous, current)).lower(), 'version': current,
            'tag': f'v{current}', 'filename': filename(current), 'previous': previous or 'none'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', required=True, help='PR base SHA or push before SHA')
    args = parser.parse_args()
    result = check(args.base)
    output = ''.join(f'{key}={value}\n' for key, value in result.items())
    print(output, end='')
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
            stream.write(output)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
            stream.write(f"## My Epoch {result['version']}\n\n")
            stream.write(f"Version: `{result['previous']}` → `{result['version']}`.\n\n")
            stream.write('A versioned addon ZIP will be built.\n' if result['changed'] == 'true'
                         else 'Version unchanged; ZIP and release publication are skipped.\n')


if __name__ == '__main__':
    main()
