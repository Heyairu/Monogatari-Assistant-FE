// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ForeshadowItem {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;
  bool get isRevealed => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String title,
      String note,
      bool isRevealed,
    )
    raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String title, String note, bool isRevealed)?
    raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String title, String note, bool isRevealed)?
    raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ForeshadowItem value) raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ForeshadowItem value)? raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ForeshadowItem value)? raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of ForeshadowItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ForeshadowItemCopyWith<ForeshadowItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ForeshadowItemCopyWith<$Res> {
  factory $ForeshadowItemCopyWith(
    ForeshadowItem value,
    $Res Function(ForeshadowItem) then,
  ) = _$ForeshadowItemCopyWithImpl<$Res, ForeshadowItem>;
  @useResult
  $Res call({String id, String title, String note, bool isRevealed});
}

/// @nodoc
class _$ForeshadowItemCopyWithImpl<$Res, $Val extends ForeshadowItem>
    implements $ForeshadowItemCopyWith<$Res> {
  _$ForeshadowItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ForeshadowItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? note = null,
    Object? isRevealed = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            note: null == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String,
            isRevealed: null == isRevealed
                ? _value.isRevealed
                : isRevealed // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ForeshadowItemImplCopyWith<$Res>
    implements $ForeshadowItemCopyWith<$Res> {
  factory _$$ForeshadowItemImplCopyWith(
    _$ForeshadowItemImpl value,
    $Res Function(_$ForeshadowItemImpl) then,
  ) = __$$ForeshadowItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, String note, bool isRevealed});
}

/// @nodoc
class __$$ForeshadowItemImplCopyWithImpl<$Res>
    extends _$ForeshadowItemCopyWithImpl<$Res, _$ForeshadowItemImpl>
    implements _$$ForeshadowItemImplCopyWith<$Res> {
  __$$ForeshadowItemImplCopyWithImpl(
    _$ForeshadowItemImpl _value,
    $Res Function(_$ForeshadowItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ForeshadowItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? note = null,
    Object? isRevealed = null,
  }) {
    return _then(
      _$ForeshadowItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        note: null == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String,
        isRevealed: null == isRevealed
            ? _value.isRevealed
            : isRevealed // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ForeshadowItemImpl extends _ForeshadowItem {
  const _$ForeshadowItemImpl({
    required this.id,
    this.title = "",
    this.note = "",
    this.isRevealed = false,
  }) : super._();

  @override
  final String id;
  @override
  @JsonKey()
  final String title;
  @override
  @JsonKey()
  final String note;
  @override
  @JsonKey()
  final bool isRevealed;

  @override
  String toString() {
    return 'ForeshadowItem.raw(id: $id, title: $title, note: $note, isRevealed: $isRevealed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ForeshadowItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.isRevealed, isRevealed) ||
                other.isRevealed == isRevealed));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, title, note, isRevealed);

  /// Create a copy of ForeshadowItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ForeshadowItemImplCopyWith<_$ForeshadowItemImpl> get copyWith =>
      __$$ForeshadowItemImplCopyWithImpl<_$ForeshadowItemImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String title,
      String note,
      bool isRevealed,
    )
    raw,
  }) {
    return raw(id, title, note, isRevealed);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String title, String note, bool isRevealed)?
    raw,
  }) {
    return raw?.call(id, title, note, isRevealed);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String title, String note, bool isRevealed)?
    raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(id, title, note, isRevealed);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ForeshadowItem value) raw,
  }) {
    return raw(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ForeshadowItem value)? raw,
  }) {
    return raw?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ForeshadowItem value)? raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(this);
    }
    return orElse();
  }
}

abstract class _ForeshadowItem extends ForeshadowItem {
  const factory _ForeshadowItem({
    required final String id,
    final String title,
    final String note,
    final bool isRevealed,
  }) = _$ForeshadowItemImpl;
  const _ForeshadowItem._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  String get note;
  @override
  bool get isRevealed;

