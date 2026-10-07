import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabiya/data/chesscom/chesscom_client.dart';
import 'package:tabiya/data/lichess/lichess_client.dart';

http.StreamedResponse _text(String body, int status, {Map<String, String> headers = const {}}) =>
    http.StreamedResponse(Stream.value(utf8.encode(body)), status, headers: headers);

void main() {
  group('Lichess client (F-LI)', () {
    test('User-Agent and bearer token are sent', () async {
      late http.BaseRequest seen;
      final client = LichessClient(
        client: MockClient.streaming((req, _) async {
          seen = req;
          return _text('{"id":"tabiya","username":"Tabiya"}', 200);
        }),
        userAgent: 'Tabiya/1.0 (+https://example.org)',
        tokenProvider: () async => 'lip_token',
      );
      final acc = await client.account();
      expect(acc.username, 'Tabiya');
      expect(seen.headers['User-Agent'], 'Tabiya/1.0 (+https://example.org)');
      expect(seen.headers['Authorization'], 'Bearer lip_token');
      expect(seen.url.toString(), 'https://lichess.org/api/account');
    });

    test('429: waits at least the configured pause, notifies, retries', () async {
      var calls = 0;
      final pauses = <Duration>[];
      final client = LichessClient(
        client: MockClient.streaming((req, _) async {
          calls++;
          return calls == 1 ? _text('slow down', 429) : _text('[Event "x"]\n\n1. e4 *', 200);
        }),
        userAgent: 'ua',
        sleep: (d) async => pauses.add(d),
      );
      final events = <Duration>[];
      final sub = client.rateLimitEvents.listen(events.add);
      final pgn = await client.gamePgn('abcdefgh');
      expect(pgn, contains('1. e4'));
      expect(calls, 2);
      expect(pauses.single, greaterThanOrEqualTo(const Duration(seconds: 60)));
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      await sub.cancel();
    });

    test('401 surfaces as unauthorized', () async {
      final client = LichessClient(
        client: MockClient.streaming((req, _) async => _text('{"error":"No such token"}', 401)),
        userAgent: 'ua',
        tokenProvider: () async => 'expired',
      );
      await expectLater(
        client.account(),
        throwsA(isA<LichessException>().having((e) => e.isUnauthorized, 'unauthorized', isTrue)),
      );
    });

    test('only one request at a time (queue)', () async {
      var active = 0;
      var maxActive = 0;
      final client = LichessClient(
        client: MockClient.streaming((req, _) async {
          active++;
          maxActive = active > maxActive ? active : maxActive;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          active--;
          return _text('[Event "x"]\n\n*', 200);
        }),
        userAgent: 'ua',
      );
      await Future.wait([for (var i = 0; i < 5; i++) client.gamePgn('game000$i')]);
      expect(maxActive, 1);
    });

    test('NDJSON games stream, and a broken stream keeps received games', () async {
      final controller = StreamController<List<int>>();
      final client = LichessClient(
        client: MockClient.streaming((req, _) async {
          expect(req.headers['Accept'], 'application/x-ndjson');
          expect(req.url.queryParameters['since'], '1000');
          return http.StreamedResponse(controller.stream, 200);
        }),
        userAgent: 'ua',
      );
      final got = <LichessGame>[];
      Object? error;
      final done = Completer<void>();
      client
          .userGames('tabiya', since: DateTime.fromMillisecondsSinceEpoch(1000))
          .listen(got.add, onError: (Object e) => error = e, onDone: done.complete);
      Map<String, Object?> game(String id, String winner) => {
        'id': id,
        'createdAt': 1700000000000,
        'speed': 'blitz',
        'rated': true,
        'status': 'mate',
        'winner': winner,
        'players': {
          'white': {
            'user': {'id': 'tabiya', 'name': 'Tabiya'},
          },
          'black': {'aiLevel': 3},
        },
        'pgn': '1. e4 e5 *',
        'clock': {'initial': 180, 'increment': 2},
      };
      controller.add(utf8.encode('${jsonEncode(game('aaaaaaaa', 'white'))}\n'));
      controller.add(utf8.encode('${jsonEncode(game('bbbbbbbb', 'black'))}\n{"id":"broken'));
      controller.addError(http.ClientException('Connection closed'));
      await controller.close();
      await done.future;
      expect(got.map((g) => g.id), ['aaaaaaaa', 'bbbbbbbb']);
      expect(got.first.result, '1-0');
      expect(got.first.black, '', reason: 'AI opponent has no user');
      expect(got.first.timeControl, '3+2');
      expect(error, isA<http.ClientException>());
    });

    test('cloud eval 404 returns null', () async {
      final client = LichessClient(
        client: MockClient.streaming(
          (req, _) async => _text('{"error":"No cloud evaluation available for that position"}', 404),
        ),
        userAgent: 'ua',
      );
      expect(await client.cloudEval('8/8/8/8/8/8/8/K6k w - - 0 1'), isNull);
    });

    test('explorer parsing', () async {
      final client = LichessClient(
        client: MockClient.streaming((req, _) async {
          expect(req.url.host, 'explorer.lichess.org');
          expect(req.url.path, '/masters');
          return _text(
            jsonEncode({
              'white': 10,
              'draws': 5,
              'black': 5,
              'opening': {'eco': 'B00', 'name': "King's Pawn"},
              'moves': [
                {'uci': 'e7e5', 'san': 'e5', 'white': 5, 'draws': 3, 'black': 2, 'averageRating': 2500},
              ],
            }),
            200,
          );
        }),
        userAgent: 'ua',
        tokenProvider: () async => 't',
      );
      final r = await client.explorer('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
      expect(r.total, 20);
      expect(r.moves.single.san, 'e5');
      expect(r.eco, 'B00');
    });

    test('URL recognition', () {
      final s = LichessUrl.parse('https://lichess.org/study/AbCdEfGh');
      expect(s!.kind, LichessUrlKind.study);
      final c = LichessUrl.parse('https://lichess.org/study/AbCdEfGh/IjKlMnOp#3');
      expect(c!.kind, LichessUrlKind.chapter);
      expect(c.chapterId, 'IjKlMnOp');
      final g = LichessUrl.parse('https://lichess.org/q7ZvsdUFabcd/black');
      expect(g!.kind, LichessUrlKind.game);
      expect(g.id, 'q7ZvsdUF');
      expect(LichessUrl.parse('https://lichess.org/training'), isNull);
    });
  });

  group('Chess.com client (F-CC)', () {
    test('player: 404 means not found; username is lowercased; UA sent', () async {
      final seen = <http.BaseRequest>[];
      final client = ChessComClient(
        client: MockClient((req) async {
          seen.add(req);
          return http.Response('{"code":0,"message":"User \\"x\\" not found."}', 404);
        }),
        userAgent: 'Tabiya/1.0 (contact: a@b.c)',
      );
      expect(await client.player('SomeOne'), isNull);
      expect(seen.single.url.path, '/pub/player/someone');
      expect(seen.single.headers['User-Agent'], contains('contact:'));
    });

    test('month: ETag conditional request, 304 = unchanged', () async {
      final seen = <http.BaseRequest>[];
      final client = ChessComClient(
        client: MockClient((req) async {
          seen.add(req);
          if (req.headers['If-None-Match'] == '"v1"') return http.Response('', 304);
          return http.Response(
            jsonEncode({
              'games': [
                {
                  'url': 'https://www.chess.com/game/live/123',
                  'pgn': '[Event "Live"]\n\n1. e4 *',
                  'end_time': 1700000000,
                  'time_control': '180+2',
                  'time_class': 'blitz',
                  'rated': true,
                  'rules': 'chess',
                  'white': {'username': 'Me', 'result': 'win'},
                  'black': {'username': 'Other', 'result': 'resigned'},
                },
              ],
            }),
            200,
            headers: {'etag': '"v1"', 'last-modified': 'Tuesday, 01-Sep-2026 22:54:08 GMT+0000'},
          );
        }),
        userAgent: 'ua',
      );
      final url = Uri.parse('https://api.chess.com/pub/player/me/games/2026/09');
      final first = await client.month(url);
      expect(first.notModified, isFalse);
      expect(first.games.single.result, '1-0');
      expect(first.games.single.id, '123');
      expect(first.etag, '"v1"');
      final second = await client.month(url, etag: first.etag, lastModified: first.lastModified);
      expect(second.notModified, isTrue);
      expect(seen.last.headers['If-Modified-Since'], first.lastModified);
    });

    test('429: exponential backoff, strictly sequential', () async {
      var calls = 0;
      var active = 0;
      var maxActive = 0;
      final waits = <Duration>[];
      final client = ChessComClient(
        client: MockClient((req) async {
          active++;
          maxActive = active > maxActive ? active : maxActive;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          active--;
          calls++;
          if (calls <= 2) return http.Response('', 429);
          return http.Response('{"archives":["https://api.chess.com/pub/player/me/games/2026/09"]}', 200);
        }),
        userAgent: 'ua',
        sleep: (d) async => waits.add(d),
      );
      final results = await Future.wait([client.archives('me'), client.archives('me')]);
      expect(results.first.single.pathSegments.last, '09');
      expect(waits, [const Duration(seconds: 2), const Duration(seconds: 4)]);
      expect(maxActive, 1);
    });
  });
}
