import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabiya/data/chesscom/chesscom_client.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/lichess/lichess_client.dart';
import 'package:tabiya/data/sync/accounts_service.dart';

import '../e2e/harness.dart' show MemoryTokens;

/// A Chess.com game of 2026, ended on [day] of [month] (D-099).
Map<String, Object?> _ccGame(String id, int month, int day) => {
  'url': 'https://www.chess.com/game/live/$id',
  'pgn': '[White "Me"]\n[Black "Opp"]\n[BlackElo "1450"]\n\n1. e4 c6 *',
  'end_time': DateTime.utc(2026, month, day, 12).millisecondsSinceEpoch ~/ 1000,
  'time_control': '300',
  'time_class': 'blitz',
  'rated': true,
  'rules': 'chess',
  'white': {'username': 'Me', 'result': 'win'},
  'black': {'username': 'Opp', 'result': 'resigned'},
};

/// The Chess.com API with two months, September (games s1…s4) and
/// October (o1…o3), each month's games oldest first as the API sends them.
MockClient _chessCom(List<Uri> monthsAsked) => MockClient((req) async {
  final path = req.url.path;
  if (path.endsWith('/archives')) {
    return http.Response(
      jsonEncode({
        'archives': [
          'https://api.chess.com/pub/player/me/games/2026/09',
          'https://api.chess.com/pub/player/me/games/2026/10',
        ],
      }),
      200,
    );
  }
  monthsAsked.add(req.url);
  final games = path.endsWith('/09')
      ? [for (var d = 1; d <= 4; d++) _ccGame('s$d', 9, d)]
      : [for (var d = 1; d <= 3; d++) _ccGame('o$d', 10, d)];
  return http.Response(jsonEncode({'games': games}), 200, headers: {'etag': '"${path.split('/').last}"'});
});

Future<(AppDatabase, AccountsService)> _setUp(http.Client chessCom, {http.Client? lichess}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final tokens = MemoryTokens();
  final svc = AccountsService(
    db: db,
    lichess: LichessClient(client: lichess ?? MockClient((_) async => http.Response('', 404)), userAgent: 'ua'),
    chessCom: ChessComClient(client: chessCom, userAgent: 'ua'),
    tokens: tokens,
  );
  for (final p in ['chesscom', 'lichess']) {
    await db
        .into(db.linkedAccounts)
        .insert(LinkedAccountsCompanion.insert(provider: p, username: 'me', connectedAt: DateTime(2026)));
  }
  return (db, svc);
}

Future<Set<String>> _ids(AppDatabase db) async => {
  for (final g in await db.select(db.importedGames).get()) g.externalId,
};

