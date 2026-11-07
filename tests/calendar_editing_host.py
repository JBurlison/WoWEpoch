"""Focused local scrapbook regressions; deliberately not added to the PR gate."""
from quest_zone_entry_host import run

if __name__ == '__main__':
    run(('calendar_stable_editing_spec.lua', 'calendar_play_preparation_spec.lua',
         'calendar_preparation_spec.lua', 'journal_views_work_spec.lua',
         'memory_editor_art_spec.lua', 'memory_prompt_dropdown_spec.lua',
         'personal_record_rows_spec.lua', 'recap_heading_spec.lua', 'source_filters_spec.lua'))
