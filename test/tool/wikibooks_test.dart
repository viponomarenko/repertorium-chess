import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/openings/position_text_book.dart';

import '../../tool/wikibooks/build.dart' show polish, polishPair;
import '../../tool/wikibooks/check.dart' show problem;
import '../../tool/wikibooks/wikitext.dart';

/// The Wikibooks pipeline (D-106): titles, cleaning, the translation check,
/// and the file the app ships.
void main() {
  group('title to moves', () {
    test('white and black moves', () {
      expect(movesFromTitle('Chess Opening Theory/1. e4/1...c5/2. Nc3/2...Nc6/3. f4'), ['e4', 'c5', 'Nc3', 'Nc6', 'f4']);
    });

    test('castling and the Max Lange line', () {
      const t = 'Chess Opening Theory/1. e4/1...e5/2. Nf3/2...Nc6/3. Bc4/3...Nf6/4. d4/4...exd4/5. O-O/5...Bc5/6. e5';
      final m = movesFromTitle(t)!;
      expect(m[8], 'O-O');
      expect(m.last, 'e5');
      expect(keyAfter(m), keyFromFen('r1bqk2r/pppp1ppp/2n2n2/2b1P3/2Bp4/5N2/PPP2PPP/RNBQ1RK1 b kq - 0 6'));
    });

    test('not a move sequence, wrong numbers, illegal moves', () {
      expect(movesFromTitle('Chess Opening Theory/Organization'), isNull);
      expect(movesFromTitle('Chess Opening Theory/1. e4/2. d4'), isNull);
      expect(movesFromTitle('Chess Opening Theory/1. e5'), isNull);
      expect(movesFromTitle('Chess Opening Theory'), isNull);
    });

    test('a transposition gives the same key', () {
      final a = keyAfter(movesFromTitle('Chess Opening Theory/1. e4/1...e5/2. Nf3/2...Nc6')!);
      final b = keyAfter(movesFromTitle('Chess Opening Theory/1. Nf3/1...Nc6/2. e4/2...e5')!);
      expect(a, b);
    });
  });

  group('cleaning', () {
    test('Grand Prix page: prose stays, board, references and footer go', () {
      const raw = r"""{{Chess Opening Theory/Position|=
|Closed Sicilian|
   |rd|  |bd|qd|kd|bd|nd|rd|=
||
}}

==Closed Sicilian: Grand Prix Attack==

With 3. f4, white starts the '''Grand Prix attack''', a sharp weapon.<ref>BCO</ref> Black can strike back with an early 3...d5.

After 3. f4, white usually develops the bishop on [[Chess Opening Theory/x|c4]] or b5.
==References==
{{reflist}}
{{Chess Opening Theory/Footer}}

[[fi:Shakki/r1bqkbnr;pp1ppppp w KQkq]]""";
      expect(
        cleanWikitext(raw),
        'With 3. f4, white starts the Grand Prix attack, a sharp weapon. Black can strike back with an early 3...d5.\n\n'
        'After 3. f4, white usually develops the bishop on c4 or b5.',
      );
    });

    test('Max Lange page: lists stay, theory table and housekeeping go', () {
      const raw = r"""= Two Knights Defence: Classical Variation =
===5. O-O===
The classical variation. Castling gives the White King some security.
Black's possible sensible replies are:
:*5....Nxe4
:*5....Bc5

When contributing to this Wikibook, please follow the [[Chess Opening Theory/Organization|conventions for organization.]]

==Theory table==
{{Chess Opening Theory/Table}}.
<table border="0"><tr><td>O-O<br>[[/5...Nxe4|Nxe4]]</td></tr></table>
{{ChessMid}}""";
      expect(
        cleanWikitext(raw),
        'The classical variation. Castling gives the White King some security. Black\'s possible sensible replies are:\n\n'
        '• 5....Nxe4\n• 5....Bc5',
      );
    });

    test('evaluation marks become signs', () {
      expect(cleanWikitext('After 5. Nc3 the game is {{Chess/not|=}} and later {{chess/not|unclear}} or {{Chess/not|+++}}.'),
          'After 5. Nc3 the game is = and later ∞ or +-.');
    });

    test('a subpage link keeps its move', () {
      expect(cleanWikitext('* [[/1...e5/]] is a reversed Sicilian Defence here.'), '• 1...e5 is a reversed Sicilian Defence here.');
    });

    test('nested templates and wiki tables', () {
      expect(cleanWikitext('Before {{a|{{b}}|c}} after.\n{|\n| cell\n|}\nEnd of the text here.'), 'Before after.\n\nEnd of the text here.');
    });
  });

  test('polish drops magic words', () {
    expect(polish('__NOTOC__\nFirst.\n\n\n\nSecond.'), 'First.\n\nSecond.');
    expect(polish('Після 5. Nа4 і е4 у темпі'), 'Після 5. Nа4 і e4 у темпі');
    // Zero castling: O-O in both when both have it, else left as text.
    expect(polishPair('9.0–0 and 18.g5 0–0, 1–0', '9.0‑0 і 18.g5 0‑0, 1-0'), ('9.O-O and 18.g5 O-O, 1–0', '9.O-O і 18.g5 O-O, 1-0'));
    expect(polishPair('9.0–0 then 0-0-0', '9. коротка рокіровка, потім 0‑0‑0'), ('9.0–0 then 0-0-0', '9. коротка рокіровка, потім 0–0–0'));
    expect(polishPair('Castles 0–0.', null).$1, 'Castles O-O.');
  });

  group('translation check', () {
    const en = 'With 3. f4, White attacks. Black can play 3...d5 or ...Nf6, and O-O follows.';

    test('a faithful translation passes', () {
      expect(problem(en, 'Ходом 3. f4 білі атакують. Чорні можуть зіграти 3...d5 або ...Nf6, а далі O-O.'), isNull);
    });

    test('a changed, dropped or Cyrillic move fails', () {
      expect(problem(en, 'Ходом 3. f4 білі атакують. Чорні можуть зіграти 3...d6 або ...Nf6, а далі O-O.'), contains('moves'));
      expect(problem(en, 'Ходом 3. f4 білі атакують. Чорні можуть зіграти 3...d5, а далі O-O.'), contains('moves'));
      expect(problem(en, 'Ходом 3. f4 білі атакують. Чорні можуть зіграти 3...d5 або ...Кf6, а далі O-O.'), contains('moves'));
      expect(problem(en, 'Ходом 3. f4 білі атакують. Чорні можуть зіграти 3...d5 або ...Nf6, а далі 0-0.'), isNull);
    });

    test('layout and typography', () {
      expect(problem('$en\n\nSecond.', 'Ходом 3. f4 білі атакують. Чорні 3...d5 або ...Nf6, далі O-O. Друге.'), contains('paragraphs'));
      expect(problem(en, 'Ходом 3. f4 білі атакують — чорні можуть зіграти 3...d5 або ...Nf6, а далі O-O.'), 'dash');
      expect(problem(en, en), 'not Ukrainian');
    });
  });

  test('the shipped file: every text is about a legal position, translations pass the check', () {
    final f = File('assets/wikibooks/texts.json.gz');
    expect(f.existsSync(), isTrue);
    expect(f.lengthSync(), lessThan(3 * 1024 * 1024), reason: 'the app carries it; keep it small');
    final j = jsonDecode(utf8.decode(gzip.decode(f.readAsBytesSync()))) as Map<String, dynamic>;
    expect(j['license'], 'CC BY-SA 4.0');
    final book = PositionTextBook.fromJson(j);
    expect(book.length, greaterThan(1000));
    for (final e in j['entries'] as List) {
      final t = PositionText.fromJson(e as Map<String, dynamic>);
      expect(t.revid, greaterThan(0));
      expect(t.en.length, greaterThanOrEqualTo(kMinChars));
      expect(tryPositionFromFen(t.key), isNotNull, reason: t.title);
      expect(keyAfter(movesFromTitle(t.title)!), t.key, reason: t.title);
      if (t.uk != null) expect(problem(t.en, t.uk!), isNull, reason: t.title);
      expect(t.en.contains('__'), isFalse, reason: t.title);
    }
    final gp = book.lookup(keyAfter(['e4', 'c5', 'Nc3', 'Nc6', 'f4']));
    expect(gp?.en, contains('Grand Prix'));
  });
}
