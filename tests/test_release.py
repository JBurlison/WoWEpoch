"""Release behavior and installable archive regressions; no game/private files needed."""
import hashlib
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import release
spec = importlib.util.spec_from_file_location('addon_package', ROOT / 'tools/package.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class ReleaseTests(unittest.TestCase):
    def test_curseforge_layout_matches_runtime_payload(self):
        metadata = (ROOT / '.pkgmeta').read_text(encoding='utf-8')
        self.assertIn('package-as: MyEpoch\n', metadata)
        self.assertIn('  MyEpoch/MyEpoch: MyEpoch\n', metadata)
        self.assertIn('enable-nolib-creation: no\n', metadata)
        ignored = {line.strip()[2:] for line in metadata.split('ignore:\n', 1)[1].splitlines()
                   if line.strip().startswith('- ')}
        tracked = subprocess.check_output(['git', 'ls-files'], cwd=ROOT, text=True).splitlines()
        shipped = {name for name in tracked if not name.startswith('.')
                   and name.split('/')[0] not in ignored}
        expected = {'MyEpoch/' + path.relative_to(ROOT / 'MyEpoch').as_posix()
                    for path in package.package_files(ROOT / 'MyEpoch')}
        self.assertEqual(shipped, expected, 'CurseForge must exclude all development files and retain every runtime asset')
        self.assertIn('## X-Curse-Project-ID: 1785036', (ROOT / 'MyEpoch/MyEpoch.toc').read_text())

    def fixture(self, version='0.1.0'):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        addon = root / 'MyEpoch'
        (addon / 'Media/Book').mkdir(parents=True)
        (addon / 'Licenses').mkdir()
        (addon / 'MyEpoch.toc').write_text(
            '## Version: ' + version + '\n## SavedVariables: MyEpochDB\n'
            '## IconTexture: Interface\\AddOns\\MyEpoch\\Media\\Book\\emblem-small-v1.tga\n\nCore.lua\n', encoding='utf-8')
        (addon / 'Core.lua').write_text(
            f'E.name, E.version, E.schema = addonName, "{version}", 1\n', encoding='utf-8')
        (addon / 'Bindings.xml').write_text('<Bindings/>', encoding='utf-8')
        (addon / 'Media/Book/emblem-small-v1.tga').write_bytes(b'icon fixture')
        (addon / 'Licenses/library.txt').write_text('license fixture', encoding='utf-8')
        return root

    def test_beta_counter_can_become_first_public_release(self):
        self.assertTrue(release.transition('0.228.0-dev', '0.1.0'))
        with self.assertRaises(ValueError):
            release.transition('0.228.0-dev', '0.0.1')

    def test_unchanged_version_skips_release(self):
        self.assertFalse(release.transition('0.1.0', '0.1.0'))
        self.assertFalse(release.transition('0.228.0-dev', '0.228.0-dev'))

    def test_increasing_semantic_versions(self):
        for before, after in [('0.1.0','0.1.1'), ('0.9.9','0.10.0'), ('0.2.1','1.0.0')]:
            self.assertTrue(release.transition(before, after))
        for before, after in [('0.2.0','0.1.9'), ('1.0.0','0.1.0')]:
            with self.assertRaises(ValueError):
                release.transition(before, after)

    def test_invalid_versions_cannot_reach_filenames_or_actions_outputs(self):
        for bad in ['v0.1.0','0.01.0','0.1','0.1.0-beta','../bad','0.1.0\nchanged=true']:
            with self.assertRaises(ValueError):
                release.transition('0.1.0', bad)
            with self.assertRaises(ValueError):
                release.filename(bad)

    def test_version_mismatch_and_duplicate_metadata_fail(self):
        root = self.fixture()
        self.assertEqual(release.version(root), '0.1.0')
        core = root / 'MyEpoch/Core.lua'
        core.write_text(core.read_text().replace('0.1.0','0.2.0'))
        with self.assertRaises(ValueError):
            release.version(root)
        with self.assertRaises(ValueError):
            release.toc_version('## Version: 0.1.0\n## Version: 0.1.1\n')

    def test_compare_actual_git_base_and_zero_base(self):
        root = self.fixture('0.228.0-dev')
        def git(*args):
            return subprocess.check_output(['git', *args], cwd=root, text=True, stderr=subprocess.DEVNULL).strip()
        git('init')
        git('add', '.')
        git('-c', 'user.name=Release Test', '-c', 'user.email=release@example.invalid', 'commit', '-m', 'beta')
        base = git('rev-parse', 'HEAD')
        self.assertEqual(release.check(base, root)['changed'], 'false')
        for name in ['MyEpoch.toc','Core.lua']:
            p = root / 'MyEpoch' / name
            p.write_text(p.read_text().replace('0.228.0-dev','0.1.0'))
        result = release.check(base, root)
        self.assertEqual(result['changed'], 'true')
        self.assertEqual(result['tag'], 'v0.1.0')
        self.assertEqual(result['filename'], 'MyEpoch-0.1.0-Forever.zip')
        self.assertEqual(release.check('0'*40, root)['changed'], 'true')
        with self.assertRaises(ValueError):
            release.check('main;echo anything', root)

    def test_archive_contains_only_installable_files_and_checksum(self):
        root = self.fixture()
        (root / 'private.txt').write_text('not shipped')
        (root / 'MyEpoch/Unused.lua').write_text('not in TOC')
        destination = package.write_package(root, release.version(root))
        with ZipFile(destination) as archive:
            self.assertEqual(set(archive.namelist()), {
                'MyEpoch/MyEpoch.toc','MyEpoch/Core.lua','MyEpoch/Bindings.xml',
                'MyEpoch/Media/Book/emblem-small-v1.tga','MyEpoch/Licenses/library.txt'})
            self.assertIn(b'## Version: 0.1.0', archive.read('MyEpoch/MyEpoch.toc'))
        self.assertEqual(destination.with_suffix('.zip.sha256').read_text().split()[0],
                         hashlib.sha256(destination.read_bytes()).hexdigest())

    def test_missing_icon_or_toc_files_fail(self):
        root = self.fixture()
        (root / 'MyEpoch/Media/Book/emblem-small-v1.tga').unlink()
        with self.assertRaises(ValueError):
            package.package_files(root / 'MyEpoch')
        (root / 'MyEpoch/Core.lua').unlink()
        with self.assertRaises(ValueError):
            package.package_files(root / 'MyEpoch')

    def test_toc_cannot_escape_or_duplicate_package_paths(self):
        for entry in ['../outside.lua','Core.lua']:
            root = self.fixture()
            (root / 'outside.lua').write_text('outside')
            toc = root / 'MyEpoch/MyEpoch.toc'
            toc.write_text(toc.read_text()+entry+'\n')
            with self.assertRaises(ValueError):
                package.package_files(root / 'MyEpoch')


if __name__ == '__main__':
    unittest.main()
