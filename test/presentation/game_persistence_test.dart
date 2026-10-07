import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/presentation/game/game_controller.dart';

void main() {
  test('edits during saving are serialized and persisted as separate snapshots', () async {
    final firstWrite = Completer<void>();
    final writes = <List<String?>>[];
    final controller = GameController(
      game: PgnParser.parseOne('*'),
      autosaveDelay: const Duration(days: 1),
      onSave: (game) async {
        if (writes.isEmpty) {
          writes.add([]);
          await firstWrite.future;
          writes[0] = game.mainline.map((n) => n.san).toList();
        } else {
          writes.add(game.mainline.map((n) => n.san).toList());
        }
      },
    );
    addTearDown(controller.dispose);
    controller.playMove(Move.parse('e2e4')!);
    final saving = controller.flush();
    expect(controller.saving, isTrue);
    controller.playMove(Move.parse('e7e5')!);
    final concurrent = controller.flush();
    expect(identical(saving, concurrent), isTrue);
    firstWrite.complete();
    await saving;
    expect(writes, [
      ['e4'],
      ['e4', 'e5'],
    ]);
    expect(controller.dirty, isFalse);
    expect(controller.saving, isFalse);
  });

  testWidgets('autosave errors are exposed without uncaught timer exceptions', (tester) async {
    final controller = GameController(
      game: PgnParser.parseOne('*'),
      autosaveDelay: const Duration(milliseconds: 10),
      onSave: (_) async => throw StateError('disk unavailable'),
    );
    controller.playMove(Move.parse('e2e4')!);
    await tester.pump(const Duration(milliseconds: 20));
    expect(controller.dirty, isTrue);
    expect(controller.saveError, isA<StateError>());
    expect(tester.takeException(), isNull);
    controller.onSave = (_) async {};
    await controller.flush();
    expect(controller.dirty, isFalse);
    expect(controller.saveError, isNull);
    controller.dispose();
  });

  test('disposal during a write does not notify disposed listeners', () async {
    final write = Completer<void>();
    final controller = GameController(
      game: PgnParser.parseOne('*'),
      autosaveDelay: const Duration(days: 1),
      onSave: (_) => write.future,
    );
    controller.playMove(Move.parse('e2e4')!);
    final saving = controller.flush();
    controller.dispose();
    write.complete();
    await saving;
  });
}
