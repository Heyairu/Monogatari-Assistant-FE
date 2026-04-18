// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'character_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CharacterHinderEvent {
  String get event => throw _privateConstructorUsedError;
  String get solve => throw _privateConstructorUsedError;

  /// Create a copy of CharacterHinderEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CharacterHinderEventCopyWith<CharacterHinderEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterHinderEventCopyWith<$Res> {
  factory $CharacterHinderEventCopyWith(
    CharacterHinderEvent value,
    $Res Function(CharacterHinderEvent) then,
  ) = _$CharacterHinderEventCopyWithImpl<$Res, CharacterHinderEvent>;
  @useResult
  $Res call({String event, String solve});
}

/// @nodoc
class _$CharacterHinderEventCopyWithImpl<
  $Res,
  $Val extends CharacterHinderEvent
>
    implements $CharacterHinderEventCopyWith<$Res> {
  _$CharacterHinderEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CharacterHinderEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? event = null, Object? solve = null}) {
    return _then(
      _value.copyWith(
            event: null == event
                ? _value.event
                : event // ignore: cast_nullable_to_non_nullable
                      as String,
            solve: null == solve
                ? _value.solve
                : solve // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CharacterHinderEventImplCopyWith<$Res>
    implements $CharacterHinderEventCopyWith<$Res> {
  factory _$$CharacterHinderEventImplCopyWith(
    _$CharacterHinderEventImpl value,
    $Res Function(_$CharacterHinderEventImpl) then,
  ) = __$$CharacterHinderEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String event, String solve});
}

/// @nodoc
class __$$CharacterHinderEventImplCopyWithImpl<$Res>
    extends _$CharacterHinderEventCopyWithImpl<$Res, _$CharacterHinderEventImpl>
    implements _$$CharacterHinderEventImplCopyWith<$Res> {
  __$$CharacterHinderEventImplCopyWithImpl(
    _$CharacterHinderEventImpl _value,
    $Res Function(_$CharacterHinderEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CharacterHinderEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? event = null, Object? solve = null}) {
    return _then(
      _$CharacterHinderEventImpl(
        event: null == event
            ? _value.event
            : event // ignore: cast_nullable_to_non_nullable
                  as String,
        solve: null == solve
            ? _value.solve
            : solve // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$CharacterHinderEventImpl implements _CharacterHinderEvent {
  const _$CharacterHinderEventImpl({this.event = "", this.solve = ""});

  @override
  @JsonKey()
  final String event;
  @override
  @JsonKey()
  final String solve;

  @override
  String toString() {
    return 'CharacterHinderEvent(event: $event, solve: $solve)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterHinderEventImpl &&
            (identical(other.event, event) || other.event == event) &&
            (identical(other.solve, solve) || other.solve == solve));
  }

  @override
  int get hashCode => Object.hash(runtimeType, event, solve);

  /// Create a copy of CharacterHinderEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterHinderEventImplCopyWith<_$CharacterHinderEventImpl>
  get copyWith =>
      __$$CharacterHinderEventImplCopyWithImpl<_$CharacterHinderEventImpl>(
        this,
        _$identity,
      );
}

abstract class _CharacterHinderEvent implements CharacterHinderEvent {
  const factory _CharacterHinderEvent({
    final String event,
    final String solve,
  }) = _$CharacterHinderEventImpl;

  @override
  String get event;
  @override
  String get solve;

  /// Create a copy of CharacterHinderEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CharacterHinderEventImplCopyWith<_$CharacterHinderEventImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CharacterEntryData {
  Map<String, String> get textFields => throw _privateConstructorUsedError;
  String? get alignment => throw _privateConstructorUsedError;
  List<CharacterHinderEvent> get hinderEvents =>
      throw _privateConstructorUsedError;
  List<String> get loveToDoList => throw _privateConstructorUsedError;
  List<String> get hateToDoList => throw _privateConstructorUsedError;
  List<String> get wantToDoList => throw _privateConstructorUsedError;
  List<String> get fearToDoList => throw _privateConstructorUsedError;
  List<String> get proficientToDoList => throw _privateConstructorUsedError;
  List<String> get unProficientToDoList => throw _privateConstructorUsedError;
  List<double> get commonAbilityValues => throw _privateConstructorUsedError;
  Map<String, bool> get howToShowLove => throw _privateConstructorUsedError;
  Map<String, bool> get howToShowGoodwill => throw _privateConstructorUsedError;
  Map<String, bool> get handleHatePeople => throw _privateConstructorUsedError;
  List<double> get socialItemValues => throw _privateConstructorUsedError;
  String? get relationship => throw _privateConstructorUsedError;
  bool get isFindNewLove => throw _privateConstructorUsedError;
  bool get isHarem => throw _privateConstructorUsedError;
  List<double> get approachValues => throw _privateConstructorUsedError;
  List<double> get traitsValues => throw _privateConstructorUsedError;
  List<String> get likeItemList => throw _privateConstructorUsedError;
  List<String> get admireItemList => throw _privateConstructorUsedError;
  List<String> get hateItemList => throw _privateConstructorUsedError;
  List<String> get fearItemList => throw _privateConstructorUsedError;
  List<String> get familiarItemList => throw _privateConstructorUsedError;

  /// Create a copy of CharacterEntryData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CharacterEntryDataCopyWith<CharacterEntryData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterEntryDataCopyWith<$Res> {
  factory $CharacterEntryDataCopyWith(
    CharacterEntryData value,
    $Res Function(CharacterEntryData) then,
  ) = _$CharacterEntryDataCopyWithImpl<$Res, CharacterEntryData>;
  @useResult
  $Res call({
    Map<String, String> textFields,
    String? alignment,
    List<CharacterHinderEvent> hinderEvents,
    List<String> loveToDoList,
    List<String> hateToDoList,
    List<String> wantToDoList,
    List<String> fearToDoList,
    List<String> proficientToDoList,
    List<String> unProficientToDoList,
    List<double> commonAbilityValues,
    Map<String, bool> howToShowLove,
    Map<String, bool> howToShowGoodwill,
    Map<String, bool> handleHatePeople,
    List<double> socialItemValues,
    String? relationship,
    bool isFindNewLove,
    bool isHarem,
    List<double> approachValues,
    List<double> traitsValues,
    List<String> likeItemList,
    List<String> admireItemList,
    List<String> hateItemList,
    List<String> fearItemList,
    List<String> familiarItemList,
  });
}

/// @nodoc
class _$CharacterEntryDataCopyWithImpl<$Res, $Val extends CharacterEntryData>
    implements $CharacterEntryDataCopyWith<$Res> {
  _$CharacterEntryDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CharacterEntryData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? textFields = null,
    Object? alignment = freezed,
    Object? hinderEvents = null,
    Object? loveToDoList = null,
    Object? hateToDoList = null,
    Object? wantToDoList = null,
    Object? fearToDoList = null,
    Object? proficientToDoList = null,
    Object? unProficientToDoList = null,
    Object? commonAbilityValues = null,
    Object? howToShowLove = null,
    Object? howToShowGoodwill = null,
    Object? handleHatePeople = null,
    Object? socialItemValues = null,
    Object? relationship = freezed,
    Object? isFindNewLove = null,
    Object? isHarem = null,
    Object? approachValues = null,
    Object? traitsValues = null,
    Object? likeItemList = null,
    Object? admireItemList = null,
    Object? hateItemList = null,
    Object? fearItemList = null,
    Object? familiarItemList = null,
  }) {
    return _then(
      _value.copyWith(
            textFields: null == textFields
                ? _value.textFields
                : textFields // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
            alignment: freezed == alignment
                ? _value.alignment
                : alignment // ignore: cast_nullable_to_non_nullable
                      as String?,
            hinderEvents: null == hinderEvents
                ? _value.hinderEvents
                : hinderEvents // ignore: cast_nullable_to_non_nullable
                      as List<CharacterHinderEvent>,
            loveToDoList: null == loveToDoList
                ? _value.loveToDoList
                : loveToDoList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            hateToDoList: null == hateToDoList
                ? _value.hateToDoList
                : hateToDoList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            wantToDoList: null == wantToDoList
                ? _value.wantToDoList
                : wantToDoList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            fearToDoList: null == fearToDoList
                ? _value.fearToDoList
                : fearToDoList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            proficientToDoList: null == proficientToDoList
                ? _value.proficientToDoList
                : proficientToDoList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            unProficientToDoList: null == unProficientToDoList
                ? _value.unProficientToDoList
                : unProficientToDoList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            commonAbilityValues: null == commonAbilityValues
                ? _value.commonAbilityValues
                : commonAbilityValues // ignore: cast_nullable_to_non_nullable
                      as List<double>,
            howToShowLove: null == howToShowLove
                ? _value.howToShowLove
                : howToShowLove // ignore: cast_nullable_to_non_nullable
                      as Map<String, bool>,
            howToShowGoodwill: null == howToShowGoodwill
                ? _value.howToShowGoodwill
                : howToShowGoodwill // ignore: cast_nullable_to_non_nullable
                      as Map<String, bool>,
            handleHatePeople: null == handleHatePeople
                ? _value.handleHatePeople
                : handleHatePeople // ignore: cast_nullable_to_non_nullable
                      as Map<String, bool>,
            socialItemValues: null == socialItemValues
                ? _value.socialItemValues
                : socialItemValues // ignore: cast_nullable_to_non_nullable
                      as List<double>,
            relationship: freezed == relationship
                ? _value.relationship
                : relationship // ignore: cast_nullable_to_non_nullable
                      as String?,
            isFindNewLove: null == isFindNewLove
                ? _value.isFindNewLove
                : isFindNewLove // ignore: cast_nullable_to_non_nullable
                      as bool,
            isHarem: null == isHarem
                ? _value.isHarem
                : isHarem // ignore: cast_nullable_to_non_nullable
                      as bool,
            approachValues: null == approachValues
                ? _value.approachValues
                : approachValues // ignore: cast_nullable_to_non_nullable
                      as List<double>,
            traitsValues: null == traitsValues
                ? _value.traitsValues
                : traitsValues // ignore: cast_nullable_to_non_nullable
                      as List<double>,
            likeItemList: null == likeItemList
                ? _value.likeItemList
                : likeItemList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            admireItemList: null == admireItemList
                ? _value.admireItemList
                : admireItemList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            hateItemList: null == hateItemList
                ? _value.hateItemList
                : hateItemList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            fearItemList: null == fearItemList
                ? _value.fearItemList
                : fearItemList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            familiarItemList: null == familiarItemList
                ? _value.familiarItemList
                : familiarItemList // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CharacterEntryDataImplCopyWith<$Res>
    implements $CharacterEntryDataCopyWith<$Res> {
  factory _$$CharacterEntryDataImplCopyWith(
    _$CharacterEntryDataImpl value,
    $Res Function(_$CharacterEntryDataImpl) then,
  ) = __$$CharacterEntryDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Map<String, String> textFields,
    String? alignment,
    List<CharacterHinderEvent> hinderEvents,
    List<String> loveToDoList,
    List<String> hateToDoList,
    List<String> wantToDoList,
    List<String> fearToDoList,
    List<String> proficientToDoList,
    List<String> unProficientToDoList,
    List<double> commonAbilityValues,
    Map<String, bool> howToShowLove,
    Map<String, bool> howToShowGoodwill,
    Map<String, bool> handleHatePeople,
    List<double> socialItemValues,
    String? relationship,
    bool isFindNewLove,
    bool isHarem,
    List<double> approachValues,
    List<double> traitsValues,
    List<String> likeItemList,
    List<String> admireItemList,
    List<String> hateItemList,
    List<String> fearItemList,
    List<String> familiarItemList,
  });
}

/// @nodoc
class __$$CharacterEntryDataImplCopyWithImpl<$Res>
    extends _$CharacterEntryDataCopyWithImpl<$Res, _$CharacterEntryDataImpl>
    implements _$$CharacterEntryDataImplCopyWith<$Res> {
  __$$CharacterEntryDataImplCopyWithImpl(
    _$CharacterEntryDataImpl _value,
    $Res Function(_$CharacterEntryDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CharacterEntryData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? textFields = null,
    Object? alignment = freezed,
    Object? hinderEvents = null,
    Object? loveToDoList = null,
    Object? hateToDoList = null,
    Object? wantToDoList = null,
    Object? fearToDoList = null,
    Object? proficientToDoList = null,
    Object? unProficientToDoList = null,
    Object? commonAbilityValues = null,
    Object? howToShowLove = null,
    Object? howToShowGoodwill = null,
    Object? handleHatePeople = null,
    Object? socialItemValues = null,
    Object? relationship = freezed,
    Object? isFindNewLove = null,
    Object? isHarem = null,
    Object? approachValues = null,
    Object? traitsValues = null,
    Object? likeItemList = null,
    Object? admireItemList = null,
    Object? hateItemList = null,
    Object? fearItemList = null,
    Object? familiarItemList = null,
  }) {
    return _then(
      _$CharacterEntryDataImpl(
        textFields: null == textFields
            ? _value.textFields
            : textFields // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
        alignment: freezed == alignment
            ? _value.alignment
            : alignment // ignore: cast_nullable_to_non_nullable
                  as String?,
        hinderEvents: null == hinderEvents
            ? _value.hinderEvents
            : hinderEvents // ignore: cast_nullable_to_non_nullable
                  as List<CharacterHinderEvent>,
        loveToDoList: null == loveToDoList
            ? _value.loveToDoList
            : loveToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        hateToDoList: null == hateToDoList
            ? _value.hateToDoList
            : hateToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        wantToDoList: null == wantToDoList
            ? _value.wantToDoList
            : wantToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        fearToDoList: null == fearToDoList
            ? _value.fearToDoList
            : fearToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        proficientToDoList: null == proficientToDoList
            ? _value.proficientToDoList
            : proficientToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        unProficientToDoList: null == unProficientToDoList
            ? _value.unProficientToDoList
            : unProficientToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        commonAbilityValues: null == commonAbilityValues
            ? _value.commonAbilityValues
            : commonAbilityValues // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        howToShowLove: null == howToShowLove
            ? _value.howToShowLove
            : howToShowLove // ignore: cast_nullable_to_non_nullable
                  as Map<String, bool>,
        howToShowGoodwill: null == howToShowGoodwill
            ? _value.howToShowGoodwill
            : howToShowGoodwill // ignore: cast_nullable_to_non_nullable
                  as Map<String, bool>,
        handleHatePeople: null == handleHatePeople
            ? _value.handleHatePeople
            : handleHatePeople // ignore: cast_nullable_to_non_nullable
                  as Map<String, bool>,
        socialItemValues: null == socialItemValues
            ? _value.socialItemValues
            : socialItemValues // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        relationship: freezed == relationship
            ? _value.relationship
            : relationship // ignore: cast_nullable_to_non_nullable
                  as String?,
        isFindNewLove: null == isFindNewLove
            ? _value.isFindNewLove
            : isFindNewLove // ignore: cast_nullable_to_non_nullable
                  as bool,
        isHarem: null == isHarem
            ? _value.isHarem
            : isHarem // ignore: cast_nullable_to_non_nullable
                  as bool,
        approachValues: null == approachValues
            ? _value.approachValues
            : approachValues // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        traitsValues: null == traitsValues
            ? _value.traitsValues
            : traitsValues // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        likeItemList: null == likeItemList
            ? _value.likeItemList
            : likeItemList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        admireItemList: null == admireItemList
            ? _value.admireItemList
            : admireItemList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        hateItemList: null == hateItemList
            ? _value.hateItemList
            : hateItemList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        fearItemList: null == fearItemList
            ? _value.fearItemList
            : fearItemList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        familiarItemList: null == familiarItemList
            ? _value.familiarItemList
            : familiarItemList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$CharacterEntryDataImpl extends _CharacterEntryData {
  const _$CharacterEntryDataImpl({
    this.textFields = const <String, String>{},
    this.alignment,
    this.hinderEvents = const <CharacterHinderEvent>[],
    this.loveToDoList = const <String>[],
    this.hateToDoList = const <String>[],
    this.wantToDoList = const <String>[],
    this.fearToDoList = const <String>[],
    this.proficientToDoList = const <String>[],
    this.unProficientToDoList = const <String>[],
    this.commonAbilityValues = const <double>[],
    this.howToShowLove = const <String, bool>{},
    this.howToShowGoodwill = const <String, bool>{},
    this.handleHatePeople = const <String, bool>{},
    this.socialItemValues = const <double>[],
    this.relationship,
    this.isFindNewLove = false,
    this.isHarem = false,
    this.approachValues = const <double>[],
    this.traitsValues = const <double>[],
    this.likeItemList = const <String>[],
    this.admireItemList = const <String>[],
    this.hateItemList = const <String>[],
    this.fearItemList = const <String>[],
    this.familiarItemList = const <String>[],
  }) : super._();

  @override
  @JsonKey()
  final Map<String, String> textFields;
  @override
  final String? alignment;
  @override
  @JsonKey()
  final List<CharacterHinderEvent> hinderEvents;
  @override
  @JsonKey()
  final List<String> loveToDoList;
  @override
  @JsonKey()
  final List<String> hateToDoList;
  @override
  @JsonKey()
  final List<String> wantToDoList;
  @override
  @JsonKey()
  final List<String> fearToDoList;
  @override
  @JsonKey()
  final List<String> proficientToDoList;
  @override
  @JsonKey()
  final List<String> unProficientToDoList;
  @override
  @JsonKey()
  final List<double> commonAbilityValues;
  @override
  @JsonKey()
  final Map<String, bool> howToShowLove;
  @override
  @JsonKey()
  final Map<String, bool> howToShowGoodwill;
  @override
  @JsonKey()
  final Map<String, bool> handleHatePeople;
  @override
  @JsonKey()
  final List<double> socialItemValues;
  @override
  final String? relationship;
  @override
  @JsonKey()
  final bool isFindNewLove;
  @override
  @JsonKey()
  final bool isHarem;
  @override
  @JsonKey()
  final List<double> approachValues;
  @override
  @JsonKey()
  final List<double> traitsValues;
  @override
  @JsonKey()
  final List<String> likeItemList;
  @override
  @JsonKey()
  final List<String> admireItemList;
  @override
  @JsonKey()
  final List<String> hateItemList;
  @override
  @JsonKey()
  final List<String> fearItemList;
  @override
  @JsonKey()
  final List<String> familiarItemList;

  @override
  String toString() {
    return 'CharacterEntryData(textFields: $textFields, alignment: $alignment, hinderEvents: $hinderEvents, loveToDoList: $loveToDoList, hateToDoList: $hateToDoList, wantToDoList: $wantToDoList, fearToDoList: $fearToDoList, proficientToDoList: $proficientToDoList, unProficientToDoList: $unProficientToDoList, commonAbilityValues: $commonAbilityValues, howToShowLove: $howToShowLove, howToShowGoodwill: $howToShowGoodwill, handleHatePeople: $handleHatePeople, socialItemValues: $socialItemValues, relationship: $relationship, isFindNewLove: $isFindNewLove, isHarem: $isHarem, approachValues: $approachValues, traitsValues: $traitsValues, likeItemList: $likeItemList, admireItemList: $admireItemList, hateItemList: $hateItemList, fearItemList: $fearItemList, familiarItemList: $familiarItemList)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterEntryDataImpl &&
            const DeepCollectionEquality().equals(
              other.textFields,
              textFields,
            ) &&
            (identical(other.alignment, alignment) ||
                other.alignment == alignment) &&
            const DeepCollectionEquality().equals(
              other.hinderEvents,
              hinderEvents,
            ) &&
            const DeepCollectionEquality().equals(
              other.loveToDoList,
              loveToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other.hateToDoList,
              hateToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other.wantToDoList,
              wantToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other.fearToDoList,
              fearToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other.proficientToDoList,
              proficientToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other.unProficientToDoList,
              unProficientToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other.commonAbilityValues,
              commonAbilityValues,
            ) &&
            const DeepCollectionEquality().equals(
              other.howToShowLove,
              howToShowLove,
            ) &&
            const DeepCollectionEquality().equals(
              other.howToShowGoodwill,
              howToShowGoodwill,
            ) &&
            const DeepCollectionEquality().equals(
              other.handleHatePeople,
              handleHatePeople,
            ) &&
            const DeepCollectionEquality().equals(
              other.socialItemValues,
              socialItemValues,
            ) &&
            (identical(other.relationship, relationship) ||
                other.relationship == relationship) &&
            (identical(other.isFindNewLove, isFindNewLove) ||
                other.isFindNewLove == isFindNewLove) &&
            (identical(other.isHarem, isHarem) || other.isHarem == isHarem) &&
            const DeepCollectionEquality().equals(
              other.approachValues,
              approachValues,
            ) &&
            const DeepCollectionEquality().equals(
              other.traitsValues,
              traitsValues,
            ) &&
            const DeepCollectionEquality().equals(
              other.likeItemList,
              likeItemList,
            ) &&
            const DeepCollectionEquality().equals(
              other.admireItemList,
              admireItemList,
            ) &&
            const DeepCollectionEquality().equals(
              other.hateItemList,
              hateItemList,
            ) &&
            const DeepCollectionEquality().equals(
              other.fearItemList,
              fearItemList,
            ) &&
            const DeepCollectionEquality().equals(
              other.familiarItemList,
              familiarItemList,
            ));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    const DeepCollectionEquality().hash(textFields),
    alignment,
    const DeepCollectionEquality().hash(hinderEvents),
    const DeepCollectionEquality().hash(loveToDoList),
    const DeepCollectionEquality().hash(hateToDoList),
    const DeepCollectionEquality().hash(wantToDoList),
    const DeepCollectionEquality().hash(fearToDoList),
    const DeepCollectionEquality().hash(proficientToDoList),
    const DeepCollectionEquality().hash(unProficientToDoList),
    const DeepCollectionEquality().hash(commonAbilityValues),
    const DeepCollectionEquality().hash(howToShowLove),
    const DeepCollectionEquality().hash(howToShowGoodwill),
    const DeepCollectionEquality().hash(handleHatePeople),
    const DeepCollectionEquality().hash(socialItemValues),
    relationship,
    isFindNewLove,
    isHarem,
    const DeepCollectionEquality().hash(approachValues),
    const DeepCollectionEquality().hash(traitsValues),
    const DeepCollectionEquality().hash(likeItemList),
    const DeepCollectionEquality().hash(admireItemList),
    const DeepCollectionEquality().hash(hateItemList),
    const DeepCollectionEquality().hash(fearItemList),
    const DeepCollectionEquality().hash(familiarItemList),
  ]);

  /// Create a copy of CharacterEntryData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterEntryDataImplCopyWith<_$CharacterEntryDataImpl> get copyWith =>
      __$$CharacterEntryDataImplCopyWithImpl<_$CharacterEntryDataImpl>(
        this,
        _$identity,
      );
}

abstract class _CharacterEntryData extends CharacterEntryData {
  const factory _CharacterEntryData({
    final Map<String, String> textFields,
    final String? alignment,
    final List<CharacterHinderEvent> hinderEvents,
    final List<String> loveToDoList,
    final List<String> hateToDoList,
    final List<String> wantToDoList,
    final List<String> fearToDoList,
    final List<String> proficientToDoList,
    final List<String> unProficientToDoList,
    final List<double> commonAbilityValues,
    final Map<String, bool> howToShowLove,
    final Map<String, bool> howToShowGoodwill,
    final Map<String, bool> handleHatePeople,
    final List<double> socialItemValues,
    final String? relationship,
    final bool isFindNewLove,
    final bool isHarem,
    final List<double> approachValues,
    final List<double> traitsValues,
    final List<String> likeItemList,
    final List<String> admireItemList,
    final List<String> hateItemList,
    final List<String> fearItemList,
    final List<String> familiarItemList,
  }) = _$CharacterEntryDataImpl;
  const _CharacterEntryData._() : super._();

  @override
  Map<String, String> get textFields;
  @override
  String? get alignment;
  @override
  List<CharacterHinderEvent> get hinderEvents;
  @override
  List<String> get loveToDoList;
  @override
  List<String> get hateToDoList;
  @override
  List<String> get wantToDoList;
  @override
  List<String> get fearToDoList;
  @override
  List<String> get proficientToDoList;
  @override
  List<String> get unProficientToDoList;
  @override
  List<double> get commonAbilityValues;
  @override
  Map<String, bool> get howToShowLove;
  @override
  Map<String, bool> get howToShowGoodwill;
  @override
  Map<String, bool> get handleHatePeople;
  @override
  List<double> get socialItemValues;
  @override
  String? get relationship;
  @override
  bool get isFindNewLove;
  @override
  bool get isHarem;
  @override
  List<double> get approachValues;
  @override
  List<double> get traitsValues;
  @override
  List<String> get likeItemList;
  @override
  List<String> get admireItemList;
  @override
  List<String> get hateItemList;
  @override
  List<String> get fearItemList;
  @override
  List<String> get familiarItemList;

  /// Create a copy of CharacterEntryData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CharacterEntryDataImplCopyWith<_$CharacterEntryDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
