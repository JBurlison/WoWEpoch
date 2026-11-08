"""Closed-journal recording and scratch lifetime in fresh production-TOC VMs."""
from time import perf_counter
from quest_zone_entry_host import run

SPECS = (
    'journal_closed_recording_spec.lua',
    'journal_background_scratch_spec.lua',
    'notification_idle_spec.lua',
    'mob_drop_memory_spec.lua',
    'saved_pages_memory_spec.lua',
)

if __name__ == '__main__':
    started = perf_counter()
    run(SPECS)
    print(f'PASS journal memory lifecycle: {perf_counter() - started:.2f}s')
