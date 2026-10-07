import 'package:drift/drift.dart';

/// Folder / database of games (ТЗ 3.2 Collection).
@DataClassName('CollectionRow')
class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// file | lichess | chesscom | manual | starter
  TextColumn get source => text().withDefault(const Constant('manual'))();

  /// Original reference (file name, study id, URL).
  TextColumn get sourceRef => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// A game / study chapter. The move tree is stored losslessly as PGN text
/// (see docs/DECISIONS.md, D-004); headers are denormalized for search.
@DataClassName('GameRow')
class Games extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get collectionId => integer().references(Collections, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIdx => integer().withDefault(const Constant(0))();
  TextColumn get pgn => text()();

  /// JSON object of all headers, in original order.
  TextColumn get headersJson => text().withDefault(const Constant('{}'))();
  TextColumn get white => text().withDefault(const Constant(''))();
  TextColumn get black => text().withDefault(const Constant(''))();
  TextColumn get event => text().withDefault(const Constant(''))();
  TextColumn get date => text().withDefault(const Constant(''))();
  TextColumn get result => text().withDefault(const Constant('*'))();
  TextColumn get eco => text().withDefault(const Constant(''))();
  TextColumn get opening => text().withDefault(const Constant(''))();
  TextColumn get rootFen => text().nullable()();
  IntColumn get plyCount => integer().withDefault(const Constant(0))();

  /// Problems found while parsing (JSON list), empty if none.
  TextColumn get issuesJson => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('RepertoireRow')
class Repertoires extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// white | black
  TextColumn get color => text()();
  TextColumn get rootKey => text()();
  TextColumn get rootFen => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// JSON with per-repertoire training options (opponent strategy etc).
  TextColumn get optionsJson => text().withDefault(const Constant('{}'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('RepPositionRow')
class RepPositions extends Table {
  IntColumn get repertoireId => integer().references(Repertoires, #id, onDelete: KeyAction.cascade)();
  TextColumn get positionKey => text()();
  TextColumn get fen => text()();
  TextColumn get comment => text().withDefault(const Constant(''))();

  /// Encoded shapes ("Ge2e4,Rd4"), shown when the position is on the board.
  TextColumn get shapes => text().withDefault(const Constant(''))();

  /// Deferred conflict: training of this position is disabled (F-REP-06).
  BoolColumn get conflictDeferred => boolean().withDefault(const Constant(false))();

  /// Engine review flag (F-ENG-04): JSON or empty.
  TextColumn get engineFlag => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {repertoireId, positionKey};
}

@DataClassName('RepMoveRow')
class RepMoves extends Table {
  IntColumn get repertoireId => integer().references(Repertoires, #id, onDelete: KeyAction.cascade)();
  TextColumn get fromKey => text()();
  TextColumn get uci => text()();
  TextColumn get toKey => text()();
  TextColumn get san => text()();

  /// main | alternative for the user's moves; empty for opponent moves.
  TextColumn get role => text().withDefault(const Constant(''))();

  /// 0..100, frequency weight for opponent moves.
  IntColumn get weight => integer().withDefault(const Constant(50))();
  TextColumn get comment => text().withDefault(const Constant(''))();

  /// manual | pgn | lichess-study | explorer | engine | starter
  TextColumn get source => text().withDefault(const Constant('manual'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {repertoireId, fromKey, uci};
}

@DataClassName('CardRow')
class Cards extends Table {
  IntColumn get repertoireId => integer().references(Repertoires, #id, onDelete: KeyAction.cascade)();
  TextColumn get positionKey => text()();
  RealColumn get stability => real().withDefault(const Constant(0))();
  RealColumn get difficulty => real().withDefault(const Constant(0))();
  DateTimeColumn get due => dateTime().nullable()();
  DateTimeColumn get lastReview => dateTime().nullable()();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();

  /// newCard | learning | review | relearning
  TextColumn get state => text().withDefault(const Constant('newCard'))();
  BoolColumn get suspended => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {repertoireId, positionKey};
}

@DataClassName('ReviewLogRow')
class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get repertoireId => integer().references(Repertoires, #id, onDelete: KeyAction.cascade)();
  TextColumn get positionKey => text()();
  DateTimeColumn get timestamp => dateTime()();

  /// again | hard | good | easy
  TextColumn get grade => text()();
  TextColumn get playedUci => text().withDefault(const Constant(''))();
  TextColumn get expectedUci => text().withDefault(const Constant(''))();

  /// learn | review | drill | light
  TextColumn get mode => text()();
  IntColumn get responseMs => integer().withDefault(const Constant(0))();

  /// Whether the review changed the schedule.
  BoolColumn get scheduled => boolean().withDefault(const Constant(true))();
}

@DataClassName('LinkedAccountRow')
class LinkedAccounts extends Table {
  /// lichess | chesscom
  TextColumn get provider => text()();
  TextColumn get username => text()();

  /// Key in secure storage (Lichess only). Never the token itself.
  TextColumn get tokenRef => text().nullable()();
  TextColumn get scopes => text().withDefault(const Constant(''))();
  DateTimeColumn get connectedAt => dateTime()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {provider};
}

@DataClassName('ImportedGameRow')
class ImportedGames extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text()();
  TextColumn get externalId => text()();
  TextColumn get pgn => text()();
  DateTimeColumn get playedAt => dateTime()();

  /// white | black
  TextColumn get userColor => text()();
  TextColumn get timeControl => text().withDefault(const Constant(''))();

  /// bullet | blitz | rapid | classical | daily | correspondence
  TextColumn get speed => text().withDefault(const Constant(''))();
  TextColumn get result => text().withDefault(const Constant('*'))();
  TextColumn get opponent => text().withDefault(const Constant(''))();
  TextColumn get url => text().withDefault(const Constant(''))();
  BoolColumn get rated => boolean().withDefault(const Constant(true))();
  DateTimeColumn get analyzedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {provider, externalId},
  ];
}

/// Result of the game-vs-repertoire analysis (F-GAP). Recomputable.
@DataClassName('GapEventRow')
class GapEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get importedGameId => integer().references(ImportedGames, #id, onDelete: KeyAction.cascade)();
  IntColumn get repertoireId => integer().references(Repertoires, #id, onDelete: KeyAction.cascade)();

  /// userDeviation | opponentNovelty | endOfBook
  TextColumn get type => text()();
  TextColumn get positionKey => text()();
  TextColumn get fen => text()();
  IntColumn get ply => integer()();
  TextColumn get playedSan => text().withDefault(const Constant(''))();
  TextColumn get playedUci => text().withDefault(const Constant(''))();
  TextColumn get expectedSan => text().withDefault(const Constant(''))();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
}

/// Cache of Opening Explorer responses (F-LI-09), TTL 30 days.
@DataClassName('ExplorerCacheRow')
class ExplorerCache extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get json => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

/// Conditional-request metadata (ETag / Last-Modified), e.g. Chess.com.
@DataClassName('HttpCacheRow')
class HttpCache extends Table {
  TextColumn get url => text()();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {url};
}

/// Key-value settings (JSON values). Included in backups.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
