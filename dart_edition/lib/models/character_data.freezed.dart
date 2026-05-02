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
            ? _value._textFields
            : textFields // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
        alignment: freezed == alignment
            ? _value.alignment
            : alignment // ignore: cast_nullable_to_non_nullable
                  as String?,
        hinderEvents: null == hinderEvents
            ? _value._hinderEvents
            : hinderEvents // ignore: cast_nullable_to_non_nullable
                  as List<CharacterHinderEvent>,
        loveToDoList: null == loveToDoList
            ? _value._loveToDoList
            : loveToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        hateToDoList: null == hateToDoList
            ? _value._hateToDoList
            : hateToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        wantToDoList: null == wantToDoList
            ? _value._wantToDoList
            : wantToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        fearToDoList: null == fearToDoList
            ? _value._fearToDoList
            : fearToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        proficientToDoList: null == proficientToDoList
            ? _value._proficientToDoList
            : proficientToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        unProficientToDoList: null == unProficientToDoList
            ? _value._unProficientToDoList
            : unProficientToDoList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        commonAbilityValues: null == commonAbilityValues
            ? _value._commonAbilityValues
            : commonAbilityValues // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        howToShowLove: null == howToShowLove
            ? _value._howToShowLove
            : howToShowLove // ignore: cast_nullable_to_non_nullable
                  as Map<String, bool>,
        howToShowGoodwill: null == howToShowGoodwill
            ? _value._howToShowGoodwill
            : howToShowGoodwill // ignore: cast_nullable_to_non_nullable
                  as Map<String, bool>,
        handleHatePeople: null == handleHatePeople
            ? _value._handleHatePeople
            : handleHatePeople // ignore: cast_nullable_to_non_nullable
                  as Map<String, bool>,
        socialItemValues: null == socialItemValues
            ? _value._socialItemValues
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
            ? _value._approachValues
            : approachValues // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        traitsValues: null == traitsValues
            ? _value._traitsValues
            : traitsValues // ignore: cast_nullable_to_non_nullable
                  as List<double>,
        likeItemList: null == likeItemList
            ? _value._likeItemList
            : likeItemList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        admireItemList: null == admireItemList
            ? _value._admireItemList
            : admireItemList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        hateItemList: null == hateItemList
            ? _value._hateItemList
            : hateItemList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        fearItemList: null == fearItemList
            ? _value._fearItemList
            : fearItemList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        familiarItemList: null == familiarItemList
            ? _value._familiarItemList
            : familiarItemList // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$CharacterEntryDataImpl extends _CharacterEntryData {
  const _$CharacterEntryDataImpl({
    final Map<String, String> textFields = const <String, String>{},
    this.alignment,
    final List<CharacterHinderEvent> hinderEvents =
        const <CharacterHinderEvent>[],
    final List<String> loveToDoList = const <String>[],
    final List<String> hateToDoList = const <String>[],
    final List<String> wantToDoList = const <String>[],
    final List<String> fearToDoList = const <String>[],
    final List<String> proficientToDoList = const <String>[],
    final List<String> unProficientToDoList = const <String>[],
    final List<double> commonAbilityValues = const <double>[],
    final Map<String, bool> howToShowLove = const <String, bool>{},
    final Map<String, bool> howToShowGoodwill = const <String, bool>{},
    final Map<String, bool> handleHatePeople = const <String, bool>{},
    final List<double> socialItemValues = const <double>[],
    this.relationship,
    this.isFindNewLove = false,
    this.isHarem = false,
    final List<double> approachValues = const <double>[],
    final List<double> traitsValues = const <double>[],
    final List<String> likeItemList = const <String>[],
    final List<String> admireItemList = const <String>[],
    final List<String> hateItemList = const <String>[],
    final List<String> fearItemList = const <String>[],
    final List<String> familiarItemList = const <String>[],
  }) : _textFields = textFields,
       _hinderEvents = hinderEvents,
       _loveToDoList = loveToDoList,
       _hateToDoList = hateToDoList,
       _wantToDoList = wantToDoList,
       _fearToDoList = fearToDoList,
       _proficientToDoList = proficientToDoList,
       _unProficientToDoList = unProficientToDoList,
       _commonAbilityValues = commonAbilityValues,
       _howToShowLove = howToShowLove,
       _howToShowGoodwill = howToShowGoodwill,
       _handleHatePeople = handleHatePeople,
       _socialItemValues = socialItemValues,
       _approachValues = approachValues,
       _traitsValues = traitsValues,
       _likeItemList = likeItemList,
       _admireItemList = admireItemList,
       _hateItemList = hateItemList,
       _fearItemList = fearItemList,
       _familiarItemList = familiarItemList,
       super._();

  final Map<String, String> _textFields;
  @override
  @JsonKey()
  Map<String, String> get textFields {
    if (_textFields is EqualUnmodifiableMapView) return _textFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_textFields);
  }

  @override
  final String? alignment;
  final List<CharacterHinderEvent> _hinderEvents;
  @override
  @JsonKey()
  List<CharacterHinderEvent> get hinderEvents {
    if (_hinderEvents is EqualUnmodifiableListView) return _hinderEvents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_hinderEvents);
  }

  final List<String> _loveToDoList;
  @override
  @JsonKey()
  List<String> get loveToDoList {
    if (_loveToDoList is EqualUnmodifiableListView) return _loveToDoList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_loveToDoList);
  }

  final List<String> _hateToDoList;
  @override
  @JsonKey()
  List<String> get hateToDoList {
    if (_hateToDoList is EqualUnmodifiableListView) return _hateToDoList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_hateToDoList);
  }

  final List<String> _wantToDoList;
  @override
  @JsonKey()
  List<String> get wantToDoList {
    if (_wantToDoList is EqualUnmodifiableListView) return _wantToDoList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_wantToDoList);
  }

  final List<String> _fearToDoList;
  @override
  @JsonKey()
  List<String> get fearToDoList {
    if (_fearToDoList is EqualUnmodifiableListView) return _fearToDoList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fearToDoList);
  }

  final List<String> _proficientToDoList;
  @override
  @JsonKey()
  List<String> get proficientToDoList {
    if (_proficientToDoList is EqualUnmodifiableListView)
      return _proficientToDoList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_proficientToDoList);
  }

  final List<String> _unProficientToDoList;
  @override
  @JsonKey()
  List<String> get unProficientToDoList {
    if (_unProficientToDoList is EqualUnmodifiableListView)
      return _unProficientToDoList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_unProficientToDoList);
  }

  final List<double> _commonAbilityValues;
  @override
  @JsonKey()
  List<double> get commonAbilityValues {
    if (_commonAbilityValues is EqualUnmodifiableListView)
      return _commonAbilityValues;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_commonAbilityValues);
  }

  final Map<String, bool> _howToShowLove;
  @override
  @JsonKey()
  Map<String, bool> get howToShowLove {
    if (_howToShowLove is EqualUnmodifiableMapView) return _howToShowLove;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_howToShowLove);
  }

  final Map<String, bool> _howToShowGoodwill;
  @override
  @JsonKey()
  Map<String, bool> get howToShowGoodwill {
    if (_howToShowGoodwill is EqualUnmodifiableMapView)
      return _howToShowGoodwill;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_howToShowGoodwill);
  }

  final Map<String, bool> _handleHatePeople;
  @override
  @JsonKey()
  Map<String, bool> get handleHatePeople {
    if (_handleHatePeople is EqualUnmodifiableMapView) return _handleHatePeople;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_handleHatePeople);
  }

  final List<double> _socialItemValues;
  @override
  @JsonKey()
  List<double> get socialItemValues {
    if (_socialItemValues is EqualUnmodifiableListView)
      return _socialItemValues;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_socialItemValues);
  }

  @override
  final String? relationship;
  @override
  @JsonKey()
  final bool isFindNewLove;
  @override
  @JsonKey()
  final bool isHarem;
  final List<double> _approachValues;
  @override
  @JsonKey()
  List<double> get approachValues {
    if (_approachValues is EqualUnmodifiableListView) return _approachValues;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_approachValues);
  }

  final List<double> _traitsValues;
  @override
  @JsonKey()
  List<double> get traitsValues {
    if (_traitsValues is EqualUnmodifiableListView) return _traitsValues;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_traitsValues);
  }

  final List<String> _likeItemList;
  @override
  @JsonKey()
  List<String> get likeItemList {
    if (_likeItemList is EqualUnmodifiableListView) return _likeItemList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_likeItemList);
  }

  final List<String> _admireItemList;
  @override
  @JsonKey()
  List<String> get admireItemList {
    if (_admireItemList is EqualUnmodifiableListView) return _admireItemList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_admireItemList);
  }

  final List<String> _hateItemList;
  @override
  @JsonKey()
  List<String> get hateItemList {
    if (_hateItemList is EqualUnmodifiableListView) return _hateItemList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_hateItemList);
  }

  final List<String> _fearItemList;
  @override
  @JsonKey()
  List<String> get fearItemList {
    if (_fearItemList is EqualUnmodifiableListView) return _fearItemList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fearItemList);
  }

  final List<String> _familiarItemList;
  @override
  @JsonKey()
  List<String> get familiarItemList {
    if (_familiarItemList is EqualUnmodifiableListView)
      return _familiarItemList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_familiarItemList);
  }

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
              other._textFields,
              _textFields,
            ) &&
            (identical(other.alignment, alignment) ||
                other.alignment == alignment) &&
            const DeepCollectionEquality().equals(
              other._hinderEvents,
              _hinderEvents,
            ) &&
            const DeepCollectionEquality().equals(
              other._loveToDoList,
              _loveToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other._hateToDoList,
              _hateToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other._wantToDoList,
              _wantToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other._fearToDoList,
              _fearToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other._proficientToDoList,
              _proficientToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other._unProficientToDoList,
              _unProficientToDoList,
            ) &&
            const DeepCollectionEquality().equals(
              other._commonAbilityValues,
              _commonAbilityValues,
            ) &&
            const DeepCollectionEquality().equals(
              other._howToShowLove,
              _howToShowLove,
            ) &&
            const DeepCollectionEquality().equals(
              other._howToShowGoodwill,
              _howToShowGoodwill,
            ) &&
            const DeepCollectionEquality().equals(
              other._handleHatePeople,
              _handleHatePeople,
            ) &&
            const DeepCollectionEquality().equals(
              other._socialItemValues,
              _socialItemValues,
            ) &&
            (identical(other.relationship, relationship) ||
                other.relationship == relationship) &&
            (identical(other.isFindNewLove, isFindNewLove) ||
                other.isFindNewLove == isFindNewLove) &&
            (identical(other.isHarem, isHarem) || other.isHarem == isHarem) &&
            const DeepCollectionEquality().equals(
              other._approachValues,
              _approachValues,
            ) &&
            const DeepCollectionEquality().equals(
              other._traitsValues,
              _traitsValues,
            ) &&
            const DeepCollectionEquality().equals(
              other._likeItemList,
              _likeItemList,
            ) &&
            const DeepCollectionEquality().equals(
              other._admireItemList,
              _admireItemList,
            ) &&
            const DeepCollectionEquality().equals(
              other._hateItemList,
              _hateItemList,
            ) &&
            const DeepCollectionEquality().equals(
              other._fearItemList,
              _fearItemList,
            ) &&
            const DeepCollectionEquality().equals(
              other._familiarItemList,
              _familiarItemList,
            ));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    const DeepCollectionEquality().hash(_textFields),
    alignment,
    const DeepCollectionEquality().hash(_hinderEvents),
    const DeepCollectionEquality().hash(_loveToDoList),
    const DeepCollectionEquality().hash(_hateToDoList),
    const DeepCollectionEquality().hash(_wantToDoList),
    const DeepCollectionEquality().hash(_fearToDoList),
    const DeepCollectionEquality().hash(_proficientToDoList),
    const DeepCollectionEquality().hash(_unProficientToDoList),
    const DeepCollectionEquality().hash(_commonAbilityValues),
    const DeepCollectionEquality().hash(_howToShowLove),
    const DeepCollectionEquality().hash(_howToShowGoodwill),
    const DeepCollectionEquality().hash(_handleHatePeople),
    const DeepCollectionEquality().hash(_socialItemValues),
    relationship,
    isFindNewLove,
    isHarem,
    const DeepCollectionEquality().hash(_approachValues),
    const DeepCollectionEquality().hash(_traitsValues),
    const DeepCollectionEquality().hash(_likeItemList),
    const DeepCollectionEquality().hash(_admireItemList),
    const DeepCollectionEquality().hash(_hateItemList),
    const DeepCollectionEquality().hash(_fearItemList),
    const DeepCollectionEquality().hash(_familiarItemList),
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
