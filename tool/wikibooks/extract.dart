// Turns the downloaded pages into clean English texts per position
// (D-106): tool/wikibooks/raw/pages.jsonl -> tool/wikibooks/en.jsonl
// ({key, title, revid, ply, en}), one entry per position: of several pages
// reaching the same position (transpositions) the longest text stays.
//
// Usage: dart run tool/wikibooks/extract.dart
import 'dart:convert';
import 'dart:io';

import 'wikitext.dart';

/// Pages left out on purpose (vandalism, nonsense), with the reason after
/// a tab: tool/wikibooks/excluded.tsv.
Set<String> _excluded() {
  final f = File('tool/wikibooks/excluded.tsv');
  if (!f.existsSync()) return {};
  return {
    for (final l in f.readAsLinesSync())
      if (l.trim().isNotEmpty && !l.startsWith('#')) l.split('\t').first.trim(),
  };
}

void main() {
  final excluded = _excluded();
  final byKey = <String, Map<String, Object>>{};
  var pages = 0, notMoves = 0, stubs = 0, skipped = 0;
  for (final line in File('tool/wikibooks/raw/pages.jsonl').readAsLinesSync()) {
    final p = jsonDecode(line) as Map<String, dynamic>;
    pages++;
    final title = p['title'] as String;
    if (excluded.contains(title)) {
      skipped++;
      continue;
    }
    final moves = movesFromTitle(title);
    if (moves == null) {
      notMoves++;
      continue;
    }
    final text = cleanWikitext(p['text'] as String);
    if (text.length < kMinChars) {
      stubs++;
      continue;
    }
    final key = keyAfter(moves);
    final prev = byKey[key];
    if (prev != null && (prev['en'] as String).length >= text.length) continue;
    byKey[key] = {'key': key, 'title': title, 'revid': p['revid'] as int, 'ply': moves.length, 'en': text};
  }
  final entries = byKey.values.toList()
    ..sort((a, b) => (a['ply'] as int).compareTo(b['ply'] as int) != 0
        ? (a['ply'] as int).compareTo(b['ply'] as int)
        : (a['title'] as String).compareTo(b['title'] as String));
  final out = StringBuffer();
  var chars = 0;
  for (final e in entries) {
    out.writeln(jsonEncode(e));
    chars += (e['en'] as String).length;
  }
  File('tool/wikibooks/en.jsonl').writeAsStringSync(out.toString());
  stdout.writeln(
    '$pages pages: ${entries.length} positions with text ($chars characters), '
    '$stubs stubs, $notMoves titles that are not moves, $skipped excluded',
  );
}
