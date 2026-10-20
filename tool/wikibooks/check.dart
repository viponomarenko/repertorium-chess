// Checks translations against their English originals (D-106). A
// translation passes when:
// - it has the same move tokens (the same multiset of SAN moves);
// - it has as many paragraphs and list items as the original;
// - its length is plausible for a translation;
// - it uses no em/en dash and no typographic apostrophe (ʼ is the
//   apostrophe).
//
// Usage: dart run tool/wikibooks/check.dart [chunk_NN ...]
// Without arguments every file in tool/wikibooks/uk/ is checked. For a
// chunk, also that every text of tool/wikibooks/work/chunk_NN.jsonl has a
// translation. Exits with 1 when anything fails.
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import 'wikitext.dart';

/// Why [uk] is not an acceptable translation of [en]; null when it is.
String? problem(String en, String uk) {
  final a = sanTokens(en)..sort();
  final b = sanTokens(uk)..sort();
  if (!const ListEquality<String>().equals(a, b)) {
    final missing = [...a];
    for (final t in b) {
      missing.remove(t);
    }
    final extra = [...b];
    for (final t in a) {
      extra.remove(t);
    }
    return 'moves differ (missing: ${missing.join(' ')}; extra: ${extra.join(' ')})';
  }
  int paras(String s) => s.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).length;
  int items(String s) => RegExp(r'^• ', multiLine: true).allMatches(s).length;
  if (paras(en) != paras(uk)) return 'paragraphs ${paras(en)} -> ${paras(uk)}';
  if (items(en) != items(uk)) return 'list items ${items(en)} -> ${items(uk)}';
  final ratio = uk.length / en.length;
  if (en.length > 150 && (ratio < 0.7 || ratio > 1.8)) return 'length ratio ${ratio.toStringAsFixed(2)}';
  if (uk.contains('—') || uk.contains('–')) return 'dash';
  if (uk.contains('’')) return 'typographic apostrophe (use ʼ)';
  if (!RegExp('[а-яіїєґА-ЯІЇЄҐ]').hasMatch(uk)) return 'not Ukrainian';
  return null;
}

Map<String, String> loadEnglish() {
  final out = <String, String>{};
  for (final l in File('tool/wikibooks/en.jsonl').readAsLinesSync()) {
    final e = jsonDecode(l) as Map<String, dynamic>;
    out[textHashOf(e['en'] as String)] = e['en'] as String;
  }
  return out;
}

void main(List<String> args) {
  final en = loadEnglish();
  final files = args.isEmpty
      ? (Directory('tool/wikibooks/uk').listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl')).toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : [for (final a in args) File('tool/wikibooks/uk/${a.replaceAll('.jsonl', '')}.jsonl')];
  var ok = 0, bad = 0;
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    if (!f.existsSync()) {
      stdout.writeln('$name: missing');
      bad++;
      continue;
    }
    final seen = <String>{};
    for (final (i, l) in f.readAsLinesSync().where((l) => l.trim().isNotEmpty).indexed) {
      Map<String, dynamic> t;
      try {
        t = jsonDecode(l) as Map<String, dynamic>;
      } catch (e) {
        stdout.writeln('$name line ${i + 1}: not JSON');
        bad++;
        continue;
      }
      final h = t['h'] as String?;
      final original = en[h];
      if (original == null) {
        stdout.writeln('$name ${t['id']}: unknown hash (the English text changed?)');
        bad++;
        continue;
      }
      seen.add(h!);
      final p = problem(original, t['uk'] as String? ?? '');
      if (p == null) {
        ok++;
      } else {
        stdout.writeln('$name ${t['id']}: $p');
        bad++;
      }
    }
    final work = File('tool/wikibooks/work/$name');
    if (args.isNotEmpty && work.existsSync()) {
      for (final l in work.readAsLinesSync().where((l) => l.trim().isNotEmpty)) {
        final w = jsonDecode(l) as Map<String, dynamic>;
        if (!seen.contains(w['h'])) {
          stdout.writeln('$name ${w['id']}: not translated');
          bad++;
        }
      }
    }
  }
  stdout.writeln('$ok passed, $bad failed');
  if (bad > 0) exitCode = 1;
}
