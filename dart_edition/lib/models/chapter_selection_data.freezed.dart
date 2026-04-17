// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chapter_selection_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ChapterData {
  String get chapterName => throw _privateConstructorUsedError;
  String get chapterContent => throw _privateConstructorUsedError;
  String get chapterUUID => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String chapterName,
      String chapterContent,
      String chapterUUID,
    )
    raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String chapterName,
      String chapterContent,
      String chapterUUID,
    )?
    raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String chapterName,
      String chapterContent,
      String chapterUUID,
    )?
    raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ChapterData value) raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ChapterData value)? raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ChapterData value)? raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of ChapterData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChapterDataCopyWith<ChapterData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChapterDataCopyWith<$Res> {
  factory $ChapterDataCopyWith(
    ChapterData value,
    $Res Function(ChapterData) then,
  ) = _$ChapterDataCopyWithImpl<$Res, ChapterData>;
  @useResult
  $Res call({String chapterName, String chapterContent, String chapterUUID});
}

/// @nodoc
class _$ChapterDataCopyWithImpl<$Res, $Val extends ChapterData>
    implements $ChapterDataCopyWith<$Res> {
  _$ChapterDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChapterData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterName = null,
    Object? chapterContent = null,
    Object? chapterUUID = null,
  }) {
    return _then(
      _value.copyWith(
            chapterName: null == chapterName
                ? _value.chapterName
                : chapterName // ignore: cast_nullable_to_non_nullable
                      as String,
            chapterContent: null == chapterContent
                ? _value.chapterContent
                : chapterContent // ignore: cast_nullable_to_non_nullable
                      as String,
            chapterUUID: null == chapterUUID
                ? _value.chapterUUID
                : chapterUUID // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChapterDataImplCopyWith<$Res>
    implements $ChapterDataCopyWith<$Res> {
  factory _$$ChapterDataImplCopyWith(
    _$ChapterDataImpl value,
    $Res Function(_$ChapterDataImpl) then,
  ) = __$$ChapterDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String chapterName, String chapterContent, String chapterUUID});
}

/// @nodoc
class __$$ChapterDataImplCopyWithImpl<$Res>
    extends _$ChapterDataCopyWithImpl<$Res, _$ChapterDataImpl>
    implements _$$ChapterDataImplCopyWith<$Res> {
  __$$ChapterDataImplCopyWithImpl(
    _$ChapterDataImpl _value,
    $Res Function(_$ChapterDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChapterData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterName = null,
    Object? chapterContent = null,
    Object? chapterUUID = null,
  }) {
    return _then(
      _$ChapterDataImpl(
        chapterName: null == chapterName
            ? _value.chapterName
            : chapterName // ignore: cast_nullable_to_non_nullable
                  as String,
        chapterContent: null == chapterContent
            ? _value.chapterContent
            : chapterContent // ignore: cast_nullable_to_non_nullable
                  as String,
        chapterUUID: null == chapterUUID
            ? _value.chapterUUID
            : chapterUUID // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ChapterDataImpl extends _ChapterData {
  const _$ChapterDataImpl({
    this.chapterName = "",
    this.chapterContent = "",
    required this.chapterUUID,
  }) : super._();

  @override
  @JsonKey()
  final String chapterName;
  @override
  @JsonKey()
  final String chapterContent;
  @override
  final String chapterUUID;

  @override
  String toString() {
    return 'ChapterData.raw(chapterName: $chapterName, chapterContent: $chapterContent, chapterUUID: $chapterUUID)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChapterDataImpl &&
            (identical(other.chapterName, chapterName) ||
                other.chapterName == chapterName) &&
            (identical(other.chapterContent, chapterContent) ||
                other.chapterContent == chapterContent) &&
            (identical(other.chapterUUID, chapterUUID) ||
                other.chapterUUID == chapterUUID));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, chapterName, chapterContent, chapterUUID);

  /// Create a copy of ChapterData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChapterDataImplCopyWith<_$ChapterDataImpl> get copyWith =>
      __$$ChapterDataImplCopyWithImpl<_$ChapterDataImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String chapterName,
      String chapterContent,
      String chapterUUID,
    )
    raw,
  }) {
    return raw(chapterName, chapterContent, chapterUUID);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String chapterName,
      String chapterContent,
      String chapterUUID,
    )?
    raw,
  }) {
    return raw?.call(chapterName, chapterContent, chapterUUID);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String chapterName,
      String chapterContent,
      String chapterUUID,
    )?
    raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(chapterName, chapterContent, chapterUUID);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_ChapterData value) raw,
  }) {
    return raw(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_ChapterData value)? raw,
  }) {
    return raw?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_ChapterData value)? raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(this);
    }
    return orElse();
  }
}

abstract class _ChapterData extends ChapterData {
  const factory _ChapterData({
    final String chapterName,
    final String chapterContent,
    required final String chapterUUID,
  }) = _$ChapterDataImpl;
  const _ChapterData._() : super._();

  @override
  String get chapterName;
  @override
  String get chapterContent;
  @override
  String get chapterUUID;

