import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two languages stay in step: same keys, same placeholders, and
/// plurals with every form their language needs ("Added 1 moves",
/// "1 днів поспіль" came from messages without them).
void main() {
  Map<String, Object?> arb(String lang) =>
      (jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map).cast<String, Object?>();
  final en = arb('en');
  final uk = arb('uk');
  Iterable<String> keys(Map<String, Object?> m) => m.keys.where((k) => !k.startsWith('@'));
  test('same keys in both languages', () {
    expect(keys(uk).toSet(), keys(en).toSet());
  });

  test('every declared placeholder is used in both languages', () {
    for (final k in keys(en)) {
      final meta = en['@$k'] as Map?;
      final declared = ((meta?['placeholders'] as Map?) ?? const {}).keys.cast<String>();
      for (final name in declared) {
        for (final (lang, m) in [('en', en), ('uk', uk)]) {
          expect(RegExp('\\{$name[,}]').hasMatch(m[k]! as String), isTrue, reason: '$lang $k does not use {$name}');
        }
      }
    }
  });

  test('plurals have every form of their language', () {
    final plural = RegExp(r'\{\w+, plural,');
    for (final (lang, m, forms) in [
      ('en', en, const ['one', 'other']),
      ('uk', uk, const ['one', 'few', 'many', 'other']),
    ]) {
      for (final k in keys(m)) {
        final text = m[k]! as String;
        if (!plural.hasMatch(text)) continue;
        // Messages that only tell zero or exact numbers from the rest
        // ("=0{...} other{Added: {count}}") need no noun forms.
        final usesForms = RegExp(r'\b(one|few|many)\{').hasMatch(text);
        if (!usesForms) {
          expect(text, contains('other{'), reason: '$lang $k');
          continue;
        }
        for (final f in forms) {
          expect(RegExp('\\b$f\\{').hasMatch(text), isTrue, reason: '$lang $k lacks "$f": $text');
        }
      }
    }
  });

  test('English counts do not say "1 moves"', () {
    // A count followed by a plural noun must sit inside a plural message.
    final suspicious = RegExp(r'other\{[^}]*\{count\} (moves|games|lines|positions|days|cards)\b');
    for (final k in keys(en)) {
      final text = en[k]! as String;
      if (suspicious.hasMatch(text)) {
        expect(RegExp(r'\bone\{').hasMatch(text), isTrue, reason: '$k: $text');
      }
    }
  });

  // One vocabulary (D-064): a mode has one name, the trained unit is a move.
  test('retired words do not come back', () {
    for (final word in ['Прогін', 'прогін', 'Додаткова практика', 'карток', 'картк', 'напівход', 'Проблемні позиції']) {
      for (final k in keys(uk)) {
        expect((uk[k]! as String).contains(word), isFalse, reason: '$k still says "$word"');
      }
    }
  });
}
