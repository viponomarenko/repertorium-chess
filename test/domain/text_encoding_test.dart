import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/pgn/pgn_model.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/domain/pgn/text_encoding.dart';

/// Real-world files that used to turn into garbage ("крякозябри").
void main() {
  DecodedText decode(String name) => decodeChessText(File('test/fixtures/pgn/$name').readAsBytesSync());

  void expectUkrainian(DecodedText d) {
    final g = PgnParser.parseOne(d.text);
    expect(g.headers['Event'], 'Чемпіонат України');
    expect(g.headers['White'], 'Шевченко, Олександр');
    expect(g.mainline.first.comments.single.text, 'Найпопулярніший перший хід.');
    expect(g.mainline.length, 6);
  }

  test('UTF-8 with one stray Windows byte stays UTF-8', () {
    final d = decode('utf8_stray_byte.pgn');
    expect(d.encoding, TextEncodingKind.utf8);
    expectUkrainian(d);
    expect(d.text, contains('королівському ’'));
  });

  test('KOI8-U', () {
    final d = decode('koi8u.pgn');
    expect(d.encoding, TextEncodingKind.koi8u);
    expectUkrainian(d);
  });

  test('UTF-16 with a BOM', () {
    final d = decode('utf16le_bom.pgn');
    expect(d.encoding, TextEncodingKind.utf16le);
    expectUkrainian(d);
  });

  test('UTF-16 without a BOM', () {
    final d = decode('utf16le_nobom.pgn');
    expect(d.encoding, TextEncodingKind.utf16le);
    expectUkrainian(d);
  });

  test('a file that already contains mojibake is repaired', () {
    expectUkrainian(decode('utf8_double_encoded.pgn'));
  });

  // ChessBase merges games in different encodings into one file and
  // writes ч/ю/Ч/Ю as private-use characters (seen in real lecture files).
  test('a ChessBase file mixing UTF-8 and Windows-1251 games', () {
    final d = decode('chessbase_mixed.pgn');
    final games = PgnParser.parseAll(d.text).map((r) => r.game).toList();
    expect(games, hasLength(3));
    expect(games[0].headers['Event'], 'Лекція');
    expect(games[0].mainline[5].comments.single.text, 'этот ход уже определяет защиту Двух коней');
    expect(games[0].mainline[7].comments.single.text, 'и перевес может быть только у черных');
    expect(games[1].headers['Event'], 'ЗАЩИТА ДВУХ КОНЕЙ');
    expect(games[1].mainline[6].comments.single.text, 'черные держатся, но перевес белых не решающий');
    expect(games[2].mainline[0].comments.single.text, 'с более приятной позицией у белых');
    expect(games[2].mainline[1].comments.single.text, 'немного слабее');
    expect(d.text, isNot(contains(RegExp('[\uE000-\uF8FF]'))));
  });

  test('Windows-1251 once read as Windows-1252 is repaired', () {
    final t = decode('latin_mojibake.pgn').text;
    expect(t, contains('Достаточно крепкий, хотя и не вполне'));
    expect(t, contains('Рейтингова партія у швидкі шахи'));
  });

  test('ALL-CAPS Windows-1251 headers are not taken for KOI8-U', () {
    final d = decode('cp1251_caps.pgn');
    expect(d.encoding, TextEncodingKind.windows1251);
    expect(PgnParser.parseOne(d.text).headers['Event'], 'КАРО-КАНН');
  });

  test('the existing fixtures keep their encodings', () {
    expect(decode('cp1251.pgn').encoding, TextEncodingKind.windows1251);
    expect(decode('cp1252.pgn').encoding, TextEncodingKind.windows1252);
    expect(decode('utf8_bom.pgn').encoding, TextEncodingKind.utf8);
    expect(decode('nags.pgn').encoding, TextEncodingKind.utf8);
  });

  // ChessBase lectures put the line into White and leave Black "?":
  // the title read "4... Nxe4?! -".
  test('players line leaves out unknown sides', () {
    expect(playersLine('4... Nxe4?!', '?'), '4... Nxe4?!');
    expect(playersLine('?', 'Коваленко'), 'Коваленко');
    expect(playersLine('Шевченко', 'Коваленко'), 'Шевченко - Коваленко');
    expect(playersLine(null, ' ? '), '');
  });
}
