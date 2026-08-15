// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UserSettings {

/// Anonymous per-install identifier. Never leaves the device.
 String get installId; ThemePreference get themeMode; LocalePreference get locale; bool get soundEnabled;/// Must not be empty (`Validators.enabledCharacterIds`).
 List<String> get enabledCharacterIds; bool get hasSeenOnboarding; bool get reminderEnabled; ReminderTime get reminderTime; DayStartHour get dayStartHour;
/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserSettingsCopyWith<UserSettings> get copyWith => _$UserSettingsCopyWithImpl<UserSettings>(this as UserSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserSettings&&(identical(other.installId, installId) || other.installId == installId)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.soundEnabled, soundEnabled) || other.soundEnabled == soundEnabled)&&const DeepCollectionEquality().equals(other.enabledCharacterIds, enabledCharacterIds)&&(identical(other.hasSeenOnboarding, hasSeenOnboarding) || other.hasSeenOnboarding == hasSeenOnboarding)&&(identical(other.reminderEnabled, reminderEnabled) || other.reminderEnabled == reminderEnabled)&&(identical(other.reminderTime, reminderTime) || other.reminderTime == reminderTime)&&(identical(other.dayStartHour, dayStartHour) || other.dayStartHour == dayStartHour));
}


@override
int get hashCode => Object.hash(runtimeType,installId,themeMode,locale,soundEnabled,const DeepCollectionEquality().hash(enabledCharacterIds),hasSeenOnboarding,reminderEnabled,reminderTime,dayStartHour);

@override
String toString() {
  return 'UserSettings(installId: $installId, themeMode: $themeMode, locale: $locale, soundEnabled: $soundEnabled, enabledCharacterIds: $enabledCharacterIds, hasSeenOnboarding: $hasSeenOnboarding, reminderEnabled: $reminderEnabled, reminderTime: $reminderTime, dayStartHour: $dayStartHour)';
}


}

/// @nodoc
abstract mixin class $UserSettingsCopyWith<$Res>  {
  factory $UserSettingsCopyWith(UserSettings value, $Res Function(UserSettings) _then) = _$UserSettingsCopyWithImpl;
@useResult
$Res call({
 String installId, ThemePreference themeMode, LocalePreference locale, bool soundEnabled, List<String> enabledCharacterIds, bool hasSeenOnboarding, bool reminderEnabled, ReminderTime reminderTime, DayStartHour dayStartHour
});




}
/// @nodoc
class _$UserSettingsCopyWithImpl<$Res>
    implements $UserSettingsCopyWith<$Res> {
  _$UserSettingsCopyWithImpl(this._self, this._then);

  final UserSettings _self;
  final $Res Function(UserSettings) _then;

/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? installId = null,Object? themeMode = null,Object? locale = null,Object? soundEnabled = null,Object? enabledCharacterIds = null,Object? hasSeenOnboarding = null,Object? reminderEnabled = null,Object? reminderTime = null,Object? dayStartHour = null,}) {
  return _then(UserSettings(
installId: null == installId ? _self.installId : installId // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemePreference,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as LocalePreference,soundEnabled: null == soundEnabled ? _self.soundEnabled : soundEnabled // ignore: cast_nullable_to_non_nullable
as bool,enabledCharacterIds: null == enabledCharacterIds ? _self.enabledCharacterIds : enabledCharacterIds // ignore: cast_nullable_to_non_nullable
as List<String>,hasSeenOnboarding: null == hasSeenOnboarding ? _self.hasSeenOnboarding : hasSeenOnboarding // ignore: cast_nullable_to_non_nullable
as bool,reminderEnabled: null == reminderEnabled ? _self.reminderEnabled : reminderEnabled // ignore: cast_nullable_to_non_nullable
as bool,reminderTime: null == reminderTime ? _self.reminderTime : reminderTime // ignore: cast_nullable_to_non_nullable
as ReminderTime,dayStartHour: null == dayStartHour ? _self.dayStartHour : dayStartHour // ignore: cast_nullable_to_non_nullable
as DayStartHour,
  ));
}

}


/// Adds pattern-matching-related methods to [UserSettings].
extension UserSettingsPatterns on UserSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserSettings value)  $default,){
final _that = this;
switch (_that) {
case _UserSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserSettings value)?  $default,){
final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String installId,  ThemePreference themeMode,  LocalePreference locale,  bool soundEnabled,  List<String> enabledCharacterIds,  bool hasSeenOnboarding,  bool reminderEnabled,  ReminderTime reminderTime,  DayStartHour dayStartHour)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
return $default(_that.installId,_that.themeMode,_that.locale,_that.soundEnabled,_that.enabledCharacterIds,_that.hasSeenOnboarding,_that.reminderEnabled,_that.reminderTime,_that.dayStartHour);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String installId,  ThemePreference themeMode,  LocalePreference locale,  bool soundEnabled,  List<String> enabledCharacterIds,  bool hasSeenOnboarding,  bool reminderEnabled,  ReminderTime reminderTime,  DayStartHour dayStartHour)  $default,) {final _that = this;
switch (_that) {
case _UserSettings():
return $default(_that.installId,_that.themeMode,_that.locale,_that.soundEnabled,_that.enabledCharacterIds,_that.hasSeenOnboarding,_that.reminderEnabled,_that.reminderTime,_that.dayStartHour);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String installId,  ThemePreference themeMode,  LocalePreference locale,  bool soundEnabled,  List<String> enabledCharacterIds,  bool hasSeenOnboarding,  bool reminderEnabled,  ReminderTime reminderTime,  DayStartHour dayStartHour)?  $default,) {final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
return $default(_that.installId,_that.themeMode,_that.locale,_that.soundEnabled,_that.enabledCharacterIds,_that.hasSeenOnboarding,_that.reminderEnabled,_that.reminderTime,_that.dayStartHour);case _:
  return null;

}
}

}