void main() {
  test('Chess.com: the limit counts new games only, so a second download goes on', () async {
    final asked = <Uri>[];
    final (db, svc) = await _setUp(_chessCom(asked));
    addTearDown(db.close);

    // The whole history, at most 4 new games: the newest four.
    var last = await svc.syncChessCom(const GamesFilter(max: 4)).last;
    expect(last.error, isNull);
    expect(last.added, 4);
    expect(last.more, isTrue, reason: 'September is not read to its end');
    expect(await _ids(db), {'o1', 'o2', 'o3', 's4'});

    // Again: October's games are known and do not count, the rest of
    // September comes in. Before, the same 4 games filled the limit and
    // the answer was "No new games".
    last = await svc.syncChessCom(const GamesFilter(max: 4)).last;
    expect(last.added, 3);
    expect(last.more, isFalse);
    expect(await _ids(db), {'o1', 'o2', 'o3', 's1', 's2', 's3', 's4'});
  });

  test('Chess.com: new games only, oldest first, so a limit leaves no hole', () async {
    final asked = <Uri>[];
    final (db, svc) = await _setUp(_chessCom(asked));
    addTearDown(db.close);
    await db
        .into(db.importedGames)
        .insert(
          ImportedGamesCompanion.insert(
            provider: 'chesscom',
            externalId: 's2',
            pgn: '1. e4 *',
            playedAt: DateTime.utc(2026, 9, 2, 12),
            userColor: 'white',
          ),
        );

    final progress = await svc.syncChessCom(const GamesFilter(max: 2, newOnly: true)).toList();
    // September first and its games oldest first; October is left for
    // the next time, not skipped.
    expect(await _ids(db), {'s1', 's2', 's3'});
    expect(progress.last.more, isTrue);
    expect(progress.where((p) => p.month != null).first.month, DateTime(2026, 9));
    expect(asked.first.path, endsWith('/2026/09'));

    await svc.syncChessCom(const GamesFilter(max: 10, newOnly: true)).last;
    expect(await _ids(db), {'s1', 's2', 's3', 's4', 'o1', 'o2', 'o3'});
  });

  test('Chess.com: a month read with a filter is not remembered as read', () async {
    final asked = <Uri>[];
    final (db, svc) = await _setUp(_chessCom(asked));
    addTearDown(db.close);
    await svc.syncChessCom(const GamesFilter(color: 'black')).last;
    expect(await db.select(db.httpCache).get(), isEmpty);
    await svc.syncChessCom(const GamesFilter()).last;
    expect((await db.select(db.httpCache).get()).length, 2);
    expect((await _ids(db)).length, 7);
  });

  test('Chess.com: a limit met at the end of a month says "more" only if a month is left unread', () async {
    final asked = <Uri>[];
    final (db, svc) = await _setUp(_chessCom(asked));
    addTearDown(db.close);
    // Everything once: both months are remembered as read through.
    await svc.syncChessCom(const GamesFilter()).last;
    // October's 3 games again, deleted and limited to exactly 3: the limit
    // is met with October done, September read through before.
    await (db.delete(db.importedGames)..where((g) => g.externalId.like('o%'))).go();
    await (db.delete(db.httpCache)..where((c) => c.url.like('%/10'))).go();
    final last = await svc.syncChessCom(const GamesFilter(max: 3)).last;
    expect(last.added, 3);
    expect(last.more, isFalse);
  });

  test('archive month from its URL', () {
    expect(
      AccountsService.archiveMonth(Uri.parse('https://api.chess.com/pub/player/me/games/2026/10')),
      DateTime(2026, 10),
    );
    expect(AccountsService.archiveMonth(Uri.parse('https://api.chess.com/pub/player/me/games/archives')), isNull);
  });

  test('Lichess: newer games oldest first, then older than the earliest one', () async {
    final asked = <Map<String, String>>[];
    final lichess = MockClient((req) async {
      asked.add(req.url.queryParameters);
      return http.Response('', 200);
    });
    final (db, svc) = await _setUp(MockClient((_) async => http.Response('', 404)), lichess: lichess);
    addTearDown(db.close);
    for (final (id, day) in [('a', 5), ('b', 9)]) {
      await db
          .into(db.importedGames)
          .insert(
            ImportedGamesCompanion.insert(
              provider: 'lichess',
              externalId: id,
              pgn: '1. e4 *',
              playedAt: DateTime.utc(2026, 9, day),
              userColor: 'white',
              rated: const Value(true),
            ),
          );
    }
    final last = await svc.syncLichess(const GamesFilter(max: 100)).last;
    expect(last.error, isNull);
    expect(asked, hasLength(2));
    expect(asked[0]['sort'], 'dateAsc');
    expect(asked[0]['since'], '${DateTime.utc(2026, 9, 9).millisecondsSinceEpoch + 1}');
    expect(asked[1]['sort'], isNull);
    expect(asked[1]['until'], '${DateTime.utc(2026, 9, 5).millisecondsSinceEpoch - 1}');

    asked.clear();
    await svc.syncLichess(const GamesFilter(max: 100, newOnly: true)).last;
    expect(asked, hasLength(1), reason: 'new games only: nothing older is asked for');
  });
}
