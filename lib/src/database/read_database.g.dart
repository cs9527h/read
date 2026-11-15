// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_database.dart';

// ignore_for_file: type=lint
class $LocalBooksTable extends LocalBooks
    with TableInfo<$LocalBooksTable, LocalBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
      'format', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourcePathMeta =
      const VerificationMeta('sourcePath');
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
      'source_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contentHashMeta =
      const VerificationMeta('contentHash');
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
      'content_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastReadAtMsMeta =
      const VerificationMeta('lastReadAtMs');
  @override
  late final GeneratedColumn<int> lastReadAtMs = GeneratedColumn<int>(
      'last_read_at_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        author,
        format,
        sourcePath,
        contentHash,
        lastReadAtMs,
        deleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_books';
  @override
  VerificationContext validateIntegrity(Insertable<LocalBook> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('format')) {
      context.handle(_formatMeta,
          format.isAcceptableOrUnknown(data['format']!, _formatMeta));
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
          _sourcePathMeta,
          sourcePath.isAcceptableOrUnknown(
              data['source_path']!, _sourcePathMeta));
    }
    if (data.containsKey('content_hash')) {
      context.handle(
          _contentHashMeta,
          contentHash.isAcceptableOrUnknown(
              data['content_hash']!, _contentHashMeta));
    }
    if (data.containsKey('last_read_at_ms')) {
      context.handle(
          _lastReadAtMsMeta,
          lastReadAtMs.isAcceptableOrUnknown(
              data['last_read_at_ms']!, _lastReadAtMsMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBook(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      format: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}format'])!,
      sourcePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_path']),
      contentHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_hash']),
      lastReadAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_read_at_ms']),
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
    );
  }

  @override
  $LocalBooksTable createAlias(String alias) {
    return $LocalBooksTable(attachedDatabase, alias);
  }
}

