import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:multistockfish/multistockfish.dart';
import 'package:path_provider/path_provider.dart';

enum NetworkPhase { checking, missing, downloading, verifying, ready, failed }

class EngineNetworkState {
  const EngineNetworkState(this.phase, {this.received = 0, this.total = EngineNetwork.expectedBytes});
  final NetworkPhase phase;
  final int received;
  final int total;
  bool get busy => phase == NetworkPhase.downloading || phase == NetworkPhase.verifying;
}

/// Full SF19 weights are optional. Only a verified, atomically renamed file
/// may be passed to native code. Downloads never start as a side effect of analysis.
class EngineNetwork extends ValueNotifier<EngineNetworkState> {
  EngineNetwork({
    Future<Directory> Function()? directory,
    http.Client Function()? client,
    this.fileName = Stockfish.latestNNUE,
    this.expectedHash = '1a298aa575a085434d29027978dc36867fe9c5bcea9376654b7a8eba1e52dfc2',
    this.expectedLength = expectedBytes,
    Uri? url,
  }) : _directory = directory ?? _defaultDirectory,
       _client = client ?? http.Client.new,
       url = url ?? Uri.parse('https://lichess1.org/assets/lifat/nnue/${Stockfish.latestNNUE}'),
       super(const EngineNetworkState(NetworkPhase.checking));

  static const expectedBytes = 98511183;
  final Future<Directory> Function() _directory;
  final http.Client Function() _client;
  final String fileName;
  final String expectedHash;
  final int expectedLength;
  final Uri url;
  Future<void>? _initializing;
  File? _file;
  String? _readyPath;
  Completer<void>? _abort;
  http.Client? _activeClient;
  bool _disposed = false;

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/engine');

  void _publish(EngineNetworkState state) {
    if (!_disposed) value = state;
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      final dir = await _directory();
      await dir.create(recursive: true);
      final file = _file = File('${dir.path}/$fileName');
      final partial = File('${file.path}.part');
      if (await partial.exists()) await partial.delete();
      if (await file.exists()) {
        final path = file.path;
        final hash = expectedHash;
        final length = expectedLength;
        if (await _validNetworkInIsolate(path, hash, length)) {
          _readyPath = path;
          _publish(const EngineNetworkState(NetworkPhase.ready));
          return;
        }
        await file.delete();
      }
      _publish(const EngineNetworkState(NetworkPhase.missing));
    } catch (error) {
      if (kDebugMode) debugPrint('Engine network initialization: $error');
      _initializing = null;
      _publish(const EngineNetworkState(NetworkPhase.failed));
    }
  }

  Future<String?> readyPath() async {
    await initialize();
    if (_readyPath != null && !await File(_readyPath!).exists()) {
      _readyPath = null;
      _publish(const EngineNetworkState(NetworkPhase.missing));
    }
    return _readyPath;
  }

  Future<bool> download() async {
    await initialize();
    if (_disposed || value.busy || _file == null) return false;
    if (_readyPath != null) return true;
    final abort = _abort = Completer<void>();
    final client = _activeClient = _client();
    final partial = File('${_file!.path}.part');
    IOSink? sink;
    // No overall deadline: a slow connection may need longer than any
    // fixed limit for ~100 MB. A stalled one is caught by the idle timeouts
    // below and reported as a failure the user can retry.
    _publish(EngineNetworkState(NetworkPhase.downloading, total: expectedLength));
    try {
      final request = http.AbortableRequest('GET', url, abortTrigger: abort.future);
      final response = await client.send(request).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}');
      final output = sink = partial.openWrite();
      var received = 0;
      var lastProgress = 0;
      await for (final bytes in response.stream.timeout(const Duration(seconds: 20))) {
        if (abort.isCompleted) throw const NetworkDownloadCancelled();
        received += bytes.length;
        if (received > expectedLength) throw const FormatException('Unexpected network size');
        output.add(bytes);
        // Apply backpressure and avoid rebuilding UI for every network packet.
        if (received - lastProgress >= 256 * 1024 || received == expectedLength) {
          await output.flush();
          lastProgress = received;
          _publish(EngineNetworkState(NetworkPhase.downloading, received: received, total: expectedLength));
        }
      }
      await output.close();
      sink = null;
      if (abort.isCompleted) throw const NetworkDownloadCancelled();
      _publish(const EngineNetworkState(NetworkPhase.verifying));
      final path = partial.path;
      final hash = expectedHash;
      final length = expectedLength;
      if (!await _validNetworkInIsolate(path, hash, length)) {
        throw const FormatException('Network checksum mismatch');
      }
      if (abort.isCompleted) throw const NetworkDownloadCancelled();
      await partial.rename(_file!.path);
      _readyPath = _file!.path;
      _publish(const EngineNetworkState(NetworkPhase.ready));
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('Engine network download: $error');
      try {
        await sink?.close();
      } catch (_) {
        // The original write error is already reported below.
      }
      try {
        if (await partial.exists()) await partial.delete();
      } catch (_) {
        // Initialization retries cleanup before accepting any local weights.
      }
      _publish(EngineNetworkState(abort.isCompleted ? NetworkPhase.missing : NetworkPhase.failed));
      return false;
    } finally {
      client.close();
      _activeClient = null;
      _abort = null;
    }
  }

  void cancel() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _activeClient?.close();
  }

  Future<void> remove() async {
    await initialize();
    if (value.busy) return;
    _readyPath = null;
    try {
      if (await _file!.exists()) await _file!.delete();
      _publish(const EngineNetworkState(NetworkPhase.missing));
    } catch (_) {
      _publish(const EngineNetworkState(NetworkPhase.failed));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}

class NetworkDownloadCancelled implements Exception {
  const NetworkDownloadCancelled();
}

/// Checks the file off the UI thread. Top-level, so the closure sent to the
/// isolate holds only its arguments, never the owning service.
Future<bool> _validNetworkInIsolate(String path, String prefix, int length) =>
    Isolate.run(() => _validNetwork(path, prefix, length));

Future<bool> _validNetwork(String path, String prefix, int length) async {
  final file = File(path);
  if (await file.length() != length) return false;
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString().startsWith(prefix);
}
