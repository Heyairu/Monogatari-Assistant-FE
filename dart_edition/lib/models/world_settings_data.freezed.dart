// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'world_settings_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$LocationCustomize {
  String get id => throw _privateConstructorUsedError;
  String get key => throw _privateConstructorUsedError;
  String get val => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String key, String val) raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String key, String val)? raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String key, String val)? raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_LocationCustomize value) raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_LocationCustomize value)? raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_LocationCustomize value)? raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of LocationCustomize
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LocationCustomizeCopyWith<LocationCustomize> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LocationCustomizeCopyWith<$Res> {
  factory $LocationCustomizeCopyWith(
    LocationCustomize value,
    $Res Function(LocationCustomize) then,
  ) = _$LocationCustomizeCopyWithImpl<$Res, LocationCustomize>;
  @useResult
  $Res call({String id, String key, String val});
}

/// @nodoc
class _$LocationCustomizeCopyWithImpl<$Res, $Val extends LocationCustomize>
    implements $LocationCustomizeCopyWith<$Res> {
  _$LocationCustomizeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LocationCustomize
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? key = null, Object? val = null}) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            key: null == key
                ? _value.key
                : key // ignore: cast_nullable_to_non_nullable
                      as String,
            val: null == val
                ? _value.val
                : val // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LocationCustomizeImplCopyWith<$Res>
    implements $LocationCustomizeCopyWith<$Res> {
  factory _$$LocationCustomizeImplCopyWith(
    _$LocationCustomizeImpl value,
    $Res Function(_$LocationCustomizeImpl) then,
  ) = __$$LocationCustomizeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String key, String val});
}

/// @nodoc
class __$$LocationCustomizeImplCopyWithImpl<$Res>
    extends _$LocationCustomizeCopyWithImpl<$Res, _$LocationCustomizeImpl>
    implements _$$LocationCustomizeImplCopyWith<$Res> {
  __$$LocationCustomizeImplCopyWithImpl(
    _$LocationCustomizeImpl _value,
    $Res Function(_$LocationCustomizeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LocationCustomize
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? key = null, Object? val = null}) {
    return _then(
      _$LocationCustomizeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        key: null == key
            ? _value.key
            : key // ignore: cast_nullable_to_non_nullable
                  as String,
        val: null == val
            ? _value.val
            : val // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$LocationCustomizeImpl extends _LocationCustomize {
  const _$LocationCustomizeImpl({
    required this.id,
    this.key = "",
    this.val = "",
  }) : super._();

  @override
  final String id;
  @override
  @JsonKey()
  final String key;
  @override
  @JsonKey()
  final String val;

  @override
  String toString() {
    return 'LocationCustomize.raw(id: $id, key: $key, val: $val)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LocationCustomizeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.val, val) || other.val == val));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, key, val);

  /// Create a copy of LocationCustomize
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LocationCustomizeImplCopyWith<_$LocationCustomizeImpl> get copyWith =>
      __$$LocationCustomizeImplCopyWithImpl<_$LocationCustomizeImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String key, String val) raw,
  }) {
    return raw(id, key, val);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String key, String val)? raw,
  }) {
    return raw?.call(id, key, val);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String key, String val)? raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(id, key, val);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_LocationCustomize value) raw,
  }) {
    return raw(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_LocationCustomize value)? raw,
  }) {
    return raw?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_LocationCustomize value)? raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(this);
    }
    return orElse();
  }
}

abstract class _LocationCustomize extends LocationCustomize {
  const factory _LocationCustomize({
    required final String id,
    final String key,
    final String val,
  }) = _$LocationCustomizeImpl;
  const _LocationCustomize._() : super._();

  @override
  String get id;
  @override
  String get key;
  @override
  String get val;

  /// Create a copy of LocationCustomize
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LocationCustomizeImplCopyWith<_$LocationCustomizeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$LocationData {
  String get id => throw _privateConstructorUsedError;
  String get localName => throw _privateConstructorUsedError;
  String get localType => throw _privateConstructorUsedError;
  WorldNodeType get nodeType => throw _privateConstructorUsedError;
  List<LocationCustomize> get customVal => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;
  List<LocationData> get child => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String localName,
      String localType,
      WorldNodeType nodeType,
      List<LocationCustomize> customVal,
      String note,
      List<LocationData> child,
    )
    raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String id,
      String localName,
      String localType,
      WorldNodeType nodeType,
      List<LocationCustomize> customVal,
      String note,
      List<LocationData> child,
    )?
    raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String id,
      String localName,
      String localType,
      WorldNodeType nodeType,
      List<LocationCustomize> customVal,
      String note,
      List<LocationData> child,
    )?
    raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_LocationData value) raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_LocationData value)? raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_LocationData value)? raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LocationDataCopyWith<LocationData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LocationDataCopyWith<$Res> {
  factory $LocationDataCopyWith(
    LocationData value,
    $Res Function(LocationData) then,
  ) = _$LocationDataCopyWithImpl<$Res, LocationData>;
  @useResult
  $Res call({
    String id,
    String localName,
    String localType,
    WorldNodeType nodeType,
    List<LocationCustomize> customVal,
    String note,
    List<LocationData> child,
  });
}

