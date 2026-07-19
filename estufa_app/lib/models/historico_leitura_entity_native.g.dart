// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'historico_leitura_entity_native.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetHistoricoLeituraEntityCollection on Isar {
  IsarCollection<HistoricoLeituraEntity> get historicoLeituraEntitys =>
      this.collection();
}

const HistoricoLeituraEntitySchema = CollectionSchema(
  name: r'HistoricoLeituraEntity',
  id: -1075977214329961243,
  properties: {
    r'alertaIncendio': PropertySchema(
      id: 0,
      name: r'alertaIncendio',
      type: IsarType.bool,
    ),
    r'aviso': PropertySchema(id: 1, name: r'aviso', type: IsarType.string),
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
    r'temperatura': PropertySchema(
      id: 4,
      name: r'temperatura',
      type: IsarType.double,
    ),
    r'temperaturaMeta': PropertySchema(
      id: 5,
      name: r'temperaturaMeta',
      type: IsarType.double,
    ),
    r'timestamp': PropertySchema(
      id: 6,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'umidade': PropertySchema(id: 7, name: r'umidade', type: IsarType.double),
    r'umidadeMeta': PropertySchema(
      id: 8,
      name: r'umidadeMeta',
      type: IsarType.double,
    ),
  },
  estimateSize: _historicoLeituraEntityEstimateSize,
  serialize: _historicoLeituraEntitySerialize,
  deserialize: _historicoLeituraEntityDeserialize,
  deserializeProp: _historicoLeituraEntityDeserializeProp,
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
  getId: _historicoLeituraEntityGetId,
  getLinks: _historicoLeituraEntityGetLinks,
  attach: _historicoLeituraEntityAttach,
  version: '3.1.0+1',
);

int _historicoLeituraEntityEstimateSize(
  HistoricoLeituraEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.aviso.length * 3;
  bytesCount += 3 + object.ipEstufa.length * 3;
  bytesCount += 3 + object.nomeEstufa.length * 3;
  return bytesCount;
}

void _historicoLeituraEntitySerialize(
  HistoricoLeituraEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.alertaIncendio);
  writer.writeString(offsets[1], object.aviso);
  writer.writeString(offsets[2], object.ipEstufa);
  writer.writeString(offsets[3], object.nomeEstufa);
  writer.writeDouble(offsets[4], object.temperatura);
  writer.writeDouble(offsets[5], object.temperaturaMeta);
  writer.writeDateTime(offsets[6], object.timestamp);
  writer.writeDouble(offsets[7], object.umidade);
  writer.writeDouble(offsets[8], object.umidadeMeta);
}

HistoricoLeituraEntity _historicoLeituraEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = HistoricoLeituraEntity();
  object.alertaIncendio = reader.readBool(offsets[0]);
  object.aviso = reader.readString(offsets[1]);
  object.id = id;
  object.ipEstufa = reader.readString(offsets[2]);
  object.nomeEstufa = reader.readString(offsets[3]);
  object.temperatura = reader.readDouble(offsets[4]);
  object.temperaturaMeta = reader.readDouble(offsets[5]);
  object.timestamp = reader.readDateTime(offsets[6]);
  object.umidade = reader.readDouble(offsets[7]);
  object.umidadeMeta = reader.readDouble(offsets[8]);
  return object;
}

