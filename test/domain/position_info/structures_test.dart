import 'dart:convert';
import 'dart:io';

import 'package:dartchess/dartchess.dart' hide File;
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/position_info/structures.dart';

/// Pawn structures (D-107): every structure is recognised in its typical
/// positions, for both colours, and not in near misses.

/// A position with only these pawns (and kings in the corners).
Board pawns(List<String> white, List<String> black) {
  final grid = List.generate(8, (_) => List<String?>.filled(8, null));
  void put(String sq, String piece) => grid[int.parse(sq[1]) - 1][sq.codeUnitAt(0) - 97] = piece;
  for (final s in white) {
    put(s, 'P');
  }
  for (final s in black) {
    put(s, 'p');
  }
  grid[0][7] ??= 'K';
  if (grid[0][7] != 'K') grid[0][0] = 'K';
  grid[7][7] ??= 'k';
  if (grid[7][7] != 'k') grid[7][0] = 'k';
  final rows = <String>[];
  for (var r = 7; r >= 0; r--) {
    var row = '', empty = 0;
    for (final c in grid[r]) {
      if (c == null) {
        empty++;
      } else {
        if (empty > 0) row += '$empty';
        empty = 0;
        row += c;
      }
    }
    if (empty > 0) row += '$empty';
    rows.add(row);
  }
  return Board.parseFen(rows.join('/'));
}

Board line(String sans) {
  Position p = Chess.initial;
  for (final san in sans.split(' ')) {
    p = p.play(p.parseSan(san) ?? (throw ArgumentError('bad move $san in $sans')));
  }
  return p.board;
}

/// The same position with the colours swapped and the board turned over.
Board mirror(Board b) {
  final fen = b.fen.split('/').reversed.map((r) {
    return String.fromCharCodes(r.codeUnits.map((c) {
      final s = String.fromCharCode(c);
      return (s.toUpperCase() == s ? s.toLowerCase() : s.toUpperCase()).codeUnitAt(0);
    }));
  }).join('/');
  return Board.parseFen(fen);
}

typedef Case = (Board board, Side side);