/// @nodoc


class _UserSettings implements UserSettings {
  const _UserSettings({required this.installId, required this.themeMode, required this.locale, required this.soundEnabled, required  List<String> enabledCharacterIds, required this.hasSeenOnboarding, required this.reminderEnabled, required this.reminderTime, required this.dayStartHour}): _enabledCharacterIds = enabledCharacterIds;
  

/// Anonymous per-install identifier. Never leaves the device.
@override final  String installId;
@override final  ThemePreference themeMode;
@override final  LocalePreference locale;
@override final  bool soundEnabled;
/// Must not be empty (`Validators.enabledCharacterIds`).
 final  List<String> _enabledCharacterIds;
/// Must not be empty (`Validators.enabledCharacterIds`).
@override List<String> get enabledCharacterIds {
  if (_enabledCharacterIds is EqualUnmodifiableListView) return _enabledCharacterIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_enabledCharacterIds);
}

@override final  bool hasSeenOnboarding;
@override final  bool reminderEnabled;
@override final  ReminderTime reminderTime;
@override final  DayStartHour dayStartHour;

/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserSettingsCopyWith<_UserSettings> get copyWith => __$UserSettingsCopyWithImpl<_UserSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserSettings&&(identical(other.installId, installId) || other.installId == installId)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.soundEnabled, soundEnabled) || other.soundEnabled == soundEnabled)&&const DeepCollectionEquality().equals(other._enabledCharacterIds, _enabledCharacterIds)&&(identical(other.hasSeenOnboarding, hasSeenOnboarding) || other.hasSeenOnboarding == hasSeenOnboarding)&&(identical(other.reminderEnabled, reminderEnabled) || other.reminderEnabled == reminderEnabled)&&(identical(other.reminderTime, reminderTime) || other.reminderTime == reminderTime)&&(identical(other.dayStartHour, dayStartHour) || other.dayStartHour == dayStartHour));
}


@override
int get hashCode => Object.hash(runtimeType,installId,themeMode,locale,soundEnabled,const DeepCollectionEquality().hash(_enabledCharacterIds),hasSeenOnboarding,reminderEnabled,reminderTime,dayStartHour);

@override
String toString() {
  return 'UserSettings(installId: $installId, themeMode: $themeMode, locale: $locale, soundEnabled: $soundEnabled, enabledCharacterIds: $enabledCharacterIds, hasSeenOnboarding: $hasSeenOnboarding, reminderEnabled: $reminderEnabled, reminderTime: $reminderTime, dayStartHour: $dayStartHour)';
}


}

/// @nodoc
abstract mixin class _$UserSettingsCopyWith<$Res> implements $UserSettingsCopyWith<$Res> {
  factory _$UserSettingsCopyWith(_UserSettings value, $Res Function(_UserSettings) _then) = __$UserSettingsCopyWithImpl;
@override @useResult
$Res call({
 String installId, ThemePreference themeMode, LocalePreference locale, bool soundEnabled, List<String> enabledCharacterIds, bool hasSeenOnboarding, bool reminderEnabled, ReminderTime reminderTime, DayStartHour dayStartHour
});




}
/// @nodoc
class __$UserSettingsCopyWithImpl<$Res>
    implements _$UserSettingsCopyWith<$Res> {
  __$UserSettingsCopyWithImpl(this._self, this._then);

  final _UserSettings _self;
  final $Res Function(_UserSettings) _then;

/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? installId = null,Object? themeMode = null,Object? locale = null,Object? soundEnabled = null,Object? enabledCharacterIds = null,Object? hasSeenOnboarding = null,Object? reminderEnabled = null,Object? reminderTime = null,Object? dayStartHour = null,}) {
  return _then(_UserSettings(
installId: null == installId ? _self.installId : installId // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemePreference,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as LocalePreference,soundEnabled: null == soundEnabled ? _self.soundEnabled : soundEnabled // ignore: cast_nullable_to_non_nullable
as bool,enabledCharacterIds: null == enabledCharacterIds ? _self._enabledCharacterIds : enabledCharacterIds // ignore: cast_nullable_to_non_nullable
as List<String>,hasSeenOnboarding: null == hasSeenOnboarding ? _self.hasSeenOnboarding : hasSeenOnboarding // ignore: cast_nullable_to_non_nullable
as bool,reminderEnabled: null == reminderEnabled ? _self.reminderEnabled : reminderEnabled // ignore: cast_nullable_to_non_nullable
as bool,reminderTime: null == reminderTime ? _self.reminderTime : reminderTime // ignore: cast_nullable_to_non_nullable
as ReminderTime,dayStartHour: null == dayStartHour ? _self.dayStartHour : dayStartHour // ignore: cast_nullable_to_non_nullable
as DayStartHour,
  ));
}


}

// dart format on
