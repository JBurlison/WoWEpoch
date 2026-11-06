"""Focused richer-memory regressions; optional locally, included in manual full tests."""
from time import perf_counter
from quest_zone_entry_host import run

SPECS = (
    'keepsakes_spec.lua', 'keepsake_view_spec.lua',
    'comparison_view_spec.lua', 'item_stories_spec.lua',
    'chapters_spec.lua', 'chapter_view_spec.lua', 'chapters_retention_spec.lua',
    'wishes_spec.lua', 'wish_sharing_spec.lua', 'wish_view_spec.lua',
    'personal_records_spec.lua', 'notifications_spec.lua',
    'richer_integration_spec.lua',
)

if __name__ == '__main__':
    started = perf_counter()
    run(SPECS)
    print(f'PASS richer memories: {perf_counter() - started:.2f}s')
