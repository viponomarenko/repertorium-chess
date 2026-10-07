import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tabiya/data/lichess/lichess_client.dart';

class Transport extends http.BaseClient {
  Transport(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

http.StreamedResponse response(int status) => http.StreamedResponse(
  Stream.value(utf8.encode(status == 200 ? '{"depth":20,"pvs":[{"moves":"e2e4","cp":20}]}' : '{}')),
  status,
);
Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('timeout aborts real request and releases the queue', () async {
    var aborted = false;
    var calls = 0;
    final client = LichessClient(
      userAgent: 'test',
      client: Transport((r) async {
        calls++;
        if (calls == 1) {
          await (r as http.AbortableRequest).abortTrigger;
          aborted = true;
          throw http.RequestAbortedException(r.url);
        }
        return response(200);
      }),
    );
    await expectLater(
      client.cloudEval('old', budget: const Duration(milliseconds: 15)),
      throwsA(isA<http.RequestAbortedException>()),
    );
    expect((await client.cloudEval('new'))!.depth, 20);
    expect(aborted, isTrue);
    expect(client.pending, 0);
    client.close();
  });

  test('cancelled queued position never sends an HTTP request', () async {
    final gate = Completer<void>();
    final seen = <String>[];
    final client = LichessClient(
      userAgent: 'test',
      client: Transport((r) async {
        seen.add(r.url.queryParameters['fen']!);
        if (seen.length == 1) await gate.future;
        return response(200);
      }),
    );
    final first = client.cloudEval('first');
    await flush();
    final abort = Completer<void>();
    final queued = client.cloudEval('obsolete', abort: abort.future);
    final assertion = expectLater(queued, throwsA(isA<http.RequestAbortedException>()));
    abort.complete();
    await assertion;
    gate.complete();
    await first;
    await flush();
    expect(seen, ['first']);
    expect(client.pending, 0);
    client.close();
  });

  test('cancelling 429 does not bypass the shared cooldown', () async {
    final pause = Completer<void>();
    var calls = 0;
    final client = LichessClient(
      userAgent: 'test',
      sleep: (_) => pause.future,
      client: Transport((r) async => response(++calls == 1 ? 429 : 200)),
    );
    final abort = Completer<void>();
    final first = client.cloudEval('old', abort: abort.future);
    final assertion = expectLater(first, throwsA(isA<http.RequestAbortedException>()));
    await flush();
    abort.complete();
    await assertion;
    final next = client.cloudEval('new');
    await flush();
    expect(calls, 1);
    pause.complete();
    expect((await next)!.depth, 20);
    expect(calls, 2);
    client.close();
  });

  test('cache includes requested MultiPV and remembers missing positions', () async {
    var calls = 0;
    final client = LichessClient(
      userAgent: 'test',
      client: Transport((r) async {
        calls++;
        return response(r.url.queryParameters['fen'] == 'missing' ? 404 : 200);
      }),
    );
    await client.cloudEval('position');
    await client.cloudEval('position');
    expect(calls, 1);
    await client.cloudEval('position', multiPv: 3);
    expect(calls, 2);
    expect(await client.cloudEval('missing'), isNull);
    expect(await client.cloudEval('missing'), isNull);
    expect(calls, 3);
    client.close();
  });
}
