// Pure helpers of the Wikibooks pipeline (D-106): page title -> moves,
// wikitext -> plain text, SAN tokens of a text. Tested in
// test/tool/wikibooks_test.dart.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartchess/dartchess.dart';

const kTitlePrefix = 'Chess Opening Theory/';

/// Pages shorter than this after cleaning are stubs and are left out.
const kMinChars = 200;

/// The SAN moves of a page title, e.g. "Chess Opening Theory/1. e4/1...c5"
/// -> [e4, c5]; null when the title is not a move sequence or a move is
/// illegal.
List<String>? movesFromTitle(String title) {
  if (!title.startsWith(kTitlePrefix)) return null;
  final parts = title.substring(kTitlePrefix.length).split('/');
  final out = <String>[];
  Position pos = Chess.initial;
  for (final raw in parts) {
    final m = RegExp(r'^\s*(\d+)\s*(\.\.\.|\.|…)\s*(.+?)\s*$').firstMatch(raw);
    if (m == null) return null;
    final number = int.parse(m.group(1)!);
    final black = m.group(2) != '.';
    if (number != pos.fullmoves || black != (pos.turn == Side.black)) return null;
    var san = m.group(3)!.replaceAll('0-0-0', 'O-O-O').replaceAll('0-0', 'O-O');
    san = san.replaceAll(RegExp(r'[!?]+$'), '');
    final move = pos.parseSan(san);
    if (move == null) return null;
    final (next, normal) = pos.makeSan(move);
    out.add(normal);
    pos = next;
  }
  return out.isEmpty ? null : out;
}

/// Position key (the first four FEN fields, as the app's positionKeyOf)
/// after [sans] from the initial position.
String keyAfter(List<String> sans) {
  Position pos = Chess.initial;
  for (final san in sans) {
    pos = pos.play(pos.parseSan(san)!);
  }
  return pos.fen.split(' ').take(4).join(' ');
}

/// {{Chess/not|...}} of the book -> the usual chess signs.
const _evaluationMarks = {
  '=': '=',
  '+': '⩲',
  '++': '±',
  '+++': '+-',
  '-': '⩱',
  '--': '∓',
  '---': '-+',
  'unclear': '∞',
  'only': '□',
};

/// Sections that are not prose about the position.
final _dropSections = RegExp(
  r'^(references?|theory tables?|see also|external links?|further reading|sources?|statistics|notes?|bibliography|'
  r'all possible (white|black)?\s*moves|possible moves|moves|sample games?|games|example games?|links)\b',
  caseSensitive: false,
);

/// Lines of the book's own housekeeping.
final _boilerplate = RegExp(
  r'(when contributing to this wikibook|conventions for organization|this page is a stub|'
  r'help (us )?(improve|expand)|you can help|please (help|add|expand))',
  caseSensitive: false,
);

String _removeBalanced(String s, String open, String close) {
  final b = StringBuffer();
  var depth = 0;
  for (var i = 0; i < s.length;) {
    if (s.startsWith(open, i)) {
      depth++;
      i += open.length;
    } else if (depth > 0 && s.startsWith(close, i)) {
      depth--;
      i += close.length;
    } else {
      if (depth == 0) b.write(s[i]);
      i++;
    }
  }
  return b.toString();
}