final positives = <String, List<Case>>{
  'hanging_pawns': [
    (pawns(['a2', 'c4', 'd4', 'f2', 'g2', 'h2'], ['a7', 'b6', 'e6', 'f7', 'g7', 'h7']), Side.white),
    (pawns(['a2', 'b2', 'e3', 'f2', 'g2', 'h2'], ['a7', 'c5', 'd5', 'f7', 'g7', 'h7']), Side.black),
    (pawns(['a3', 'c4', 'd4', 'g3', 'h2'], ['a6', 'f7', 'g6', 'h7']), Side.white),
  ],
  'isolated_queen_pawn': [
    (line('e4 c6 d4 d5 exd5 cxd5 c4 Nf6 Nc3 e6 Nf3 Be7 cxd5 Nxd5'), Side.white),
    (line('d4 d5 c4 e6 Nc3 c5 cxd5 exd5 Nf3 Nc6 g3 Nf6 Bg2 Be7 O-O O-O dxc5 Bxc5'), Side.black),
    (pawns(['a2', 'b2', 'd4', 'f2', 'g2', 'h2'], ['a7', 'b7', 'e6', 'f7', 'g7', 'h7']), Side.white),
  ],
  'hedgehog': [
    (pawns(['a2', 'b2', 'c4', 'e4', 'f2', 'g2', 'h2'], ['a6', 'b6', 'd6', 'e6', 'f7', 'g7', 'h7']), Side.black),
    (pawns(['a3', 'b2', 'c4', 'e4', 'f2', 'g3', 'h2'], ['a6', 'b6', 'd6', 'e6', 'f7', 'g6', 'h7']), Side.black),
    (pawns(['a3', 'b3', 'd3', 'e3', 'f2', 'g2', 'h2'], ['a7', 'b7', 'c5', 'e5', 'f7', 'g7', 'h7']), Side.white),
  ],
  'maroczy_bind': [
    (pawns(['a2', 'b2', 'c4', 'e4', 'f2', 'g2', 'h2'], ['a7', 'b7', 'd6', 'e7', 'f7', 'g6', 'h7']), Side.white),
    (line('e4 c5 Nf3 Nc6 d4 cxd4 Nxd4 g6 c4'), Side.white),
    (pawns(['a3', 'b2', 'c4', 'e4', 'f3', 'g2', 'h2'], ['a6', 'b7', 'd6', 'e7', 'f7', 'g6', 'h7']), Side.white),
  ],
  'stonewall': [
    (pawns(['a2', 'b2', 'c3', 'd4', 'e3', 'f4', 'g2', 'h2'], ['a7', 'b7', 'c7', 'd5', 'e6', 'f7', 'g7', 'h7']), Side.white),
    (line('d4 f5 c4 Nf6 g3 e6 Bg2 d5 Nf3 c6'), Side.black),
    (pawns(['a2', 'b2', 'c2', 'd3', 'e4', 'f2', 'g2', 'h2'], ['a7', 'b7', 'c6', 'd5', 'e6', 'f5', 'g7', 'h7']), Side.black),
  ],
  'carlsbad': [
    (line('d4 d5 c4 e6 Nc3 Nf6 cxd5 exd5 Bg5 c6'), Side.white),
    (pawns(['a2', 'b2', 'd4', 'e3', 'f2', 'g2', 'h2'], ['a7', 'b7', 'c6', 'd5', 'f7', 'g7', 'h7']), Side.white),
    (pawns(['a2', 'b2', 'c3', 'd4', 'f2', 'g2', 'h2'], ['a7', 'b7', 'd5', 'e6', 'f7', 'g7', 'h7']), Side.black),
  ],
  'benoni': [
    (line('d4 Nf6 c4 c5 d5 e6 Nc3 exd5 cxd5 d6'), Side.white),
    (pawns(['a2', 'b2', 'c4', 'd5', 'e4', 'f2', 'g2', 'h2'], ['a7', 'b7', 'c5', 'd6', 'f7', 'g7', 'h7']), Side.white),
    (pawns(['a2', 'b2', 'c4', 'd5', 'f2', 'g2', 'h2'], ['a7', 'b7', 'c5', 'd6', 'f7', 'g6', 'h7']), Side.white),
  ],
  'kings_indian_chain': [
    (line('d4 Nf6 c4 g6 Nc3 Bg7 e4 d6 Nf3 O-O Be2 e5 O-O Nc6 d5'), Side.white),
    (pawns(['a2', 'b2', 'c4', 'd5', 'e4', 'f2', 'g2', 'h2'], ['a7', 'b7', 'c7', 'd6', 'e5', 'f7', 'g7', 'h7']), Side.white),
    (pawns(['a2', 'b2', 'c2', 'd5', 'e4', 'f3', 'g2', 'h2'], ['a7', 'b7', 'c5', 'd6', 'e5', 'f5', 'g7', 'h7']), Side.white),
  ],
  'french_chain': [
    (line('e4 e6 d4 d5 e5 c5 c3 Nc6 Nf3'), Side.white),
    (pawns(['a2', 'b2', 'c3', 'd4', 'e5', 'f2', 'g2', 'h2'], ['a7', 'b7', 'c7', 'd5', 'e6', 'f7', 'g7', 'h7']), Side.white),
    (pawns(['a2', 'b2', 'c2', 'd4', 'e5', 'f4', 'g2', 'h2'], ['a6', 'b7', 'c5', 'd5', 'e6', 'f7', 'g7', 'h7']), Side.white),
  ],
  'boleslavsky': [
    (line('e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6 Be2 e5'), Side.black),
    (pawns(['a2', 'b2', 'c2', 'e4', 'f2', 'g2', 'h2'], ['a6', 'b7', 'd6', 'e5', 'f7', 'g7', 'h7']), Side.black),
    (pawns(['a2', 'b2', 'c2', 'e4', 'f3', 'g2', 'h2'], ['a7', 'b6', 'd6', 'e5', 'f7', 'g6', 'h7']), Side.black),
  ],
  'scheveningen': [
    (line('e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 e6'), Side.black),
    (pawns(['a2', 'b2', 'c2', 'e4', 'f2', 'g2', 'h2'], ['a6', 'b7', 'd6', 'e6', 'f7', 'g7', 'h7']), Side.black),
    (pawns(['a2', 'b2', 'c2', 'e4', 'f4', 'g2', 'h2'], ['a7', 'b5', 'd6', 'e6', 'f7', 'g7', 'h7']), Side.black),
  ],
  'caro_slav': [
    (line('e4 c6 d4 d5 Nc3 dxe4 Nxe4 Bf5 Ng3 Bg6 Nf3 e6'), Side.black),
    (pawns(['a2', 'b2', 'c2', 'd4', 'f2', 'g2', 'h2'], ['a7', 'b7', 'c6', 'e6', 'f7', 'g7', 'h7']), Side.black),
    (pawns(['a2', 'b2', 'c4', 'd4', 'f2', 'g3', 'h2'], ['a7', 'b6', 'c6', 'e6', 'f7', 'g7', 'h7']), Side.black),
  ],
  'doubled_c_pawns': [
    (line('d4 Nf6 c4 e6 Nc3 Bb4 a3 Bxc3+ bxc3'), Side.white),
    (pawns(['a2', 'c3', 'c4', 'd4', 'e3', 'f2', 'g2', 'h2'], ['a7', 'b7', 'c5', 'd6', 'e5', 'f7', 'g7', 'h7']), Side.white),
    (pawns(['a3', 'c3', 'c4', 'e4', 'f2', 'g2', 'h2'], ['a7', 'b7', 'c7', 'd6', 'e5', 'f7', 'g7', 'h7']), Side.white),
  ],
};

