"""Focused combat/memory regressions, kept outside the inexpensive PR gate."""
from quest_zone_entry_host import run
if __name__ == '__main__':
    run(('pull_links_spec.lua','pull_details_spec.lua','memory_location_spec.lua','pull_lifetime_spec.lua','pull_detail_trim_spec.lua'))
