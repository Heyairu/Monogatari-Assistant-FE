// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'glossary_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$GlossaryPair {
  String get meaning => throw _privateConstructorUsedError;
  set meaning(String value) => throw _privateConstructorUsedError;
  String get example => throw _privateConstructorUsedError;
  set example(String value) => throw _privateConstructorUsedError;

  /// Create a copy of GlossaryPair
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GlossaryPairCopyWith<GlossaryPair> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GlossaryPairCopyWith<$Res> {
  factory $GlossaryPairCopyWith(
    GlossaryPair value,
    $Res Function(GlossaryPair) then,
  ) = _$GlossaryPairCopyWithImpl<$Res, GlossaryPair>;
  @useResult
  $Res call({String meaning, String example});
}

/// @nodoc
class _$GlossaryPairCopyWithImpl<$Res, $Val extends GlossaryPair>
    implements $GlossaryPairCopyWith<$Res> {
  _$GlossaryPairCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GlossaryPair
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? meaning = null, Object? example = null}) {
    return _then(
      _value.copyWith(
            meaning: null == meaning
                ? _value.meaning
                : meaning // ignore: cast_nullable_to_non_nullable
                      as String,
            example: null == example
                ? _value.example
                : example // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GlossaryPairImplCopyWith<$Res>
    implements $GlossaryPairCopyWith<$Res> {
  factory _$$GlossaryPairImplCopyWith(
    _$GlossaryPairImpl value,
    $Res Function(_$GlossaryPairImpl) then,
  ) = __$$GlossaryPairImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String meaning, String example});
}

/// @nodoc
class __$$GlossaryPairImplCopyWithImpl<$Res>
    extends _$GlossaryPairCopyWithImpl<$Res, _$GlossaryPairImpl>
    implements _$$GlossaryPairImplCopyWith<$Res> {
  __$$GlossaryPairImplCopyWithImpl(
    _$GlossaryPairImpl _value,
    $Res Function(_$GlossaryPairImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GlossaryPair
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? meaning = null, Object? example = null}) {
    return _then(
      _$GlossaryPairImpl(
        meaning: null == meaning
            ? _value.meaning
            : meaning // ignore: cast_nullable_to_non_nullable
                  as String,
        example: null == example
            ? _value.example
            : example // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$GlossaryPairImpl extends _GlossaryPair {
  _$GlossaryPairImpl({this.meaning = "", this.example = ""}) : super._();

  @override
  @JsonKey()
  String meaning;
  @override
  @JsonKey()
  String example;

  @override
  String toString() {
    return 'GlossaryPair(meaning: $meaning, example: $example)';
  }

  /// Create a copy of GlossaryPair
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GlossaryPairImplCopyWith<_$GlossaryPairImpl> get copyWith =>
      __$$GlossaryPairImplCopyWithImpl<_$GlossaryPairImpl>(this, _$identity);
}

abstract class _GlossaryPair extends GlossaryPair {
  factory _GlossaryPair({String meaning, String example}) = _$GlossaryPairImpl;
  _GlossaryPair._() : super._();

  @override
  String get meaning;
  set meaning(String value);
  @override
  String get example;
  set example(String value);

  /// Create a copy of GlossaryPair
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GlossaryPairImplCopyWith<_$GlossaryPairImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$GlossaryEntry {
  String get id => throw _privateConstructorUsedError;
  set id(String value) => throw _privateConstructorUsedError;
  String get term => throw _privateConstructorUsedError;
  set term(String value) => throw _privateConstructorUsedError;
  GlossaryPartOfSpeech get partOfSpeech => throw _privateConstructorUsedError;
  set partOfSpeech(GlossaryPartOfSpeech value) =>
      throw _privateConstructorUsedError;
  String get customPartOfSpeech => throw _privateConstructorUsedError;
  set customPartOfSpeech(String value) => throw _privateConstructorUsedError;
  GlossaryPolarity get polarity => throw _privateConstructorUsedError;
  set polarity(GlossaryPolarity value) => throw _privateConstructorUsedError;
  List<GlossaryPair> get pairs => throw _privateConstructorUsedError;
  set pairs(List<GlossaryPair> value) => throw _privateConstructorUsedError;

  /// Create a copy of GlossaryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GlossaryEntryCopyWith<GlossaryEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GlossaryEntryCopyWith<$Res> {
  factory $GlossaryEntryCopyWith(
    GlossaryEntry value,
    $Res Function(GlossaryEntry) then,
  ) = _$GlossaryEntryCopyWithImpl<$Res, GlossaryEntry>;
  @useResult
  $Res call({
    String id,
    String term,
    GlossaryPartOfSpeech partOfSpeech,
    String customPartOfSpeech,
    GlossaryPolarity polarity,
    List<GlossaryPair> pairs,
  });
}

/// @nodoc
class _$GlossaryEntryCopyWithImpl<$Res, $Val extends GlossaryEntry>
    implements $GlossaryEntryCopyWith<$Res> {
  _$GlossaryEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GlossaryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? term = null,
    Object? partOfSpeech = null,
    Object? customPartOfSpeech = null,
    Object? polarity = null,
    Object? pairs = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            term: null == term
                ? _value.term
                : term // ignore: cast_nullable_to_non_nullable
                      as String,
            partOfSpeech: null == partOfSpeech
                ? _value.partOfSpeech
                : partOfSpeech // ignore: cast_nullable_to_non_nullable
                      as GlossaryPartOfSpeech,
            customPartOfSpeech: null == customPartOfSpeech
                ? _value.customPartOfSpeech
                : customPartOfSpeech // ignore: cast_nullable_to_non_nullable
                      as String,
            polarity: null == polarity
                ? _value.polarity
                : polarity // ignore: cast_nullable_to_non_nullable
                      as GlossaryPolarity,
            pairs: null == pairs
                ? _value.pairs
                : pairs // ignore: cast_nullable_to_non_nullable
                      as List<GlossaryPair>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GlossaryEntryImplCopyWith<$Res>
    implements $GlossaryEntryCopyWith<$Res> {
  factory _$$GlossaryEntryImplCopyWith(
    _$GlossaryEntryImpl value,
    $Res Function(_$GlossaryEntryImpl) then,
  ) = __$$GlossaryEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String term,
    GlossaryPartOfSpeech partOfSpeech,
    String customPartOfSpeech,
    GlossaryPolarity polarity,
    List<GlossaryPair> pairs,
  });
}

/// @nodoc
class __$$GlossaryEntryImplCopyWithImpl<$Res>
    extends _$GlossaryEntryCopyWithImpl<$Res, _$GlossaryEntryImpl>
    implements _$$GlossaryEntryImplCopyWith<$Res> {
  __$$GlossaryEntryImplCopyWithImpl(
    _$GlossaryEntryImpl _value,
    $Res Function(_$GlossaryEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GlossaryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? term = null,
    Object? partOfSpeech = null,
    Object? customPartOfSpeech = null,
    Object? polarity = null,
    Object? pairs = null,
  }) {
    return _then(
      _$GlossaryEntryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        term: null == term
            ? _value.term
            : term // ignore: cast_nullable_to_non_nullable
                  as String,
        partOfSpeech: null == partOfSpeech
            ? _value.partOfSpeech
            : partOfSpeech // ignore: cast_nullable_to_non_nullable
                  as GlossaryPartOfSpeech,
        customPartOfSpeech: null == customPartOfSpeech
            ? _value.customPartOfSpeech
            : customPartOfSpeech // ignore: cast_nullable_to_non_nullable
                  as String,
        polarity: null == polarity
            ? _value.polarity
            : polarity // ignore: cast_nullable_to_non_nullable
                  as GlossaryPolarity,
        pairs: null == pairs
            ? _value.pairs
            : pairs // ignore: cast_nullable_to_non_nullable
                  as List<GlossaryPair>,
      ),
    );
  }
}

/// @nodoc

class _$GlossaryEntryImpl extends _GlossaryEntry {
  _$GlossaryEntryImpl({
    required this.id,
    required this.term,
    required this.partOfSpeech,
    required this.customPartOfSpeech,
    required this.polarity,
    required this.pairs,
  }) : super._();

  @override
  String id;
  @override
  String term;
  @override
  GlossaryPartOfSpeech partOfSpeech;
  @override
  String customPartOfSpeech;
  @override
  GlossaryPolarity polarity;
  @override
  List<GlossaryPair> pairs;

  @override
  String toString() {
    return 'GlossaryEntry(id: $id, term: $term, partOfSpeech: $partOfSpeech, customPartOfSpeech: $customPartOfSpeech, polarity: $polarity, pairs: $pairs)';
  }

  /// Create a copy of GlossaryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GlossaryEntryImplCopyWith<_$GlossaryEntryImpl> get copyWith =>
      __$$GlossaryEntryImplCopyWithImpl<_$GlossaryEntryImpl>(this, _$identity);
}

abstract class _GlossaryEntry extends GlossaryEntry {
  factory _GlossaryEntry({
    required String id,
    required String term,
    required GlossaryPartOfSpeech partOfSpeech,
    required String customPartOfSpeech,
    required GlossaryPolarity polarity,
    required List<GlossaryPair> pairs,
  }) = _$GlossaryEntryImpl;
  _GlossaryEntry._() : super._();

  @override
  String get id;
  set id(String value);
  @override
  String get term;
  set term(String value);
  @override
  GlossaryPartOfSpeech get partOfSpeech;
  set partOfSpeech(GlossaryPartOfSpeech value);
  @override
  String get customPartOfSpeech;
  set customPartOfSpeech(String value);
  @override
  GlossaryPolarity get polarity;
  set polarity(GlossaryPolarity value);
  @override
  List<GlossaryPair> get pairs;
  set pairs(List<GlossaryPair> value);

  /// Create a copy of GlossaryEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GlossaryEntryImplCopyWith<_$GlossaryEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$GlossaryCategory {
  String get id => throw _privateConstructorUsedError;
  set id(String value) => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  set name(String value) => throw _privateConstructorUsedError;
  List<String> get entryIds => throw _privateConstructorUsedError;
  set entryIds(List<String> value) => throw _privateConstructorUsedError;
  List<GlossaryCategory> get children => throw _privateConstructorUsedError;
  set children(List<GlossaryCategory> value) =>
      throw _privateConstructorUsedError;

  /// Create a copy of GlossaryCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GlossaryCategoryCopyWith<GlossaryCategory> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GlossaryCategoryCopyWith<$Res> {
  factory $GlossaryCategoryCopyWith(
    GlossaryCategory value,
    $Res Function(GlossaryCategory) then,
  ) = _$GlossaryCategoryCopyWithImpl<$Res, GlossaryCategory>;
  @useResult
  $Res call({
    String id,
    String name,
    List<String> entryIds,
    List<GlossaryCategory> children,
  });
}

/// @nodoc
class _$GlossaryCategoryCopyWithImpl<$Res, $Val extends GlossaryCategory>
    implements $GlossaryCategoryCopyWith<$Res> {
  _$GlossaryCategoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GlossaryCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? entryIds = null,
    Object? children = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            entryIds: null == entryIds
                ? _value.entryIds
                : entryIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            children: null == children
                ? _value.children
                : children // ignore: cast_nullable_to_non_nullable
                      as List<GlossaryCategory>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GlossaryCategoryImplCopyWith<$Res>
    implements $GlossaryCategoryCopyWith<$Res> {
  factory _$$GlossaryCategoryImplCopyWith(
    _$GlossaryCategoryImpl value,
    $Res Function(_$GlossaryCategoryImpl) then,
  ) = __$$GlossaryCategoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    List<String> entryIds,
    List<GlossaryCategory> children,
  });
}

/// @nodoc
class __$$GlossaryCategoryImplCopyWithImpl<$Res>
    extends _$GlossaryCategoryCopyWithImpl<$Res, _$GlossaryCategoryImpl>
    implements _$$GlossaryCategoryImplCopyWith<$Res> {
  __$$GlossaryCategoryImplCopyWithImpl(
    _$GlossaryCategoryImpl _value,
    $Res Function(_$GlossaryCategoryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GlossaryCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? entryIds = null,
    Object? children = null,
  }) {
    return _then(
      _$GlossaryCategoryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        entryIds: null == entryIds
            ? _value.entryIds
            : entryIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        children: null == children
            ? _value.children
            : children // ignore: cast_nullable_to_non_nullable
                  as List<GlossaryCategory>,
      ),
    );
  }
}

/// @nodoc

class _$GlossaryCategoryImpl extends _GlossaryCategory {
  _$GlossaryCategoryImpl({
    required this.id,
    required this.name,
    required this.entryIds,
    required this.children,
  }) : super._();

  @override
  String id;
  @override
  String name;
  @override
  List<String> entryIds;
  @override
  List<GlossaryCategory> children;

  @override
  String toString() {
    return 'GlossaryCategory(id: $id, name: $name, entryIds: $entryIds, children: $children)';
  }

  /// Create a copy of GlossaryCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GlossaryCategoryImplCopyWith<_$GlossaryCategoryImpl> get copyWith =>
      __$$GlossaryCategoryImplCopyWithImpl<_$GlossaryCategoryImpl>(
        this,
        _$identity,
      );
}

abstract class _GlossaryCategory extends GlossaryCategory {
  factory _GlossaryCategory({
    required String id,
    required String name,
    required List<String> entryIds,
    required List<GlossaryCategory> children,
  }) = _$GlossaryCategoryImpl;
  _GlossaryCategory._() : super._();

  @override
  String get id;
  set id(String value);
  @override
  String get name;
  set name(String value);
  @override
  List<String> get entryIds;
  set entryIds(List<String> value);
  @override
  List<GlossaryCategory> get children;
  set children(List<GlossaryCategory> value);

  /// Create a copy of GlossaryCategory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GlossaryCategoryImplCopyWith<_$GlossaryCategoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
