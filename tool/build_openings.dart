// Builds assets/openings/openings.tsv from lichess-org/chess-openings (CC0).
//
// Usage: dart run tool/build_openings.dart
// Input: tool/openings/{a,b,c,d,e}.tsv (eco, name, pgn)
// Output: position key \t eco \t name \t moves (SAN, space separated)
import 'dart:io';

import 'package:dartchess/dartchess.dart' hide File;

void main() {
  final out = StringBuffer();
  var count = 0;
  for (final f in ['a', 'b', 'c', 'd', 'e']) {
    final lines = File('tool/openings/$f.tsv').readAsLinesSync();
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\t');
      final eco = parts[0];
      final name = parts[1];
      final pgn = parts[2];
      Position pos = Chess.initial;
      final sans = <String>[];
      for (final tok in pgn.split(RegExp(r'\s+'))) {
        if (tok.isEmpty || RegExp(r'^\d+\.+$').hasMatch(tok)) continue;
        final m = pos.parseSan(tok);
        if (m == null) {
          stderr.writeln('Bad move $tok in $line');
          break;
        }
        final (next, san) = pos.makeSan(m);
        sans.add(san);
        pos = next;
      }
      final key = pos.fen.split(' ').take(4).join(' ');
      out.writeln('$key\t$eco\t$name\t${sans.join(' ')}');
      count++;
    }
  }
  File('assets/openings/openings.tsv').writeAsStringSync(out.toString());
  stdout.writeln('Wrote $count openings');
}
