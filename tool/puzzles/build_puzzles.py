"""Builds assets/puzzles/puzzles.tsv.gz, the offline puzzle pack (D-126),
from the Lichess puzzle database (CC0, https://database.lichess.org/#puzzles).

Usage:
  curl -o /tmp/lichess_db_puzzle.csv.zst https://database.lichess.org/lichess_db_puzzle.csv.zst
  python3 tool/puzzles/build_puzzles.py /tmp/lichess_db_puzzle.csv.zst [count]

Needs the `zstd` command. The database (~300 MB) is not kept in the repo.

Selection: only well-tested puzzles (rating deviation <= 80, popularity
>= 85, >= 300 plays; the more played and liked first), spread evenly over
every theme of the app and every 200 points of rating, so a theme has
puzzles for a beginner and for a master alike. A quota per (theme, band)
is searched so that about `count` puzzles (default 50 000) come out.

Output, one puzzle per line, tab separated:
  id  FEN  moves  rating  deviation  themes
FEN is the position before the opponent's move; `moves` are UCI, the
first is the opponent's, the rest the solution (as in the database).
Themes are those of the app only (lib/domain/puzzles/puzzle_themes.dart).
"""
import csv
import gzip
import hashlib
import io
import os
import re
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
OUT = os.path.join(ROOT, 'assets', 'puzzles', 'puzzles.tsv.gz')


def app_themes():
    src = open(os.path.join(ROOT, 'lib', 'domain', 'puzzles', 'puzzle_themes.dart'), encoding='utf-8').read()
    block = src[src.index('kPuzzleThemes'):src.index('};', src.index('kPuzzleThemes'))]
    keys = set(re.findall(r"'([A-Za-z0-9]+)'", block))
    keys.discard('mix')
    return keys


def rows(path):
    p = subprocess.Popen(['zstd', '-dc', path], stdout=subprocess.PIPE)
    reader = csv.reader(io.TextIOWrapper(p.stdout, encoding='utf-8'))
    next(reader)
    yield from reader
    p.wait()


def band(rating):
    return max(0, min(13, (rating - 400) // 200))


def main():
    path = sys.argv[1]
    target = int(sys.argv[2]) if len(sys.argv) > 2 else 50000
    themes = app_themes()
    index = {t: i for i, t in enumerate(sorted(themes))}

    # Pass 1: candidates, best first.
    cands = []
    for r in rows(path):
        rd, pop, plays = int(r[4]), int(r[5]), int(r[6])
        if rd > 80 or pop < 85 or plays < 300:
            continue
        ts = tuple(index[t] for t in r[7].split() if t in index)
        if not ts:
            continue
        strict = pop >= 90 and plays >= 1000
        # Stable shuffle inside a quality tier: not only the most played.
        h = int(hashlib.md5(r[0].encode()).hexdigest()[:8], 16)
        cands.append(((0 if strict else 1), h, r[0], band(int(r[3])), ts))
    cands.sort()
    print(f'{len(cands)} candidates', file=sys.stderr)

    def select(quota):
        filled = {}
        chosen = []
        for _, _, pid, b, ts in cands:
            if any(filled.get((t, b), 0) < quota for t in ts):
                chosen.append(pid)
                for t in ts:
                    filled[(t, b)] = filled.get((t, b), 0) + 1
        return chosen

    lo, hi = 1, 2000
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if len(select(mid)) <= target:
            lo = mid
        else:
            hi = mid - 1
    chosen = set(select(lo))
    print(f'quota {lo} per theme and band: {len(chosen)} puzzles', file=sys.stderr)

    # Pass 2: write the chosen ones, by rating (neighbours compress well).
    out = []
    for r in rows(path):
        if r[0] in chosen:
            ts = ' '.join(t for t in r[7].split() if t in themes)
            out.append((int(r[3]), '\t'.join([r[0], r[1], r[2], r[3], r[4], ts])))
    out.sort()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with gzip.open(OUT, 'wt', encoding='utf-8', compresslevel=9) as f:
        f.write('\n'.join(line for _, line in out))
        f.write('\n')
    print(f'wrote {len(out)} puzzles, {os.path.getsize(OUT)} bytes', file=sys.stderr)


if __name__ == '__main__':
    main()
