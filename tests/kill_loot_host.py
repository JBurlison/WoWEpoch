"""Focused kill/loot checks, intentionally outside the small PR smoke gate."""
from quest_zone_entry_host import run
if __name__ == '__main__':
    run(('kill_loot_spec.lua', 'kill_loot_view_spec.lua', 'loot_receipt_source_spec.lua', 'mob_drops_spec.lua', 'pull_links_spec.lua'))
