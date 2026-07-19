// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ciclo_secagem_entity_native.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCicloSecagemEntityCollection on Isar {
  IsarCollection<CicloSecagemEntity> get cicloSecagemEntitys =>
      this.collection();
}

const CicloSecagemEntitySchema = CollectionSchema(
  name: r'CicloSecagemEntity',
  id: -1999433397147366231,
  properties: {
    r'fim': PropertySchema(id: 0, name: r'fim', type: IsarType.dateTime),
    r'inicio': PropertySchema(id: 1, name: r'inicio', type: IsarType.dateTime),
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
    r'observacao': PropertySchema(
      id: 4,
      name: r'observacao',
      type: IsarType.string,
    ),
    r'status': PropertySchema(id: 5, name: r'status', type: IsarType.string),
  },
  estimateSize: _cicloSecagemEntityEstimateSize,
  serialize: _cicloSecagemEntitySerialize,
  deserialize: _cicloSecagemEntityDeserialize,
  deserializeProp: _cicloSecagemEntityDeserializeProp,
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
  getId: _cicloSecagemEntityGetId,
  getLinks: _cicloSecagemEntityGetLinks,
  attach: _cicloSecagemEntityAttach,
  version: '3.1.0+1',
);

int _cicloSecagemEntityEstimateSize(
  CicloSecagemEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.ipEstufa.length * 3;
  bytesCount += 3 + object.nomeEstufa.length * 3;
  bytesCount += 3 + object.observacao.length * 3;
  bytesCount += 3 + object.status.length * 3;
  return bytesCount;
}

void _cicloSecagemEntitySerialize(
  CicloSecagemEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.fim);
  writer.writeDateTime(offsets[1], object.inicio);
  writer.writeString(offsets[2], object.ipEstufa);
  writer.writeString(offsets[3], object.nomeEstufa);
  writer.writeString(offsets[4], object.observacao);
  writer.writeString(offsets[5], object.status);
}

CicloSecagemEntity _cicloSecagemEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CicloSecagemEntity();
  object.fim = reader.readDateTimeOrNull(offsets[0]);
  object.id = id;
  object.inicio = reader.readDateTime(offsets[1]);
  object.ipEstufa = reader.readString(offsets[2]);
  object.nomeEstufa = reader.readString(offsets[3]);
  object.observacao = reader.readString(offsets[4]);
  object.status = reader.readString(offsets[5]);
  return object;
}

P _cicloSecagemEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _cicloSecagemEntityGetId(CicloSecagemEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _cicloSecagemEntityGetLinks(
  CicloSecagemEntity object,
) {
  return [];
}

void _cicloSecagemEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  CicloSecagemEntity object,
) {
  object.id = id;
}

extension CicloSecagemEntityQueryWhereSort
    on QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QWhere> {
  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CicloSecagemEntityQueryWhere
    on QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QWhereClause> {
  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterWhereClause>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterWhereClause>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterWhereClause>
  ipEstufaEqualTo(String ipEstufa) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'ipEstufa', value: [ipEstufa]),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterWhereClause>
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

extension CicloSecagemEntityQueryFilter
    on QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QFilterCondition> {
  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  fimIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fim'),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  fimIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fim'),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  fimEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fim', value: value),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  fimGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fim',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  fimLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fim',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  fimBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fim',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  inicioEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'inicio', value: value),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  inicioGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'inicio',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  inicioLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'inicio',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  inicioBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'inicio',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  ipEstufaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ipEstufa', value: ''),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  ipEstufaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ipEstufa', value: ''),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
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

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  nomeEstufaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nomeEstufa', value: ''),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  nomeEstufaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'nomeEstufa', value: ''),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  observacaoEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'observacao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  observacaoGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'observacao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  observacaoLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'observacao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  observacaoBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'observacao',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  observacaoStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'observacao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  observacaoEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'observacao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  observacaoContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'observacao',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  observacaoMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'observacao',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  observacaoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'observacao', value: ''),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  observacaoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'observacao', value: ''),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  statusEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  statusStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  statusEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'status',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterFilterCondition>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }
}

extension CicloSecagemEntityQueryObject
    on QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QFilterCondition> {}

extension CicloSecagemEntityQueryLinks
    on QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QFilterCondition> {}

extension CicloSecagemEntityQuerySortBy
    on QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QSortBy> {
  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByFim() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fim', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByFimDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fim', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByInicio() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inicio', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByInicioDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inicio', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByIpEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByIpEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByNomeEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByNomeEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByObservacao() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observacao', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByObservacaoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observacao', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension CicloSecagemEntityQuerySortThenBy
    on QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QSortThenBy> {
  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByFim() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fim', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByFimDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fim', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByInicio() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inicio', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByInicioDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inicio', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByIpEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByIpEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ipEstufa', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByNomeEstufa() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByNomeEstufaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nomeEstufa', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByObservacao() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observacao', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByObservacaoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observacao', Sort.desc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QAfterSortBy>
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension CicloSecagemEntityQueryWhereDistinct
    on QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QDistinct> {
  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QDistinct>
  distinctByFim() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fim');
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QDistinct>
  distinctByInicio() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'inicio');
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QDistinct>
  distinctByIpEstufa({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ipEstufa', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QDistinct>
  distinctByNomeEstufa({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nomeEstufa', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QDistinct>
  distinctByObservacao({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'observacao', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QDistinct>
  distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }
}

extension CicloSecagemEntityQueryProperty
    on QueryBuilder<CicloSecagemEntity, CicloSecagemEntity, QQueryProperty> {
  QueryBuilder<CicloSecagemEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CicloSecagemEntity, DateTime?, QQueryOperations> fimProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fim');
    });
  }

  QueryBuilder<CicloSecagemEntity, DateTime, QQueryOperations>
  inicioProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inicio');
    });
  }

  QueryBuilder<CicloSecagemEntity, String, QQueryOperations>
  ipEstufaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ipEstufa');
    });
  }

  QueryBuilder<CicloSecagemEntity, String, QQueryOperations>
  nomeEstufaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nomeEstufa');
    });
  }

  QueryBuilder<CicloSecagemEntity, String, QQueryOperations>
  observacaoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'observacao');
    });
  }

  QueryBuilder<CicloSecagemEntity, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }
}
