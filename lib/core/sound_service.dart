import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

enum GameSound { move, capture, error, success, line }

/// Short UI sounds (F-VIEW-05, D-049): move, capture, correct move
/// (success), mistake (error) and line completed (line); see NOTICE.
class SoundService {
  SoundService();

  final Map<GameSound, AudioPlayer> _players = {};
  bool enabled = true;
  bool haptics = true;

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers, respectSilence: true).build(),
      );
      for (final s in GameSound.values) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sounds/${s.name}.wav'));
        _players[s] = p;
      }
    } catch (_) {
      // Sound is optional (e.g. tests, unsupported platforms).
    }
  }

  Future<void> play(GameSound s) async {
    if (haptics) {
      switch (s) {
        case GameSound.error:
          await HapticFeedback.mediumImpact();
        case GameSound.capture:
        case GameSound.move:
          await HapticFeedback.selectionClick();
        case GameSound.success:
        case GameSound.line:
          await HapticFeedback.lightImpact();
      }
    }
    if (!enabled) return;
    final p = _players[s];
    if (p == null) return;
    try {
      await p.stop();
      await p.resume();
    } catch (_) {}
  }

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
  }
}
