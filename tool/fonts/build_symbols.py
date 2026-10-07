"""Builds assets/fonts/noto_sans_math/TabiyaSymbols-Regular.ttf (T-04).

A subset of Noto Sans Math (SIL OFL 1.1, no Reserved Font Name) with the chess
annotation (NAG) and math symbols that Inter lacks. Requires fonttools.

    curl -sSLO https://github.com/google/fonts/raw/main/ofl/notosansmath/NotoSansMath-Regular.ttf
    python3 tool/fonts/build_symbols.py NotoSansMath-Regular.ttf
"""
import sys
from fontTools import subset
from fontTools.ttLib import TTFont

CHARS = "⩲⩱∓⨀⟳⇆□±∞↑→⊕∆⇄⇅⟲⊞○◯⇈↗⇔⊗⊡⊠⌓∇⇕⇓⇑⇗⇘−×÷≈≠≤≥∀∃∈√∑∏∫⊥∥"

src = sys.argv[1] if len(sys.argv) > 1 else 'NotoSansMath-Regular.ttf'
opts = subset.Options()
opts.layout_features = ['*']
opts.name_IDs = ['*']
opts.notdef_outline = True
font = TTFont(src)
s = subset.Subsetter(opts)
s.populate(unicodes=[ord(c) for c in set(CHARS)])
s.subset(font)
names = {1: 'Tabiya Symbols', 16: 'Tabiya Symbols', 4: 'Tabiya Symbols Regular', 6: 'TabiyaSymbols-Regular'}
for rec in font['name'].names:
    if rec.nameID in names:
        rec.string = names[rec.nameID]
font.save('assets/fonts/noto_sans_math/TabiyaSymbols-Regular.ttf')
print('ok')
