import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../domain/chess/chess_utils.dart';
import '../app/providers.dart';
import '../repertoire/create_repertoire_dialog.dart';
import '../theme/app_icons.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import '../widgets/san_text.dart';
import 'game_screen.dart';

/// Position editor (F-EDIT-05): place pieces, side to move, castling,
/// en passant. With [pickMode] the FEN is returned to the caller.
class PositionEditorScreen extends ConsumerStatefulWidget {
  const PositionEditorScreen({super.key, this.initialFen, this.pickMode = false});
  final String? initialFen;
  final bool pickMode;

  @override
  ConsumerState<PositionEditorScreen> createState() => _PositionEditorScreenState();
}

class _PositionEditorScreenState extends ConsumerState<PositionEditorScreen> {
  late Pieces _pieces;
  Side _turn = Side.white;
  final Set<String> _castling = {};
  String? _ep;
  Side _orientation = Side.white;

  /// Selected palette piece; null = move pieces by dragging.
  Piece? _brush;
  bool _eraser = false;

  @override
  void initState() {
    super.initState();
    if (!_load(widget.initialFen ?? kInitialFen)) _load(kInitialFen);
    _openedFen = _fen;
  }

  /// The position the editor opened with: leaving a changed one asks first.
  late final String _openedFen;

  bool _load(String fen) {
    try {
      // Syntax validation allows unfinished setups, including an empty board.
      // Parse everything before changing any state, so bad input is harmless.
      final setup = Setup.parseFen(fen.trim());
      final pieces = readFen(setup.board.fen);
      final parts = fen.trim().split(RegExp(r'\s+'));
      _pieces = pieces;
      _turn = setup.turn;
      _castling
        ..clear()
        ..addAll(parts.length > 2 && parts[2] != '-' ? parts[2].split('') : const []);
      _ep = setup.epSquare?.name;
      return true;
    } catch (_) {
      return false;
    }
  }

  String _pieceLabel(Piece? piece, AppLocalizations l) =>
      piece == null ? l.emptySquare : '${piece.color == Side.white ? l.white : l.black} ${_roleName(piece.role, l)}';

