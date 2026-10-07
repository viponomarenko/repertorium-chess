// Keeps design values in one place (D-075): screens and widgets must not
// spell out colours, paddings, gaps, radii, icon sizes, durations or font
// sizes. Those live in lib/presentation/theme (tokens, colours, text) and
// in the shared widgets of lib/presentation/widgets/ui.
//
// design_tokens_baseline.json may list files with the number of literals
// they are still allowed to hold (it was used while screens were being
// migrated and is empty now). The number can only go down.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _update = bool.fromEnvironment('UPDATE_TOKENS_BASELINE');

final _rules = <String, RegExp>{
  'colour literal': RegExp(r'\bColor\(0x|\bColors\.(?!transparent\b)[a-zA-Z]'),
  'padding literal': RegExp(r'EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*(?<![\w.])(?:[1-9]\d*|0?\.\d+)'),
  'gap literal': RegExp(r'SizedBox\((height|width): [\d.]+\)'),
  'radius literal': RegExp(r'Radius\.circular\([\d.]+\)'),
  'icon size literal': RegExp(r'\bIcon\([^;]*?size: [\d.]+'),
  'duration literal': RegExp(r'Duration\(milliseconds: \d'),
  'font literal': RegExp(r'fontSize: [\d.]|FontWeight\.w\d'),
  'opacity literal': RegExp(r'withValues\(alpha: [\d.]+\)'),
  // Menus are built from appMenuItem / appMenuDivider (D-081).
  'hand-built menu row': RegExp(r'\bPopupMenuItem\b|\bPopupMenuDivider\b|\bshowMenu\b'),
};

bool _exempt(String path) =>
    path.startsWith('lib/presentation/theme/') ||
    path.startsWith('lib/presentation/widgets/ui/') ||
    path.startsWith('lib/presentation/about/typography_preview_screen.dart') ||
    // The logo is a drawing with its own colours and geometry (D-033).
    path.startsWith('lib/presentation/widgets/app_logo.dart');

void main() {
  test('no design literals outside the theme and the shared widgets', () {
    final baselineFile = File('test/presentation/design_tokens_baseline.json');
    final baseline = baselineFile.existsSync()
        ? (jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>).cast<String, int>()
        : <String, int>{};

    final found = <String, int>{};
    final details = <String, List<String>>{};
    final files = Directory('lib/presentation').listSync(recursive: true).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || _exempt(path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final rule in _rules.entries) {
          final n = rule.value.allMatches(line).length;
          if (n == 0) continue;
          found[path] = (found[path] ?? 0) + n;
          (details[path] ??= []).add('  $path:${i + 1}: ${rule.key}: ${line.trim()}');
        }
      }
    }

    if (_update) {
      baselineFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(found)}\n');
      return;
    }

    final problems = <String>[];
    for (final e in found.entries) {
      final allowed = baseline[e.key] ?? 0;
      if (e.value > allowed) {
        problems.add('${e.key}: ${e.value} literals, ${allowed == 0 ? 'none' : allowed} allowed');
        if (allowed == 0) problems.addAll(details[e.key]!);
      }
    }
    for (final e in baseline.entries) {
      final now = found[e.key] ?? 0;
      if (now < e.value) problems.add('${e.key}: baseline says ${e.value}, the file has $now: lower the baseline');
    }
    expect(problems, isEmpty, reason: 'Use the tokens of lib/presentation/theme/tokens.dart:\n${problems.join('\n')}');
  });
}