/// @nodoc
class _$LocationDataCopyWithImpl<$Res, $Val extends LocationData>
    implements $LocationDataCopyWith<$Res> {
  _$LocationDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? localName = null,
    Object? localType = null,
    Object? nodeType = null,
    Object? customVal = null,
    Object? note = null,
    Object? child = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            localName: null == localName
                ? _value.localName
                : localName // ignore: cast_nullable_to_non_nullable
                      as String,
            localType: null == localType
                ? _value.localType
                : localType // ignore: cast_nullable_to_non_nullable
                      as String,
            nodeType: null == nodeType
                ? _value.nodeType
                : nodeType // ignore: cast_nullable_to_non_nullable
                      as WorldNodeType,
            customVal: null == customVal
                ? _value.customVal
                : customVal // ignore: cast_nullable_to_non_nullable
                      as List<LocationCustomize>,
            note: null == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String,
            child: null == child
                ? _value.child
                : child // ignore: cast_nullable_to_non_nullable
                      as List<LocationData>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LocationDataImplCopyWith<$Res>
    implements $LocationDataCopyWith<$Res> {
  factory _$$LocationDataImplCopyWith(
    _$LocationDataImpl value,
    $Res Function(_$LocationDataImpl) then,
  ) = __$$LocationDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String localName,
    String localType,
    WorldNodeType nodeType,
    List<LocationCustomize> customVal,
    String note,
    List<LocationData> child,
  });
}

/// @nodoc
class __$$LocationDataImplCopyWithImpl<$Res>
    extends _$LocationDataCopyWithImpl<$Res, _$LocationDataImpl>
    implements _$$LocationDataImplCopyWith<$Res> {
  __$$LocationDataImplCopyWithImpl(
    _$LocationDataImpl _value,
    $Res Function(_$LocationDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? localName = null,
    Object? localType = null,
    Object? nodeType = null,
    Object? customVal = null,
    Object? note = null,
    Object? child = null,
  }) {
    return _then(
      _$LocationDataImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        localName: null == localName
            ? _value.localName
            : localName // ignore: cast_nullable_to_non_nullable
                  as String,
        localType: null == localType
            ? _value.localType
            : localType // ignore: cast_nullable_to_non_nullable
                  as String,
        nodeType: null == nodeType
            ? _value.nodeType
            : nodeType // ignore: cast_nullable_to_non_nullable
                  as WorldNodeType,
        customVal: null == customVal
            ? _value.customVal
            : customVal // ignore: cast_nullable_to_non_nullable
                  as List<LocationCustomize>,
        note: null == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String,
        child: null == child
            ? _value.child
            : child // ignore: cast_nullable_to_non_nullable
                  as List<LocationData>,
      ),
    );
  }
}

/// @nodoc

class _$LocationDataImpl extends _LocationData {
  const _$LocationDataImpl({
    required this.id,
    this.localName = "",
    this.localType = "",
    this.nodeType = WorldNodeType.location,
    this.customVal = const <LocationCustomize>[],
    this.note = "",
    this.child = const <LocationData>[],
  }) : super._();

  @override
  final String id;
  @override
  @JsonKey()
  final String localName;
  @override
  @JsonKey()
  final String localType;
  @override
  @JsonKey()
  final WorldNodeType nodeType;
  @override
  @JsonKey()
  final List<LocationCustomize> customVal;
  @override
  @JsonKey()
  final String note;
  @override
  @JsonKey()
  final List<LocationData> child;

  @override
  String toString() {
    return 'LocationData.raw(id: $id, localName: $localName, localType: $localType, nodeType: $nodeType, customVal: $customVal, note: $note, child: $child)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LocationDataImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.localName, localName) ||
                other.localName == localName) &&
            (identical(other.localType, localType) ||
                other.localType == localType) &&
            (identical(other.nodeType, nodeType) ||
                other.nodeType == nodeType) &&
            const DeepCollectionEquality().equals(other.customVal, customVal) &&
            (identical(other.note, note) || other.note == note) &&
            const DeepCollectionEquality().equals(other.child, child));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    localName,
    localType,
    nodeType,
    const DeepCollectionEquality().hash(customVal),
    note,
    const DeepCollectionEquality().hash(child),
  );

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LocationDataImplCopyWith<_$LocationDataImpl> get copyWith =>
      __$$LocationDataImplCopyWithImpl<_$LocationDataImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String localName,
      String localType,
      WorldNodeType nodeType,
      List<LocationCustomize> customVal,
      String note,
      List<LocationData> child,
    )
    raw,
  }) {
    return raw(id, localName, localType, nodeType, customVal, note, child);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String id,
      String localName,
      String localType,
      WorldNodeType nodeType,
      List<LocationCustomize> customVal,
      String note,
      List<LocationData> child,
    )?
    raw,
  }) {
    return raw?.call(
      id,
      localName,
      localType,
      nodeType,
      customVal,
      note,
      child,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String id,
      String localName,
      String localType,
      WorldNodeType nodeType,
      List<LocationCustomize> customVal,
      String note,
      List<LocationData> child,
    )?
    raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(id, localName, localType, nodeType, customVal, note, child);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_LocationData value) raw,
  }) {
    return raw(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_LocationData value)? raw,
  }) {
    return raw?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_LocationData value)? raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(this);
    }
    return orElse();
  }
}

abstract class _LocationData extends LocationData {
  const factory _LocationData({
    required final String id,
    final String localName,
    final String localType,
    final WorldNodeType nodeType,
    final List<LocationCustomize> customVal,
    final String note,
    final List<LocationData> child,
  }) = _$LocationDataImpl;
  const _LocationData._() : super._();

  @override
  String get id;
  @override
  String get localName;
  @override
  String get localType;
  @override
  WorldNodeType get nodeType;
  @override
  List<LocationCustomize> get customVal;
  @override
  String get note;
  @override
  List<LocationData> get child;

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LocationDataImplCopyWith<_$LocationDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
