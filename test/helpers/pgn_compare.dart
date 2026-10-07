import 'package:tabiya/domain/pgn/pgn_model.dart';

/// Semantic comparison of two games (F-EDIT-07): same moves, variations,
/// comments, NAGs, `[%...]` commands and headers. Returns a list of
/// differences (empty if equal).
List<String> diffGames(ChessGame a, ChessGame b) {
  final diffs = <String>[];
  if (a.headers.length != b.headers.length) {
    diffs.add('header count ${a.headers.length} != ${b.headers.length}');
  }
  for (final e in a.headers.entries) {
    if (b.headers[e.key] != e.value) {
      diffs.add('header ${e.key}: "${e.value}" != "${b.headers[e.key]}"');
    }
  }
  if (a.root.fen != b.root.fen) diffs.add('start fen differs');
  if (!_listEq(a.root.comments, b.root.comments)) {
    diffs.add('root comments ${a.root.comments} != ${b.root.comments}');
  }
  void cmp(GameNode x, GameNode y, String path) {
    if (x.children.length != y.children.length) {
      diffs.add('$path: children ${x.children.length} != ${y.children.length}');
      return;
    }
    for (var i = 0; i < x.children.length; i++) {
      final cx = x.children[i];
      final cy = y.children[i];
      final p = '$path/${cx.san}';
      if (cx.san != cy.san) diffs.add('$p: san ${cx.san} != ${cy.san}');
      if (!_listEq(cx.nags, cy.nags)) diffs.add('$p: nags ${cx.nags} != ${cy.nags}');
      if (!_listEq(cx.comments, cy.comments)) {
        diffs.add('$p: comments ${cx.comments} != ${cy.comments}');
      }
      if (!_listEq(cx.startComments, cy.startComments)) {
        diffs.add('$p: startComments ${cx.startComments} != ${cy.startComments}');
      }
      cmp(cx, cy, p);
    }
  }

  cmp(a.root, b.root, '');
  return diffs;
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
