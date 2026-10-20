// Writes the document for the human check (D-106): the English original
// and the Ukrainian translation side by side for the most visited
// positions - the main replies to the four main first moves. A person
// reads it and lists the approved titles in tool/wikibooks/reviewed.txt.
//
// Usage: dart run tool/wikibooks/review.dart [limit]
// Output: docs/wikibooks-review.md
import 'dart:convert';
import 'dart:io';

import 'wikitext.dart';

const _mainFirst = {'e4', 'd4', 'c4', 'Nf3'};

void main(List<String> args) {
  final limit = args.isEmpty ? 40 : int.parse(args.first);
  final uk = <String, String>{};
  for (final f in Directory('tool/wikibooks/uk').listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl'))) {
    for (final l in f.readAsLinesSync().where((l) => l.trim().isNotEmpty)) {
      final t = jsonDecode(l) as Map<String, dynamic>;
      uk[t['h'] as String] = t['uk'] as String;
    }
  }
  final picked = <Map<String, dynamic>>[];
  for (final l in File('tool/wikibooks/en.jsonl').readAsLinesSync()) {
    final e = jsonDecode(l) as Map<String, dynamic>;
    final moves = movesFromTitle(e['title'] as String)!;
    if (moves.length > 3 || !_mainFirst.contains(moves.first)) continue;
    if (uk[textHashOf(e['en'] as String)] == null) continue;
    picked.add(e);
  }
  // The first moves, then the replies, then the third moves.
  picked.sort((a, b) => (a['ply'] as int).compareTo(b['ply'] as int));
  final out = StringBuffer()
    ..writeln('# Вичитка перекладу Wikibooks (D-106)')
    ..writeln()
    ..writeln('Найчастіші позиції: оригінал і машинний переклад. Що перекладено добре - ')
    ..writeln('познач ✅, що треба виправити - напиши поруч. Схвалені назви йдуть у')
    ..writeln('`tool/wikibooks/reviewed.txt`, і в застосунку такі тексти мають позначку «переклад перевірено».')
    ..writeln();
  for (final e in picked.take(limit)) {
    final moves = (e['title'] as String).substring(kTitlePrefix.length).replaceAll('/', ' ');
    out
      ..writeln('---')
      ..writeln()
      ..writeln('## $moves')
      ..writeln()
      ..writeln('- [ ] перевірено · `${e['title']}`')
      ..writeln()
      ..writeln('**Оригінал**')
      ..writeln()
      ..writeln(e['en'])
      ..writeln()
      ..writeln('**Переклад**')
      ..writeln()
      ..writeln(uk[textHashOf(e['en'] as String)])
      ..writeln();
  }
  File('docs/wikibooks-review.md').writeAsStringSync(out.toString());
  stdout.writeln('${picked.take(limit).length} pages in docs/wikibooks-review.md');
}
