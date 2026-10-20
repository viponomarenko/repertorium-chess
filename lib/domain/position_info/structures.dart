/// Pawn structures for "About this position" (D-107). A structure is a
/// rule over the pawns, written in data (assets/structures/structures.json)
/// for one side - "own" pawns on the squares as White sees them - and
/// mirrored by the engine for the other side.
///
/// Rule grammar (JSON objects):
/// - `{"pawn": "own"|"opp", "on": ["d4", ...], "mode": "all"|"any"}`:
///   pawns on those squares (all of them by default).
/// - `{"noPawn": "own"|"opp", "files": ["c", "e"]}` or `"on": [...]`:
///   no such pawns there.
/// - `{"count": "own"|"opp", "files": ["c"], "op": "==", "n": 2}`: how many
///   pawns are on those files (op: ==, >=, <=).
/// - `{"all": [rules]}`, `{"any": [rules]}`, `{"not": rule}`.
library;

import 'package:dartchess/dartchess.dart';

class StructureText {
  const StructureText({required this.uk, required this.en});
  factory StructureText.fromJson(Map<String, dynamic> j) => StructureText(uk: j['uk'] as String, en: j['en'] as String);
  final String uk;
  final String en;

  String of(String languageCode) => languageCode == 'uk' ? uk : en;
}

class PawnStructure {
  const PawnStructure({
    required this.id,
    required this.priority,
    required this.name,
    required this.text,
    required this.rule,
    this.reviewed = false,
  });

  factory PawnStructure.fromJson(Map<String, dynamic> j) => PawnStructure(
    id: j['id'] as String,
    priority: j['priority'] as int,
    name: StructureText.fromJson(j['name'] as Map<String, dynamic>),
    text: StructureText.fromJson(j['text'] as Map<String, dynamic>),
    rule: j['rule'] as Map<String, dynamic>,
    reviewed: j['reviewed'] as bool? ?? false,
  );

  final String id;

  /// When several match, the highest wins.
  final int priority;
  final StructureText name;

  /// What the structure is about, the plans of both sides, where the
  /// pieces go.
  final StructureText text;
  final Map<String, dynamic> rule;

  /// A person has read the texts.
  final bool reviewed;
}

class StructureMatch {
  const StructureMatch(this.structure, this.side);
  final PawnStructure structure;

  /// The side the rule's "own" pawns belong to.
  final Side side;
}

class StructureCatalog {
  StructureCatalog(this.structures);

  factory StructureCatalog.fromJson(Map<String, dynamic> j) => StructureCatalog([
    for (final s in j['structures'] as List) PawnStructure.fromJson(s as Map<String, dynamic>),
  ]);

  static final empty = StructureCatalog(const []);

  final List<PawnStructure> structures;

  /// The structure of [board] with the highest priority, for either side;
  /// null when none matches. White's reading wins a tie.
  StructureMatch? detect(Board board, {bool Function(PawnStructure)? include}) {
    StructureMatch? best;
    for (final s in structures) {
      if (include != null && !include(s)) continue;
      if (best != null && best.structure.priority >= s.priority) continue;
      for (final side in Side.values) {
        if (ruleHolds(s.rule, board, side)) {
          best = StructureMatch(s, side);
          break;
        }
      }
    }
    return best;
  }
}

/// [side]'s and the opponent's pawns as White sees them: Black's position
/// is turned over so the rule's squares read the same.
(SquareSet own, SquareSet opp) _pawns(Board b, Side side) {
  final w = b.piecesOf(Side.white, Role.pawn);
  final k = b.piecesOf(Side.black, Role.pawn);
  return side == Side.white ? (w, k) : (k.flipVertical(), w.flipVertical());
}

SquareSet _squares(List<dynamic> names) {
  var s = SquareSet.empty;
  for (final n in names) {
    s = s.withSquare(Square.fromName(n as String));
  }
  return s;
}

