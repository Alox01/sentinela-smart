// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'estufa_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEstufaEntityCollection on Isar {
  IsarCollection<EstufaEntity> get estufaEntitys => this.collection();
}

const EstufaEntitySchema = CollectionSchema(
  name: r'EstufaEntity',
  id: 4053660982038359951,
  properties: {
    r'chave': PropertySchema(
      id: 0,
      name: r'chave',
      type: IsarType.string,
    ),
    r'criadaEm': PropertySchema(
      id: 1,
      name: r'criadaEm',
      type: IsarType.dateTime,
    ),
    r'ip': PropertySchema(
      id: 2,
      name: r'ip',
      type: IsarType.string,
    ),
    r'nome': PropertySchema(
      id: 3,
      name: r'nome',
      type: IsarType.string,
    ),
    r'tokenAcesso': PropertySchema(
      id: 4,
      name: r'tokenAcesso',
      type: IsarType.string,
    )
  },
  estimateSize: _estufaEntityEstimateSize,
  serialize: _estufaEntitySerialize,
  deserialize: _estufaEntityDeserialize,
  deserializeProp: _estufaEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'chave': IndexSchema(
      id: -6375079618054803693,
      name: r'chave',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'chave',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _estufaEntityGetId,
  getLinks: _estufaEntityGetLinks,
  attach: _estufaEntityAttach,
  version: '3.1.0+1',
);

int _estufaEntityEstimateSize(
  EstufaEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.chave.length * 3;
  bytesCount += 3 + object.ip.length * 3;
  bytesCount += 3 + object.nome.length * 3;
  {
    final value = object.tokenAcesso;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _estufaEntitySerialize(
  EstufaEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.chave);
  writer.writeDateTime(offsets[1], object.criadaEm);
  writer.writeString(offsets[2], object.ip);
  writer.writeString(offsets[3], object.nome);
  writer.writeString(offsets[4], object.tokenAcesso);
}

EstufaEntity _estufaEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EstufaEntity();
  object.chave = reader.readString(offsets[0]);
  object.criadaEm = reader.readDateTime(offsets[1]);
  object.id = id;
  object.ip = reader.readString(offsets[2]);
  object.nome = reader.readString(offsets[3]);
  object.tokenAcesso = reader.readStringOrNull(offsets[4]);
  return object;
}

P _estufaEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _estufaEntityGetId(EstufaEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _estufaEntityGetLinks(EstufaEntity object) {
  return [];
}

void _estufaEntityAttach(
    IsarCollection<dynamic> col, Id id, EstufaEntity object) {
  object.id = id;
}

extension EstufaEntityByIndex on IsarCollection<EstufaEntity> {
  Future<EstufaEntity?> getByChave(String chave) {
    return getByIndex(r'chave', [chave]);
  }

  EstufaEntity? getByChaveSync(String chave) {
    return getByIndexSync(r'chave', [chave]);
  }

  Future<bool> deleteByChave(String chave) {
    return deleteByIndex(r'chave', [chave]);
  }

  bool deleteByChaveSync(String chave) {
    return deleteByIndexSync(r'chave', [chave]);
  }

  Future<List<EstufaEntity?>> getAllByChave(List<String> chaveValues) {
    final values = chaveValues.map((e) => [e]).toList();
    return getAllByIndex(r'chave', values);
  }

  List<EstufaEntity?> getAllByChaveSync(List<String> chaveValues) {
    final values = chaveValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'chave', values);
  }

  Future<int> deleteAllByChave(List<String> chaveValues) {
    final values = chaveValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'chave', values);
  }

  int deleteAllByChaveSync(List<String> chaveValues) {
    final values = chaveValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'chave', values);
  }

  Future<Id> putByChave(EstufaEntity object) {
    return putByIndex(r'chave', object);
  }

  Id putByChaveSync(EstufaEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'chave', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByChave(List<EstufaEntity> objects) {
    return putAllByIndex(r'chave', objects);
  }

  List<Id> putAllByChaveSync(List<EstufaEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'chave', objects, saveLinks: saveLinks);
  }
}

extension EstufaEntityQueryWhereSort
    on QueryBuilder<EstufaEntity, EstufaEntity, QWhere> {
  QueryBuilder<EstufaEntity, EstufaEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension EstufaEntityQueryWhere
    on QueryBuilder<EstufaEntity, EstufaEntity, QWhereClause> {
  QueryBuilder<EstufaEntity, EstufaEntity, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterWhereClause> chaveEqualTo(
      String chave) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'chave',
        value: [chave],
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterWhereClause> chaveNotEqualTo(
      String chave) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chave',
              lower: [],
              upper: [chave],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chave',
              lower: [chave],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chave',
              lower: [chave],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chave',
              lower: [],
              upper: [chave],
              includeUpper: false,
            ));
      }
    });
  }
}

