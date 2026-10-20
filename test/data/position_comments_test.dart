import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/presentation/repertoire/repertoire_controller.dart';

PositionKey keyAfter(List<String> sans) {
  Position p = Chess.initial;
  for (final san in sans) {
    p = p.play(p.parseSan(san)!);
  }
  return positionKeyOf(p);
}

/// Comments of "About this position" are the repertoires' position
/// comments (D-105).
void main() {
  late AppDatabase db;
  late RepertoireRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = RepertoireRepository(db);
  });
  tearDown(() => db.close());

  Future<int> rep(String name, List<String> line) async {
    final id = await repo.create(name: name, color: Side.white);
    final g = await repo.loadGraph(id);
    addSanLine(g, Chess.initial, line);
    await repo.saveGraph(id, g);
    return id;
  }

  test('collects the position from every repertoire, transpositions included', () async {
    final a = await rep('A', ['e4', 'e5', 'Nf3', 'Nc6']);
    final b = await rep('B', ['Nf3', 'Nc6', 'e4', 'e5']);
    await rep('C', ['d4', 'd5']);
    final k = keyAfter(['e4', 'e5', 'Nf3', 'Nc6']);
    expect(keyAfter(['Nf3', 'Nc6', 'e4', 'e5']), k);
    await repo.setPositionComment(a, k, 'з A');
    final refs = await repo.positionComments(k);
    expect([for (final r in refs) (r.repertoireId, r.repertoireName, r.comment)], [(a, 'A', 'з A'), (b, 'B', '')]);
    expect(await repo.positionComments(keyAfter(['c4'])), isEmpty);
  });

  test('an open repertoire takes the edit and does not write the old text back', () async {
    final id = await rep('A', ['e4', 'e5', 'Nf3']);
    final k = keyAfter(['e4', 'e5']);
    final c = RepertoireController(id, repo);
    await c.load();
    final revision = c.revision;
    await repo.setPositionComment(id, k, 'новий');
    await Future<void>.delayed(Duration.zero);
    expect(c.graph!.positions[k]!.comment, 'новий');
    expect(c.revision, greaterThan(revision));
    // Another edit on the screen saves that position again.
    await c.setPositionComment(keyAfter(['e4']), 'інший');
    c.graph!.setPositionShapes(k, const []);
    await c.save();
    expect((await repo.positionComments(k)).single.comment, 'новий');
    c.dispose();
  });
}
