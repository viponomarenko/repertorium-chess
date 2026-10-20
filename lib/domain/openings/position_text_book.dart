/// Texts about opening positions from Wikibooks "Chess Opening Theory"
/// (CC BY-SA 4.0), with Ukrainian translations (D-106). Looked up by
/// position key, so transpositions find the same text.
library;

import '../chess/chess_utils.dart';

class PositionText {
  const PositionText({
    required this.key,
    required this.title,
    required this.revid,
    required this.en,
    this.uk,
    this.reviewed = false,
  });

  factory PositionText.fromJson(Map<String, dynamic> j) => PositionText(
    key: j['key'] as String,
    title: j['title'] as String,
    revid: j['revid'] as int,
    en: j['en'] as String,
    uk: j['uk'] as String?,
    reviewed: j['reviewed'] as bool? ?? false,
  );

  final PositionKey key;

  /// The Wikibooks page, e.g. "Chess Opening Theory/1. e4/1...c5".
  final String title;

  /// The page revision the text comes from (for the attribution link).
  final int revid;
  final String en;

  /// Machine translation that passed the checks; null when there is none.
  final String? uk;

  /// A person has read the translation.
  final bool reviewed;

  /// The page at exactly the revision used.
  Uri get url => Uri.parse('https://en.wikibooks.org/w/index.php?oldid=$revid');

  /// The last move of the page title ("3. f4", "3...d5").
  String get lastMove => title.split('/').last;
}

class PositionTextBook {
  PositionTextBook(Iterable<PositionText> texts) {
    for (final t in texts) {
      _byKey[t.key] = t;
    }
  }

  factory PositionTextBook.fromJson(Map<String, dynamic> j) =>
      PositionTextBook([for (final e in j['entries'] as List) PositionText.fromJson(e as Map<String, dynamic>)]);

  static final empty = PositionTextBook(const []);

  final Map<PositionKey, PositionText> _byKey = {};

  int get length => _byKey.length;

  PositionText? lookup(PositionKey key) => _byKey[key];

  /// The text of the deepest position along a line that has one (the
  /// position itself first, then back towards the start).
  PositionText? deepest(List<PositionKey> keysFromStart) {
    for (var i = keysFromStart.length - 1; i >= 0; i--) {
      final t = _byKey[keysFromStart[i]];
      if (t != null) return t;
    }
    return null;
  }
}
