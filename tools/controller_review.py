"""Create a private UIForever controller review ZIP with synthetic history.

The complete production package is built separately by package.py. This review
uses production code and a bounded illustration selection to keep browser imports
small. Missing unrelated illustrations do not certify the full artwork library.
"""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]


def controller_locales(addon):
    """Wrap the real catalogs for review without executing their locale guards."""
    output = ['-- Review-only translations; never included in the production package.',
              'local R=assert(MyEpochControllerReview)', '']
    for path in sorted((addon / 'Locales/Controller').glob('*.lua')):
        source = path.read_text(encoding='utf-8')
        marker = 'E.Localize('
        if marker not in source:
            raise ValueError(f'Unsupported controller catalog: {path.name}')
        values = source.split(marker, 1)[1].strip()
        if not values.endswith(')'):
            raise ValueError(f'Unterminated controller catalog: {path.name}')
        # Preserve the actual Lua table, escaping and translations verbatim.
        values = values[:-1].strip()
        if not values.startswith('{') or not values.endswith('}'):
            raise ValueError(f'Expected a plain translation table: {path.name}')
        output.append(f'R.RegisterLocale("{path.stem}",function() return {values} end)')
    return '\n'.join(output) + '\n'


def main():
    addon = ROOT / 'MyEpoch'
    destination = ROOT / '.tools/controller-review.zip'
    destination.parent.mkdir(exist_ok=True)
    toc = (addon / 'MyEpoch.toc').read_text(encoding='utf-8')
    fixture = 'ControllerReview.lua'
    locale_fixture = 'ControllerReviewLocales.lua'
    files = [addon / 'Bindings.xml']
    files += [addon / line for line in toc.splitlines() if line and not line.startswith('#')]
    files += list((addon / 'Media/Book').rglob('*'))
    files += list((addon / 'Licenses').rglob('*'))
    files += [p for p in (addon / 'Media/Illustrations').iterdir()
              if p.name.startswith(('westfall-', 'elwynn-', 'riverglades-'))]
    with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
        archive.writestr('MyEpoch/MyEpoch.toc', toc + '\n' + fixture + '\n' + locale_fixture + '\n')
        for path in files:
            if path.is_file():
                archive.write(path, 'MyEpoch/' + path.relative_to(addon).as_posix())
        archive.write(ROOT / 'tests/fixtures/uiforever-controller.lua', 'MyEpoch/' + fixture)
        archive.writestr('MyEpoch/' + locale_fixture, controller_locales(addon))
    with ZipFile(destination) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(set(archive.namelist()))
        review_toc = archive.read('MyEpoch/MyEpoch.toc').decode('utf-8')
        assert review_toc.endswith(f'{fixture}\n{locale_fixture}\n')
        assert fixture not in toc and locale_fixture not in toc
    print(destination, destination.stat().st_size)


if __name__ == '__main__':
    main()
