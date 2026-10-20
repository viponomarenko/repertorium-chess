import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/lichess/lichess_client.dart';
import 'package:tabiya/data/puzzles/puzzle_repository.dart';
import 'package:tabiya/domain/puzzles/glicko2.dart';
import 'package:tabiya/domain/puzzles/puzzle.dart';
import 'package:tabiya/domain/puzzles/puzzle_pack.dart';
import 'package:tabiya/domain/puzzles/puzzle_profile.dart';

import '../domain/puzzles_test.dart' show legalJson, scholarJson;

/// The pack shipped with the app.
List<String> loadPackLines() => utf8
    .decode(gzip.decode(File('assets/puzzles/puzzles.tsv.gz').readAsBytesSync()))
    .split('\n')
    .where((l) => l.isNotEmpty)
    .toList();

LichessClient lichess(Future<http.Response> Function(http.Request req) answer) => LichessClient(
  client: MockClient(answer),
  userAgent: 'test',
  tokenProvider: () async => 'lip_token',
  sleep: (_) async {},
);

http.Response batch(List<Map<String, Object?>> puzzles, {Map<String, Object?>? glicko}) => http.Response(
  jsonEncode({'puzzles': puzzles, 'glicko': ?glicko}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  final packLines = loadPackLines();
  final pack = PuzzlePack(packLines);

  group('the pack', () {
    test('about 50 000 puzzles, every theme of the app, each line replays', () {
      expect(pack.length, greaterThan(49000));
      for (final line in packLines.take(300)) {
        final p = Puzzle.fromPackLine(line);
        expect(p.source, PuzzleSource.pack);
        expect(p.setup, returnsNormally, reason: line);
      }
      expect(pack.count('fork'), greaterThan(1000));
      expect(pack.count('equality'), greaterThan(50));
    });

    test('picks the theme, near the rating, never a puzzle in skip', () {
      final skip = <String>{};
      for (var i = 0; i < 30; i++) {
        final p = pack.pick('smotheredMate', 1600, skip)!;
        expect(p.themes, contains('smotheredMate'));
        expect((p.rating - 1600).abs(), lessThan(400));
        expect(skip.add(p.id), isTrue, reason: 'no repeats');
      }
      final mix = pack.pick('mix', 900, const {})!;
      expect((mix.rating - 900).abs(), lessThan(200));
    });
  });

  group('PuzzleFeed: Lichess first, the pack the moment it fails (D-126)', () {
    test('no network: the pack at once, and Lichess is not asked again for a while', () async {
      var calls = 0;
      var now = DateTime(2026, 10, 20, 12);
      final network = PuzzleNetwork(now: () => now);
      final feed = PuzzleFeed(
        client: lichess((_) async {
          calls++;
          throw const SocketException('offline');
        }),
        angle: 'fork',
        network: network,
        pack: () async => pack,
      );
      final p = await feed.next(rating: 1500, seen: const []);
      expect(p.source, PuzzleSource.pack);
      expect(p.themes, contains('fork'));
      expect(network.blocked, PuzzleOffline.network);
      final asked = calls;
      final q = await feed.next(rating: 1500, seen: const []);
      expect(q.source, PuzzleSource.pack);
      expect(q.id, isNot(p.id));
      expect(calls, asked, reason: 'blocked: straight to the pack');
      now = now.add(PuzzleNetwork.networkPause);
      expect(network.blocked, isNull, reason: 'tried again after the pause');
    });

    test('a 429: the pack, marked as limited', () async {
      final network = PuzzleNetwork();
      final feed = PuzzleFeed(
        client: lichess((_) async => http.Response('{"error":"Too many requests"}', 429)),
        angle: 'mix',
        network: network,
        pack: () async => pack,
      );
      expect((await feed.next(rating: 1500, seen: const [])).source, PuzzleSource.pack);
      expect(network.blocked, PuzzleOffline.limited);
    });

    test('a slow Lichess: the pack after the first wait, not later', () async {
      final feed = PuzzleFeed(
        client: lichess((_) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return batch([legalJson()]);
        }),
        angle: 'mix',
        network: PuzzleNetwork(),
        pack: () async => pack,
        firstTimeout: const Duration(milliseconds: 50),
      );
      expect((await feed.next(rating: 1500, seen: const [])).source, PuzzleSource.pack);
    });

    test('with the account: three at once with the token, the rating reported', () async {
      final asked = <http.Request>[];
      Glicko? reported;
      final feed = PuzzleFeed(
        client: lichess((req) async {
          asked.add(req);
          return batch(
            [
              legalJson(),
              scholarJson(['h5f7']),
            ],
            glicko: {'rating': 1888.5, 'deviation': 70},
          );
        }),
        angle: 'fork',
        network: PuzzleNetwork(),
        pack: () async => pack,
        account: (user: 'tabiya', canWrite: true),
        onLichessRating: (user, g) => reported = g,
      );
      final p = await feed.next(rating: 1500, seen: const []);
      expect(p.id, 'LeGaL');
      expect(asked.first.url.queryParameters, {'nb': '3', 'difficulty': 'normal'});
      expect(asked.first.headers['Authorization'], 'Bearer lip_token');
      expect(reported?.rating, 1888.5);
    });

    test('a token without the puzzle scope: on without it', () async {
      final asked = <http.Request>[];
      final feed = PuzzleFeed(
        client: lichess((req) async {
          asked.add(req);
          return req.headers.containsKey('Authorization')
              ? http.Response('{"error":"Missing scope"}', 403)
              : batch([legalJson()]);
        }),
        angle: 'mix',
        network: PuzzleNetwork(),
        pack: () async => pack,
        account: (user: 'tabiya', canWrite: true),
      );
      await feed.next(rating: 1500, seen: const []);
      expect(feed.account, isNull);
      final p = await feed.next(rating: 1500, seen: const []);
      expect(p.id, 'LeGaL');
      expect(asked.last.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('results counted on Lichess (D-126)', () {
    final legal = Puzzle.fromLichessJson(legalJson());

    test('a result waits, the estimate moves the Lichess rating, the device rating moves too', () {
      final p0 = const PuzzleProfile().withLichessRating('tabiya', const Glicko(rating: 1800, deviation: 70));
      final r = p0.record(legal, 'fork', win: false, lichessUser: 'tabiya');
      expect(r.profile.pending, [(id: 'LeGaL', angle: 'fork', win: false)]);
      expect(r.profile.lichessGlicko!.rating, lessThan(1800));
      expect(r.diff, lessThan(0));
      expect(r.profile.glicko.rating, lessThan(1500));
      expect(r.profile.shown('tabiya').rating, r.profile.lichessGlicko!.rating);
      expect(r.profile.shown(null).rating, r.profile.glicko.rating);
      // Kept across a restart.
      expect(PuzzleProfile.decode(r.profile.encode()).pending, r.profile.pending);
    });

    test('another account starts afresh; Lichess\'s rating waits while results do', () {
      final p = const PuzzleProfile()
          .withLichessRating('a', const Glicko(rating: 1700))
          .record(legal, 'mix', win: true, lichessUser: 'a')
          .profile;
      expect(p.withLichessRating('a', const Glicko(rating: 1650)).lichessGlicko!.rating, isNot(1650));
      final other = p.forAccount('b');
      expect(other.pending, isEmpty);
      expect(other.lichessGlicko, isNull);
    });

    test('PuzzleSync sends by theme, keeps Lichess\'s rating, never sends twice', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = PuzzleRepository(db);
      await repo.update(
        (p) => p
            .record(legal, 'fork', win: true, lichessUser: 'tabiya')
            .profile
            .record(Puzzle.fromLichessJson(scholarJson(['h5f7'])), 'mateIn1', win: false, lichessUser: 'tabiya')
            .profile,
      );
      final posts = <String>[];
      final sync = PuzzleSync(
        lichess((req) async {
          posts.add('${req.url.path} ${req.body}');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final id = ((body['solutions'] as List).first as Map)['id'];
          return http.Response(
            jsonEncode({
              'puzzles': [],
              'glicko': {'rating': 1555.5, 'deviation': 90},
              'rounds': [
                {'id': id, 'win': true, 'ratingDiff': 12},
              ],
            }),
            200,
          );
        }),
        repo,
      );
      final both = await Future.wait([sync.send('tabiya'), sync.send('tabiya')]);
      expect(posts, hasLength(2), reason: 'one post per theme, shared by both calls');
      expect(posts.first, startsWith('/api/puzzle/batch/fork'));
      expect(both.first, {'LeGaL': 12, 'ScHoL': 12});
      final after = await repo.load();
      expect(after.pending, isEmpty);
      expect(after.lichessGlicko!.rating, 1555.5);
    });

    test('offline: the results stay', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = PuzzleRepository(db);
      await repo.update((p) => p.record(legal, 'fork', win: true, lichessUser: 'tabiya').profile);
      final sync = PuzzleSync(lichess((_) async => throw const SocketException('offline')), repo);
      await expectLater(sync.send('tabiya'), throwsA(isA<SocketException>()));
      expect((await repo.load()).pending, hasLength(1));
    });
  });
}
