import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/backup/backup_service.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/import/pgn_import_service.dart';
import 'package:tabiya/data/repositories/library_repository.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';

Future<AppDatabase> seeded() async {
  final db = AppDatabase(NativeDatabase.memory());
  final lib = LibraryRepository(db);
  final col = await lib.createCollection('Games');
  await lib.addGames(col, PgnImportService.parseTextSync('1. e4 e5 {comment [%clk 0:01:00]} *\n\n1. d4 d5 *'));
  final reps = RepertoireRepository(db);
  final id = await reps.create(name: 'Black', color: Side.black);
  final g = await reps.loadGraph(id);
  importIntoRepertoire(g, [ImportSource.game(PgnParser.parseOne('1. e4 c5 2. Nf3 d6 *'))], const RepImportOptions());
  await reps.saveGraph(id, g);
  await db
      .into(db.linkedAccounts)
      .insert(LinkedAccountsCompanion.insert(provider: 'lichess', username: 'me', connectedAt: DateTime(2026)));
  return db;
}

void main() {
  for (final corruption in [
    'missing table',
    'count mismatch',
    'future format',
    'dangling collection',
    'dangling position',
    'duplicate key',
    'invalid row',
  ]) {
    for (final mode in RestoreMode.values) {
      test('$corruption is rejected without changing data during ${mode.name}', () async {
        final db = await seeded();
        addTearDown(db.close);
        final svc = BackupService(db, appVersion: 'test');
        final bytes = await svc.export();
        final original = ZipDecoder().decodeBytes(bytes);
        final damaged = Archive();
        for (final file in original.files) {
          if (corruption == 'missing table' && file.name == 'cards.json') continue;
          var content = file.content;
          if (file.name == 'manifest.json') {
            final manifest = jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
            if (corruption == 'future format') manifest['formatVersion'] = 999;
            if (corruption == 'count mismatch') (manifest['counts'] as Map)['games'] = 99;
            content = utf8.encode(jsonEncode(manifest));
          }
          if (file.name == 'games.json') {
            final games = jsonDecode(utf8.decode(content)) as List;
            if (corruption == 'dangling collection') (games.first as Map)['collectionId'] = 999;
            if (corruption == 'duplicate key') (games.last as Map)['id'] = (games.first as Map)['id'];
            if (corruption == 'invalid row') (games.first as Map)['pgn'] = 42;
            content = utf8.encode(jsonEncode(games));
          }
          if (file.name == 'rep_moves.json' && corruption == 'dangling position') {
            final moves = jsonDecode(utf8.decode(content)) as List;
            (moves.first as Map)['toKey'] = 'missing';
            content = utf8.encode(jsonEncode(moves));
          }
          damaged.addFile(ArchiveFile(file.name, content.length, content));
        }
        final gamesBefore = await db.select(db.games).get();
        final repsBefore = await db.select(db.repertoires).get();
        final broken = ZipEncoder().encode(damaged);
        expect(() => svc.inspect(broken), throwsA(isA<BackupException>()));
        await expectLater(svc.restore(broken, mode), throwsA(isA<BackupException>()));
        expect(await db.select(db.games).get(), gamesBefore);
        expect(await db.select(db.repertoires).get(), repsBefore);
      });
    }
  }

  test('a complete empty backup can replace data, accounts and settings', () async {
    final empty = AppDatabase(NativeDatabase.memory());
    final target = await seeded();
    addTearDown(empty.close);
    addTearDown(target.close);
    await target.into(target.settings).insert(SettingsCompanion.insert(key: 'old', value: 'true'));
    final bytes = await BackupService(empty, appVersion: 'test').export();
    await BackupService(target, appVersion: 'test').restore(bytes, RestoreMode.replace);
    expect(await target.select(target.games).get(), isEmpty);
    expect(await target.select(target.repertoires).get(), isEmpty);
    expect(await target.select(target.linkedAccounts).get(), isEmpty);
    expect(await target.select(target.settings).get(), isEmpty);
  });

  test('export contains no tokens and restores with replace', () async {
    final src = await seeded();
    final bytes = await BackupService(src, appVersion: '1.0.0').export();
    final info = BackupService(src, appVersion: '1.0.0').inspect(bytes);
    expect(info.counts['games'], 2);
    expect(info.counts['repertoires'], 1);

    final dst = AppDatabase(NativeDatabase.memory());
    final svc = BackupService(dst, appVersion: '1.0.0');
    await svc.restore(bytes, RestoreMode.replace);
    final games = await dst.select(dst.games).get();
    expect(games, hasLength(2));
    expect(games.first.pgn, contains('[%clk 0:01:00]'));
    final graph = await RepertoireRepository(dst).loadGraph((await dst.select(dst.repertoires).getSingle()).id);
    expect(graph.moveCount, 4);
    expect(graph.checkInvariants(), isEmpty);
    final acc = await dst.select(dst.linkedAccounts).getSingle();
    expect(acc.tokenRef, isNull);
    await src.close();
    await dst.close();
  });

  // Audit 05.10: merging a backup into the data it was made from doubled
  // every repertoire, collection and review (D-056).
  test('merge skips what is already on the device', () async {
    final src = await seeded();
    final bytes = await BackupService(src, appVersion: '1.0.0').export();
    final dst = await seeded();
    final gamesBefore = (await dst.select(dst.games).get()).length;
    final logsBefore = (await dst.select(dst.reviewLogs).get()).length;
    final summary = await BackupService(dst, appVersion: '1.0.0').restore(bytes, RestoreMode.merge);
    expect(summary.added, 0);
    expect(summary.skipped, greaterThan(0));
    expect(await dst.select(dst.games).get(), hasLength(gamesBefore));
    expect(await dst.select(dst.repertoires).get(), hasLength(1));
    expect(await dst.select(dst.reviewLogs).get(), hasLength(logsBefore));
    await src.close();
    await dst.close();
  });

  test('merge adds what the device does not have', () async {
    final src = await seeded();
    final bytes = await BackupService(src, appVersion: '1.0.0').export();
    final dst = AppDatabase(NativeDatabase.memory());
    final other = await RepertoireRepository(dst).create(name: 'Other', color: Side.black);
    final summary = await BackupService(dst, appVersion: '1.0.0').restore(bytes, RestoreMode.merge);
    expect(summary.skipped, 0);
    expect(summary.repertoiresAdded, 1);
    final reps = await dst.select(dst.repertoires).get();
    expect(reps, hasLength(2));
    final added = reps.firstWhere((r) => r.id != other);
    final g = await RepertoireRepository(dst).loadGraph(added.id);
    expect(g.moveCount, 4);
    expect(g.checkInvariants(), isEmpty);
    expect(await dst.select(dst.games).get(), hasLength(2));
    await src.close();
    await dst.close();
  });

  test('hidden gap events survive a replace restore', () async {
    final src = await seeded();
    final rep = (await src.select(src.repertoires).get()).single;
    final gameId = await src
        .into(src.importedGames)
        .insert(
          ImportedGamesCompanion.insert(
            provider: 'lichess',
            externalId: 'x1',
            pgn: '1. e4 *',
            playedAt: DateTime(2026, 9, 1),
            userColor: 'white',
          ),
        );
    await src
        .into(src.gapEvents)
        .insert(
          GapEventsCompanion.insert(
            importedGameId: gameId,
            repertoireId: rep.id,
            type: 'userDeviation',
            positionKey: 'k',
            fen: 'f',
            ply: 3,
            dismissed: const Value(true),
          ),
        );
    final bytes = await BackupService(src, appVersion: '1.0.0').export();
    final dst = AppDatabase(NativeDatabase.memory());
    await BackupService(dst, appVersion: '1.0.0').restore(bytes, RestoreMode.replace);
    final events = await dst.select(dst.gapEvents).get();
    expect(events.single.dismissed, isTrue);
    await src.close();
    await dst.close();
  });

  test('garbage is rejected', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(() => BackupService(db, appVersion: '1').inspect([1, 2, 3]), throwsA(isA<BackupException>()));
    db.close();
  });
}