  /// A form alternative to dragging, usable with screen readers and large text.
  Future<void> _editAccessibleSquare() async {
    final l = context.l10n;
    var square = Square.fromName('e4');
    Square? destination;
    Piece? piece = _pieces[square];
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(l.editSquare),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Square>(
                initialValue: square,
                isExpanded: true,
                itemHeight: null,
                decoration: InputDecoration(labelText: l.squareLabel),
                items: [
                  for (var i = 0; i < 64; i++)
                    DropdownMenuItem(
                      value: Square(i),
                      child: Text('${Square(i).name}: ${_pieceLabel(_pieces[Square(i)], l)}'),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    update(() {
                      square = v;
                      piece = _pieces[v];
                      destination = null;
                    });
                  }
                },
              ),
              AppGap.v16,
              DropdownButtonFormField<Piece>(
                key: ValueKey(square),
                initialValue: piece,
                isExpanded: true,
                itemHeight: null,
                hint: Text(l.emptySquare),
                decoration: InputDecoration(labelText: l.pieceLabel),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.emptySquare)),
                  for (final side in Side.values)
                    for (final role in Role.values)
                      DropdownMenuItem(
                        value: Piece(color: side, role: role),
                        child: Text(_pieceLabel(Piece(color: side, role: role), l)),
                      ),
                ],
                onChanged: (v) => update(() {
                  piece = v;
                  if (v == null) destination = null;
                }),
              ),
              AppGap.v16,
              DropdownButtonFormField<Square>(
                key: ValueKey((square, piece)),
                initialValue: destination,
                isExpanded: true,
                itemHeight: null,
                hint: Text(l.keepOnSquare),
                decoration: InputDecoration(labelText: l.moveToSquare),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.keepOnSquare)),
                  for (var i = 0; i < 64; i++)
                    if (Square(i) != square) DropdownMenuItem(value: Square(i), child: Text(Square(i).name)),
                ],
                onChanged: piece == null ? null : (v) => update(() => destination = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.done)),
          ],
        ),
      ),
    );
    if (apply != true || !mounted) return;
    setState(() {
      _pieces = {..._pieces}..remove(square);
      if (piece != null) _pieces[destination ?? square] = piece!;
    });
  }

  /// Castling rights that are consistent with the kings/rooks placement.
  bool _castlingPossible(String c) {
    Piece? at(String sq) => _pieces[Square.fromName(sq)];
    bool isP(String sq, Role r, Side s) => at(sq)?.role == r && at(sq)?.color == s;
    return switch (c) {
      'K' => isP('e1', Role.king, Side.white) && isP('h1', Role.rook, Side.white),
      'Q' => isP('e1', Role.king, Side.white) && isP('a1', Role.rook, Side.white),
      'k' => isP('e8', Role.king, Side.black) && isP('h8', Role.rook, Side.black),
      'q' => isP('e8', Role.king, Side.black) && isP('a8', Role.rook, Side.black),
      _ => false,
    };
  }

  String get _fen {
    final castling = ['K', 'Q', 'k', 'q'].where((c) => _castling.contains(c) && _castlingPossible(c)).join();
    return '${writeFen(_pieces)} ${_turn == Side.white ? 'w' : 'b'} ${castling.isEmpty ? '-' : castling} ${_ep ?? '-'} 0 1';
  }

  String? _validate(AppLocalizations l) {
    try {
      Chess.fromSetup(Setup.parseFen(_fen));
      return null;
    } on PositionSetupException catch (e) {
      // An empty board gets a hint of what to do, not just "invalid".
      if (_pieces.isEmpty) return l.setupEmptyBoard;
      return switch (e.cause) {
        IllegalSetupCause.kings => l.setupKings,
        IllegalSetupCause.pawnsOnBackrank => l.setupPawns,
        IllegalSetupCause.oppositeCheck => l.setupOppositeCheck,
        IllegalSetupCause.impossibleCheck => l.setupImpossibleCheck,
        _ => l.setupInvalid,
      };
    } catch (_) {
      return _pieces.isEmpty ? l.setupEmptyBoard : l.setupInvalid;
    }
  }

  List<String> _epCandidates() {
    // The opponent's pawn has just made a double step past these squares.
    final out = <String>[];
    final pawnRank = _turn == Side.white ? 4 : 3;
    final epRank = _turn == Side.white ? 5 : 2;
    final originRank = _turn == Side.white ? 6 : 1;
    for (var f = 0; f < 8; f++) {
      final pawn = _pieces[Square(pawnRank * 8 + f)];
      if (pawn?.role == Role.pawn &&
          pawn?.color == _turn.opposite &&
          _pieces[Square(epRank * 8 + f)] == null &&
          _pieces[Square(originRank * 8 + f)] == null) {
        out.add(Square(epRank * 8 + f).name);
      }
    }
    return out;
  }

  static String _roleName(Role r, AppLocalizations l) => switch (r) {
    Role.king => l.pieceKing,
    Role.queen => l.pieceQueen,
    Role.rook => l.pieceRook,
    Role.bishop => l.pieceBishop,
    Role.knight => l.pieceKnight,
    Role.pawn => l.piecePawn,
  };

  Widget _palette(Side side) {
    final set = BoardAppearance.pieceSet(ref.watch(settingsProvider).pieceSet);
    final roles = [Role.king, Role.queen, Role.rook, Role.bishop, Role.knight, Role.pawn];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final r in roles)
          Builder(
            builder: (context) {
              final piece = Piece(color: side, role: r);
              final selected = !_eraser && _brush == piece;
              return Draggable<Piece>(
                data: piece,
                feedback: SizedBox.square(
                  dimension: AppSizes.tapTarget,
                  child: Image(image: set.assets[piece.kind]!),
                ),
                child: InkWell(
                  onTap: () => setState(() {
                    _eraser = false;
                    _brush = selected ? null : piece;
                  }),
                  borderRadius: AppRadius.smAll,
                  child: Container(
                    width: AppSizes.tapTarget,
                    height: AppSizes.tapTarget,
                    decoration: BoxDecoration(
                      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
                      borderRadius: AppRadius.smAll,
                    ),
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Semantics(
                      label:
                          '${side == Side.white ? context.l10n.white : context.l10n.black} ${_roleName(r, context.l10n)}',
                      selected: selected,
                      button: true,
                      child: Image(image: set.assets[piece.kind]!),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final eps = _epCandidates();
    if (_ep != null && !eps.contains(_ep)) _ep = null;
    final error = _validate(l);

    Future<void> pasteFen() async {
      final d = await Clipboard.getData(Clipboard.kTextPlain);
      var t = d?.text?.trim() ?? '';
      // iOS may hide the clipboard from the app: ask to paste instead.
      if (t.isEmpty && context.mounted) {
        t = (await promptText(context, title: l.pasteFen, label: 'FEN', mono: true))?.trim() ?? '';
        if (t.isEmpty) return;
      }
      if (!context.mounted) return;
      if (_load(t)) {
        setState(() {});
      } else {
        showSnack(context, l.invalidFen);
      }
    }

    return PopScope(
      // A position set up by hand is not dropped by one stray Back.
      canPop: _fen == _openedFen,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(
          context,
          title: l.leavePositionQ,
          message: l.leavePositionMessage,
          confirmLabel: l.discard,
          cancelLabel: l.stay,
          destructive: true,
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.positionEditor),
          actions: [
            IconButton(
              tooltip: l.flipBoard,
              onPressed: () => setState(() => _orientation = _orientation.opposite),
              icon: const Icon(AppIcons.flip),
            ),
            // The rare FEN actions sit in a menu: four icons squeezed the
            // title to "Position e…".
            PopupMenuButton<String>(
              constraints: appMenuConstraints,
              icon: const Icon(AppIcons.more),
              tooltip: l.more,
              onSelected: (v) {
                if (v == 'copy') {
                  Clipboard.setData(ClipboardData(text: _fen));
                  showSnack(context, l.copied);
                } else {
                  unawaited(pasteFen());
                }
              },
              itemBuilder: (_) => [
                appMenuItem(value: 'copy', icon: AppIcons.copy, label: l.copyFen),
                appMenuItem(value: 'paste', icon: AppIcons.paste, label: l.pasteFen),
              ],
            ),
            if (widget.pickMode)
              IconButton(
                tooltip: l.done,
                onPressed: error == null ? () => context.pop(positionFromFen(_fen).fen) : null,
                icon: const Icon(AppIcons.check),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            children: [
              _palette(_orientation.opposite),
              LayoutBuilder(
                builder: (context, c) {
                  final size = c.maxWidth.clamp(0.0, 560.0);
                  return Center(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: kBoardTextScaleMax,
                      child: Semantics(
                        label:
                            '${l.positionEditor}, ${_eraser
                                ? l.eraser
                                : _brush != null
                                ? _pieceLabel(_brush, l)
                                : l.dragMode}',
                        hint: l.editSquareHint,
                        button: true,
                        onTap: _editAccessibleSquare,
                        excludeSemantics: true,
                        child: ChessboardEditor(
                          size: size,
                          orientation: _orientation,
                          pieces: _pieces,
                          pointerMode: _brush != null || _eraser ? EditorPointerMode.edit : EditorPointerMode.drag,
                          settings: BoardAppearance.settings(settings),
                          onEditedSquare: (sq) => setState(() {
                            if (_eraser) {
                              _pieces = {..._pieces}..remove(sq);
                            } else if (_brush != null) {
                              final existing = _pieces[sq];
                              _pieces = {..._pieces};
                              if (existing == _brush) {
                                _pieces.remove(sq);
                              } else {
                                _pieces[sq] = _brush!;
                              }
                            }
                          }),
                          onDroppedPiece: (origin, dest, piece) => setState(() {
                            _pieces = {..._pieces};
                            if (origin != null) _pieces.remove(origin);
                            _pieces[dest] = piece;
                          }),
                          onDiscardedPiece: (sq) => setState(() => _pieces = {..._pieces}..remove(sq)),
                        ),
                      ),
                    ),
                  );
                },
              ),
              _palette(_orientation),
              // The problem is shown right under the board, where the user looks.
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    child: InfoStrip(icon: AppIcons.error, text: error, tone: Tone.error),
                  ),
                ),
              // Whose move it is: the one thing every set-up needs, so it is
              // first under the board (it used to sit below the fold).
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
                child: ChoiceSegments<Side>(
                  options: [ChoiceOption(Side.white, l.whiteToMove), ChoiceOption(Side.black, l.blackToMove)],
                  selected: _turn,
                  onChanged: (v) => setState(() => _turn = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionChip(label: Text(l.editSquare), onPressed: _editAccessibleSquare),
                    FilterChip(
                      avatar: const Icon(AppIcons.clearBoard, size: AppSizes.iconMd),
                      label: Text(l.eraser),
                      selected: _eraser,
                      onSelected: (v) => setState(() {
                        _eraser = v;
                        if (v) _brush = null;
                      }),
                    ),
                    ActionChip(
                      avatar: const Icon(AppIcons.movePieces, size: AppSizes.iconMd),
                      label: Text(l.dragMode),
                      onPressed: () => setState(() {
                        _brush = null;
                        _eraser = false;
                      }),
                    ),
                    ActionChip(label: Text(l.startPosition), onPressed: () => setState(() => _load(kInitialFen))),
                    ActionChip(
                      label: Text(l.clearBoard),
                      onPressed: () => setState(() => _load('8/8/8/8/8/8/8/8 w - - 0 1')),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: AppInsets.pageH,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.castling, style: context.tt.title),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final (c, label, kind) in [
                          ('K', l.castleWhiteShort, PieceKind.whiteKing),
                          ('Q', l.castleWhiteLong, PieceKind.whiteKing),
                          ('k', l.castleBlackShort, PieceKind.blackKing),
                          ('q', l.castleBlackLong, PieceKind.blackKing),
                        ])
                          FilterChip(
                            avatar: PieceIcon(kind, size: AppSizes.iconMd),
                            label: Text(label),
                            selected: _castling.contains(c) && _castlingPossible(c),
                            onSelected: _castlingPossible(c)
                                ? (v) => setState(() => v ? _castling.add(c) : _castling.remove(c))
                                : null,
                          ),
                      ],
                    ),
                    if (eps.isNotEmpty) ...[
                      AppGap.v12,
                      DropdownButtonFormField<String?>(
                        icon: const Icon(AppIcons.expand, size: AppSizes.iconMd),
                        initialValue: _ep,
                        decoration: InputDecoration(labelText: l.enPassant),
                        items: [
                          DropdownMenuItem(value: null, child: Text(l.none)),
                          for (final e in eps) DropdownMenuItem(value: e, child: Text(e)),
                        ],
                        onChanged: (v) => setState(() => _ep = v),
                      ),
                    ],
                    AppGap.v12,
                    SelectableText(_fen, style: context.tt.mono),
                    AppGap.v16,
                    if (!widget.pickMode) ...[
                      FilledButton.icon(
                        style: AppButtonSize.large,
                        onPressed: error == null
                            ? () => context.push('/analysis', extra: GameScreenArgs(fen: positionFromFen(_fen).fen))
                            : null,
                        icon: const Icon(AppIcons.analysis),
                        label: Text(l.analyzePosition),
                      ),
                      AppGap.v8,
                      OutlinedButton.icon(
                        style: AppButtonSize.wide,
                        onPressed: error == null
                            ? () => showCreateRepertoire(context, fen: positionFromFen(_fen).fen, color: _turn)
                            : null,
                        icon: const Icon(AppIcons.repertoire),
                        label: Text(l.createRepertoireFromHere),
                      ),
                    ] else
                      FilledButton(
                        style: AppButtonSize.large,
                        onPressed: error == null ? () => context.pop(positionFromFen(_fen).fen) : null,
                        child: Text(l.done),
                      ),
                    AppGap.v24,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
