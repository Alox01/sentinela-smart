// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evento_ciclo_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEventoCicloEntityCollection on Isar {
  IsarCollection<EventoCicloEntity> get eventoCicloEntitys => this.collection();
}

const EventoCicloEntitySchema = CollectionSchema(
  name: r'EventoCicloEntity',
  id: 4964800623692747,
  properties: {
    r'cicloId': PropertySchema(id: 0, name: r'cicloId', type: IsarType.long),
    r'descricao': PropertySchema(
      id: 1,
      name: r'descricao',
      type: IsarType.string,
    ),
    r'ipEstufa': PropertySchema(
      id: 2,
      name: r'ipEstufa',
      type: IsarType.string,
    ),
    r'nomeEstufa': PropertySchema(
      id: 3,
      name: r'nomeEstufa',
      type: IsarType.string,
    ),
    r'severidade': PropertySchema(
      id: 4,
      name: r'severidade',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 5,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'tipo': PropertySchema(id: 6, name: r'tipo', type: IsarType.string),
    r'valorAnterior': PropertySchema(
      id: 7,
      name: r'valorAnterior',
      type: IsarType.double,
    ),
    r'valorAtual': PropertySchema(
      id: 8,
      name: r'valorAtual',
      type: IsarType.double,
    ),
  },
  estimateSize: _eventoCicloEntityEstimateSize,
  serialize: _eventoCicloEntitySerialize,
  deserialize: _eventoCicloEntityDeserialize,
  deserializeProp: _eventoCicloEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ipEstufa': IndexSchema(
      id: 6742162026097778,
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
    r'cicloId': IndexSchema(
      id: 7604226280865895,
      name: r'cicloId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cicloId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _eventoCicloEntityGetId,
  getLinks: _eventoCicloEntityGetLinks,
  attach: _eventoCicloEntityAttach,
  version: '3.1.0+1',
);

int _eventoCicloEntityEstimateSize(
  EventoCicloEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.descricao.length * 3;
  bytesCount += 3 + object.ipEstufa.length * 3;
  bytesCount += 3 + object.nomeEstufa.length * 3;
  bytesCount += 3 + object.severidade.length * 3;
  bytesCount += 3 + object.tipo.length * 3;
  return bytesCount;
}

void _eventoCicloEntitySerialize(
  EventoCicloEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.cicloId);
  writer.writeString(offsets[1], object.descricao);
  writer.writeString(offsets[2], object.ipEstufa);
  writer.writeString(offsets[3], object.nomeEstufa);
  writer.writeString(offsets[4], object.severidade);
  writer.writeDateTime(offsets[5], object.timestamp);
  writer.writeString(offsets[6], object.tipo);
  writer.writeDouble(offsets[7], object.valorAnterior);
  writer.writeDouble(offsets[8], object.valorAtual);
}

EventoCicloEntity _eventoCicloEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EventoCicloEntity();
  object.cicloId = reader.readLong(offsets[0]);
  object.descricao = reader.readString(offsets[1]);
  object.id = id;
  object.ipEstufa = reader.readString(offsets[2]);
  object.nomeEstufa = reader.readString(offsets[3]);
  object.severidade = reader.readString(offsets[4]);
  object.timestamp = reader.readDateTime(offsets[5]);
  object.tipo = reader.readString(offsets[6]);
  object.valorAnterior = reader.readDoubleOrNull(offsets[7]);
  object.valorAtual = reader.readDoubleOrNull(offsets[8]);
  return object;
}

P _eventoCicloEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readDoubleOrNull(offset)) as P;
    case 8:
      return (reader.readDoubleOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _eventoCicloEntityGetId(EventoCicloEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _eventoCicloEntityGetLinks(
  EventoCicloEntity object,
) {
  return [];
}

void _eventoCicloEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  EventoCicloEntity object,
) {
  object.id = id;
}

extension EventoCicloEntityQueryWhereSort
    on QueryBuilder<EventoCicloEntity, EventoCicloEntity, QWhere> {
  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhere> anyCicloId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'cicloId'),
      );
    });
  }
}