P _historicoLeituraEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDouble(offset)) as P;
    case 5:
      return (reader.readDouble(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _historicoLeituraEntityGetId(HistoricoLeituraEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _historicoLeituraEntityGetLinks(
  HistoricoLeituraEntity object,
) {
  return [];
}

void _historicoLeituraEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  HistoricoLeituraEntity object,
) {
  object.id = id;
}

extension HistoricoLeituraEntityQueryWhereSort
    on QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QWhere> {
  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension HistoricoLeituraEntityQueryWhere
    on
        QueryBuilder<
          HistoricoLeituraEntity,
          HistoricoLeituraEntity,
          QWhereClause
        > {
  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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

extension HistoricoLeituraEntityQueryFilter
    on
        QueryBuilder<
          HistoricoLeituraEntity,
          HistoricoLeituraEntity,
          QFilterCondition
        > {
  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  alertaIncendioEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'alertaIncendio', value: value),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  avisoEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'aviso',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  avisoGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'aviso',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  avisoLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'aviso',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  avisoBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'aviso',
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  avisoStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'aviso',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  avisoEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'aviso',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  avisoContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'aviso',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  avisoMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'aviso',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  avisoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'aviso', value: ''),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  avisoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'aviso', value: ''),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
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
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  nomeEstufaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nomeEstufa', value: ''),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  nomeEstufaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'nomeEstufa', value: ''),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  temperaturaEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'temperatura',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  temperaturaGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'temperatura',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  temperaturaLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'temperatura',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  temperaturaBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'temperatura',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  temperaturaMetaEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'temperaturaMeta',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  temperaturaMetaGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'temperaturaMeta',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  temperaturaMetaLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'temperaturaMeta',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  temperaturaMetaBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'temperaturaMeta',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  umidadeEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'umidade',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  umidadeGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'umidade',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  umidadeLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'umidade',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  umidadeBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'umidade',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  umidadeMetaEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'umidadeMeta',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  umidadeMetaGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'umidadeMeta',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  umidadeMetaLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'umidadeMeta',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HistoricoLeituraEntity,
    HistoricoLeituraEntity,
    QAfterFilterCondition
  >
  umidadeMetaBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'umidadeMeta',
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

extension HistoricoLeituraEntityQueryObject
    on
        QueryBuilder<
          HistoricoLeituraEntity,
          HistoricoLeituraEntity,
          QFilterCondition
        > {}

extension HistoricoLeituraEntityQueryLinks
    on
        QueryBuilder<
          HistoricoLeituraEntity,
          HistoricoLeituraEntity,
          QFilterCondition
        > {}

extension HistoricoLeituraEntityQuerySortBy
    on QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QSortBy> {
  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByAlertaIncendio() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alertaIncendio', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByAlertaIncendioDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alertaIncendio', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByAviso() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aviso', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByAvisoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aviso', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByIpEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByIpEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByNomeEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByNomeEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByTemperatura() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'temperatura', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByTemperaturaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'temperatura', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByTemperaturaMeta() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'temperaturaMeta', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByTemperaturaMetaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'temperaturaMeta', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByUmidade() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'umidade', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByUmidadeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'umidade', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByUmidadeMeta() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'umidadeMeta', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  sortByUmidadeMetaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'umidadeMeta', Sort.desc);
    });
  }
}

extension HistoricoLeituraEntityQuerySortThenBy
    on
        QueryBuilder<
          HistoricoLeituraEntity,
          HistoricoLeituraEntity,
          QSortThenBy
        > {
  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByAlertaIncendio() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alertaIncendio', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByAlertaIncendioDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alertaIncendio', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByAviso() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aviso', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByAvisoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aviso', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByIpEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByIpEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByNomeEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByNomeEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByTemperatura() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'temperatura', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByTemperaturaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'temperatura', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByTemperaturaMeta() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'temperaturaMeta', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByTemperaturaMetaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'temperaturaMeta', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByUmidade() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'umidade', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByUmidadeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'umidade', Sort.desc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByUmidadeMeta() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'umidadeMeta', Sort.asc);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QAfterSortBy>
  thenByUmidadeMetaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'umidadeMeta', Sort.desc);
    });
  }
}

extension HistoricoLeituraEntityQueryWhereDistinct
    on QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QDistinct> {
  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QDistinct>
  distinctByAlertaIncendio() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'alertaIncendio');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QDistinct>
  distinctByAviso({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aviso', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QDistinct>
  distinctByIpEstufa({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ipEstufa', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QDistinct>
  distinctByNomeEstufa({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nomeEstufa', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QDistinct>
  distinctByTemperatura() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'temperatura');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QDistinct>
  distinctByTemperaturaMeta() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'temperaturaMeta');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QDistinct>
  distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QDistinct>
  distinctByUmidade() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'umidade');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, HistoricoLeituraEntity, QDistinct>
  distinctByUmidadeMeta() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'umidadeMeta');
    });
  }
}

extension HistoricoLeituraEntityQueryProperty
    on
        QueryBuilder<
          HistoricoLeituraEntity,
          HistoricoLeituraEntity,
          QQueryProperty
        > {
  QueryBuilder<HistoricoLeituraEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, bool, QQueryOperations>
  alertaIncendioProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'alertaIncendio');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, String, QQueryOperations>
  avisoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aviso');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, String, QQueryOperations>
  ipEstufaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ipEstufa');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, String, QQueryOperations>
  nomeEstufaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nomeEstufa');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, double, QQueryOperations>
  temperaturaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'temperatura');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, double, QQueryOperations>
  temperaturaMetaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'temperaturaMeta');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, DateTime, QQueryOperations>
  timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, double, QQueryOperations>
  umidadeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'umidade');
    });
  }

  QueryBuilder<HistoricoLeituraEntity, double, QQueryOperations>
  umidadeMetaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'umidadeMeta');
    });
  }
}
