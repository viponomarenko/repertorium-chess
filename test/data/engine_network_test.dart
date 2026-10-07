import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabiya/data/engine/engine_network.dart';
import 'package:tabiya/data/settings/app_settings.dart';

class StreamingClient extends http.BaseClient {
  StreamingClient(this.stream);
  final Stream<List<int>> stream;
  bool aborted = false;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abort = (request as http.AbortableRequest).abortTrigger!;
    final output = StreamController<List<int>>();
    final sub = stream.listen(output.add, onDone: output.close);
    unawaited(
      abort.then((_) async {
        aborted = true;
        await sub.cancel();
        output.addError(http.RequestAbortedException());
        await output.close();
      }),
    );
    return http.StreamedResponse(output.stream, 200);
  }

  @override
  void close() => closed = true;
}

void main() {
  late Directory dir;
  late EngineNetwork network;
  final bytes = List<int>.generate(4096, (i) => i % 256);
  var requests = 0;
  EngineNetwork create({http.Client Function()? client}) => EngineNetwork(
    directory: () async => dir,
    fileName: 'test.nnue',
    expectedHash: sha256.convert(bytes).toString(),
    expectedLength: bytes.length,
    client:
        client ??
        () => MockClient((_) async {
          requests++;
          return http.Response.bytes(bytes, 200);
        }),
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tabiya-network-test');
    requests = 0;
    network = create();
  });
  tearDown(() async {
    network.dispose();
    await dir.delete(recursive: true);
  });

  test('initialization never downloads; verified download is reusable offline', () async {
    expect(await network.readyPath(), isNull);
    expect(requests, 0);
    expect(await network.download(), isTrue);
    expect(await File((await network.readyPath())!).readAsBytes(), bytes);
    expect(await File('${dir.path}/test.nnue.part').exists(), isFalse);
    expect(await network.download(), isTrue);
    expect(requests, 1);
    network.dispose();
    network = create();
    expect(await network.readyPath(), '${dir.path}/test.nnue');
    expect(requests, 1);
  });

  test('corrupt stored weights and abandoned partial files are removed', () async {
    await File('${dir.path}/test.nnue').writeAsBytes(List.filled(bytes.length, 0));
    await File('${dir.path}/test.nnue.part').writeAsBytes(bytes);
    expect(await network.readyPath(), isNull);
    expect(await dir.list().length, 0);
    expect(requests, 0);
  });

  test('checksum mismatch never exposes weights to native engine', () async {
    network.dispose();
    network = create(client: () => MockClient((_) async => http.Response.bytes(List.filled(bytes.length, 0), 200)));
    expect(await network.download(), isFalse);
    expect(network.value.phase, NetworkPhase.failed);
    expect(await network.readyPath(), isNull);
    expect(await dir.list().length, 0);
  });

  test('short download fails and retry succeeds', () async {
    network.dispose();
    var first = true;
    network = create(
      client: () => MockClient((_) async {
        final data = first ? bytes.take(30).toList() : bytes;
        first = false;
        return http.Response.bytes(data, 200);
      }),
    );
    expect(await network.download(), isFalse);
    expect(await network.download(), isTrue);
    expect(network.value.phase, NetworkPhase.ready);
  });

  test('cancel aborts HTTP, removes partial data and prevents concurrent downloads', () async {
    final body = StreamController<List<int>>();
    final client = StreamingClient(body.stream);
    network.dispose();
    network = create(client: () => client);
    await network.initialize();
    final downloading = network.download();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    body.add(bytes.take(50).toList());
    expect(await network.download(), isFalse);
    network.cancel();
    expect(await downloading, isFalse);
    expect(client.aborted, isTrue);
    expect(client.closed, isTrue);
    expect(network.value.phase, NetworkPhase.missing);
    expect(await dir.list().length, 0);
    await body.close();
  });

  test('removing weights invalidates availability and allows another download', () async {
    expect(await network.download(), isTrue);
    await network.remove();
    expect(await network.readyPath(), isNull);
    expect(await network.download(), isTrue);
    expect(requests, 2);
  });

  test('external removal is detected before starting full engine', () async {
    await network.download();
    await File((await network.readyPath())!).delete();
    expect(await network.readyPath(), isNull);
    expect(network.value.phase, NetworkPhase.missing);
  });

  test('settings migrate to Light and preserve full engine selection', () {
    expect(AppSettings.fromJson({}).engineModel, 'light');
    expect(AppSettings.fromJson({'engineModel': 'unknown'}).engineModel, 'light');
    final full = const AppSettings().copyWith(engineModel: 'full');
    expect(AppSettings.decode(full.encode()).engineModel, 'full');
  });
}