/// Close to a structure, but not it.
final nearMisses = <String, List<Board>>{
  'hanging_pawns': [
    pawns(['a2', 'b2', 'c4', 'd4', 'f2'], ['a7', 'b7', 'e6', 'f7']),
    pawns(['c4', 'd4', 'e3', 'f2'], ['a7', 'e6']),
    pawns(['c4', 'd4', 'f2'], ['d6', 'e6']),
  ],
  'isolated_queen_pawn': [
    pawns(['c3', 'd4', 'f2'], ['e6', 'f7']),
    pawns(['d4', 'e3', 'f2'], ['e6']),
    pawns(['d4', 'f2'], ['d5', 'e6']),
    pawns(['d3', 'f2'], ['e6']),
  ],
  'hedgehog': [
    pawns(['a2', 'b2', 'c4', 'e4'], ['a6', 'b6', 'c7', 'd6', 'e6']),
    pawns(['a2', 'b2', 'c4', 'd3', 'e4'], ['a6', 'b6', 'd6', 'e6']),
  ],
  'maroczy_bind': [
    pawns(['c4', 'd3', 'e4'], ['d6', 'g6']),
    pawns(['c4', 'e4'], ['c7', 'd6']),
    pawns(['c4', 'e4'], ['e7', 'g6']),
  ],
  'stonewall': [
    pawns(['c3', 'd4', 'e3', 'f3'], ['d5']),
    pawns(['c2', 'd4', 'e3', 'f4'], ['d5']),
  ],
  'carlsbad': [
    pawns(['c4', 'd4', 'e3'], ['c6', 'd5']),
    pawns(['d4', 'e3'], ['c6', 'd5', 'e6']),
    pawns(['d4', 'e3'], ['c7', 'd5']),
  ],
  'benoni': [
    pawns(['c4', 'd5', 'e4'], ['c5', 'd6', 'e5']),
    pawns(['c4', 'd4'], ['c5', 'd6']),
  ],
  'kings_indian_chain': [
    pawns(['c4', 'd4', 'e4'], ['d6', 'e5']),
    pawns(['d5', 'e3'], ['d6', 'e5']),
  ],
  'french_chain': [
    pawns(['d4', 'e4'], ['d5', 'e6']),
    pawns(['d4', 'e5'], ['d6', 'e6']),
  ],
  'boleslavsky': [
    pawns(['c2', 'd3', 'e4'], ['d6', 'e5']),
    pawns(['c2', 'e4'], ['c5', 'd6', 'e5']),
  ],
  'scheveningen': [
    pawns(['c2', 'd4', 'e4'], ['d6', 'e6']),
    pawns(['c2', 'e4'], ['c5', 'd6', 'e6']),
  ],
  'caro_slav': [
    pawns(['c2', 'd4', 'e4'], ['c6', 'e6']),
    pawns(['c2', 'd4'], ['c6', 'd5', 'e6']),
  ],
  'doubled_c_pawns': [
    pawns(['b2', 'c4', 'd4'], ['c5']),
    pawns(['c2', 'c3', 'c4'], ['c5']),
  ],
};

