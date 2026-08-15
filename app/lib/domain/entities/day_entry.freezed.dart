// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'day_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DayEntry {

/// `null` until the entry is persisted.
 int? get id; DateTime get occurredAt; MoodScore get moodScore; String? get dayText; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of DayEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DayEntryCopyWith<DayEntry> get copyWith => _$DayEntryCopyWithImpl<DayEntry>(this as DayEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DayEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.moodScore, moodScore) || other.moodScore == moodScore)&&(identical(other.dayText, dayText) || other.dayText == dayText)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,occurredAt,moodScore,dayText,createdAt,updatedAt);

@override
String toString() {
  return 'DayEntry(id: $id, occurredAt: $occurredAt, moodScore: $moodScore, dayText: $dayText, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $DayEntryCopyWith<$Res>  {
  factory $DayEntryCopyWith(DayEntry value, $Res Function(DayEntry) _then) = _$DayEntryCopyWithImpl;
@useResult
$Res call({
 int? id, DateTime occurredAt, MoodScore moodScore, String? dayText, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$DayEntryCopyWithImpl<$Res>
    implements $DayEntryCopyWith<$Res> {
  _$DayEntryCopyWithImpl(this._self, this._then);

  final DayEntry _self;
  final $Res Function(DayEntry) _then;

/// Create a copy of DayEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? occurredAt = null,Object? moodScore = null,Object? dayText = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(DayEntry(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,moodScore: null == moodScore ? _self.moodScore : moodScore // ignore: cast_nullable_to_non_nullable
as MoodScore,dayText: freezed == dayText ? _self.dayText : dayText // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [DayEntry].
extension DayEntryPatterns on DayEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DayEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DayEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DayEntry value)  $default,){
final _that = this;
switch (_that) {
case _DayEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DayEntry value)?  $default,){
final _that = this;
switch (_that) {
case _DayEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  DateTime occurredAt,  MoodScore moodScore,  String? dayText,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DayEntry() when $default != null:
return $default(_that.id,_that.occurredAt,_that.moodScore,_that.dayText,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  DateTime occurredAt,  MoodScore moodScore,  String? dayText,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _DayEntry():
return $default(_that.id,_that.occurredAt,_that.moodScore,_that.dayText,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  DateTime occurredAt,  MoodScore moodScore,  String? dayText,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _DayEntry() when $default != null:
return $default(_that.id,_that.occurredAt,_that.moodScore,_that.dayText,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _DayEntry implements DayEntry {
  const _DayEntry({this.id, required this.occurredAt, required this.moodScore, this.dayText, required this.createdAt, required this.updatedAt});
  

/// `null` until the entry is persisted.
@override final  int? id;
@override final  DateTime occurredAt;
@override final  MoodScore moodScore;
@override final  String? dayText;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of DayEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DayEntryCopyWith<_DayEntry> get copyWith => __$DayEntryCopyWithImpl<_DayEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DayEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.moodScore, moodScore) || other.moodScore == moodScore)&&(identical(other.dayText, dayText) || other.dayText == dayText)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,occurredAt,moodScore,dayText,createdAt,updatedAt);

@override
String toString() {
  return 'DayEntry(id: $id, occurredAt: $occurredAt, moodScore: $moodScore, dayText: $dayText, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$DayEntryCopyWith<$Res> implements $DayEntryCopyWith<$Res> {
  factory _$DayEntryCopyWith(_DayEntry value, $Res Function(_DayEntry) _then) = __$DayEntryCopyWithImpl;
@override @useResult
$Res call({
 int? id, DateTime occurredAt, MoodScore moodScore, String? dayText, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$DayEntryCopyWithImpl<$Res>
    implements _$DayEntryCopyWith<$Res> {
  __$DayEntryCopyWithImpl(this._self, this._then);

  final _DayEntry _self;
  final $Res Function(_DayEntry) _then;

/// Create a copy of DayEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? occurredAt = null,Object? moodScore = null,Object? dayText = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_DayEntry(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,moodScore: null == moodScore ? _self.moodScore : moodScore // ignore: cast_nullable_to_non_nullable
as MoodScore,dayText: freezed == dayText ? _self.dayText : dayText // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
