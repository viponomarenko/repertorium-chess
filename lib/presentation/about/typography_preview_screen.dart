/// Debug-only page with every text style, notation with variations and
/// NAGs, all three notation languages and tabular numbers (acceptance for
/// the typography section; also used by the golden tests).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../domain/pgn/pgn_model.dart';
import '../../domain/pgn/pgn_parser.dart';
import '../app/providers.dart';
import '../theme/typography.dart';
import '../widgets/board_view.dart';
import '../widgets/notation_view.dart';
import '../widgets/san_text.dart';

/// Test line from the specification: Ukrainian letters, apostrophe U+02BC,
/// guillemets, numero sign and evaluation symbols.
const kTypographyTestLine =
    'Чуєш їх, доцю, га? Кумедна ж ти, прощайся без ґольфів! Пʼять позицій, «Сицилійський захист», № 12, ±, ⩲.';

const kTypographyPgn =
    '1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6 {Найдорф: гнучкий хід, що готує e5 або b5.} '
    '6. Be3 (6. Bg5!? e6 7. f4 Qb6 (7... Be7 8. Qf3 Qc7) 8. Qd2?! Qxb2) 6... e5! 7. Nb3 Be6 8. f3?? '
    '(8. Qd2 Nbd7 9. f3 Be7 (9... h5 10. O-O-O) 10. O-O-O) 8... d5 9. exd5 Nxd5 10. Nxd5 Qxd5 11. Qxd5 Bxd5 '
    '12. O-O-O Nc6 13. Bc4 Bxc4 14. Rd8+?! Rxd8 *';

class TypographyPreviewScreen extends ConsumerStatefulWidget {
  const TypographyPreviewScreen({super.key});

  @override
  ConsumerState<TypographyPreviewScreen> createState() => _TypographyPreviewScreenState();
}

class _TypographyPreviewScreenState extends ConsumerState<TypographyPreviewScreen> {
  late final ChessGame _game = PgnParser.parseOne(kTypographyPgn);
  late GameNode _current = _game.root.mainChild!.mainChild!;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final cs = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final lang = NotationLanguage.fromName(settings.notationLanguage);
    final pieces = BoardAppearance.pieceSet(settings.pieceSet).assets;
    Widget style(String name, TextStyle? s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name · ${s?.fontSize?.round()}/${((s?.height ?? 1) * (s?.fontSize ?? 0)).round()}',
            style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(kTypographyTestLine, style: s),
        ],
      ),
    );
    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(title, style: t.titleLarge),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.typographyPreview)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section('Styles'),
          style('displaySmall', t.displaySmall),
          style('headlineSmall', t.headlineSmall),
          style('titleLarge', t.titleLarge),
          style('titleMedium', t.titleMedium),
          style('bodyLarge', t.bodyLarge),
          style('bodyMedium', t.bodyMedium),
          style('bodySmall', t.bodySmall),
          style('labelLarge', t.labelLarge),
          style('labelSmall', t.labelSmall),
          style('mono', context.tt.mono),
          section('Notation'),
          NotationView(game: _game, current: _current, onSelect: (n) => setState(() => _current = n)),
          section('Languages'),
          for (final language in NotationLanguage.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 88, child: Text(language.name, style: t.labelLarge)),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: NotationFormatter(
                          language,
                          pieces,
                        ).spans('1. e4 Nf6 2. Bc4 Qe7 3. O-O Kd8 4. Rxe1+ e8=Q#', context.tt.moveMain),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Text('current: ${lang.name}', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          section('Tabular figures'),
          for (final n in [1, 11, 111, 1111, 12345, 1234567])
            Text(
              '${context.fmtInt(n)} · ${context.fmtPercent(n % 100 / 100)} · ${context.fmtEval(cp: n % 400 - 200)}',
              style: t.bodyLarge?.tabular,
            ),
          Text(context.fmtDateTime(DateTime(2026, 9, 27, 18, 5)), style: t.bodyLarge?.tabular),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
