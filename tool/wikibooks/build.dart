// Builds the app's file of opening texts (D-106) from the clean English
// texts and the translations that pass the checks:
// tool/wikibooks/en.jsonl + uk/*.jsonl + reviewed.txt
// -> assets/wikibooks/texts.json.gz
//
// A text without a passing translation goes in English only. Titles
// listed in reviewed.txt (one per line) are marked as checked by a person.
//
// Usage: dart run tool/wikibooks/build.dart
import 'dart:convert';
import 'dart:io';

import 'check.dart' show problem;
import 'wikitext.dart';

/// Last touches that do not change what was translated (so no text needs
/// translating again): wiki magic words like __NOTOC__ go, and so do the
/// empty lines they leave; Cyrillic look-alikes in squares become Latin.
String polish(String s) => s
    .replaceAll(RegExp(r'__[A-Z]+__'), '')
    // A square typed with a Cyrillic look-alike (е4 in one page) is a move.
    .replaceAllMapped(
      RegExp(r'(?<![А-Яа-яІіЇїЄєҐґA-Za-z])([асе])([1-8])(?![0-9])'),
      (m) => '${const {'а': 'a', 'с': 'c', 'е': 'e'}[m.group(1)]}${m.group(2)}',
    )
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// Castling written with zeros and any dash ("0–0").
final _zeroCastling = RegExp(r'(?<![0-9])0[-–‑]0(?:[-–‑]0)?(?![0-9])');

String _castle(String s) =>
    s.replaceAllMapped(_zeroCastling, (m) => m.group(0)!.length > 3 ? 'O-O-O' : 'O-O');

/// [polish] for a text and its translation together. Zero castling becomes
/// O-O in both when both have it the same number of times; otherwise (the
/// translation wrote it in words) both keep it as a non-move, the
/// translation's non-breaking hyphen turned into the original's dash.
(String, String?) polishPair(String en, String? uk) {
  var e = polish(en);
  if (uk == null) return (_castle(e), null);
  var u = polish(uk);
  if (_zeroCastling.allMatches(e).length == _zeroCastling.allMatches(u).length) {
    e = _castle(e);
    u = _castle(u);
  } else {
    u = u.replaceAll('‑', '–');
  }
  return (e, u);
}

void main() {
  final uk = <String, String>{};
  final dir = Directory('tool/wikibooks/uk');
  if (dir.existsSync()) {
    for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl'))) {
      for (final l in f.readAsLinesSync().where((l) => l.trim().isNotEmpty)) {
        final t = jsonDecode(l) as Map<String, dynamic>;
        uk[t['h'] as String] = t['uk'] as String;
      }
    }
  }
  final reviewedFile = File('tool/wikibooks/reviewed.txt');
  final reviewed = reviewedFile.existsSync()
      ? reviewedFile.readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('#')).toSet()
      : <String>{};
  final entries = <Map<String, Object>>[];
  var translated = 0, rejected = 0;
  for (final l in File('tool/wikibooks/en.jsonl').readAsLinesSync()) {
    final e = jsonDecode(l) as Map<String, dynamic>;
    final en = e['en'] as String;
    final t = uk[textHashOf(en)];
    final ok = t != null && problem(en, t) == null;
    if (t != null && !ok) rejected++;
    if (ok) translated++;
    final (pe, pu) = polishPair(en, ok ? t : null);
    entries.add({
      'key': e['key'] as String,
      'title': e['title'] as String,
      'revid': e['revid'] as int,
      'en': pe,
      'uk': ?pu,
      if (reviewed.contains(e['title'])) 'reviewed': true,
    });
  }
  final json = jsonEncode({
    'version': 1,
    'source': 'Wikibooks, Chess Opening Theory',
    'license': 'CC BY-SA 4.0',
    'entries': entries,
  });
  final out = File('assets/wikibooks/texts.json.gz')..parent.createSync(recursive: true);
  out.writeAsBytesSync(gzip.encode(utf8.encode(json)));
  stdout.writeln(
    '${entries.length} texts, $translated translated, $rejected translations rejected, '
    '${reviewed.length} reviewed; ${(out.lengthSync() / 1024).round()} KB',
  );
}