/// Wikitext -> plain paragraphs: no templates, tables, references,
/// categories, images, headings or markup; links become their text; list
/// items become "• " lines; sections like "References" or "Theory table"
/// are dropped whole.
String cleanWikitext(String text) {
  var s = text.replaceAll('\r', '');
  s = s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  s = s.replaceAll(RegExp(r'<ref[^>]*/>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<ref[^>]*>.*?</ref>', dotAll: true, caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<table.*?</table>', dotAll: true, caseSensitive: false), '');
  // Evaluation marks ({{Chess/not|+}}) are text, not decoration: "with
  // {{Chess/not|=}}" must not become "with .".
  s = s.replaceAllMapped(
    RegExp(r'\{\{\s*chess/not\s*\|([^}]*)\}\}', caseSensitive: false),
    (m) => _evaluationMarks[m.group(1)!.trim()] ?? '',
  );
  s = _removeBalanced(s, '{{', '}}');
  s = _removeBalanced(s, '{|', '|}');
  // Files, categories and other-language links.
  s = s.replaceAll(RegExp(r'\[\[(file|image|category|[a-z]{2,3}(-[a-z]+)?):[^\]]*\]\]', caseSensitive: false), '');
  // [[target|text]] -> text, [[target]] -> target.
  s = s.replaceAllMapped(RegExp(r'\[\[([^\]|]*)\|([^\]]*)\]\]'), (m) => m.group(2)!);
  // A subpage link like [[/1...Nf6/]] shows its last part, the move.
  s = s.replaceAllMapped(
    RegExp(r'\[\[([^\]]*)\]\]'),
    (m) => m.group(1)!.replaceAll(RegExp(r'/+$'), '').split('/').last,
  );
  // [http://... text] -> text; bare [http://...] goes.
  s = s.replaceAllMapped(RegExp(r'\[https?://\S+\s+([^\]]+)\]'), (m) => m.group(1)!);
  s = s.replaceAll(RegExp(r'\[https?://\S+\]'), '');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</?[a-z][^>]*>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r"'{2,}"), '');
  s = s.replaceAll('&nbsp;', ' ').replaceAll('&ndash;', '-').replaceAll('&mdash;', '-').replaceAll('&amp;', '&');

  final paragraphs = <String>[];
  final current = <String>[];
  var dropping = false;
  void flush() {
    if (current.isNotEmpty) paragraphs.add(current.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim());
    current.clear();
  }

  for (var line in s.split('\n')) {
    line = line.trim();
    final heading = RegExp(r'^=+\s*(.*?)\s*=+$').firstMatch(line);
    if (heading != null) {
      flush();
      dropping = _dropSections.hasMatch(heading.group(1)!);
      continue;
    }
    if (dropping) continue;
    if (line.isEmpty) {
      flush();
      continue;
    }
    if (_boilerplate.hasMatch(line)) continue;
    final item = RegExp(r'^[:;*#]+\s*(.*)$').firstMatch(line);
    if (item != null) {
      flush();
      final t = item.group(1)!.trim();
      if (t.isNotEmpty) paragraphs.add('• $t');
      continue;
    }
    current.add(line);
  }
  flush();
  final kept = [
    for (final p in paragraphs)
      if (p.isNotEmpty && p != '•' && RegExp(r'[A-Za-z0-9]').hasMatch(p)) p,
  ];
  // Consecutive list items stay together, paragraphs apart.
  final b = StringBuffer();
  for (var i = 0; i < kept.length; i++) {
    if (i > 0) b.write(kept[i].startsWith('• ') && kept[i - 1].startsWith('• ') ? '\n' : '\n\n');
    b.write(kept[i]);
  }
  return b.toString().trim();
}

/// SAN-looking tokens of a text (moves with or without numbers), in order,
/// for comparing a translation with its original: a translation may
/// reword everything except the moves.
List<String> sanTokens(String text) {
  final re = RegExp(
    r'(?<![\w/])(?:\d+\s*\.(?:\.\.)?\s*)?(O-O-O|O-O|0-0-0|0-0|[KQRBN][a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?|[a-h]x[a-h][1-8](?:=[QRBN])?|[a-h][1-8](?:=[QRBN])?)[+#]?(?![\w])',
  );
  return [for (final m in re.allMatches(text)) m.group(1)!.replaceAll('0', 'O')];
}

/// Short hash of an English text: a translation belongs to exactly this
/// text, so an edited page is translated again.
String textHashOf(String en) => sha1.convert(utf8.encode(en)).toString().substring(0, 12);
