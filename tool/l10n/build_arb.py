"""Generates lib/l10n/app_en.arb and app_uk.arb from the string tables.

Usage: python3 tool/l10n/build_arb.py
"""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from strings_a import S
import strings_b, strings_c, strings_d, strings_e, strings_f, strings_arb, strings_g  # noqa: F401  (register strings)

en = {'@@locale': 'en'}
uk = {'@@locale': 'uk'}
for key, (e, u, ph) in S.items():
    en[key] = e
    uk[key] = u
    if ph:
        en['@' + key] = {'placeholders': {n: {'type': t} for n, t in ph.items()}}
    # sanity: placeholders used in both texts
    for n in ph:
        for txt, lang in ((e, 'en'), (u, 'uk')):
            if '{' + n not in txt:
                print(f'WARNING {key} ({lang}) does not use {{{n}}}')
# T-19: Ukrainian apostrophe ʼ (U+02BC), no dashes in UI texts.
bad = []
for key, (e, u, ph) in S.items():
    for ch, name in (('’', 'U+2019 apostrophe'), ('—', 'em dash'), ('–', 'en dash')):
        if ch in u or ch in e:
            bad.append(f'{key}: {name}')
    if re.search(r"[А-Яа-яЇїІіЄєҐґ]'[А-Яа-яЇїІіЄєҐґ]", u):
        bad.append(f'{key}: ASCII apostrophe in Ukrainian')
if bad:
    sys.exit('Typography errors:\n' + '\n'.join(bad))
root = os.path.join(os.path.dirname(__file__), '..', '..', 'lib', 'l10n')
with open(os.path.join(root, 'app_en.arb'), 'w', encoding='utf-8') as f:
    json.dump(en, f, ensure_ascii=False, indent=2)
with open(os.path.join(root, 'app_uk.arb'), 'w', encoding='utf-8') as f:
    json.dump(uk, f, ensure_ascii=False, indent=2)
print(f'{len(S)} strings')
