// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_sync_command_entity_native.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPendingSyncCommandEntityCollection on Isar {
  IsarCollection<PendingSyncCommandEntity> get pendingSyncCommandEntitys =>
      this.collection();
}

const PendingSyncCommandEntitySchema = CollectionSchema(
  name: r'PendingSyncCommandEntity',
  id: 5044675138016500576,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'ipEstufa': PropertySchema(
      id: 1,
      name: r'ipEstufa',
      type: IsarType.string,
    ),
    r'payloadJson': PropertySchema(
      id: 2,
      name: r'payloadJson',
      type: IsarType.string,
    ),
  },
  estimateSize: _pendingSyncCommandEntityEstimateSize,
  serialize: _pendingSyncCommandEntitySerialize,
  deserialize: _pendingSyncCommandEntityDeserialize,
  deserializeProp: _pendingSyncCommandEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ipEstufa': IndexSchema(
      id: 6742162026097778419,
      name: r'ipEstufa',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ipEstufa',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _pendingSyncCommandEntityGetId,
  getLinks: _pendingSyncCommandEntityGetLinks,
  attach: _pendingSyncCommandEntityAttach,
  version: '3.1.0+1',
);

int _pendingSyncCommandEntityEstimateSize(
  PendingSyncCommandEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.ipEstufa.length * 3;
  bytesCount += 3 + object.payloadJson.length * 3;
  return bytesCount;
}

void _pendingSyncCommandEntitySerialize(
  PendingSyncCommandEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.ipEstufa);
  writer.writeString(offsets[2], object.payloadJson);
}

PendingSyncCommandEntity _pendingSyncCommandEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PendingSyncCommandEntity();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.ipEstufa = reader.readString(offsets[1]);
  object.payloadJson = reader.readString(offsets[2]);
  return object;
}

P _pendingSyncCommandEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _pendingSyncCommandEntityGetId(PendingSyncCommandEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _pendingSyncCommandEntityGetLinks(
  PendingSyncCommandEntity object,
) {
  return [];
}

void _pendingSyncCommandEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  PendingSyncCommandEntity object,
) {
  object.id = id;
}

extension PendingSyncCommandEntityQueryWhereSort
    on
        QueryBuilder<
          PendingSyncCommandEntity,
          PendingSyncCommandEntity,
          QWhere
        > {
  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PendingSyncCommandEntityQueryWhere
    on
        QueryBuilder<
          PendingSyncCommandEntity,
          PendingSyncCommandEntity,
          QWhereClause
        > {
  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterWhereClause
  >
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterWhereClause
  >
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterWhereClause
  >
  ipEstufaEqualTo(String ipEstufa) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'ipEstufa', value: [ipEstufa]),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterWhereClause
  >
  ipEstufaNotEqualTo(String ipEstufa) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ipEstufa',
                lower: [],
                upper: [ipEstufa],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ipEstufa',
                lower: [ipEstufa],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ipEstufa',
                lower: [ipEstufa],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ipEstufa',
                lower: [],
                upper: [ipEstufa],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension PendingSyncCommandEntityQueryFilter
    on
        QueryBuilder<
          PendingSyncCommandEntity,
          PendingSyncCommandEntity,
          QFilterCondition
        > {
  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  ipEstufaEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ipEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  ipEstufaGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ipEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  ipEstufaLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ipEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  ipEstufaBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ipEstufa',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  ipEstufaStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ipEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  ipEstufaEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ipEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  ipEstufaContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ipEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  ipEstufaMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ipEstufa',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  ipEstufaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ipEstufa', value: ''),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  ipEstufaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ipEstufa', value: ''),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  payloadJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  payloadJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  payloadJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  payloadJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'payloadJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  payloadJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  payloadJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  payloadJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  payloadJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'payloadJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  payloadJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'payloadJson', value: ''),
      );
    });
  }

  QueryBuilder<
    PendingSyncCommandEntity,
    PendingSyncCommandEntity,
    QAfterFilterCondition
  >
  payloadJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'payloadJson', value: ''),
      );
    });
  }
}

extension PendingSyncCommandEntityQueryObject
    on
        QueryBuilder<
          PendingSyncCommandEntity,
          PendingSyncCommandEntity,
          QFilterCondition
        > {}

extension PendingSyncCommandEntityQueryLinks
    on
        QueryBuilder<
          PendingSyncCommandEntity,
          PendingSyncCommandEntity,
          QFilterCondition
        > {}

extension PendingSyncCommandEntityQuerySortBy
    on
        QueryBuilder<
          PendingSyncCommandEntity,
          PendingSyncCommandEntity,
          QSortBy
        > {
  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  sortByIpEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.asc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  sortByIpEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.desc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  sortByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  sortByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }
}

extension PendingSyncCommandEntityQuerySortThenBy
    on
        QueryBuilder<
          PendingSyncCommandEntity,
          PendingSyncCommandEntity,
          QSortThenBy
        > {
  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  thenByIpEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.asc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  thenByIpEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.desc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  thenByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QAfterSortBy>
  thenByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }
}

extension PendingSyncCommandEntityQueryWhereDistinct
    on
        QueryBuilder<
          PendingSyncCommandEntity,
          PendingSyncCommandEntity,
          QDistinct
        > {
  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QDistinct>
  distinctByIpEstufa({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ipEstufa', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PendingSyncCommandEntity, PendingSyncCommandEntity, QDistinct>
  distinctByPayloadJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payloadJson', caseSensitive: caseSensitive);
    });
  }
}

extension PendingSyncCommandEntityQueryProperty
    on
        QueryBuilder<
          PendingSyncCommandEntity,
          PendingSyncCommandEntity,
          QQueryProperty
        > {
  QueryBuilder<PendingSyncCommandEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PendingSyncCommandEntity, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<PendingSyncCommandEntity, String, QQueryOperations>
  ipEstufaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ipEstufa');
    });
  }

  QueryBuilder<PendingSyncCommandEntity, String, QQueryOperations>
  payloadJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payloadJson');
    });
  }
}