extension EstufaEntityQueryFilter
    on QueryBuilder<EstufaEntity, EstufaEntity, QFilterCondition> {
  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> chaveEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chave',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      chaveGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chave',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> chaveLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chave',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> chaveBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chave',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      chaveStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'chave',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> chaveEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'chave',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> chaveContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chave',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> chaveMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chave',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      chaveIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chave',
        value: '',
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      chaveIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chave',
        value: '',
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      criadaEmEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'criadaEm',
        value: value,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      criadaEmGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'criadaEm',
        value: value,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      criadaEmLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'criadaEm',
        value: value,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      criadaEmBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'criadaEm',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> ipEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ip',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> ipGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ip',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> ipLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ip',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> ipBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ip',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> ipStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ip',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> ipEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ip',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> ipContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ip',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> ipMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ip',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> ipIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ip',
        value: '',
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      ipIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ip',
        value: '',
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> nomeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      nomeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> nomeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> nomeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nome',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      nomeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> nomeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> nomeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition> nomeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'nome',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      nomeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nome',
        value: '',
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      nomeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'nome',
        value: '',
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'tokenAcesso',
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'tokenAcesso',
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tokenAcesso',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tokenAcesso',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tokenAcesso',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tokenAcesso',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tokenAcesso',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tokenAcesso',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tokenAcesso',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tokenAcesso',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tokenAcesso',
        value: '',
      ));
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterFilterCondition>
      tokenAcessoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tokenAcesso',
        value: '',
      ));
    });
  }
}

extension EstufaEntityQueryObject
    on QueryBuilder<EstufaEntity, EstufaEntity, QFilterCondition> {}

extension EstufaEntityQueryLinks
    on QueryBuilder<EstufaEntity, EstufaEntity, QFilterCondition> {}

extension EstufaEntityQuerySortBy
    on QueryBuilder<EstufaEntity, EstufaEntity, QSortBy> {
  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> sortByChave() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chave', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> sortByChaveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chave', Sort.desc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> sortByCriadaEm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criadaEm', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> sortByCriadaEmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criadaEm', Sort.desc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> sortByIp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ip', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> sortByIpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ip', Sort.desc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> sortByNome() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nome', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> sortByNomeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nome', Sort.desc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> sortByTokenAcesso() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tokenAcesso', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy>
      sortByTokenAcessoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tokenAcesso', Sort.desc);
    });
  }
}

extension EstufaEntityQuerySortThenBy
    on QueryBuilder<EstufaEntity, EstufaEntity, QSortThenBy> {
  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenByChave() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chave', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenByChaveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chave', Sort.desc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenByCriadaEm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criadaEm', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenByCriadaEmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'criadaEm', Sort.desc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenByIp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ip', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenByIpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ip', Sort.desc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenByNome() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nome', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenByNomeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nome', Sort.desc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy> thenByTokenAcesso() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tokenAcesso', Sort.asc);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QAfterSortBy>
      thenByTokenAcessoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tokenAcesso', Sort.desc);
    });
  }
}

extension EstufaEntityQueryWhereDistinct
    on QueryBuilder<EstufaEntity, EstufaEntity, QDistinct> {
  QueryBuilder<EstufaEntity, EstufaEntity, QDistinct> distinctByChave(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chave', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QDistinct> distinctByCriadaEm() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'criadaEm');
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QDistinct> distinctByIp(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ip', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QDistinct> distinctByNome(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nome', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EstufaEntity, EstufaEntity, QDistinct> distinctByTokenAcesso(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tokenAcesso', caseSensitive: caseSensitive);
    });
  }
}

extension EstufaEntityQueryProperty
    on QueryBuilder<EstufaEntity, EstufaEntity, QQueryProperty> {
  QueryBuilder<EstufaEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<EstufaEntity, String, QQueryOperations> chaveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chave');
    });
  }

  QueryBuilder<EstufaEntity, DateTime, QQueryOperations> criadaEmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'criadaEm');
    });
  }

  QueryBuilder<EstufaEntity, String, QQueryOperations> ipProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ip');
    });
  }

  QueryBuilder<EstufaEntity, String, QQueryOperations> nomeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nome');
    });
  }

  QueryBuilder<EstufaEntity, String?, QQueryOperations> tokenAcessoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tokenAcesso');
    });
  }
}
