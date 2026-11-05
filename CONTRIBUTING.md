# Contributing and releases

The [README](README.md) is the player guide. This file describes the contributor workflow.

## Preparing a release PR

1. Create a branch from `main`.
2. Update `## Version` in `MyEpoch/MyEpoch.toc` and `E.version` in `MyEpoch/Core.lua` to the same **MAJOR.MINOR.PATCH** value, without a `v` prefix.
3. Run the release tests and package checks below, then open a PR targeting `main`.
4. In the PR’s **Checks**, open **Addon release**. Its run summary links the downloadable ZIP artifact. The artifact contains the installable `MyEpoch-<version>-Forever.zip` and its SHA-256 checksum. Extract the outer artifact download first; install the `MyEpoch` folder from the inner addon ZIP.
5. Merge the PR when it is ready. The workflow runs the fast checks and packages the merged commit, creates tag `v<version>` on that exact commit, and publishes a GitHub Release with the ZIP and checksum attached.

The first public release is **0.1.0**. The previous `0.228.0-dev` string was an internal beta build counter; the workflow allows that one-time transition. Afterward, versions must increase: use patches such as `0.1.1` for fixes and minor versions such as `0.2.0` for new features. A `0.x` release remains under active development.

PRs with no version change still run the fast checks but skip ZIP creation. The comparison runs against the PR base commit; on `main`, it compares the pushed commit with the preceding commit. Direct version-changing pushes to `main` also publish, so use PRs for release changes. Merely changing the workflow does not release another copy of the current version.

PR jobs have read-only repository permissions and no release credentials. Publication runs only for `main`, after successful tests and packaging. Existing tags and releases are never overwritten. If publication fails after a draft is created, inspect and finish that draft in GitHub rather than rerunning to replace it. The workflow does not merge PRs or change branch protection. Maintainers can require the **Check release version** check in branch protection; the packaging job is intentionally skipped when the version is unchanged.

PR artifacts expire after seven days. Published release assets remain available separately.

## Keeping CI small

Normal PR opens, code pushes, reopens, and merges run the release/package unit tests plus `tests/ci_smoke.py`. Editing a PR title or description does not start another run. The smoke suite loads every production Lua module and checks startup, character isolation, UI basics, gold/FIFO, inventory, crafting/gathering records, groups, retention controls, completed quests, deferred recaps, and SavedVariables login/reload behavior. Its fixed selection runs in about eleven seconds on the development machine; GitHub checkout/setup and release ZIP creation add time. The smoke step has a two-minute limit, and the containing check job has a five-minute limit.

The exhaustive suite, including the slow auction and large UI fixtures, is **manual only**. In GitHub **Actions**, choose **Full addon tests (manual)**, then **Run workflow** and select the branch. It does not publish or tag a release and has no schedule. Run it before substantial collector, accounting, persistence, or shared-UI changes, or when investigating a regression outside the smoke coverage. It can also run locally with `python -B -X utf8 tests/run.py`. No full-suite result is required by the automatic release workflow; the smaller gate trades exhaustive coverage for lower routine runner usage.

Version-changing PRs and merges still validate generated catalogs, artwork checksums, installable paths, and the ZIP. Those release safeguards are separate from the slow Lua regressions and remain enabled. Both PR and merged commits get the fast checks; an unversioned PR does not upload another large artwork archive.

## CurseForge automatic packaging

The project is [ME: My Epoch, ID 1785036](https://www.curseforge.com/wow/addons/me-my-epoch). Its Source setting uses this GitHub repository and **tagged commits only**. `.pkgmeta` moves the nested source folder into the installable `MyEpoch/` directory and excludes developer tools, fixtures and source evidence. The TOC records the project ID. Finished artwork and bundled licenses remain included.

The post-merge workflow pushes `v<version>` only after tests and ZIP validation succeed. That push must reach a repository webhook configured according to [CurseForge's automatic packaging instructions](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging), using this project's ID and a CurseForge API token. Keep that token out of the repository, logs and screenshots. Subscribe only to push events and leave SSL verification enabled. PR branches do not receive release tags.

The GitHub Release and CurseForge file are separate outputs. Confirm the first tag's successful delivery in GitHub Webhooks, then inspect CurseForge Builds and Files for the correct folder layout and Forever game version. New projects/files may wait for CurseForge moderation. A saved Source setting alone does not prove a successful package. If release publication fails after the tag push, inspect the existing tag and finish that same release manually; do not move or replace the tag.

## Localization

`MyEpoch/Localization.lua` selects the client locale and provides an English fallback. Locale tables live in `MyEpoch/Locales/`; `esMX` shares `esES`, and `enGB` shares `enUS`. The initial Portuguese translation is Brazilian Portuguese (`ptBR`). Only the active table is loaded into memory.

Translate the intention, not the English syntax. My Epoch should sound like a warm, easygoing scrapbook with a little whimsy. Adapt metaphors, rhythm, and idioms when a literal version would feel awkward. Keep action labels short and unmistakable; do not sacrifice clarity to make every button poetic. Use terminology familiar to players of that WoW language. These initial translations still welcome native-speaker review.

Use explicit `E.L[key]` lookups at presentation boundaries. Keep record IDs, chapter keys, filter IDs, slash commands, player names, item links, saved chat, and personal writing unchanged. Do not translate arbitrary text globally in shared rendering helpers. Full sentences with named placeholders (`E.Format`) allow translators to reorder words; preserve every placeholder name. Use `E.Count` and the locale's plural families for counts, and `E.LocaleDate` for Calendar dates. Russian count forms and date-month cases are separate. Use `E.Font()` to respect Blizzard's locale-specific alphabet fonts.

The catalogs cover all eleven chapters and their detail views. Shared messages live in the base locale files; domain catalogs live in subdirectories under `Locales/` and are listed in the TOC. Keep each language's key set and named placeholders aligned. Illustration catalog prose and legacy prose-only entries remain untranslated.

`Display.lua` resolves current-client names using recorded IDs, falling back to captured names without mutating history. `DiaryPresentation.lua` renders saved facts and linked sources in the active language through bounded work; it never replaces saved prose or personal notes. Preserve that distinction when adding translations.

Run `python -B -X utf8 tests/localization_host.py` after locale changes. It checks every supported client locale, aliases, fallback, placeholder preservation, plural forms, UI callbacks, and unchanged player text. It is also part of the fast CI suite. Verify long labels and non-Latin glyphs visually in the target client; host tests cannot prove font rendering.

## Running local checks

Use Python 3.13 or newer and Git. Create a virtual environment, then run:

```text
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -p test_release.py -v
python -B -X utf8 tests/ci_smoke.py
python -B -X utf8 tools/package.py
```

The package command validates version agreement, generated quest/crafting/auction data, artwork checksums, TOC paths, and the AddOns-menu icon. It produces a versioned ZIP and checksum in `dist/`. Only runtime addon files, finished artwork, bindings, and bundled licenses are shipped. Private `docs/` and `design/` folders are optional and are not needed by CI or the release package.

The Lua tests exercise behavior outside the game; they do not replace in-game checks for rendering, event timing, combat restrictions, and persistence. The release workflow does not change the client interface or SavedVariables schema.

Calendar fixtures use New York's daylight-saving boundaries. CI sets `TZ=America/New_York`; use that timezone when running the complete suite locally as well. The addon itself continues to use each player's local time.

Workflow behavior follows GitHub’s [artifact documentation](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts) and [release creation command](https://cli.github.com/manual/gh_release_create).
