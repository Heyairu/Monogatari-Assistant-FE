// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'timeline_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TickDurationData {
  int get value => throw _privateConstructorUsedError;
  TickDurationUnit get unit => throw _privateConstructorUsedError;
  String get customLabel => throw _privateConstructorUsedError;

  /// Create a copy of TickDurationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TickDurationDataCopyWith<TickDurationData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TickDurationDataCopyWith<$Res> {
  factory $TickDurationDataCopyWith(
    TickDurationData value,
    $Res Function(TickDurationData) then,
  ) = _$TickDurationDataCopyWithImpl<$Res, TickDurationData>;
  @useResult
  $Res call({int value, TickDurationUnit unit, String customLabel});
}

/// @nodoc
class _$TickDurationDataCopyWithImpl<$Res, $Val extends TickDurationData>
    implements $TickDurationDataCopyWith<$Res> {
  _$TickDurationDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TickDurationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = null,
    Object? unit = null,
    Object? customLabel = null,
  }) {
    return _then(
      _value.copyWith(
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as int,
            unit: null == unit
                ? _value.unit
                : unit // ignore: cast_nullable_to_non_nullable
                      as TickDurationUnit,
            customLabel: null == customLabel
                ? _value.customLabel
                : customLabel // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TickDurationDataImplCopyWith<$Res>
    implements $TickDurationDataCopyWith<$Res> {
  factory _$$TickDurationDataImplCopyWith(
    _$TickDurationDataImpl value,
    $Res Function(_$TickDurationDataImpl) then,
  ) = __$$TickDurationDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int value, TickDurationUnit unit, String customLabel});
}

/// @nodoc
class __$$TickDurationDataImplCopyWithImpl<$Res>
    extends _$TickDurationDataCopyWithImpl<$Res, _$TickDurationDataImpl>
    implements _$$TickDurationDataImplCopyWith<$Res> {
  __$$TickDurationDataImplCopyWithImpl(
    _$TickDurationDataImpl _value,
    $Res Function(_$TickDurationDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TickDurationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = null,
    Object? unit = null,
    Object? customLabel = null,
  }) {
    return _then(
      _$TickDurationDataImpl(
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as int,
        unit: null == unit
            ? _value.unit
            : unit // ignore: cast_nullable_to_non_nullable
                  as TickDurationUnit,
        customLabel: null == customLabel
            ? _value.customLabel
            : customLabel // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$TickDurationDataImpl implements _TickDurationData {
  const _$TickDurationDataImpl({
    this.value = 1,
    this.unit = TickDurationUnit.day,
    this.customLabel = "",
  });

  @override
  @JsonKey()
  final int value;
  @override
  @JsonKey()
  final TickDurationUnit unit;
  @override
  @JsonKey()
  final String customLabel;

  @override
  String toString() {
    return 'TickDurationData(value: $value, unit: $unit, customLabel: $customLabel)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TickDurationDataImpl &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.customLabel, customLabel) ||
                other.customLabel == customLabel));
  }

  @override
  int get hashCode => Object.hash(runtimeType, value, unit, customLabel);

  /// Create a copy of TickDurationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TickDurationDataImplCopyWith<_$TickDurationDataImpl> get copyWith =>
      __$$TickDurationDataImplCopyWithImpl<_$TickDurationDataImpl>(
        this,
        _$identity,
      );
}

abstract class _TickDurationData implements TickDurationData {
  const factory _TickDurationData({
    final int value,
    final TickDurationUnit unit,
    final String customLabel,
  }) = _$TickDurationDataImpl;

  @override
  int get value;
  @override
  TickDurationUnit get unit;
  @override
  String get customLabel;

  /// Create a copy of TickDurationData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TickDurationDataImplCopyWith<_$TickDurationDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TimelineGridConfig {
  TickDurationData get ticksPerLittleBox => throw _privateConstructorUsedError;
  int get ticksPerSmallBox => throw _privateConstructorUsedError;
  int get ticksPerMiddleBox => throw _privateConstructorUsedError;
  int get middleBoxesPerLargeBox => throw _privateConstructorUsedError;
  bool get autoSortOutline => throw _privateConstructorUsedError;
  String get originLabel => throw _privateConstructorUsedError;
  String? get originIso8601 => throw _privateConstructorUsedError;

  /// Create a copy of TimelineGridConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimelineGridConfigCopyWith<TimelineGridConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimelineGridConfigCopyWith<$Res> {
  factory $TimelineGridConfigCopyWith(
    TimelineGridConfig value,
    $Res Function(TimelineGridConfig) then,
  ) = _$TimelineGridConfigCopyWithImpl<$Res, TimelineGridConfig>;
  @useResult
  $Res call({
    TickDurationData ticksPerLittleBox,
    int ticksPerSmallBox,
    int ticksPerMiddleBox,
    int middleBoxesPerLargeBox,
    bool autoSortOutline,
    String originLabel,
    String? originIso8601,
  });

  $TickDurationDataCopyWith<$Res> get ticksPerLittleBox;
}

/// @nodoc
class _$TimelineGridConfigCopyWithImpl<$Res, $Val extends TimelineGridConfig>
    implements $TimelineGridConfigCopyWith<$Res> {
  _$TimelineGridConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimelineGridConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ticksPerLittleBox = null,
    Object? ticksPerSmallBox = null,
    Object? ticksPerMiddleBox = null,
    Object? middleBoxesPerLargeBox = null,
    Object? autoSortOutline = null,
    Object? originLabel = null,
    Object? originIso8601 = freezed,
  }) {
    return _then(
      _value.copyWith(
            ticksPerLittleBox: null == ticksPerLittleBox
                ? _value.ticksPerLittleBox
                : ticksPerLittleBox // ignore: cast_nullable_to_non_nullable
                      as TickDurationData,
            ticksPerSmallBox: null == ticksPerSmallBox
                ? _value.ticksPerSmallBox
                : ticksPerSmallBox // ignore: cast_nullable_to_non_nullable
                      as int,
            ticksPerMiddleBox: null == ticksPerMiddleBox
                ? _value.ticksPerMiddleBox
                : ticksPerMiddleBox // ignore: cast_nullable_to_non_nullable
                      as int,
            middleBoxesPerLargeBox: null == middleBoxesPerLargeBox
                ? _value.middleBoxesPerLargeBox
                : middleBoxesPerLargeBox // ignore: cast_nullable_to_non_nullable
                      as int,
            autoSortOutline: null == autoSortOutline
                ? _value.autoSortOutline
                : autoSortOutline // ignore: cast_nullable_to_non_nullable
                      as bool,
            originLabel: null == originLabel
                ? _value.originLabel
                : originLabel // ignore: cast_nullable_to_non_nullable
                      as String,
            originIso8601: freezed == originIso8601
                ? _value.originIso8601
                : originIso8601 // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of TimelineGridConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TickDurationDataCopyWith<$Res> get ticksPerLittleBox {
    return $TickDurationDataCopyWith<$Res>(_value.ticksPerLittleBox, (value) {
      return _then(_value.copyWith(ticksPerLittleBox: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TimelineGridConfigImplCopyWith<$Res>
    implements $TimelineGridConfigCopyWith<$Res> {
  factory _$$TimelineGridConfigImplCopyWith(
    _$TimelineGridConfigImpl value,
    $Res Function(_$TimelineGridConfigImpl) then,
  ) = __$$TimelineGridConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    TickDurationData ticksPerLittleBox,
    int ticksPerSmallBox,
    int ticksPerMiddleBox,
    int middleBoxesPerLargeBox,
    bool autoSortOutline,
    String originLabel,
    String? originIso8601,
  });

  @override
  $TickDurationDataCopyWith<$Res> get ticksPerLittleBox;
}

/// @nodoc
class __$$TimelineGridConfigImplCopyWithImpl<$Res>
    extends _$TimelineGridConfigCopyWithImpl<$Res, _$TimelineGridConfigImpl>
    implements _$$TimelineGridConfigImplCopyWith<$Res> {
  __$$TimelineGridConfigImplCopyWithImpl(
    _$TimelineGridConfigImpl _value,
    $Res Function(_$TimelineGridConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TimelineGridConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ticksPerLittleBox = null,
    Object? ticksPerSmallBox = null,
    Object? ticksPerMiddleBox = null,
    Object? middleBoxesPerLargeBox = null,
    Object? autoSortOutline = null,
    Object? originLabel = null,
    Object? originIso8601 = freezed,
  }) {
    return _then(
      _$TimelineGridConfigImpl(
        ticksPerLittleBox: null == ticksPerLittleBox
            ? _value.ticksPerLittleBox
            : ticksPerLittleBox // ignore: cast_nullable_to_non_nullable
                  as TickDurationData,
        ticksPerSmallBox: null == ticksPerSmallBox
            ? _value.ticksPerSmallBox
            : ticksPerSmallBox // ignore: cast_nullable_to_non_nullable
                  as int,
        ticksPerMiddleBox: null == ticksPerMiddleBox
            ? _value.ticksPerMiddleBox
            : ticksPerMiddleBox // ignore: cast_nullable_to_non_nullable
                  as int,
        middleBoxesPerLargeBox: null == middleBoxesPerLargeBox
            ? _value.middleBoxesPerLargeBox
            : middleBoxesPerLargeBox // ignore: cast_nullable_to_non_nullable
                  as int,
        autoSortOutline: null == autoSortOutline
            ? _value.autoSortOutline
            : autoSortOutline // ignore: cast_nullable_to_non_nullable
                  as bool,
        originLabel: null == originLabel
            ? _value.originLabel
            : originLabel // ignore: cast_nullable_to_non_nullable
                  as String,
        originIso8601: freezed == originIso8601
            ? _value.originIso8601
            : originIso8601 // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$TimelineGridConfigImpl implements _TimelineGridConfig {
  const _$TimelineGridConfigImpl({
    this.ticksPerLittleBox = const TickDurationData(),
    this.ticksPerSmallBox = 1,
    this.ticksPerMiddleBox = 4,
    this.middleBoxesPerLargeBox = 6,
    this.autoSortOutline = false,
    this.originLabel = "故事開始",
    this.originIso8601,
  });

  @override
  @JsonKey()
  final TickDurationData ticksPerLittleBox;
  @override
  @JsonKey()
  final int ticksPerSmallBox;
  @override
  @JsonKey()
  final int ticksPerMiddleBox;
  @override
  @JsonKey()
  final int middleBoxesPerLargeBox;
  @override
  @JsonKey()
  final bool autoSortOutline;
  @override
  @JsonKey()
  final String originLabel;
  @override
  final String? originIso8601;

  @override
  String toString() {
    return 'TimelineGridConfig(ticksPerLittleBox: $ticksPerLittleBox, ticksPerSmallBox: $ticksPerSmallBox, ticksPerMiddleBox: $ticksPerMiddleBox, middleBoxesPerLargeBox: $middleBoxesPerLargeBox, autoSortOutline: $autoSortOutline, originLabel: $originLabel, originIso8601: $originIso8601)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimelineGridConfigImpl &&
            (identical(other.ticksPerLittleBox, ticksPerLittleBox) ||
                other.ticksPerLittleBox == ticksPerLittleBox) &&
            (identical(other.ticksPerSmallBox, ticksPerSmallBox) ||
                other.ticksPerSmallBox == ticksPerSmallBox) &&
            (identical(other.ticksPerMiddleBox, ticksPerMiddleBox) ||
                other.ticksPerMiddleBox == ticksPerMiddleBox) &&
            (identical(other.middleBoxesPerLargeBox, middleBoxesPerLargeBox) ||
                other.middleBoxesPerLargeBox == middleBoxesPerLargeBox) &&
            (identical(other.autoSortOutline, autoSortOutline) ||
                other.autoSortOutline == autoSortOutline) &&
            (identical(other.originLabel, originLabel) ||
                other.originLabel == originLabel) &&
            (identical(other.originIso8601, originIso8601) ||
                other.originIso8601 == originIso8601));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    ticksPerLittleBox,
    ticksPerSmallBox,
    ticksPerMiddleBox,
    middleBoxesPerLargeBox,
    autoSortOutline,
    originLabel,
    originIso8601,
  );

  /// Create a copy of TimelineGridConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimelineGridConfigImplCopyWith<_$TimelineGridConfigImpl> get copyWith =>
      __$$TimelineGridConfigImplCopyWithImpl<_$TimelineGridConfigImpl>(
        this,
        _$identity,
      );
}

abstract class _TimelineGridConfig implements TimelineGridConfig {
  const factory _TimelineGridConfig({
    final TickDurationData ticksPerLittleBox,
    final int ticksPerSmallBox,
    final int ticksPerMiddleBox,
    final int middleBoxesPerLargeBox,
    final bool autoSortOutline,
    final String originLabel,
    final String? originIso8601,
  }) = _$TimelineGridConfigImpl;

  @override
  TickDurationData get ticksPerLittleBox;
  @override
  int get ticksPerSmallBox;
  @override
  int get ticksPerMiddleBox;
  @override
  int get middleBoxesPerLargeBox;
  @override
  bool get autoSortOutline;
  @override
  String get originLabel;
  @override
  String? get originIso8601;

  /// Create a copy of TimelineGridConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimelineGridConfigImplCopyWith<_$TimelineGridConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TimelineTrackData {
  String get trackUUID => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;
  String? get colorToken => throw _privateConstructorUsedError;
  bool get isCollapsed => throw _privateConstructorUsedError;

  /// Create a copy of TimelineTrackData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimelineTrackDataCopyWith<TimelineTrackData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimelineTrackDataCopyWith<$Res> {
  factory $TimelineTrackDataCopyWith(
    TimelineTrackData value,
    $Res Function(TimelineTrackData) then,
  ) = _$TimelineTrackDataCopyWithImpl<$Res, TimelineTrackData>;
  @useResult
  $Res call({
    String trackUUID,
    String name,
    int order,
    String? colorToken,
    bool isCollapsed,
  });
}

/// @nodoc
class _$TimelineTrackDataCopyWithImpl<$Res, $Val extends TimelineTrackData>
    implements $TimelineTrackDataCopyWith<$Res> {
  _$TimelineTrackDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimelineTrackData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? trackUUID = null,
    Object? name = null,
    Object? order = null,
    Object? colorToken = freezed,
    Object? isCollapsed = null,
  }) {
    return _then(
      _value.copyWith(
            trackUUID: null == trackUUID
                ? _value.trackUUID
                : trackUUID // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            order: null == order
                ? _value.order
                : order // ignore: cast_nullable_to_non_nullable
                      as int,
            colorToken: freezed == colorToken
                ? _value.colorToken
                : colorToken // ignore: cast_nullable_to_non_nullable
                      as String?,
            isCollapsed: null == isCollapsed
                ? _value.isCollapsed
                : isCollapsed // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TimelineTrackDataImplCopyWith<$Res>
    implements $TimelineTrackDataCopyWith<$Res> {
  factory _$$TimelineTrackDataImplCopyWith(
    _$TimelineTrackDataImpl value,
    $Res Function(_$TimelineTrackDataImpl) then,
  ) = __$$TimelineTrackDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String trackUUID,
    String name,
    int order,
    String? colorToken,
    bool isCollapsed,
  });
}

/// @nodoc
class __$$TimelineTrackDataImplCopyWithImpl<$Res>
    extends _$TimelineTrackDataCopyWithImpl<$Res, _$TimelineTrackDataImpl>
    implements _$$TimelineTrackDataImplCopyWith<$Res> {
  __$$TimelineTrackDataImplCopyWithImpl(
    _$TimelineTrackDataImpl _value,
    $Res Function(_$TimelineTrackDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TimelineTrackData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? trackUUID = null,
    Object? name = null,
    Object? order = null,
    Object? colorToken = freezed,
    Object? isCollapsed = null,
  }) {
    return _then(
      _$TimelineTrackDataImpl(
        trackUUID: null == trackUUID
            ? _value.trackUUID
            : trackUUID // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        order: null == order
            ? _value.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        colorToken: freezed == colorToken
            ? _value.colorToken
            : colorToken // ignore: cast_nullable_to_non_nullable
                  as String?,
        isCollapsed: null == isCollapsed
            ? _value.isCollapsed
            : isCollapsed // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$TimelineTrackDataImpl implements _TimelineTrackData {
  const _$TimelineTrackDataImpl({
    required this.trackUUID,
    required this.name,
    this.order = 0,
    this.colorToken,
    this.isCollapsed = false,
  });

  @override
  final String trackUUID;
  @override
  final String name;
  @override
  @JsonKey()
  final int order;
  @override
  final String? colorToken;
  @override
  @JsonKey()
  final bool isCollapsed;

  @override
  String toString() {
    return 'TimelineTrackData(trackUUID: $trackUUID, name: $name, order: $order, colorToken: $colorToken, isCollapsed: $isCollapsed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimelineTrackDataImpl &&
            (identical(other.trackUUID, trackUUID) ||
                other.trackUUID == trackUUID) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.order, order) || other.order == order) &&
            (identical(other.colorToken, colorToken) ||
                other.colorToken == colorToken) &&
            (identical(other.isCollapsed, isCollapsed) ||
                other.isCollapsed == isCollapsed));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, trackUUID, name, order, colorToken, isCollapsed);

  /// Create a copy of TimelineTrackData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimelineTrackDataImplCopyWith<_$TimelineTrackDataImpl> get copyWith =>
      __$$TimelineTrackDataImplCopyWithImpl<_$TimelineTrackDataImpl>(
        this,
        _$identity,
      );
}

abstract class _TimelineTrackData implements TimelineTrackData {
  const factory _TimelineTrackData({
    required final String trackUUID,
    required final String name,
    final int order,
    final String? colorToken,
    final bool isCollapsed,
  }) = _$TimelineTrackDataImpl;

  @override
  String get trackUUID;
  @override
  String get name;
  @override
  int get order;
  @override
  String? get colorToken;
  @override
  bool get isCollapsed;

  /// Create a copy of TimelineTrackData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimelineTrackDataImplCopyWith<_$TimelineTrackDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TimelinePlacementData {
  String get placementUUID => throw _privateConstructorUsedError;
  String? get storylineUUID => throw _privateConstructorUsedError;
  String? get eventUUID => throw _privateConstructorUsedError;
  String? get sceneUUID => throw _privateConstructorUsedError;
  String? get parentPlacementUUID => throw _privateConstructorUsedError;
  TimelineElementLevel get level => throw _privateConstructorUsedError;
  String get trackUUID => throw _privateConstructorUsedError;
  int get startTick => throw _privateConstructorUsedError;
  int get durationTicks => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;

  /// Create a copy of TimelinePlacementData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimelinePlacementDataCopyWith<TimelinePlacementData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimelinePlacementDataCopyWith<$Res> {
  factory $TimelinePlacementDataCopyWith(
    TimelinePlacementData value,
    $Res Function(TimelinePlacementData) then,
  ) = _$TimelinePlacementDataCopyWithImpl<$Res, TimelinePlacementData>;
  @useResult
  $Res call({
    String placementUUID,
    String? storylineUUID,
    String? eventUUID,
    String? sceneUUID,
    String? parentPlacementUUID,
    TimelineElementLevel level,
    String trackUUID,
    int startTick,
    int durationTicks,
    int order,
    String label,
  });
}

/// @nodoc
class _$TimelinePlacementDataCopyWithImpl<
  $Res,
  $Val extends TimelinePlacementData
>
    implements $TimelinePlacementDataCopyWith<$Res> {
  _$TimelinePlacementDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimelinePlacementData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? placementUUID = null,
    Object? storylineUUID = freezed,
    Object? eventUUID = freezed,
    Object? sceneUUID = freezed,
    Object? parentPlacementUUID = freezed,
    Object? level = null,
    Object? trackUUID = null,
    Object? startTick = null,
    Object? durationTicks = null,
    Object? order = null,
    Object? label = null,
  }) {
    return _then(
      _value.copyWith(
            placementUUID: null == placementUUID
                ? _value.placementUUID
                : placementUUID // ignore: cast_nullable_to_non_nullable
                      as String,
            storylineUUID: freezed == storylineUUID
                ? _value.storylineUUID
                : storylineUUID // ignore: cast_nullable_to_non_nullable
                      as String?,
            eventUUID: freezed == eventUUID
                ? _value.eventUUID
                : eventUUID // ignore: cast_nullable_to_non_nullable
                      as String?,
            sceneUUID: freezed == sceneUUID
                ? _value.sceneUUID
                : sceneUUID // ignore: cast_nullable_to_non_nullable
                      as String?,
            parentPlacementUUID: freezed == parentPlacementUUID
                ? _value.parentPlacementUUID
                : parentPlacementUUID // ignore: cast_nullable_to_non_nullable
                      as String?,
            level: null == level
                ? _value.level
                : level // ignore: cast_nullable_to_non_nullable
                      as TimelineElementLevel,
            trackUUID: null == trackUUID
                ? _value.trackUUID
                : trackUUID // ignore: cast_nullable_to_non_nullable
                      as String,
            startTick: null == startTick
                ? _value.startTick
                : startTick // ignore: cast_nullable_to_non_nullable
                      as int,
            durationTicks: null == durationTicks
                ? _value.durationTicks
                : durationTicks // ignore: cast_nullable_to_non_nullable
                      as int,
            order: null == order
                ? _value.order
                : order // ignore: cast_nullable_to_non_nullable
                      as int,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TimelinePlacementDataImplCopyWith<$Res>
    implements $TimelinePlacementDataCopyWith<$Res> {
  factory _$$TimelinePlacementDataImplCopyWith(
    _$TimelinePlacementDataImpl value,
    $Res Function(_$TimelinePlacementDataImpl) then,
  ) = __$$TimelinePlacementDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String placementUUID,
    String? storylineUUID,
    String? eventUUID,
    String? sceneUUID,
    String? parentPlacementUUID,
    TimelineElementLevel level,
    String trackUUID,
    int startTick,
    int durationTicks,
    int order,
    String label,
  });
}

/// @nodoc
class __$$TimelinePlacementDataImplCopyWithImpl<$Res>
    extends
        _$TimelinePlacementDataCopyWithImpl<$Res, _$TimelinePlacementDataImpl>
    implements _$$TimelinePlacementDataImplCopyWith<$Res> {
  __$$TimelinePlacementDataImplCopyWithImpl(
    _$TimelinePlacementDataImpl _value,
    $Res Function(_$TimelinePlacementDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TimelinePlacementData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? placementUUID = null,
    Object? storylineUUID = freezed,
    Object? eventUUID = freezed,
    Object? sceneUUID = freezed,
    Object? parentPlacementUUID = freezed,
    Object? level = null,
    Object? trackUUID = null,
    Object? startTick = null,
    Object? durationTicks = null,
    Object? order = null,
    Object? label = null,
  }) {
    return _then(
      _$TimelinePlacementDataImpl(
        placementUUID: null == placementUUID
            ? _value.placementUUID
            : placementUUID // ignore: cast_nullable_to_non_nullable
                  as String,
        storylineUUID: freezed == storylineUUID
            ? _value.storylineUUID
            : storylineUUID // ignore: cast_nullable_to_non_nullable
                  as String?,
        eventUUID: freezed == eventUUID
            ? _value.eventUUID
            : eventUUID // ignore: cast_nullable_to_non_nullable
                  as String?,
        sceneUUID: freezed == sceneUUID
            ? _value.sceneUUID
            : sceneUUID // ignore: cast_nullable_to_non_nullable
                  as String?,
        parentPlacementUUID: freezed == parentPlacementUUID
            ? _value.parentPlacementUUID
            : parentPlacementUUID // ignore: cast_nullable_to_non_nullable
                  as String?,
        level: null == level
            ? _value.level
            : level // ignore: cast_nullable_to_non_nullable
                  as TimelineElementLevel,
        trackUUID: null == trackUUID
            ? _value.trackUUID
            : trackUUID // ignore: cast_nullable_to_non_nullable
                  as String,
        startTick: null == startTick
            ? _value.startTick
            : startTick // ignore: cast_nullable_to_non_nullable
                  as int,
        durationTicks: null == durationTicks
            ? _value.durationTicks
            : durationTicks // ignore: cast_nullable_to_non_nullable
                  as int,
        order: null == order
            ? _value.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$TimelinePlacementDataImpl extends _TimelinePlacementData {
  const _$TimelinePlacementDataImpl({
    required this.placementUUID,
    this.storylineUUID,
    this.eventUUID,
    this.sceneUUID,
    this.parentPlacementUUID,
    this.level = TimelineElementLevel.small,
    required this.trackUUID,
    this.startTick = 0,
    this.durationTicks = 1,
    this.order = 0,
    this.label = "",
  }) : super._();

  @override
  final String placementUUID;
  @override
  final String? storylineUUID;
  @override
  final String? eventUUID;
  @override
  final String? sceneUUID;
  @override
  final String? parentPlacementUUID;
  @override
  @JsonKey()
  final TimelineElementLevel level;
  @override
  final String trackUUID;
  @override
  @JsonKey()
  final int startTick;
  @override
  @JsonKey()
  final int durationTicks;
  @override
  @JsonKey()
  final int order;
  @override
  @JsonKey()
  final String label;

  @override
  String toString() {
    return 'TimelinePlacementData(placementUUID: $placementUUID, storylineUUID: $storylineUUID, eventUUID: $eventUUID, sceneUUID: $sceneUUID, parentPlacementUUID: $parentPlacementUUID, level: $level, trackUUID: $trackUUID, startTick: $startTick, durationTicks: $durationTicks, order: $order, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimelinePlacementDataImpl &&
            (identical(other.placementUUID, placementUUID) ||
                other.placementUUID == placementUUID) &&
            (identical(other.storylineUUID, storylineUUID) ||
                other.storylineUUID == storylineUUID) &&
            (identical(other.eventUUID, eventUUID) ||
                other.eventUUID == eventUUID) &&
            (identical(other.sceneUUID, sceneUUID) ||
                other.sceneUUID == sceneUUID) &&
            (identical(other.parentPlacementUUID, parentPlacementUUID) ||
                other.parentPlacementUUID == parentPlacementUUID) &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.trackUUID, trackUUID) ||
                other.trackUUID == trackUUID) &&
            (identical(other.startTick, startTick) ||
                other.startTick == startTick) &&
            (identical(other.durationTicks, durationTicks) ||
                other.durationTicks == durationTicks) &&
            (identical(other.order, order) || other.order == order) &&
            (identical(other.label, label) || other.label == label));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    placementUUID,
    storylineUUID,
    eventUUID,
    sceneUUID,
    parentPlacementUUID,
    level,
    trackUUID,
    startTick,
    durationTicks,
    order,
    label,
  );

  /// Create a copy of TimelinePlacementData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimelinePlacementDataImplCopyWith<_$TimelinePlacementDataImpl>
  get copyWith =>
      __$$TimelinePlacementDataImplCopyWithImpl<_$TimelinePlacementDataImpl>(
        this,
        _$identity,
      );
}

abstract class _TimelinePlacementData extends TimelinePlacementData {
  const factory _TimelinePlacementData({
    required final String placementUUID,
    final String? storylineUUID,
    final String? eventUUID,
    final String? sceneUUID,
    final String? parentPlacementUUID,
    final TimelineElementLevel level,
    required final String trackUUID,
    final int startTick,
    final int durationTicks,
    final int order,
    final String label,
  }) = _$TimelinePlacementDataImpl;
  const _TimelinePlacementData._() : super._();

  @override
  String get placementUUID;
  @override
  String? get storylineUUID;
  @override
  String? get eventUUID;
  @override
  String? get sceneUUID;
  @override
  String? get parentPlacementUUID;
  @override
  TimelineElementLevel get level;
  @override
  String get trackUUID;
  @override
  int get startTick;
  @override
  int get durationTicks;
  @override
  int get order;
  @override
  String get label;

  /// Create a copy of TimelinePlacementData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimelinePlacementDataImplCopyWith<_$TimelinePlacementDataImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$OutlineChapterLinkData {
  String get linkUUID => throw _privateConstructorUsedError;
  String get sceneUUID => throw _privateConstructorUsedError;
  String get chapterUUID => throw _privateConstructorUsedError;
  int get sequence => throw _privateConstructorUsedError;
  ChapterLinkCoverage get coverage => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Create a copy of OutlineChapterLinkData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OutlineChapterLinkDataCopyWith<OutlineChapterLinkData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OutlineChapterLinkDataCopyWith<$Res> {
  factory $OutlineChapterLinkDataCopyWith(
    OutlineChapterLinkData value,
    $Res Function(OutlineChapterLinkData) then,
  ) = _$OutlineChapterLinkDataCopyWithImpl<$Res, OutlineChapterLinkData>;
  @useResult
  $Res call({
    String linkUUID,
    String sceneUUID,
    String chapterUUID,
    int sequence,
    ChapterLinkCoverage coverage,
    String? note,
  });
}

/// @nodoc
class _$OutlineChapterLinkDataCopyWithImpl<
  $Res,
  $Val extends OutlineChapterLinkData
>
    implements $OutlineChapterLinkDataCopyWith<$Res> {
  _$OutlineChapterLinkDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OutlineChapterLinkData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? linkUUID = null,
    Object? sceneUUID = null,
    Object? chapterUUID = null,
    Object? sequence = null,
    Object? coverage = null,
    Object? note = freezed,
  }) {
    return _then(
      _value.copyWith(
            linkUUID: null == linkUUID
                ? _value.linkUUID
                : linkUUID // ignore: cast_nullable_to_non_nullable
                      as String,
            sceneUUID: null == sceneUUID
                ? _value.sceneUUID
                : sceneUUID // ignore: cast_nullable_to_non_nullable
                      as String,
            chapterUUID: null == chapterUUID
                ? _value.chapterUUID
                : chapterUUID // ignore: cast_nullable_to_non_nullable
                      as String,
            sequence: null == sequence
                ? _value.sequence
                : sequence // ignore: cast_nullable_to_non_nullable
                      as int,
            coverage: null == coverage
                ? _value.coverage
                : coverage // ignore: cast_nullable_to_non_nullable
                      as ChapterLinkCoverage,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OutlineChapterLinkDataImplCopyWith<$Res>
    implements $OutlineChapterLinkDataCopyWith<$Res> {
  factory _$$OutlineChapterLinkDataImplCopyWith(
    _$OutlineChapterLinkDataImpl value,
    $Res Function(_$OutlineChapterLinkDataImpl) then,
  ) = __$$OutlineChapterLinkDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String linkUUID,
    String sceneUUID,
    String chapterUUID,
    int sequence,
    ChapterLinkCoverage coverage,
    String? note,
  });
}

/// @nodoc
class __$$OutlineChapterLinkDataImplCopyWithImpl<$Res>
    extends
        _$OutlineChapterLinkDataCopyWithImpl<$Res, _$OutlineChapterLinkDataImpl>
    implements _$$OutlineChapterLinkDataImplCopyWith<$Res> {
  __$$OutlineChapterLinkDataImplCopyWithImpl(
    _$OutlineChapterLinkDataImpl _value,
    $Res Function(_$OutlineChapterLinkDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OutlineChapterLinkData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? linkUUID = null,
    Object? sceneUUID = null,
    Object? chapterUUID = null,
    Object? sequence = null,
    Object? coverage = null,
    Object? note = freezed,
  }) {
    return _then(
      _$OutlineChapterLinkDataImpl(
        linkUUID: null == linkUUID
            ? _value.linkUUID
            : linkUUID // ignore: cast_nullable_to_non_nullable
                  as String,
        sceneUUID: null == sceneUUID
            ? _value.sceneUUID
            : sceneUUID // ignore: cast_nullable_to_non_nullable
                  as String,
        chapterUUID: null == chapterUUID
            ? _value.chapterUUID
            : chapterUUID // ignore: cast_nullable_to_non_nullable
                  as String,
        sequence: null == sequence
            ? _value.sequence
            : sequence // ignore: cast_nullable_to_non_nullable
                  as int,
        coverage: null == coverage
            ? _value.coverage
            : coverage // ignore: cast_nullable_to_non_nullable
                  as ChapterLinkCoverage,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$OutlineChapterLinkDataImpl implements _OutlineChapterLinkData {
  const _$OutlineChapterLinkDataImpl({
    required this.linkUUID,
    required this.sceneUUID,
    required this.chapterUUID,
    this.sequence = 0,
    this.coverage = ChapterLinkCoverage.full,
    this.note,
  });

  @override
  final String linkUUID;
  @override
  final String sceneUUID;
  @override
  final String chapterUUID;
  @override
  @JsonKey()
  final int sequence;
  @override
  @JsonKey()
  final ChapterLinkCoverage coverage;
  @override
  final String? note;

  @override
  String toString() {
    return 'OutlineChapterLinkData(linkUUID: $linkUUID, sceneUUID: $sceneUUID, chapterUUID: $chapterUUID, sequence: $sequence, coverage: $coverage, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OutlineChapterLinkDataImpl &&
            (identical(other.linkUUID, linkUUID) ||
                other.linkUUID == linkUUID) &&
            (identical(other.sceneUUID, sceneUUID) ||
                other.sceneUUID == sceneUUID) &&
            (identical(other.chapterUUID, chapterUUID) ||
                other.chapterUUID == chapterUUID) &&
            (identical(other.sequence, sequence) ||
                other.sequence == sequence) &&
            (identical(other.coverage, coverage) ||
                other.coverage == coverage) &&
            (identical(other.note, note) || other.note == note));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    linkUUID,
    sceneUUID,
    chapterUUID,
    sequence,
    coverage,
    note,
  );

  /// Create a copy of OutlineChapterLinkData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OutlineChapterLinkDataImplCopyWith<_$OutlineChapterLinkDataImpl>
  get copyWith =>
      __$$OutlineChapterLinkDataImplCopyWithImpl<_$OutlineChapterLinkDataImpl>(
        this,
        _$identity,
      );
}

abstract class _OutlineChapterLinkData implements OutlineChapterLinkData {
  const factory _OutlineChapterLinkData({
    required final String linkUUID,
    required final String sceneUUID,
    required final String chapterUUID,
    final int sequence,
    final ChapterLinkCoverage coverage,
    final String? note,
  }) = _$OutlineChapterLinkDataImpl;

  @override
  String get linkUUID;
  @override
  String get sceneUUID;
  @override
  String get chapterUUID;
  @override
  int get sequence;
  @override
  ChapterLinkCoverage get coverage;
  @override
  String? get note;

  /// Create a copy of OutlineChapterLinkData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OutlineChapterLinkDataImplCopyWith<_$OutlineChapterLinkDataImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TimelineDocumentData {
  TimelineGridConfig get grid => throw _privateConstructorUsedError;
  List<TimelineTrackData> get tracks => throw _privateConstructorUsedError;
  List<TimelinePlacementData> get placements =>
      throw _privateConstructorUsedError;

  /// Create a copy of TimelineDocumentData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimelineDocumentDataCopyWith<TimelineDocumentData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimelineDocumentDataCopyWith<$Res> {
  factory $TimelineDocumentDataCopyWith(
    TimelineDocumentData value,
    $Res Function(TimelineDocumentData) then,
  ) = _$TimelineDocumentDataCopyWithImpl<$Res, TimelineDocumentData>;
  @useResult
  $Res call({
    TimelineGridConfig grid,
    List<TimelineTrackData> tracks,
    List<TimelinePlacementData> placements,
  });

  $TimelineGridConfigCopyWith<$Res> get grid;
}

/// @nodoc
class _$TimelineDocumentDataCopyWithImpl<
  $Res,
  $Val extends TimelineDocumentData
>
    implements $TimelineDocumentDataCopyWith<$Res> {
  _$TimelineDocumentDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimelineDocumentData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? grid = null,
    Object? tracks = null,
    Object? placements = null,
  }) {
    return _then(
      _value.copyWith(
            grid: null == grid
                ? _value.grid
                : grid // ignore: cast_nullable_to_non_nullable
                      as TimelineGridConfig,
            tracks: null == tracks
                ? _value.tracks
                : tracks // ignore: cast_nullable_to_non_nullable
                      as List<TimelineTrackData>,
            placements: null == placements
                ? _value.placements
                : placements // ignore: cast_nullable_to_non_nullable
                      as List<TimelinePlacementData>,
          )
          as $Val,
    );
  }

  /// Create a copy of TimelineDocumentData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TimelineGridConfigCopyWith<$Res> get grid {
    return $TimelineGridConfigCopyWith<$Res>(_value.grid, (value) {
      return _then(_value.copyWith(grid: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TimelineDocumentDataImplCopyWith<$Res>
    implements $TimelineDocumentDataCopyWith<$Res> {
  factory _$$TimelineDocumentDataImplCopyWith(
    _$TimelineDocumentDataImpl value,
    $Res Function(_$TimelineDocumentDataImpl) then,
  ) = __$$TimelineDocumentDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    TimelineGridConfig grid,
    List<TimelineTrackData> tracks,
    List<TimelinePlacementData> placements,
  });

  @override
  $TimelineGridConfigCopyWith<$Res> get grid;
}

/// @nodoc
class __$$TimelineDocumentDataImplCopyWithImpl<$Res>
    extends _$TimelineDocumentDataCopyWithImpl<$Res, _$TimelineDocumentDataImpl>
    implements _$$TimelineDocumentDataImplCopyWith<$Res> {
  __$$TimelineDocumentDataImplCopyWithImpl(
    _$TimelineDocumentDataImpl _value,
    $Res Function(_$TimelineDocumentDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TimelineDocumentData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? grid = null,
    Object? tracks = null,
    Object? placements = null,
  }) {
    return _then(
      _$TimelineDocumentDataImpl(
        grid: null == grid
            ? _value.grid
            : grid // ignore: cast_nullable_to_non_nullable
                  as TimelineGridConfig,
        tracks: null == tracks
            ? _value._tracks
            : tracks // ignore: cast_nullable_to_non_nullable
                  as List<TimelineTrackData>,
        placements: null == placements
            ? _value._placements
            : placements // ignore: cast_nullable_to_non_nullable
                  as List<TimelinePlacementData>,
      ),
    );
  }
}

/// @nodoc

class _$TimelineDocumentDataImpl implements _TimelineDocumentData {
  const _$TimelineDocumentDataImpl({
    this.grid = const TimelineGridConfig(),
    final List<TimelineTrackData> tracks = const <TimelineTrackData>[],
    final List<TimelinePlacementData> placements =
        const <TimelinePlacementData>[],
  }) : _tracks = tracks,
       _placements = placements;

  @override
  @JsonKey()
  final TimelineGridConfig grid;
  final List<TimelineTrackData> _tracks;
  @override
  @JsonKey()
  List<TimelineTrackData> get tracks {
    if (_tracks is EqualUnmodifiableListView) return _tracks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tracks);
  }

  final List<TimelinePlacementData> _placements;
  @override
  @JsonKey()
  List<TimelinePlacementData> get placements {
    if (_placements is EqualUnmodifiableListView) return _placements;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_placements);
  }

  @override
  String toString() {
    return 'TimelineDocumentData(grid: $grid, tracks: $tracks, placements: $placements)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimelineDocumentDataImpl &&
            (identical(other.grid, grid) || other.grid == grid) &&
            const DeepCollectionEquality().equals(other._tracks, _tracks) &&
            const DeepCollectionEquality().equals(
              other._placements,
              _placements,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    grid,
    const DeepCollectionEquality().hash(_tracks),
    const DeepCollectionEquality().hash(_placements),
  );

  /// Create a copy of TimelineDocumentData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimelineDocumentDataImplCopyWith<_$TimelineDocumentDataImpl>
  get copyWith =>
      __$$TimelineDocumentDataImplCopyWithImpl<_$TimelineDocumentDataImpl>(
        this,
        _$identity,
      );
}

abstract class _TimelineDocumentData implements TimelineDocumentData {
  const factory _TimelineDocumentData({
    final TimelineGridConfig grid,
    final List<TimelineTrackData> tracks,
    final List<TimelinePlacementData> placements,
  }) = _$TimelineDocumentDataImpl;

  @override
  TimelineGridConfig get grid;
  @override
  List<TimelineTrackData> get tracks;
  @override
  List<TimelinePlacementData> get placements;

  /// Create a copy of TimelineDocumentData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimelineDocumentDataImplCopyWith<_$TimelineDocumentDataImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TimelineProjectData {
  TimelineDocumentData get document => throw _privateConstructorUsedError;
  List<OutlineChapterLinkData> get chapterLinks =>
      throw _privateConstructorUsedError;

  /// Create a copy of TimelineProjectData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimelineProjectDataCopyWith<TimelineProjectData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimelineProjectDataCopyWith<$Res> {
  factory $TimelineProjectDataCopyWith(
    TimelineProjectData value,
    $Res Function(TimelineProjectData) then,
  ) = _$TimelineProjectDataCopyWithImpl<$Res, TimelineProjectData>;
  @useResult
  $Res call({
    TimelineDocumentData document,
    List<OutlineChapterLinkData> chapterLinks,
  });

  $TimelineDocumentDataCopyWith<$Res> get document;
}

/// @nodoc
class _$TimelineProjectDataCopyWithImpl<$Res, $Val extends TimelineProjectData>
    implements $TimelineProjectDataCopyWith<$Res> {
  _$TimelineProjectDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimelineProjectData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? document = null, Object? chapterLinks = null}) {
    return _then(
      _value.copyWith(
            document: null == document
                ? _value.document
                : document // ignore: cast_nullable_to_non_nullable
                      as TimelineDocumentData,
            chapterLinks: null == chapterLinks
                ? _value.chapterLinks
                : chapterLinks // ignore: cast_nullable_to_non_nullable
                      as List<OutlineChapterLinkData>,
          )
          as $Val,
    );
  }

  /// Create a copy of TimelineProjectData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TimelineDocumentDataCopyWith<$Res> get document {
    return $TimelineDocumentDataCopyWith<$Res>(_value.document, (value) {
      return _then(_value.copyWith(document: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TimelineProjectDataImplCopyWith<$Res>
    implements $TimelineProjectDataCopyWith<$Res> {
  factory _$$TimelineProjectDataImplCopyWith(
    _$TimelineProjectDataImpl value,
    $Res Function(_$TimelineProjectDataImpl) then,
  ) = __$$TimelineProjectDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    TimelineDocumentData document,
    List<OutlineChapterLinkData> chapterLinks,
  });

  @override
  $TimelineDocumentDataCopyWith<$Res> get document;
}

/// @nodoc
class __$$TimelineProjectDataImplCopyWithImpl<$Res>
    extends _$TimelineProjectDataCopyWithImpl<$Res, _$TimelineProjectDataImpl>
    implements _$$TimelineProjectDataImplCopyWith<$Res> {
  __$$TimelineProjectDataImplCopyWithImpl(
    _$TimelineProjectDataImpl _value,
    $Res Function(_$TimelineProjectDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TimelineProjectData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? document = null, Object? chapterLinks = null}) {
    return _then(
      _$TimelineProjectDataImpl(
        document: null == document
            ? _value.document
            : document // ignore: cast_nullable_to_non_nullable
                  as TimelineDocumentData,
        chapterLinks: null == chapterLinks
            ? _value._chapterLinks
            : chapterLinks // ignore: cast_nullable_to_non_nullable
                  as List<OutlineChapterLinkData>,
      ),
    );
  }
}

/// @nodoc

class _$TimelineProjectDataImpl implements _TimelineProjectData {
  const _$TimelineProjectDataImpl({
    required this.document,
    final List<OutlineChapterLinkData> chapterLinks =
        const <OutlineChapterLinkData>[],
  }) : _chapterLinks = chapterLinks;

  @override
  final TimelineDocumentData document;
  final List<OutlineChapterLinkData> _chapterLinks;
  @override
  @JsonKey()
  List<OutlineChapterLinkData> get chapterLinks {
    if (_chapterLinks is EqualUnmodifiableListView) return _chapterLinks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapterLinks);
  }

  @override
  String toString() {
    return 'TimelineProjectData(document: $document, chapterLinks: $chapterLinks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimelineProjectDataImpl &&
            (identical(other.document, document) ||
                other.document == document) &&
            const DeepCollectionEquality().equals(
              other._chapterLinks,
              _chapterLinks,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    document,
    const DeepCollectionEquality().hash(_chapterLinks),
  );

  /// Create a copy of TimelineProjectData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimelineProjectDataImplCopyWith<_$TimelineProjectDataImpl> get copyWith =>
      __$$TimelineProjectDataImplCopyWithImpl<_$TimelineProjectDataImpl>(
        this,
        _$identity,
      );
}

abstract class _TimelineProjectData implements TimelineProjectData {
  const factory _TimelineProjectData({
    required final TimelineDocumentData document,
    final List<OutlineChapterLinkData> chapterLinks,
  }) = _$TimelineProjectDataImpl;

  @override
  TimelineDocumentData get document;
  @override
  List<OutlineChapterLinkData> get chapterLinks;

  /// Create a copy of TimelineProjectData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimelineProjectDataImplCopyWith<_$TimelineProjectDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