  /// Create a copy of ForeshadowItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ForeshadowItemImplCopyWith<_$ForeshadowItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$UpdatePlanItem {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;
  bool get isDone => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String title, String note, bool isDone)
    raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String title, String note, bool isDone)? raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String title, String note, bool isDone)? raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_UpdatePlanItem value) raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_UpdatePlanItem value)? raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_UpdatePlanItem value)? raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of UpdatePlanItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UpdatePlanItemCopyWith<UpdatePlanItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UpdatePlanItemCopyWith<$Res> {
  factory $UpdatePlanItemCopyWith(
    UpdatePlanItem value,
    $Res Function(UpdatePlanItem) then,
  ) = _$UpdatePlanItemCopyWithImpl<$Res, UpdatePlanItem>;
  @useResult
  $Res call({String id, String title, String note, bool isDone});
}

/// @nodoc
class _$UpdatePlanItemCopyWithImpl<$Res, $Val extends UpdatePlanItem>
    implements $UpdatePlanItemCopyWith<$Res> {
  _$UpdatePlanItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UpdatePlanItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? note = null,
    Object? isDone = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            note: null == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String,
            isDone: null == isDone
                ? _value.isDone
                : isDone // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UpdatePlanItemImplCopyWith<$Res>
    implements $UpdatePlanItemCopyWith<$Res> {
  factory _$$UpdatePlanItemImplCopyWith(
    _$UpdatePlanItemImpl value,
    $Res Function(_$UpdatePlanItemImpl) then,
  ) = __$$UpdatePlanItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, String note, bool isDone});
}

/// @nodoc
class __$$UpdatePlanItemImplCopyWithImpl<$Res>
    extends _$UpdatePlanItemCopyWithImpl<$Res, _$UpdatePlanItemImpl>
    implements _$$UpdatePlanItemImplCopyWith<$Res> {
  __$$UpdatePlanItemImplCopyWithImpl(
    _$UpdatePlanItemImpl _value,
    $Res Function(_$UpdatePlanItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UpdatePlanItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? note = null,
    Object? isDone = null,
  }) {
    return _then(
      _$UpdatePlanItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        note: null == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String,
        isDone: null == isDone
            ? _value.isDone
            : isDone // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$UpdatePlanItemImpl extends _UpdatePlanItem {
  const _$UpdatePlanItemImpl({
    required this.id,
    this.title = "",
    this.note = "",
    this.isDone = false,
  }) : super._();

  @override
  final String id;
  @override
  @JsonKey()
  final String title;
  @override
  @JsonKey()
  final String note;
  @override
  @JsonKey()
  final bool isDone;

  @override
  String toString() {
    return 'UpdatePlanItem.raw(id: $id, title: $title, note: $note, isDone: $isDone)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdatePlanItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.isDone, isDone) || other.isDone == isDone));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, title, note, isDone);

  /// Create a copy of UpdatePlanItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdatePlanItemImplCopyWith<_$UpdatePlanItemImpl> get copyWith =>
      __$$UpdatePlanItemImplCopyWithImpl<_$UpdatePlanItemImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String title, String note, bool isDone)
    raw,
  }) {
    return raw(id, title, note, isDone);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String title, String note, bool isDone)? raw,
  }) {
    return raw?.call(id, title, note, isDone);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String title, String note, bool isDone)? raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(id, title, note, isDone);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_UpdatePlanItem value) raw,
  }) {
    return raw(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_UpdatePlanItem value)? raw,
  }) {
    return raw?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_UpdatePlanItem value)? raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(this);
    }
    return orElse();
  }
}

abstract class _UpdatePlanItem extends UpdatePlanItem {
  const factory _UpdatePlanItem({
    required final String id,
    final String title,
    final String note,
    final bool isDone,
  }) = _$UpdatePlanItemImpl;
  const _UpdatePlanItem._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  String get note;
  @override
  bool get isDone;

  /// Create a copy of UpdatePlanItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UpdatePlanItemImplCopyWith<_$UpdatePlanItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PlanProjectData {
  List<ForeshadowItem> get foreshadows => throw _privateConstructorUsedError;
  List<UpdatePlanItem> get updatePlans => throw _privateConstructorUsedError;

  /// Create a copy of PlanProjectData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanProjectDataCopyWith<PlanProjectData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanProjectDataCopyWith<$Res> {
  factory $PlanProjectDataCopyWith(
    PlanProjectData value,
    $Res Function(PlanProjectData) then,
  ) = _$PlanProjectDataCopyWithImpl<$Res, PlanProjectData>;
  @useResult
  $Res call({
    List<ForeshadowItem> foreshadows,
    List<UpdatePlanItem> updatePlans,
  });
}

