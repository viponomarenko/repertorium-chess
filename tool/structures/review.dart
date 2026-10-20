// Writes docs/structures-review.md (D-107): every structure's name and
// texts in both languages, for a person to read. Approved structures get
// "reviewed": true in assets/structures/structures.json; only those are
// shown in release builds.
//
// Usage: dart run tool/structures/review.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final j = jsonDecode(File('assets/structures/structures.json').readAsStringSync()) as Map<String, dynamic>;
  final out = StringBuffer()
    ..writeln('# Вичитка текстів пішакових структур (D-107)')
    ..writeln()
    ..writeln('Кожна структура: назва й текст українською та англійською. Що гаразд - познач ✅;')
    ..writeln('що виправити - напиши поруч. Схвалені отримують `"reviewed": true` у')
    ..writeln('`assets/structures/structures.json` і тоді видні в релізній збірці.')
    ..writeln();
  for (final s in j['structures'] as List) {
    final m = s as Map<String, dynamic>;
    final name = m['name'] as Map<String, dynamic>;
    final text = m['text'] as Map<String, dynamic>;
    out
      ..writeln('---')
      ..writeln()
      ..writeln('## ${name['uk']} / ${name['en']}')
      ..writeln()
      ..writeln('- [ ] перевірено · `${m['id']}` · пріоритет ${m['priority']}')
      ..writeln()
      ..writeln(text['uk'])
      ..writeln()
      ..writeln('*${text['en']}*')
      ..writeln();
  }
  File('docs/structures-review.md').writeAsStringSync(out.toString());
  stdout.writeln('${(j['structures'] as List).length} structures in docs/structures-review.md');
}
