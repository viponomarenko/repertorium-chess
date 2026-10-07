import 'package:dartchess/dartchess.dart';

/// Standard initial position FEN.
const kInitialFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Normalized position key (see ТЗ 3.1): piece placement, side to move,
/// castling rights and en-passant square (only when an en-passant capture
/// is actually legal). Half-move clock and move number are excluded, so
/// transpositions map to the same key.
typedef PositionKey = String;

PositionKey positionKeyOf(Position pos) => keyFromFen(pos.fen);

/// Takes the first four FEN fields. Assumes the FEN comes from
/// [Position.fen], which already only includes a legal en-passant square.
PositionKey keyFromFen(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  return parts.take(4).join(' ');
}

/// Normalizes an arbitrary (user supplied) FEN into a key, dropping an
/// en-passant square when no legal capture exists.
PositionKey normalizeFenToKey(String fen) {
  final pos = positionFromFen(fen);
  return positionKeyOf(pos);
}

final kInitialKey = keyFromFen(kInitialFen);

Position positionFromFen(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  // Accept EPD-like 4-field input by appending counters.
  final full = parts.length == 4 ? '${parts.join(' ')} 0 1' : fen.trim();
  return Chess.fromSetup(Setup.parseFen(full));
}

Position? tryPositionFromFen(String fen) {
  try {
    return positionFromFen(fen);
  } catch (_) {
    return null;
  }
}

Side sideToMoveOfKey(PositionKey key) {
  final parts = key.split(' ');
  return parts.length > 1 && parts[1] == 'b' ? Side.black : Side.white;
}

/// Whether [move] is a castling move in [pos] (either king-two-squares or
/// king-takes-rook notation).
bool isCastling(Position pos, Move move) {
  if (move is! NormalMove) return false;
  final piece = pos.board.pieceAt(move.from);
  if (piece == null || piece.role != Role.king) return false;
  final target = pos.board.pieceAt(move.to);
  if (target != null && target.color == piece.color && target.role == Role.rook) {
    return true;
  }
  return (move.from.file - move.to.file).abs() >= 2;
}

/// Converts a move to the dartchess internal representation (castling as
/// king-takes-rook), which is what [Position.play] expects.
Move normalizeMove(Position pos, Move move) {
  if (move is NormalMove) return pos.normalizeMove(move);
  return move;
}

/// UCI in the conventional form (castling as king two squares: e1g1).
String standardUci(Position pos, Move move) {
  if (move is NormalMove && isCastling(pos, move)) {
    final kingFrom = move.from;
    final toFile = move.to.file > kingFrom.file ? File.g : File.c;
    return kingFrom.name + Square.fromCoords(toFile, kingFrom.rank).name;
  }
  return move.uci;
}

/// Parses a UCI string (either castling notation) into a legal move for
/// [pos], normalized for [Position.play]. Returns null if illegal.
Move? parseUciMove(Position pos, String uci) {
  if (uci.length < 4) return null;
  final m = Move.parse(uci);
  if (m == null) return null;
  final norm = normalizeMove(pos, m);
  return pos.isLegal(norm) ? norm : null;
}

/// Plays [move] and returns the SAN and the new position.
(Position, String) playWithSan(Position pos, Move move) => pos.makeSan(move);

/// Parses SAN leniently: handles `0-0`, trailing annotations, `e2e4` UCI.
Move? parseSanLenient(Position pos, String token) {
  var san = token.trim();
  if (san.isEmpty) return null;
  san = san.replaceAll('0-0-0', 'O-O-O').replaceAll('0-0', 'O-O');
  san = san.replaceAll(RegExp(r'[!?]+$'), '');
  final m = pos.parseSan(san);
  if (m != null) return m;
  // Some files use lowercase promotion or missing '='.
  final promo = RegExp(r'^([a-h](?:x[a-h])?[18])=?([qrbnQRBN])([+#]?)$').firstMatch(san);
  if (promo != null) {
    final alt = '${promo.group(1)}=${promo.group(2)!.toUpperCase()}';
    final m2 = pos.parseSan(alt);
    if (m2 != null) return m2;
  }
  // Long algebraic / UCI fallback: e2e4, e2-e4, Ng1-f3.
  final lan = RegExp(r'^[KQRBN]?([a-h][1-8])[-x]?([a-h][1-8])=?([qrbnQRBN])?').firstMatch(san);
  if (lan != null) {
    final uci = '${lan.group(1)}${lan.group(2)}${(lan.group(3) ?? '').toLowerCase()}';
    return parseUciMove(pos, uci);
  }
  return null;
}

/// Parses a move typed by the user: English SAN, Ukrainian letters
/// (Кр Ф Т С К), castling with zeros or letters o, UCI.
Move? parseTypedMove(Position pos, String text) {
  var t = text.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (RegExp(r'^[oO0](-[oO0]){1,2}[+#]?$').hasMatch(t)) t = t.replaceAll(RegExp('[o0]'), 'O');
  t = t
      .replaceAll('Кр', 'K')
      .replaceAll('кр', 'K')
      .replaceAll('Ф', 'Q')
      .replaceAll('Т', 'R')
      .replaceAll('С', 'B')
      .replaceAll('К', 'N')
      .replaceAll('х', 'x')
      // Cyrillic look-alikes of the file letters (typed on a Ukrainian
      // keyboard or pasted): а, с, е are meant as a, c, e.
      .replaceAll('а', 'a')
      .replaceAll('с', 'c')
      .replaceAll('е', 'e');
  final direct = parseSanLenient(pos, t);
  if (direct != null) return direct;
  // Lowercase piece letters (nf3, bb5) are common when typing on a phone.
  if (RegExp('^[kqrn]').hasMatch(t)) return parseSanLenient(pos, t[0].toUpperCase() + t.substring(1));
  if (t.startsWith('b') && t.length >= 3 && !RegExp(r'^b[1-8]$|^bx|^b[1-8]=').hasMatch(t)) {
    return parseSanLenient(pos, 'B${t.substring(1)}');
  }
  return null;
}

/// Plays a null move (`--`): passes the turn. Not a legal chess move, but
/// PGN files may contain it (F-IMP-04).
Position playNullMove(Position pos) => pos.copyWith(
  turn: pos.turn.opposite,
  epSquare: null,
  halfmoves: pos.halfmoves + 1,
  fullmoves: pos.turn == Side.black ? pos.fullmoves + 1 : pos.fullmoves,
);

/// Name of the piece role for announcements.
String roleLetter(Role role) => role.uppercaseLetter;
