import 'dart:math' as math;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings/app_settings.dart';
import '../../domain/pgn/pgn_model.dart';
import '../app/providers.dart';
import '../theme/app_theme.dart';

/// Board themes and piece sets offered to the user. Only solid-color boards
/// and piece sets with GPL-compatible licenses (see NOTICE, 9.4).
class BoardAppearance {
  static const boardThemes = ['brown', 'blue', 'green', 'ic', 'grey', 'purple', 'tabiya'];
  static const pieceSets = <PieceSet>[
    PieceSet.cburnett,
    PieceSet.merida,
    PieceSet.mpchess,
    PieceSet.chessnut,
    PieceSet.fantasy,
    PieceSet.spatial,
    PieceSet.celtic,
    PieceSet.rhosgfx,
    PieceSet.firi,
    PieceSet.shapes,
  ];

  static ChessboardColorScheme _solid(Color light, Color dark) => ChessboardColorScheme.brown.copyWith(
    lightSquare: light,
    darkSquare: dark,
    background: SolidColorChessboardBackground(lightSquare: light, darkSquare: dark),
    whiteCoordBackground: SolidColorChessboardBackground(lightSquare: light, darkSquare: dark, coordinates: true),
    blackCoordBackground: SolidColorChessboardBackground(
      lightSquare: light,
      darkSquare: dark,
      coordinates: true,
      orientation: Side.black,
    ),
  );

  static ChessboardColorScheme scheme(String name) => switch (name) {
    'blue' => ChessboardColorScheme.blue,
    'green' => ChessboardColorScheme.green,
    'ic' => ChessboardColorScheme.ic,
    'grey' => _solid(BoardColors.greyBoard.$1, BoardColors.greyBoard.$2),
    'purple' => _solid(BoardColors.purpleBoard.$1, BoardColors.purpleBoard.$2),
    'tabiya' => _solid(BoardColors.stoneBoard.$1, BoardColors.stoneBoard.$2),
    _ => ChessboardColorScheme.brown,
  };

  static PieceSet pieceSet(String name) => pieceSets.firstWhere((p) => p.name == name, orElse: () => PieceSet.cburnett);

  static PieceShiftMethod shiftMethod(String name) => switch (name) {
    'drag' => PieceShiftMethod.drag,
    'tapTwoSquares' => PieceShiftMethod.tapTwoSquares,
    _ => PieceShiftMethod.either,
  };

  static ChessboardSettings settings(AppSettings s, {bool drawing = false, Color? drawColor}) => ChessboardSettings(
    colorScheme: scheme(s.boardTheme),
    pieceAssets: pieceSet(s.pieceSet).assets,
    enableCoordinates: s.showCoordinates,
    animationDuration: Duration(milliseconds: s.animationMs),
    showValidMoves: s.showLegalMoves,
    enablePremoves: false,
    pieceShiftMethod: shiftMethod(s.moveMethod),
    borderRadius: AppRadius.xsAll,
    boxShadow: BoardColors.boardShadow,
    drawShape: DrawShapeOptions(enable: drawing, newShapeColor: drawColor ?? shapeColor(ShapeColor.green)),
  );

  static Color shapeColor(ShapeColor c) => switch (c) {
    ShapeColor.green => BoardColors.green,
    ShapeColor.red => BoardColors.red,
    ShapeColor.blue => BoardColors.blue,
    ShapeColor.yellow => BoardColors.yellow,
  };

  static ShapeColor? shapeColorOf(Color c) {
    for (final sc in ShapeColor.values) {
      if (shapeColor(sc).toARGB32() == c.toARGB32()) return sc;
    }
    return null;
  }

  static Shape toShape(BoardShape s) => s.isArrow
      ? Arrow(color: shapeColor(s.color), orig: s.orig, dest: s.dest!)
      : Circle(color: shapeColor(s.color), orig: s.orig);

  static BoardShape? fromShape(Shape s) => switch (s) {
    Arrow(:final color, :final orig, :final dest) => BoardShape(shapeColorOf(color) ?? ShapeColor.green, orig, dest),
    Circle(:final color, :final orig) => BoardShape(shapeColorOf(color) ?? ShapeColor.green, orig),
    _ => null,
  };
}

/// Chessboard bound to a dartchess [Position] (wraps chessground 10).
class BoardView extends ConsumerStatefulWidget {
  const BoardView({
    super.key,
    required this.position,
    this.orientation = Side.white,
    this.lastMove,
    this.playerSide = PlayerSide.none,
    this.onMove,
    this.shapes = const {},
    this.annotations = const {},
    this.animate = true,
    this.maxSize,
    this.onTouchedSquare,
    this.semanticsLabel,
  });

  final Position position;
  final Side orientation;
  final Move? lastMove;
  final PlayerSide playerSide;
  final void Function(Move move)? onMove;
  final Set<Shape> shapes;
  final Map<Square, Annotation> annotations;
  final bool animate;
  final double? maxSize;

  final void Function(Square square)? onTouchedSquare;
  final String? semanticsLabel;

  @override
  ConsumerState<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<BoardView> {
  late ChessboardController _controller;

  GameData _data() {
    final pos = widget.position;
    final interactive = widget.playerSide != PlayerSide.none;
    return GameData(
      fen: pos.fen,
      playerSide: widget.playerSide,
      sideToMove: pos.turn,
      validMoves: interactive ? makeLegalMoves(pos) : const {},
      lastMove: widget.lastMove,
      kingSquareInCheck: pos.isCheck ? pos.board.kingOf(pos.turn) : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = ChessboardController(game: _data());
  }

  @override
  void didUpdateWidget(BoardView old) {
    super.didUpdateWidget(old);
    final changed =
        old.position.fen != widget.position.fen ||
        old.lastMove != widget.lastMove ||
        old.playerSide != widget.playerSide ||
        _controller.fen != widget.position.fen;
    if (changed) {
      _controller.updatePosition(_data(), animate: widget.animate, resetPremove: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return LayoutBuilder(
      builder: (context, c) {
        var size = math.min(c.maxWidth, c.maxHeight.isFinite ? c.maxHeight : c.maxWidth);
        if (widget.maxSize != null) size = math.min(size, widget.maxSize!);
        return Semantics(
          label: widget.semanticsLabel,
          container: true,
          // Coordinates are drawn inside the squares: they must not grow
          // with the system text size (T-21).
          child: SizedBox.square(
            dimension: size,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: kBoardTextScaleMax,
              child: Chessboard(
                size: size,
                controller: _controller,
                orientation: widget.orientation,
                settings: BoardAppearance.settings(settings),
                shapes: widget.shapes,
                annotations: widget.annotations,
                onTouchedSquare: widget.onTouchedSquare,
                onMove: widget.onMove == null ? null : (move, {viaDragAndDrop}) => widget.onMove!(move),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Non-interactive thumbnail board.
class MiniBoard extends ConsumerWidget {
  const MiniBoard({
    super.key,
    required this.fen,
    this.orientation = Side.white,
    this.size = 120,
    this.lastMove,
    this.shapes = const {},
  });

  final String fen;
  final Side orientation;
  final double size;
  final Move? lastMove;
  final Set<Shape> shapes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: kBoardTextScaleMax,
      child: StaticChessboard(
        size: size,
        orientation: orientation,
        fen: fen,
        lastMove: lastMove,
        shapes: shapes,
        settings: StaticChessboardSettings(
          colorScheme: BoardAppearance.scheme(s.boardTheme),
          pieceAssets: BoardAppearance.pieceSet(s.pieceSet).assets,
          borderRadius: AppRadius.xsAll,
        ),
      ),
    );
  }
}
