// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'character_reaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CharacterReaction {

/// `null` until the reaction is persisted.
 int? get id; int get dayEntryId; String get characterId; ReactionTone get tone; String get reply;/// Animation amplitude, 0.0..1.0.
 double get intensity; bool get isFallback; DateTime get createdAt;
/// Create a copy of CharacterReaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CharacterReactionCopyWith<CharacterReaction> get copyWith => _$CharacterReactionCopyWithImpl<CharacterReaction>(this as CharacterReaction, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CharacterReaction&&(identical(other.id, id) || other.id == id)&&(identical(other.dayEntryId, dayEntryId) || other.dayEntryId == dayEntryId)&&(identical(other.characterId, characterId) || other.characterId == characterId)&&(identical(other.tone, tone) || other.tone == tone)&&(identical(other.reply, reply) || other.reply == reply)&&(identical(other.intensity, intensity) || other.intensity == intensity)&&(identical(other.isFallback, isFallback) || other.isFallback == isFallback)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,dayEntryId,characterId,tone,reply,intensity,isFallback,createdAt);

@override
String toString() {
  return 'CharacterReaction(id: $id, dayEntryId: $dayEntryId, characterId: $characterId, tone: $tone, reply: $reply, intensity: $intensity, isFallback: $isFallback, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $CharacterReactionCopyWith<$Res>  {
  factory $CharacterReactionCopyWith(CharacterReaction value, $Res Function(CharacterReaction) _then) = _$CharacterReactionCopyWithImpl;
@useResult
$Res call({
 int? id, int dayEntryId, String characterId, ReactionTone tone, String reply, double intensity, bool isFallback, DateTime createdAt
});




}
/// @nodoc
class _$CharacterReactionCopyWithImpl<$Res>
    implements $CharacterReactionCopyWith<$Res> {
  _$CharacterReactionCopyWithImpl(this._self, this._then);

  final CharacterReaction _self;
  final $Res Function(CharacterReaction) _then;

/// Create a copy of CharacterReaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? dayEntryId = null,Object? characterId = null,Object? tone = null,Object? reply = null,Object? intensity = null,Object? isFallback = null,Object? createdAt = null,}) {
  return _then(CharacterReaction(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,dayEntryId: null == dayEntryId ? _self.dayEntryId : dayEntryId // ignore: cast_nullable_to_non_nullable
as int,characterId: null == characterId ? _self.characterId : characterId // ignore: cast_nullable_to_non_nullable
as String,tone: null == tone ? _self.tone : tone // ignore: cast_nullable_to_non_nullable
as ReactionTone,reply: null == reply ? _self.reply : reply // ignore: cast_nullable_to_non_nullable
as String,intensity: null == intensity ? _self.intensity : intensity // ignore: cast_nullable_to_non_nullable
as double,isFallback: null == isFallback ? _self.isFallback : isFallback // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [CharacterReaction].
extension CharacterReactionPatterns on CharacterReaction {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CharacterReaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CharacterReaction() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CharacterReaction value)  $default,){
final _that = this;
switch (_that) {
case _CharacterReaction():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CharacterReaction value)?  $default,){
final _that = this;
switch (_that) {
case _CharacterReaction() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  int dayEntryId,  String characterId,  ReactionTone tone,  String reply,  double intensity,  bool isFallback,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CharacterReaction() when $default != null:
return $default(_that.id,_that.dayEntryId,_that.characterId,_that.tone,_that.reply,_that.intensity,_that.isFallback,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  int dayEntryId,  String characterId,  ReactionTone tone,  String reply,  double intensity,  bool isFallback,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _CharacterReaction():
return $default(_that.id,_that.dayEntryId,_that.characterId,_that.tone,_that.reply,_that.intensity,_that.isFallback,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  int dayEntryId,  String characterId,  ReactionTone tone,  String reply,  double intensity,  bool isFallback,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _CharacterReaction() when $default != null:
return $default(_that.id,_that.dayEntryId,_that.characterId,_that.tone,_that.reply,_that.intensity,_that.isFallback,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _CharacterReaction implements CharacterReaction {
  const _CharacterReaction({this.id, required this.dayEntryId, required this.characterId, required this.tone, required this.reply, required this.intensity, required this.isFallback, required this.createdAt});
  

/// `null` until the reaction is persisted.
@override final  int? id;
@override final  int dayEntryId;
@override final  String characterId;
@override final  ReactionTone tone;
@override final  String reply;
/// Animation amplitude, 0.0..1.0.
@override final  double intensity;
@override final  bool isFallback;
@override final  DateTime createdAt;

/// Create a copy of CharacterReaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CharacterReactionCopyWith<_CharacterReaction> get copyWith => __$CharacterReactionCopyWithImpl<_CharacterReaction>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CharacterReaction&&(identical(other.id, id) || other.id == id)&&(identical(other.dayEntryId, dayEntryId) || other.dayEntryId == dayEntryId)&&(identical(other.characterId, characterId) || other.characterId == characterId)&&(identical(other.tone, tone) || other.tone == tone)&&(identical(other.reply, reply) || other.reply == reply)&&(identical(other.intensity, intensity) || other.intensity == intensity)&&(identical(other.isFallback, isFallback) || other.isFallback == isFallback)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,dayEntryId,characterId,tone,reply,intensity,isFallback,createdAt);

@override
String toString() {
  return 'CharacterReaction(id: $id, dayEntryId: $dayEntryId, characterId: $characterId, tone: $tone, reply: $reply, intensity: $intensity, isFallback: $isFallback, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$CharacterReactionCopyWith<$Res> implements $CharacterReactionCopyWith<$Res> {
  factory _$CharacterReactionCopyWith(_CharacterReaction value, $Res Function(_CharacterReaction) _then) = __$CharacterReactionCopyWithImpl;
@override @useResult
$Res call({
 int? id, int dayEntryId, String characterId, ReactionTone tone, String reply, double intensity, bool isFallback, DateTime createdAt
});




}
/// @nodoc
class __$CharacterReactionCopyWithImpl<$Res>
    implements _$CharacterReactionCopyWith<$Res> {
  __$CharacterReactionCopyWithImpl(this._self, this._then);

  final _CharacterReaction _self;
  final $Res Function(_CharacterReaction) _then;

/// Create a copy of CharacterReaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? dayEntryId = null,Object? characterId = null,Object? tone = null,Object? reply = null,Object? intensity = null,Object? isFallback = null,Object? createdAt = null,}) {
  return _then(_CharacterReaction(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,dayEntryId: null == dayEntryId ? _self.dayEntryId : dayEntryId // ignore: cast_nullable_to_non_nullable
as int,characterId: null == characterId ? _self.characterId : characterId // ignore: cast_nullable_to_non_nullable
as String,tone: null == tone ? _self.tone : tone // ignore: cast_nullable_to_non_nullable
as ReactionTone,reply: null == reply ? _self.reply : reply // ignore: cast_nullable_to_non_nullable
as String,intensity: null == intensity ? _self.intensity : intensity // ignore: cast_nullable_to_non_nullable
as double,isFallback: null == isFallback ? _self.isFallback : isFallback // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
