"""Inventory the complete approved scope; partial work never becomes a completed feature."""
import json
import re
from html import unescape
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'design/requirements.html').read_text(encoding='utf-8')
evidence = {
    'ART': ['MyEpoch/ArtCatalog.lua', 'MyEpoch/Artwork.lua', 'MyEpoch/ArtView.lua', 'tests/artwork_spec.lua', 'tests/memory_art_spec.lua', 'docs/memory-art-evidence.md', 'docs/wetlands-art-evidence.md', 'docs/illustration-evidence.md', 'docs/illustration-loading-evidence.md', 'docs/loch-modan-art-evidence.md', 'design/art-matrix.json', 'tools/build-art-catalog.py'],
    'RCP': ['MyEpoch/Diary.lua', 'MyEpoch/JournalJobs.lua', 'tests/recaps_spec.lua'],
    'TIME': ['MyEpoch/History.lua', 'MyEpoch/Query.lua', 'tests/core_spec.lua'],
    'PROD': ['MyEpoch/GatherActions.lua', 'tests/gather_actions_spec.lua', 'docs/gather-actions-evidence.md', 'MyEpoch/Gathering.lua', 'tests/gathering_spec.lua', 'docs/gathering-evidence.md', 'MyEpoch/History.lua', 'MyEpoch/Forever.lua', 'MyEpoch/Items.lua', 'MyEpoch/LootView.lua', 'MyEpoch/Production.lua', 'MyEpoch/ProductionView.lua', 'tests/core_spec.lua', 'tests/items_spec.lua', 'tests/production_spec.lua'],
    'QK': ['MyEpoch/History.lua', 'MyEpoch/Store.lua', 'tests/core_spec.lua'],
    'QST': ['MyEpoch/Collectors.lua', 'MyEpoch/History.lua', 'MyEpoch/QuestCatalog.lua', 'MyEpoch/QuestAtlas.lua', 'MyEpoch/QuestView.lua', 'tests/history_coverage_spec.lua', 'tests/quest_atlas_spec.lua'],
    'WIN': ['MyEpoch/Book.lua', 'MyEpoch/BookTheme.lua', 'tools/build-book-skin.cjs', 'tests/integration_spec.lua', 'docs/native-skin-evidence.md'],
    'CAL': ['MyEpoch/Book.lua'],
    'MIL': ['MyEpoch/Collectors.lua', 'MyEpoch/Query.lua', 'MyEpoch/Progress.lua', 'tests/progress_spec.lua'],
    'CHR': ['MyEpoch/Book.lua', 'MyEpoch/Query.lua', 'tests/chronicle_view_spec.lua', 'docs/native-skin-evidence.md'],
    'GRP': ['MyEpoch/History.lua', 'MyEpoch/Collectors.lua', 'MyEpoch/Company.lua', 'MyEpoch/CompanyView.lua', 'MyEpoch/Social.lua', 'tests/company_spec.lua'],
    'CHAT': ['MyEpoch/Collectors.lua', 'MyEpoch/SearchView.lua', 'MyEpoch/Company.lua', 'MyEpoch/CompanyView.lua', 'tests/company_spec.lua'],
    'LOOT': ['MyEpoch/GatherActions.lua', 'tests/gather_actions_spec.lua', 'docs/gather-actions-evidence.md', 'MyEpoch/Gathering.lua', 'tests/gathering_spec.lua', 'docs/gathering-evidence.md', 'MyEpoch/Collectors.lua', 'MyEpoch/Items.lua', 'MyEpoch/LootView.lua', 'MyEpoch/Drops.lua', 'MyEpoch/DropView.lua', 'tests/items_spec.lua', 'tests/drops_spec.lua'],
    'GOLD': ['MyEpoch/History.lua', 'MyEpoch/Query.lua', 'MyEpoch/Economy.lua', 'MyEpoch/FinanceView.lua', 'MyEpoch/Merchant.lua', 'MyEpoch/Mail.lua', 'MyEpoch/MailMoney.lua', 'MyEpoch/MailView.lua', 'tests/mail_spec.lua', 'docs/mail-history-evidence.md', 'tests/merchant_spec.lua', 'tests/economy_spec.lua'],
    'FIN': ['MyEpoch/Economy.lua', 'MyEpoch/FinanceView.lua', 'MyEpoch/Inventory.lua', 'MyEpoch/InventoryView.lua', 'MyEpoch/MailCosts.lua', 'MyEpoch/Auctions.lua', 'MyEpoch/AuctionView.lua', 'tests/auction_posts_spec.lua', 'docs/auction-posting-evidence.md', 'MyEpoch/AuctionCosts.lua', 'tests/auction_costs_spec.lua', 'docs/auction-costs-evidence.md', 'tests/mail_costs_spec.lua', 'docs/mail-costs-evidence.md', 'tests/economy_spec.lua', 'tests/finance_view_spec.lua', 'tests/inventory_spec.lua', 'docs/inventory-evidence.md'],
    'MEM': ['MyEpoch/Book.lua', 'MyEpoch/Collectors.lua', 'MyEpoch/Memories.lua', 'MyEpoch/MemoryView.lua', 'MyEpoch/Capture.lua', 'MyEpoch/Bindings.xml', 'tests/memories_spec.lua', 'tests/memory_art_spec.lua', 'docs/memory-art-evidence.md'],
    'OTD': ['MyEpoch/Memories.lua', 'MyEpoch/MemoryView.lua', 'tests/memories_spec.lua', 'tests/memory_art_spec.lua', 'docs/memory-art-evidence.md'],
    'RET': ['MyEpoch/Store.lua', 'MyEpoch/Archive.lua', 'MyEpoch/ArchiveView.lua', 'MyEpoch/Economy.lua', 'tests/core_spec.lua', 'tests/retention_archive_spec.lua', 'docs/archive-evidence.md'],
    'SRCH': ['MyEpoch/Search.lua', 'MyEpoch/SearchView.lua', 'MyEpoch/Book.lua', 'tests/search_spec.lua'],
    'DAY': ['MyEpoch/Diary.lua', 'MyEpoch/Book.lua'],
    'JNY': ['MyEpoch/Journey.lua', 'MyEpoch/JourneyView.lua', 'MyEpoch/Forever.lua', 'tests/journey_spec.lua'],
}
out = ROOT / 'docs/implementation-matrix.json'
previous = {r['id']: r for r in json.loads(out.read_text(encoding='utf-8')).get('requirements', [])} if out.exists() else {}
rows = []
for code, body in re.findall(r'<li><strong>([A-Z]+-\d+):</strong>(.*?)</li>', source, re.S):
    files = evidence.get(code.split('-')[0], [])
    requirement = unescape(re.sub('<[^>]*>', '', body)).strip()
    row = previous.get(code, {'id': code, 'status': 'partial' if files else 'pending',
                             'in_game_validation': 'not run', 'completion_proven': False})
    if row.get('requirement', requirement) != requirement:
        row.update(completion_proven=False, status='partial' if files else 'pending', review='Requirement changed; review evidence again')
    row['requirement'] = requirement
    row['evidence'] = sorted(set(row.get('evidence', []) + files))
    rows.append(row)
assert rows and len({r['id'] for r in rows}) == len(rows)
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps({'scope': 'Full approved My Epoch requirements; no scope reduction', 'requirements': rows}, indent=2, ensure_ascii=False), encoding='utf-8')
print(f'Inventoried {len(rows)} requirements. No feature is certified complete by source presence alone.')
