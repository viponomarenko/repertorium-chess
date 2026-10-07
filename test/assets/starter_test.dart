import 'dart:io';

import 'package:dartchess/dartchess.dart' hide File, PgnComment;
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/domain/repertoire/repertoire_graph.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';

void main() {
  for (final (file, color) in [('white_e4_basics.pgn', Side.white), ('black_d4_qgd.pgn', Side.black)]) {
    test('starter $file parses and imports cleanly', () {
      final g = PgnParser.parseOne(File('assets/starter/$file').readAsStringSync());
      expect(g.issues, isEmpty);
      final rep = RepertoireGraph(color: color, rootKey: kInitialKey, rootFen: kInitialFen);
      final r = importIntoRepertoire(rep, [ImportSource.game(g)], const RepImportOptions(ownAllVariations: true));
      expect(r.conflicts, isEmpty);
      expect(rep.checkInvariants(), isEmpty);
      expect(rep.cards.length, greaterThan(8));
      final maxDepth = g.root.descendants().map((n) => n.depth).reduce((a, b) => a > b ? a : b);
      expect(maxDepth, lessThanOrEqualTo(12));
    });
  }

  test('starter texts follow Ukrainian typography (T-19)', () {
    for (final f in Directory('assets/starter').listSync().whereType<File>()) {
      final text = f.readAsStringSync();
      expect(RegExp('[–—’]').hasMatch(text), isFalse, reason: '${f.path}: use " - " and ʼ');
    }
  });
}