/// No structure at all.
final plain = <Board>[
  Chess.initial.board,
  line('e4 e5 Nf3 Nc6 Bb5 a6'),
  line('d4 d5 c4 c6'),
  line('e4 c5'),
  pawns(['a2', 'b2'], ['a7']),
];

void main() {
  final json = jsonDecode(File('assets/structures/structures.json').readAsStringSync()) as Map<String, dynamic>;
  final catalog = StructureCatalog.fromJson(json);

  test('the catalog is valid and every structure has fixtures', () {
    expect(validateCatalog(json), isEmpty);
    expect({for (final s in catalog.structures) s.id}, positives.keys.toSet());
    for (final s in catalog.structures) {
      expect(positives[s.id]!.length * 2, greaterThanOrEqualTo(5), reason: s.id);
      expect(s.text.uk, isNot(contains("'")), reason: '${s.id}: the apostrophe is ʼ');
      expect(s.text.uk, isNot(matches(RegExp('[—–]'))), reason: s.id);
      // Release builds show only structures a person has read.
      expect(s.reviewed, isTrue, reason: '${s.id} is not reviewed');
    }
  });

  for (final MapEntry(key: id, value: cases) in positives.entries) {
    group(id, () {
      test('recognised for the right side, and mirrored for the other', () {
        for (final (i, (board, side)) in cases.indexed) {
          final m = catalog.detect(board);
          expect(m?.structure.id, id, reason: 'case ${i + 1}: ${board.fen}');
          expect(m?.side, side, reason: 'case ${i + 1}');
          final mm = catalog.detect(mirror(board));
          expect(mm?.structure.id, id, reason: 'mirrored case ${i + 1}');
          expect(mm?.side, side.opposite, reason: 'mirrored case ${i + 1}');
        }
      });

      test('not in near misses or the other structures', () {
        final others = [
          ...?nearMisses[id],
          for (final MapEntry(key: other, value: cs) in positives.entries)
            if (other != id)
              for (final (b, _) in cs) b,
          ...plain,
        ];
        expect(others.length, greaterThanOrEqualTo(5));
        for (final b in others) {
          expect(catalog.detect(b)?.structure.id, isNot(id), reason: b.fen);
          expect(catalog.detect(mirror(b))?.structure.id, isNot(id), reason: 'mirrored ${b.fen}');
        }
      });
    });
  }

  test('nothing in plain positions', () {
    for (final b in plain) {
      expect(catalog.detect(b), isNull, reason: b.fen);
    }
  });

  test('every catalogued opening position: no errors, and the mirror agrees', () {
    var found = 0;
    for (final l in File('assets/openings/openings.tsv').readAsLinesSync()) {
      if (l.isEmpty) continue;
      final board = Board.parseFen(l.split(' ').first);
      final m = catalog.detect(board);
      final mm = catalog.detect(mirror(board));
      expect(mm?.structure.id, m?.structure.id, reason: l);
      if (m != null) {
        expect(mm!.side, m.side.opposite, reason: l);
        found++;
      }
    }
    expect(found, greaterThan(0));
  });

  test('a rule with an unknown key is rejected', () {
    expect(
      validateCatalog({
        'structures': [
          {
            'id': 'x',
            'priority': 1,
            'name': {'uk': 'x', 'en': 'x'},
            'text': {'uk': 'x', 'en': 'x'},
            'rule': {'pawns': 'own', 'on': ['z9']},
          },
        ],
      }),
      containsAll(['x: unknown key pawns', 'x: bad square z9']),
    );
  });
}
