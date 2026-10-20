// Packs a plain-text translation into JSONL (D-106), so translating never
// means escaping JSON by hand.
//
// Input: tool/wikibooks/work/chunk_NN.uk.txt, blocks of
//   @@@ <id> <hash>
//   <translation, any number of lines>
// Output: tool/wikibooks/uk/chunk_NN.jsonl ({id, h, uk} per line).
//
// Usage: dart run tool/wikibooks/pack.dart chunk_NN
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  for (final a in args) {
    final name = a.replaceAll('.jsonl', '');
    final lines = File('tool/wikibooks/work/$name.uk.txt').readAsLinesSync();
    final out = StringBuffer();
    String? id, h;
    final text = <String>[];
    var count = 0;
    void flush() {
      if (id == null) return;
      out.writeln(jsonEncode({'id': int.parse(id), 'h': h, 'uk': text.join('\n').trim()}));
      count++;
      text.clear();
    }

    for (final l in lines) {
      final m = RegExp(r'^@@@\s+(\d+)\s+([0-9a-f]{12})\s*$').firstMatch(l);
      if (m != null) {
        flush();
        id = m.group(1);
        h = m.group(2);
      } else {
        text.add(l);
      }
    }
    flush();
    Directory('tool/wikibooks/uk').createSync(recursive: true);
    File('tool/wikibooks/uk/$name.jsonl').writeAsStringSync(out.toString());
    stdout.writeln('$name: $count translations');
  }
}