/// @nodoc
class _$PlanProjectDataCopyWithImpl<$Res, $Val extends PlanProjectData>
    implements $PlanProjectDataCopyWith<$Res> {
  _$PlanProjectDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanProjectData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? foreshadows = null, Object? updatePlans = null}) {
    return _then(
      _value.copyWith(
            foreshadows: null == foreshadows
                ? _value.foreshadows
                : foreshadows // ignore: cast_nullable_to_non_nullable
                      as List<ForeshadowItem>,
            updatePlans: null == updatePlans
                ? _value.updatePlans
                : updatePlans // ignore: cast_nullable_to_non_nullable
                      as List<UpdatePlanItem>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlanProjectDataImplCopyWith<$Res>
    implements $PlanProjectDataCopyWith<$Res> {
  factory _$$PlanProjectDataImplCopyWith(
    _$PlanProjectDataImpl value,
    $Res Function(_$PlanProjectDataImpl) then,
  ) = __$$PlanProjectDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<ForeshadowItem> foreshadows,
    List<UpdatePlanItem> updatePlans,
  });
}

/// @nodoc
class __$$PlanProjectDataImplCopyWithImpl<$Res>
    extends _$PlanProjectDataCopyWithImpl<$Res, _$PlanProjectDataImpl>
    implements _$$PlanProjectDataImplCopyWith<$Res> {
  __$$PlanProjectDataImplCopyWithImpl(
    _$PlanProjectDataImpl _value,
    $Res Function(_$PlanProjectDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlanProjectData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? foreshadows = null, Object? updatePlans = null}) {
    return _then(
      _$PlanProjectDataImpl(
        foreshadows: null == foreshadows
            ? _value._foreshadows
            : foreshadows // ignore: cast_nullable_to_non_nullable
                  as List<ForeshadowItem>,
        updatePlans: null == updatePlans
            ? _value._updatePlans
            : updatePlans // ignore: cast_nullable_to_non_nullable
                  as List<UpdatePlanItem>,
      ),
    );
  }
}

/// @nodoc

class _$PlanProjectDataImpl implements _PlanProjectData {
  const _$PlanProjectDataImpl({
    final List<ForeshadowItem> foreshadows = const <ForeshadowItem>[],
    final List<UpdatePlanItem> updatePlans = const <UpdatePlanItem>[],
  }) : _foreshadows = foreshadows,
       _updatePlans = updatePlans;

  final List<ForeshadowItem> _foreshadows;
  @override
  @JsonKey()
  List<ForeshadowItem> get foreshadows {
    if (_foreshadows is EqualUnmodifiableListView) return _foreshadows;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_foreshadows);
  }

  final List<UpdatePlanItem> _updatePlans;
  @override
  @JsonKey()
  List<UpdatePlanItem> get updatePlans {
    if (_updatePlans is EqualUnmodifiableListView) return _updatePlans;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_updatePlans);
  }

  @override
  String toString() {
    return 'PlanProjectData(foreshadows: $foreshadows, updatePlans: $updatePlans)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanProjectDataImpl &&
            const DeepCollectionEquality().equals(
              other._foreshadows,
              _foreshadows,
            ) &&
            const DeepCollectionEquality().equals(
              other._updatePlans,
              _updatePlans,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_foreshadows),
    const DeepCollectionEquality().hash(_updatePlans),
  );

  /// Create a copy of PlanProjectData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanProjectDataImplCopyWith<_$PlanProjectDataImpl> get copyWith =>
      __$$PlanProjectDataImplCopyWithImpl<_$PlanProjectDataImpl>(
        this,
        _$identity,
      );
}

abstract class _PlanProjectData implements PlanProjectData {
  const factory _PlanProjectData({
    final List<ForeshadowItem> foreshadows,
    final List<UpdatePlanItem> updatePlans,
  }) = _$PlanProjectDataImpl;

  @override
  List<ForeshadowItem> get foreshadows;
  @override
  List<UpdatePlanItem> get updatePlans;

  /// Create a copy of PlanProjectData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanProjectDataImplCopyWith<_$PlanProjectDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