SquareSet _files(List<dynamic> names) {
  var s = SquareSet.empty;
  for (final n in names) {
    s = s | SquareSet.fromFile(File.values[(n as String).codeUnitAt(0) - 97]);
  }
  return s;
}

/// Whether [rule] holds for [side] in [board].
bool ruleHolds(Map<String, dynamic> rule, Board board, Side side) {
  final (own, opp) = _pawns(board, side);
  return _eval(rule, own, opp);
}

bool _eval(Map<String, dynamic> r, SquareSet own, SquareSet opp) {
  SquareSet who(Object? w) => switch (w) {
    'own' => own,
    'opp' => opp,
    _ => throw FormatException('who must be own or opp: $w'),
  };
  if (r['all'] case final List<dynamic> rules) {
    return rules.every((x) => _eval(x as Map<String, dynamic>, own, opp));
  }
  if (r['any'] case final List<dynamic> rules) {
    return rules.any((x) => _eval(x as Map<String, dynamic>, own, opp));
  }
  if (r['not'] case final Map<String, dynamic> x) return !_eval(x, own, opp);
  if (r.containsKey('pawn')) {
    final set = _squares(r['on'] as List<dynamic>);
    final hit = who(r['pawn']) & set;
    return r['mode'] == 'any' ? hit.isNotEmpty : hit == set;
  }
  if (r.containsKey('noPawn')) {
    final where = r.containsKey('files') ? _files(r['files'] as List<dynamic>) : _squares(r['on'] as List<dynamic>);
    return (who(r['noPawn']) & where).isEmpty;
  }
  if (r.containsKey('count')) {
    final n = (who(r['count']) & _files(r['files'] as List<dynamic>)).size;
    final want = r['n'] as int;
    return switch (r['op']) {
      '==' => n == want,
      '>=' => n >= want,
      '<=' => n <= want,
      _ => throw FormatException('op must be ==, >= or <=: ${r['op']}'),
    };
  }
  throw FormatException('unknown rule: $r');
}

/// Problems of a catalog (for its tests): unknown keys, bad squares,
/// repeated ids or priorities, missing texts.
List<String> validateCatalog(Map<String, dynamic> j) {
  final out = <String>[];
  final ids = <String>{}, priorities = <int>{};
  const keys = {'all', 'any', 'not', 'pawn', 'noPawn', 'count', 'on', 'files', 'mode', 'op', 'n'};
  void rule(Object? r, String id) {
    if (r is! Map<String, dynamic>) {
      out.add('$id: a rule must be an object');
      return;
    }
    for (final k in r.keys) {
      if (!keys.contains(k)) out.add('$id: unknown key $k');
    }
    for (final k in ['all', 'any']) {
      if (r[k] case final List<dynamic> l) {
        for (final x in l) {
          rule(x, id);
        }
      }
    }
    if (r['not'] != null) rule(r['not'], id);
    for (final n in (r['on'] as List<dynamic>?) ?? const []) {
      if (!RegExp(r'^[a-h][1-8]$').hasMatch(n as String)) out.add('$id: bad square $n');
    }
    for (final n in (r['files'] as List<dynamic>?) ?? const []) {
      if (!RegExp(r'^[a-h]$').hasMatch(n as String)) out.add('$id: bad file $n');
    }
  }

  for (final s in (j['structures'] as List?) ?? const []) {
    final m = s as Map<String, dynamic>;
    final id = m['id'] as String? ?? '?';
    if (!ids.add(id)) out.add('$id: repeated id');
    if (!priorities.add(m['priority'] as int? ?? -1)) out.add('$id: repeated priority');
    for (final f in ['name', 'text']) {
      final t = m[f] as Map<String, dynamic>?;
      if (t == null || (t['uk'] as String? ?? '').isEmpty || (t['en'] as String? ?? '').isEmpty) {
        out.add('$id: $f needs uk and en');
      }
    }
    rule(m['rule'], id);
  }
  return out;
}