class LocalBook extends DataClass implements Insertable<LocalBook> {
  final String id;
  final String title;
  final String author;
  final String format;
  final String? sourcePath;
  final String? contentHash;
  final int? lastReadAtMs;
  final bool deleted;
  const LocalBook(
      {required this.id,
      required this.title,
      required this.author,
      required this.format,
      this.sourcePath,
      this.contentHash,
      this.lastReadAtMs,
      required this.deleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || sourcePath != null) {
      map['source_path'] = Variable<String>(sourcePath);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || lastReadAtMs != null) {
      map['last_read_at_ms'] = Variable<int>(lastReadAtMs);
    }
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  LocalBooksCompanion toCompanion(bool nullToAbsent) {
    return LocalBooksCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
      format: Value(format),
      sourcePath: sourcePath == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePath),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      lastReadAtMs: lastReadAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAtMs),
      deleted: Value(deleted),
    );
  }

  factory LocalBook.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBook(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      format: serializer.fromJson<String>(json['format']),
      sourcePath: serializer.fromJson<String?>(json['sourcePath']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      lastReadAtMs: serializer.fromJson<int?>(json['lastReadAtMs']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'format': serializer.toJson<String>(format),
      'sourcePath': serializer.toJson<String?>(sourcePath),
      'contentHash': serializer.toJson<String?>(contentHash),
      'lastReadAtMs': serializer.toJson<int?>(lastReadAtMs),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  LocalBook copyWith(
          {String? id,
          String? title,
          String? author,
          String? format,
          Value<String?> sourcePath = const Value.absent(),
          Value<String?> contentHash = const Value.absent(),
          Value<int?> lastReadAtMs = const Value.absent(),
          bool? deleted}) =>
      LocalBook(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        format: format ?? this.format,
        sourcePath: sourcePath.present ? sourcePath.value : this.sourcePath,
        contentHash: contentHash.present ? contentHash.value : this.contentHash,
        lastReadAtMs:
            lastReadAtMs.present ? lastReadAtMs.value : this.lastReadAtMs,
        deleted: deleted ?? this.deleted,
      );
  LocalBook copyWithCompanion(LocalBooksCompanion data) {
    return LocalBook(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      format: data.format.present ? data.format.value : this.format,
      sourcePath:
          data.sourcePath.present ? data.sourcePath.value : this.sourcePath,
      contentHash:
          data.contentHash.present ? data.contentHash.value : this.contentHash,
      lastReadAtMs: data.lastReadAtMs.present
          ? data.lastReadAtMs.value
          : this.lastReadAtMs,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBook(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('contentHash: $contentHash, ')
          ..write('lastReadAtMs: $lastReadAtMs, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, author, format, sourcePath,
      contentHash, lastReadAtMs, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBook &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.format == this.format &&
          other.sourcePath == this.sourcePath &&
          other.contentHash == this.contentHash &&
          other.lastReadAtMs == this.lastReadAtMs &&
          other.deleted == this.deleted);
}

class LocalBooksCompanion extends UpdateCompanion<LocalBook> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> author;
  final Value<String> format;
  final Value<String?> sourcePath;
  final Value<String?> contentHash;
  final Value<int?> lastReadAtMs;
  final Value<bool> deleted;
  final Value<int> rowid;
  const LocalBooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.format = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.lastReadAtMs = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalBooksCompanion.insert({
    required String id,
    required String title,
    required String author,
    required String format,
    this.sourcePath = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.lastReadAtMs = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        author = Value(author),
        format = Value(format);
  static Insertable<LocalBook> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? format,
    Expression<String>? sourcePath,
    Expression<String>? contentHash,
    Expression<int>? lastReadAtMs,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (format != null) 'format': format,
      if (sourcePath != null) 'source_path': sourcePath,
      if (contentHash != null) 'content_hash': contentHash,
      if (lastReadAtMs != null) 'last_read_at_ms': lastReadAtMs,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalBooksCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? author,
      Value<String>? format,
      Value<String?>? sourcePath,
      Value<String?>? contentHash,
      Value<int?>? lastReadAtMs,
      Value<bool>? deleted,
      Value<int>? rowid}) {
    return LocalBooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format ?? this.format,
      sourcePath: sourcePath ?? this.sourcePath,
      contentHash: contentHash ?? this.contentHash,
      lastReadAtMs: lastReadAtMs ?? this.lastReadAtMs,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (lastReadAtMs.present) {
      map['last_read_at_ms'] = Variable<int>(lastReadAtMs.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('contentHash: $contentHash, ')
          ..write('lastReadAtMs: $lastReadAtMs, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingPositionsTable extends ReadingPositions
    with TableInfo<$ReadingPositionsTable, ReadingPosition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIndexMeta =
      const VerificationMeta('chapterIndex');
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
      'chapter_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _pageIndexMeta =
      const VerificationMeta('pageIndex');
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
      'page_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _charOffsetMeta =
      const VerificationMeta('charOffset');
  @override
  late final GeneratedColumn<int> charOffset = GeneratedColumn<int>(
      'char_offset', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(-1));
  static const VerificationMeta _revisionMeta =
      const VerificationMeta('revision');
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
      'revision', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('legacy'));
  static const VerificationMeta _modifiedAtMsMeta =
      const VerificationMeta('modifiedAtMs');
  @override
  late final GeneratedColumn<int> modifiedAtMs = GeneratedColumn<int>(
      'modified_at_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        bookId,
        chapterIndex,
        pageIndex,
        charOffset,
        revision,
        deviceId,
        modifiedAtMs,
        deleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_positions';
  @override
  VerificationContext validateIntegrity(Insertable<ReadingPosition> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
          _chapterIndexMeta,
          chapterIndex.isAcceptableOrUnknown(
              data['chapter_index']!, _chapterIndexMeta));
    }
    if (data.containsKey('page_index')) {
      context.handle(_pageIndexMeta,
          pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta));
    }
    if (data.containsKey('char_offset')) {
      context.handle(
          _charOffsetMeta,
          charOffset.isAcceptableOrUnknown(
              data['char_offset']!, _charOffsetMeta));
    }
    if (data.containsKey('revision')) {
      context.handle(_revisionMeta,
          revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    }
    if (data.containsKey('modified_at_ms')) {
      context.handle(
          _modifiedAtMsMeta,
          modifiedAtMs.isAcceptableOrUnknown(
              data['modified_at_ms']!, _modifiedAtMsMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingPosition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingPosition(
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      chapterIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_index'])!,
      pageIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_index'])!,
      charOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}char_offset'])!,
      revision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}revision'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      modifiedAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}modified_at_ms'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
    );
  }

  @override
  $ReadingPositionsTable createAlias(String alias) {
    return $ReadingPositionsTable(attachedDatabase, alias);
  }
}

class ReadingPosition extends DataClass implements Insertable<ReadingPosition> {
  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final int charOffset;
  final int revision;
  final String deviceId;
  final int modifiedAtMs;
  final bool deleted;
  const ReadingPosition(
      {required this.bookId,
      required this.chapterIndex,
      required this.pageIndex,
      required this.charOffset,
      required this.revision,
      required this.deviceId,
      required this.modifiedAtMs,
      required this.deleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['page_index'] = Variable<int>(pageIndex);
    map['char_offset'] = Variable<int>(charOffset);
    map['revision'] = Variable<int>(revision);
    map['device_id'] = Variable<String>(deviceId);
    map['modified_at_ms'] = Variable<int>(modifiedAtMs);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  ReadingPositionsCompanion toCompanion(bool nullToAbsent) {
    return ReadingPositionsCompanion(
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      pageIndex: Value(pageIndex),
      charOffset: Value(charOffset),
      revision: Value(revision),
      deviceId: Value(deviceId),
      modifiedAtMs: Value(modifiedAtMs),
      deleted: Value(deleted),
    );
  }

  factory ReadingPosition.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingPosition(
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      charOffset: serializer.fromJson<int>(json['charOffset']),
      revision: serializer.fromJson<int>(json['revision']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      modifiedAtMs: serializer.fromJson<int>(json['modifiedAtMs']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'charOffset': serializer.toJson<int>(charOffset),
      'revision': serializer.toJson<int>(revision),
      'deviceId': serializer.toJson<String>(deviceId),
      'modifiedAtMs': serializer.toJson<int>(modifiedAtMs),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  ReadingPosition copyWith(
          {String? bookId,
          int? chapterIndex,
          int? pageIndex,
          int? charOffset,
          int? revision,
          String? deviceId,
          int? modifiedAtMs,
          bool? deleted}) =>
      ReadingPosition(
        bookId: bookId ?? this.bookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        pageIndex: pageIndex ?? this.pageIndex,
        charOffset: charOffset ?? this.charOffset,
        revision: revision ?? this.revision,
        deviceId: deviceId ?? this.deviceId,
        modifiedAtMs: modifiedAtMs ?? this.modifiedAtMs,
        deleted: deleted ?? this.deleted,
      );
  ReadingPosition copyWithCompanion(ReadingPositionsCompanion data) {
    return ReadingPosition(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      charOffset:
          data.charOffset.present ? data.charOffset.value : this.charOffset,
      revision: data.revision.present ? data.revision.value : this.revision,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      modifiedAtMs: data.modifiedAtMs.present
          ? data.modifiedAtMs.value
          : this.modifiedAtMs,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingPosition(')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('charOffset: $charOffset, ')
          ..write('revision: $revision, ')
          ..write('deviceId: $deviceId, ')
          ..write('modifiedAtMs: $modifiedAtMs, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, chapterIndex, pageIndex, charOffset,
      revision, deviceId, modifiedAtMs, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingPosition &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.pageIndex == this.pageIndex &&
          other.charOffset == this.charOffset &&
          other.revision == this.revision &&
          other.deviceId == this.deviceId &&
          other.modifiedAtMs == this.modifiedAtMs &&
          other.deleted == this.deleted);
}

class ReadingPositionsCompanion extends UpdateCompanion<ReadingPosition> {
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<int> pageIndex;
  final Value<int> charOffset;
  final Value<int> revision;
  final Value<String> deviceId;
  final Value<int> modifiedAtMs;
  final Value<bool> deleted;
  final Value<int> rowid;
  const ReadingPositionsCompanion({
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.charOffset = const Value.absent(),
    this.revision = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.modifiedAtMs = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingPositionsCompanion.insert({
    required String bookId,
    this.chapterIndex = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.charOffset = const Value.absent(),
    this.revision = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.modifiedAtMs = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId);
  static Insertable<ReadingPosition> custom({
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<int>? pageIndex,
    Expression<int>? charOffset,
    Expression<int>? revision,
    Expression<String>? deviceId,
    Expression<int>? modifiedAtMs,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (pageIndex != null) 'page_index': pageIndex,
      if (charOffset != null) 'char_offset': charOffset,
      if (revision != null) 'revision': revision,
      if (deviceId != null) 'device_id': deviceId,
      if (modifiedAtMs != null) 'modified_at_ms': modifiedAtMs,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingPositionsCompanion copyWith(
      {Value<String>? bookId,
      Value<int>? chapterIndex,
      Value<int>? pageIndex,
      Value<int>? charOffset,
      Value<int>? revision,
      Value<String>? deviceId,
      Value<int>? modifiedAtMs,
      Value<bool>? deleted,
      Value<int>? rowid}) {
    return ReadingPositionsCompanion(
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      pageIndex: pageIndex ?? this.pageIndex,
      charOffset: charOffset ?? this.charOffset,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      modifiedAtMs: modifiedAtMs ?? this.modifiedAtMs,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (charOffset.present) {
      map['char_offset'] = Variable<int>(charOffset.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (modifiedAtMs.present) {
      map['modified_at_ms'] = Variable<int>(modifiedAtMs.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingPositionsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('charOffset: $charOffset, ')
          ..write('revision: $revision, ')
          ..write('deviceId: $deviceId, ')
          ..write('modifiedAtMs: $modifiedAtMs, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalBookmarksTable extends LocalBookmarks
    with TableInfo<$LocalBookmarksTable, LocalBookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIndexMeta =
      const VerificationMeta('chapterIndex');
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
      'chapter_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _charOffsetMeta =
      const VerificationMeta('charOffset');
  @override
  late final GeneratedColumn<int> charOffset = GeneratedColumn<int>(
      'char_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _revisionMeta =
      const VerificationMeta('revision');
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
      'revision', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local'));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bookId,
        chapterIndex,
        charOffset,
        label,
        revision,
        deviceId,
        deleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_bookmarks';
  @override
  VerificationContext validateIntegrity(Insertable<LocalBookmark> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
          _chapterIndexMeta,
          chapterIndex.isAcceptableOrUnknown(
              data['chapter_index']!, _chapterIndexMeta));
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('char_offset')) {
      context.handle(
          _charOffsetMeta,
          charOffset.isAcceptableOrUnknown(
              data['char_offset']!, _charOffsetMeta));
    } else if (isInserting) {
      context.missing(_charOffsetMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    }
    if (data.containsKey('revision')) {
      context.handle(_revisionMeta,
          revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBookmark(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      chapterIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_index'])!,
      charOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}char_offset'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      revision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}revision'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
    );
  }

  @override
  $LocalBookmarksTable createAlias(String alias) {
    return $LocalBookmarksTable(attachedDatabase, alias);
  }
}

class LocalBookmark extends DataClass implements Insertable<LocalBookmark> {
  final String id;
  final String bookId;
  final int chapterIndex;
  final int charOffset;
  final String label;
  final int revision;
  final String deviceId;
  final bool deleted;
  const LocalBookmark(
      {required this.id,
      required this.bookId,
      required this.chapterIndex,
      required this.charOffset,
      required this.label,
      required this.revision,
      required this.deviceId,
      required this.deleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['char_offset'] = Variable<int>(charOffset);
    map['label'] = Variable<String>(label);
    map['revision'] = Variable<int>(revision);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  LocalBookmarksCompanion toCompanion(bool nullToAbsent) {
    return LocalBookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      charOffset: Value(charOffset),
      label: Value(label),
      revision: Value(revision),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
    );
  }

  factory LocalBookmark.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBookmark(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      charOffset: serializer.fromJson<int>(json['charOffset']),
      label: serializer.fromJson<String>(json['label']),
      revision: serializer.fromJson<int>(json['revision']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'charOffset': serializer.toJson<int>(charOffset),
      'label': serializer.toJson<String>(label),
      'revision': serializer.toJson<int>(revision),
      'deviceId': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  LocalBookmark copyWith(
          {String? id,
          String? bookId,
          int? chapterIndex,
          int? charOffset,
          String? label,
          int? revision,
          String? deviceId,
          bool? deleted}) =>
      LocalBookmark(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        charOffset: charOffset ?? this.charOffset,
        label: label ?? this.label,
        revision: revision ?? this.revision,
        deviceId: deviceId ?? this.deviceId,
        deleted: deleted ?? this.deleted,
      );
  LocalBookmark copyWithCompanion(LocalBookmarksCompanion data) {
    return LocalBookmark(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      charOffset:
          data.charOffset.present ? data.charOffset.value : this.charOffset,
      label: data.label.present ? data.label.value : this.label,
      revision: data.revision.present ? data.revision.value : this.revision,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBookmark(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('charOffset: $charOffset, ')
          ..write('label: $label, ')
          ..write('revision: $revision, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, bookId, chapterIndex, charOffset, label, revision, deviceId, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBookmark &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.charOffset == this.charOffset &&
          other.label == this.label &&
          other.revision == this.revision &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted);
}

class LocalBookmarksCompanion extends UpdateCompanion<LocalBookmark> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<int> charOffset;
  final Value<String> label;
  final Value<int> revision;
  final Value<String> deviceId;
  final Value<bool> deleted;
  final Value<int> rowid;
  const LocalBookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.charOffset = const Value.absent(),
    this.label = const Value.absent(),
    this.revision = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalBookmarksCompanion.insert({
    required String id,
    required String bookId,
    required int chapterIndex,
    required int charOffset,
    this.label = const Value.absent(),
    this.revision = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        bookId = Value(bookId),
        chapterIndex = Value(chapterIndex),
        charOffset = Value(charOffset);
  static Insertable<LocalBookmark> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<int>? charOffset,
    Expression<String>? label,
    Expression<int>? revision,
    Expression<String>? deviceId,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (charOffset != null) 'char_offset': charOffset,
      if (label != null) 'label': label,
      if (revision != null) 'revision': revision,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalBookmarksCompanion copyWith(
      {Value<String>? id,
      Value<String>? bookId,
      Value<int>? chapterIndex,
      Value<int>? charOffset,
      Value<String>? label,
      Value<int>? revision,
      Value<String>? deviceId,
      Value<bool>? deleted,
      Value<int>? rowid}) {
    return LocalBookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      charOffset: charOffset ?? this.charOffset,
      label: label ?? this.label,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (charOffset.present) {
      map['char_offset'] = Variable<int>(charOffset.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('charOffset: $charOffset, ')
          ..write('label: $label, ')
          ..write('revision: $revision, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalNotesTable extends LocalNotes
    with TableInfo<$LocalNotesTable, LocalNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startOffsetMeta =
      const VerificationMeta('startOffset');
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
      'start_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _endOffsetMeta =
      const VerificationMeta('endOffset');
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
      'end_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _noteTextMeta =
      const VerificationMeta('noteText');
  @override
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
      'note_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _excerptMeta =
      const VerificationMeta('excerpt');
  @override
  late final GeneratedColumn<String> excerpt = GeneratedColumn<String>(
      'excerpt', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _revisionMeta =
      const VerificationMeta('revision');
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
      'revision', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local'));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bookId,
        startOffset,
        endOffset,
        noteText,
        excerpt,
        revision,
        deviceId,
        deleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_notes';
  @override
  VerificationContext validateIntegrity(Insertable<LocalNote> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
          _startOffsetMeta,
          startOffset.isAcceptableOrUnknown(
              data['start_offset']!, _startOffsetMeta));
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(_endOffsetMeta,
          endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta));
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('note_text')) {
      context.handle(_noteTextMeta,
          noteText.isAcceptableOrUnknown(data['note_text']!, _noteTextMeta));
    } else if (isInserting) {
      context.missing(_noteTextMeta);
    }
    if (data.containsKey('excerpt')) {
      context.handle(_excerptMeta,
          excerpt.isAcceptableOrUnknown(data['excerpt']!, _excerptMeta));
    }
    if (data.containsKey('revision')) {
      context.handle(_revisionMeta,
          revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalNote(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      startOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_offset'])!,
      endOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_offset'])!,
      noteText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note_text'])!,
      excerpt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}excerpt'])!,
      revision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}revision'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
    );
  }

  @override
  $LocalNotesTable createAlias(String alias) {
    return $LocalNotesTable(attachedDatabase, alias);
  }
}

class LocalNote extends DataClass implements Insertable<LocalNote> {
  final String id;
  final String bookId;
  final int startOffset;
  final int endOffset;
  final String noteText;
  final String excerpt;
  final int revision;
  final String deviceId;
  final bool deleted;
  const LocalNote(
      {required this.id,
      required this.bookId,
      required this.startOffset,
      required this.endOffset,
      required this.noteText,
      required this.excerpt,
      required this.revision,
      required this.deviceId,
      required this.deleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    map['note_text'] = Variable<String>(noteText);
    map['excerpt'] = Variable<String>(excerpt);
    map['revision'] = Variable<int>(revision);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  LocalNotesCompanion toCompanion(bool nullToAbsent) {
    return LocalNotesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      noteText: Value(noteText),
      excerpt: Value(excerpt),
      revision: Value(revision),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
    );
  }

  factory LocalNote.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNote(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      noteText: serializer.fromJson<String>(json['noteText']),
      excerpt: serializer.fromJson<String>(json['excerpt']),
      revision: serializer.fromJson<int>(json['revision']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'noteText': serializer.toJson<String>(noteText),
      'excerpt': serializer.toJson<String>(excerpt),
      'revision': serializer.toJson<int>(revision),
      'deviceId': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  LocalNote copyWith(
          {String? id,
          String? bookId,
          int? startOffset,
          int? endOffset,
          String? noteText,
          String? excerpt,
          int? revision,
          String? deviceId,
          bool? deleted}) =>
      LocalNote(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        startOffset: startOffset ?? this.startOffset,
        endOffset: endOffset ?? this.endOffset,
        noteText: noteText ?? this.noteText,
        excerpt: excerpt ?? this.excerpt,
        revision: revision ?? this.revision,
        deviceId: deviceId ?? this.deviceId,
        deleted: deleted ?? this.deleted,
      );
  LocalNote copyWithCompanion(LocalNotesCompanion data) {
    return LocalNote(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      startOffset:
          data.startOffset.present ? data.startOffset.value : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      noteText: data.noteText.present ? data.noteText.value : this.noteText,
      excerpt: data.excerpt.present ? data.excerpt.value : this.excerpt,
      revision: data.revision.present ? data.revision.value : this.revision,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNote(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('noteText: $noteText, ')
          ..write('excerpt: $excerpt, ')
          ..write('revision: $revision, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, startOffset, endOffset, noteText,
      excerpt, revision, deviceId, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNote &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.noteText == this.noteText &&
          other.excerpt == this.excerpt &&
          other.revision == this.revision &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted);
}

class LocalNotesCompanion extends UpdateCompanion<LocalNote> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<String> noteText;
  final Value<String> excerpt;
  final Value<int> revision;
  final Value<String> deviceId;
  final Value<bool> deleted;
  final Value<int> rowid;
  const LocalNotesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.noteText = const Value.absent(),
    this.excerpt = const Value.absent(),
    this.revision = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNotesCompanion.insert({
    required String id,
    required String bookId,
    required int startOffset,
    required int endOffset,
    required String noteText,
    this.excerpt = const Value.absent(),
    this.revision = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        bookId = Value(bookId),
        startOffset = Value(startOffset),
        endOffset = Value(endOffset),
        noteText = Value(noteText);
  static Insertable<LocalNote> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<String>? noteText,
    Expression<String>? excerpt,
    Expression<int>? revision,
    Expression<String>? deviceId,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (noteText != null) 'note_text': noteText,
      if (excerpt != null) 'excerpt': excerpt,
      if (revision != null) 'revision': revision,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNotesCompanion copyWith(
      {Value<String>? id,
      Value<String>? bookId,
      Value<int>? startOffset,
      Value<int>? endOffset,
      Value<String>? noteText,
      Value<String>? excerpt,
      Value<int>? revision,
      Value<String>? deviceId,
      Value<bool>? deleted,
      Value<int>? rowid}) {
    return LocalNotesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      noteText: noteText ?? this.noteText,
      excerpt: excerpt ?? this.excerpt,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (noteText.present) {
      map['note_text'] = Variable<String>(noteText.value);
    }
    if (excerpt.present) {
      map['excerpt'] = Variable<String>(excerpt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalNotesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('noteText: $noteText, ')
          ..write('excerpt: $excerpt, ')
          ..write('revision: $revision, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncJournalTable extends SyncJournal
    with TableInfo<$SyncJournalTable, SyncJournalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncJournalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _revisionMeta =
      const VerificationMeta('revision');
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
      'revision', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serializedMeta =
      const VerificationMeta('serialized');
  @override
  late final GeneratedColumn<String> serialized = GeneratedColumn<String>(
      'serialized', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMsMeta =
      const VerificationMeta('createdAtMs');
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
      'created_at_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedMeta =
      const VerificationMeta('completed');
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
      'completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, kind, revision, deviceId, serialized, createdAtMs, completed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_journal';
  @override
  VerificationContext validateIntegrity(Insertable<SyncJournalData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(_revisionMeta,
          revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta));
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('serialized')) {
      context.handle(
          _serializedMeta,
          serialized.isAcceptableOrUnknown(
              data['serialized']!, _serializedMeta));
    } else if (isInserting) {
      context.missing(_serializedMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
          _createdAtMsMeta,
          createdAtMs.isAcceptableOrUnknown(
              data['created_at_ms']!, _createdAtMsMeta));
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(_completedMeta,
          completed.isAcceptableOrUnknown(data['completed']!, _completedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncJournalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncJournalData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      revision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}revision'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      serialized: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serialized'])!,
      createdAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at_ms'])!,
      completed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}completed'])!,
    );
  }

  @override
  $SyncJournalTable createAlias(String alias) {
    return $SyncJournalTable(attachedDatabase, alias);
  }
}

class SyncJournalData extends DataClass implements Insertable<SyncJournalData> {
  final String id;
  final String kind;
  final int revision;
  final String deviceId;
  final String serialized;
  final int createdAtMs;
  final bool completed;
  const SyncJournalData(
      {required this.id,
      required this.kind,
      required this.revision,
      required this.deviceId,
      required this.serialized,
      required this.createdAtMs,
      required this.completed});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['revision'] = Variable<int>(revision);
    map['device_id'] = Variable<String>(deviceId);
    map['serialized'] = Variable<String>(serialized);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  SyncJournalCompanion toCompanion(bool nullToAbsent) {
    return SyncJournalCompanion(
      id: Value(id),
      kind: Value(kind),
      revision: Value(revision),
      deviceId: Value(deviceId),
      serialized: Value(serialized),
      createdAtMs: Value(createdAtMs),
      completed: Value(completed),
    );
  }

  factory SyncJournalData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncJournalData(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      revision: serializer.fromJson<int>(json['revision']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      serialized: serializer.fromJson<String>(json['serialized']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'revision': serializer.toJson<int>(revision),
      'deviceId': serializer.toJson<String>(deviceId),
      'serialized': serializer.toJson<String>(serialized),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  SyncJournalData copyWith(
          {String? id,
          String? kind,
          int? revision,
          String? deviceId,
          String? serialized,
          int? createdAtMs,
          bool? completed}) =>
      SyncJournalData(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        revision: revision ?? this.revision,
        deviceId: deviceId ?? this.deviceId,
        serialized: serialized ?? this.serialized,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        completed: completed ?? this.completed,
      );
  SyncJournalData copyWithCompanion(SyncJournalCompanion data) {
    return SyncJournalData(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      revision: data.revision.present ? data.revision.value : this.revision,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      serialized:
          data.serialized.present ? data.serialized.value : this.serialized,
      createdAtMs:
          data.createdAtMs.present ? data.createdAtMs.value : this.createdAtMs,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncJournalData(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('revision: $revision, ')
          ..write('deviceId: $deviceId, ')
          ..write('serialized: $serialized, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, kind, revision, deviceId, serialized, createdAtMs, completed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncJournalData &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.revision == this.revision &&
          other.deviceId == this.deviceId &&
          other.serialized == this.serialized &&
          other.createdAtMs == this.createdAtMs &&
          other.completed == this.completed);
}

class SyncJournalCompanion extends UpdateCompanion<SyncJournalData> {
  final Value<String> id;
  final Value<String> kind;
  final Value<int> revision;
  final Value<String> deviceId;
  final Value<String> serialized;
  final Value<int> createdAtMs;
  final Value<bool> completed;
  final Value<int> rowid;
  const SyncJournalCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.revision = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.serialized = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncJournalCompanion.insert({
    required String id,
    required String kind,
    required int revision,
    required String deviceId,
    required String serialized,
    required int createdAtMs,
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        kind = Value(kind),
        revision = Value(revision),
        deviceId = Value(deviceId),
        serialized = Value(serialized),
        createdAtMs = Value(createdAtMs);
  static Insertable<SyncJournalData> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<int>? revision,
    Expression<String>? deviceId,
    Expression<String>? serialized,
    Expression<int>? createdAtMs,
    Expression<bool>? completed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (revision != null) 'revision': revision,
      if (deviceId != null) 'device_id': deviceId,
      if (serialized != null) 'serialized': serialized,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (completed != null) 'completed': completed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncJournalCompanion copyWith(
      {Value<String>? id,
      Value<String>? kind,
      Value<int>? revision,
      Value<String>? deviceId,
      Value<String>? serialized,
      Value<int>? createdAtMs,
      Value<bool>? completed,
      Value<int>? rowid}) {
    return SyncJournalCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      serialized: serialized ?? this.serialized,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      completed: completed ?? this.completed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (serialized.present) {
      map['serialized'] = Variable<String>(serialized.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncJournalCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('revision: $revision, ')
          ..write('deviceId: $deviceId, ')
          ..write('serialized: $serialized, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('completed: $completed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ReadDatabase extends GeneratedDatabase {
  _$ReadDatabase(QueryExecutor e) : super(e);
  $ReadDatabaseManager get managers => $ReadDatabaseManager(this);
  late final $LocalBooksTable localBooks = $LocalBooksTable(this);
  late final $ReadingPositionsTable readingPositions =
      $ReadingPositionsTable(this);
  late final $LocalBookmarksTable localBookmarks = $LocalBookmarksTable(this);
  late final $LocalNotesTable localNotes = $LocalNotesTable(this);
  late final $SyncJournalTable syncJournal = $SyncJournalTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [localBooks, readingPositions, localBookmarks, localNotes, syncJournal];
}

typedef $$LocalBooksTableCreateCompanionBuilder = LocalBooksCompanion Function({
  required String id,
  required String title,
  required String author,
  required String format,
  Value<String?> sourcePath,
  Value<String?> contentHash,
  Value<int?> lastReadAtMs,
  Value<bool> deleted,
  Value<int> rowid,
});
typedef $$LocalBooksTableUpdateCompanionBuilder = LocalBooksCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> author,
  Value<String> format,
  Value<String?> sourcePath,
  Value<String?> contentHash,
  Value<int?> lastReadAtMs,
  Value<bool> deleted,
  Value<int> rowid,
});

class $$LocalBooksTableFilterComposer
    extends Composer<_$ReadDatabase, $LocalBooksTable> {
  $$LocalBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourcePath => $composableBuilder(
      column: $table.sourcePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastReadAtMs => $composableBuilder(
      column: $table.lastReadAtMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));
}

class $$LocalBooksTableOrderingComposer
    extends Composer<_$ReadDatabase, $LocalBooksTable> {
  $$LocalBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourcePath => $composableBuilder(
      column: $table.sourcePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastReadAtMs => $composableBuilder(
      column: $table.lastReadAtMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));
}

class $$LocalBooksTableAnnotationComposer
    extends Composer<_$ReadDatabase, $LocalBooksTable> {
  $$LocalBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
      column: $table.sourcePath, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => column);

  GeneratedColumn<int> get lastReadAtMs => $composableBuilder(
      column: $table.lastReadAtMs, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$LocalBooksTableTableManager extends RootTableManager<
    _$ReadDatabase,
    $LocalBooksTable,
    LocalBook,
    $$LocalBooksTableFilterComposer,
    $$LocalBooksTableOrderingComposer,
    $$LocalBooksTableAnnotationComposer,
    $$LocalBooksTableCreateCompanionBuilder,
    $$LocalBooksTableUpdateCompanionBuilder,
    (LocalBook, BaseReferences<_$ReadDatabase, $LocalBooksTable, LocalBook>),
    LocalBook,
    PrefetchHooks Function()> {
  $$LocalBooksTableTableManager(_$ReadDatabase db, $LocalBooksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> format = const Value.absent(),
            Value<String?> sourcePath = const Value.absent(),
            Value<String?> contentHash = const Value.absent(),
            Value<int?> lastReadAtMs = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalBooksCompanion(
            id: id,
            title: title,
            author: author,
            format: format,
            sourcePath: sourcePath,
            contentHash: contentHash,
            lastReadAtMs: lastReadAtMs,
            deleted: deleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String author,
            required String format,
            Value<String?> sourcePath = const Value.absent(),
            Value<String?> contentHash = const Value.absent(),
            Value<int?> lastReadAtMs = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalBooksCompanion.insert(
            id: id,
            title: title,
            author: author,
            format: format,
            sourcePath: sourcePath,
            contentHash: contentHash,
            lastReadAtMs: lastReadAtMs,
            deleted: deleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalBooksTable, LocalBook>(table),
                    BaseReferences<_$ReadDatabase, $LocalBooksTable, LocalBook>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalBooksTableProcessedTableManager = ProcessedTableManager<
    _$ReadDatabase,
    $LocalBooksTable,
    LocalBook,
    $$LocalBooksTableFilterComposer,
    $$LocalBooksTableOrderingComposer,
    $$LocalBooksTableAnnotationComposer,
    $$LocalBooksTableCreateCompanionBuilder,
    $$LocalBooksTableUpdateCompanionBuilder,
    (LocalBook, BaseReferences<_$ReadDatabase, $LocalBooksTable, LocalBook>),
    LocalBook,
    PrefetchHooks Function()>;
typedef $$ReadingPositionsTableCreateCompanionBuilder
    = ReadingPositionsCompanion Function({
  required String bookId,
  Value<int> chapterIndex,
  Value<int> pageIndex,
  Value<int> charOffset,
  Value<int> revision,
  Value<String> deviceId,
  Value<int> modifiedAtMs,
  Value<bool> deleted,
  Value<int> rowid,
});
typedef $$ReadingPositionsTableUpdateCompanionBuilder
    = ReadingPositionsCompanion Function({
  Value<String> bookId,
  Value<int> chapterIndex,
  Value<int> pageIndex,
  Value<int> charOffset,
  Value<int> revision,
  Value<String> deviceId,
  Value<int> modifiedAtMs,
  Value<bool> deleted,
  Value<int> rowid,
});

class $$ReadingPositionsTableFilterComposer
    extends Composer<_$ReadDatabase, $ReadingPositionsTable> {
  $$ReadingPositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageIndex => $composableBuilder(
      column: $table.pageIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get charOffset => $composableBuilder(
      column: $table.charOffset, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get modifiedAtMs => $composableBuilder(
      column: $table.modifiedAtMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));
}

class $$ReadingPositionsTableOrderingComposer
    extends Composer<_$ReadDatabase, $ReadingPositionsTable> {
  $$ReadingPositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageIndex => $composableBuilder(
      column: $table.pageIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get charOffset => $composableBuilder(
      column: $table.charOffset, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get modifiedAtMs => $composableBuilder(
      column: $table.modifiedAtMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));
}

class $$ReadingPositionsTableAnnotationComposer
    extends Composer<_$ReadDatabase, $ReadingPositionsTable> {
  $$ReadingPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<int> get charOffset => $composableBuilder(
      column: $table.charOffset, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get modifiedAtMs => $composableBuilder(
      column: $table.modifiedAtMs, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$ReadingPositionsTableTableManager extends RootTableManager<
    _$ReadDatabase,
    $ReadingPositionsTable,
    ReadingPosition,
    $$ReadingPositionsTableFilterComposer,
    $$ReadingPositionsTableOrderingComposer,
    $$ReadingPositionsTableAnnotationComposer,
    $$ReadingPositionsTableCreateCompanionBuilder,
    $$ReadingPositionsTableUpdateCompanionBuilder,
    (
      ReadingPosition,
      BaseReferences<_$ReadDatabase, $ReadingPositionsTable, ReadingPosition>
    ),
    ReadingPosition,
    PrefetchHooks Function()> {
  $$ReadingPositionsTableTableManager(
      _$ReadDatabase db, $ReadingPositionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingPositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingPositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingPositionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> bookId = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<int> pageIndex = const Value.absent(),
            Value<int> charOffset = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<int> modifiedAtMs = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadingPositionsCompanion(
            bookId: bookId,
            chapterIndex: chapterIndex,
            pageIndex: pageIndex,
            charOffset: charOffset,
            revision: revision,
            deviceId: deviceId,
            modifiedAtMs: modifiedAtMs,
            deleted: deleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String bookId,
            Value<int> chapterIndex = const Value.absent(),
            Value<int> pageIndex = const Value.absent(),
            Value<int> charOffset = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<int> modifiedAtMs = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadingPositionsCompanion.insert(
            bookId: bookId,
            chapterIndex: chapterIndex,
            pageIndex: pageIndex,
            charOffset: charOffset,
            revision: revision,
            deviceId: deviceId,
            modifiedAtMs: modifiedAtMs,
            deleted: deleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ReadingPositionsTable, ReadingPosition>(table),
                    BaseReferences<_$ReadDatabase, $ReadingPositionsTable,
                        ReadingPosition>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReadingPositionsTableProcessedTableManager = ProcessedTableManager<
    _$ReadDatabase,
    $ReadingPositionsTable,
    ReadingPosition,
    $$ReadingPositionsTableFilterComposer,
    $$ReadingPositionsTableOrderingComposer,
    $$ReadingPositionsTableAnnotationComposer,
    $$ReadingPositionsTableCreateCompanionBuilder,
    $$ReadingPositionsTableUpdateCompanionBuilder,
    (
      ReadingPosition,
      BaseReferences<_$ReadDatabase, $ReadingPositionsTable, ReadingPosition>
    ),
    ReadingPosition,
    PrefetchHooks Function()>;
typedef $$LocalBookmarksTableCreateCompanionBuilder = LocalBookmarksCompanion
    Function({
  required String id,
  required String bookId,
  required int chapterIndex,
  required int charOffset,
  Value<String> label,
  Value<int> revision,
  Value<String> deviceId,
  Value<bool> deleted,
  Value<int> rowid,
});
typedef $$LocalBookmarksTableUpdateCompanionBuilder = LocalBookmarksCompanion
    Function({
  Value<String> id,
  Value<String> bookId,
  Value<int> chapterIndex,
  Value<int> charOffset,
  Value<String> label,
  Value<int> revision,
  Value<String> deviceId,
  Value<bool> deleted,
  Value<int> rowid,
});

class $$LocalBookmarksTableFilterComposer
    extends Composer<_$ReadDatabase, $LocalBookmarksTable> {
  $$LocalBookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get charOffset => $composableBuilder(
      column: $table.charOffset, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));
}

class $$LocalBookmarksTableOrderingComposer
    extends Composer<_$ReadDatabase, $LocalBookmarksTable> {
  $$LocalBookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get charOffset => $composableBuilder(
      column: $table.charOffset, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));
}

class $$LocalBookmarksTableAnnotationComposer
    extends Composer<_$ReadDatabase, $LocalBookmarksTable> {
  $$LocalBookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
      column: $table.chapterIndex, builder: (column) => column);

  GeneratedColumn<int> get charOffset => $composableBuilder(
      column: $table.charOffset, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$LocalBookmarksTableTableManager extends RootTableManager<
    _$ReadDatabase,
    $LocalBookmarksTable,
    LocalBookmark,
    $$LocalBookmarksTableFilterComposer,
    $$LocalBookmarksTableOrderingComposer,
    $$LocalBookmarksTableAnnotationComposer,
    $$LocalBookmarksTableCreateCompanionBuilder,
    $$LocalBookmarksTableUpdateCompanionBuilder,
    (
      LocalBookmark,
      BaseReferences<_$ReadDatabase, $LocalBookmarksTable, LocalBookmark>
    ),
    LocalBookmark,
    PrefetchHooks Function()> {
  $$LocalBookmarksTableTableManager(
      _$ReadDatabase db, $LocalBookmarksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<int> chapterIndex = const Value.absent(),
            Value<int> charOffset = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalBookmarksCompanion(
            id: id,
            bookId: bookId,
            chapterIndex: chapterIndex,
            charOffset: charOffset,
            label: label,
            revision: revision,
            deviceId: deviceId,
            deleted: deleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String bookId,
            required int chapterIndex,
            required int charOffset,
            Value<String> label = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalBookmarksCompanion.insert(
            id: id,
            bookId: bookId,
            chapterIndex: chapterIndex,
            charOffset: charOffset,
            label: label,
            revision: revision,
            deviceId: deviceId,
            deleted: deleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalBookmarksTable, LocalBookmark>(table),
                    BaseReferences<_$ReadDatabase, $LocalBookmarksTable,
                        LocalBookmark>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalBookmarksTableProcessedTableManager = ProcessedTableManager<
    _$ReadDatabase,
    $LocalBookmarksTable,
    LocalBookmark,
    $$LocalBookmarksTableFilterComposer,
    $$LocalBookmarksTableOrderingComposer,
    $$LocalBookmarksTableAnnotationComposer,
    $$LocalBookmarksTableCreateCompanionBuilder,
    $$LocalBookmarksTableUpdateCompanionBuilder,
    (
      LocalBookmark,
      BaseReferences<_$ReadDatabase, $LocalBookmarksTable, LocalBookmark>
    ),
    LocalBookmark,
    PrefetchHooks Function()>;
typedef $$LocalNotesTableCreateCompanionBuilder = LocalNotesCompanion Function({
  required String id,
  required String bookId,
  required int startOffset,
  required int endOffset,
  required String noteText,
  Value<String> excerpt,
  Value<int> revision,
  Value<String> deviceId,
  Value<bool> deleted,
  Value<int> rowid,
});
typedef $$LocalNotesTableUpdateCompanionBuilder = LocalNotesCompanion Function({
  Value<String> id,
  Value<String> bookId,
  Value<int> startOffset,
  Value<int> endOffset,
  Value<String> noteText,
  Value<String> excerpt,
  Value<int> revision,
  Value<String> deviceId,
  Value<bool> deleted,
  Value<int> rowid,
});

class $$LocalNotesTableFilterComposer
    extends Composer<_$ReadDatabase, $LocalNotesTable> {
  $$LocalNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startOffset => $composableBuilder(
      column: $table.startOffset, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endOffset => $composableBuilder(
      column: $table.endOffset, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get noteText => $composableBuilder(
      column: $table.noteText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get excerpt => $composableBuilder(
      column: $table.excerpt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));
}

class $$LocalNotesTableOrderingComposer
    extends Composer<_$ReadDatabase, $LocalNotesTable> {
  $$LocalNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startOffset => $composableBuilder(
      column: $table.startOffset, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endOffset => $composableBuilder(
      column: $table.endOffset, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get noteText => $composableBuilder(
      column: $table.noteText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get excerpt => $composableBuilder(
      column: $table.excerpt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));
}

class $$LocalNotesTableAnnotationComposer
    extends Composer<_$ReadDatabase, $LocalNotesTable> {
  $$LocalNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get startOffset => $composableBuilder(
      column: $table.startOffset, builder: (column) => column);

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<String> get noteText =>
      $composableBuilder(column: $table.noteText, builder: (column) => column);

  GeneratedColumn<String> get excerpt =>
      $composableBuilder(column: $table.excerpt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$LocalNotesTableTableManager extends RootTableManager<
    _$ReadDatabase,
    $LocalNotesTable,
    LocalNote,
    $$LocalNotesTableFilterComposer,
    $$LocalNotesTableOrderingComposer,
    $$LocalNotesTableAnnotationComposer,
    $$LocalNotesTableCreateCompanionBuilder,
    $$LocalNotesTableUpdateCompanionBuilder,
    (LocalNote, BaseReferences<_$ReadDatabase, $LocalNotesTable, LocalNote>),
    LocalNote,
    PrefetchHooks Function()> {
  $$LocalNotesTableTableManager(_$ReadDatabase db, $LocalNotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<int> startOffset = const Value.absent(),
            Value<int> endOffset = const Value.absent(),
            Value<String> noteText = const Value.absent(),
            Value<String> excerpt = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalNotesCompanion(
            id: id,
            bookId: bookId,
            startOffset: startOffset,
            endOffset: endOffset,
            noteText: noteText,
            excerpt: excerpt,
            revision: revision,
            deviceId: deviceId,
            deleted: deleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String bookId,
            required int startOffset,
            required int endOffset,
            required String noteText,
            Value<String> excerpt = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalNotesCompanion.insert(
            id: id,
            bookId: bookId,
            startOffset: startOffset,
            endOffset: endOffset,
            noteText: noteText,
            excerpt: excerpt,
            revision: revision,
            deviceId: deviceId,
            deleted: deleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalNotesTable, LocalNote>(table),
                    BaseReferences<_$ReadDatabase, $LocalNotesTable, LocalNote>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalNotesTableProcessedTableManager = ProcessedTableManager<
    _$ReadDatabase,
    $LocalNotesTable,
    LocalNote,
    $$LocalNotesTableFilterComposer,
    $$LocalNotesTableOrderingComposer,
    $$LocalNotesTableAnnotationComposer,
    $$LocalNotesTableCreateCompanionBuilder,
    $$LocalNotesTableUpdateCompanionBuilder,
    (LocalNote, BaseReferences<_$ReadDatabase, $LocalNotesTable, LocalNote>),
    LocalNote,
    PrefetchHooks Function()>;
typedef $$SyncJournalTableCreateCompanionBuilder = SyncJournalCompanion
    Function({
  required String id,
  required String kind,
  required int revision,
  required String deviceId,
  required String serialized,
  required int createdAtMs,
  Value<bool> completed,
  Value<int> rowid,
});
typedef $$SyncJournalTableUpdateCompanionBuilder = SyncJournalCompanion
    Function({
  Value<String> id,
  Value<String> kind,
  Value<int> revision,
  Value<String> deviceId,
  Value<String> serialized,
  Value<int> createdAtMs,
  Value<bool> completed,
  Value<int> rowid,
});

class $$SyncJournalTableFilterComposer
    extends Composer<_$ReadDatabase, $SyncJournalTable> {
  $$SyncJournalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get completed => $composableBuilder(
      column: $table.completed, builder: (column) => ColumnFilters(column));
}

class $$SyncJournalTableOrderingComposer
    extends Composer<_$ReadDatabase, $SyncJournalTable> {
  $$SyncJournalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get completed => $composableBuilder(
      column: $table.completed, builder: (column) => ColumnOrderings(column));
}

class $$SyncJournalTableAnnotationComposer
    extends Composer<_$ReadDatabase, $SyncJournalTable> {
  $$SyncJournalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get serialized => $composableBuilder(
      column: $table.serialized, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);
}

class $$SyncJournalTableTableManager extends RootTableManager<
    _$ReadDatabase,
    $SyncJournalTable,
    SyncJournalData,
    $$SyncJournalTableFilterComposer,
    $$SyncJournalTableOrderingComposer,
    $$SyncJournalTableAnnotationComposer,
    $$SyncJournalTableCreateCompanionBuilder,
    $$SyncJournalTableUpdateCompanionBuilder,
    (
      SyncJournalData,
      BaseReferences<_$ReadDatabase, $SyncJournalTable, SyncJournalData>
    ),
    SyncJournalData,
    PrefetchHooks Function()> {
  $$SyncJournalTableTableManager(_$ReadDatabase db, $SyncJournalTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncJournalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncJournalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncJournalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> serialized = const Value.absent(),
            Value<int> createdAtMs = const Value.absent(),
            Value<bool> completed = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncJournalCompanion(
            id: id,
            kind: kind,
            revision: revision,
            deviceId: deviceId,
            serialized: serialized,
            createdAtMs: createdAtMs,
            completed: completed,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String kind,
            required int revision,
            required String deviceId,
            required String serialized,
            required int createdAtMs,
            Value<bool> completed = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncJournalCompanion.insert(
            id: id,
            kind: kind,
            revision: revision,
            deviceId: deviceId,
            serialized: serialized,
            createdAtMs: createdAtMs,
            completed: completed,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncJournalTable, SyncJournalData>(table),
                    BaseReferences<_$ReadDatabase, $SyncJournalTable,
                        SyncJournalData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncJournalTableProcessedTableManager = ProcessedTableManager<
    _$ReadDatabase,
    $SyncJournalTable,
    SyncJournalData,
    $$SyncJournalTableFilterComposer,
    $$SyncJournalTableOrderingComposer,
    $$SyncJournalTableAnnotationComposer,
    $$SyncJournalTableCreateCompanionBuilder,
    $$SyncJournalTableUpdateCompanionBuilder,
    (
      SyncJournalData,
      BaseReferences<_$ReadDatabase, $SyncJournalTable, SyncJournalData>
    ),
    SyncJournalData,
    PrefetchHooks Function()>;

class $ReadDatabaseManager {
  final _$ReadDatabase _db;
  $ReadDatabaseManager(this._db);
  $$LocalBooksTableTableManager get localBooks =>
      $$LocalBooksTableTableManager(_db, _db.localBooks);
  $$ReadingPositionsTableTableManager get readingPositions =>
      $$ReadingPositionsTableTableManager(_db, _db.readingPositions);
  $$LocalBookmarksTableTableManager get localBookmarks =>
      $$LocalBookmarksTableTableManager(_db, _db.localBookmarks);
  $$LocalNotesTableTableManager get localNotes =>
      $$LocalNotesTableTableManager(_db, _db.localNotes);
  $$SyncJournalTableTableManager get syncJournal =>
      $$SyncJournalTableTableManager(_db, _db.syncJournal);
}
