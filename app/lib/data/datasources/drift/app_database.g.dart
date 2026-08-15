// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DayEntriesTable extends DayEntries
    with TableInfo<$DayEntriesTable, DayEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodScoreMeta = const VerificationMeta(
    'moodScore',
  );
  @override
  late final GeneratedColumn<int> moodScore = GeneratedColumn<int>(
    'mood_score',
    aliasedName,
    false,
    check: () =>
        ComparableExpr(moodScore).isBiggerOrEqualValue(1) &
        ComparableExpr(moodScore).isSmallerOrEqualValue(5),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayTextMeta = const VerificationMeta(
    'dayText',
  );
  @override
  late final GeneratedColumn<String> dayText = GeneratedColumn<String>(
    'day_text',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 2000),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
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
    occurredAt,
    moodScore,
    dayText,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('mood_score')) {
      context.handle(
        _moodScoreMeta,
        moodScore.isAcceptableOrUnknown(data['mood_score']!, _moodScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_moodScoreMeta);
    }
    if (data.containsKey('day_text')) {
      context.handle(
        _dayTextMeta,
        dayText.isAcceptableOrUnknown(data['day_text']!, _dayTextMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DayEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      moodScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood_score'],
      )!,
      dayText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_text'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DayEntriesTable createAlias(String alias) {
    return $DayEntriesTable(attachedDatabase, alias);
  }
}

class DayEntryRow extends DataClass implements Insertable<DayEntryRow> {
  final int id;

  /// UTC instant the entry refers to.
  final DateTime occurredAt;

  /// Explicit emoji-scale score, 1..5 — never derived from reaction tone.
  final int moodScore;
  final String? dayText;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DayEntryRow({
    required this.id,
    required this.occurredAt,
    required this.moodScore,
    this.dayText,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['mood_score'] = Variable<int>(moodScore);
    if (!nullToAbsent || dayText != null) {
      map['day_text'] = Variable<String>(dayText);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DayEntriesCompanion toCompanion(bool nullToAbsent) {
    return DayEntriesCompanion(
      id: Value(id),
      occurredAt: Value(occurredAt),
      moodScore: Value(moodScore),
      dayText: dayText == null && nullToAbsent
          ? const Value.absent()
          : Value(dayText),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DayEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayEntryRow(
      id: serializer.fromJson<int>(json['id']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      moodScore: serializer.fromJson<int>(json['moodScore']),
      dayText: serializer.fromJson<String?>(json['dayText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'moodScore': serializer.toJson<int>(moodScore),
      'dayText': serializer.toJson<String?>(dayText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DayEntryRow copyWith({
    int? id,
    DateTime? occurredAt,
    int? moodScore,
    Value<String?> dayText = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DayEntryRow(
    id: id ?? this.id,
    occurredAt: occurredAt ?? this.occurredAt,
    moodScore: moodScore ?? this.moodScore,
    dayText: dayText.present ? dayText.value : this.dayText,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DayEntryRow copyWithCompanion(DayEntriesCompanion data) {
    return DayEntryRow(
      id: data.id.present ? data.id.value : this.id,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      moodScore: data.moodScore.present ? data.moodScore.value : this.moodScore,
      dayText: data.dayText.present ? data.dayText.value : this.dayText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayEntryRow(')
          ..write('id: $id, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('moodScore: $moodScore, ')
          ..write('dayText: $dayText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, occurredAt, moodScore, dayText, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayEntryRow &&
          other.id == this.id &&
          other.occurredAt == this.occurredAt &&
          other.moodScore == this.moodScore &&
          other.dayText == this.dayText &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DayEntriesCompanion extends UpdateCompanion<DayEntryRow> {
  final Value<int> id;
  final Value<DateTime> occurredAt;
  final Value<int> moodScore;
  final Value<String?> dayText;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DayEntriesCompanion({
    this.id = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.moodScore = const Value.absent(),
    this.dayText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DayEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime occurredAt,
    required int moodScore,
    this.dayText = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : occurredAt = Value(occurredAt),
       moodScore = Value(moodScore),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DayEntryRow> custom({
    Expression<int>? id,
    Expression<DateTime>? occurredAt,
    Expression<int>? moodScore,
    Expression<String>? dayText,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (moodScore != null) 'mood_score': moodScore,
      if (dayText != null) 'day_text': dayText,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DayEntriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? occurredAt,
    Value<int>? moodScore,
    Value<String?>? dayText,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DayEntriesCompanion(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      moodScore: moodScore ?? this.moodScore,
      dayText: dayText ?? this.dayText,
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
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (moodScore.present) {
      map['mood_score'] = Variable<int>(moodScore.value);
    }
    if (dayText.present) {
      map['day_text'] = Variable<String>(dayText.value);
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
    return (StringBuffer('DayEntriesCompanion(')
          ..write('id: $id, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('moodScore: $moodScore, ')
          ..write('dayText: $dayText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CharacterReactionsTable extends CharacterReactions
    with TableInfo<$CharacterReactionsTable, CharacterReactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharacterReactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dayEntryIdMeta = const VerificationMeta(
    'dayEntryId',
  );
  @override
  late final GeneratedColumn<int> dayEntryId = GeneratedColumn<int>(
    'day_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES day_entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toneMeta = const VerificationMeta('tone');
  @override
  late final GeneratedColumn<String> tone = GeneratedColumn<String>(
    'tone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('neutral'),
  );
  static const VerificationMeta _replyMeta = const VerificationMeta('reply');
  @override
  late final GeneratedColumn<String> reply = GeneratedColumn<String>(
    'reply',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intensityMeta = const VerificationMeta(
    'intensity',
  );
  @override
  late final GeneratedColumn<double> intensity = GeneratedColumn<double>(
    'intensity',
    aliasedName,
    false,
    check: () =>
        ComparableExpr(intensity).isBiggerOrEqualValue(0.0) &
        ComparableExpr(intensity).isSmallerOrEqualValue(1.0),
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFallbackMeta = const VerificationMeta(
    'isFallback',
  );
  @override
  late final GeneratedColumn<bool> isFallback = GeneratedColumn<bool>(
    'is_fallback',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_fallback" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
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
    id,
    dayEntryId,
    characterId,
    tone,
    reply,
    intensity,
    isFallback,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'character_reactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CharacterReactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day_entry_id')) {
      context.handle(
        _dayEntryIdMeta,
        dayEntryId.isAcceptableOrUnknown(
          data['day_entry_id']!,
          _dayEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dayEntryIdMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('tone')) {
      context.handle(
        _toneMeta,
        tone.isAcceptableOrUnknown(data['tone']!, _toneMeta),
      );
    }
    if (data.containsKey('reply')) {
      context.handle(
        _replyMeta,
        reply.isAcceptableOrUnknown(data['reply']!, _replyMeta),
      );
    } else if (isInserting) {
      context.missing(_replyMeta);
    }
    if (data.containsKey('intensity')) {
      context.handle(
        _intensityMeta,
        intensity.isAcceptableOrUnknown(data['intensity']!, _intensityMeta),
      );
    } else if (isInserting) {
      context.missing(_intensityMeta);
    }
    if (data.containsKey('is_fallback')) {
      context.handle(
        _isFallbackMeta,
        isFallback.isAcceptableOrUnknown(data['is_fallback']!, _isFallbackMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CharacterReactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CharacterReactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dayEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_entry_id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      tone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tone'],
      )!,
      reply: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply'],
      )!,
      intensity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}intensity'],
      )!,
      isFallback: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_fallback'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CharacterReactionsTable createAlias(String alias) {
    return $CharacterReactionsTable(attachedDatabase, alias);
  }
}

class CharacterReactionRow extends DataClass
    implements Insertable<CharacterReactionRow> {
  final int id;
  final int dayEntryId;

  /// Static character config id (`'cat' | 'dog' | 'crocodile' | 'hippo' | …`) — not a table FK.
  final String characterId;

  /// `ReactionTone.name`; unknown values are mapped to `neutral` by the
  /// mapper before they ever reach this column (FR-010b).
  final String tone;
  final String reply;

  /// Animation amplitude, 0.0..1.0.
  final double intensity;
  final bool isFallback;
  final DateTime createdAt;
  const CharacterReactionRow({
    required this.id,
    required this.dayEntryId,
    required this.characterId,
    required this.tone,
    required this.reply,
    required this.intensity,
    required this.isFallback,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day_entry_id'] = Variable<int>(dayEntryId);
    map['character_id'] = Variable<String>(characterId);
    map['tone'] = Variable<String>(tone);
    map['reply'] = Variable<String>(reply);
    map['intensity'] = Variable<double>(intensity);
    map['is_fallback'] = Variable<bool>(isFallback);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CharacterReactionsCompanion toCompanion(bool nullToAbsent) {
    return CharacterReactionsCompanion(
      id: Value(id),
      dayEntryId: Value(dayEntryId),
      characterId: Value(characterId),
      tone: Value(tone),
      reply: Value(reply),
      intensity: Value(intensity),
      isFallback: Value(isFallback),
      createdAt: Value(createdAt),
    );
  }

  factory CharacterReactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CharacterReactionRow(
      id: serializer.fromJson<int>(json['id']),
      dayEntryId: serializer.fromJson<int>(json['dayEntryId']),
      characterId: serializer.fromJson<String>(json['characterId']),
      tone: serializer.fromJson<String>(json['tone']),
      reply: serializer.fromJson<String>(json['reply']),
      intensity: serializer.fromJson<double>(json['intensity']),
      isFallback: serializer.fromJson<bool>(json['isFallback']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dayEntryId': serializer.toJson<int>(dayEntryId),
      'characterId': serializer.toJson<String>(characterId),
      'tone': serializer.toJson<String>(tone),
      'reply': serializer.toJson<String>(reply),
      'intensity': serializer.toJson<double>(intensity),
      'isFallback': serializer.toJson<bool>(isFallback),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CharacterReactionRow copyWith({
    int? id,
    int? dayEntryId,
    String? characterId,
    String? tone,
    String? reply,
    double? intensity,
    bool? isFallback,
    DateTime? createdAt,
  }) => CharacterReactionRow(
    id: id ?? this.id,
    dayEntryId: dayEntryId ?? this.dayEntryId,
    characterId: characterId ?? this.characterId,
    tone: tone ?? this.tone,
    reply: reply ?? this.reply,
    intensity: intensity ?? this.intensity,
    isFallback: isFallback ?? this.isFallback,
    createdAt: createdAt ?? this.createdAt,
  );
  CharacterReactionRow copyWithCompanion(CharacterReactionsCompanion data) {
    return CharacterReactionRow(
      id: data.id.present ? data.id.value : this.id,
      dayEntryId: data.dayEntryId.present
          ? data.dayEntryId.value
          : this.dayEntryId,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      tone: data.tone.present ? data.tone.value : this.tone,
      reply: data.reply.present ? data.reply.value : this.reply,
      intensity: data.intensity.present ? data.intensity.value : this.intensity,
      isFallback: data.isFallback.present
          ? data.isFallback.value
          : this.isFallback,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CharacterReactionRow(')
          ..write('id: $id, ')
          ..write('dayEntryId: $dayEntryId, ')
          ..write('characterId: $characterId, ')
          ..write('tone: $tone, ')
          ..write('reply: $reply, ')
          ..write('intensity: $intensity, ')
          ..write('isFallback: $isFallback, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dayEntryId,
    characterId,
    tone,
    reply,
    intensity,
    isFallback,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CharacterReactionRow &&
          other.id == this.id &&
          other.dayEntryId == this.dayEntryId &&
          other.characterId == this.characterId &&
          other.tone == this.tone &&
          other.reply == this.reply &&
          other.intensity == this.intensity &&
          other.isFallback == this.isFallback &&
          other.createdAt == this.createdAt);
}

class CharacterReactionsCompanion
    extends UpdateCompanion<CharacterReactionRow> {
  final Value<int> id;
  final Value<int> dayEntryId;
  final Value<String> characterId;
  final Value<String> tone;
  final Value<String> reply;
  final Value<double> intensity;
  final Value<bool> isFallback;
  final Value<DateTime> createdAt;
  const CharacterReactionsCompanion({
    this.id = const Value.absent(),
    this.dayEntryId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.tone = const Value.absent(),
    this.reply = const Value.absent(),
    this.intensity = const Value.absent(),
    this.isFallback = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CharacterReactionsCompanion.insert({
    this.id = const Value.absent(),
    required int dayEntryId,
    required String characterId,
    this.tone = const Value.absent(),
    required String reply,
    required double intensity,
    this.isFallback = const Value.absent(),
    required DateTime createdAt,
  }) : dayEntryId = Value(dayEntryId),
       characterId = Value(characterId),
       reply = Value(reply),
       intensity = Value(intensity),
       createdAt = Value(createdAt);
  static Insertable<CharacterReactionRow> custom({
    Expression<int>? id,
    Expression<int>? dayEntryId,
    Expression<String>? characterId,
    Expression<String>? tone,
    Expression<String>? reply,
    Expression<double>? intensity,
    Expression<bool>? isFallback,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayEntryId != null) 'day_entry_id': dayEntryId,
      if (characterId != null) 'character_id': characterId,
      if (tone != null) 'tone': tone,
      if (reply != null) 'reply': reply,
      if (intensity != null) 'intensity': intensity,
      if (isFallback != null) 'is_fallback': isFallback,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CharacterReactionsCompanion copyWith({
    Value<int>? id,
    Value<int>? dayEntryId,
    Value<String>? characterId,
    Value<String>? tone,
    Value<String>? reply,
    Value<double>? intensity,
    Value<bool>? isFallback,
    Value<DateTime>? createdAt,
  }) {
    return CharacterReactionsCompanion(
      id: id ?? this.id,
      dayEntryId: dayEntryId ?? this.dayEntryId,
      characterId: characterId ?? this.characterId,
      tone: tone ?? this.tone,
      reply: reply ?? this.reply,
      intensity: intensity ?? this.intensity,
      isFallback: isFallback ?? this.isFallback,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dayEntryId.present) {
      map['day_entry_id'] = Variable<int>(dayEntryId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (tone.present) {
      map['tone'] = Variable<String>(tone.value);
    }
    if (reply.present) {
      map['reply'] = Variable<String>(reply.value);
    }
    if (intensity.present) {
      map['intensity'] = Variable<double>(intensity.value);
    }
    if (isFallback.present) {
      map['is_fallback'] = Variable<bool>(isFallback.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharacterReactionsCompanion(')
          ..write('id: $id, ')
          ..write('dayEntryId: $dayEntryId, ')
          ..write('characterId: $characterId, ')
          ..write('tone: $tone, ')
          ..write('reply: $reply, ')
          ..write('intensity: $intensity, ')
          ..write('isFallback: $isFallback, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTableTable extends UserSettingsTable
    with TableInfo<$UserSettingsTableTable, UserSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => 1,
  );
  static const VerificationMeta _installIdMeta = const VerificationMeta(
    'installId',
  );
  @override
  late final GeneratedColumn<String> installId = GeneratedColumn<String>(
    'install_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  @override
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
    'locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _soundEnabledMeta = const VerificationMeta(
    'soundEnabled',
  );
  @override
  late final GeneratedColumn<bool> soundEnabled = GeneratedColumn<bool>(
    'sound_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sound_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _enabledCharacterIdsMeta =
      const VerificationMeta('enabledCharacterIds');
  @override
  late final GeneratedColumn<String> enabledCharacterIds =
      GeneratedColumn<String>(
        'enabled_character_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('["cat","dog","crocodile","hippo"]'),
      );
  static const VerificationMeta _hasSeenOnboardingMeta = const VerificationMeta(
    'hasSeenOnboarding',
  );
  @override
  late final GeneratedColumn<bool> hasSeenOnboarding = GeneratedColumn<bool>(
    'has_seen_onboarding',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_seen_onboarding" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reminderTimeMeta = const VerificationMeta(
    'reminderTime',
  );
  @override
  late final GeneratedColumn<String> reminderTime = GeneratedColumn<String>(
    'reminder_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('20:00'),
  );
  static const VerificationMeta _dayStartHourMeta = const VerificationMeta(
    'dayStartHour',
  );
  @override
  late final GeneratedColumn<int> dayStartHour = GeneratedColumn<int>(
    'day_start_hour',
    aliasedName,
    false,
    check: () =>
        ComparableExpr(dayStartHour).isBiggerOrEqualValue(0) &
        ComparableExpr(dayStartHour).isSmallerOrEqualValue(23),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    installId,
    themeMode,
    locale,
    soundEnabled,
    enabledCharacterIds,
    hasSeenOnboarding,
    reminderEnabled,
    reminderTime,
    dayStartHour,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('install_id')) {
      context.handle(
        _installIdMeta,
        installId.isAcceptableOrUnknown(data['install_id']!, _installIdMeta),
      );
    } else if (isInserting) {
      context.missing(_installIdMeta);
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('locale')) {
      context.handle(
        _localeMeta,
        locale.isAcceptableOrUnknown(data['locale']!, _localeMeta),
      );
    }
    if (data.containsKey('sound_enabled')) {
      context.handle(
        _soundEnabledMeta,
        soundEnabled.isAcceptableOrUnknown(
          data['sound_enabled']!,
          _soundEnabledMeta,
        ),
      );
    }
    if (data.containsKey('enabled_character_ids')) {
      context.handle(
        _enabledCharacterIdsMeta,
        enabledCharacterIds.isAcceptableOrUnknown(
          data['enabled_character_ids']!,
          _enabledCharacterIdsMeta,
        ),
      );
    }
    if (data.containsKey('has_seen_onboarding')) {
      context.handle(
        _hasSeenOnboardingMeta,
        hasSeenOnboarding.isAcceptableOrUnknown(
          data['has_seen_onboarding']!,
          _hasSeenOnboardingMeta,
        ),
      );
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('reminder_time')) {
      context.handle(
        _reminderTimeMeta,
        reminderTime.isAcceptableOrUnknown(
          data['reminder_time']!,
          _reminderTimeMeta,
        ),
      );
    }
    if (data.containsKey('day_start_hour')) {
      context.handle(
        _dayStartHourMeta,
        dayStartHour.isAcceptableOrUnknown(
          data['day_start_hour']!,
          _dayStartHourMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  UserSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      installId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}install_id'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      locale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale'],
      )!,
      soundEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sound_enabled'],
      )!,
      enabledCharacterIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enabled_character_ids'],
      )!,
      hasSeenOnboarding: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_seen_onboarding'],
      )!,
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      reminderTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_time'],
      )!,
      dayStartHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_start_hour'],
      )!,
    );
  }

  @override
  $UserSettingsTableTable createAlias(String alias) {
    return $UserSettingsTableTable(attachedDatabase, alias);
  }
}

class UserSettingsRow extends DataClass implements Insertable<UserSettingsRow> {
  final int id;

  /// 32 hex characters, generated once on first insert (FR-014, FR-015).
  final String installId;

  /// `'light' | 'dark' | 'system'`.
  final String themeMode;

  /// `'ru' | 'uk' | 'en' | 'system'`.
  final String locale;
  final bool soundEnabled;

  /// JSON array of character ids; must contain at least one entry.
  final String enabledCharacterIds;
  final bool hasSeenOnboarding;
  final bool reminderEnabled;

  /// `HH:mm`.
  final String reminderTime;
  final int dayStartHour;
  const UserSettingsRow({
    required this.id,
    required this.installId,
    required this.themeMode,
    required this.locale,
    required this.soundEnabled,
    required this.enabledCharacterIds,
    required this.hasSeenOnboarding,
    required this.reminderEnabled,
    required this.reminderTime,
    required this.dayStartHour,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['install_id'] = Variable<String>(installId);
    map['theme_mode'] = Variable<String>(themeMode);
    map['locale'] = Variable<String>(locale);
    map['sound_enabled'] = Variable<bool>(soundEnabled);
    map['enabled_character_ids'] = Variable<String>(enabledCharacterIds);
    map['has_seen_onboarding'] = Variable<bool>(hasSeenOnboarding);
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    map['reminder_time'] = Variable<String>(reminderTime);
    map['day_start_hour'] = Variable<int>(dayStartHour);
    return map;
  }

  UserSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsTableCompanion(
      id: Value(id),
      installId: Value(installId),
      themeMode: Value(themeMode),
      locale: Value(locale),
      soundEnabled: Value(soundEnabled),
      enabledCharacterIds: Value(enabledCharacterIds),
      hasSeenOnboarding: Value(hasSeenOnboarding),
      reminderEnabled: Value(reminderEnabled),
      reminderTime: Value(reminderTime),
      dayStartHour: Value(dayStartHour),
    );
  }

  factory UserSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSettingsRow(
      id: serializer.fromJson<int>(json['id']),
      installId: serializer.fromJson<String>(json['installId']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      locale: serializer.fromJson<String>(json['locale']),
      soundEnabled: serializer.fromJson<bool>(json['soundEnabled']),
      enabledCharacterIds: serializer.fromJson<String>(
        json['enabledCharacterIds'],
      ),
      hasSeenOnboarding: serializer.fromJson<bool>(json['hasSeenOnboarding']),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      reminderTime: serializer.fromJson<String>(json['reminderTime']),
      dayStartHour: serializer.fromJson<int>(json['dayStartHour']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'installId': serializer.toJson<String>(installId),
      'themeMode': serializer.toJson<String>(themeMode),
      'locale': serializer.toJson<String>(locale),
      'soundEnabled': serializer.toJson<bool>(soundEnabled),
      'enabledCharacterIds': serializer.toJson<String>(enabledCharacterIds),
      'hasSeenOnboarding': serializer.toJson<bool>(hasSeenOnboarding),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'reminderTime': serializer.toJson<String>(reminderTime),
      'dayStartHour': serializer.toJson<int>(dayStartHour),
    };
  }

  UserSettingsRow copyWith({
    int? id,
    String? installId,
    String? themeMode,
    String? locale,
    bool? soundEnabled,
    String? enabledCharacterIds,
    bool? hasSeenOnboarding,
    bool? reminderEnabled,
    String? reminderTime,
    int? dayStartHour,
  }) => UserSettingsRow(
    id: id ?? this.id,
    installId: installId ?? this.installId,
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    enabledCharacterIds: enabledCharacterIds ?? this.enabledCharacterIds,
    hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderTime: reminderTime ?? this.reminderTime,
    dayStartHour: dayStartHour ?? this.dayStartHour,
  );
  UserSettingsRow copyWithCompanion(UserSettingsTableCompanion data) {
    return UserSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      installId: data.installId.present ? data.installId.value : this.installId,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      locale: data.locale.present ? data.locale.value : this.locale,
      soundEnabled: data.soundEnabled.present
          ? data.soundEnabled.value
          : this.soundEnabled,
      enabledCharacterIds: data.enabledCharacterIds.present
          ? data.enabledCharacterIds.value
          : this.enabledCharacterIds,
      hasSeenOnboarding: data.hasSeenOnboarding.present
          ? data.hasSeenOnboarding.value
          : this.hasSeenOnboarding,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderTime: data.reminderTime.present
          ? data.reminderTime.value
          : this.reminderTime,
      dayStartHour: data.dayStartHour.present
          ? data.dayStartHour.value
          : this.dayStartHour,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsRow(')
          ..write('id: $id, ')
          ..write('installId: $installId, ')
          ..write('themeMode: $themeMode, ')
          ..write('locale: $locale, ')
          ..write('soundEnabled: $soundEnabled, ')
          ..write('enabledCharacterIds: $enabledCharacterIds, ')
          ..write('hasSeenOnboarding: $hasSeenOnboarding, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('dayStartHour: $dayStartHour')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    installId,
    themeMode,
    locale,
    soundEnabled,
    enabledCharacterIds,
    hasSeenOnboarding,
    reminderEnabled,
    reminderTime,
    dayStartHour,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSettingsRow &&
          other.id == this.id &&
          other.installId == this.installId &&
          other.themeMode == this.themeMode &&
          other.locale == this.locale &&
          other.soundEnabled == this.soundEnabled &&
          other.enabledCharacterIds == this.enabledCharacterIds &&
          other.hasSeenOnboarding == this.hasSeenOnboarding &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderTime == this.reminderTime &&
          other.dayStartHour == this.dayStartHour);
}

class UserSettingsTableCompanion extends UpdateCompanion<UserSettingsRow> {
  final Value<int> id;
  final Value<String> installId;
  final Value<String> themeMode;
  final Value<String> locale;
  final Value<bool> soundEnabled;
  final Value<String> enabledCharacterIds;
  final Value<bool> hasSeenOnboarding;
  final Value<bool> reminderEnabled;
  final Value<String> reminderTime;
  final Value<int> dayStartHour;
  final Value<int> rowid;
  const UserSettingsTableCompanion({
    this.id = const Value.absent(),
    this.installId = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.locale = const Value.absent(),
    this.soundEnabled = const Value.absent(),
    this.enabledCharacterIds = const Value.absent(),
    this.hasSeenOnboarding = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.dayStartHour = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserSettingsTableCompanion.insert({
    this.id = const Value.absent(),
    required String installId,
    this.themeMode = const Value.absent(),
    this.locale = const Value.absent(),
    this.soundEnabled = const Value.absent(),
    this.enabledCharacterIds = const Value.absent(),
    this.hasSeenOnboarding = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.dayStartHour = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : installId = Value(installId);
  static Insertable<UserSettingsRow> custom({
    Expression<int>? id,
    Expression<String>? installId,
    Expression<String>? themeMode,
    Expression<String>? locale,
    Expression<bool>? soundEnabled,
    Expression<String>? enabledCharacterIds,
    Expression<bool>? hasSeenOnboarding,
    Expression<bool>? reminderEnabled,
    Expression<String>? reminderTime,
    Expression<int>? dayStartHour,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (installId != null) 'install_id': installId,
      if (themeMode != null) 'theme_mode': themeMode,
      if (locale != null) 'locale': locale,
      if (soundEnabled != null) 'sound_enabled': soundEnabled,
      if (enabledCharacterIds != null)
        'enabled_character_ids': enabledCharacterIds,
      if (hasSeenOnboarding != null) 'has_seen_onboarding': hasSeenOnboarding,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderTime != null) 'reminder_time': reminderTime,
      if (dayStartHour != null) 'day_start_hour': dayStartHour,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserSettingsTableCompanion copyWith({
    Value<int>? id,
    Value<String>? installId,
    Value<String>? themeMode,
    Value<String>? locale,
    Value<bool>? soundEnabled,
    Value<String>? enabledCharacterIds,
    Value<bool>? hasSeenOnboarding,
    Value<bool>? reminderEnabled,
    Value<String>? reminderTime,
    Value<int>? dayStartHour,
    Value<int>? rowid,
  }) {
    return UserSettingsTableCompanion(
      id: id ?? this.id,
      installId: installId ?? this.installId,
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      enabledCharacterIds: enabledCharacterIds ?? this.enabledCharacterIds,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (installId.present) {
      map['install_id'] = Variable<String>(installId.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (locale.present) {
      map['locale'] = Variable<String>(locale.value);
    }
    if (soundEnabled.present) {
      map['sound_enabled'] = Variable<bool>(soundEnabled.value);
    }
    if (enabledCharacterIds.present) {
      map['enabled_character_ids'] = Variable<String>(
        enabledCharacterIds.value,
      );
    }
    if (hasSeenOnboarding.present) {
      map['has_seen_onboarding'] = Variable<bool>(hasSeenOnboarding.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (reminderTime.present) {
      map['reminder_time'] = Variable<String>(reminderTime.value);
    }
    if (dayStartHour.present) {
      map['day_start_hour'] = Variable<int>(dayStartHour.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsTableCompanion(')
          ..write('id: $id, ')
          ..write('installId: $installId, ')
          ..write('themeMode: $themeMode, ')
          ..write('locale: $locale, ')
          ..write('soundEnabled: $soundEnabled, ')
          ..write('enabledCharacterIds: $enabledCharacterIds, ')
          ..write('hasSeenOnboarding: $hasSeenOnboarding, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('dayStartHour: $dayStartHour, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DayEntriesTable dayEntries = $DayEntriesTable(this);
  late final $CharacterReactionsTable characterReactions =
      $CharacterReactionsTable(this);
  late final $UserSettingsTableTable userSettingsTable =
      $UserSettingsTableTable(this);
  late final Index idxDayEntriesOccurredAt = Index(
    'idx_day_entries_occurred_at',
    'CREATE INDEX idx_day_entries_occurred_at ON day_entries (occurred_at)',
  );
  late final Index idxCharacterReactionsDayEntry = Index(
    'idx_character_reactions_day_entry',
    'CREATE INDEX idx_character_reactions_day_entry ON character_reactions (day_entry_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dayEntries,
    characterReactions,
    userSettingsTable,
    idxDayEntriesOccurredAt,
    idxCharacterReactionsDayEntry,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'day_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('character_reactions', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DayEntriesTableCreateCompanionBuilder = DayEntriesCompanion Function({
  Value<int> id,
  required DateTime occurredAt,
  required int moodScore,
  Value<String?> dayText,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$DayEntriesTableUpdateCompanionBuilder = DayEntriesCompanion Function({
  Value<int> id,
  Value<DateTime> occurredAt,
  Value<int> moodScore,
  Value<String?> dayText,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$DayEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $DayEntriesTable, DayEntryRow> {
  $$DayEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $CharacterReactionsTable,
    List<CharacterReactionRow>
  >
  _characterReactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.characterReactions,
        aliasName: 'day_entries__id__character_reactions__day_entry_id',
      );

  $$CharacterReactionsTableProcessedTableManager get characterReactionsRefs {
    final manager = $$CharacterReactionsTableTableManager(
      $_db,
      $_db.characterReactions,
    ).filter((f) => f.dayEntryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _characterReactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DayEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DayEntriesTable> {
  $$DayEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moodScore => $composableBuilder(
    column: $table.moodScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayText => $composableBuilder(
    column: $table.dayText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> characterReactionsRefs(
    Expression<bool> Function($$CharacterReactionsTableFilterComposer f) f,
  ) {
    final $$CharacterReactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.characterReactions,
      getReferencedColumn: (t) => t.dayEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharacterReactionsTableFilterComposer(
            $db: $db,
            $table: $db.characterReactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DayEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DayEntriesTable> {
  $$DayEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moodScore => $composableBuilder(
    column: $table.moodScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayText => $composableBuilder(
    column: $table.dayText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DayEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayEntriesTable> {
  $$DayEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get moodScore =>
      $composableBuilder(column: $table.moodScore, builder: (column) => column);

  GeneratedColumn<String> get dayText =>
      $composableBuilder(column: $table.dayText, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> characterReactionsRefs<T extends Object>(
    Expression<T> Function($$CharacterReactionsTableAnnotationComposer a) f,
  ) {
    final $$CharacterReactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.characterReactions,
          getReferencedColumn: (t) => t.dayEntryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CharacterReactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.characterReactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DayEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayEntriesTable,
          DayEntryRow,
          $$DayEntriesTableFilterComposer,
          $$DayEntriesTableOrderingComposer,
          $$DayEntriesTableAnnotationComposer,
          $$DayEntriesTableCreateCompanionBuilder,
          $$DayEntriesTableUpdateCompanionBuilder,
          (DayEntryRow, $$DayEntriesTableReferences),
          DayEntryRow,
          PrefetchHooks Function({bool characterReactionsRefs})
        > {
  $$DayEntriesTableTableManager(_$AppDatabase db, $DayEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<int> moodScore = const Value.absent(),
                Value<String?> dayText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DayEntriesCompanion(
                id: id,
                occurredAt: occurredAt,
                moodScore: moodScore,
                dayText: dayText,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime occurredAt,
                required int moodScore,
                Value<String?> dayText = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => DayEntriesCompanion.insert(
                id: id,
                occurredAt: occurredAt,
                moodScore: moodScore,
                dayText: dayText,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DayEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({characterReactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (characterReactionsRefs) db.characterReactions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (characterReactionsRefs)
                    await $_getPrefetchedData<
                      DayEntryRow,
                      $DayEntriesTable,
                      CharacterReactionRow
                    >(
                      currentTable: table,
                      referencedTable: $$DayEntriesTableReferences
                          ._characterReactionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DayEntriesTableReferences(
                            db,
                            table,
                            p0,
                          ).characterReactionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.dayEntryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DayEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayEntriesTable,
      DayEntryRow,
      $$DayEntriesTableFilterComposer,
      $$DayEntriesTableOrderingComposer,
      $$DayEntriesTableAnnotationComposer,
      $$DayEntriesTableCreateCompanionBuilder,
      $$DayEntriesTableUpdateCompanionBuilder,
      (DayEntryRow, $$DayEntriesTableReferences),
      DayEntryRow,
      PrefetchHooks Function({bool characterReactionsRefs})
    >;
typedef $$CharacterReactionsTableCreateCompanionBuilder =
    CharacterReactionsCompanion Function({
      Value<int> id,
      required int dayEntryId,
      required String characterId,
      Value<String> tone,
      required String reply,
      required double intensity,
      Value<bool> isFallback,
      required DateTime createdAt,
    });
typedef $$CharacterReactionsTableUpdateCompanionBuilder =
    CharacterReactionsCompanion Function({
      Value<int> id,
      Value<int> dayEntryId,
      Value<String> characterId,
      Value<String> tone,
      Value<String> reply,
      Value<double> intensity,
      Value<bool> isFallback,
      Value<DateTime> createdAt,
    });

final class $$CharacterReactionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CharacterReactionsTable,
          CharacterReactionRow
        > {
  $$CharacterReactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DayEntriesTable _dayEntryIdTable(_$AppDatabase db) => db.dayEntries
      .createAlias('character_reactions__day_entry_id__day_entries__id');

  $$DayEntriesTableProcessedTableManager get dayEntryId {
    final $_column = $_itemColumn<int>('day_entry_id')!;

    final manager = $$DayEntriesTableTableManager(
      $_db,
      $_db.dayEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dayEntryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CharacterReactionsTableFilterComposer
    extends Composer<_$AppDatabase, $CharacterReactionsTable> {
  $$CharacterReactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tone => $composableBuilder(
    column: $table.tone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reply => $composableBuilder(
    column: $table.reply,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get intensity => $composableBuilder(
    column: $table.intensity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFallback => $composableBuilder(
    column: $table.isFallback,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DayEntriesTableFilterComposer get dayEntryId {
    final $$DayEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayEntryId,
      referencedTable: $db.dayEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayEntriesTableFilterComposer(
            $db: $db,
            $table: $db.dayEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharacterReactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CharacterReactionsTable> {
  $$CharacterReactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tone => $composableBuilder(
    column: $table.tone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reply => $composableBuilder(
    column: $table.reply,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get intensity => $composableBuilder(
    column: $table.intensity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFallback => $composableBuilder(
    column: $table.isFallback,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DayEntriesTableOrderingComposer get dayEntryId {
    final $$DayEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayEntryId,
      referencedTable: $db.dayEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.dayEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharacterReactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharacterReactionsTable> {
  $$CharacterReactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tone =>
      $composableBuilder(column: $table.tone, builder: (column) => column);

  GeneratedColumn<String> get reply =>
      $composableBuilder(column: $table.reply, builder: (column) => column);

  GeneratedColumn<double> get intensity =>
      $composableBuilder(column: $table.intensity, builder: (column) => column);

  GeneratedColumn<bool> get isFallback => $composableBuilder(
    column: $table.isFallback,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DayEntriesTableAnnotationComposer get dayEntryId {
    final $$DayEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayEntryId,
      referencedTable: $db.dayEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.dayEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharacterReactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CharacterReactionsTable,
          CharacterReactionRow,
          $$CharacterReactionsTableFilterComposer,
          $$CharacterReactionsTableOrderingComposer,
          $$CharacterReactionsTableAnnotationComposer,
          $$CharacterReactionsTableCreateCompanionBuilder,
          $$CharacterReactionsTableUpdateCompanionBuilder,
          (CharacterReactionRow, $$CharacterReactionsTableReferences),
          CharacterReactionRow,
          PrefetchHooks Function({bool dayEntryId})
        > {
  $$CharacterReactionsTableTableManager(
    _$AppDatabase db,
    $CharacterReactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharacterReactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharacterReactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharacterReactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dayEntryId = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<String> tone = const Value.absent(),
                Value<String> reply = const Value.absent(),
                Value<double> intensity = const Value.absent(),
                Value<bool> isFallback = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CharacterReactionsCompanion(
                id: id,
                dayEntryId: dayEntryId,
                characterId: characterId,
                tone: tone,
                reply: reply,
                intensity: intensity,
                isFallback: isFallback,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int dayEntryId,
                required String characterId,
                Value<String> tone = const Value.absent(),
                required String reply,
                required double intensity,
                Value<bool> isFallback = const Value.absent(),
                required DateTime createdAt,
              }) => CharacterReactionsCompanion.insert(
                id: id,
                dayEntryId: dayEntryId,
                characterId: characterId,
                tone: tone,
                reply: reply,
                intensity: intensity,
                isFallback: isFallback,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CharacterReactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({dayEntryId = false}) {
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
                    if (dayEntryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.dayEntryId,
                        referencedTable: $$CharacterReactionsTableReferences
                            ._dayEntryIdTable(db),
                        referencedColumn: $$CharacterReactionsTableReferences
                            ._dayEntryIdTable(db)
                            .id,
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

typedef $$CharacterReactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CharacterReactionsTable,
      CharacterReactionRow,
      $$CharacterReactionsTableFilterComposer,
      $$CharacterReactionsTableOrderingComposer,
      $$CharacterReactionsTableAnnotationComposer,
      $$CharacterReactionsTableCreateCompanionBuilder,
      $$CharacterReactionsTableUpdateCompanionBuilder,
      (CharacterReactionRow, $$CharacterReactionsTableReferences),
      CharacterReactionRow,
      PrefetchHooks Function({bool dayEntryId})
    >;
typedef $$UserSettingsTableTableCreateCompanionBuilder =
    UserSettingsTableCompanion Function({
      Value<int> id,
      required String installId,
      Value<String> themeMode,
      Value<String> locale,
      Value<bool> soundEnabled,
      Value<String> enabledCharacterIds,
      Value<bool> hasSeenOnboarding,
      Value<bool> reminderEnabled,
      Value<String> reminderTime,
      Value<int> dayStartHour,
      Value<int> rowid,
    });
typedef $$UserSettingsTableTableUpdateCompanionBuilder =
    UserSettingsTableCompanion Function({
      Value<int> id,
      Value<String> installId,
      Value<String> themeMode,
      Value<String> locale,
      Value<bool> soundEnabled,
      Value<String> enabledCharacterIds,
      Value<bool> hasSeenOnboarding,
      Value<bool> reminderEnabled,
      Value<String> reminderTime,
      Value<int> dayStartHour,
      Value<int> rowid,
    });

class $$UserSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTableTable> {
  $$UserSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installId => $composableBuilder(
    column: $table.installId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enabledCharacterIds => $composableBuilder(
    column: $table.enabledCharacterIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasSeenOnboarding => $composableBuilder(
    column: $table.hasSeenOnboarding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayStartHour => $composableBuilder(
    column: $table.dayStartHour,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTableTable> {
  $$UserSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installId => $composableBuilder(
    column: $table.installId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enabledCharacterIds => $composableBuilder(
    column: $table.enabledCharacterIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasSeenOnboarding => $composableBuilder(
    column: $table.hasSeenOnboarding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayStartHour => $composableBuilder(
    column: $table.dayStartHour,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTableTable> {
  $$UserSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get installId =>
      $composableBuilder(column: $table.installId, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  GeneratedColumn<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enabledCharacterIds => $composableBuilder(
    column: $table.enabledCharacterIds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasSeenOnboarding => $composableBuilder(
    column: $table.hasSeenOnboarding,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayStartHour => $composableBuilder(
    column: $table.dayStartHour,
    builder: (column) => column,
  );
}

class $$UserSettingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserSettingsTableTable,
          UserSettingsRow,
          $$UserSettingsTableTableFilterComposer,
          $$UserSettingsTableTableOrderingComposer,
          $$UserSettingsTableTableAnnotationComposer,
          $$UserSettingsTableTableCreateCompanionBuilder,
          $$UserSettingsTableTableUpdateCompanionBuilder,
          (
            UserSettingsRow,
            BaseReferences<
              _$AppDatabase,
              $UserSettingsTableTable,
              UserSettingsRow
            >,
          ),
          UserSettingsRow,
          PrefetchHooks Function()
        > {
  $$UserSettingsTableTableTableManager(
    _$AppDatabase db,
    $UserSettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> installId = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<bool> soundEnabled = const Value.absent(),
                Value<String> enabledCharacterIds = const Value.absent(),
                Value<bool> hasSeenOnboarding = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<String> reminderTime = const Value.absent(),
                Value<int> dayStartHour = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserSettingsTableCompanion(
                id: id,
                installId: installId,
                themeMode: themeMode,
                locale: locale,
                soundEnabled: soundEnabled,
                enabledCharacterIds: enabledCharacterIds,
                hasSeenOnboarding: hasSeenOnboarding,
                reminderEnabled: reminderEnabled,
                reminderTime: reminderTime,
                dayStartHour: dayStartHour,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String installId,
                Value<String> themeMode = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<bool> soundEnabled = const Value.absent(),
                Value<String> enabledCharacterIds = const Value.absent(),
                Value<bool> hasSeenOnboarding = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<String> reminderTime = const Value.absent(),
                Value<int> dayStartHour = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserSettingsTableCompanion.insert(
                id: id,
                installId: installId,
                themeMode: themeMode,
                locale: locale,
                soundEnabled: soundEnabled,
                enabledCharacterIds: enabledCharacterIds,
                hasSeenOnboarding: hasSeenOnboarding,
                reminderEnabled: reminderEnabled,
                reminderTime: reminderTime,
                dayStartHour: dayStartHour,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserSettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserSettingsTableTable,
      UserSettingsRow,
      $$UserSettingsTableTableFilterComposer,
      $$UserSettingsTableTableOrderingComposer,
      $$UserSettingsTableTableAnnotationComposer,
      $$UserSettingsTableTableCreateCompanionBuilder,
      $$UserSettingsTableTableUpdateCompanionBuilder,
      (
        UserSettingsRow,
        BaseReferences<_$AppDatabase, $UserSettingsTableTable, UserSettingsRow>,
      ),
      UserSettingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DayEntriesTableTableManager get dayEntries =>
      $$DayEntriesTableTableManager(_db, _db.dayEntries);
  $$CharacterReactionsTableTableManager get characterReactions =>
      $$CharacterReactionsTableTableManager(_db, _db.characterReactions);
  $$UserSettingsTableTableTableManager get userSettingsTable =>
      $$UserSettingsTableTableTableManager(_db, _db.userSettingsTable);
}