extension EventoCicloEntityQueryWhere
    on QueryBuilder<EventoCicloEntity, EventoCicloEntity, QWhereClause> {
  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
  ipEstufaEqualTo(String ipEstufa) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'ipEstufa', value: [ipEstufa]),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
  cicloIdEqualTo(int cicloId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cicloId', value: [cicloId]),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
  cicloIdNotEqualTo(int cicloId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cicloId',
                lower: [],
                upper: [cicloId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cicloId',
                lower: [cicloId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cicloId',
                lower: [cicloId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cicloId',
                lower: [],
                upper: [cicloId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
  cicloIdGreaterThan(int cicloId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cicloId',
          lower: [cicloId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
  cicloIdLessThan(int cicloId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cicloId',
          lower: [],
          upper: [cicloId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterWhereClause>
  cicloIdBetween(
    int lowerCicloId,
    int upperCicloId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cicloId',
          lower: [lowerCicloId],
          includeLower: includeLower,
          upper: [upperCicloId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension EventoCicloEntityQueryFilter
    on QueryBuilder<EventoCicloEntity, EventoCicloEntity, QFilterCondition> {
  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  cicloIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cicloId', value: value),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  cicloIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cicloId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  cicloIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cicloId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  cicloIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cicloId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  descricaoEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'descricao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  descricaoGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'descricao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  descricaoLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'descricao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  descricaoBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'descricao',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  descricaoStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'descricao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  descricaoEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'descricao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  descricaoContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'descricao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  descricaoMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'descricao',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  descricaoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'descricao', value: ''),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  descricaoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'descricao', value: ''),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
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

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  ipEstufaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ipEstufa', value: ''),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  ipEstufaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ipEstufa', value: ''),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  nomeEstufaEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nomeEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  nomeEstufaGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nomeEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  nomeEstufaLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nomeEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  nomeEstufaBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nomeEstufa',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  nomeEstufaStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'nomeEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  nomeEstufaEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'nomeEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  nomeEstufaContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'nomeEstufa',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  nomeEstufaMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'nomeEstufa',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  nomeEstufaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nomeEstufa', value: ''),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  nomeEstufaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'nomeEstufa', value: ''),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  severidadeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'severidade',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  severidadeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'severidade',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  severidadeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'severidade',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  severidadeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'severidade',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  severidadeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'severidade',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  severidadeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'severidade',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  severidadeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'severidade',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  severidadeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'severidade',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  severidadeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'severidade', value: ''),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  severidadeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'severidade', value: ''),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  timestampGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  timestampLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'timestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  tipoEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tipo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  tipoGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tipo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  tipoLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tipo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  tipoBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tipo',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  tipoStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tipo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  tipoEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tipo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  tipoContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tipo',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  tipoMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tipo',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  tipoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tipo', value: ''),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  tipoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tipo', value: ''),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAnteriorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'valorAnterior'),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAnteriorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'valorAnterior'),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAnteriorEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'valorAnterior',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAnteriorGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'valorAnterior',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAnteriorLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'valorAnterior',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAnteriorBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'valorAnterior',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAtualIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'valorAtual'),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAtualIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'valorAtual'),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAtualEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'valorAtual',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAtualGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'valorAtual',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAtualLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'valorAtual',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterFilterCondition>
  valorAtualBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'valorAtual',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }
}

extension EventoCicloEntityQueryObject
    on QueryBuilder<EventoCicloEntity, EventoCicloEntity, QFilterCondition> {}

extension EventoCicloEntityQueryLinks
    on QueryBuilder<EventoCicloEntity, EventoCicloEntity, QFilterCondition> {}

extension EventoCicloEntityQuerySortBy
    on QueryBuilder<EventoCicloEntity, EventoCicloEntity, QSortBy> {
  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByCicloId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cicloId', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByCicloIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cicloId', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByDescricao() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByDescricaoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByIpEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByIpEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByNomeEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByNomeEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortBySeveridade() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severidade', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortBySeveridadeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severidade', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByTipo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tipo', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByTipoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tipo', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByValorAnterior() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valorAnterior', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByValorAnteriorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valorAnterior', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByValorAtual() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valorAtual', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  sortByValorAtualDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valorAtual', Sort.desc);
    });
  }
}

extension EventoCicloEntityQuerySortThenBy
    on QueryBuilder<EventoCicloEntity, EventoCicloEntity, QSortThenBy> {
  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByCicloId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cicloId', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByCicloIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cicloId', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByDescricao() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByDescricaoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByIpEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByIpEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByNomeEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByNomeEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenBySeveridade() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severidade', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenBySeveridadeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severidade', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByTipo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tipo', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByTipoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tipo', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByValorAnterior() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valorAnterior', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByValorAnteriorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valorAnterior', Sort.desc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByValorAtual() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valorAtual', Sort.asc);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QAfterSortBy>
  thenByValorAtualDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valorAtual', Sort.desc);
    });
  }
}

extension EventoCicloEntityQueryWhereDistinct
    on QueryBuilder<EventoCicloEntity, EventoCicloEntity, QDistinct> {
  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QDistinct>
  distinctByCicloId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cicloId');
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QDistinct>
  distinctByDescricao({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'descricao', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QDistinct>
  distinctByIpEstufa({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ipEstufa', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QDistinct>
  distinctByNomeEstufa({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nomeEstufa', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QDistinct>
  distinctBySeveridade({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'severidade', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QDistinct>
  distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QDistinct> distinctByTipo({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tipo', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QDistinct>
  distinctByValorAnterior() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'valorAnterior');
    });
  }

  QueryBuilder<EventoCicloEntity, EventoCicloEntity, QDistinct>
  distinctByValorAtual() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'valorAtual');
    });
  }
}

extension EventoCicloEntityQueryProperty
    on QueryBuilder<EventoCicloEntity, EventoCicloEntity, QQueryProperty> {
  QueryBuilder<EventoCicloEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<EventoCicloEntity, int, QQueryOperations> cicloIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cicloId');
    });
  }

  QueryBuilder<EventoCicloEntity, String, QQueryOperations>
  descricaoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'descricao');
    });
  }

  QueryBuilder<EventoCicloEntity, String, QQueryOperations> ipEstufaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ipEstufa');
    });
  }

  QueryBuilder<EventoCicloEntity, String, QQueryOperations>
  nomeEstufaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nomeEstufa');
    });
  }

  QueryBuilder<EventoCicloEntity, String, QQueryOperations>
  severidadeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'severidade');
    });
  }

  QueryBuilder<EventoCicloEntity, DateTime, QQueryOperations>
  timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<EventoCicloEntity, String, QQueryOperations> tipoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tipo');
    });
  }

  QueryBuilder<EventoCicloEntity, double?, QQueryOperations>
  valorAnteriorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'valorAnterior');
    });
  }

  QueryBuilder<EventoCicloEntity, double?, QQueryOperations>
  valorAtualProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'valorAtual');
    });
  }
}
