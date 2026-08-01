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
mixin _$CharacterAlias {
  String get type => throw _privateConstructorUsedError;
  List<String> get values => throw _privateConstructorUsedError;

  /// Create a copy of CharacterAlias
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CharacterAliasCopyWith<CharacterAlias> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterAliasCopyWith<$Res> {
  factory $CharacterAliasCopyWith(
    CharacterAlias value,
    $Res Function(CharacterAlias) then,
  ) = _$CharacterAliasCopyWithImpl<$Res, CharacterAlias>;
  @useResult
  $Res call({String type, List<String> values});
}

/// @nodoc
class _$CharacterAliasCopyWithImpl<$Res, $Val extends CharacterAlias>
    implements $CharacterAliasCopyWith<$Res> {
  _$CharacterAliasCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CharacterAlias
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? values = null}) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            values: null == values
                ? _value.values
                : values // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CharacterAliasImplCopyWith<$Res>
    implements $CharacterAliasCopyWith<$Res> {
  factory _$$CharacterAliasImplCopyWith(
    _$CharacterAliasImpl value,
    $Res Function(_$CharacterAliasImpl) then,
  ) = __$$CharacterAliasImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, List<String> values});
}

/// @nodoc
class __$$CharacterAliasImplCopyWithImpl<$Res>
    extends _$CharacterAliasCopyWithImpl<$Res, _$CharacterAliasImpl>
    implements _$$CharacterAliasImplCopyWith<$Res> {
  __$$CharacterAliasImplCopyWithImpl(
    _$CharacterAliasImpl _value,
    $Res Function(_$CharacterAliasImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CharacterAlias
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? values = null}) {
    return _then(
      _$CharacterAliasImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        values: null == values
            ? _value._values
            : values // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$CharacterAliasImpl implements _CharacterAlias {
  const _$CharacterAliasImpl({
    this.type = "nickname",
    final List<String> values = const <String>[],
  }) : _values = values;

  @override
  @JsonKey()
  final String type;
  final List<String> _values;
  @override
  @JsonKey()
  List<String> get values {
    if (_values is EqualUnmodifiableListView) return _values;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_values);
  }

  @override
  String toString() {
    return 'CharacterAlias(type: $type, values: $values)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterAliasImpl &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other._values, _values));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    type,
    const DeepCollectionEquality().hash(_values),
  );

  /// Create a copy of CharacterAlias
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterAliasImplCopyWith<_$CharacterAliasImpl> get copyWith =>
      __$$CharacterAliasImplCopyWithImpl<_$CharacterAliasImpl>(
        this,
        _$identity,
      );
}

abstract class _CharacterAlias implements CharacterAlias {
  const factory _CharacterAlias({
    final String type,
    final List<String> values,
  }) = _$CharacterAliasImpl;

  @override
  String get type;
  @override
  List<String> get values;

  /// Create a copy of CharacterAlias
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CharacterAliasImplCopyWith<_$CharacterAliasImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CharacterConflict {
  String get obstacle => throw _privateConstructorUsedError;
  String get resolution => throw _privateConstructorUsedError;

  /// Create a copy of CharacterConflict
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CharacterConflictCopyWith<CharacterConflict> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterConflictCopyWith<$Res> {
  factory $CharacterConflictCopyWith(
    CharacterConflict value,
    $Res Function(CharacterConflict) then,
  ) = _$CharacterConflictCopyWithImpl<$Res, CharacterConflict>;
  @useResult
  $Res call({String obstacle, String resolution});
}

/// @nodoc
class _$CharacterConflictCopyWithImpl<$Res, $Val extends CharacterConflict>
    implements $CharacterConflictCopyWith<$Res> {
  _$CharacterConflictCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CharacterConflict
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? obstacle = null, Object? resolution = null}) {
    return _then(
      _value.copyWith(
            obstacle: null == obstacle
                ? _value.obstacle
                : obstacle // ignore: cast_nullable_to_non_nullable
                      as String,
            resolution: null == resolution
                ? _value.resolution
                : resolution // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CharacterConflictImplCopyWith<$Res>
    implements $CharacterConflictCopyWith<$Res> {
  factory _$$CharacterConflictImplCopyWith(
    _$CharacterConflictImpl value,
    $Res Function(_$CharacterConflictImpl) then,
  ) = __$$CharacterConflictImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String obstacle, String resolution});
}

/// @nodoc
class __$$CharacterConflictImplCopyWithImpl<$Res>
    extends _$CharacterConflictCopyWithImpl<$Res, _$CharacterConflictImpl>
    implements _$$CharacterConflictImplCopyWith<$Res> {
  __$$CharacterConflictImplCopyWithImpl(
    _$CharacterConflictImpl _value,
    $Res Function(_$CharacterConflictImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CharacterConflict
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? obstacle = null, Object? resolution = null}) {
    return _then(
      _$CharacterConflictImpl(
        obstacle: null == obstacle
            ? _value.obstacle
            : obstacle // ignore: cast_nullable_to_non_nullable
                  as String,
        resolution: null == resolution
            ? _value.resolution
            : resolution // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$CharacterConflictImpl implements _CharacterConflict {
  const _$CharacterConflictImpl({this.obstacle = "", this.resolution = ""});

  @override
  @JsonKey()
  final String obstacle;
  @override
  @JsonKey()
  final String resolution;

  @override
  String toString() {
    return 'CharacterConflict(obstacle: $obstacle, resolution: $resolution)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterConflictImpl &&
            (identical(other.obstacle, obstacle) ||
                other.obstacle == obstacle) &&
            (identical(other.resolution, resolution) ||
                other.resolution == resolution));
  }

  @override
  int get hashCode => Object.hash(runtimeType, obstacle, resolution);

  /// Create a copy of CharacterConflict
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterConflictImplCopyWith<_$CharacterConflictImpl> get copyWith =>
      __$$CharacterConflictImplCopyWithImpl<_$CharacterConflictImpl>(
        this,
        _$identity,
      );
}

abstract class _CharacterConflict implements CharacterConflict {
  const factory _CharacterConflict({
    final String obstacle,
    final String resolution,
  }) = _$CharacterConflictImpl;

  @override
  String get obstacle;
  @override
  String get resolution;

  /// Create a copy of CharacterConflict
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CharacterConflictImplCopyWith<_$CharacterConflictImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CharacterRelationship {
  String get person => throw _privateConstructorUsedError;
  String get relationship => throw _privateConstructorUsedError;

  /// Create a copy of CharacterRelationship
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CharacterRelationshipCopyWith<CharacterRelationship> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterRelationshipCopyWith<$Res> {
  factory $CharacterRelationshipCopyWith(
    CharacterRelationship value,
    $Res Function(CharacterRelationship) then,
  ) = _$CharacterRelationshipCopyWithImpl<$Res, CharacterRelationship>;
  @useResult
  $Res call({String person, String relationship});
}

/// @nodoc
class _$CharacterRelationshipCopyWithImpl<
  $Res,
  $Val extends CharacterRelationship
>
    implements $CharacterRelationshipCopyWith<$Res> {
  _$CharacterRelationshipCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CharacterRelationship
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? person = null, Object? relationship = null}) {
    return _then(
      _value.copyWith(
            person: null == person
                ? _value.person
                : person // ignore: cast_nullable_to_non_nullable
                      as String,
            relationship: null == relationship
                ? _value.relationship
                : relationship // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CharacterRelationshipImplCopyWith<$Res>
    implements $CharacterRelationshipCopyWith<$Res> {
  factory _$$CharacterRelationshipImplCopyWith(
    _$CharacterRelationshipImpl value,
    $Res Function(_$CharacterRelationshipImpl) then,
  ) = __$$CharacterRelationshipImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String person, String relationship});
}

/// @nodoc
class __$$CharacterRelationshipImplCopyWithImpl<$Res>
    extends
        _$CharacterRelationshipCopyWithImpl<$Res, _$CharacterRelationshipImpl>
    implements _$$CharacterRelationshipImplCopyWith<$Res> {
  __$$CharacterRelationshipImplCopyWithImpl(
    _$CharacterRelationshipImpl _value,
    $Res Function(_$CharacterRelationshipImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CharacterRelationship
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? person = null, Object? relationship = null}) {
    return _then(
      _$CharacterRelationshipImpl(
        person: null == person
            ? _value.person
            : person // ignore: cast_nullable_to_non_nullable
                  as String,
        relationship: null == relationship
            ? _value.relationship
            : relationship // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$CharacterRelationshipImpl implements _CharacterRelationship {
  const _$CharacterRelationshipImpl({this.person = "", this.relationship = ""});

  @override
  @JsonKey()
  final String person;
  @override
  @JsonKey()
  final String relationship;

  @override
  String toString() {
    return 'CharacterRelationship(person: $person, relationship: $relationship)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterRelationshipImpl &&
            (identical(other.person, person) || other.person == person) &&
            (identical(other.relationship, relationship) ||
                other.relationship == relationship));
  }

  @override
  int get hashCode => Object.hash(runtimeType, person, relationship);

  /// Create a copy of CharacterRelationship
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterRelationshipImplCopyWith<_$CharacterRelationshipImpl>
  get copyWith =>
      __$$CharacterRelationshipImplCopyWithImpl<_$CharacterRelationshipImpl>(
        this,
        _$identity,
      );
}

abstract class _CharacterRelationship implements CharacterRelationship {
  const factory _CharacterRelationship({
    final String person,
    final String relationship,
  }) = _$CharacterRelationshipImpl;

  @override
  String get person;
  @override
  String get relationship;

  /// Create a copy of CharacterRelationship
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CharacterRelationshipImplCopyWith<_$CharacterRelationshipImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CharacterAdvancedProfile {
  Map<String, double> get commonAbilities => throw _privateConstructorUsedError;
  Map<String, double> get socialTraits => throw _privateConstructorUsedError;
  Map<String, double> get approaches => throw _privateConstructorUsedError;
  Map<String, double> get personalityTraits =>
      throw _privateConstructorUsedError;

  /// Create a copy of CharacterAdvancedProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CharacterAdvancedProfileCopyWith<CharacterAdvancedProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterAdvancedProfileCopyWith<$Res> {
  factory $CharacterAdvancedProfileCopyWith(
    CharacterAdvancedProfile value,
    $Res Function(CharacterAdvancedProfile) then,
  ) = _$CharacterAdvancedProfileCopyWithImpl<$Res, CharacterAdvancedProfile>;
  @useResult
  $Res call({
    Map<String, double> commonAbilities,
    Map<String, double> socialTraits,
    Map<String, double> approaches,
    Map<String, double> personalityTraits,
  });
}

/// @nodoc
class _$CharacterAdvancedProfileCopyWithImpl<
  $Res,
  $Val extends CharacterAdvancedProfile
>
    implements $CharacterAdvancedProfileCopyWith<$Res> {
  _$CharacterAdvancedProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CharacterAdvancedProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? commonAbilities = null,
    Object? socialTraits = null,
    Object? approaches = null,
    Object? personalityTraits = null,
  }) {
    return _then(
      _value.copyWith(
            commonAbilities: null == commonAbilities
                ? _value.commonAbilities
                : commonAbilities // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>,
            socialTraits: null == socialTraits
                ? _value.socialTraits
                : socialTraits // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>,
            approaches: null == approaches
                ? _value.approaches
                : approaches // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>,
            personalityTraits: null == personalityTraits
                ? _value.personalityTraits
                : personalityTraits // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CharacterAdvancedProfileImplCopyWith<$Res>
    implements $CharacterAdvancedProfileCopyWith<$Res> {
  factory _$$CharacterAdvancedProfileImplCopyWith(
    _$CharacterAdvancedProfileImpl value,
    $Res Function(_$CharacterAdvancedProfileImpl) then,
  ) = __$$CharacterAdvancedProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Map<String, double> commonAbilities,
    Map<String, double> socialTraits,
    Map<String, double> approaches,
    Map<String, double> personalityTraits,
  });
}

/// @nodoc
class __$$CharacterAdvancedProfileImplCopyWithImpl<$Res>
    extends
        _$CharacterAdvancedProfileCopyWithImpl<
          $Res,
          _$CharacterAdvancedProfileImpl
        >
    implements _$$CharacterAdvancedProfileImplCopyWith<$Res> {
  __$$CharacterAdvancedProfileImplCopyWithImpl(
    _$CharacterAdvancedProfileImpl _value,
    $Res Function(_$CharacterAdvancedProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CharacterAdvancedProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? commonAbilities = null,
    Object? socialTraits = null,
    Object? approaches = null,
    Object? personalityTraits = null,
  }) {
    return _then(
      _$CharacterAdvancedProfileImpl(
        commonAbilities: null == commonAbilities
            ? _value._commonAbilities
            : commonAbilities // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>,
        socialTraits: null == socialTraits
            ? _value._socialTraits
            : socialTraits // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>,
        approaches: null == approaches
            ? _value._approaches
            : approaches // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>,
        personalityTraits: null == personalityTraits
            ? _value._personalityTraits
            : personalityTraits // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>,
      ),
    );
  }
}

/// @nodoc

class _$CharacterAdvancedProfileImpl implements _CharacterAdvancedProfile {
  const _$CharacterAdvancedProfileImpl({
    final Map<String, double> commonAbilities = const <String, double>{},
    final Map<String, double> socialTraits = const <String, double>{},
    final Map<String, double> approaches = const <String, double>{},
    final Map<String, double> personalityTraits = const <String, double>{},
  }) : _commonAbilities = commonAbilities,
       _socialTraits = socialTraits,
       _approaches = approaches,
       _personalityTraits = personalityTraits;

  final Map<String, double> _commonAbilities;
  @override
  @JsonKey()
  Map<String, double> get commonAbilities {
    if (_commonAbilities is EqualUnmodifiableMapView) return _commonAbilities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_commonAbilities);
  }

  final Map<String, double> _socialTraits;
  @override
  @JsonKey()
  Map<String, double> get socialTraits {
    if (_socialTraits is EqualUnmodifiableMapView) return _socialTraits;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_socialTraits);
  }

  final Map<String, double> _approaches;
  @override
  @JsonKey()
  Map<String, double> get approaches {
    if (_approaches is EqualUnmodifiableMapView) return _approaches;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_approaches);
  }

  final Map<String, double> _personalityTraits;
  @override
  @JsonKey()
  Map<String, double> get personalityTraits {
    if (_personalityTraits is EqualUnmodifiableMapView)
      return _personalityTraits;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_personalityTraits);
  }

  @override
  String toString() {
    return 'CharacterAdvancedProfile(commonAbilities: $commonAbilities, socialTraits: $socialTraits, approaches: $approaches, personalityTraits: $personalityTraits)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterAdvancedProfileImpl &&
            const DeepCollectionEquality().equals(
              other._commonAbilities,
              _commonAbilities,
            ) &&
            const DeepCollectionEquality().equals(
              other._socialTraits,
              _socialTraits,
            ) &&
            const DeepCollectionEquality().equals(
              other._approaches,
              _approaches,
            ) &&
            const DeepCollectionEquality().equals(
              other._personalityTraits,
              _personalityTraits,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_commonAbilities),
    const DeepCollectionEquality().hash(_socialTraits),
    const DeepCollectionEquality().hash(_approaches),
    const DeepCollectionEquality().hash(_personalityTraits),
  );

  /// Create a copy of CharacterAdvancedProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterAdvancedProfileImplCopyWith<_$CharacterAdvancedProfileImpl>
  get copyWith =>
      __$$CharacterAdvancedProfileImplCopyWithImpl<
        _$CharacterAdvancedProfileImpl
      >(this, _$identity);
}

abstract class _CharacterAdvancedProfile implements CharacterAdvancedProfile {
  const factory _CharacterAdvancedProfile({
    final Map<String, double> commonAbilities,
    final Map<String, double> socialTraits,
    final Map<String, double> approaches,
    final Map<String, double> personalityTraits,
  }) = _$CharacterAdvancedProfileImpl;

  @override
  Map<String, double> get commonAbilities;
  @override
  Map<String, double> get socialTraits;
  @override
  Map<String, double> get approaches;
  @override
  Map<String, double> get personalityTraits;

  /// Create a copy of CharacterAdvancedProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CharacterAdvancedProfileImplCopyWith<_$CharacterAdvancedProfileImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CharacterState {
  String get characterId => throw _privateConstructorUsedError;
  String? get storyTimePointId => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  String get healthStatus => throw _privateConstructorUsedError;
  String get emotion => throw _privateConstructorUsedError;
  String get alignment => throw _privateConstructorUsedError;
  List<String> get possessions => throw _privateConstructorUsedError;

  /// Create a copy of CharacterState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CharacterStateCopyWith<CharacterState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterStateCopyWith<$Res> {
  factory $CharacterStateCopyWith(
    CharacterState value,
    $Res Function(CharacterState) then,
  ) = _$CharacterStateCopyWithImpl<$Res, CharacterState>;
  @useResult
  $Res call({
    String characterId,
    String? storyTimePointId,
    String location,
    String healthStatus,
    String emotion,
    String alignment,
    List<String> possessions,
  });
}

/// @nodoc
class _$CharacterStateCopyWithImpl<$Res, $Val extends CharacterState>
    implements $CharacterStateCopyWith<$Res> {
  _$CharacterStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CharacterState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? characterId = null,
    Object? storyTimePointId = freezed,
    Object? location = null,
    Object? healthStatus = null,
    Object? emotion = null,
    Object? alignment = null,
    Object? possessions = null,
  }) {
    return _then(
      _value.copyWith(
            characterId: null == characterId
                ? _value.characterId
                : characterId // ignore: cast_nullable_to_non_nullable
                      as String,
            storyTimePointId: freezed == storyTimePointId
                ? _value.storyTimePointId
                : storyTimePointId // ignore: cast_nullable_to_non_nullable
                      as String?,
            location: null == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as String,
            healthStatus: null == healthStatus
                ? _value.healthStatus
                : healthStatus // ignore: cast_nullable_to_non_nullable
                      as String,
            emotion: null == emotion
                ? _value.emotion
                : emotion // ignore: cast_nullable_to_non_nullable
                      as String,
            alignment: null == alignment
                ? _value.alignment
                : alignment // ignore: cast_nullable_to_non_nullable
                      as String,
            possessions: null == possessions
                ? _value.possessions
                : possessions // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CharacterStateImplCopyWith<$Res>
    implements $CharacterStateCopyWith<$Res> {
  factory _$$CharacterStateImplCopyWith(
    _$CharacterStateImpl value,
    $Res Function(_$CharacterStateImpl) then,
  ) = __$$CharacterStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String characterId,
    String? storyTimePointId,
    String location,
    String healthStatus,
    String emotion,
    String alignment,
    List<String> possessions,
  });
}

/// @nodoc
class __$$CharacterStateImplCopyWithImpl<$Res>
    extends _$CharacterStateCopyWithImpl<$Res, _$CharacterStateImpl>
    implements _$$CharacterStateImplCopyWith<$Res> {
  __$$CharacterStateImplCopyWithImpl(
    _$CharacterStateImpl _value,
    $Res Function(_$CharacterStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CharacterState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? characterId = null,
    Object? storyTimePointId = freezed,
    Object? location = null,
    Object? healthStatus = null,
    Object? emotion = null,
    Object? alignment = null,
    Object? possessions = null,
  }) {
    return _then(
      _$CharacterStateImpl(
        characterId: null == characterId
            ? _value.characterId
            : characterId // ignore: cast_nullable_to_non_nullable
                  as String,
        storyTimePointId: freezed == storyTimePointId
            ? _value.storyTimePointId
            : storyTimePointId // ignore: cast_nullable_to_non_nullable
                  as String?,
        location: null == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as String,
        healthStatus: null == healthStatus
            ? _value.healthStatus
            : healthStatus // ignore: cast_nullable_to_non_nullable
                  as String,
        emotion: null == emotion
            ? _value.emotion
            : emotion // ignore: cast_nullable_to_non_nullable
                  as String,
        alignment: null == alignment
            ? _value.alignment
            : alignment // ignore: cast_nullable_to_non_nullable
                  as String,
        possessions: null == possessions
            ? _value._possessions
            : possessions // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$CharacterStateImpl implements _CharacterState {
  const _$CharacterStateImpl({
    required this.characterId,
    this.storyTimePointId,
    this.location = "",
    this.healthStatus = "",
    this.emotion = "",
    this.alignment = "",
    final List<String> possessions = const <String>[],
  }) : _possessions = possessions;

  @override
  final String characterId;
  @override
  final String? storyTimePointId;
  @override
  @JsonKey()
  final String location;
  @override
  @JsonKey()
  final String healthStatus;
  @override
  @JsonKey()
  final String emotion;
  @override
  @JsonKey()
  final String alignment;
  final List<String> _possessions;
  @override
  @JsonKey()
  List<String> get possessions {
    if (_possessions is EqualUnmodifiableListView) return _possessions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_possessions);
  }

  @override
  String toString() {
    return 'CharacterState(characterId: $characterId, storyTimePointId: $storyTimePointId, location: $location, healthStatus: $healthStatus, emotion: $emotion, alignment: $alignment, possessions: $possessions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterStateImpl &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.storyTimePointId, storyTimePointId) ||
                other.storyTimePointId == storyTimePointId) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.healthStatus, healthStatus) ||
                other.healthStatus == healthStatus) &&
            (identical(other.emotion, emotion) || other.emotion == emotion) &&
            (identical(other.alignment, alignment) ||
                other.alignment == alignment) &&
            const DeepCollectionEquality().equals(
              other._possessions,
              _possessions,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    characterId,
    storyTimePointId,
    location,
    healthStatus,
    emotion,
    alignment,
    const DeepCollectionEquality().hash(_possessions),
  );

  /// Create a copy of CharacterState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterStateImplCopyWith<_$CharacterStateImpl> get copyWith =>
      __$$CharacterStateImplCopyWithImpl<_$CharacterStateImpl>(
        this,
        _$identity,
      );
}

abstract class _CharacterState implements CharacterState {
  const factory _CharacterState({
    required final String characterId,
    final String? storyTimePointId,
    final String location,
    final String healthStatus,
    final String emotion,
    final String alignment,
    final List<String> possessions,
  }) = _$CharacterStateImpl;

  @override
  String get characterId;
  @override
  String? get storyTimePointId;
  @override
  String get location;
  @override
  String get healthStatus;
  @override
  String get emotion;
  @override
  String get alignment;
  @override
  List<String> get possessions;

  /// Create a copy of CharacterState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CharacterStateImplCopyWith<_$CharacterStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

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
  String get characterId => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  List<CharacterAlias> get aliases => throw _privateConstructorUsedError;
  String get roleOrOccupation => throw _privateConstructorUsedError;
  String get age => throw _privateConstructorUsedError;
  String get gender => throw _privateConstructorUsedError;
  String get appearanceSummary => throw _privateConstructorUsedError;
  String get personalitySummary => throw _privateConstructorUsedError;
  String get speechStyle => throw _privateConstructorUsedError;
  String get motivation => throw _privateConstructorUsedError;
  String get goal => throw _privateConstructorUsedError;
  List<CharacterConflict> get conflicts => throw _privateConstructorUsedError;
  String get valuesAndBeliefs => throw _privateConstructorUsedError;
  String get fear => throw _privateConstructorUsedError;
  String get relationshipSummary => throw _privateConstructorUsedError;
  List<CharacterRelationship> get relationships =>
      throw _privateConstructorUsedError;
  String get notes => throw _privateConstructorUsedError;
  CharacterAdvancedProfile get advanced => throw _privateConstructorUsedError;
  Map<String, CustomFieldValue> get customFields =>
      throw _privateConstructorUsedError;
  Map<String, String> get legacyFields => throw _privateConstructorUsedError;
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
    String characterId,
    String displayName,
    List<CharacterAlias> aliases,
    String roleOrOccupation,
    String age,
    String gender,
    String appearanceSummary,
    String personalitySummary,
    String speechStyle,
    String motivation,
    String goal,
    List<CharacterConflict> conflicts,
    String valuesAndBeliefs,
    String fear,
    String relationshipSummary,
    List<CharacterRelationship> relationships,
    String notes,
    CharacterAdvancedProfile advanced,
    Map<String, CustomFieldValue> customFields,
    Map<String, String> legacyFields,
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

  $CharacterAdvancedProfileCopyWith<$Res> get advanced;
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
    Object? characterId = null,
    Object? displayName = null,
    Object? aliases = null,
    Object? roleOrOccupation = null,
    Object? age = null,
    Object? gender = null,
    Object? appearanceSummary = null,
    Object? personalitySummary = null,
    Object? speechStyle = null,
    Object? motivation = null,
    Object? goal = null,
    Object? conflicts = null,
    Object? valuesAndBeliefs = null,
    Object? fear = null,
    Object? relationshipSummary = null,
    Object? relationships = null,
    Object? notes = null,
    Object? advanced = null,
    Object? customFields = null,
    Object? legacyFields = null,
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
            characterId: null == characterId
                ? _value.characterId
                : characterId // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
            aliases: null == aliases
                ? _value.aliases
                : aliases // ignore: cast_nullable_to_non_nullable
                      as List<CharacterAlias>,
            roleOrOccupation: null == roleOrOccupation
                ? _value.roleOrOccupation
                : roleOrOccupation // ignore: cast_nullable_to_non_nullable
                      as String,
            age: null == age
                ? _value.age
                : age // ignore: cast_nullable_to_non_nullable
                      as String,
            gender: null == gender
                ? _value.gender
                : gender // ignore: cast_nullable_to_non_nullable
                      as String,
            appearanceSummary: null == appearanceSummary
                ? _value.appearanceSummary
                : appearanceSummary // ignore: cast_nullable_to_non_nullable
                      as String,
            personalitySummary: null == personalitySummary
                ? _value.personalitySummary
                : personalitySummary // ignore: cast_nullable_to_non_nullable
                      as String,
            speechStyle: null == speechStyle
                ? _value.speechStyle
                : speechStyle // ignore: cast_nullable_to_non_nullable
                      as String,
            motivation: null == motivation
                ? _value.motivation
                : motivation // ignore: cast_nullable_to_non_nullable
                      as String,
            goal: null == goal
                ? _value.goal
                : goal // ignore: cast_nullable_to_non_nullable
                      as String,
            conflicts: null == conflicts
                ? _value.conflicts
                : conflicts // ignore: cast_nullable_to_non_nullable
                      as List<CharacterConflict>,
            valuesAndBeliefs: null == valuesAndBeliefs
                ? _value.valuesAndBeliefs
                : valuesAndBeliefs // ignore: cast_nullable_to_non_nullable
                      as String,
            fear: null == fear
                ? _value.fear
                : fear // ignore: cast_nullable_to_non_nullable
                      as String,
            relationshipSummary: null == relationshipSummary
                ? _value.relationshipSummary
                : relationshipSummary // ignore: cast_nullable_to_non_nullable
                      as String,
            relationships: null == relationships
                ? _value.relationships
                : relationships // ignore: cast_nullable_to_non_nullable
                      as List<CharacterRelationship>,
            notes: null == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String,
            advanced: null == advanced
                ? _value.advanced
                : advanced // ignore: cast_nullable_to_non_nullable
                      as CharacterAdvancedProfile,
            customFields: null == customFields
                ? _value.customFields
                : customFields // ignore: cast_nullable_to_non_nullable
                      as Map<String, CustomFieldValue>,
            legacyFields: null == legacyFields
                ? _value.legacyFields
                : legacyFields // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
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

  /// Create a copy of CharacterEntryData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CharacterAdvancedProfileCopyWith<$Res> get advanced {
    return $CharacterAdvancedProfileCopyWith<$Res>(_value.advanced, (value) {
      return _then(_value.copyWith(advanced: value) as $Val);
    });
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
    String characterId,
    String displayName,
    List<CharacterAlias> aliases,
    String roleOrOccupation,
    String age,
    String gender,
    String appearanceSummary,
    String personalitySummary,
    String speechStyle,
    String motivation,
    String goal,
    List<CharacterConflict> conflicts,
    String valuesAndBeliefs,
    String fear,
    String relationshipSummary,
    List<CharacterRelationship> relationships,
    String notes,
    CharacterAdvancedProfile advanced,
    Map<String, CustomFieldValue> customFields,
    Map<String, String> legacyFields,
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

  @override
  $CharacterAdvancedProfileCopyWith<$Res> get advanced;
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
    Object? characterId = null,
    Object? displayName = null,
    Object? aliases = null,
    Object? roleOrOccupation = null,
    Object? age = null,
    Object? gender = null,
    Object? appearanceSummary = null,
    Object? personalitySummary = null,
    Object? speechStyle = null,
    Object? motivation = null,
    Object? goal = null,
    Object? conflicts = null,
    Object? valuesAndBeliefs = null,
    Object? fear = null,
    Object? relationshipSummary = null,
    Object? relationships = null,
    Object? notes = null,
    Object? advanced = null,
    Object? customFields = null,
    Object? legacyFields = null,
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
        characterId: null == characterId
            ? _value.characterId
            : characterId // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        aliases: null == aliases
            ? _value._aliases
            : aliases // ignore: cast_nullable_to_non_nullable
                  as List<CharacterAlias>,
        roleOrOccupation: null == roleOrOccupation
            ? _value.roleOrOccupation
            : roleOrOccupation // ignore: cast_nullable_to_non_nullable
                  as String,
        age: null == age
            ? _value.age
            : age // ignore: cast_nullable_to_non_nullable
                  as String,
        gender: null == gender
            ? _value.gender
            : gender // ignore: cast_nullable_to_non_nullable
                  as String,
        appearanceSummary: null == appearanceSummary
            ? _value.appearanceSummary
            : appearanceSummary // ignore: cast_nullable_to_non_nullable
                  as String,
        personalitySummary: null == personalitySummary
            ? _value.personalitySummary
            : personalitySummary // ignore: cast_nullable_to_non_nullable
                  as String,
        speechStyle: null == speechStyle
            ? _value.speechStyle
            : speechStyle // ignore: cast_nullable_to_non_nullable
                  as String,
        motivation: null == motivation
            ? _value.motivation
            : motivation // ignore: cast_nullable_to_non_nullable
                  as String,
        goal: null == goal
            ? _value.goal
            : goal // ignore: cast_nullable_to_non_nullable
                  as String,
        conflicts: null == conflicts
            ? _value._conflicts
            : conflicts // ignore: cast_nullable_to_non_nullable
                  as List<CharacterConflict>,
        valuesAndBeliefs: null == valuesAndBeliefs
            ? _value.valuesAndBeliefs
            : valuesAndBeliefs // ignore: cast_nullable_to_non_nullable
                  as String,
        fear: null == fear
            ? _value.fear
            : fear // ignore: cast_nullable_to_non_nullable
                  as String,
        relationshipSummary: null == relationshipSummary
            ? _value.relationshipSummary
            : relationshipSummary // ignore: cast_nullable_to_non_nullable
                  as String,
        relationships: null == relationships
            ? _value._relationships
            : relationships // ignore: cast_nullable_to_non_nullable
                  as List<CharacterRelationship>,
        notes: null == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String,
        advanced: null == advanced
            ? _value.advanced
            : advanced // ignore: cast_nullable_to_non_nullable
                  as CharacterAdvancedProfile,
        customFields: null == customFields
            ? _value._customFields
            : customFields // ignore: cast_nullable_to_non_nullable
                  as Map<String, CustomFieldValue>,
        legacyFields: null == legacyFields
            ? _value._legacyFields
            : legacyFields // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
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
    this.characterId = "",
    this.displayName = "",
    final List<CharacterAlias> aliases = const <CharacterAlias>[],
    this.roleOrOccupation = "",
    this.age = "",
    this.gender = "",
    this.appearanceSummary = "",
    this.personalitySummary = "",
    this.speechStyle = "",
    this.motivation = "",
    this.goal = "",
    final List<CharacterConflict> conflicts = const <CharacterConflict>[],
    this.valuesAndBeliefs = "",
    this.fear = "",
    this.relationshipSummary = "",
    final List<CharacterRelationship> relationships =
        const <CharacterRelationship>[],
    this.notes = "",
    this.advanced = const CharacterAdvancedProfile(),
    final Map<String, CustomFieldValue> customFields =
        const <String, CustomFieldValue>{},
    final Map<String, String> legacyFields = const <String, String>{},
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
  }) : _aliases = aliases,
       _conflicts = conflicts,
       _relationships = relationships,
       _customFields = customFields,
       _legacyFields = legacyFields,
       _textFields = textFields,
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

  @override
  @JsonKey()
  final String characterId;
  @override
  @JsonKey()
  final String displayName;
  final List<CharacterAlias> _aliases;
  @override
  @JsonKey()
  List<CharacterAlias> get aliases {
    if (_aliases is EqualUnmodifiableListView) return _aliases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_aliases);
  }

  @override
  @JsonKey()
  final String roleOrOccupation;
  @override
  @JsonKey()
  final String age;
  @override
  @JsonKey()
  final String gender;
  @override
  @JsonKey()
  final String appearanceSummary;
  @override
  @JsonKey()
  final String personalitySummary;
  @override
  @JsonKey()
  final String speechStyle;
  @override
  @JsonKey()
  final String motivation;
  @override
  @JsonKey()
  final String goal;
  final List<CharacterConflict> _conflicts;
  @override
  @JsonKey()
  List<CharacterConflict> get conflicts {
    if (_conflicts is EqualUnmodifiableListView) return _conflicts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_conflicts);
  }

  @override
  @JsonKey()
  final String valuesAndBeliefs;
  @override
  @JsonKey()
  final String fear;
  @override
  @JsonKey()
  final String relationshipSummary;
  final List<CharacterRelationship> _relationships;
  @override
  @JsonKey()
  List<CharacterRelationship> get relationships {
    if (_relationships is EqualUnmodifiableListView) return _relationships;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_relationships);
  }

  @override
  @JsonKey()
  final String notes;
  @override
  @JsonKey()
  final CharacterAdvancedProfile advanced;
  final Map<String, CustomFieldValue> _customFields;
  @override
  @JsonKey()
  Map<String, CustomFieldValue> get customFields {
    if (_customFields is EqualUnmodifiableMapView) return _customFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_customFields);
  }

  final Map<String, String> _legacyFields;
  @override
  @JsonKey()
  Map<String, String> get legacyFields {
    if (_legacyFields is EqualUnmodifiableMapView) return _legacyFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_legacyFields);
  }

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
    return 'CharacterEntryData(characterId: $characterId, displayName: $displayName, aliases: $aliases, roleOrOccupation: $roleOrOccupation, age: $age, gender: $gender, appearanceSummary: $appearanceSummary, personalitySummary: $personalitySummary, speechStyle: $speechStyle, motivation: $motivation, goal: $goal, conflicts: $conflicts, valuesAndBeliefs: $valuesAndBeliefs, fear: $fear, relationshipSummary: $relationshipSummary, relationships: $relationships, notes: $notes, advanced: $advanced, customFields: $customFields, legacyFields: $legacyFields, textFields: $textFields, alignment: $alignment, hinderEvents: $hinderEvents, loveToDoList: $loveToDoList, hateToDoList: $hateToDoList, wantToDoList: $wantToDoList, fearToDoList: $fearToDoList, proficientToDoList: $proficientToDoList, unProficientToDoList: $unProficientToDoList, commonAbilityValues: $commonAbilityValues, howToShowLove: $howToShowLove, howToShowGoodwill: $howToShowGoodwill, handleHatePeople: $handleHatePeople, socialItemValues: $socialItemValues, relationship: $relationship, isFindNewLove: $isFindNewLove, isHarem: $isHarem, approachValues: $approachValues, traitsValues: $traitsValues, likeItemList: $likeItemList, admireItemList: $admireItemList, hateItemList: $hateItemList, fearItemList: $fearItemList, familiarItemList: $familiarItemList)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterEntryDataImpl &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            const DeepCollectionEquality().equals(other._aliases, _aliases) &&
            (identical(other.roleOrOccupation, roleOrOccupation) ||
                other.roleOrOccupation == roleOrOccupation) &&
            (identical(other.age, age) || other.age == age) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.appearanceSummary, appearanceSummary) ||
                other.appearanceSummary == appearanceSummary) &&
            (identical(other.personalitySummary, personalitySummary) ||
                other.personalitySummary == personalitySummary) &&
            (identical(other.speechStyle, speechStyle) ||
                other.speechStyle == speechStyle) &&
            (identical(other.motivation, motivation) ||
                other.motivation == motivation) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            const DeepCollectionEquality().equals(
              other._conflicts,
              _conflicts,
            ) &&
            (identical(other.valuesAndBeliefs, valuesAndBeliefs) ||
                other.valuesAndBeliefs == valuesAndBeliefs) &&
            (identical(other.fear, fear) || other.fear == fear) &&
            (identical(other.relationshipSummary, relationshipSummary) ||
                other.relationshipSummary == relationshipSummary) &&
            const DeepCollectionEquality().equals(
              other._relationships,
              _relationships,
            ) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.advanced, advanced) ||
                other.advanced == advanced) &&
            const DeepCollectionEquality().equals(
              other._customFields,
              _customFields,
            ) &&
            const DeepCollectionEquality().equals(
              other._legacyFields,
              _legacyFields,
            ) &&
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
    characterId,
    displayName,
    const DeepCollectionEquality().hash(_aliases),
    roleOrOccupation,
    age,
    gender,
    appearanceSummary,
    personalitySummary,
    speechStyle,
    motivation,
    goal,
    const DeepCollectionEquality().hash(_conflicts),
    valuesAndBeliefs,
    fear,
    relationshipSummary,
    const DeepCollectionEquality().hash(_relationships),
    notes,
    advanced,
    const DeepCollectionEquality().hash(_customFields),
    const DeepCollectionEquality().hash(_legacyFields),
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
    final String characterId,
    final String displayName,
    final List<CharacterAlias> aliases,
    final String roleOrOccupation,
    final String age,
    final String gender,
    final String appearanceSummary,
    final String personalitySummary,
    final String speechStyle,
    final String motivation,
    final String goal,
    final List<CharacterConflict> conflicts,
    final String valuesAndBeliefs,
    final String fear,
    final String relationshipSummary,
    final List<CharacterRelationship> relationships,
    final String notes,
    final CharacterAdvancedProfile advanced,
    final Map<String, CustomFieldValue> customFields,
    final Map<String, String> legacyFields,
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
  String get characterId;
  @override
  String get displayName;
  @override
  List<CharacterAlias> get aliases;
  @override
  String get roleOrOccupation;
  @override
  String get age;
  @override
  String get gender;
  @override
  String get appearanceSummary;
  @override
  String get personalitySummary;
  @override
  String get speechStyle;
  @override
  String get motivation;
  @override
  String get goal;
  @override
  List<CharacterConflict> get conflicts;
  @override
  String get valuesAndBeliefs;
  @override
  String get fear;
  @override
  String get relationshipSummary;
  @override
  List<CharacterRelationship> get relationships;
  @override
  String get notes;
  @override
  CharacterAdvancedProfile get advanced;
  @override
  Map<String, CustomFieldValue> get customFields;
  @override
  Map<String, String> get legacyFields;
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