  /// Create a copy of ChapterData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChapterDataImplCopyWith<_$ChapterDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SegmentData {
  String get segmentName => throw _privateConstructorUsedError;
  List<ChapterData> get chapters => throw _privateConstructorUsedError;
  String get segmentUUID => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String segmentName,
      List<ChapterData> chapters,
      String segmentUUID,
    )
    raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String segmentName,
      List<ChapterData> chapters,
      String segmentUUID,
    )?
    raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String segmentName,
      List<ChapterData> chapters,
      String segmentUUID,
    )?
    raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_SegmentData value) raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_SegmentData value)? raw,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_SegmentData value)? raw,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of SegmentData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SegmentDataCopyWith<SegmentData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SegmentDataCopyWith<$Res> {
  factory $SegmentDataCopyWith(
    SegmentData value,
    $Res Function(SegmentData) then,
  ) = _$SegmentDataCopyWithImpl<$Res, SegmentData>;
  @useResult
  $Res call({
    String segmentName,
    List<ChapterData> chapters,
    String segmentUUID,
  });
}

/// @nodoc
class _$SegmentDataCopyWithImpl<$Res, $Val extends SegmentData>
    implements $SegmentDataCopyWith<$Res> {
  _$SegmentDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SegmentData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? segmentName = null,
    Object? chapters = null,
    Object? segmentUUID = null,
  }) {
    return _then(
      _value.copyWith(
            segmentName: null == segmentName
                ? _value.segmentName
                : segmentName // ignore: cast_nullable_to_non_nullable
                      as String,
            chapters: null == chapters
                ? _value.chapters
                : chapters // ignore: cast_nullable_to_non_nullable
                      as List<ChapterData>,
            segmentUUID: null == segmentUUID
                ? _value.segmentUUID
                : segmentUUID // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SegmentDataImplCopyWith<$Res>
    implements $SegmentDataCopyWith<$Res> {
  factory _$$SegmentDataImplCopyWith(
    _$SegmentDataImpl value,
    $Res Function(_$SegmentDataImpl) then,
  ) = __$$SegmentDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String segmentName,
    List<ChapterData> chapters,
    String segmentUUID,
  });
}

/// @nodoc
class __$$SegmentDataImplCopyWithImpl<$Res>
    extends _$SegmentDataCopyWithImpl<$Res, _$SegmentDataImpl>
    implements _$$SegmentDataImplCopyWith<$Res> {
  __$$SegmentDataImplCopyWithImpl(
    _$SegmentDataImpl _value,
    $Res Function(_$SegmentDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SegmentData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? segmentName = null,
    Object? chapters = null,
    Object? segmentUUID = null,
  }) {
    return _then(
      _$SegmentDataImpl(
        segmentName: null == segmentName
            ? _value.segmentName
            : segmentName // ignore: cast_nullable_to_non_nullable
                  as String,
        chapters: null == chapters
            ? _value._chapters
            : chapters // ignore: cast_nullable_to_non_nullable
                  as List<ChapterData>,
        segmentUUID: null == segmentUUID
            ? _value.segmentUUID
            : segmentUUID // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$SegmentDataImpl extends _SegmentData {
  const _$SegmentDataImpl({
    this.segmentName = "",
    final List<ChapterData> chapters = const <ChapterData>[],
    required this.segmentUUID,
  }) : _chapters = chapters,
       super._();

  @override
  @JsonKey()
  final String segmentName;
  final List<ChapterData> _chapters;
  @override
  @JsonKey()
  List<ChapterData> get chapters {
    if (_chapters is EqualUnmodifiableListView) return _chapters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapters);
  }

  @override
  final String segmentUUID;

  @override
  String toString() {
    return 'SegmentData.raw(segmentName: $segmentName, chapters: $chapters, segmentUUID: $segmentUUID)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SegmentDataImpl &&
            (identical(other.segmentName, segmentName) ||
                other.segmentName == segmentName) &&
            const DeepCollectionEquality().equals(other._chapters, _chapters) &&
            (identical(other.segmentUUID, segmentUUID) ||
                other.segmentUUID == segmentUUID));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    segmentName,
    const DeepCollectionEquality().hash(_chapters),
    segmentUUID,
  );

  /// Create a copy of SegmentData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SegmentDataImplCopyWith<_$SegmentDataImpl> get copyWith =>
      __$$SegmentDataImplCopyWithImpl<_$SegmentDataImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String segmentName,
      List<ChapterData> chapters,
      String segmentUUID,
    )
    raw,
  }) {
    return raw(segmentName, chapters, segmentUUID);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String segmentName,
      List<ChapterData> chapters,
      String segmentUUID,
    )?
    raw,
  }) {
    return raw?.call(segmentName, chapters, segmentUUID);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String segmentName,
      List<ChapterData> chapters,
      String segmentUUID,
    )?
    raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(segmentName, chapters, segmentUUID);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_SegmentData value) raw,
  }) {
    return raw(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_SegmentData value)? raw,
  }) {
    return raw?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_SegmentData value)? raw,
    required TResult orElse(),
  }) {
    if (raw != null) {
      return raw(this);
    }
    return orElse();
  }
}

abstract class _SegmentData extends SegmentData {
  const factory _SegmentData({
    final String segmentName,
    final List<ChapterData> chapters,
    required final String segmentUUID,
  }) = _$SegmentDataImpl;
  const _SegmentData._() : super._();

  @override
  String get segmentName;
  @override
  List<ChapterData> get chapters;
  @override
  String get segmentUUID;

  /// Create a copy of SegmentData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SegmentDataImplCopyWith<_$SegmentDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
