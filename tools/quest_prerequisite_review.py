"""Withhold unsupported base edges while preserving shared base IDs as possible links."""
import hashlib
import json

REVIEW_SHA256 = 'f60a2fa98efd545d2b99c5742a230a06b190479eae08606df1d867b544b5d3bc'

def apply(quests, review_path):
    data = review_path.read_bytes()
    if hashlib.sha256(data).hexdigest() != REVIEW_SHA256:
        raise ValueError('Prerequisite review hash mismatch')
    decisions = json.loads(data)['decisions']
    matched = 0
    for quest in quests:
        review = decisions.get(str(quest['questID']))
        if not review:
            continue
        members = quest.pop('prerequisiteCandidates', None)
        for key in ('requiresAll', 'requiresAny', 'prerequisiteThreshold'):
            relation = quest.pop(key, None)
            if relation is not None:
                if members is not None:
                    raise ValueError('Prerequisite review expected one base relation')
                members = relation['questIDs'] if key=='prerequisiteThreshold' else relation
        retained = review['retainBaseIDs']
        if not members or retained != sorted(set(retained)) or not set(retained).issubset(members):
            raise ValueError('A reviewed edge must originate in the base provider')
        if retained:
            quest['prerequisiteCandidates'] = [i for i in members if i in retained]
        quest.setdefault('sourceDisputes', {})['prerequisites'] = True
        matched += 1
    if matched != len(decisions):
        raise ValueError('Review contains an absent base quest')
    return matched
