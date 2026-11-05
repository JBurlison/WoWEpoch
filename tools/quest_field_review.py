"""Withhold disputed imported claims, preserving independently supported base maps."""
import hashlib
import json

REVIEW_SHA256 = 'c9cafd44b9b75a88076dbf476bab24a69364380d3dccfb22efc76ac42b34b111'
RULES = {'minLevel', 'faction', 'classIDs', 'raceIDs', 'profession'}


def apply(quests, review_path):
    data = review_path.read_bytes()
    if hashlib.sha256(data).hexdigest() != REVIEW_SHA256:
        raise ValueError('Field review hash mismatch')
    decisions = json.loads(data)['decisions']
    matched = 0
    for quest in quests:
        review = decisions.get(str(quest['questID']))
        if not review:
            continue
        disputes = quest.setdefault('sourceDisputes', {})
        for field in review['fields']:
            disputes[field] = True
            if field == 'offer':
                continue  # A reported non-offer at the catalog giver leaves the quest in history.
            if field == 'mapIDs':
                original = quest.pop('mapIDs')
                retained = review['retainBaseMaps']
                if retained != sorted(set(retained)) or not set(retained).issubset(original):
                    raise ValueError('A retained map must originate in the base provider')
                if retained:
                    quest['mapIDs'] = retained
            elif field in RULES:
                del quest['eligibility'][field]
            elif field in ('starts', 'repeatable'):
                del quest[field]
            else:
                raise ValueError('Unrecognized field review key')
        matched += 1
    if matched != len(decisions):
        raise ValueError('Field review references an absent base quest')
    return matched
