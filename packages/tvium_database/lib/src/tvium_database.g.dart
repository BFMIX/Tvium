// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tvium_database.dart';

// ignore_for_file: type=lint
class $MediaEntriesTable extends MediaEntries
    with TableInfo<$MediaEntriesTable, MediaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceReferenceMeta = const VerificationMeta(
    'sourceReference',
  );
  @override
  late final GeneratedColumn<String> sourceReference = GeneratedColumn<String>(
    'source_reference',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalNameMeta = const VerificationMeta(
    'originalName',
  );
  @override
  late final GeneratedColumn<String> originalName = GeneratedColumn<String>(
    'original_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _searchNameMeta = const VerificationMeta(
    'searchName',
  );
  @override
  late final GeneratedColumn<String> searchName = GeneratedColumn<String>(
    'search_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    sourceReference,
    originalName,
    displayName,
    groupName,
    kind,
    position,
    searchName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('source_reference')) {
      context.handle(
        _sourceReferenceMeta,
        sourceReference.isAcceptableOrUnknown(
          data['source_reference']!,
          _sourceReferenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceReferenceMeta);
    }
    if (data.containsKey('original_name')) {
      context.handle(
        _originalNameMeta,
        originalName.isAcceptableOrUnknown(
          data['original_name']!,
          _originalNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalNameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('search_name')) {
      context.handle(
        _searchNameMeta,
        searchName.isAcceptableOrUnknown(data['search_name']!, _searchNameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, id};
  @override
  MediaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
      sourceReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_reference'],
      )!,
      originalName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      searchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_name'],
      )!,
    );
  }

  @override
  $MediaEntriesTable createAlias(String alias) {
    return $MediaEntriesTable(attachedDatabase, alias);
  }
}

class MediaEntry extends DataClass implements Insertable<MediaEntry> {
  final String id;
  final String playlistId;
  final String sourceReference;
  final String originalName;
  final String displayName;
  final String? groupName;
  final String kind;
  final int position;
  final String searchName;
  const MediaEntry({
    required this.id,
    required this.playlistId,
    required this.sourceReference,
    required this.originalName,
    required this.displayName,
    this.groupName,
    required this.kind,
    required this.position,
    required this.searchName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['playlist_id'] = Variable<String>(playlistId);
    map['source_reference'] = Variable<String>(sourceReference);
    map['original_name'] = Variable<String>(originalName);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    map['kind'] = Variable<String>(kind);
    map['position'] = Variable<int>(position);
    map['search_name'] = Variable<String>(searchName);
    return map;
  }

  MediaEntriesCompanion toCompanion(bool nullToAbsent) {
    return MediaEntriesCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      sourceReference: Value(sourceReference),
      originalName: Value(originalName),
      displayName: Value(displayName),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      kind: Value(kind),
      position: Value(position),
      searchName: Value(searchName),
    );
  }

  factory MediaEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaEntry(
      id: serializer.fromJson<String>(json['id']),
      playlistId: serializer.fromJson<String>(json['playlistId']),
      sourceReference: serializer.fromJson<String>(json['sourceReference']),
      originalName: serializer.fromJson<String>(json['originalName']),
      displayName: serializer.fromJson<String>(json['displayName']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      kind: serializer.fromJson<String>(json['kind']),
      position: serializer.fromJson<int>(json['position']),
      searchName: serializer.fromJson<String>(json['searchName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'playlistId': serializer.toJson<String>(playlistId),
      'sourceReference': serializer.toJson<String>(sourceReference),
      'originalName': serializer.toJson<String>(originalName),
      'displayName': serializer.toJson<String>(displayName),
      'groupName': serializer.toJson<String?>(groupName),
      'kind': serializer.toJson<String>(kind),
      'position': serializer.toJson<int>(position),
      'searchName': serializer.toJson<String>(searchName),
    };
  }

  MediaEntry copyWith({
    String? id,
    String? playlistId,
    String? sourceReference,
    String? originalName,
    String? displayName,
    Value<String?> groupName = const Value.absent(),
    String? kind,
    int? position,
    String? searchName,
  }) => MediaEntry(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    sourceReference: sourceReference ?? this.sourceReference,
    originalName: originalName ?? this.originalName,
    displayName: displayName ?? this.displayName,
    groupName: groupName.present ? groupName.value : this.groupName,
    kind: kind ?? this.kind,
    position: position ?? this.position,
    searchName: searchName ?? this.searchName,
  );
  MediaEntry copyWithCompanion(MediaEntriesCompanion data) {
    return MediaEntry(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      sourceReference: data.sourceReference.present
          ? data.sourceReference.value
          : this.sourceReference,
      originalName: data.originalName.present
          ? data.originalName.value
          : this.originalName,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      kind: data.kind.present ? data.kind.value : this.kind,
      position: data.position.present ? data.position.value : this.position,
      searchName: data.searchName.present
          ? data.searchName.value
          : this.searchName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaEntry(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('sourceReference: $sourceReference, ')
          ..write('originalName: $originalName, ')
          ..write('displayName: $displayName, ')
          ..write('groupName: $groupName, ')
          ..write('kind: $kind, ')
          ..write('position: $position, ')
          ..write('searchName: $searchName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    sourceReference,
    originalName,
    displayName,
    groupName,
    kind,
    position,
    searchName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaEntry &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.sourceReference == this.sourceReference &&
          other.originalName == this.originalName &&
          other.displayName == this.displayName &&
          other.groupName == this.groupName &&
          other.kind == this.kind &&
          other.position == this.position &&
          other.searchName == this.searchName);
}

class MediaEntriesCompanion extends UpdateCompanion<MediaEntry> {
  final Value<String> id;
  final Value<String> playlistId;
  final Value<String> sourceReference;
  final Value<String> originalName;
  final Value<String> displayName;
  final Value<String?> groupName;
  final Value<String> kind;
  final Value<int> position;
  final Value<String> searchName;
  final Value<int> rowid;
  const MediaEntriesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.sourceReference = const Value.absent(),
    this.originalName = const Value.absent(),
    this.displayName = const Value.absent(),
    this.groupName = const Value.absent(),
    this.kind = const Value.absent(),
    this.position = const Value.absent(),
    this.searchName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaEntriesCompanion.insert({
    required String id,
    required String playlistId,
    required String sourceReference,
    required String originalName,
    required String displayName,
    this.groupName = const Value.absent(),
    required String kind,
    this.position = const Value.absent(),
    this.searchName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       playlistId = Value(playlistId),
       sourceReference = Value(sourceReference),
       originalName = Value(originalName),
       displayName = Value(displayName),
       kind = Value(kind);
  static Insertable<MediaEntry> custom({
    Expression<String>? id,
    Expression<String>? playlistId,
    Expression<String>? sourceReference,
    Expression<String>? originalName,
    Expression<String>? displayName,
    Expression<String>? groupName,
    Expression<String>? kind,
    Expression<int>? position,
    Expression<String>? searchName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (sourceReference != null) 'source_reference': sourceReference,
      if (originalName != null) 'original_name': originalName,
      if (displayName != null) 'display_name': displayName,
      if (groupName != null) 'group_name': groupName,
      if (kind != null) 'kind': kind,
      if (position != null) 'position': position,
      if (searchName != null) 'search_name': searchName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? playlistId,
    Value<String>? sourceReference,
    Value<String>? originalName,
    Value<String>? displayName,
    Value<String?>? groupName,
    Value<String>? kind,
    Value<int>? position,
    Value<String>? searchName,
    Value<int>? rowid,
  }) {
    return MediaEntriesCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      sourceReference: sourceReference ?? this.sourceReference,
      originalName: originalName ?? this.originalName,
      displayName: displayName ?? this.displayName,
      groupName: groupName ?? this.groupName,
      kind: kind ?? this.kind,
      position: position ?? this.position,
      searchName: searchName ?? this.searchName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (sourceReference.present) {
      map['source_reference'] = Variable<String>(sourceReference.value);
    }
    if (originalName.present) {
      map['original_name'] = Variable<String>(originalName.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (searchName.present) {
      map['search_name'] = Variable<String>(searchName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaEntriesCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('sourceReference: $sourceReference, ')
          ..write('originalName: $originalName, ')
          ..write('displayName: $displayName, ')
          ..write('groupName: $groupName, ')
          ..write('kind: $kind, ')
          ..write('position: $position, ')
          ..write('searchName: $searchName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TviumDatabase extends GeneratedDatabase {
  _$TviumDatabase(QueryExecutor e) : super(e);
  $TviumDatabaseManager get managers => $TviumDatabaseManager(this);
  late final $MediaEntriesTable mediaEntries = $MediaEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [mediaEntries];
}

typedef $$MediaEntriesTableCreateCompanionBuilder =
    MediaEntriesCompanion Function({
      required String id,
      required String playlistId,
      required String sourceReference,
      required String originalName,
      required String displayName,
      Value<String?> groupName,
      required String kind,
      Value<int> position,
      Value<String> searchName,
      Value<int> rowid,
    });
typedef $$MediaEntriesTableUpdateCompanionBuilder =
    MediaEntriesCompanion Function({
      Value<String> id,
      Value<String> playlistId,
      Value<String> sourceReference,
      Value<String> originalName,
      Value<String> displayName,
      Value<String?> groupName,
      Value<String> kind,
      Value<int> position,
      Value<String> searchName,
      Value<int> rowid,
    });

class $$MediaEntriesTableFilterComposer
    extends Composer<_$TviumDatabase, $MediaEntriesTable> {
  $$MediaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceReference => $composableBuilder(
    column: $table.sourceReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalName => $composableBuilder(
    column: $table.originalName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaEntriesTableOrderingComposer
    extends Composer<_$TviumDatabase, $MediaEntriesTable> {
  $$MediaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceReference => $composableBuilder(
    column: $table.sourceReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalName => $composableBuilder(
    column: $table.originalName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaEntriesTableAnnotationComposer
    extends Composer<_$TviumDatabase, $MediaEntriesTable> {
  $$MediaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceReference => $composableBuilder(
    column: $table.sourceReference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalName => $composableBuilder(
    column: $table.originalName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => column,
  );
}

class $$MediaEntriesTableTableManager
    extends
        RootTableManager<
          _$TviumDatabase,
          $MediaEntriesTable,
          MediaEntry,
          $$MediaEntriesTableFilterComposer,
          $$MediaEntriesTableOrderingComposer,
          $$MediaEntriesTableAnnotationComposer,
          $$MediaEntriesTableCreateCompanionBuilder,
          $$MediaEntriesTableUpdateCompanionBuilder,
          (
            MediaEntry,
            BaseReferences<_$TviumDatabase, $MediaEntriesTable, MediaEntry>,
          ),
          MediaEntry,
          PrefetchHooks Function()
        > {
  $$MediaEntriesTableTableManager(_$TviumDatabase db, $MediaEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> playlistId = const Value.absent(),
                Value<String> sourceReference = const Value.absent(),
                Value<String> originalName = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> searchName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaEntriesCompanion(
                id: id,
                playlistId: playlistId,
                sourceReference: sourceReference,
                originalName: originalName,
                displayName: displayName,
                groupName: groupName,
                kind: kind,
                position: position,
                searchName: searchName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String playlistId,
                required String sourceReference,
                required String originalName,
                required String displayName,
                Value<String?> groupName = const Value.absent(),
                required String kind,
                Value<int> position = const Value.absent(),
                Value<String> searchName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaEntriesCompanion.insert(
                id: id,
                playlistId: playlistId,
                sourceReference: sourceReference,
                originalName: originalName,
                displayName: displayName,
                groupName: groupName,
                kind: kind,
                position: position,
                searchName: searchName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MediaEntriesTable, MediaEntry>(table),
                  BaseReferences<
                    _$TviumDatabase,
                    $MediaEntriesTable,
                    MediaEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$TviumDatabase,
      $MediaEntriesTable,
      MediaEntry,
      $$MediaEntriesTableFilterComposer,
      $$MediaEntriesTableOrderingComposer,
      $$MediaEntriesTableAnnotationComposer,
      $$MediaEntriesTableCreateCompanionBuilder,
      $$MediaEntriesTableUpdateCompanionBuilder,
      (
        MediaEntry,
        BaseReferences<_$TviumDatabase, $MediaEntriesTable, MediaEntry>,
      ),
      MediaEntry,
      PrefetchHooks Function()
    >;

class $TviumDatabaseManager {
  final _$TviumDatabase _db;
  $TviumDatabaseManager(this._db);
  $$MediaEntriesTableTableManager get mediaEntries =>
      $$MediaEntriesTableTableManager(_db, _db.mediaEntries);
}
