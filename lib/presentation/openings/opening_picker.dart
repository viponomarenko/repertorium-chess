import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../domain/openings/opening_book.dart';
import '../app/providers.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/san_text.dart';

/// The moves of an opening as notation ("1. e4 c5 2. Nf3").
String openingMovesText(OpeningInfo o) {
  final sb = StringBuffer();
  for (var i = 0; i < o.moves.length; i++) {
    if (i.isEven) sb.write('${i ~/ 2 + 1}. ');
    sb.write('${o.moves[i]} ');
  }
  return sb.toString().trim();
}

/// An opening in a list: its ECO code, its name and its moves.
class OpeningTile extends StatelessWidget {
  const OpeningTile({super.key, required this.opening, required this.onTap});
  final OpeningInfo opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: AppAvatar(text: opening.eco),
    title: Text(opening.name),
    subtitle: MovesText(openingMovesText(opening), maxLines: 2, overflow: TextOverflow.ellipsis),
    onTap: onTap,
  );
}

/// The catalog of openings as a sheet with a search; returns the opening
/// tapped (a start position without typing moves or a FEN, D-088).
Future<OpeningInfo?> showOpeningPicker(BuildContext context) => showAppSheet<OpeningInfo>(
  context,
  title: context.l10n.openingsTitle,
  scrollable: false,
  builder: (_) => const _OpeningPicker(),
);

class _OpeningPicker extends ConsumerStatefulWidget {
  const _OpeningPicker();

  @override
  ConsumerState<_OpeningPicker> createState() => _OpeningPickerState();
}

class _OpeningPickerState extends ConsumerState<_OpeningPicker> {
  /// Share of the screen the sheet takes: the same height while the
  /// search narrows the list, so the sheet does not jump.
  static const double _share = 0.75;

  String _q = '';

  /// Shown first while nothing is searched: the main line of each opening
  /// people play most, instead of the catalog's alphabetical start (A00).
  static const _popular = [
    'Sicilian Defense',
    'French Defense',
    'Caro-Kann Defense',
    'Italian Game',
    'Ruy Lopez',
    'Scotch Game',
    'Scandinavian Defense',
    'Pirc Defense',
    "Queen's Gambit Declined",
    "Queen's Gambit Accepted",
    'Slav Defense',
    'Catalan Opening',
    "King's Indian Defense",
    'Nimzo-Indian Defense',
    'Grünfeld Defense',
    'Dutch Defense',
    'London System',
    'English Opening',
  ];

  List<OpeningInfo> _popularIn(OpeningBook b) => [
    for (final name in _popular) ?b.search(name, limit: 50).where((o) => o.name == name).firstOrNull,
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final book = ref.watch(openingBookProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * _share,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.sm),
            child: TextField(
              decoration: InputDecoration(prefixIcon: const Icon(AppIcons.search), hintText: l.openingsSearchHint),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: book.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorState(
                message: l.somethingWentWrong,
                details: e,
                onRetry: () => ref.invalidate(openingBookProvider),
              ),
              data: (b) {
                final results = b.search(_q, limit: 300);
                final popular = _q.trim().isEmpty ? _popularIn(b) : const <OpeningInfo>[];
                Widget tile(OpeningInfo o) => OpeningTile(opening: o, onTap: () => Navigator.pop(context, o));
                return CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    if (popular.isNotEmpty) ...[
                      SliverToBoxAdapter(child: SectionHeader(l.popularOpenings)),
                      SliverList.builder(itemCount: popular.length, itemBuilder: (_, i) => tile(popular[i])),
                      SliverToBoxAdapter(child: SectionHeader(l.allOpenings)),
                    ],
                    SliverList.builder(itemCount: results.length, itemBuilder: (_, i) => tile(results[i])),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
