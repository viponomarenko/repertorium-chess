// Splits tool/wikibooks/en.jsonl into chunks for translation in a Claude
// session (D-106), shallowest positions first, skipping texts that already
// have a translation of the same English text (by hash).
//
// Usage: dart run tool/wikibooks/split.dart [prefix]
// Output: tool/wikibooks/work/<prefix>NN.jsonl (not committed); the prefix
// (default chunk_) keeps new chunks apart from translated ones in uk/.
import 'dart:convert';
import 'dart:io';

import 'wikitext.dart';

/// About a quarter of an hour of translating per chunk.
const _chunkChars = 25000;

Set<String> _translated() {
  final dir = Directory('tool/wikibooks/uk');
  if (!dir.existsSync()) return {};
  return {
    for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl')))
      for (final l in f.readAsLinesSync().where((l) => l.trim().isNotEmpty))
        (jsonDecode(l) as Map<String, dynamic>)['h'] as String,
  };
}

void main(List<String> args) {
  final prefix = args.isEmpty ? 'chunk_' : args.first;
  final done = _translated();
  final work = Directory('tool/wikibooks/work');
  if (work.existsSync()) work.deleteSync(recursive: true);
  work.createSync(recursive: true);
  var n = 0, chars = 0, count = 0;
  var buf = StringBuffer();
  void flush() {
    if (buf.isEmpty) return;
    File('${work.path}/$prefix${(n++).toString().padLeft(2, '0')}.jsonl').writeAsStringSync(buf.toString());
    buf = StringBuffer();
    chars = 0;
  }

  for (final l in File('tool/wikibooks/en.jsonl').readAsLinesSync()) {
    final e = jsonDecode(l) as Map<String, dynamic>;
    final en = e['en'] as String;
    final h = textHashOf(en);
    if (done.contains(h)) continue;
    buf.writeln(jsonEncode({'id': e['revid'], 'h': h, 'title': e['title'], 'en': en}));
    chars += en.length;
    count++;
    if (chars >= _chunkChars) flush();
  }
  flush();
  stdout.writeln('$count texts to translate in $n chunks');
}
