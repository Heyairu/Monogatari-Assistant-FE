// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_state_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AppThemeStateData {
  AppThemeMode get themeMode => throw _privateConstructorUsedError;
  Color get themeColor => throw _privateConstructorUsedError;

  /// Create a copy of AppThemeStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppThemeStateDataCopyWith<AppThemeStateData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppThemeStateDataCopyWith<$Res> {
  factory $AppThemeStateDataCopyWith(
    AppThemeStateData value,
    $Res Function(AppThemeStateData) then,
  ) = _$AppThemeStateDataCopyWithImpl<$Res, AppThemeStateData>;
  @useResult
  $Res call({AppThemeMode themeMode, Color themeColor});
}

/// @nodoc
class _$AppThemeStateDataCopyWithImpl<$Res, $Val extends AppThemeStateData>
    implements $AppThemeStateDataCopyWith<$Res> {
  _$AppThemeStateDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppThemeStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? themeMode = null, Object? themeColor = null}) {
    return _then(
      _value.copyWith(
            themeMode: null == themeMode
                ? _value.themeMode
                : themeMode // ignore: cast_nullable_to_non_nullable
                      as AppThemeMode,
            themeColor: null == themeColor
                ? _value.themeColor
                : themeColor // ignore: cast_nullable_to_non_nullable
                      as Color,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppThemeStateDataImplCopyWith<$Res>
    implements $AppThemeStateDataCopyWith<$Res> {
  factory _$$AppThemeStateDataImplCopyWith(
    _$AppThemeStateDataImpl value,
    $Res Function(_$AppThemeStateDataImpl) then,
  ) = __$$AppThemeStateDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({AppThemeMode themeMode, Color themeColor});
}

/// @nodoc
class __$$AppThemeStateDataImplCopyWithImpl<$Res>
    extends _$AppThemeStateDataCopyWithImpl<$Res, _$AppThemeStateDataImpl>
    implements _$$AppThemeStateDataImplCopyWith<$Res> {
  __$$AppThemeStateDataImplCopyWithImpl(
    _$AppThemeStateDataImpl _value,
    $Res Function(_$AppThemeStateDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppThemeStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? themeMode = null, Object? themeColor = null}) {
    return _then(
      _$AppThemeStateDataImpl(
        themeMode: null == themeMode
            ? _value.themeMode
            : themeMode // ignore: cast_nullable_to_non_nullable
                  as AppThemeMode,
        themeColor: null == themeColor
            ? _value.themeColor
            : themeColor // ignore: cast_nullable_to_non_nullable
                  as Color,
      ),
    );
  }
}

/// @nodoc

class _$AppThemeStateDataImpl implements _AppThemeStateData {
  const _$AppThemeStateDataImpl({
    this.themeMode = AppThemeMode.system,
    this.themeColor = Colors.lightBlue,
  });

  @override
  @JsonKey()
  final AppThemeMode themeMode;
  @override
  @JsonKey()
  final Color themeColor;

  @override
  String toString() {
    return 'AppThemeStateData(themeMode: $themeMode, themeColor: $themeColor)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppThemeStateDataImpl &&
            (identical(other.themeMode, themeMode) ||
                other.themeMode == themeMode) &&
            (identical(other.themeColor, themeColor) ||
                other.themeColor == themeColor));
  }

  @override
  int get hashCode => Object.hash(runtimeType, themeMode, themeColor);

  /// Create a copy of AppThemeStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppThemeStateDataImplCopyWith<_$AppThemeStateDataImpl> get copyWith =>
      __$$AppThemeStateDataImplCopyWithImpl<_$AppThemeStateDataImpl>(
        this,
        _$identity,
      );
}

abstract class _AppThemeStateData implements AppThemeStateData {
  const factory _AppThemeStateData({
    final AppThemeMode themeMode,
    final Color themeColor,
  }) = _$AppThemeStateDataImpl;

  @override
  AppThemeMode get themeMode;
  @override
  Color get themeColor;

  /// Create a copy of AppThemeStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppThemeStateDataImplCopyWith<_$AppThemeStateDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AppSettingsStateData {
  bool get showExitWarning => throw _privateConstructorUsedError;
  double get fontSize => throw _privateConstructorUsedError;
  WordCountMode get wordCountMode => throw _privateConstructorUsedError;
  List<RecentProjectEntry> get recentProjects =>
      throw _privateConstructorUsedError;

  /// Create a copy of AppSettingsStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppSettingsStateDataCopyWith<AppSettingsStateData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppSettingsStateDataCopyWith<$Res> {
  factory $AppSettingsStateDataCopyWith(
    AppSettingsStateData value,
    $Res Function(AppSettingsStateData) then,
  ) = _$AppSettingsStateDataCopyWithImpl<$Res, AppSettingsStateData>;
  @useResult
  $Res call({
    bool showExitWarning,
    double fontSize,
    WordCountMode wordCountMode,
    List<RecentProjectEntry> recentProjects,
  });
}

/// @nodoc
class _$AppSettingsStateDataCopyWithImpl<
  $Res,
  $Val extends AppSettingsStateData
>
    implements $AppSettingsStateDataCopyWith<$Res> {
  _$AppSettingsStateDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppSettingsStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? showExitWarning = null,
    Object? fontSize = null,
    Object? wordCountMode = null,
    Object? recentProjects = null,
  }) {
    return _then(
      _value.copyWith(
            showExitWarning: null == showExitWarning
                ? _value.showExitWarning
                : showExitWarning // ignore: cast_nullable_to_non_nullable
                      as bool,
            fontSize: null == fontSize
                ? _value.fontSize
                : fontSize // ignore: cast_nullable_to_non_nullable
                      as double,
            wordCountMode: null == wordCountMode
                ? _value.wordCountMode
                : wordCountMode // ignore: cast_nullable_to_non_nullable
                      as WordCountMode,
            recentProjects: null == recentProjects
                ? _value.recentProjects
                : recentProjects // ignore: cast_nullable_to_non_nullable
                      as List<RecentProjectEntry>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppSettingsStateDataImplCopyWith<$Res>
    implements $AppSettingsStateDataCopyWith<$Res> {
  factory _$$AppSettingsStateDataImplCopyWith(
    _$AppSettingsStateDataImpl value,
    $Res Function(_$AppSettingsStateDataImpl) then,
  ) = __$$AppSettingsStateDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool showExitWarning,
    double fontSize,
    WordCountMode wordCountMode,
    List<RecentProjectEntry> recentProjects,
  });
}

/// @nodoc
class __$$AppSettingsStateDataImplCopyWithImpl<$Res>
    extends _$AppSettingsStateDataCopyWithImpl<$Res, _$AppSettingsStateDataImpl>
    implements _$$AppSettingsStateDataImplCopyWith<$Res> {
  __$$AppSettingsStateDataImplCopyWithImpl(
    _$AppSettingsStateDataImpl _value,
    $Res Function(_$AppSettingsStateDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppSettingsStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? showExitWarning = null,
    Object? fontSize = null,
    Object? wordCountMode = null,
    Object? recentProjects = null,
  }) {
    return _then(
      _$AppSettingsStateDataImpl(
        showExitWarning: null == showExitWarning
            ? _value.showExitWarning
            : showExitWarning // ignore: cast_nullable_to_non_nullable
                  as bool,
        fontSize: null == fontSize
            ? _value.fontSize
            : fontSize // ignore: cast_nullable_to_non_nullable
                  as double,
        wordCountMode: null == wordCountMode
            ? _value.wordCountMode
            : wordCountMode // ignore: cast_nullable_to_non_nullable
                  as WordCountMode,
        recentProjects: null == recentProjects
            ? _value._recentProjects
            : recentProjects // ignore: cast_nullable_to_non_nullable
                  as List<RecentProjectEntry>,
      ),
    );
  }
}

/// @nodoc

class _$AppSettingsStateDataImpl implements _AppSettingsStateData {
  const _$AppSettingsStateDataImpl({
    this.showExitWarning = true,
    this.fontSize = 12.0,
    this.wordCountMode = WordCountMode.wordsAndCharacters,
    final List<RecentProjectEntry> recentProjects =
        const <RecentProjectEntry>[],
  }) : _recentProjects = recentProjects;

  @override
  @JsonKey()
  final bool showExitWarning;
  @override
  @JsonKey()
  final double fontSize;
  @override
  @JsonKey()
  final WordCountMode wordCountMode;
  final List<RecentProjectEntry> _recentProjects;
  @override
  @JsonKey()
  List<RecentProjectEntry> get recentProjects {
    if (_recentProjects is EqualUnmodifiableListView) return _recentProjects;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentProjects);
  }

  @override
  String toString() {
    return 'AppSettingsStateData(showExitWarning: $showExitWarning, fontSize: $fontSize, wordCountMode: $wordCountMode, recentProjects: $recentProjects)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppSettingsStateDataImpl &&
            (identical(other.showExitWarning, showExitWarning) ||
                other.showExitWarning == showExitWarning) &&
            (identical(other.fontSize, fontSize) ||
                other.fontSize == fontSize) &&
            (identical(other.wordCountMode, wordCountMode) ||
                other.wordCountMode == wordCountMode) &&
            const DeepCollectionEquality().equals(
              other._recentProjects,
              _recentProjects,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    showExitWarning,
    fontSize,
    wordCountMode,
    const DeepCollectionEquality().hash(_recentProjects),
  );

  /// Create a copy of AppSettingsStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppSettingsStateDataImplCopyWith<_$AppSettingsStateDataImpl>
  get copyWith =>
      __$$AppSettingsStateDataImplCopyWithImpl<_$AppSettingsStateDataImpl>(
        this,
        _$identity,
      );
}

abstract class _AppSettingsStateData implements AppSettingsStateData {
  const factory _AppSettingsStateData({
    final bool showExitWarning,
    final double fontSize,
    final WordCountMode wordCountMode,
    final List<RecentProjectEntry> recentProjects,
  }) = _$AppSettingsStateDataImpl;

  @override
  bool get showExitWarning;
  @override
  double get fontSize;
  @override
  WordCountMode get wordCountMode;
  @override
  List<RecentProjectEntry> get recentProjects;

  /// Create a copy of AppSettingsStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppSettingsStateDataImplCopyWith<_$AppSettingsStateDataImpl>
  get copyWith => throw _privateConstructorUsedError;
}
