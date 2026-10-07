// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CollectionsTable extends Collections with TableInfo<$CollectionsTable, CollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _sourceRefMeta = const VerificationMeta('sourceRef');
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
    'source_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, source, sourceRef, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collections';
  @override
  VerificationContext validateIntegrity(Insertable<CollectionRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta, source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('source_ref')) {
      context.handle(_sourceRefMeta, sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      source: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      sourceRef: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source_ref']),
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CollectionsTable createAlias(String alias) {
    return $CollectionsTable(attachedDatabase, alias);
  }
}

class CollectionRow extends DataClass implements Insertable<CollectionRow> {
  final int id;
  final String name;

  /// file | lichess | chesscom | manual | starter
  final String source;

  /// Original reference (file name, study id, URL).
  final String? sourceRef;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CollectionRow({
    required this.id,
    required this.name,
    required this.source,
    this.sourceRef,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      source: Value(source),
      sourceRef: sourceRef == null && nullToAbsent ? const Value.absent() : Value(sourceRef),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CollectionRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      source: serializer.fromJson<String>(json['source']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'source': serializer.toJson<String>(source),
      'sourceRef': serializer.toJson<String?>(sourceRef),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CollectionRow copyWith({
    int? id,
    String? name,
    String? source,
    Value<String?> sourceRef = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CollectionRow(
    id: id ?? this.id,
    name: name ?? this.name,
    source: source ?? this.source,
    sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CollectionRow copyWithCompanion(CollectionsCompanion data) {
    return CollectionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      source: data.source.present ? data.source.value : this.source,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, source, sourceRef, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.source == this.source &&
          other.sourceRef == this.sourceRef &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CollectionsCompanion extends UpdateCompanion<CollectionRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> source;
  final Value<String?> sourceRef;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CollectionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.source = const Value.absent(),
    this.sourceRef = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CollectionRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? source,
    Expression<String>? sourceRef,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (source != null) 'source': source,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CollectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? source,
    Value<String?>? sourceRef,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $GamesTable extends Games with TableInfo<$GamesTable, GameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta('collectionId');
  @override
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES collections (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _orderIdxMeta = const VerificationMeta('orderIdx');
  @override
  late final GeneratedColumn<int> orderIdx = GeneratedColumn<int>(
    'order_idx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pgnMeta = const VerificationMeta('pgn');
  @override
  late final GeneratedColumn<String> pgn = GeneratedColumn<String>(
    'pgn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headersJsonMeta = const VerificationMeta('headersJson');
  @override
  late final GeneratedColumn<String> headersJson = GeneratedColumn<String>(
    'headers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _whiteMeta = const VerificationMeta('white');
  @override
  late final GeneratedColumn<String> white = GeneratedColumn<String>(
    'white',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _blackMeta = const VerificationMeta('black');
  @override
  late final GeneratedColumn<String> black = GeneratedColumn<String>(
    'black',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _eventMeta = const VerificationMeta('event');
  @override
  late final GeneratedColumn<String> event = GeneratedColumn<String>(
    'event',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('*'),
  );
  static const VerificationMeta _ecoMeta = const VerificationMeta('eco');
  @override
  late final GeneratedColumn<String> eco = GeneratedColumn<String>(
    'eco',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _openingMeta = const VerificationMeta('opening');
  @override
  late final GeneratedColumn<String> opening = GeneratedColumn<String>(
    'opening',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _rootFenMeta = const VerificationMeta('rootFen');
  @override
  late final GeneratedColumn<String> rootFen = GeneratedColumn<String>(
    'root_fen',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plyCountMeta = const VerificationMeta('plyCount');
  @override
  late final GeneratedColumn<int> plyCount = GeneratedColumn<int>(
    'ply_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _issuesJsonMeta = const VerificationMeta('issuesJson');
  @override
  late final GeneratedColumn<String> issuesJson = GeneratedColumn<String>(
    'issues_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collectionId,
    orderIdx,
    pgn,
    headersJson,
    white,
    black,
    event,
    date,
    result,
    eco,
    opening,
    rootFen,
    plyCount,
    issuesJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'games';
  @override
  VerificationContext validateIntegrity(Insertable<GameRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('collection_id')) {
      context.handle(_collectionIdMeta, collectionId.isAcceptableOrUnknown(data['collection_id']!, _collectionIdMeta));
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('order_idx')) {
      context.handle(_orderIdxMeta, orderIdx.isAcceptableOrUnknown(data['order_idx']!, _orderIdxMeta));
    }
    if (data.containsKey('pgn')) {
      context.handle(_pgnMeta, pgn.isAcceptableOrUnknown(data['pgn']!, _pgnMeta));
    } else if (isInserting) {
      context.missing(_pgnMeta);
    }
    if (data.containsKey('headers_json')) {
      context.handle(_headersJsonMeta, headersJson.isAcceptableOrUnknown(data['headers_json']!, _headersJsonMeta));
    }
    if (data.containsKey('white')) {
      context.handle(_whiteMeta, white.isAcceptableOrUnknown(data['white']!, _whiteMeta));
    }
    if (data.containsKey('black')) {
      context.handle(_blackMeta, black.isAcceptableOrUnknown(data['black']!, _blackMeta));
    }
    if (data.containsKey('event')) {
      context.handle(_eventMeta, event.isAcceptableOrUnknown(data['event']!, _eventMeta));
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    }
    if (data.containsKey('result')) {
      context.handle(_resultMeta, result.isAcceptableOrUnknown(data['result']!, _resultMeta));
    }
    if (data.containsKey('eco')) {
      context.handle(_ecoMeta, eco.isAcceptableOrUnknown(data['eco']!, _ecoMeta));
    }
    if (data.containsKey('opening')) {
      context.handle(_openingMeta, opening.isAcceptableOrUnknown(data['opening']!, _openingMeta));
    }
    if (data.containsKey('root_fen')) {
      context.handle(_rootFenMeta, rootFen.isAcceptableOrUnknown(data['root_fen']!, _rootFenMeta));
    }
    if (data.containsKey('ply_count')) {
      context.handle(_plyCountMeta, plyCount.isAcceptableOrUnknown(data['ply_count']!, _plyCountMeta));
    }
    if (data.containsKey('issues_json')) {
      context.handle(_issuesJsonMeta, issuesJson.isAcceptableOrUnknown(data['issues_json']!, _issuesJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      collectionId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}collection_id'])!,
      orderIdx: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}order_idx'])!,
      pgn: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}pgn'])!,
      headersJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}headers_json'])!,
      white: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}white'])!,
      black: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}black'])!,
      event: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}event'])!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      result: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}result'])!,
      eco: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}eco'])!,
      opening: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}opening'])!,
      rootFen: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}root_fen']),
      plyCount: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}ply_count'])!,
      issuesJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}issues_json'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $GamesTable createAlias(String alias) {
    return $GamesTable(attachedDatabase, alias);
  }
}

class GameRow extends DataClass implements Insertable<GameRow> {
  final int id;
  final int collectionId;
  final int orderIdx;
  final String pgn;

  /// JSON object of all headers, in original order.
  final String headersJson;
  final String white;
  final String black;
  final String event;
  final String date;
  final String result;
  final String eco;
  final String opening;
  final String? rootFen;
  final int plyCount;

  /// Problems found while parsing (JSON list), empty if none.
  final String issuesJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const GameRow({
    required this.id,
    required this.collectionId,
    required this.orderIdx,
    required this.pgn,
    required this.headersJson,
    required this.white,
    required this.black,
    required this.event,
    required this.date,
    required this.result,
    required this.eco,
    required this.opening,
    this.rootFen,
    required this.plyCount,
    required this.issuesJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['collection_id'] = Variable<int>(collectionId);
    map['order_idx'] = Variable<int>(orderIdx);
    map['pgn'] = Variable<String>(pgn);
    map['headers_json'] = Variable<String>(headersJson);
    map['white'] = Variable<String>(white);
    map['black'] = Variable<String>(black);
    map['event'] = Variable<String>(event);
    map['date'] = Variable<String>(date);
    map['result'] = Variable<String>(result);
    map['eco'] = Variable<String>(eco);
    map['opening'] = Variable<String>(opening);
    if (!nullToAbsent || rootFen != null) {
      map['root_fen'] = Variable<String>(rootFen);
    }
    map['ply_count'] = Variable<int>(plyCount);
    map['issues_json'] = Variable<String>(issuesJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GamesCompanion toCompanion(bool nullToAbsent) {
    return GamesCompanion(
      id: Value(id),
      collectionId: Value(collectionId),
      orderIdx: Value(orderIdx),
      pgn: Value(pgn),
      headersJson: Value(headersJson),
      white: Value(white),
      black: Value(black),
      event: Value(event),
      date: Value(date),
      result: Value(result),
      eco: Value(eco),
      opening: Value(opening),
      rootFen: rootFen == null && nullToAbsent ? const Value.absent() : Value(rootFen),
      plyCount: Value(plyCount),
      issuesJson: Value(issuesJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GameRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameRow(
      id: serializer.fromJson<int>(json['id']),
      collectionId: serializer.fromJson<int>(json['collectionId']),
      orderIdx: serializer.fromJson<int>(json['orderIdx']),
      pgn: serializer.fromJson<String>(json['pgn']),
      headersJson: serializer.fromJson<String>(json['headersJson']),
      white: serializer.fromJson<String>(json['white']),
      black: serializer.fromJson<String>(json['black']),
      event: serializer.fromJson<String>(json['event']),
      date: serializer.fromJson<String>(json['date']),
      result: serializer.fromJson<String>(json['result']),
      eco: serializer.fromJson<String>(json['eco']),
      opening: serializer.fromJson<String>(json['opening']),
      rootFen: serializer.fromJson<String?>(json['rootFen']),
      plyCount: serializer.fromJson<int>(json['plyCount']),
      issuesJson: serializer.fromJson<String>(json['issuesJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'collectionId': serializer.toJson<int>(collectionId),
      'orderIdx': serializer.toJson<int>(orderIdx),
      'pgn': serializer.toJson<String>(pgn),
      'headersJson': serializer.toJson<String>(headersJson),
      'white': serializer.toJson<String>(white),
      'black': serializer.toJson<String>(black),
      'event': serializer.toJson<String>(event),
      'date': serializer.toJson<String>(date),
      'result': serializer.toJson<String>(result),
      'eco': serializer.toJson<String>(eco),
      'opening': serializer.toJson<String>(opening),
      'rootFen': serializer.toJson<String?>(rootFen),
      'plyCount': serializer.toJson<int>(plyCount),
      'issuesJson': serializer.toJson<String>(issuesJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GameRow copyWith({
    int? id,
    int? collectionId,
    int? orderIdx,
    String? pgn,
    String? headersJson,
    String? white,
    String? black,
    String? event,
    String? date,
    String? result,
    String? eco,
    String? opening,
    Value<String?> rootFen = const Value.absent(),
    int? plyCount,
    String? issuesJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GameRow(
    id: id ?? this.id,
    collectionId: collectionId ?? this.collectionId,
    orderIdx: orderIdx ?? this.orderIdx,
    pgn: pgn ?? this.pgn,
    headersJson: headersJson ?? this.headersJson,
    white: white ?? this.white,
    black: black ?? this.black,
    event: event ?? this.event,
    date: date ?? this.date,
    result: result ?? this.result,
    eco: eco ?? this.eco,
    opening: opening ?? this.opening,
    rootFen: rootFen.present ? rootFen.value : this.rootFen,
    plyCount: plyCount ?? this.plyCount,
    issuesJson: issuesJson ?? this.issuesJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GameRow copyWithCompanion(GamesCompanion data) {
    return GameRow(
      id: data.id.present ? data.id.value : this.id,
      collectionId: data.collectionId.present ? data.collectionId.value : this.collectionId,
      orderIdx: data.orderIdx.present ? data.orderIdx.value : this.orderIdx,
      pgn: data.pgn.present ? data.pgn.value : this.pgn,
      headersJson: data.headersJson.present ? data.headersJson.value : this.headersJson,
      white: data.white.present ? data.white.value : this.white,
      black: data.black.present ? data.black.value : this.black,
      event: data.event.present ? data.event.value : this.event,
      date: data.date.present ? data.date.value : this.date,
      result: data.result.present ? data.result.value : this.result,
      eco: data.eco.present ? data.eco.value : this.eco,
      opening: data.opening.present ? data.opening.value : this.opening,
      rootFen: data.rootFen.present ? data.rootFen.value : this.rootFen,
      plyCount: data.plyCount.present ? data.plyCount.value : this.plyCount,
      issuesJson: data.issuesJson.present ? data.issuesJson.value : this.issuesJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameRow(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('orderIdx: $orderIdx, ')
          ..write('pgn: $pgn, ')
          ..write('headersJson: $headersJson, ')
          ..write('white: $white, ')
          ..write('black: $black, ')
          ..write('event: $event, ')
          ..write('date: $date, ')
          ..write('result: $result, ')
          ..write('eco: $eco, ')
          ..write('opening: $opening, ')
          ..write('rootFen: $rootFen, ')
          ..write('plyCount: $plyCount, ')
          ..write('issuesJson: $issuesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    collectionId,
    orderIdx,
    pgn,
    headersJson,
    white,
    black,
    event,
    date,
    result,
    eco,
    opening,
    rootFen,
    plyCount,
    issuesJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameRow &&
          other.id == this.id &&
          other.collectionId == this.collectionId &&
          other.orderIdx == this.orderIdx &&
          other.pgn == this.pgn &&
          other.headersJson == this.headersJson &&
          other.white == this.white &&
          other.black == this.black &&
          other.event == this.event &&
          other.date == this.date &&
          other.result == this.result &&
          other.eco == this.eco &&
          other.opening == this.opening &&
          other.rootFen == this.rootFen &&
          other.plyCount == this.plyCount &&
          other.issuesJson == this.issuesJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GamesCompanion extends UpdateCompanion<GameRow> {
  final Value<int> id;
  final Value<int> collectionId;
  final Value<int> orderIdx;
  final Value<String> pgn;
  final Value<String> headersJson;
  final Value<String> white;
  final Value<String> black;
  final Value<String> event;
  final Value<String> date;
  final Value<String> result;
  final Value<String> eco;
  final Value<String> opening;
  final Value<String?> rootFen;
  final Value<int> plyCount;
  final Value<String> issuesJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const GamesCompanion({
    this.id = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.orderIdx = const Value.absent(),
    this.pgn = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.white = const Value.absent(),
    this.black = const Value.absent(),
    this.event = const Value.absent(),
    this.date = const Value.absent(),
    this.result = const Value.absent(),
    this.eco = const Value.absent(),
    this.opening = const Value.absent(),
    this.rootFen = const Value.absent(),
    this.plyCount = const Value.absent(),
    this.issuesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GamesCompanion.insert({
    this.id = const Value.absent(),
    required int collectionId,
    this.orderIdx = const Value.absent(),
    required String pgn,
    this.headersJson = const Value.absent(),
    this.white = const Value.absent(),
    this.black = const Value.absent(),
    this.event = const Value.absent(),
    this.date = const Value.absent(),
    this.result = const Value.absent(),
    this.eco = const Value.absent(),
    this.opening = const Value.absent(),
    this.rootFen = const Value.absent(),
    this.plyCount = const Value.absent(),
    this.issuesJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : collectionId = Value(collectionId),
       pgn = Value(pgn),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GameRow> custom({
    Expression<int>? id,
    Expression<int>? collectionId,
    Expression<int>? orderIdx,
    Expression<String>? pgn,
    Expression<String>? headersJson,
    Expression<String>? white,
    Expression<String>? black,
    Expression<String>? event,
    Expression<String>? date,
    Expression<String>? result,
    Expression<String>? eco,
    Expression<String>? opening,
    Expression<String>? rootFen,
    Expression<int>? plyCount,
    Expression<String>? issuesJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collectionId != null) 'collection_id': collectionId,
      if (orderIdx != null) 'order_idx': orderIdx,
      if (pgn != null) 'pgn': pgn,
      if (headersJson != null) 'headers_json': headersJson,
      if (white != null) 'white': white,
      if (black != null) 'black': black,
      if (event != null) 'event': event,
      if (date != null) 'date': date,
      if (result != null) 'result': result,
      if (eco != null) 'eco': eco,
      if (opening != null) 'opening': opening,
      if (rootFen != null) 'root_fen': rootFen,
      if (plyCount != null) 'ply_count': plyCount,
      if (issuesJson != null) 'issues_json': issuesJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GamesCompanion copyWith({
    Value<int>? id,
    Value<int>? collectionId,
    Value<int>? orderIdx,
    Value<String>? pgn,
    Value<String>? headersJson,
    Value<String>? white,
    Value<String>? black,
    Value<String>? event,
    Value<String>? date,
    Value<String>? result,
    Value<String>? eco,
    Value<String>? opening,
    Value<String?>? rootFen,
    Value<int>? plyCount,
    Value<String>? issuesJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return GamesCompanion(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      orderIdx: orderIdx ?? this.orderIdx,
      pgn: pgn ?? this.pgn,
      headersJson: headersJson ?? this.headersJson,
      white: white ?? this.white,
      black: black ?? this.black,
      event: event ?? this.event,
      date: date ?? this.date,
      result: result ?? this.result,
      eco: eco ?? this.eco,
      opening: opening ?? this.opening,
      rootFen: rootFen ?? this.rootFen,
      plyCount: plyCount ?? this.plyCount,
      issuesJson: issuesJson ?? this.issuesJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    if (orderIdx.present) {
      map['order_idx'] = Variable<int>(orderIdx.value);
    }
    if (pgn.present) {
      map['pgn'] = Variable<String>(pgn.value);
    }
    if (headersJson.present) {
      map['headers_json'] = Variable<String>(headersJson.value);
    }
    if (white.present) {
      map['white'] = Variable<String>(white.value);
    }
    if (black.present) {
      map['black'] = Variable<String>(black.value);
    }
    if (event.present) {
      map['event'] = Variable<String>(event.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (eco.present) {
      map['eco'] = Variable<String>(eco.value);
    }
    if (opening.present) {
      map['opening'] = Variable<String>(opening.value);
    }
    if (rootFen.present) {
      map['root_fen'] = Variable<String>(rootFen.value);
    }
    if (plyCount.present) {
      map['ply_count'] = Variable<int>(plyCount.value);
    }
    if (issuesJson.present) {
      map['issues_json'] = Variable<String>(issuesJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamesCompanion(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('orderIdx: $orderIdx, ')
          ..write('pgn: $pgn, ')
          ..write('headersJson: $headersJson, ')
          ..write('white: $white, ')
          ..write('black: $black, ')
          ..write('event: $event, ')
          ..write('date: $date, ')
          ..write('result: $result, ')
          ..write('eco: $eco, ')
          ..write('opening: $opening, ')
          ..write('rootFen: $rootFen, ')
          ..write('plyCount: $plyCount, ')
          ..write('issuesJson: $issuesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RepertoiresTable extends Repertoires with TableInfo<$RepertoiresTable, RepertoireRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepertoiresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootKeyMeta = const VerificationMeta('rootKey');
  @override
  late final GeneratedColumn<String> rootKey = GeneratedColumn<String>(
    'root_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootFenMeta = const VerificationMeta('rootFen');
  @override
  late final GeneratedColumn<String> rootFen = GeneratedColumn<String>(
    'root_fen',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta('optionsJson');
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    rootKey,
    rootFen,
    description,
    optionsJson,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repertoires';
  @override
  VerificationContext validateIntegrity(Insertable<RepertoireRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(_colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('root_key')) {
      context.handle(_rootKeyMeta, rootKey.isAcceptableOrUnknown(data['root_key']!, _rootKeyMeta));
    } else if (isInserting) {
      context.missing(_rootKeyMeta);
    }
    if (data.containsKey('root_fen')) {
      context.handle(_rootFenMeta, rootFen.isAcceptableOrUnknown(data['root_fen']!, _rootFenMeta));
    } else if (isInserting) {
      context.missing(_rootFenMeta);
    }
    if (data.containsKey('description')) {
      context.handle(_descriptionMeta, description.isAcceptableOrUnknown(data['description']!, _descriptionMeta));
    }
    if (data.containsKey('options_json')) {
      context.handle(_optionsJsonMeta, optionsJson.isAcceptableOrUnknown(data['options_json']!, _optionsJsonMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta, sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RepertoireRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepertoireRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}color'])!,
      rootKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}root_key'])!,
      rootFen: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}root_fen'])!,
      description: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      optionsJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}options_json'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $RepertoiresTable createAlias(String alias) {
    return $RepertoiresTable(attachedDatabase, alias);
  }
}

class RepertoireRow extends DataClass implements Insertable<RepertoireRow> {
  final int id;
  final String name;

  /// white | black
  final String color;
  final String rootKey;
  final String rootFen;
  final String description;

  /// JSON with per-repertoire training options (opponent strategy etc).
  final String optionsJson;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RepertoireRow({
    required this.id,
    required this.name,
    required this.color,
    required this.rootKey,
    required this.rootFen,
    required this.description,
    required this.optionsJson,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['root_key'] = Variable<String>(rootKey);
    map['root_fen'] = Variable<String>(rootFen);
    map['description'] = Variable<String>(description);
    map['options_json'] = Variable<String>(optionsJson);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RepertoiresCompanion toCompanion(bool nullToAbsent) {
    return RepertoiresCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      rootKey: Value(rootKey),
      rootFen: Value(rootFen),
      description: Value(description),
      optionsJson: Value(optionsJson),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RepertoireRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepertoireRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      rootKey: serializer.fromJson<String>(json['rootKey']),
      rootFen: serializer.fromJson<String>(json['rootFen']),
      description: serializer.fromJson<String>(json['description']),
      optionsJson: serializer.fromJson<String>(json['optionsJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'rootKey': serializer.toJson<String>(rootKey),
      'rootFen': serializer.toJson<String>(rootFen),
      'description': serializer.toJson<String>(description),
      'optionsJson': serializer.toJson<String>(optionsJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RepertoireRow copyWith({
    int? id,
    String? name,
    String? color,
    String? rootKey,
    String? rootFen,
    String? description,
    String? optionsJson,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RepertoireRow(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    rootKey: rootKey ?? this.rootKey,
    rootFen: rootFen ?? this.rootFen,
    description: description ?? this.description,
    optionsJson: optionsJson ?? this.optionsJson,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RepertoireRow copyWithCompanion(RepertoiresCompanion data) {
    return RepertoireRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      rootKey: data.rootKey.present ? data.rootKey.value : this.rootKey,
      rootFen: data.rootFen.present ? data.rootFen.value : this.rootFen,
      description: data.description.present ? data.description.value : this.description,
      optionsJson: data.optionsJson.present ? data.optionsJson.value : this.optionsJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepertoireRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('rootKey: $rootKey, ')
          ..write('rootFen: $rootFen, ')
          ..write('description: $description, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, color, rootKey, rootFen, description, optionsJson, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepertoireRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.rootKey == this.rootKey &&
          other.rootFen == this.rootFen &&
          other.description == this.description &&
          other.optionsJson == this.optionsJson &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RepertoiresCompanion extends UpdateCompanion<RepertoireRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> color;
  final Value<String> rootKey;
  final Value<String> rootFen;
  final Value<String> description;
  final Value<String> optionsJson;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const RepertoiresCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.rootKey = const Value.absent(),
    this.rootFen = const Value.absent(),
    this.description = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RepertoiresCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String color,
    required String rootKey,
    required String rootFen,
    this.description = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       color = Value(color),
       rootKey = Value(rootKey),
       rootFen = Value(rootFen),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RepertoireRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<String>? rootKey,
    Expression<String>? rootFen,
    Expression<String>? description,
    Expression<String>? optionsJson,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (rootKey != null) 'root_key': rootKey,
      if (rootFen != null) 'root_fen': rootFen,
      if (description != null) 'description': description,
      if (optionsJson != null) 'options_json': optionsJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RepertoiresCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? color,
    Value<String>? rootKey,
    Value<String>? rootFen,
    Value<String>? description,
    Value<String>? optionsJson,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return RepertoiresCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      rootKey: rootKey ?? this.rootKey,
      rootFen: rootFen ?? this.rootFen,
      description: description ?? this.description,
      optionsJson: optionsJson ?? this.optionsJson,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (rootKey.present) {
      map['root_key'] = Variable<String>(rootKey.value);
    }
    if (rootFen.present) {
      map['root_fen'] = Variable<String>(rootFen.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepertoiresCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('rootKey: $rootKey, ')
          ..write('rootFen: $rootFen, ')
          ..write('description: $description, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RepPositionsTable extends RepPositions with TableInfo<$RepPositionsTable, RepPositionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _repertoireIdMeta = const VerificationMeta('repertoireId');
  @override
  late final GeneratedColumn<int> repertoireId = GeneratedColumn<int>(
    'repertoire_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES repertoires (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _positionKeyMeta = const VerificationMeta('positionKey');
  @override
  late final GeneratedColumn<String> positionKey = GeneratedColumn<String>(
    'position_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fenMeta = const VerificationMeta('fen');
  @override
  late final GeneratedColumn<String> fen = GeneratedColumn<String>(
    'fen',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta('comment');
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _shapesMeta = const VerificationMeta('shapes');
  @override
  late final GeneratedColumn<String> shapes = GeneratedColumn<String>(
    'shapes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _conflictDeferredMeta = const VerificationMeta('conflictDeferred');
  @override
  late final GeneratedColumn<bool> conflictDeferred = GeneratedColumn<bool>(
    'conflict_deferred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("conflict_deferred" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _engineFlagMeta = const VerificationMeta('engineFlag');
  @override
  late final GeneratedColumn<String> engineFlag = GeneratedColumn<String>(
    'engine_flag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [repertoireId, positionKey, fen, comment, shapes, conflictDeferred, engineFlag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rep_positions';
  @override
  VerificationContext validateIntegrity(Insertable<RepPositionRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('repertoire_id')) {
      context.handle(_repertoireIdMeta, repertoireId.isAcceptableOrUnknown(data['repertoire_id']!, _repertoireIdMeta));
    } else if (isInserting) {
      context.missing(_repertoireIdMeta);
    }
    if (data.containsKey('position_key')) {
      context.handle(_positionKeyMeta, positionKey.isAcceptableOrUnknown(data['position_key']!, _positionKeyMeta));
    } else if (isInserting) {
      context.missing(_positionKeyMeta);
    }
    if (data.containsKey('fen')) {
      context.handle(_fenMeta, fen.isAcceptableOrUnknown(data['fen']!, _fenMeta));
    } else if (isInserting) {
      context.missing(_fenMeta);
    }
    if (data.containsKey('comment')) {
      context.handle(_commentMeta, comment.isAcceptableOrUnknown(data['comment']!, _commentMeta));
    }
    if (data.containsKey('shapes')) {
      context.handle(_shapesMeta, shapes.isAcceptableOrUnknown(data['shapes']!, _shapesMeta));
    }
    if (data.containsKey('conflict_deferred')) {
      context.handle(
        _conflictDeferredMeta,
        conflictDeferred.isAcceptableOrUnknown(data['conflict_deferred']!, _conflictDeferredMeta),
      );
    }
    if (data.containsKey('engine_flag')) {
      context.handle(_engineFlagMeta, engineFlag.isAcceptableOrUnknown(data['engine_flag']!, _engineFlagMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {repertoireId, positionKey};
  @override
  RepPositionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepPositionRow(
      repertoireId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}repertoire_id'])!,
      positionKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}position_key'])!,
      fen: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fen'])!,
      comment: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}comment'])!,
      shapes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}shapes'])!,
      conflictDeferred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}conflict_deferred'],
      )!,
      engineFlag: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}engine_flag'])!,
    );
  }

  @override
  $RepPositionsTable createAlias(String alias) {
    return $RepPositionsTable(attachedDatabase, alias);
  }
}

class RepPositionRow extends DataClass implements Insertable<RepPositionRow> {
  final int repertoireId;
  final String positionKey;
  final String fen;
  final String comment;

  /// Encoded shapes ("Ge2e4,Rd4"), shown when the position is on the board.
  final String shapes;

  /// Deferred conflict: training of this position is disabled (F-REP-06).
  final bool conflictDeferred;

  /// Engine review flag (F-ENG-04): JSON or empty.
  final String engineFlag;
  const RepPositionRow({
    required this.repertoireId,
    required this.positionKey,
    required this.fen,
    required this.comment,
    required this.shapes,
    required this.conflictDeferred,
    required this.engineFlag,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['repertoire_id'] = Variable<int>(repertoireId);
    map['position_key'] = Variable<String>(positionKey);
    map['fen'] = Variable<String>(fen);
    map['comment'] = Variable<String>(comment);
    map['shapes'] = Variable<String>(shapes);
    map['conflict_deferred'] = Variable<bool>(conflictDeferred);
    map['engine_flag'] = Variable<String>(engineFlag);
    return map;
  }

  RepPositionsCompanion toCompanion(bool nullToAbsent) {
    return RepPositionsCompanion(
      repertoireId: Value(repertoireId),
      positionKey: Value(positionKey),
      fen: Value(fen),
      comment: Value(comment),
      shapes: Value(shapes),
      conflictDeferred: Value(conflictDeferred),
      engineFlag: Value(engineFlag),
    );
  }

  factory RepPositionRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepPositionRow(
      repertoireId: serializer.fromJson<int>(json['repertoireId']),
      positionKey: serializer.fromJson<String>(json['positionKey']),
      fen: serializer.fromJson<String>(json['fen']),
      comment: serializer.fromJson<String>(json['comment']),
      shapes: serializer.fromJson<String>(json['shapes']),
      conflictDeferred: serializer.fromJson<bool>(json['conflictDeferred']),
      engineFlag: serializer.fromJson<String>(json['engineFlag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'repertoireId': serializer.toJson<int>(repertoireId),
      'positionKey': serializer.toJson<String>(positionKey),
      'fen': serializer.toJson<String>(fen),
      'comment': serializer.toJson<String>(comment),
      'shapes': serializer.toJson<String>(shapes),
      'conflictDeferred': serializer.toJson<bool>(conflictDeferred),
      'engineFlag': serializer.toJson<String>(engineFlag),
    };
  }

  RepPositionRow copyWith({
    int? repertoireId,
    String? positionKey,
    String? fen,
    String? comment,
    String? shapes,
    bool? conflictDeferred,
    String? engineFlag,
  }) => RepPositionRow(
    repertoireId: repertoireId ?? this.repertoireId,
    positionKey: positionKey ?? this.positionKey,
    fen: fen ?? this.fen,
    comment: comment ?? this.comment,
    shapes: shapes ?? this.shapes,
    conflictDeferred: conflictDeferred ?? this.conflictDeferred,
    engineFlag: engineFlag ?? this.engineFlag,
  );
  RepPositionRow copyWithCompanion(RepPositionsCompanion data) {
    return RepPositionRow(
      repertoireId: data.repertoireId.present ? data.repertoireId.value : this.repertoireId,
      positionKey: data.positionKey.present ? data.positionKey.value : this.positionKey,
      fen: data.fen.present ? data.fen.value : this.fen,
      comment: data.comment.present ? data.comment.value : this.comment,
      shapes: data.shapes.present ? data.shapes.value : this.shapes,
      conflictDeferred: data.conflictDeferred.present ? data.conflictDeferred.value : this.conflictDeferred,
      engineFlag: data.engineFlag.present ? data.engineFlag.value : this.engineFlag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepPositionRow(')
          ..write('repertoireId: $repertoireId, ')
          ..write('positionKey: $positionKey, ')
          ..write('fen: $fen, ')
          ..write('comment: $comment, ')
          ..write('shapes: $shapes, ')
          ..write('conflictDeferred: $conflictDeferred, ')
          ..write('engineFlag: $engineFlag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(repertoireId, positionKey, fen, comment, shapes, conflictDeferred, engineFlag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepPositionRow &&
          other.repertoireId == this.repertoireId &&
          other.positionKey == this.positionKey &&
          other.fen == this.fen &&
          other.comment == this.comment &&
          other.shapes == this.shapes &&
          other.conflictDeferred == this.conflictDeferred &&
          other.engineFlag == this.engineFlag);
}

class RepPositionsCompanion extends UpdateCompanion<RepPositionRow> {
  final Value<int> repertoireId;
  final Value<String> positionKey;
  final Value<String> fen;
  final Value<String> comment;
  final Value<String> shapes;
  final Value<bool> conflictDeferred;
  final Value<String> engineFlag;
  final Value<int> rowid;
  const RepPositionsCompanion({
    this.repertoireId = const Value.absent(),
    this.positionKey = const Value.absent(),
    this.fen = const Value.absent(),
    this.comment = const Value.absent(),
    this.shapes = const Value.absent(),
    this.conflictDeferred = const Value.absent(),
    this.engineFlag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RepPositionsCompanion.insert({
    required int repertoireId,
    required String positionKey,
    required String fen,
    this.comment = const Value.absent(),
    this.shapes = const Value.absent(),
    this.conflictDeferred = const Value.absent(),
    this.engineFlag = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : repertoireId = Value(repertoireId),
       positionKey = Value(positionKey),
       fen = Value(fen);
  static Insertable<RepPositionRow> custom({
    Expression<int>? repertoireId,
    Expression<String>? positionKey,
    Expression<String>? fen,
    Expression<String>? comment,
    Expression<String>? shapes,
    Expression<bool>? conflictDeferred,
    Expression<String>? engineFlag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (repertoireId != null) 'repertoire_id': repertoireId,
      if (positionKey != null) 'position_key': positionKey,
      if (fen != null) 'fen': fen,
      if (comment != null) 'comment': comment,
      if (shapes != null) 'shapes': shapes,
      if (conflictDeferred != null) 'conflict_deferred': conflictDeferred,
      if (engineFlag != null) 'engine_flag': engineFlag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RepPositionsCompanion copyWith({
    Value<int>? repertoireId,
    Value<String>? positionKey,
    Value<String>? fen,
    Value<String>? comment,
    Value<String>? shapes,
    Value<bool>? conflictDeferred,
    Value<String>? engineFlag,
    Value<int>? rowid,
  }) {
    return RepPositionsCompanion(
      repertoireId: repertoireId ?? this.repertoireId,
      positionKey: positionKey ?? this.positionKey,
      fen: fen ?? this.fen,
      comment: comment ?? this.comment,
      shapes: shapes ?? this.shapes,
      conflictDeferred: conflictDeferred ?? this.conflictDeferred,
      engineFlag: engineFlag ?? this.engineFlag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (repertoireId.present) {
      map['repertoire_id'] = Variable<int>(repertoireId.value);
    }
    if (positionKey.present) {
      map['position_key'] = Variable<String>(positionKey.value);
    }
    if (fen.present) {
      map['fen'] = Variable<String>(fen.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (shapes.present) {
      map['shapes'] = Variable<String>(shapes.value);
    }
    if (conflictDeferred.present) {
      map['conflict_deferred'] = Variable<bool>(conflictDeferred.value);
    }
    if (engineFlag.present) {
      map['engine_flag'] = Variable<String>(engineFlag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepPositionsCompanion(')
          ..write('repertoireId: $repertoireId, ')
          ..write('positionKey: $positionKey, ')
          ..write('fen: $fen, ')
          ..write('comment: $comment, ')
          ..write('shapes: $shapes, ')
          ..write('conflictDeferred: $conflictDeferred, ')
          ..write('engineFlag: $engineFlag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RepMovesTable extends RepMoves with TableInfo<$RepMovesTable, RepMoveRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepMovesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _repertoireIdMeta = const VerificationMeta('repertoireId');
  @override
  late final GeneratedColumn<int> repertoireId = GeneratedColumn<int>(
    'repertoire_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES repertoires (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _fromKeyMeta = const VerificationMeta('fromKey');
  @override
  late final GeneratedColumn<String> fromKey = GeneratedColumn<String>(
    'from_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uciMeta = const VerificationMeta('uci');
  @override
  late final GeneratedColumn<String> uci = GeneratedColumn<String>(
    'uci',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toKeyMeta = const VerificationMeta('toKey');
  @override
  late final GeneratedColumn<String> toKey = GeneratedColumn<String>(
    'to_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sanMeta = const VerificationMeta('san');
  @override
  late final GeneratedColumn<String> san = GeneratedColumn<String>(
    'san',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<int> weight = GeneratedColumn<int>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(50),
  );
  static const VerificationMeta _commentMeta = const VerificationMeta('comment');
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    repertoireId,
    fromKey,
    uci,
    toKey,
    san,
    role,
    weight,
    comment,
    source,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rep_moves';
  @override
  VerificationContext validateIntegrity(Insertable<RepMoveRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('repertoire_id')) {
      context.handle(_repertoireIdMeta, repertoireId.isAcceptableOrUnknown(data['repertoire_id']!, _repertoireIdMeta));
    } else if (isInserting) {
      context.missing(_repertoireIdMeta);
    }
    if (data.containsKey('from_key')) {
      context.handle(_fromKeyMeta, fromKey.isAcceptableOrUnknown(data['from_key']!, _fromKeyMeta));
    } else if (isInserting) {
      context.missing(_fromKeyMeta);
    }
    if (data.containsKey('uci')) {
      context.handle(_uciMeta, uci.isAcceptableOrUnknown(data['uci']!, _uciMeta));
    } else if (isInserting) {
      context.missing(_uciMeta);
    }
    if (data.containsKey('to_key')) {
      context.handle(_toKeyMeta, toKey.isAcceptableOrUnknown(data['to_key']!, _toKeyMeta));
    } else if (isInserting) {
      context.missing(_toKeyMeta);
    }
    if (data.containsKey('san')) {
      context.handle(_sanMeta, san.isAcceptableOrUnknown(data['san']!, _sanMeta));
    } else if (isInserting) {
      context.missing(_sanMeta);
    }
    if (data.containsKey('role')) {
      context.handle(_roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta, weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    }
    if (data.containsKey('comment')) {
      context.handle(_commentMeta, comment.isAcceptableOrUnknown(data['comment']!, _commentMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta, source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta, sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {repertoireId, fromKey, uci};
  @override
  RepMoveRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepMoveRow(
      repertoireId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}repertoire_id'])!,
      fromKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}from_key'])!,
      uci: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}uci'])!,
      toKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}to_key'])!,
      san: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}san'])!,
      role: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      weight: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}weight'])!,
      comment: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}comment'])!,
      source: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $RepMovesTable createAlias(String alias) {
    return $RepMovesTable(attachedDatabase, alias);
  }
}

class RepMoveRow extends DataClass implements Insertable<RepMoveRow> {
  final int repertoireId;
  final String fromKey;
  final String uci;
  final String toKey;
  final String san;

  /// main | alternative for the user's moves; empty for opponent moves.
  final String role;

  /// 0..100, frequency weight for opponent moves.
  final int weight;
  final String comment;

  /// manual | pgn | lichess-study | explorer | engine | starter
  final String source;
  final int sortOrder;
  final DateTime createdAt;
  const RepMoveRow({
    required this.repertoireId,
    required this.fromKey,
    required this.uci,
    required this.toKey,
    required this.san,
    required this.role,
    required this.weight,
    required this.comment,
    required this.source,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['repertoire_id'] = Variable<int>(repertoireId);
    map['from_key'] = Variable<String>(fromKey);
    map['uci'] = Variable<String>(uci);
    map['to_key'] = Variable<String>(toKey);
    map['san'] = Variable<String>(san);
    map['role'] = Variable<String>(role);
    map['weight'] = Variable<int>(weight);
    map['comment'] = Variable<String>(comment);
    map['source'] = Variable<String>(source);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RepMovesCompanion toCompanion(bool nullToAbsent) {
    return RepMovesCompanion(
      repertoireId: Value(repertoireId),
      fromKey: Value(fromKey),
      uci: Value(uci),
      toKey: Value(toKey),
      san: Value(san),
      role: Value(role),
      weight: Value(weight),
      comment: Value(comment),
      source: Value(source),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory RepMoveRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepMoveRow(
      repertoireId: serializer.fromJson<int>(json['repertoireId']),
      fromKey: serializer.fromJson<String>(json['fromKey']),
      uci: serializer.fromJson<String>(json['uci']),
      toKey: serializer.fromJson<String>(json['toKey']),
      san: serializer.fromJson<String>(json['san']),
      role: serializer.fromJson<String>(json['role']),
      weight: serializer.fromJson<int>(json['weight']),
      comment: serializer.fromJson<String>(json['comment']),
      source: serializer.fromJson<String>(json['source']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'repertoireId': serializer.toJson<int>(repertoireId),
      'fromKey': serializer.toJson<String>(fromKey),
      'uci': serializer.toJson<String>(uci),
      'toKey': serializer.toJson<String>(toKey),
      'san': serializer.toJson<String>(san),
      'role': serializer.toJson<String>(role),
      'weight': serializer.toJson<int>(weight),
      'comment': serializer.toJson<String>(comment),
      'source': serializer.toJson<String>(source),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RepMoveRow copyWith({
    int? repertoireId,
    String? fromKey,
    String? uci,
    String? toKey,
    String? san,
    String? role,
    int? weight,
    String? comment,
    String? source,
    int? sortOrder,
    DateTime? createdAt,
  }) => RepMoveRow(
    repertoireId: repertoireId ?? this.repertoireId,
    fromKey: fromKey ?? this.fromKey,
    uci: uci ?? this.uci,
    toKey: toKey ?? this.toKey,
    san: san ?? this.san,
    role: role ?? this.role,
    weight: weight ?? this.weight,
    comment: comment ?? this.comment,
    source: source ?? this.source,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  RepMoveRow copyWithCompanion(RepMovesCompanion data) {
    return RepMoveRow(
      repertoireId: data.repertoireId.present ? data.repertoireId.value : this.repertoireId,
      fromKey: data.fromKey.present ? data.fromKey.value : this.fromKey,
      uci: data.uci.present ? data.uci.value : this.uci,
      toKey: data.toKey.present ? data.toKey.value : this.toKey,
      san: data.san.present ? data.san.value : this.san,
      role: data.role.present ? data.role.value : this.role,
      weight: data.weight.present ? data.weight.value : this.weight,
      comment: data.comment.present ? data.comment.value : this.comment,
      source: data.source.present ? data.source.value : this.source,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepMoveRow(')
          ..write('repertoireId: $repertoireId, ')
          ..write('fromKey: $fromKey, ')
          ..write('uci: $uci, ')
          ..write('toKey: $toKey, ')
          ..write('san: $san, ')
          ..write('role: $role, ')
          ..write('weight: $weight, ')
          ..write('comment: $comment, ')
          ..write('source: $source, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(repertoireId, fromKey, uci, toKey, san, role, weight, comment, source, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepMoveRow &&
          other.repertoireId == this.repertoireId &&
          other.fromKey == this.fromKey &&
          other.uci == this.uci &&
          other.toKey == this.toKey &&
          other.san == this.san &&
          other.role == this.role &&
          other.weight == this.weight &&
          other.comment == this.comment &&
          other.source == this.source &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class RepMovesCompanion extends UpdateCompanion<RepMoveRow> {
  final Value<int> repertoireId;
  final Value<String> fromKey;
  final Value<String> uci;
  final Value<String> toKey;
  final Value<String> san;
  final Value<String> role;
  final Value<int> weight;
  final Value<String> comment;
  final Value<String> source;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RepMovesCompanion({
    this.repertoireId = const Value.absent(),
    this.fromKey = const Value.absent(),
    this.uci = const Value.absent(),
    this.toKey = const Value.absent(),
    this.san = const Value.absent(),
    this.role = const Value.absent(),
    this.weight = const Value.absent(),
    this.comment = const Value.absent(),
    this.source = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RepMovesCompanion.insert({
    required int repertoireId,
    required String fromKey,
    required String uci,
    required String toKey,
    required String san,
    this.role = const Value.absent(),
    this.weight = const Value.absent(),
    this.comment = const Value.absent(),
    this.source = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : repertoireId = Value(repertoireId),
       fromKey = Value(fromKey),
       uci = Value(uci),
       toKey = Value(toKey),
       san = Value(san),
       createdAt = Value(createdAt);
  static Insertable<RepMoveRow> custom({
    Expression<int>? repertoireId,
    Expression<String>? fromKey,
    Expression<String>? uci,
    Expression<String>? toKey,
    Expression<String>? san,
    Expression<String>? role,
    Expression<int>? weight,
    Expression<String>? comment,
    Expression<String>? source,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (repertoireId != null) 'repertoire_id': repertoireId,
      if (fromKey != null) 'from_key': fromKey,
      if (uci != null) 'uci': uci,
      if (toKey != null) 'to_key': toKey,
      if (san != null) 'san': san,
      if (role != null) 'role': role,
      if (weight != null) 'weight': weight,
      if (comment != null) 'comment': comment,
      if (source != null) 'source': source,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RepMovesCompanion copyWith({
    Value<int>? repertoireId,
    Value<String>? fromKey,
    Value<String>? uci,
    Value<String>? toKey,
    Value<String>? san,
    Value<String>? role,
    Value<int>? weight,
    Value<String>? comment,
    Value<String>? source,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RepMovesCompanion(
      repertoireId: repertoireId ?? this.repertoireId,
      fromKey: fromKey ?? this.fromKey,
      uci: uci ?? this.uci,
      toKey: toKey ?? this.toKey,
      san: san ?? this.san,
      role: role ?? this.role,
      weight: weight ?? this.weight,
      comment: comment ?? this.comment,
      source: source ?? this.source,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (repertoireId.present) {
      map['repertoire_id'] = Variable<int>(repertoireId.value);
    }
    if (fromKey.present) {
      map['from_key'] = Variable<String>(fromKey.value);
    }
    if (uci.present) {
      map['uci'] = Variable<String>(uci.value);
    }
    if (toKey.present) {
      map['to_key'] = Variable<String>(toKey.value);
    }
    if (san.present) {
      map['san'] = Variable<String>(san.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (weight.present) {
      map['weight'] = Variable<int>(weight.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepMovesCompanion(')
          ..write('repertoireId: $repertoireId, ')
          ..write('fromKey: $fromKey, ')
          ..write('uci: $uci, ')
          ..write('toKey: $toKey, ')
          ..write('san: $san, ')
          ..write('role: $role, ')
          ..write('weight: $weight, ')
          ..write('comment: $comment, ')
          ..write('source: $source, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, CardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _repertoireIdMeta = const VerificationMeta('repertoireId');
  @override
  late final GeneratedColumn<int> repertoireId = GeneratedColumn<int>(
    'repertoire_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES repertoires (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _positionKeyMeta = const VerificationMeta('positionKey');
  @override
  late final GeneratedColumn<String> positionKey = GeneratedColumn<String>(
    'position_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta('stability');
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueMeta = const VerificationMeta('due');
  @override
  late final GeneratedColumn<DateTime> due = GeneratedColumn<DateTime>(
    'due',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReviewMeta = const VerificationMeta('lastReview');
  @override
  late final GeneratedColumn<DateTime> lastReview = GeneratedColumn<DateTime>(
    'last_review',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('newCard'),
  );
  static const VerificationMeta _suspendedMeta = const VerificationMeta('suspended');
  @override
  late final GeneratedColumn<bool> suspended = GeneratedColumn<bool>(
    'suspended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("suspended" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    repertoireId,
    positionKey,
    stability,
    difficulty,
    due,
    lastReview,
    reps,
    lapses,
    state,
    suspended,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(Insertable<CardRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('repertoire_id')) {
      context.handle(_repertoireIdMeta, repertoireId.isAcceptableOrUnknown(data['repertoire_id']!, _repertoireIdMeta));
    } else if (isInserting) {
      context.missing(_repertoireIdMeta);
    }
    if (data.containsKey('position_key')) {
      context.handle(_positionKeyMeta, positionKey.isAcceptableOrUnknown(data['position_key']!, _positionKeyMeta));
    } else if (isInserting) {
      context.missing(_positionKeyMeta);
    }
    if (data.containsKey('stability')) {
      context.handle(_stabilityMeta, stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta));
    }
    if (data.containsKey('difficulty')) {
      context.handle(_difficultyMeta, difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta));
    }
    if (data.containsKey('due')) {
      context.handle(_dueMeta, due.isAcceptableOrUnknown(data['due']!, _dueMeta));
    }
    if (data.containsKey('last_review')) {
      context.handle(_lastReviewMeta, lastReview.isAcceptableOrUnknown(data['last_review']!, _lastReviewMeta));
    }
    if (data.containsKey('reps')) {
      context.handle(_repsMeta, reps.isAcceptableOrUnknown(data['reps']!, _repsMeta));
    }
    if (data.containsKey('lapses')) {
      context.handle(_lapsesMeta, lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta));
    }
    if (data.containsKey('state')) {
      context.handle(_stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('suspended')) {
      context.handle(_suspendedMeta, suspended.isAcceptableOrUnknown(data['suspended']!, _suspendedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {repertoireId, positionKey};
  @override
  CardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRow(
      repertoireId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}repertoire_id'])!,
      positionKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}position_key'])!,
      stability: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}stability'])!,
      difficulty: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}difficulty'])!,
      due: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}due']),
      lastReview: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}last_review']),
      reps: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reps'])!,
      lapses: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}lapses'])!,
      state: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      suspended: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}suspended'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class CardRow extends DataClass implements Insertable<CardRow> {
  final int repertoireId;
  final String positionKey;
  final double stability;
  final double difficulty;
  final DateTime? due;
  final DateTime? lastReview;
  final int reps;
  final int lapses;

  /// newCard | learning | review | relearning
  final String state;
  final bool suspended;
  final DateTime createdAt;
  const CardRow({
    required this.repertoireId,
    required this.positionKey,
    required this.stability,
    required this.difficulty,
    this.due,
    this.lastReview,
    required this.reps,
    required this.lapses,
    required this.state,
    required this.suspended,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['repertoire_id'] = Variable<int>(repertoireId);
    map['position_key'] = Variable<String>(positionKey);
    map['stability'] = Variable<double>(stability);
    map['difficulty'] = Variable<double>(difficulty);
    if (!nullToAbsent || due != null) {
      map['due'] = Variable<DateTime>(due);
    }
    if (!nullToAbsent || lastReview != null) {
      map['last_review'] = Variable<DateTime>(lastReview);
    }
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    map['state'] = Variable<String>(state);
    map['suspended'] = Variable<bool>(suspended);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      repertoireId: Value(repertoireId),
      positionKey: Value(positionKey),
      stability: Value(stability),
      difficulty: Value(difficulty),
      due: due == null && nullToAbsent ? const Value.absent() : Value(due),
      lastReview: lastReview == null && nullToAbsent ? const Value.absent() : Value(lastReview),
      reps: Value(reps),
      lapses: Value(lapses),
      state: Value(state),
      suspended: Value(suspended),
      createdAt: Value(createdAt),
    );
  }

  factory CardRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardRow(
      repertoireId: serializer.fromJson<int>(json['repertoireId']),
      positionKey: serializer.fromJson<String>(json['positionKey']),
      stability: serializer.fromJson<double>(json['stability']),
      difficulty: serializer.fromJson<double>(json['difficulty']),
      due: serializer.fromJson<DateTime?>(json['due']),
      lastReview: serializer.fromJson<DateTime?>(json['lastReview']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      state: serializer.fromJson<String>(json['state']),
      suspended: serializer.fromJson<bool>(json['suspended']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'repertoireId': serializer.toJson<int>(repertoireId),
      'positionKey': serializer.toJson<String>(positionKey),
      'stability': serializer.toJson<double>(stability),
      'difficulty': serializer.toJson<double>(difficulty),
      'due': serializer.toJson<DateTime?>(due),
      'lastReview': serializer.toJson<DateTime?>(lastReview),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'state': serializer.toJson<String>(state),
      'suspended': serializer.toJson<bool>(suspended),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CardRow copyWith({
    int? repertoireId,
    String? positionKey,
    double? stability,
    double? difficulty,
    Value<DateTime?> due = const Value.absent(),
    Value<DateTime?> lastReview = const Value.absent(),
    int? reps,
    int? lapses,
    String? state,
    bool? suspended,
    DateTime? createdAt,
  }) => CardRow(
    repertoireId: repertoireId ?? this.repertoireId,
    positionKey: positionKey ?? this.positionKey,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    due: due.present ? due.value : this.due,
    lastReview: lastReview.present ? lastReview.value : this.lastReview,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    state: state ?? this.state,
    suspended: suspended ?? this.suspended,
    createdAt: createdAt ?? this.createdAt,
  );
  CardRow copyWithCompanion(CardsCompanion data) {
    return CardRow(
      repertoireId: data.repertoireId.present ? data.repertoireId.value : this.repertoireId,
      positionKey: data.positionKey.present ? data.positionKey.value : this.positionKey,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty: data.difficulty.present ? data.difficulty.value : this.difficulty,
      due: data.due.present ? data.due.value : this.due,
      lastReview: data.lastReview.present ? data.lastReview.value : this.lastReview,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      state: data.state.present ? data.state.value : this.state,
      suspended: data.suspended.present ? data.suspended.value : this.suspended,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardRow(')
          ..write('repertoireId: $repertoireId, ')
          ..write('positionKey: $positionKey, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('due: $due, ')
          ..write('lastReview: $lastReview, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('state: $state, ')
          ..write('suspended: $suspended, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    repertoireId,
    positionKey,
    stability,
    difficulty,
    due,
    lastReview,
    reps,
    lapses,
    state,
    suspended,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardRow &&
          other.repertoireId == this.repertoireId &&
          other.positionKey == this.positionKey &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.due == this.due &&
          other.lastReview == this.lastReview &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.state == this.state &&
          other.suspended == this.suspended &&
          other.createdAt == this.createdAt);
}

class CardsCompanion extends UpdateCompanion<CardRow> {
  final Value<int> repertoireId;
  final Value<String> positionKey;
  final Value<double> stability;
  final Value<double> difficulty;
  final Value<DateTime?> due;
  final Value<DateTime?> lastReview;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<String> state;
  final Value<bool> suspended;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CardsCompanion({
    this.repertoireId = const Value.absent(),
    this.positionKey = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.due = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.state = const Value.absent(),
    this.suspended = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required int repertoireId,
    required String positionKey,
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.due = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.state = const Value.absent(),
    this.suspended = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : repertoireId = Value(repertoireId),
       positionKey = Value(positionKey),
       createdAt = Value(createdAt);
  static Insertable<CardRow> custom({
    Expression<int>? repertoireId,
    Expression<String>? positionKey,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<DateTime>? due,
    Expression<DateTime>? lastReview,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<String>? state,
    Expression<bool>? suspended,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (repertoireId != null) 'repertoire_id': repertoireId,
      if (positionKey != null) 'position_key': positionKey,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (due != null) 'due': due,
      if (lastReview != null) 'last_review': lastReview,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (state != null) 'state': state,
      if (suspended != null) 'suspended': suspended,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith({
    Value<int>? repertoireId,
    Value<String>? positionKey,
    Value<double>? stability,
    Value<double>? difficulty,
    Value<DateTime?>? due,
    Value<DateTime?>? lastReview,
    Value<int>? reps,
    Value<int>? lapses,
    Value<String>? state,
    Value<bool>? suspended,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CardsCompanion(
      repertoireId: repertoireId ?? this.repertoireId,
      positionKey: positionKey ?? this.positionKey,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      due: due ?? this.due,
      lastReview: lastReview ?? this.lastReview,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      state: state ?? this.state,
      suspended: suspended ?? this.suspended,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (repertoireId.present) {
      map['repertoire_id'] = Variable<int>(repertoireId.value);
    }
    if (positionKey.present) {
      map['position_key'] = Variable<String>(positionKey.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (due.present) {
      map['due'] = Variable<DateTime>(due.value);
    }
    if (lastReview.present) {
      map['last_review'] = Variable<DateTime>(lastReview.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (suspended.present) {
      map['suspended'] = Variable<bool>(suspended.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('repertoireId: $repertoireId, ')
          ..write('positionKey: $positionKey, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('due: $due, ')
          ..write('lastReview: $lastReview, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('state: $state, ')
          ..write('suspended: $suspended, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogsTable extends ReviewLogs with TableInfo<$ReviewLogsTable, ReviewLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _repertoireIdMeta = const VerificationMeta('repertoireId');
  @override
  late final GeneratedColumn<int> repertoireId = GeneratedColumn<int>(
    'repertoire_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES repertoires (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _positionKeyMeta = const VerificationMeta('positionKey');
  @override
  late final GeneratedColumn<String> positionKey = GeneratedColumn<String>(
    'position_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<String> grade = GeneratedColumn<String>(
    'grade',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedUciMeta = const VerificationMeta('playedUci');
  @override
  late final GeneratedColumn<String> playedUci = GeneratedColumn<String>(
    'played_uci',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _expectedUciMeta = const VerificationMeta('expectedUci');
  @override
  late final GeneratedColumn<String> expectedUci = GeneratedColumn<String>(
    'expected_uci',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseMsMeta = const VerificationMeta('responseMs');
  @override
  late final GeneratedColumn<int> responseMs = GeneratedColumn<int>(
    'response_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _scheduledMeta = const VerificationMeta('scheduled');
  @override
  late final GeneratedColumn<bool> scheduled = GeneratedColumn<bool>(
    'scheduled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("scheduled" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repertoireId,
    positionKey,
    timestamp,
    grade,
    playedUci,
    expectedUci,
    mode,
    responseMs,
    scheduled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_logs';
  @override
  VerificationContext validateIntegrity(Insertable<ReviewLogRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('repertoire_id')) {
      context.handle(_repertoireIdMeta, repertoireId.isAcceptableOrUnknown(data['repertoire_id']!, _repertoireIdMeta));
    } else if (isInserting) {
      context.missing(_repertoireIdMeta);
    }
    if (data.containsKey('position_key')) {
      context.handle(_positionKeyMeta, positionKey.isAcceptableOrUnknown(data['position_key']!, _positionKeyMeta));
    } else if (isInserting) {
      context.missing(_positionKeyMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta, timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('grade')) {
      context.handle(_gradeMeta, grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta));
    } else if (isInserting) {
      context.missing(_gradeMeta);
    }
    if (data.containsKey('played_uci')) {
      context.handle(_playedUciMeta, playedUci.isAcceptableOrUnknown(data['played_uci']!, _playedUciMeta));
    }
    if (data.containsKey('expected_uci')) {
      context.handle(_expectedUciMeta, expectedUci.isAcceptableOrUnknown(data['expected_uci']!, _expectedUciMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(_modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('response_ms')) {
      context.handle(_responseMsMeta, responseMs.isAcceptableOrUnknown(data['response_ms']!, _responseMsMeta));
    }
    if (data.containsKey('scheduled')) {
      context.handle(_scheduledMeta, scheduled.isAcceptableOrUnknown(data['scheduled']!, _scheduledMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewLogRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      repertoireId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}repertoire_id'])!,
      positionKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}position_key'])!,
      timestamp: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      grade: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}grade'])!,
      playedUci: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}played_uci'])!,
      expectedUci: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}expected_uci'])!,
      mode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      responseMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}response_ms'])!,
      scheduled: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}scheduled'])!,
    );
  }

  @override
  $ReviewLogsTable createAlias(String alias) {
    return $ReviewLogsTable(attachedDatabase, alias);
  }
}

class ReviewLogRow extends DataClass implements Insertable<ReviewLogRow> {
  final int id;
  final int repertoireId;
  final String positionKey;
  final DateTime timestamp;

  /// again | hard | good | easy
  final String grade;
  final String playedUci;
  final String expectedUci;

  /// learn | review | drill | light
  final String mode;
  final int responseMs;

  /// Whether the review changed the schedule.
  final bool scheduled;
  const ReviewLogRow({
    required this.id,
    required this.repertoireId,
    required this.positionKey,
    required this.timestamp,
    required this.grade,
    required this.playedUci,
    required this.expectedUci,
    required this.mode,
    required this.responseMs,
    required this.scheduled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['repertoire_id'] = Variable<int>(repertoireId);
    map['position_key'] = Variable<String>(positionKey);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['grade'] = Variable<String>(grade);
    map['played_uci'] = Variable<String>(playedUci);
    map['expected_uci'] = Variable<String>(expectedUci);
    map['mode'] = Variable<String>(mode);
    map['response_ms'] = Variable<int>(responseMs);
    map['scheduled'] = Variable<bool>(scheduled);
    return map;
  }

  ReviewLogsCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogsCompanion(
      id: Value(id),
      repertoireId: Value(repertoireId),
      positionKey: Value(positionKey),
      timestamp: Value(timestamp),
      grade: Value(grade),
      playedUci: Value(playedUci),
      expectedUci: Value(expectedUci),
      mode: Value(mode),
      responseMs: Value(responseMs),
      scheduled: Value(scheduled),
    );
  }

  factory ReviewLogRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewLogRow(
      id: serializer.fromJson<int>(json['id']),
      repertoireId: serializer.fromJson<int>(json['repertoireId']),
      positionKey: serializer.fromJson<String>(json['positionKey']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      grade: serializer.fromJson<String>(json['grade']),
      playedUci: serializer.fromJson<String>(json['playedUci']),
      expectedUci: serializer.fromJson<String>(json['expectedUci']),
      mode: serializer.fromJson<String>(json['mode']),
      responseMs: serializer.fromJson<int>(json['responseMs']),
      scheduled: serializer.fromJson<bool>(json['scheduled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repertoireId': serializer.toJson<int>(repertoireId),
      'positionKey': serializer.toJson<String>(positionKey),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'grade': serializer.toJson<String>(grade),
      'playedUci': serializer.toJson<String>(playedUci),
      'expectedUci': serializer.toJson<String>(expectedUci),
      'mode': serializer.toJson<String>(mode),
      'responseMs': serializer.toJson<int>(responseMs),
      'scheduled': serializer.toJson<bool>(scheduled),
    };
  }

  ReviewLogRow copyWith({
    int? id,
    int? repertoireId,
    String? positionKey,
    DateTime? timestamp,
    String? grade,
    String? playedUci,
    String? expectedUci,
    String? mode,
    int? responseMs,
    bool? scheduled,
  }) => ReviewLogRow(
    id: id ?? this.id,
    repertoireId: repertoireId ?? this.repertoireId,
    positionKey: positionKey ?? this.positionKey,
    timestamp: timestamp ?? this.timestamp,
    grade: grade ?? this.grade,
    playedUci: playedUci ?? this.playedUci,
    expectedUci: expectedUci ?? this.expectedUci,
    mode: mode ?? this.mode,
    responseMs: responseMs ?? this.responseMs,
    scheduled: scheduled ?? this.scheduled,
  );
  ReviewLogRow copyWithCompanion(ReviewLogsCompanion data) {
    return ReviewLogRow(
      id: data.id.present ? data.id.value : this.id,
      repertoireId: data.repertoireId.present ? data.repertoireId.value : this.repertoireId,
      positionKey: data.positionKey.present ? data.positionKey.value : this.positionKey,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      grade: data.grade.present ? data.grade.value : this.grade,
      playedUci: data.playedUci.present ? data.playedUci.value : this.playedUci,
      expectedUci: data.expectedUci.present ? data.expectedUci.value : this.expectedUci,
      mode: data.mode.present ? data.mode.value : this.mode,
      responseMs: data.responseMs.present ? data.responseMs.value : this.responseMs,
      scheduled: data.scheduled.present ? data.scheduled.value : this.scheduled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogRow(')
          ..write('id: $id, ')
          ..write('repertoireId: $repertoireId, ')
          ..write('positionKey: $positionKey, ')
          ..write('timestamp: $timestamp, ')
          ..write('grade: $grade, ')
          ..write('playedUci: $playedUci, ')
          ..write('expectedUci: $expectedUci, ')
          ..write('mode: $mode, ')
          ..write('responseMs: $responseMs, ')
          ..write('scheduled: $scheduled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, repertoireId, positionKey, timestamp, grade, playedUci, expectedUci, mode, responseMs, scheduled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewLogRow &&
          other.id == this.id &&
          other.repertoireId == this.repertoireId &&
          other.positionKey == this.positionKey &&
          other.timestamp == this.timestamp &&
          other.grade == this.grade &&
          other.playedUci == this.playedUci &&
          other.expectedUci == this.expectedUci &&
          other.mode == this.mode &&
          other.responseMs == this.responseMs &&
          other.scheduled == this.scheduled);
}

class ReviewLogsCompanion extends UpdateCompanion<ReviewLogRow> {
  final Value<int> id;
  final Value<int> repertoireId;
  final Value<String> positionKey;
  final Value<DateTime> timestamp;
  final Value<String> grade;
  final Value<String> playedUci;
  final Value<String> expectedUci;
  final Value<String> mode;
  final Value<int> responseMs;
  final Value<bool> scheduled;
  const ReviewLogsCompanion({
    this.id = const Value.absent(),
    this.repertoireId = const Value.absent(),
    this.positionKey = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.grade = const Value.absent(),
    this.playedUci = const Value.absent(),
    this.expectedUci = const Value.absent(),
    this.mode = const Value.absent(),
    this.responseMs = const Value.absent(),
    this.scheduled = const Value.absent(),
  });
  ReviewLogsCompanion.insert({
    this.id = const Value.absent(),
    required int repertoireId,
    required String positionKey,
    required DateTime timestamp,
    required String grade,
    this.playedUci = const Value.absent(),
    this.expectedUci = const Value.absent(),
    required String mode,
    this.responseMs = const Value.absent(),
    this.scheduled = const Value.absent(),
  }) : repertoireId = Value(repertoireId),
       positionKey = Value(positionKey),
       timestamp = Value(timestamp),
       grade = Value(grade),
       mode = Value(mode);
  static Insertable<ReviewLogRow> custom({
    Expression<int>? id,
    Expression<int>? repertoireId,
    Expression<String>? positionKey,
    Expression<DateTime>? timestamp,
    Expression<String>? grade,
    Expression<String>? playedUci,
    Expression<String>? expectedUci,
    Expression<String>? mode,
    Expression<int>? responseMs,
    Expression<bool>? scheduled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repertoireId != null) 'repertoire_id': repertoireId,
      if (positionKey != null) 'position_key': positionKey,
      if (timestamp != null) 'timestamp': timestamp,
      if (grade != null) 'grade': grade,
      if (playedUci != null) 'played_uci': playedUci,
      if (expectedUci != null) 'expected_uci': expectedUci,
      if (mode != null) 'mode': mode,
      if (responseMs != null) 'response_ms': responseMs,
      if (scheduled != null) 'scheduled': scheduled,
    });
  }

  ReviewLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? repertoireId,
    Value<String>? positionKey,
    Value<DateTime>? timestamp,
    Value<String>? grade,
    Value<String>? playedUci,
    Value<String>? expectedUci,
    Value<String>? mode,
    Value<int>? responseMs,
    Value<bool>? scheduled,
  }) {
    return ReviewLogsCompanion(
      id: id ?? this.id,
      repertoireId: repertoireId ?? this.repertoireId,
      positionKey: positionKey ?? this.positionKey,
      timestamp: timestamp ?? this.timestamp,
      grade: grade ?? this.grade,
      playedUci: playedUci ?? this.playedUci,
      expectedUci: expectedUci ?? this.expectedUci,
      mode: mode ?? this.mode,
      responseMs: responseMs ?? this.responseMs,
      scheduled: scheduled ?? this.scheduled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repertoireId.present) {
      map['repertoire_id'] = Variable<int>(repertoireId.value);
    }
    if (positionKey.present) {
      map['position_key'] = Variable<String>(positionKey.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (grade.present) {
      map['grade'] = Variable<String>(grade.value);
    }
    if (playedUci.present) {
      map['played_uci'] = Variable<String>(playedUci.value);
    }
    if (expectedUci.present) {
      map['expected_uci'] = Variable<String>(expectedUci.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (responseMs.present) {
      map['response_ms'] = Variable<int>(responseMs.value);
    }
    if (scheduled.present) {
      map['scheduled'] = Variable<bool>(scheduled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsCompanion(')
          ..write('id: $id, ')
          ..write('repertoireId: $repertoireId, ')
          ..write('positionKey: $positionKey, ')
          ..write('timestamp: $timestamp, ')
          ..write('grade: $grade, ')
          ..write('playedUci: $playedUci, ')
          ..write('expectedUci: $expectedUci, ')
          ..write('mode: $mode, ')
          ..write('responseMs: $responseMs, ')
          ..write('scheduled: $scheduled')
          ..write(')'))
        .toString();
  }
}

class $LinkedAccountsTable extends LinkedAccounts with TableInfo<$LinkedAccountsTable, LinkedAccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LinkedAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerMeta = const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenRefMeta = const VerificationMeta('tokenRef');
  @override
  late final GeneratedColumn<String> tokenRef = GeneratedColumn<String>(
    'token_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scopesMeta = const VerificationMeta('scopes');
  @override
  late final GeneratedColumn<String> scopes = GeneratedColumn<String>(
    'scopes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _connectedAtMeta = const VerificationMeta('connectedAt');
  @override
  late final GeneratedColumn<DateTime> connectedAt = GeneratedColumn<DateTime>(
    'connected_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta('lastSyncAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [provider, username, tokenRef, scopes, connectedAt, lastSyncAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'linked_accounts';
  @override
  VerificationContext validateIntegrity(Insertable<LinkedAccountRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('provider')) {
      context.handle(_providerMeta, provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta, username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('token_ref')) {
      context.handle(_tokenRefMeta, tokenRef.isAcceptableOrUnknown(data['token_ref']!, _tokenRefMeta));
    }
    if (data.containsKey('scopes')) {
      context.handle(_scopesMeta, scopes.isAcceptableOrUnknown(data['scopes']!, _scopesMeta));
    }
    if (data.containsKey('connected_at')) {
      context.handle(_connectedAtMeta, connectedAt.isAcceptableOrUnknown(data['connected_at']!, _connectedAtMeta));
    } else if (isInserting) {
      context.missing(_connectedAtMeta);
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(_lastSyncAtMeta, lastSyncAt.isAcceptableOrUnknown(data['last_sync_at']!, _lastSyncAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {provider};
  @override
  LinkedAccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LinkedAccountRow(
      provider: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      username: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      tokenRef: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}token_ref']),
      scopes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}scopes'])!,
      connectedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}connected_at'])!,
      lastSyncAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}last_sync_at']),
    );
  }

  @override
  $LinkedAccountsTable createAlias(String alias) {
    return $LinkedAccountsTable(attachedDatabase, alias);
  }
}

class LinkedAccountRow extends DataClass implements Insertable<LinkedAccountRow> {
  /// lichess | chesscom
  final String provider;
  final String username;

  /// Key in secure storage (Lichess only). Never the token itself.
  final String? tokenRef;
  final String scopes;
  final DateTime connectedAt;
  final DateTime? lastSyncAt;
  const LinkedAccountRow({
    required this.provider,
    required this.username,
    this.tokenRef,
    required this.scopes,
    required this.connectedAt,
    this.lastSyncAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider'] = Variable<String>(provider);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || tokenRef != null) {
      map['token_ref'] = Variable<String>(tokenRef);
    }
    map['scopes'] = Variable<String>(scopes);
    map['connected_at'] = Variable<DateTime>(connectedAt);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    return map;
  }

  LinkedAccountsCompanion toCompanion(bool nullToAbsent) {
    return LinkedAccountsCompanion(
      provider: Value(provider),
      username: Value(username),
      tokenRef: tokenRef == null && nullToAbsent ? const Value.absent() : Value(tokenRef),
      scopes: Value(scopes),
      connectedAt: Value(connectedAt),
      lastSyncAt: lastSyncAt == null && nullToAbsent ? const Value.absent() : Value(lastSyncAt),
    );
  }

  factory LinkedAccountRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LinkedAccountRow(
      provider: serializer.fromJson<String>(json['provider']),
      username: serializer.fromJson<String>(json['username']),
      tokenRef: serializer.fromJson<String?>(json['tokenRef']),
      scopes: serializer.fromJson<String>(json['scopes']),
      connectedAt: serializer.fromJson<DateTime>(json['connectedAt']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'provider': serializer.toJson<String>(provider),
      'username': serializer.toJson<String>(username),
      'tokenRef': serializer.toJson<String?>(tokenRef),
      'scopes': serializer.toJson<String>(scopes),
      'connectedAt': serializer.toJson<DateTime>(connectedAt),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
    };
  }

  LinkedAccountRow copyWith({
    String? provider,
    String? username,
    Value<String?> tokenRef = const Value.absent(),
    String? scopes,
    DateTime? connectedAt,
    Value<DateTime?> lastSyncAt = const Value.absent(),
  }) => LinkedAccountRow(
    provider: provider ?? this.provider,
    username: username ?? this.username,
    tokenRef: tokenRef.present ? tokenRef.value : this.tokenRef,
    scopes: scopes ?? this.scopes,
    connectedAt: connectedAt ?? this.connectedAt,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
  );
  LinkedAccountRow copyWithCompanion(LinkedAccountsCompanion data) {
    return LinkedAccountRow(
      provider: data.provider.present ? data.provider.value : this.provider,
      username: data.username.present ? data.username.value : this.username,
      tokenRef: data.tokenRef.present ? data.tokenRef.value : this.tokenRef,
      scopes: data.scopes.present ? data.scopes.value : this.scopes,
      connectedAt: data.connectedAt.present ? data.connectedAt.value : this.connectedAt,
      lastSyncAt: data.lastSyncAt.present ? data.lastSyncAt.value : this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LinkedAccountRow(')
          ..write('provider: $provider, ')
          ..write('username: $username, ')
          ..write('tokenRef: $tokenRef, ')
          ..write('scopes: $scopes, ')
          ..write('connectedAt: $connectedAt, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(provider, username, tokenRef, scopes, connectedAt, lastSyncAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LinkedAccountRow &&
          other.provider == this.provider &&
          other.username == this.username &&
          other.tokenRef == this.tokenRef &&
          other.scopes == this.scopes &&
          other.connectedAt == this.connectedAt &&
          other.lastSyncAt == this.lastSyncAt);
}

class LinkedAccountsCompanion extends UpdateCompanion<LinkedAccountRow> {
  final Value<String> provider;
  final Value<String> username;
  final Value<String?> tokenRef;
  final Value<String> scopes;
  final Value<DateTime> connectedAt;
  final Value<DateTime?> lastSyncAt;
  final Value<int> rowid;
  const LinkedAccountsCompanion({
    this.provider = const Value.absent(),
    this.username = const Value.absent(),
    this.tokenRef = const Value.absent(),
    this.scopes = const Value.absent(),
    this.connectedAt = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LinkedAccountsCompanion.insert({
    required String provider,
    required String username,
    this.tokenRef = const Value.absent(),
    this.scopes = const Value.absent(),
    required DateTime connectedAt,
    this.lastSyncAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : provider = Value(provider),
       username = Value(username),
       connectedAt = Value(connectedAt);
  static Insertable<LinkedAccountRow> custom({
    Expression<String>? provider,
    Expression<String>? username,
    Expression<String>? tokenRef,
    Expression<String>? scopes,
    Expression<DateTime>? connectedAt,
    Expression<DateTime>? lastSyncAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (provider != null) 'provider': provider,
      if (username != null) 'username': username,
      if (tokenRef != null) 'token_ref': tokenRef,
      if (scopes != null) 'scopes': scopes,
      if (connectedAt != null) 'connected_at': connectedAt,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LinkedAccountsCompanion copyWith({
    Value<String>? provider,
    Value<String>? username,
    Value<String?>? tokenRef,
    Value<String>? scopes,
    Value<DateTime>? connectedAt,
    Value<DateTime?>? lastSyncAt,
    Value<int>? rowid,
  }) {
    return LinkedAccountsCompanion(
      provider: provider ?? this.provider,
      username: username ?? this.username,
      tokenRef: tokenRef ?? this.tokenRef,
      scopes: scopes ?? this.scopes,
      connectedAt: connectedAt ?? this.connectedAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (tokenRef.present) {
      map['token_ref'] = Variable<String>(tokenRef.value);
    }
    if (scopes.present) {
      map['scopes'] = Variable<String>(scopes.value);
    }
    if (connectedAt.present) {
      map['connected_at'] = Variable<DateTime>(connectedAt.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LinkedAccountsCompanion(')
          ..write('provider: $provider, ')
          ..write('username: $username, ')
          ..write('tokenRef: $tokenRef, ')
          ..write('scopes: $scopes, ')
          ..write('connectedAt: $connectedAt, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportedGamesTable extends ImportedGames with TableInfo<$ImportedGamesTable, ImportedGameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportedGamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta('externalId');
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pgnMeta = const VerificationMeta('pgn');
  @override
  late final GeneratedColumn<String> pgn = GeneratedColumn<String>(
    'pgn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta('playedAt');
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userColorMeta = const VerificationMeta('userColor');
  @override
  late final GeneratedColumn<String> userColor = GeneratedColumn<String>(
    'user_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeControlMeta = const VerificationMeta('timeControl');
  @override
  late final GeneratedColumn<String> timeControl = GeneratedColumn<String>(
    'time_control',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<String> speed = GeneratedColumn<String>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('*'),
  );
  static const VerificationMeta _opponentMeta = const VerificationMeta('opponent');
  @override
  late final GeneratedColumn<String> opponent = GeneratedColumn<String>(
    'opponent',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _ratedMeta = const VerificationMeta('rated');
  @override
  late final GeneratedColumn<bool> rated = GeneratedColumn<bool>(
    'rated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("rated" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _analyzedAtMeta = const VerificationMeta('analyzedAt');
  @override
  late final GeneratedColumn<DateTime> analyzedAt = GeneratedColumn<DateTime>(
    'analyzed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    externalId,
    pgn,
    playedAt,
    userColor,
    timeControl,
    speed,
    result,
    opponent,
    url,
    rated,
    analyzedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'imported_games';
  @override
  VerificationContext validateIntegrity(Insertable<ImportedGameRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta, provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(_externalIdMeta, externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta));
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('pgn')) {
      context.handle(_pgnMeta, pgn.isAcceptableOrUnknown(data['pgn']!, _pgnMeta));
    } else if (isInserting) {
      context.missing(_pgnMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(_playedAtMeta, playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta));
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    if (data.containsKey('user_color')) {
      context.handle(_userColorMeta, userColor.isAcceptableOrUnknown(data['user_color']!, _userColorMeta));
    } else if (isInserting) {
      context.missing(_userColorMeta);
    }
    if (data.containsKey('time_control')) {
      context.handle(_timeControlMeta, timeControl.isAcceptableOrUnknown(data['time_control']!, _timeControlMeta));
    }
    if (data.containsKey('speed')) {
      context.handle(_speedMeta, speed.isAcceptableOrUnknown(data['speed']!, _speedMeta));
    }
    if (data.containsKey('result')) {
      context.handle(_resultMeta, result.isAcceptableOrUnknown(data['result']!, _resultMeta));
    }
    if (data.containsKey('opponent')) {
      context.handle(_opponentMeta, opponent.isAcceptableOrUnknown(data['opponent']!, _opponentMeta));
    }
    if (data.containsKey('url')) {
      context.handle(_urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    }
    if (data.containsKey('rated')) {
      context.handle(_ratedMeta, rated.isAcceptableOrUnknown(data['rated']!, _ratedMeta));
    }
    if (data.containsKey('analyzed_at')) {
      context.handle(_analyzedAtMeta, analyzedAt.isAcceptableOrUnknown(data['analyzed_at']!, _analyzedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {provider, externalId},
  ];
  @override
  ImportedGameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportedGameRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      provider: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      externalId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}external_id'])!,
      pgn: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}pgn'])!,
      playedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}played_at'])!,
      userColor: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}user_color'])!,
      timeControl: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}time_control'])!,
      speed: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}speed'])!,
      result: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}result'])!,
      opponent: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}opponent'])!,
      url: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      rated: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}rated'])!,
      analyzedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}analyzed_at']),
    );
  }

  @override
  $ImportedGamesTable createAlias(String alias) {
    return $ImportedGamesTable(attachedDatabase, alias);
  }
}

class ImportedGameRow extends DataClass implements Insertable<ImportedGameRow> {
  final int id;
  final String provider;
  final String externalId;
  final String pgn;
  final DateTime playedAt;

  /// white | black
  final String userColor;
  final String timeControl;

  /// bullet | blitz | rapid | classical | daily | correspondence
  final String speed;
  final String result;
  final String opponent;
  final String url;
  final bool rated;
  final DateTime? analyzedAt;
  const ImportedGameRow({
    required this.id,
    required this.provider,
    required this.externalId,
    required this.pgn,
    required this.playedAt,
    required this.userColor,
    required this.timeControl,
    required this.speed,
    required this.result,
    required this.opponent,
    required this.url,
    required this.rated,
    this.analyzedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider'] = Variable<String>(provider);
    map['external_id'] = Variable<String>(externalId);
    map['pgn'] = Variable<String>(pgn);
    map['played_at'] = Variable<DateTime>(playedAt);
    map['user_color'] = Variable<String>(userColor);
    map['time_control'] = Variable<String>(timeControl);
    map['speed'] = Variable<String>(speed);
    map['result'] = Variable<String>(result);
    map['opponent'] = Variable<String>(opponent);
    map['url'] = Variable<String>(url);
    map['rated'] = Variable<bool>(rated);
    if (!nullToAbsent || analyzedAt != null) {
      map['analyzed_at'] = Variable<DateTime>(analyzedAt);
    }
    return map;
  }

  ImportedGamesCompanion toCompanion(bool nullToAbsent) {
    return ImportedGamesCompanion(
      id: Value(id),
      provider: Value(provider),
      externalId: Value(externalId),
      pgn: Value(pgn),
      playedAt: Value(playedAt),
      userColor: Value(userColor),
      timeControl: Value(timeControl),
      speed: Value(speed),
      result: Value(result),
      opponent: Value(opponent),
      url: Value(url),
      rated: Value(rated),
      analyzedAt: analyzedAt == null && nullToAbsent ? const Value.absent() : Value(analyzedAt),
    );
  }

  factory ImportedGameRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportedGameRow(
      id: serializer.fromJson<int>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      externalId: serializer.fromJson<String>(json['externalId']),
      pgn: serializer.fromJson<String>(json['pgn']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
      userColor: serializer.fromJson<String>(json['userColor']),
      timeControl: serializer.fromJson<String>(json['timeControl']),
      speed: serializer.fromJson<String>(json['speed']),
      result: serializer.fromJson<String>(json['result']),
      opponent: serializer.fromJson<String>(json['opponent']),
      url: serializer.fromJson<String>(json['url']),
      rated: serializer.fromJson<bool>(json['rated']),
      analyzedAt: serializer.fromJson<DateTime?>(json['analyzedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'provider': serializer.toJson<String>(provider),
      'externalId': serializer.toJson<String>(externalId),
      'pgn': serializer.toJson<String>(pgn),
      'playedAt': serializer.toJson<DateTime>(playedAt),
      'userColor': serializer.toJson<String>(userColor),
      'timeControl': serializer.toJson<String>(timeControl),
      'speed': serializer.toJson<String>(speed),
      'result': serializer.toJson<String>(result),
      'opponent': serializer.toJson<String>(opponent),
      'url': serializer.toJson<String>(url),
      'rated': serializer.toJson<bool>(rated),
      'analyzedAt': serializer.toJson<DateTime?>(analyzedAt),
    };
  }

  ImportedGameRow copyWith({
    int? id,
    String? provider,
    String? externalId,
    String? pgn,
    DateTime? playedAt,
    String? userColor,
    String? timeControl,
    String? speed,
    String? result,
    String? opponent,
    String? url,
    bool? rated,
    Value<DateTime?> analyzedAt = const Value.absent(),
  }) => ImportedGameRow(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    externalId: externalId ?? this.externalId,
    pgn: pgn ?? this.pgn,
    playedAt: playedAt ?? this.playedAt,
    userColor: userColor ?? this.userColor,
    timeControl: timeControl ?? this.timeControl,
    speed: speed ?? this.speed,
    result: result ?? this.result,
    opponent: opponent ?? this.opponent,
    url: url ?? this.url,
    rated: rated ?? this.rated,
    analyzedAt: analyzedAt.present ? analyzedAt.value : this.analyzedAt,
  );
  ImportedGameRow copyWithCompanion(ImportedGamesCompanion data) {
    return ImportedGameRow(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      externalId: data.externalId.present ? data.externalId.value : this.externalId,
      pgn: data.pgn.present ? data.pgn.value : this.pgn,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      userColor: data.userColor.present ? data.userColor.value : this.userColor,
      timeControl: data.timeControl.present ? data.timeControl.value : this.timeControl,
      speed: data.speed.present ? data.speed.value : this.speed,
      result: data.result.present ? data.result.value : this.result,
      opponent: data.opponent.present ? data.opponent.value : this.opponent,
      url: data.url.present ? data.url.value : this.url,
      rated: data.rated.present ? data.rated.value : this.rated,
      analyzedAt: data.analyzedAt.present ? data.analyzedAt.value : this.analyzedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportedGameRow(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('externalId: $externalId, ')
          ..write('pgn: $pgn, ')
          ..write('playedAt: $playedAt, ')
          ..write('userColor: $userColor, ')
          ..write('timeControl: $timeControl, ')
          ..write('speed: $speed, ')
          ..write('result: $result, ')
          ..write('opponent: $opponent, ')
          ..write('url: $url, ')
          ..write('rated: $rated, ')
          ..write('analyzedAt: $analyzedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    externalId,
    pgn,
    playedAt,
    userColor,
    timeControl,
    speed,
    result,
    opponent,
    url,
    rated,
    analyzedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportedGameRow &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.externalId == this.externalId &&
          other.pgn == this.pgn &&
          other.playedAt == this.playedAt &&
          other.userColor == this.userColor &&
          other.timeControl == this.timeControl &&
          other.speed == this.speed &&
          other.result == this.result &&
          other.opponent == this.opponent &&
          other.url == this.url &&
          other.rated == this.rated &&
          other.analyzedAt == this.analyzedAt);
}

class ImportedGamesCompanion extends UpdateCompanion<ImportedGameRow> {
  final Value<int> id;
  final Value<String> provider;
  final Value<String> externalId;
  final Value<String> pgn;
  final Value<DateTime> playedAt;
  final Value<String> userColor;
  final Value<String> timeControl;
  final Value<String> speed;
  final Value<String> result;
  final Value<String> opponent;
  final Value<String> url;
  final Value<bool> rated;
  final Value<DateTime?> analyzedAt;
  const ImportedGamesCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.externalId = const Value.absent(),
    this.pgn = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.userColor = const Value.absent(),
    this.timeControl = const Value.absent(),
    this.speed = const Value.absent(),
    this.result = const Value.absent(),
    this.opponent = const Value.absent(),
    this.url = const Value.absent(),
    this.rated = const Value.absent(),
    this.analyzedAt = const Value.absent(),
  });
  ImportedGamesCompanion.insert({
    this.id = const Value.absent(),
    required String provider,
    required String externalId,
    required String pgn,
    required DateTime playedAt,
    required String userColor,
    this.timeControl = const Value.absent(),
    this.speed = const Value.absent(),
    this.result = const Value.absent(),
    this.opponent = const Value.absent(),
    this.url = const Value.absent(),
    this.rated = const Value.absent(),
    this.analyzedAt = const Value.absent(),
  }) : provider = Value(provider),
       externalId = Value(externalId),
       pgn = Value(pgn),
       playedAt = Value(playedAt),
       userColor = Value(userColor);
  static Insertable<ImportedGameRow> custom({
    Expression<int>? id,
    Expression<String>? provider,
    Expression<String>? externalId,
    Expression<String>? pgn,
    Expression<DateTime>? playedAt,
    Expression<String>? userColor,
    Expression<String>? timeControl,
    Expression<String>? speed,
    Expression<String>? result,
    Expression<String>? opponent,
    Expression<String>? url,
    Expression<bool>? rated,
    Expression<DateTime>? analyzedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (externalId != null) 'external_id': externalId,
      if (pgn != null) 'pgn': pgn,
      if (playedAt != null) 'played_at': playedAt,
      if (userColor != null) 'user_color': userColor,
      if (timeControl != null) 'time_control': timeControl,
      if (speed != null) 'speed': speed,
      if (result != null) 'result': result,
      if (opponent != null) 'opponent': opponent,
      if (url != null) 'url': url,
      if (rated != null) 'rated': rated,
      if (analyzedAt != null) 'analyzed_at': analyzedAt,
    });
  }

  ImportedGamesCompanion copyWith({
    Value<int>? id,
    Value<String>? provider,
    Value<String>? externalId,
    Value<String>? pgn,
    Value<DateTime>? playedAt,
    Value<String>? userColor,
    Value<String>? timeControl,
    Value<String>? speed,
    Value<String>? result,
    Value<String>? opponent,
    Value<String>? url,
    Value<bool>? rated,
    Value<DateTime?>? analyzedAt,
  }) {
    return ImportedGamesCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      externalId: externalId ?? this.externalId,
      pgn: pgn ?? this.pgn,
      playedAt: playedAt ?? this.playedAt,
      userColor: userColor ?? this.userColor,
      timeControl: timeControl ?? this.timeControl,
      speed: speed ?? this.speed,
      result: result ?? this.result,
      opponent: opponent ?? this.opponent,
      url: url ?? this.url,
      rated: rated ?? this.rated,
      analyzedAt: analyzedAt ?? this.analyzedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (pgn.present) {
      map['pgn'] = Variable<String>(pgn.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    if (userColor.present) {
      map['user_color'] = Variable<String>(userColor.value);
    }
    if (timeControl.present) {
      map['time_control'] = Variable<String>(timeControl.value);
    }
    if (speed.present) {
      map['speed'] = Variable<String>(speed.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (opponent.present) {
      map['opponent'] = Variable<String>(opponent.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (rated.present) {
      map['rated'] = Variable<bool>(rated.value);
    }
    if (analyzedAt.present) {
      map['analyzed_at'] = Variable<DateTime>(analyzedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportedGamesCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('externalId: $externalId, ')
          ..write('pgn: $pgn, ')
          ..write('playedAt: $playedAt, ')
          ..write('userColor: $userColor, ')
          ..write('timeControl: $timeControl, ')
          ..write('speed: $speed, ')
          ..write('result: $result, ')
          ..write('opponent: $opponent, ')
          ..write('url: $url, ')
          ..write('rated: $rated, ')
          ..write('analyzedAt: $analyzedAt')
          ..write(')'))
        .toString();
  }
}

class $GapEventsTable extends GapEvents with TableInfo<$GapEventsTable, GapEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GapEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _importedGameIdMeta = const VerificationMeta('importedGameId');
  @override
  late final GeneratedColumn<int> importedGameId = GeneratedColumn<int>(
    'imported_game_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES imported_games (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _repertoireIdMeta = const VerificationMeta('repertoireId');
  @override
  late final GeneratedColumn<int> repertoireId = GeneratedColumn<int>(
    'repertoire_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES repertoires (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionKeyMeta = const VerificationMeta('positionKey');
  @override
  late final GeneratedColumn<String> positionKey = GeneratedColumn<String>(
    'position_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fenMeta = const VerificationMeta('fen');
  @override
  late final GeneratedColumn<String> fen = GeneratedColumn<String>(
    'fen',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plyMeta = const VerificationMeta('ply');
  @override
  late final GeneratedColumn<int> ply = GeneratedColumn<int>(
    'ply',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedSanMeta = const VerificationMeta('playedSan');
  @override
  late final GeneratedColumn<String> playedSan = GeneratedColumn<String>(
    'played_san',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _playedUciMeta = const VerificationMeta('playedUci');
  @override
  late final GeneratedColumn<String> playedUci = GeneratedColumn<String>(
    'played_uci',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _expectedSanMeta = const VerificationMeta('expectedSan');
  @override
  late final GeneratedColumn<String> expectedSan = GeneratedColumn<String>(
    'expected_san',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dismissedMeta = const VerificationMeta('dismissed');
  @override
  late final GeneratedColumn<bool> dismissed = GeneratedColumn<bool>(
    'dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("dismissed" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    importedGameId,
    repertoireId,
    type,
    positionKey,
    fen,
    ply,
    playedSan,
    playedUci,
    expectedSan,
    dismissed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gap_events';
  @override
  VerificationContext validateIntegrity(Insertable<GapEventRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('imported_game_id')) {
      context.handle(
        _importedGameIdMeta,
        importedGameId.isAcceptableOrUnknown(data['imported_game_id']!, _importedGameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_importedGameIdMeta);
    }
    if (data.containsKey('repertoire_id')) {
      context.handle(_repertoireIdMeta, repertoireId.isAcceptableOrUnknown(data['repertoire_id']!, _repertoireIdMeta));
    } else if (isInserting) {
      context.missing(_repertoireIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(_typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('position_key')) {
      context.handle(_positionKeyMeta, positionKey.isAcceptableOrUnknown(data['position_key']!, _positionKeyMeta));
    } else if (isInserting) {
      context.missing(_positionKeyMeta);
    }
    if (data.containsKey('fen')) {
      context.handle(_fenMeta, fen.isAcceptableOrUnknown(data['fen']!, _fenMeta));
    } else if (isInserting) {
      context.missing(_fenMeta);
    }
    if (data.containsKey('ply')) {
      context.handle(_plyMeta, ply.isAcceptableOrUnknown(data['ply']!, _plyMeta));
    } else if (isInserting) {
      context.missing(_plyMeta);
    }
    if (data.containsKey('played_san')) {
      context.handle(_playedSanMeta, playedSan.isAcceptableOrUnknown(data['played_san']!, _playedSanMeta));
    }
    if (data.containsKey('played_uci')) {
      context.handle(_playedUciMeta, playedUci.isAcceptableOrUnknown(data['played_uci']!, _playedUciMeta));
    }
    if (data.containsKey('expected_san')) {
      context.handle(_expectedSanMeta, expectedSan.isAcceptableOrUnknown(data['expected_san']!, _expectedSanMeta));
    }
    if (data.containsKey('dismissed')) {
      context.handle(_dismissedMeta, dismissed.isAcceptableOrUnknown(data['dismissed']!, _dismissedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GapEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GapEventRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      importedGameId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}imported_game_id'])!,
      repertoireId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}repertoire_id'])!,
      type: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      positionKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}position_key'])!,
      fen: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fen'])!,
      ply: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}ply'])!,
      playedSan: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}played_san'])!,
      playedUci: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}played_uci'])!,
      expectedSan: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}expected_san'])!,
      dismissed: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}dismissed'])!,
    );
  }

  @override
  $GapEventsTable createAlias(String alias) {
    return $GapEventsTable(attachedDatabase, alias);
  }
}

class GapEventRow extends DataClass implements Insertable<GapEventRow> {
  final int id;
  final int importedGameId;
  final int repertoireId;

  /// userDeviation | opponentNovelty | endOfBook
  final String type;
  final String positionKey;
  final String fen;
  final int ply;
  final String playedSan;
  final String playedUci;
  final String expectedSan;
  final bool dismissed;
  const GapEventRow({
    required this.id,
    required this.importedGameId,
    required this.repertoireId,
    required this.type,
    required this.positionKey,
    required this.fen,
    required this.ply,
    required this.playedSan,
    required this.playedUci,
    required this.expectedSan,
    required this.dismissed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['imported_game_id'] = Variable<int>(importedGameId);
    map['repertoire_id'] = Variable<int>(repertoireId);
    map['type'] = Variable<String>(type);
    map['position_key'] = Variable<String>(positionKey);
    map['fen'] = Variable<String>(fen);
    map['ply'] = Variable<int>(ply);
    map['played_san'] = Variable<String>(playedSan);
    map['played_uci'] = Variable<String>(playedUci);
    map['expected_san'] = Variable<String>(expectedSan);
    map['dismissed'] = Variable<bool>(dismissed);
    return map;
  }

  GapEventsCompanion toCompanion(bool nullToAbsent) {
    return GapEventsCompanion(
      id: Value(id),
      importedGameId: Value(importedGameId),
      repertoireId: Value(repertoireId),
      type: Value(type),
      positionKey: Value(positionKey),
      fen: Value(fen),
      ply: Value(ply),
      playedSan: Value(playedSan),
      playedUci: Value(playedUci),
      expectedSan: Value(expectedSan),
      dismissed: Value(dismissed),
    );
  }

  factory GapEventRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GapEventRow(
      id: serializer.fromJson<int>(json['id']),
      importedGameId: serializer.fromJson<int>(json['importedGameId']),
      repertoireId: serializer.fromJson<int>(json['repertoireId']),
      type: serializer.fromJson<String>(json['type']),
      positionKey: serializer.fromJson<String>(json['positionKey']),
      fen: serializer.fromJson<String>(json['fen']),
      ply: serializer.fromJson<int>(json['ply']),
      playedSan: serializer.fromJson<String>(json['playedSan']),
      playedUci: serializer.fromJson<String>(json['playedUci']),
      expectedSan: serializer.fromJson<String>(json['expectedSan']),
      dismissed: serializer.fromJson<bool>(json['dismissed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'importedGameId': serializer.toJson<int>(importedGameId),
      'repertoireId': serializer.toJson<int>(repertoireId),
      'type': serializer.toJson<String>(type),
      'positionKey': serializer.toJson<String>(positionKey),
      'fen': serializer.toJson<String>(fen),
      'ply': serializer.toJson<int>(ply),
      'playedSan': serializer.toJson<String>(playedSan),
      'playedUci': serializer.toJson<String>(playedUci),
      'expectedSan': serializer.toJson<String>(expectedSan),
      'dismissed': serializer.toJson<bool>(dismissed),
    };
  }

  GapEventRow copyWith({
    int? id,
    int? importedGameId,
    int? repertoireId,
    String? type,
    String? positionKey,
    String? fen,
    int? ply,
    String? playedSan,
    String? playedUci,
    String? expectedSan,
    bool? dismissed,
  }) => GapEventRow(
    id: id ?? this.id,
    importedGameId: importedGameId ?? this.importedGameId,
    repertoireId: repertoireId ?? this.repertoireId,
    type: type ?? this.type,
    positionKey: positionKey ?? this.positionKey,
    fen: fen ?? this.fen,
    ply: ply ?? this.ply,
    playedSan: playedSan ?? this.playedSan,
    playedUci: playedUci ?? this.playedUci,
    expectedSan: expectedSan ?? this.expectedSan,
    dismissed: dismissed ?? this.dismissed,
  );
  GapEventRow copyWithCompanion(GapEventsCompanion data) {
    return GapEventRow(
      id: data.id.present ? data.id.value : this.id,
      importedGameId: data.importedGameId.present ? data.importedGameId.value : this.importedGameId,
      repertoireId: data.repertoireId.present ? data.repertoireId.value : this.repertoireId,
      type: data.type.present ? data.type.value : this.type,
      positionKey: data.positionKey.present ? data.positionKey.value : this.positionKey,
      fen: data.fen.present ? data.fen.value : this.fen,
      ply: data.ply.present ? data.ply.value : this.ply,
      playedSan: data.playedSan.present ? data.playedSan.value : this.playedSan,
      playedUci: data.playedUci.present ? data.playedUci.value : this.playedUci,
      expectedSan: data.expectedSan.present ? data.expectedSan.value : this.expectedSan,
      dismissed: data.dismissed.present ? data.dismissed.value : this.dismissed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GapEventRow(')
          ..write('id: $id, ')
          ..write('importedGameId: $importedGameId, ')
          ..write('repertoireId: $repertoireId, ')
          ..write('type: $type, ')
          ..write('positionKey: $positionKey, ')
          ..write('fen: $fen, ')
          ..write('ply: $ply, ')
          ..write('playedSan: $playedSan, ')
          ..write('playedUci: $playedUci, ')
          ..write('expectedSan: $expectedSan, ')
          ..write('dismissed: $dismissed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    importedGameId,
    repertoireId,
    type,
    positionKey,
    fen,
    ply,
    playedSan,
    playedUci,
    expectedSan,
    dismissed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GapEventRow &&
          other.id == this.id &&
          other.importedGameId == this.importedGameId &&
          other.repertoireId == this.repertoireId &&
          other.type == this.type &&
          other.positionKey == this.positionKey &&
          other.fen == this.fen &&
          other.ply == this.ply &&
          other.playedSan == this.playedSan &&
          other.playedUci == this.playedUci &&
          other.expectedSan == this.expectedSan &&
          other.dismissed == this.dismissed);
}

class GapEventsCompanion extends UpdateCompanion<GapEventRow> {
  final Value<int> id;
  final Value<int> importedGameId;
  final Value<int> repertoireId;
  final Value<String> type;
  final Value<String> positionKey;
  final Value<String> fen;
  final Value<int> ply;
  final Value<String> playedSan;
  final Value<String> playedUci;
  final Value<String> expectedSan;
  final Value<bool> dismissed;
  const GapEventsCompanion({
    this.id = const Value.absent(),
    this.importedGameId = const Value.absent(),
    this.repertoireId = const Value.absent(),
    this.type = const Value.absent(),
    this.positionKey = const Value.absent(),
    this.fen = const Value.absent(),
    this.ply = const Value.absent(),
    this.playedSan = const Value.absent(),
    this.playedUci = const Value.absent(),
    this.expectedSan = const Value.absent(),
    this.dismissed = const Value.absent(),
  });
  GapEventsCompanion.insert({
    this.id = const Value.absent(),
    required int importedGameId,
    required int repertoireId,
    required String type,
    required String positionKey,
    required String fen,
    required int ply,
    this.playedSan = const Value.absent(),
    this.playedUci = const Value.absent(),
    this.expectedSan = const Value.absent(),
    this.dismissed = const Value.absent(),
  }) : importedGameId = Value(importedGameId),
       repertoireId = Value(repertoireId),
       type = Value(type),
       positionKey = Value(positionKey),
       fen = Value(fen),
       ply = Value(ply);
  static Insertable<GapEventRow> custom({
    Expression<int>? id,
    Expression<int>? importedGameId,
    Expression<int>? repertoireId,
    Expression<String>? type,
    Expression<String>? positionKey,
    Expression<String>? fen,
    Expression<int>? ply,
    Expression<String>? playedSan,
    Expression<String>? playedUci,
    Expression<String>? expectedSan,
    Expression<bool>? dismissed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (importedGameId != null) 'imported_game_id': importedGameId,
      if (repertoireId != null) 'repertoire_id': repertoireId,
      if (type != null) 'type': type,
      if (positionKey != null) 'position_key': positionKey,
      if (fen != null) 'fen': fen,
      if (ply != null) 'ply': ply,
      if (playedSan != null) 'played_san': playedSan,
      if (playedUci != null) 'played_uci': playedUci,
      if (expectedSan != null) 'expected_san': expectedSan,
      if (dismissed != null) 'dismissed': dismissed,
    });
  }

  GapEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? importedGameId,
    Value<int>? repertoireId,
    Value<String>? type,
    Value<String>? positionKey,
    Value<String>? fen,
    Value<int>? ply,
    Value<String>? playedSan,
    Value<String>? playedUci,
    Value<String>? expectedSan,
    Value<bool>? dismissed,
  }) {
    return GapEventsCompanion(
      id: id ?? this.id,
      importedGameId: importedGameId ?? this.importedGameId,
      repertoireId: repertoireId ?? this.repertoireId,
      type: type ?? this.type,
      positionKey: positionKey ?? this.positionKey,
      fen: fen ?? this.fen,
      ply: ply ?? this.ply,
      playedSan: playedSan ?? this.playedSan,
      playedUci: playedUci ?? this.playedUci,
      expectedSan: expectedSan ?? this.expectedSan,
      dismissed: dismissed ?? this.dismissed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (importedGameId.present) {
      map['imported_game_id'] = Variable<int>(importedGameId.value);
    }
    if (repertoireId.present) {
      map['repertoire_id'] = Variable<int>(repertoireId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (positionKey.present) {
      map['position_key'] = Variable<String>(positionKey.value);
    }
    if (fen.present) {
      map['fen'] = Variable<String>(fen.value);
    }
    if (ply.present) {
      map['ply'] = Variable<int>(ply.value);
    }
    if (playedSan.present) {
      map['played_san'] = Variable<String>(playedSan.value);
    }
    if (playedUci.present) {
      map['played_uci'] = Variable<String>(playedUci.value);
    }
    if (expectedSan.present) {
      map['expected_san'] = Variable<String>(expectedSan.value);
    }
    if (dismissed.present) {
      map['dismissed'] = Variable<bool>(dismissed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GapEventsCompanion(')
          ..write('id: $id, ')
          ..write('importedGameId: $importedGameId, ')
          ..write('repertoireId: $repertoireId, ')
          ..write('type: $type, ')
          ..write('positionKey: $positionKey, ')
          ..write('fen: $fen, ')
          ..write('ply: $ply, ')
          ..write('playedSan: $playedSan, ')
          ..write('playedUci: $playedUci, ')
          ..write('expectedSan: $expectedSan, ')
          ..write('dismissed: $dismissed')
          ..write(')'))
        .toString();
  }
}

class $ExplorerCacheTable extends ExplorerCache with TableInfo<$ExplorerCacheTable, ExplorerCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExplorerCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta('cacheKey');
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cacheKey, json, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'explorer_cache';
  @override
  VerificationContext validateIntegrity(Insertable<ExplorerCacheRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(_cacheKeyMeta, cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta));
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(_jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta, fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  ExplorerCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExplorerCacheRow(
      cacheKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}cache_key'])!,
      json: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      fetchedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $ExplorerCacheTable createAlias(String alias) {
    return $ExplorerCacheTable(attachedDatabase, alias);
  }
}

class ExplorerCacheRow extends DataClass implements Insertable<ExplorerCacheRow> {
  final String cacheKey;
  final String json;
  final DateTime fetchedAt;
  const ExplorerCacheRow({required this.cacheKey, required this.json, required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['json'] = Variable<String>(json);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  ExplorerCacheCompanion toCompanion(bool nullToAbsent) {
    return ExplorerCacheCompanion(cacheKey: Value(cacheKey), json: Value(json), fetchedAt: Value(fetchedAt));
  }

  factory ExplorerCacheRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExplorerCacheRow(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      json: serializer.fromJson<String>(json['json']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'json': serializer.toJson<String>(json),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  ExplorerCacheRow copyWith({String? cacheKey, String? json, DateTime? fetchedAt}) => ExplorerCacheRow(
    cacheKey: cacheKey ?? this.cacheKey,
    json: json ?? this.json,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  ExplorerCacheRow copyWithCompanion(ExplorerCacheCompanion data) {
    return ExplorerCacheRow(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      json: data.json.present ? data.json.value : this.json,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExplorerCacheRow(')
          ..write('cacheKey: $cacheKey, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, json, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExplorerCacheRow &&
          other.cacheKey == this.cacheKey &&
          other.json == this.json &&
          other.fetchedAt == this.fetchedAt);
}

class ExplorerCacheCompanion extends UpdateCompanion<ExplorerCacheRow> {
  final Value<String> cacheKey;
  final Value<String> json;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const ExplorerCacheCompanion({
    this.cacheKey = const Value.absent(),
    this.json = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExplorerCacheCompanion.insert({
    required String cacheKey,
    required String json,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       json = Value(json),
       fetchedAt = Value(fetchedAt);
  static Insertable<ExplorerCacheRow> custom({
    Expression<String>? cacheKey,
    Expression<String>? json,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (json != null) 'json': json,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExplorerCacheCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? json,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return ExplorerCacheCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      json: json ?? this.json,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExplorerCacheCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HttpCacheTable extends HttpCache with TableInfo<$HttpCacheTable, HttpCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HttpCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<String> lastModified = GeneratedColumn<String>(
    'last_modified',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [url, etag, lastModified, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'http_cache';
  @override
  VerificationContext validateIntegrity(Insertable<HttpCacheRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('url')) {
      context.handle(_urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(_etagMeta, etag.isAcceptableOrUnknown(data['etag']!, _etagMeta));
    }
    if (data.containsKey('last_modified')) {
      context.handle(_lastModifiedMeta, lastModified.isAcceptableOrUnknown(data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta, fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {url};
  @override
  HttpCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HttpCacheRow(
      url: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      etag: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}etag']),
      lastModified: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}last_modified']),
      fetchedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $HttpCacheTable createAlias(String alias) {
    return $HttpCacheTable(attachedDatabase, alias);
  }
}

class HttpCacheRow extends DataClass implements Insertable<HttpCacheRow> {
  final String url;
  final String? etag;
  final String? lastModified;
  final DateTime fetchedAt;
  const HttpCacheRow({required this.url, this.etag, this.lastModified, required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<String>(lastModified);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  HttpCacheCompanion toCompanion(bool nullToAbsent) {
    return HttpCacheCompanion(
      url: Value(url),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastModified: lastModified == null && nullToAbsent ? const Value.absent() : Value(lastModified),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory HttpCacheRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HttpCacheRow(
      url: serializer.fromJson<String>(json['url']),
      etag: serializer.fromJson<String?>(json['etag']),
      lastModified: serializer.fromJson<String?>(json['lastModified']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'url': serializer.toJson<String>(url),
      'etag': serializer.toJson<String?>(etag),
      'lastModified': serializer.toJson<String?>(lastModified),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  HttpCacheRow copyWith({
    String? url,
    Value<String?> etag = const Value.absent(),
    Value<String?> lastModified = const Value.absent(),
    DateTime? fetchedAt,
  }) => HttpCacheRow(
    url: url ?? this.url,
    etag: etag.present ? etag.value : this.etag,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  HttpCacheRow copyWithCompanion(HttpCacheCompanion data) {
    return HttpCacheRow(
      url: data.url.present ? data.url.value : this.url,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastModified: data.lastModified.present ? data.lastModified.value : this.lastModified,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HttpCacheRow(')
          ..write('url: $url, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(url, etag, lastModified, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HttpCacheRow &&
          other.url == this.url &&
          other.etag == this.etag &&
          other.lastModified == this.lastModified &&
          other.fetchedAt == this.fetchedAt);
}

class HttpCacheCompanion extends UpdateCompanion<HttpCacheRow> {
  final Value<String> url;
  final Value<String?> etag;
  final Value<String?> lastModified;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const HttpCacheCompanion({
    this.url = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HttpCacheCompanion.insert({
    required String url,
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : url = Value(url),
       fetchedAt = Value(fetchedAt);
  static Insertable<HttpCacheRow> custom({
    Expression<String>? url,
    Expression<String>? etag,
    Expression<String>? lastModified,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (url != null) 'url': url,
      if (etag != null) 'etag': etag,
      if (lastModified != null) 'last_modified': lastModified,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HttpCacheCompanion copyWith({
    Value<String>? url,
    Value<String?>? etag,
    Value<String?>? lastModified,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return HttpCacheCompanion(
      url: url ?? this.url,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<String>(lastModified.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HttpCacheCompanion(')
          ..write('url: $url, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<SettingRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(key: serializer.fromJson<String>(json['key']), value: serializer.fromJson<String>(json['value']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'key': serializer.toJson<String>(key), 'value': serializer.toJson<String>(value)};
  }

  SettingRow copyWith({String? key, String? value}) => SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SettingRow && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({required String key, required String value, this.rowid = const Value.absent()})
    : key = Value(key),
      value = Value(value);
  static Insertable<SettingRow> custom({Expression<String>? key, Expression<String>? value, Expression<int>? rowid}) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(key: key ?? this.key, value: value ?? this.value, rowid: rowid ?? this.rowid);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CollectionsTable collections = $CollectionsTable(this);
  late final $GamesTable games = $GamesTable(this);
  late final $RepertoiresTable repertoires = $RepertoiresTable(this);
  late final $RepPositionsTable repPositions = $RepPositionsTable(this);
  late final $RepMovesTable repMoves = $RepMovesTable(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $ReviewLogsTable reviewLogs = $ReviewLogsTable(this);
  late final $LinkedAccountsTable linkedAccounts = $LinkedAccountsTable(this);
  late final $ImportedGamesTable importedGames = $ImportedGamesTable(this);
  late final $GapEventsTable gapEvents = $GapEventsTable(this);
  late final $ExplorerCacheTable explorerCache = $ExplorerCacheTable(this);
  late final $HttpCacheTable httpCache = $HttpCacheTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    collections,
    games,
    repertoires,
    repPositions,
    repMoves,
    cards,
    reviewLogs,
    linkedAccounts,
    importedGames,
    gapEvents,
    explorerCache,
    httpCache,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('collections', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('games', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('repertoires', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('rep_positions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('repertoires', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('rep_moves', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('repertoires', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('cards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('repertoires', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('review_logs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('imported_games', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('gap_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('repertoires', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('gap_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CollectionsTableCreateCompanionBuilder = CollectionsCompanion Function({
  Value<int> id,
  required String name,
  Value<String> source,
  Value<String?> sourceRef,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$CollectionsTableUpdateCompanionBuilder = CollectionsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> source,
  Value<String?> sourceRef,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$CollectionsTableReferences extends BaseReferences<_$AppDatabase, $CollectionsTable, CollectionRow> {
  $$CollectionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GamesTable, List<GameRow>> _gamesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.games, aliasName: 'collections__id__games__collection_id');

  $$GamesTableProcessedTableManager get gamesRefs {
    final manager = $$GamesTableTableManager(
      $_db,
      $_db.games,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gamesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CollectionsTableFilterComposer extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> gamesRefs(Expression<bool> Function($$GamesTableFilterComposer f) f) {
    final $$GamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.collectionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$GamesTableFilterComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionsTableOrderingComposer extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CollectionsTableAnnotationComposer extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get source => $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceRef => $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> gamesRefs<T extends Object>(Expression<T> Function($$GamesTableAnnotationComposer a) f) {
    final $$GamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.collectionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$GamesTableAnnotationComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionsTable,
          CollectionRow,
          $$CollectionsTableFilterComposer,
          $$CollectionsTableOrderingComposer,
          $$CollectionsTableAnnotationComposer,
          $$CollectionsTableCreateCompanionBuilder,
          $$CollectionsTableUpdateCompanionBuilder,
          (CollectionRow, $$CollectionsTableReferences),
          CollectionRow,
          PrefetchHooks Function({bool gamesRefs})
        > {
  $$CollectionsTableTableManager(_$AppDatabase db, $CollectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CollectionsCompanion(
                id: id,
                name: name,
                source: source,
                sourceRef: sourceRef,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> source = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => CollectionsCompanion.insert(
                id: id,
                name: name,
                source: source,
                sourceRef: sourceRef,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable<$CollectionsTable, CollectionRow>(table), $$CollectionsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({gamesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (gamesRefs) db.games],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (gamesRefs)
                    await $_getPrefetchedData<CollectionRow, $CollectionsTable, GameRow>(
                      currentTable: table,
                      referencedTable: $$CollectionsTableReferences._gamesRefsTable(db),
                      managerFromTypedResult: (p0) => $$CollectionsTableReferences(db, table, p0).gamesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.collectionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionsTable,
      CollectionRow,
      $$CollectionsTableFilterComposer,
      $$CollectionsTableOrderingComposer,
      $$CollectionsTableAnnotationComposer,
      $$CollectionsTableCreateCompanionBuilder,
      $$CollectionsTableUpdateCompanionBuilder,
      (CollectionRow, $$CollectionsTableReferences),
      CollectionRow,
      PrefetchHooks Function({bool gamesRefs})
    >;
typedef $$GamesTableCreateCompanionBuilder = GamesCompanion Function({
  Value<int> id,
  required int collectionId,
  Value<int> orderIdx,
  required String pgn,
  Value<String> headersJson,
  Value<String> white,
  Value<String> black,
  Value<String> event,
  Value<String> date,
  Value<String> result,
  Value<String> eco,
  Value<String> opening,
  Value<String?> rootFen,
  Value<int> plyCount,
  Value<String> issuesJson,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$GamesTableUpdateCompanionBuilder = GamesCompanion Function({
  Value<int> id,
  Value<int> collectionId,
  Value<int> orderIdx,
  Value<String> pgn,
  Value<String> headersJson,
  Value<String> white,
  Value<String> black,
  Value<String> event,
  Value<String> date,
  Value<String> result,
  Value<String> eco,
  Value<String> opening,
  Value<String?> rootFen,
  Value<int> plyCount,
  Value<String> issuesJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$GamesTableReferences extends BaseReferences<_$AppDatabase, $GamesTable, GameRow> {
  $$GamesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CollectionsTable _collectionIdTable(_$AppDatabase db) =>
      db.collections.createAlias('games__collection_id__collections__id');

  $$CollectionsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<int>('collection_id')!;

    final manager = $$CollectionsTableTableManager($_db, $_db.collections).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$GamesTableFilterComposer extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderIdx =>
      $composableBuilder(column: $table.orderIdx, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pgn => $composableBuilder(column: $table.pgn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get headersJson =>
      $composableBuilder(column: $table.headersJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get white =>
      $composableBuilder(column: $table.white, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get black =>
      $composableBuilder(column: $table.black, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get event =>
      $composableBuilder(column: $table.event, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eco => $composableBuilder(column: $table.eco, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get opening =>
      $composableBuilder(column: $table.opening, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rootFen =>
      $composableBuilder(column: $table.rootFen, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get plyCount =>
      $composableBuilder(column: $table.plyCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get issuesJson =>
      $composableBuilder(column: $table.issuesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$CollectionsTableFilterComposer get collectionId {
    final $$CollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CollectionsTableFilterComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GamesTableOrderingComposer extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderIdx =>
      $composableBuilder(column: $table.orderIdx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pgn =>
      $composableBuilder(column: $table.pgn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get headersJson =>
      $composableBuilder(column: $table.headersJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get white =>
      $composableBuilder(column: $table.white, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get black =>
      $composableBuilder(column: $table.black, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get event =>
      $composableBuilder(column: $table.event, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eco =>
      $composableBuilder(column: $table.eco, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get opening =>
      $composableBuilder(column: $table.opening, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rootFen =>
      $composableBuilder(column: $table.rootFen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get plyCount =>
      $composableBuilder(column: $table.plyCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get issuesJson =>
      $composableBuilder(column: $table.issuesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$CollectionsTableOrderingComposer get collectionId {
    final $$CollectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CollectionsTableOrderingComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GamesTableAnnotationComposer extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orderIdx => $composableBuilder(column: $table.orderIdx, builder: (column) => column);

  GeneratedColumn<String> get pgn => $composableBuilder(column: $table.pgn, builder: (column) => column);

  GeneratedColumn<String> get headersJson =>
      $composableBuilder(column: $table.headersJson, builder: (column) => column);

  GeneratedColumn<String> get white => $composableBuilder(column: $table.white, builder: (column) => column);

  GeneratedColumn<String> get black => $composableBuilder(column: $table.black, builder: (column) => column);

  GeneratedColumn<String> get event => $composableBuilder(column: $table.event, builder: (column) => column);

  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get result => $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get eco => $composableBuilder(column: $table.eco, builder: (column) => column);

  GeneratedColumn<String> get opening => $composableBuilder(column: $table.opening, builder: (column) => column);

  GeneratedColumn<String> get rootFen => $composableBuilder(column: $table.rootFen, builder: (column) => column);

  GeneratedColumn<int> get plyCount => $composableBuilder(column: $table.plyCount, builder: (column) => column);

  GeneratedColumn<String> get issuesJson => $composableBuilder(column: $table.issuesJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CollectionsTableAnnotationComposer get collectionId {
    final $$CollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamesTable,
          GameRow,
          $$GamesTableFilterComposer,
          $$GamesTableOrderingComposer,
          $$GamesTableAnnotationComposer,
          $$GamesTableCreateCompanionBuilder,
          $$GamesTableUpdateCompanionBuilder,
          (GameRow, $$GamesTableReferences),
          GameRow,
          PrefetchHooks Function({bool collectionId})
        > {
  $$GamesTableTableManager(_$AppDatabase db, $GamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$GamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$GamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$GamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> collectionId = const Value.absent(),
                Value<int> orderIdx = const Value.absent(),
                Value<String> pgn = const Value.absent(),
                Value<String> headersJson = const Value.absent(),
                Value<String> white = const Value.absent(),
                Value<String> black = const Value.absent(),
                Value<String> event = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String> eco = const Value.absent(),
                Value<String> opening = const Value.absent(),
                Value<String?> rootFen = const Value.absent(),
                Value<int> plyCount = const Value.absent(),
                Value<String> issuesJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GamesCompanion(
                id: id,
                collectionId: collectionId,
                orderIdx: orderIdx,
                pgn: pgn,
                headersJson: headersJson,
                white: white,
                black: black,
                event: event,
                date: date,
                result: result,
                eco: eco,
                opening: opening,
                rootFen: rootFen,
                plyCount: plyCount,
                issuesJson: issuesJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int collectionId,
                Value<int> orderIdx = const Value.absent(),
                required String pgn,
                Value<String> headersJson = const Value.absent(),
                Value<String> white = const Value.absent(),
                Value<String> black = const Value.absent(),
                Value<String> event = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String> eco = const Value.absent(),
                Value<String> opening = const Value.absent(),
                Value<String?> rootFen = const Value.absent(),
                Value<int> plyCount = const Value.absent(),
                Value<String> issuesJson = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => GamesCompanion.insert(
                id: id,
                collectionId: collectionId,
                orderIdx: orderIdx,
                pgn: pgn,
                headersJson: headersJson,
                white: white,
                black: black,
                event: event,
                date: date,
                result: result,
                eco: eco,
                opening: opening,
                rootFen: rootFen,
                plyCount: plyCount,
                issuesJson: issuesJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<$GamesTable, GameRow>(table), $$GamesTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({collectionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (collectionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.collectionId,
                        referencedTable: $$GamesTableReferences._collectionIdTable(db),
                        referencedColumn: $$GamesTableReferences._collectionIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamesTable,
      GameRow,
      $$GamesTableFilterComposer,
      $$GamesTableOrderingComposer,
      $$GamesTableAnnotationComposer,
      $$GamesTableCreateCompanionBuilder,
      $$GamesTableUpdateCompanionBuilder,
      (GameRow, $$GamesTableReferences),
      GameRow,
      PrefetchHooks Function({bool collectionId})
    >;
typedef $$RepertoiresTableCreateCompanionBuilder = RepertoiresCompanion Function({
  Value<int> id,
  required String name,
  required String color,
  required String rootKey,
  required String rootFen,
  Value<String> description,
  Value<String> optionsJson,
  Value<int> sortOrder,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$RepertoiresTableUpdateCompanionBuilder = RepertoiresCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> color,
  Value<String> rootKey,
  Value<String> rootFen,
  Value<String> description,
  Value<String> optionsJson,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$RepertoiresTableReferences extends BaseReferences<_$AppDatabase, $RepertoiresTable, RepertoireRow> {
  $$RepertoiresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RepPositionsTable, List<RepPositionRow>> _repPositionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.repPositions, aliasName: 'repertoires__id__rep_positions__repertoire_id');

  $$RepPositionsTableProcessedTableManager get repPositionsRefs {
    final manager = $$RepPositionsTableTableManager(
      $_db,
      $_db.repPositions,
    ).filter((f) => f.repertoireId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_repPositionsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$RepMovesTable, List<RepMoveRow>> _repMovesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.repMoves, aliasName: 'repertoires__id__rep_moves__repertoire_id');

  $$RepMovesTableProcessedTableManager get repMovesRefs {
    final manager = $$RepMovesTableTableManager(
      $_db,
      $_db.repMoves,
    ).filter((f) => f.repertoireId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_repMovesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CardsTable, List<CardRow>> _cardsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.cards, aliasName: 'repertoires__id__cards__repertoire_id');

  $$CardsTableProcessedTableManager get cardsRefs {
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.repertoireId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ReviewLogsTable, List<ReviewLogRow>> _reviewLogsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.reviewLogs, aliasName: 'repertoires__id__review_logs__repertoire_id');

  $$ReviewLogsTableProcessedTableManager get reviewLogsRefs {
    final manager = $$ReviewLogsTableTableManager(
      $_db,
      $_db.reviewLogs,
    ).filter((f) => f.repertoireId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewLogsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$GapEventsTable, List<GapEventRow>> _gapEventsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.gapEvents, aliasName: 'repertoires__id__gap_events__repertoire_id');

  $$GapEventsTableProcessedTableManager get gapEventsRefs {
    final manager = $$GapEventsTableTableManager(
      $_db,
      $_db.gapEvents,
    ).filter((f) => f.repertoireId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gapEventsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RepertoiresTableFilterComposer extends Composer<_$AppDatabase, $RepertoiresTable> {
  $$RepertoiresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rootKey =>
      $composableBuilder(column: $table.rootKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rootFen =>
      $composableBuilder(column: $table.rootFen, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get optionsJson =>
      $composableBuilder(column: $table.optionsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> repPositionsRefs(Expression<bool> Function($$RepPositionsTableFilterComposer f) f) {
    final $$RepPositionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.repPositions,
      getReferencedColumn: (t) => t.repertoireId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepPositionsTableFilterComposer(
            $db: $db,
            $table: $db.repPositions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> repMovesRefs(Expression<bool> Function($$RepMovesTableFilterComposer f) f) {
    final $$RepMovesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.repMoves,
      getReferencedColumn: (t) => t.repertoireId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepMovesTableFilterComposer(
            $db: $db,
            $table: $db.repMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cardsRefs(Expression<bool> Function($$CardsTableFilterComposer f) f) {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.repertoireId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> reviewLogsRefs(Expression<bool> Function($$ReviewLogsTableFilterComposer f) f) {
    final $$ReviewLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewLogs,
      getReferencedColumn: (t) => t.repertoireId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ReviewLogsTableFilterComposer(
            $db: $db,
            $table: $db.reviewLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> gapEventsRefs(Expression<bool> Function($$GapEventsTableFilterComposer f) f) {
    final $$GapEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gapEvents,
      getReferencedColumn: (t) => t.repertoireId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$GapEventsTableFilterComposer(
            $db: $db,
            $table: $db.gapEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepertoiresTableOrderingComposer extends Composer<_$AppDatabase, $RepertoiresTable> {
  $$RepertoiresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rootKey =>
      $composableBuilder(column: $table.rootKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rootFen =>
      $composableBuilder(column: $table.rootFen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get optionsJson =>
      $composableBuilder(column: $table.optionsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$RepertoiresTableAnnotationComposer extends Composer<_$AppDatabase, $RepertoiresTable> {
  $$RepertoiresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color => $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get rootKey => $composableBuilder(column: $table.rootKey, builder: (column) => column);

  GeneratedColumn<String> get rootFen => $composableBuilder(column: $table.rootFen, builder: (column) => column);

  GeneratedColumn<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get optionsJson =>
      $composableBuilder(column: $table.optionsJson, builder: (column) => column);

  GeneratedColumn<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> repPositionsRefs<T extends Object>(Expression<T> Function($$RepPositionsTableAnnotationComposer a) f) {
    final $$RepPositionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.repPositions,
      getReferencedColumn: (t) => t.repertoireId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepPositionsTableAnnotationComposer(
            $db: $db,
            $table: $db.repPositions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> repMovesRefs<T extends Object>(Expression<T> Function($$RepMovesTableAnnotationComposer a) f) {
    final $$RepMovesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.repMoves,
      getReferencedColumn: (t) => t.repertoireId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepMovesTableAnnotationComposer(
            $db: $db,
            $table: $db.repMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cardsRefs<T extends Object>(Expression<T> Function($$CardsTableAnnotationComposer a) f) {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.repertoireId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> reviewLogsRefs<T extends Object>(Expression<T> Function($$ReviewLogsTableAnnotationComposer a) f) {
    final $$ReviewLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewLogs,
      getReferencedColumn: (t) => t.repertoireId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ReviewLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> gapEventsRefs<T extends Object>(Expression<T> Function($$GapEventsTableAnnotationComposer a) f) {
    final $$GapEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gapEvents,
      getReferencedColumn: (t) => t.repertoireId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$GapEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.gapEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepertoiresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepertoiresTable,
          RepertoireRow,
          $$RepertoiresTableFilterComposer,
          $$RepertoiresTableOrderingComposer,
          $$RepertoiresTableAnnotationComposer,
          $$RepertoiresTableCreateCompanionBuilder,
          $$RepertoiresTableUpdateCompanionBuilder,
          (RepertoireRow, $$RepertoiresTableReferences),
          RepertoireRow,
          PrefetchHooks Function({
            bool repPositionsRefs,
            bool repMovesRefs,
            bool cardsRefs,
            bool reviewLogsRefs,
            bool gapEventsRefs,
          })
        > {
  $$RepertoiresTableTableManager(_$AppDatabase db, $RepertoiresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RepertoiresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$RepertoiresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$RepertoiresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> rootKey = const Value.absent(),
                Value<String> rootFen = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> optionsJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RepertoiresCompanion(
                id: id,
                name: name,
                color: color,
                rootKey: rootKey,
                rootFen: rootFen,
                description: description,
                optionsJson: optionsJson,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String color,
                required String rootKey,
                required String rootFen,
                Value<String> description = const Value.absent(),
                Value<String> optionsJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => RepertoiresCompanion.insert(
                id: id,
                name: name,
                color: color,
                rootKey: rootKey,
                rootFen: rootFen,
                description: description,
                optionsJson: optionsJson,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable<$RepertoiresTable, RepertoireRow>(table), $$RepertoiresTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                repPositionsRefs = false,
                repMovesRefs = false,
                cardsRefs = false,
                reviewLogsRefs = false,
                gapEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (repPositionsRefs) db.repPositions,
                    if (repMovesRefs) db.repMoves,
                    if (cardsRefs) db.cards,
                    if (reviewLogsRefs) db.reviewLogs,
                    if (gapEventsRefs) db.gapEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (repPositionsRefs)
                        await $_getPrefetchedData<RepertoireRow, $RepertoiresTable, RepPositionRow>(
                          currentTable: table,
                          referencedTable: $$RepertoiresTableReferences._repPositionsRefsTable(db),
                          managerFromTypedResult: (p0) => $$RepertoiresTableReferences(db, table, p0).repPositionsRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.repertoireId == item.id),
                          typedResults: items,
                        ),
                      if (repMovesRefs)
                        await $_getPrefetchedData<RepertoireRow, $RepertoiresTable, RepMoveRow>(
                          currentTable: table,
                          referencedTable: $$RepertoiresTableReferences._repMovesRefsTable(db),
                          managerFromTypedResult: (p0) => $$RepertoiresTableReferences(db, table, p0).repMovesRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.repertoireId == item.id),
                          typedResults: items,
                        ),
                      if (cardsRefs)
                        await $_getPrefetchedData<RepertoireRow, $RepertoiresTable, CardRow>(
                          currentTable: table,
                          referencedTable: $$RepertoiresTableReferences._cardsRefsTable(db),
                          managerFromTypedResult: (p0) => $$RepertoiresTableReferences(db, table, p0).cardsRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.repertoireId == item.id),
                          typedResults: items,
                        ),
                      if (reviewLogsRefs)
                        await $_getPrefetchedData<RepertoireRow, $RepertoiresTable, ReviewLogRow>(
                          currentTable: table,
                          referencedTable: $$RepertoiresTableReferences._reviewLogsRefsTable(db),
                          managerFromTypedResult: (p0) => $$RepertoiresTableReferences(db, table, p0).reviewLogsRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.repertoireId == item.id),
                          typedResults: items,
                        ),
                      if (gapEventsRefs)
                        await $_getPrefetchedData<RepertoireRow, $RepertoiresTable, GapEventRow>(
                          currentTable: table,
                          referencedTable: $$RepertoiresTableReferences._gapEventsRefsTable(db),
                          managerFromTypedResult: (p0) => $$RepertoiresTableReferences(db, table, p0).gapEventsRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.repertoireId == item.id),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RepertoiresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepertoiresTable,
      RepertoireRow,
      $$RepertoiresTableFilterComposer,
      $$RepertoiresTableOrderingComposer,
      $$RepertoiresTableAnnotationComposer,
      $$RepertoiresTableCreateCompanionBuilder,
      $$RepertoiresTableUpdateCompanionBuilder,
      (RepertoireRow, $$RepertoiresTableReferences),
      RepertoireRow,
      PrefetchHooks Function({
        bool repPositionsRefs,
        bool repMovesRefs,
        bool cardsRefs,
        bool reviewLogsRefs,
        bool gapEventsRefs,
      })
    >;
typedef $$RepPositionsTableCreateCompanionBuilder = RepPositionsCompanion Function({
  required int repertoireId,
  required String positionKey,
  required String fen,
  Value<String> comment,
  Value<String> shapes,
  Value<bool> conflictDeferred,
  Value<String> engineFlag,
  Value<int> rowid,
});
typedef $$RepPositionsTableUpdateCompanionBuilder = RepPositionsCompanion Function({
  Value<int> repertoireId,
  Value<String> positionKey,
  Value<String> fen,
  Value<String> comment,
  Value<String> shapes,
  Value<bool> conflictDeferred,
  Value<String> engineFlag,
  Value<int> rowid,
});

final class $$RepPositionsTableReferences extends BaseReferences<_$AppDatabase, $RepPositionsTable, RepPositionRow> {
  $$RepPositionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RepertoiresTable _repertoireIdTable(_$AppDatabase db) =>
      db.repertoires.createAlias('rep_positions__repertoire_id__repertoires__id');

  $$RepertoiresTableProcessedTableManager get repertoireId {
    final $_column = $_itemColumn<int>('repertoire_id')!;

    final manager = $$RepertoiresTableTableManager($_db, $_db.repertoires).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repertoireIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RepPositionsTableFilterComposer extends Composer<_$AppDatabase, $RepPositionsTable> {
  $$RepPositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fen => $composableBuilder(column: $table.fen, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shapes =>
      $composableBuilder(column: $table.shapes, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get conflictDeferred =>
      $composableBuilder(column: $table.conflictDeferred, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get engineFlag =>
      $composableBuilder(column: $table.engineFlag, builder: (column) => ColumnFilters(column));

  $$RepertoiresTableFilterComposer get repertoireId {
    final $$RepertoiresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableFilterComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepPositionsTableOrderingComposer extends Composer<_$AppDatabase, $RepPositionsTable> {
  $$RepPositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fen =>
      $composableBuilder(column: $table.fen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shapes =>
      $composableBuilder(column: $table.shapes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get conflictDeferred =>
      $composableBuilder(column: $table.conflictDeferred, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get engineFlag =>
      $composableBuilder(column: $table.engineFlag, builder: (column) => ColumnOrderings(column));

  $$RepertoiresTableOrderingComposer get repertoireId {
    final $$RepertoiresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableOrderingComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepPositionsTableAnnotationComposer extends Composer<_$AppDatabase, $RepPositionsTable> {
  $$RepPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => column);

  GeneratedColumn<String> get fen => $composableBuilder(column: $table.fen, builder: (column) => column);

  GeneratedColumn<String> get comment => $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get shapes => $composableBuilder(column: $table.shapes, builder: (column) => column);

  GeneratedColumn<bool> get conflictDeferred =>
      $composableBuilder(column: $table.conflictDeferred, builder: (column) => column);

  GeneratedColumn<String> get engineFlag => $composableBuilder(column: $table.engineFlag, builder: (column) => column);

  $$RepertoiresTableAnnotationComposer get repertoireId {
    final $$RepertoiresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableAnnotationComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepPositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepPositionsTable,
          RepPositionRow,
          $$RepPositionsTableFilterComposer,
          $$RepPositionsTableOrderingComposer,
          $$RepPositionsTableAnnotationComposer,
          $$RepPositionsTableCreateCompanionBuilder,
          $$RepPositionsTableUpdateCompanionBuilder,
          (RepPositionRow, $$RepPositionsTableReferences),
          RepPositionRow,
          PrefetchHooks Function({bool repertoireId})
        > {
  $$RepPositionsTableTableManager(_$AppDatabase db, $RepPositionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RepPositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$RepPositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$RepPositionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> repertoireId = const Value.absent(),
                Value<String> positionKey = const Value.absent(),
                Value<String> fen = const Value.absent(),
                Value<String> comment = const Value.absent(),
                Value<String> shapes = const Value.absent(),
                Value<bool> conflictDeferred = const Value.absent(),
                Value<String> engineFlag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepPositionsCompanion(
                repertoireId: repertoireId,
                positionKey: positionKey,
                fen: fen,
                comment: comment,
                shapes: shapes,
                conflictDeferred: conflictDeferred,
                engineFlag: engineFlag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int repertoireId,
                required String positionKey,
                required String fen,
                Value<String> comment = const Value.absent(),
                Value<String> shapes = const Value.absent(),
                Value<bool> conflictDeferred = const Value.absent(),
                Value<String> engineFlag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepPositionsCompanion.insert(
                repertoireId: repertoireId,
                positionKey: positionKey,
                fen: fen,
                comment: comment,
                shapes: shapes,
                conflictDeferred: conflictDeferred,
                engineFlag: engineFlag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RepPositionsTable, RepPositionRow>(table),
                  $$RepPositionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({repertoireId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (repertoireId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.repertoireId,
                        referencedTable: $$RepPositionsTableReferences._repertoireIdTable(db),
                        referencedColumn: $$RepPositionsTableReferences._repertoireIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RepPositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepPositionsTable,
      RepPositionRow,
      $$RepPositionsTableFilterComposer,
      $$RepPositionsTableOrderingComposer,
      $$RepPositionsTableAnnotationComposer,
      $$RepPositionsTableCreateCompanionBuilder,
      $$RepPositionsTableUpdateCompanionBuilder,
      (RepPositionRow, $$RepPositionsTableReferences),
      RepPositionRow,
      PrefetchHooks Function({bool repertoireId})
    >;
typedef $$RepMovesTableCreateCompanionBuilder = RepMovesCompanion Function({
  required int repertoireId,
  required String fromKey,
  required String uci,
  required String toKey,
  required String san,
  Value<String> role,
  Value<int> weight,
  Value<String> comment,
  Value<String> source,
  Value<int> sortOrder,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$RepMovesTableUpdateCompanionBuilder = RepMovesCompanion Function({
  Value<int> repertoireId,
  Value<String> fromKey,
  Value<String> uci,
  Value<String> toKey,
  Value<String> san,
  Value<String> role,
  Value<int> weight,
  Value<String> comment,
  Value<String> source,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$RepMovesTableReferences extends BaseReferences<_$AppDatabase, $RepMovesTable, RepMoveRow> {
  $$RepMovesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RepertoiresTable _repertoireIdTable(_$AppDatabase db) =>
      db.repertoires.createAlias('rep_moves__repertoire_id__repertoires__id');

  $$RepertoiresTableProcessedTableManager get repertoireId {
    final $_column = $_itemColumn<int>('repertoire_id')!;

    final manager = $$RepertoiresTableTableManager($_db, $_db.repertoires).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repertoireIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RepMovesTableFilterComposer extends Composer<_$AppDatabase, $RepMovesTable> {
  $$RepMovesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fromKey =>
      $composableBuilder(column: $table.fromKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uci => $composableBuilder(column: $table.uci, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toKey =>
      $composableBuilder(column: $table.toKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get san => $composableBuilder(column: $table.san, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$RepertoiresTableFilterComposer get repertoireId {
    final $$RepertoiresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableFilterComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepMovesTableOrderingComposer extends Composer<_$AppDatabase, $RepMovesTable> {
  $$RepMovesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fromKey =>
      $composableBuilder(column: $table.fromKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uci =>
      $composableBuilder(column: $table.uci, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toKey =>
      $composableBuilder(column: $table.toKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get san =>
      $composableBuilder(column: $table.san, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$RepertoiresTableOrderingComposer get repertoireId {
    final $$RepertoiresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableOrderingComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepMovesTableAnnotationComposer extends Composer<_$AppDatabase, $RepMovesTable> {
  $$RepMovesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fromKey => $composableBuilder(column: $table.fromKey, builder: (column) => column);

  GeneratedColumn<String> get uci => $composableBuilder(column: $table.uci, builder: (column) => column);

  GeneratedColumn<String> get toKey => $composableBuilder(column: $table.toKey, builder: (column) => column);

  GeneratedColumn<String> get san => $composableBuilder(column: $table.san, builder: (column) => column);

  GeneratedColumn<String> get role => $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get weight => $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<String> get comment => $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get source => $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RepertoiresTableAnnotationComposer get repertoireId {
    final $$RepertoiresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableAnnotationComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepMovesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepMovesTable,
          RepMoveRow,
          $$RepMovesTableFilterComposer,
          $$RepMovesTableOrderingComposer,
          $$RepMovesTableAnnotationComposer,
          $$RepMovesTableCreateCompanionBuilder,
          $$RepMovesTableUpdateCompanionBuilder,
          (RepMoveRow, $$RepMovesTableReferences),
          RepMoveRow,
          PrefetchHooks Function({bool repertoireId})
        > {
  $$RepMovesTableTableManager(_$AppDatabase db, $RepMovesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RepMovesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$RepMovesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$RepMovesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> repertoireId = const Value.absent(),
                Value<String> fromKey = const Value.absent(),
                Value<String> uci = const Value.absent(),
                Value<String> toKey = const Value.absent(),
                Value<String> san = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> weight = const Value.absent(),
                Value<String> comment = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepMovesCompanion(
                repertoireId: repertoireId,
                fromKey: fromKey,
                uci: uci,
                toKey: toKey,
                san: san,
                role: role,
                weight: weight,
                comment: comment,
                source: source,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int repertoireId,
                required String fromKey,
                required String uci,
                required String toKey,
                required String san,
                Value<String> role = const Value.absent(),
                Value<int> weight = const Value.absent(),
                Value<String> comment = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RepMovesCompanion.insert(
                repertoireId: repertoireId,
                fromKey: fromKey,
                uci: uci,
                toKey: toKey,
                san: san,
                role: role,
                weight: weight,
                comment: comment,
                source: source,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$RepMovesTable, RepMoveRow>(table), $$RepMovesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({repertoireId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (repertoireId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.repertoireId,
                        referencedTable: $$RepMovesTableReferences._repertoireIdTable(db),
                        referencedColumn: $$RepMovesTableReferences._repertoireIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RepMovesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepMovesTable,
      RepMoveRow,
      $$RepMovesTableFilterComposer,
      $$RepMovesTableOrderingComposer,
      $$RepMovesTableAnnotationComposer,
      $$RepMovesTableCreateCompanionBuilder,
      $$RepMovesTableUpdateCompanionBuilder,
      (RepMoveRow, $$RepMovesTableReferences),
      RepMoveRow,
      PrefetchHooks Function({bool repertoireId})
    >;
typedef $$CardsTableCreateCompanionBuilder = CardsCompanion Function({
  required int repertoireId,
  required String positionKey,
  Value<double> stability,
  Value<double> difficulty,
  Value<DateTime?> due,
  Value<DateTime?> lastReview,
  Value<int> reps,
  Value<int> lapses,
  Value<String> state,
  Value<bool> suspended,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$CardsTableUpdateCompanionBuilder = CardsCompanion Function({
  Value<int> repertoireId,
  Value<String> positionKey,
  Value<double> stability,
  Value<double> difficulty,
  Value<DateTime?> due,
  Value<DateTime?> lastReview,
  Value<int> reps,
  Value<int> lapses,
  Value<String> state,
  Value<bool> suspended,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$CardsTableReferences extends BaseReferences<_$AppDatabase, $CardsTable, CardRow> {
  $$CardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RepertoiresTable _repertoireIdTable(_$AppDatabase db) =>
      db.repertoires.createAlias('cards__repertoire_id__repertoires__id');

  $$RepertoiresTableProcessedTableManager get repertoireId {
    final $_column = $_itemColumn<int>('repertoire_id')!;

    final manager = $$RepertoiresTableTableManager($_db, $_db.repertoires).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repertoireIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get difficulty =>
      $composableBuilder(column: $table.difficulty, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get due => $composableBuilder(column: $table.due, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastReview =>
      $composableBuilder(column: $table.lastReview, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reps => $composableBuilder(column: $table.reps, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get suspended =>
      $composableBuilder(column: $table.suspended, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$RepertoiresTableFilterComposer get repertoireId {
    final $$RepertoiresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableFilterComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardsTableOrderingComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get difficulty =>
      $composableBuilder(column: $table.difficulty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get due =>
      $composableBuilder(column: $table.due, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastReview =>
      $composableBuilder(column: $table.lastReview, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get suspended =>
      $composableBuilder(column: $table.suspended, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$RepertoiresTableOrderingComposer get repertoireId {
    final $$RepertoiresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableOrderingComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardsTableAnnotationComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => column);

  GeneratedColumn<double> get stability => $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(column: $table.difficulty, builder: (column) => column);

  GeneratedColumn<DateTime> get due => $composableBuilder(column: $table.due, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReview =>
      $composableBuilder(column: $table.lastReview, builder: (column) => column);

  GeneratedColumn<int> get reps => $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses => $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<String> get state => $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<bool> get suspended => $composableBuilder(column: $table.suspended, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RepertoiresTableAnnotationComposer get repertoireId {
    final $$RepertoiresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableAnnotationComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          CardRow,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (CardRow, $$CardsTableReferences),
          CardRow,
          PrefetchHooks Function({bool repertoireId})
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> repertoireId = const Value.absent(),
                Value<String> positionKey = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<DateTime?> due = const Value.absent(),
                Value<DateTime?> lastReview = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                repertoireId: repertoireId,
                positionKey: positionKey,
                stability: stability,
                difficulty: difficulty,
                due: due,
                lastReview: lastReview,
                reps: reps,
                lapses: lapses,
                state: state,
                suspended: suspended,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int repertoireId,
                required String positionKey,
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<DateTime?> due = const Value.absent(),
                Value<DateTime?> lastReview = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                repertoireId: repertoireId,
                positionKey: positionKey,
                stability: stability,
                difficulty: difficulty,
                due: due,
                lastReview: lastReview,
                reps: reps,
                lapses: lapses,
                state: state,
                suspended: suspended,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<$CardsTable, CardRow>(table), $$CardsTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({repertoireId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (repertoireId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.repertoireId,
                        referencedTable: $$CardsTableReferences._repertoireIdTable(db),
                        referencedColumn: $$CardsTableReferences._repertoireIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      CardRow,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (CardRow, $$CardsTableReferences),
      CardRow,
      PrefetchHooks Function({bool repertoireId})
    >;
typedef $$ReviewLogsTableCreateCompanionBuilder = ReviewLogsCompanion Function({
  Value<int> id,
  required int repertoireId,
  required String positionKey,
  required DateTime timestamp,
  required String grade,
  Value<String> playedUci,
  Value<String> expectedUci,
  required String mode,
  Value<int> responseMs,
  Value<bool> scheduled,
});
typedef $$ReviewLogsTableUpdateCompanionBuilder = ReviewLogsCompanion Function({
  Value<int> id,
  Value<int> repertoireId,
  Value<String> positionKey,
  Value<DateTime> timestamp,
  Value<String> grade,
  Value<String> playedUci,
  Value<String> expectedUci,
  Value<String> mode,
  Value<int> responseMs,
  Value<bool> scheduled,
});

final class $$ReviewLogsTableReferences extends BaseReferences<_$AppDatabase, $ReviewLogsTable, ReviewLogRow> {
  $$ReviewLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RepertoiresTable _repertoireIdTable(_$AppDatabase db) =>
      db.repertoires.createAlias('review_logs__repertoire_id__repertoires__id');

  $$RepertoiresTableProcessedTableManager get repertoireId {
    final $_column = $_itemColumn<int>('repertoire_id')!;

    final manager = $$RepertoiresTableTableManager($_db, $_db.repertoires).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repertoireIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ReviewLogsTableFilterComposer extends Composer<_$AppDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playedUci =>
      $composableBuilder(column: $table.playedUci, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get expectedUci =>
      $composableBuilder(column: $table.expectedUci, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get responseMs =>
      $composableBuilder(column: $table.responseMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get scheduled =>
      $composableBuilder(column: $table.scheduled, builder: (column) => ColumnFilters(column));

  $$RepertoiresTableFilterComposer get repertoireId {
    final $$RepertoiresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableFilterComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableOrderingComposer extends Composer<_$AppDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playedUci =>
      $composableBuilder(column: $table.playedUci, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get expectedUci =>
      $composableBuilder(column: $table.expectedUci, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get responseMs =>
      $composableBuilder(column: $table.responseMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get scheduled =>
      $composableBuilder(column: $table.scheduled, builder: (column) => ColumnOrderings(column));

  $$RepertoiresTableOrderingComposer get repertoireId {
    final $$RepertoiresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableOrderingComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableAnnotationComposer extends Composer<_$AppDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp => $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get grade => $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<String> get playedUci => $composableBuilder(column: $table.playedUci, builder: (column) => column);

  GeneratedColumn<String> get expectedUci =>
      $composableBuilder(column: $table.expectedUci, builder: (column) => column);

  GeneratedColumn<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get responseMs => $composableBuilder(column: $table.responseMs, builder: (column) => column);

  GeneratedColumn<bool> get scheduled => $composableBuilder(column: $table.scheduled, builder: (column) => column);

  $$RepertoiresTableAnnotationComposer get repertoireId {
    final $$RepertoiresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableAnnotationComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewLogsTable,
          ReviewLogRow,
          $$ReviewLogsTableFilterComposer,
          $$ReviewLogsTableOrderingComposer,
          $$ReviewLogsTableAnnotationComposer,
          $$ReviewLogsTableCreateCompanionBuilder,
          $$ReviewLogsTableUpdateCompanionBuilder,
          (ReviewLogRow, $$ReviewLogsTableReferences),
          ReviewLogRow,
          PrefetchHooks Function({bool repertoireId})
        > {
  $$ReviewLogsTableTableManager(_$AppDatabase db, $ReviewLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ReviewLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ReviewLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ReviewLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> repertoireId = const Value.absent(),
                Value<String> positionKey = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> grade = const Value.absent(),
                Value<String> playedUci = const Value.absent(),
                Value<String> expectedUci = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> responseMs = const Value.absent(),
                Value<bool> scheduled = const Value.absent(),
              }) => ReviewLogsCompanion(
                id: id,
                repertoireId: repertoireId,
                positionKey: positionKey,
                timestamp: timestamp,
                grade: grade,
                playedUci: playedUci,
                expectedUci: expectedUci,
                mode: mode,
                responseMs: responseMs,
                scheduled: scheduled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int repertoireId,
                required String positionKey,
                required DateTime timestamp,
                required String grade,
                Value<String> playedUci = const Value.absent(),
                Value<String> expectedUci = const Value.absent(),
                required String mode,
                Value<int> responseMs = const Value.absent(),
                Value<bool> scheduled = const Value.absent(),
              }) => ReviewLogsCompanion.insert(
                id: id,
                repertoireId: repertoireId,
                positionKey: positionKey,
                timestamp: timestamp,
                grade: grade,
                playedUci: playedUci,
                expectedUci: expectedUci,
                mode: mode,
                responseMs: responseMs,
                scheduled: scheduled,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (e.readTable<$ReviewLogsTable, ReviewLogRow>(table), $$ReviewLogsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({repertoireId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (repertoireId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.repertoireId,
                        referencedTable: $$ReviewLogsTableReferences._repertoireIdTable(db),
                        referencedColumn: $$ReviewLogsTableReferences._repertoireIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReviewLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewLogsTable,
      ReviewLogRow,
      $$ReviewLogsTableFilterComposer,
      $$ReviewLogsTableOrderingComposer,
      $$ReviewLogsTableAnnotationComposer,
      $$ReviewLogsTableCreateCompanionBuilder,
      $$ReviewLogsTableUpdateCompanionBuilder,
      (ReviewLogRow, $$ReviewLogsTableReferences),
      ReviewLogRow,
      PrefetchHooks Function({bool repertoireId})
    >;
typedef $$LinkedAccountsTableCreateCompanionBuilder = LinkedAccountsCompanion Function({
  required String provider,
  required String username,
  Value<String?> tokenRef,
  Value<String> scopes,
  required DateTime connectedAt,
  Value<DateTime?> lastSyncAt,
  Value<int> rowid,
});
typedef $$LinkedAccountsTableUpdateCompanionBuilder = LinkedAccountsCompanion Function({
  Value<String> provider,
  Value<String> username,
  Value<String?> tokenRef,
  Value<String> scopes,
  Value<DateTime> connectedAt,
  Value<DateTime?> lastSyncAt,
  Value<int> rowid,
});

class $$LinkedAccountsTableFilterComposer extends Composer<_$AppDatabase, $LinkedAccountsTable> {
  $$LinkedAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tokenRef =>
      $composableBuilder(column: $table.tokenRef, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scopes =>
      $composableBuilder(column: $table.scopes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get connectedAt =>
      $composableBuilder(column: $table.connectedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncAt =>
      $composableBuilder(column: $table.lastSyncAt, builder: (column) => ColumnFilters(column));
}

class $$LinkedAccountsTableOrderingComposer extends Composer<_$AppDatabase, $LinkedAccountsTable> {
  $$LinkedAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tokenRef =>
      $composableBuilder(column: $table.tokenRef, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scopes =>
      $composableBuilder(column: $table.scopes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get connectedAt =>
      $composableBuilder(column: $table.connectedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncAt =>
      $composableBuilder(column: $table.lastSyncAt, builder: (column) => ColumnOrderings(column));
}

class $$LinkedAccountsTableAnnotationComposer extends Composer<_$AppDatabase, $LinkedAccountsTable> {
  $$LinkedAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get provider => $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get username => $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get tokenRef => $composableBuilder(column: $table.tokenRef, builder: (column) => column);

  GeneratedColumn<String> get scopes => $composableBuilder(column: $table.scopes, builder: (column) => column);

  GeneratedColumn<DateTime> get connectedAt =>
      $composableBuilder(column: $table.connectedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt =>
      $composableBuilder(column: $table.lastSyncAt, builder: (column) => column);
}

class $$LinkedAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LinkedAccountsTable,
          LinkedAccountRow,
          $$LinkedAccountsTableFilterComposer,
          $$LinkedAccountsTableOrderingComposer,
          $$LinkedAccountsTableAnnotationComposer,
          $$LinkedAccountsTableCreateCompanionBuilder,
          $$LinkedAccountsTableUpdateCompanionBuilder,
          (LinkedAccountRow, BaseReferences<_$AppDatabase, $LinkedAccountsTable, LinkedAccountRow>),
          LinkedAccountRow,
          PrefetchHooks Function()
        > {
  $$LinkedAccountsTableTableManager(_$AppDatabase db, $LinkedAccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LinkedAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LinkedAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LinkedAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> provider = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String?> tokenRef = const Value.absent(),
                Value<String> scopes = const Value.absent(),
                Value<DateTime> connectedAt = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LinkedAccountsCompanion(
                provider: provider,
                username: username,
                tokenRef: tokenRef,
                scopes: scopes,
                connectedAt: connectedAt,
                lastSyncAt: lastSyncAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String provider,
                required String username,
                Value<String?> tokenRef = const Value.absent(),
                Value<String> scopes = const Value.absent(),
                required DateTime connectedAt,
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LinkedAccountsCompanion.insert(
                provider: provider,
                username: username,
                tokenRef: tokenRef,
                scopes: scopes,
                connectedAt: connectedAt,
                lastSyncAt: lastSyncAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LinkedAccountsTable, LinkedAccountRow>(table),
                  BaseReferences<_$AppDatabase, $LinkedAccountsTable, LinkedAccountRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LinkedAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LinkedAccountsTable,
      LinkedAccountRow,
      $$LinkedAccountsTableFilterComposer,
      $$LinkedAccountsTableOrderingComposer,
      $$LinkedAccountsTableAnnotationComposer,
      $$LinkedAccountsTableCreateCompanionBuilder,
      $$LinkedAccountsTableUpdateCompanionBuilder,
      (LinkedAccountRow, BaseReferences<_$AppDatabase, $LinkedAccountsTable, LinkedAccountRow>),
      LinkedAccountRow,
      PrefetchHooks Function()
    >;
typedef $$ImportedGamesTableCreateCompanionBuilder = ImportedGamesCompanion Function({
  Value<int> id,
  required String provider,
  required String externalId,
  required String pgn,
  required DateTime playedAt,
  required String userColor,
  Value<String> timeControl,
  Value<String> speed,
  Value<String> result,
  Value<String> opponent,
  Value<String> url,
  Value<bool> rated,
  Value<DateTime?> analyzedAt,
});
typedef $$ImportedGamesTableUpdateCompanionBuilder = ImportedGamesCompanion Function({
  Value<int> id,
  Value<String> provider,
  Value<String> externalId,
  Value<String> pgn,
  Value<DateTime> playedAt,
  Value<String> userColor,
  Value<String> timeControl,
  Value<String> speed,
  Value<String> result,
  Value<String> opponent,
  Value<String> url,
  Value<bool> rated,
  Value<DateTime?> analyzedAt,
});

final class $$ImportedGamesTableReferences extends BaseReferences<_$AppDatabase, $ImportedGamesTable, ImportedGameRow> {
  $$ImportedGamesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GapEventsTable, List<GapEventRow>> _gapEventsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.gapEvents, aliasName: 'imported_games__id__gap_events__imported_game_id');

  $$GapEventsTableProcessedTableManager get gapEventsRefs {
    final manager = $$GapEventsTableTableManager(
      $_db,
      $_db.gapEvents,
    ).filter((f) => f.importedGameId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gapEventsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ImportedGamesTableFilterComposer extends Composer<_$AppDatabase, $ImportedGamesTable> {
  $$ImportedGamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get externalId =>
      $composableBuilder(column: $table.externalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pgn => $composableBuilder(column: $table.pgn, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userColor =>
      $composableBuilder(column: $table.userColor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timeControl =>
      $composableBuilder(column: $table.timeControl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get opponent =>
      $composableBuilder(column: $table.opponent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url => $composableBuilder(column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get rated => $composableBuilder(column: $table.rated, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get analyzedAt =>
      $composableBuilder(column: $table.analyzedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> gapEventsRefs(Expression<bool> Function($$GapEventsTableFilterComposer f) f) {
    final $$GapEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gapEvents,
      getReferencedColumn: (t) => t.importedGameId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$GapEventsTableFilterComposer(
            $db: $db,
            $table: $db.gapEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImportedGamesTableOrderingComposer extends Composer<_$AppDatabase, $ImportedGamesTable> {
  $$ImportedGamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get externalId =>
      $composableBuilder(column: $table.externalId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pgn =>
      $composableBuilder(column: $table.pgn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userColor =>
      $composableBuilder(column: $table.userColor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timeControl =>
      $composableBuilder(column: $table.timeControl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get opponent =>
      $composableBuilder(column: $table.opponent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get rated =>
      $composableBuilder(column: $table.rated, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get analyzedAt =>
      $composableBuilder(column: $table.analyzedAt, builder: (column) => ColumnOrderings(column));
}

class $$ImportedGamesTableAnnotationComposer extends Composer<_$AppDatabase, $ImportedGamesTable> {
  $$ImportedGamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider => $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(column: $table.externalId, builder: (column) => column);

  GeneratedColumn<String> get pgn => $composableBuilder(column: $table.pgn, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt => $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<String> get userColor => $composableBuilder(column: $table.userColor, builder: (column) => column);

  GeneratedColumn<String> get timeControl =>
      $composableBuilder(column: $table.timeControl, builder: (column) => column);

  GeneratedColumn<String> get speed => $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<String> get result => $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get opponent => $composableBuilder(column: $table.opponent, builder: (column) => column);

  GeneratedColumn<String> get url => $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<bool> get rated => $composableBuilder(column: $table.rated, builder: (column) => column);

  GeneratedColumn<DateTime> get analyzedAt =>
      $composableBuilder(column: $table.analyzedAt, builder: (column) => column);

  Expression<T> gapEventsRefs<T extends Object>(Expression<T> Function($$GapEventsTableAnnotationComposer a) f) {
    final $$GapEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gapEvents,
      getReferencedColumn: (t) => t.importedGameId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$GapEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.gapEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImportedGamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportedGamesTable,
          ImportedGameRow,
          $$ImportedGamesTableFilterComposer,
          $$ImportedGamesTableOrderingComposer,
          $$ImportedGamesTableAnnotationComposer,
          $$ImportedGamesTableCreateCompanionBuilder,
          $$ImportedGamesTableUpdateCompanionBuilder,
          (ImportedGameRow, $$ImportedGamesTableReferences),
          ImportedGameRow,
          PrefetchHooks Function({bool gapEventsRefs})
        > {
  $$ImportedGamesTableTableManager(_$AppDatabase db, $ImportedGamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ImportedGamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ImportedGamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ImportedGamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> externalId = const Value.absent(),
                Value<String> pgn = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
                Value<String> userColor = const Value.absent(),
                Value<String> timeControl = const Value.absent(),
                Value<String> speed = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String> opponent = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<bool> rated = const Value.absent(),
                Value<DateTime?> analyzedAt = const Value.absent(),
              }) => ImportedGamesCompanion(
                id: id,
                provider: provider,
                externalId: externalId,
                pgn: pgn,
                playedAt: playedAt,
                userColor: userColor,
                timeControl: timeControl,
                speed: speed,
                result: result,
                opponent: opponent,
                url: url,
                rated: rated,
                analyzedAt: analyzedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String provider,
                required String externalId,
                required String pgn,
                required DateTime playedAt,
                required String userColor,
                Value<String> timeControl = const Value.absent(),
                Value<String> speed = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String> opponent = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<bool> rated = const Value.absent(),
                Value<DateTime?> analyzedAt = const Value.absent(),
              }) => ImportedGamesCompanion.insert(
                id: id,
                provider: provider,
                externalId: externalId,
                pgn: pgn,
                playedAt: playedAt,
                userColor: userColor,
                timeControl: timeControl,
                speed: speed,
                result: result,
                opponent: opponent,
                url: url,
                rated: rated,
                analyzedAt: analyzedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImportedGamesTable, ImportedGameRow>(table),
                  $$ImportedGamesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gapEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (gapEventsRefs) db.gapEvents],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (gapEventsRefs)
                    await $_getPrefetchedData<ImportedGameRow, $ImportedGamesTable, GapEventRow>(
                      currentTable: table,
                      referencedTable: $$ImportedGamesTableReferences._gapEventsRefsTable(db),
                      managerFromTypedResult: (p0) => $$ImportedGamesTableReferences(db, table, p0).gapEventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.importedGameId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ImportedGamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportedGamesTable,
      ImportedGameRow,
      $$ImportedGamesTableFilterComposer,
      $$ImportedGamesTableOrderingComposer,
      $$ImportedGamesTableAnnotationComposer,
      $$ImportedGamesTableCreateCompanionBuilder,
      $$ImportedGamesTableUpdateCompanionBuilder,
      (ImportedGameRow, $$ImportedGamesTableReferences),
      ImportedGameRow,
      PrefetchHooks Function({bool gapEventsRefs})
    >;
typedef $$GapEventsTableCreateCompanionBuilder = GapEventsCompanion Function({
  Value<int> id,
  required int importedGameId,
  required int repertoireId,
  required String type,
  required String positionKey,
  required String fen,
  required int ply,
  Value<String> playedSan,
  Value<String> playedUci,
  Value<String> expectedSan,
  Value<bool> dismissed,
});
typedef $$GapEventsTableUpdateCompanionBuilder = GapEventsCompanion Function({
  Value<int> id,
  Value<int> importedGameId,
  Value<int> repertoireId,
  Value<String> type,
  Value<String> positionKey,
  Value<String> fen,
  Value<int> ply,
  Value<String> playedSan,
  Value<String> playedUci,
  Value<String> expectedSan,
  Value<bool> dismissed,
});

final class $$GapEventsTableReferences extends BaseReferences<_$AppDatabase, $GapEventsTable, GapEventRow> {
  $$GapEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ImportedGamesTable _importedGameIdTable(_$AppDatabase db) =>
      db.importedGames.createAlias('gap_events__imported_game_id__imported_games__id');

  $$ImportedGamesTableProcessedTableManager get importedGameId {
    final $_column = $_itemColumn<int>('imported_game_id')!;

    final manager = $$ImportedGamesTableTableManager($_db, $_db.importedGames).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_importedGameIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static $RepertoiresTable _repertoireIdTable(_$AppDatabase db) =>
      db.repertoires.createAlias('gap_events__repertoire_id__repertoires__id');

  $$RepertoiresTableProcessedTableManager get repertoireId {
    final $_column = $_itemColumn<int>('repertoire_id')!;

    final manager = $$RepertoiresTableTableManager($_db, $_db.repertoires).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repertoireIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$GapEventsTableFilterComposer extends Composer<_$AppDatabase, $GapEventsTable> {
  $$GapEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fen => $composableBuilder(column: $table.fen, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ply => $composableBuilder(column: $table.ply, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playedSan =>
      $composableBuilder(column: $table.playedSan, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get playedUci =>
      $composableBuilder(column: $table.playedUci, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get expectedSan =>
      $composableBuilder(column: $table.expectedSan, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => ColumnFilters(column));

  $$ImportedGamesTableFilterComposer get importedGameId {
    final $$ImportedGamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importedGameId,
      referencedTable: $db.importedGames,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ImportedGamesTableFilterComposer(
            $db: $db,
            $table: $db.importedGames,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepertoiresTableFilterComposer get repertoireId {
    final $$RepertoiresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableFilterComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GapEventsTableOrderingComposer extends Composer<_$AppDatabase, $GapEventsTable> {
  $$GapEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fen =>
      $composableBuilder(column: $table.fen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ply => $composableBuilder(column: $table.ply, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playedSan =>
      $composableBuilder(column: $table.playedSan, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get playedUci =>
      $composableBuilder(column: $table.playedUci, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get expectedSan =>
      $composableBuilder(column: $table.expectedSan, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => ColumnOrderings(column));

  $$ImportedGamesTableOrderingComposer get importedGameId {
    final $$ImportedGamesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importedGameId,
      referencedTable: $db.importedGames,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ImportedGamesTableOrderingComposer(
            $db: $db,
            $table: $db.importedGames,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepertoiresTableOrderingComposer get repertoireId {
    final $$RepertoiresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableOrderingComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GapEventsTableAnnotationComposer extends Composer<_$AppDatabase, $GapEventsTable> {
  $$GapEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type => $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get positionKey =>
      $composableBuilder(column: $table.positionKey, builder: (column) => column);

  GeneratedColumn<String> get fen => $composableBuilder(column: $table.fen, builder: (column) => column);

  GeneratedColumn<int> get ply => $composableBuilder(column: $table.ply, builder: (column) => column);

  GeneratedColumn<String> get playedSan => $composableBuilder(column: $table.playedSan, builder: (column) => column);

  GeneratedColumn<String> get playedUci => $composableBuilder(column: $table.playedUci, builder: (column) => column);

  GeneratedColumn<String> get expectedSan =>
      $composableBuilder(column: $table.expectedSan, builder: (column) => column);

  GeneratedColumn<bool> get dismissed => $composableBuilder(column: $table.dismissed, builder: (column) => column);

  $$ImportedGamesTableAnnotationComposer get importedGameId {
    final $$ImportedGamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importedGameId,
      referencedTable: $db.importedGames,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ImportedGamesTableAnnotationComposer(
            $db: $db,
            $table: $db.importedGames,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepertoiresTableAnnotationComposer get repertoireId {
    final $$RepertoiresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RepertoiresTableAnnotationComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GapEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GapEventsTable,
          GapEventRow,
          $$GapEventsTableFilterComposer,
          $$GapEventsTableOrderingComposer,
          $$GapEventsTableAnnotationComposer,
          $$GapEventsTableCreateCompanionBuilder,
          $$GapEventsTableUpdateCompanionBuilder,
          (GapEventRow, $$GapEventsTableReferences),
          GapEventRow,
          PrefetchHooks Function({bool importedGameId, bool repertoireId})
        > {
  $$GapEventsTableTableManager(_$AppDatabase db, $GapEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$GapEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$GapEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$GapEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> importedGameId = const Value.absent(),
                Value<int> repertoireId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> positionKey = const Value.absent(),
                Value<String> fen = const Value.absent(),
                Value<int> ply = const Value.absent(),
                Value<String> playedSan = const Value.absent(),
                Value<String> playedUci = const Value.absent(),
                Value<String> expectedSan = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
              }) => GapEventsCompanion(
                id: id,
                importedGameId: importedGameId,
                repertoireId: repertoireId,
                type: type,
                positionKey: positionKey,
                fen: fen,
                ply: ply,
                playedSan: playedSan,
                playedUci: playedUci,
                expectedSan: expectedSan,
                dismissed: dismissed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int importedGameId,
                required int repertoireId,
                required String type,
                required String positionKey,
                required String fen,
                required int ply,
                Value<String> playedSan = const Value.absent(),
                Value<String> playedUci = const Value.absent(),
                Value<String> expectedSan = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
              }) => GapEventsCompanion.insert(
                id: id,
                importedGameId: importedGameId,
                repertoireId: repertoireId,
                type: type,
                positionKey: positionKey,
                fen: fen,
                ply: ply,
                playedSan: playedSan,
                playedUci: playedUci,
                expectedSan: expectedSan,
                dismissed: dismissed,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$GapEventsTable, GapEventRow>(table), $$GapEventsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({importedGameId = false, repertoireId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (importedGameId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.importedGameId,
                        referencedTable: $$GapEventsTableReferences._importedGameIdTable(db),
                        referencedColumn: $$GapEventsTableReferences._importedGameIdTable(db).id,
                      ) as T;
                    }
                    if (repertoireId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.repertoireId,
                        referencedTable: $$GapEventsTableReferences._repertoireIdTable(db),
                        referencedColumn: $$GapEventsTableReferences._repertoireIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GapEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GapEventsTable,
      GapEventRow,
      $$GapEventsTableFilterComposer,
      $$GapEventsTableOrderingComposer,
      $$GapEventsTableAnnotationComposer,
      $$GapEventsTableCreateCompanionBuilder,
      $$GapEventsTableUpdateCompanionBuilder,
      (GapEventRow, $$GapEventsTableReferences),
      GapEventRow,
      PrefetchHooks Function({bool importedGameId, bool repertoireId})
    >;
typedef $$ExplorerCacheTableCreateCompanionBuilder = ExplorerCacheCompanion Function({
  required String cacheKey,
  required String json,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$ExplorerCacheTableUpdateCompanionBuilder = ExplorerCacheCompanion Function({
  Value<String> cacheKey,
  Value<String> json,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$ExplorerCacheTableFilterComposer extends Composer<_$AppDatabase, $ExplorerCacheTable> {
  $$ExplorerCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$ExplorerCacheTableOrderingComposer extends Composer<_$AppDatabase, $ExplorerCacheTable> {
  $$ExplorerCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$ExplorerCacheTableAnnotationComposer extends Composer<_$AppDatabase, $ExplorerCacheTable> {
  $$ExplorerCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey => $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get json => $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt => $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$ExplorerCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExplorerCacheTable,
          ExplorerCacheRow,
          $$ExplorerCacheTableFilterComposer,
          $$ExplorerCacheTableOrderingComposer,
          $$ExplorerCacheTableAnnotationComposer,
          $$ExplorerCacheTableCreateCompanionBuilder,
          $$ExplorerCacheTableUpdateCompanionBuilder,
          (ExplorerCacheRow, BaseReferences<_$AppDatabase, $ExplorerCacheTable, ExplorerCacheRow>),
          ExplorerCacheRow,
          PrefetchHooks Function()
        > {
  $$ExplorerCacheTableTableManager(_$AppDatabase db, $ExplorerCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ExplorerCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ExplorerCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ExplorerCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> cacheKey = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => ExplorerCacheCompanion(cacheKey: cacheKey, json: json, fetchedAt: fetchedAt, rowid: rowid),
          createCompanionCallback: ({
            required String cacheKey,
            required String json,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) => ExplorerCacheCompanion.insert(cacheKey: cacheKey, json: json, fetchedAt: fetchedAt, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExplorerCacheTable, ExplorerCacheRow>(table),
                  BaseReferences<_$AppDatabase, $ExplorerCacheTable, ExplorerCacheRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExplorerCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExplorerCacheTable,
      ExplorerCacheRow,
      $$ExplorerCacheTableFilterComposer,
      $$ExplorerCacheTableOrderingComposer,
      $$ExplorerCacheTableAnnotationComposer,
      $$ExplorerCacheTableCreateCompanionBuilder,
      $$ExplorerCacheTableUpdateCompanionBuilder,
      (ExplorerCacheRow, BaseReferences<_$AppDatabase, $ExplorerCacheTable, ExplorerCacheRow>),
      ExplorerCacheRow,
      PrefetchHooks Function()
    >;
typedef $$HttpCacheTableCreateCompanionBuilder = HttpCacheCompanion Function({
  required String url,
  Value<String?> etag,
  Value<String?> lastModified,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$HttpCacheTableUpdateCompanionBuilder = HttpCacheCompanion Function({
  Value<String> url,
  Value<String?> etag,
  Value<String?> lastModified,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$HttpCacheTableFilterComposer extends Composer<_$AppDatabase, $HttpCacheTable> {
  $$HttpCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get url => $composableBuilder(column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get etag => $composableBuilder(column: $table.etag, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastModified =>
      $composableBuilder(column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$HttpCacheTableOrderingComposer extends Composer<_$AppDatabase, $HttpCacheTable> {
  $$HttpCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastModified =>
      $composableBuilder(column: $table.lastModified, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$HttpCacheTableAnnotationComposer extends Composer<_$AppDatabase, $HttpCacheTable> {
  $$HttpCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get url => $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get etag => $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get lastModified =>
      $composableBuilder(column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt => $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$HttpCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HttpCacheTable,
          HttpCacheRow,
          $$HttpCacheTableFilterComposer,
          $$HttpCacheTableOrderingComposer,
          $$HttpCacheTableAnnotationComposer,
          $$HttpCacheTableCreateCompanionBuilder,
          $$HttpCacheTableUpdateCompanionBuilder,
          (HttpCacheRow, BaseReferences<_$AppDatabase, $HttpCacheTable, HttpCacheRow>),
          HttpCacheRow,
          PrefetchHooks Function()
        > {
  $$HttpCacheTableTableManager(_$AppDatabase db, $HttpCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$HttpCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$HttpCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$HttpCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> url = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HttpCacheCompanion(
                url: url,
                etag: etag,
                lastModified: lastModified,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String url,
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => HttpCacheCompanion.insert(
                url: url,
                etag: etag,
                lastModified: lastModified,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HttpCacheTable, HttpCacheRow>(table),
                  BaseReferences<_$AppDatabase, $HttpCacheTable, HttpCacheRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HttpCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HttpCacheTable,
      HttpCacheRow,
      $$HttpCacheTableFilterComposer,
      $$HttpCacheTableOrderingComposer,
      $$HttpCacheTableAnnotationComposer,
      $$HttpCacheTableCreateCompanionBuilder,
      $$HttpCacheTableUpdateCompanionBuilder,
      (HttpCacheRow, BaseReferences<_$AppDatabase, $HttpCacheTable, HttpCacheRow>),
      HttpCacheRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CollectionsTableTableManager get collections => $$CollectionsTableTableManager(_db, _db.collections);
  $$GamesTableTableManager get games => $$GamesTableTableManager(_db, _db.games);
  $$RepertoiresTableTableManager get repertoires => $$RepertoiresTableTableManager(_db, _db.repertoires);
  $$RepPositionsTableTableManager get repPositions => $$RepPositionsTableTableManager(_db, _db.repPositions);
  $$RepMovesTableTableManager get repMoves => $$RepMovesTableTableManager(_db, _db.repMoves);
  $$CardsTableTableManager get cards => $$CardsTableTableManager(_db, _db.cards);
  $$ReviewLogsTableTableManager get reviewLogs => $$ReviewLogsTableTableManager(_db, _db.reviewLogs);
  $$LinkedAccountsTableTableManager get linkedAccounts => $$LinkedAccountsTableTableManager(_db, _db.linkedAccounts);
  $$ImportedGamesTableTableManager get importedGames => $$ImportedGamesTableTableManager(_db, _db.importedGames);
  $$GapEventsTableTableManager get gapEvents => $$GapEventsTableTableManager(_db, _db.gapEvents);
  $$ExplorerCacheTableTableManager get explorerCache => $$ExplorerCacheTableTableManager(_db, _db.explorerCache);
  $$HttpCacheTableTableManager get httpCache => $$HttpCacheTableTableManager(_db, _db.httpCache);
  $$SettingsTableTableManager get settings => $$SettingsTableTableManager(_db, _db.settings);
}
