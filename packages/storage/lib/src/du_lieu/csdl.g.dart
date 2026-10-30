// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'csdl.dart';

// ignore_for_file: type=lint
class $DiemTable extends Diem with TableInfo<$DiemTable, DongDiem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiemTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenMeta = const VerificationMeta('ten');
  @override
  late final GeneratedColumn<String> ten = GeneratedColumn<String>(
    'ten',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viDoMeta = const VerificationMeta('viDo');
  @override
  late final GeneratedColumn<double> viDo = GeneratedColumn<double>(
    'vi_do',
    aliasedName,
    false,
    check: () => ComparableExpr(viDo).isBetweenValues(-90, 90),
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kinhDoMeta = const VerificationMeta('kinhDo');
  @override
  late final GeneratedColumn<double> kinhDo = GeneratedColumn<double>(
    'kinh_do',
    aliasedName,
    false,
    check: () => ComparableExpr(kinhDo).isBetweenValues(-180, 180),
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caoDoMeta = const VerificationMeta('caoDo');
  @override
  late final GeneratedColumn<double> caoDo = GeneratedColumn<double>(
    'cao_do',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ghiChuMeta = const VerificationMeta('ghiChu');
  @override
  late final GeneratedColumn<String> ghiChu = GeneratedColumn<String>(
    'ghi_chu',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _taoLucMeta = const VerificationMeta('taoLuc');
  @override
  late final GeneratedColumn<int> taoLuc = GeneratedColumn<int>(
    'tao_luc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _suaLucMeta = const VerificationMeta('suaLuc');
  @override
  late final GeneratedColumn<int> suaLuc = GeneratedColumn<int>(
    'sua_luc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ten,
    viDo,
    kinhDo,
    caoDo,
    ghiChu,
    taoLuc,
    suaLuc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diem';
  @override
  VerificationContext validateIntegrity(
    Insertable<DongDiem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ten')) {
      context.handle(
        _tenMeta,
        ten.isAcceptableOrUnknown(data['ten']!, _tenMeta),
      );
    } else if (isInserting) {
      context.missing(_tenMeta);
    }
    if (data.containsKey('vi_do')) {
      context.handle(
        _viDoMeta,
        viDo.isAcceptableOrUnknown(data['vi_do']!, _viDoMeta),
      );
    } else if (isInserting) {
      context.missing(_viDoMeta);
    }
    if (data.containsKey('kinh_do')) {
      context.handle(
        _kinhDoMeta,
        kinhDo.isAcceptableOrUnknown(data['kinh_do']!, _kinhDoMeta),
      );
    } else if (isInserting) {
      context.missing(_kinhDoMeta);
    }
    if (data.containsKey('cao_do')) {
      context.handle(
        _caoDoMeta,
        caoDo.isAcceptableOrUnknown(data['cao_do']!, _caoDoMeta),
      );
    }
    if (data.containsKey('ghi_chu')) {
      context.handle(
        _ghiChuMeta,
        ghiChu.isAcceptableOrUnknown(data['ghi_chu']!, _ghiChuMeta),
      );
    }
    if (data.containsKey('tao_luc')) {
      context.handle(
        _taoLucMeta,
        taoLuc.isAcceptableOrUnknown(data['tao_luc']!, _taoLucMeta),
      );
    } else if (isInserting) {
      context.missing(_taoLucMeta);
    }
    if (data.containsKey('sua_luc')) {
      context.handle(
        _suaLucMeta,
        suaLuc.isAcceptableOrUnknown(data['sua_luc']!, _suaLucMeta),
      );
    } else if (isInserting) {
      context.missing(_suaLucMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DongDiem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DongDiem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ten: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ten'],
      )!,
      viDo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vi_do'],
      )!,
      kinhDo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kinh_do'],
      )!,
      caoDo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cao_do'],
      ),
      ghiChu: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ghi_chu'],
      )!,
      taoLuc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tao_luc'],
      )!,
      suaLuc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sua_luc'],
      )!,
    );
  }

  @override
  $DiemTable createAlias(String alias) {
    return $DiemTable(attachedDatabase, alias);
  }
}

class DongDiem extends DataClass implements Insertable<DongDiem> {
  final String id;
  final String ten;
  final double viDo;
  final double kinhDo;
  final double? caoDo;
  final String ghiChu;

  /// Mốc thời gian UTC, mili giây.
  final int taoLuc;
  final int suaLuc;
  const DongDiem({
    required this.id,
    required this.ten,
    required this.viDo,
    required this.kinhDo,
    this.caoDo,
    required this.ghiChu,
    required this.taoLuc,
    required this.suaLuc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ten'] = Variable<String>(ten);
    map['vi_do'] = Variable<double>(viDo);
    map['kinh_do'] = Variable<double>(kinhDo);
    if (!nullToAbsent || caoDo != null) {
      map['cao_do'] = Variable<double>(caoDo);
    }
    map['ghi_chu'] = Variable<String>(ghiChu);
    map['tao_luc'] = Variable<int>(taoLuc);
    map['sua_luc'] = Variable<int>(suaLuc);
    return map;
  }

  DiemCompanion toCompanion(bool nullToAbsent) {
    return DiemCompanion(
      id: Value(id),
      ten: Value(ten),
      viDo: Value(viDo),
      kinhDo: Value(kinhDo),
      caoDo: caoDo == null && nullToAbsent
          ? const Value.absent()
          : Value(caoDo),
      ghiChu: Value(ghiChu),
      taoLuc: Value(taoLuc),
      suaLuc: Value(suaLuc),
    );
  }

  factory DongDiem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DongDiem(
      id: serializer.fromJson<String>(json['id']),
      ten: serializer.fromJson<String>(json['ten']),
      viDo: serializer.fromJson<double>(json['viDo']),
      kinhDo: serializer.fromJson<double>(json['kinhDo']),
      caoDo: serializer.fromJson<double?>(json['caoDo']),
      ghiChu: serializer.fromJson<String>(json['ghiChu']),
      taoLuc: serializer.fromJson<int>(json['taoLuc']),
      suaLuc: serializer.fromJson<int>(json['suaLuc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ten': serializer.toJson<String>(ten),
      'viDo': serializer.toJson<double>(viDo),
      'kinhDo': serializer.toJson<double>(kinhDo),
      'caoDo': serializer.toJson<double?>(caoDo),
      'ghiChu': serializer.toJson<String>(ghiChu),
      'taoLuc': serializer.toJson<int>(taoLuc),
      'suaLuc': serializer.toJson<int>(suaLuc),
    };
  }

  DongDiem copyWith({
    String? id,
    String? ten,
    double? viDo,
    double? kinhDo,
    Value<double?> caoDo = const Value.absent(),
    String? ghiChu,
    int? taoLuc,
    int? suaLuc,
  }) => DongDiem(
    id: id ?? this.id,
    ten: ten ?? this.ten,
    viDo: viDo ?? this.viDo,
    kinhDo: kinhDo ?? this.kinhDo,
    caoDo: caoDo.present ? caoDo.value : this.caoDo,
    ghiChu: ghiChu ?? this.ghiChu,
    taoLuc: taoLuc ?? this.taoLuc,
    suaLuc: suaLuc ?? this.suaLuc,
  );
  DongDiem copyWithCompanion(DiemCompanion data) {
    return DongDiem(
      id: data.id.present ? data.id.value : this.id,
      ten: data.ten.present ? data.ten.value : this.ten,
      viDo: data.viDo.present ? data.viDo.value : this.viDo,
      kinhDo: data.kinhDo.present ? data.kinhDo.value : this.kinhDo,
      caoDo: data.caoDo.present ? data.caoDo.value : this.caoDo,
      ghiChu: data.ghiChu.present ? data.ghiChu.value : this.ghiChu,
      taoLuc: data.taoLuc.present ? data.taoLuc.value : this.taoLuc,
      suaLuc: data.suaLuc.present ? data.suaLuc.value : this.suaLuc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DongDiem(')
          ..write('id: $id, ')
          ..write('ten: $ten, ')
          ..write('viDo: $viDo, ')
          ..write('kinhDo: $kinhDo, ')
          ..write('caoDo: $caoDo, ')
          ..write('ghiChu: $ghiChu, ')
          ..write('taoLuc: $taoLuc, ')
          ..write('suaLuc: $suaLuc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, ten, viDo, kinhDo, caoDo, ghiChu, taoLuc, suaLuc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DongDiem &&
          other.id == this.id &&
          other.ten == this.ten &&
          other.viDo == this.viDo &&
          other.kinhDo == this.kinhDo &&
          other.caoDo == this.caoDo &&
          other.ghiChu == this.ghiChu &&
          other.taoLuc == this.taoLuc &&
          other.suaLuc == this.suaLuc);
}

class DiemCompanion extends UpdateCompanion<DongDiem> {
  final Value<String> id;
  final Value<String> ten;
  final Value<double> viDo;
  final Value<double> kinhDo;
  final Value<double?> caoDo;
  final Value<String> ghiChu;
  final Value<int> taoLuc;
  final Value<int> suaLuc;
  final Value<int> rowid;
  const DiemCompanion({
    this.id = const Value.absent(),
    this.ten = const Value.absent(),
    this.viDo = const Value.absent(),
    this.kinhDo = const Value.absent(),
    this.caoDo = const Value.absent(),
    this.ghiChu = const Value.absent(),
    this.taoLuc = const Value.absent(),
    this.suaLuc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiemCompanion.insert({
    required String id,
    required String ten,
    required double viDo,
    required double kinhDo,
    this.caoDo = const Value.absent(),
    this.ghiChu = const Value.absent(),
    required int taoLuc,
    required int suaLuc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ten = Value(ten),
       viDo = Value(viDo),
       kinhDo = Value(kinhDo),
       taoLuc = Value(taoLuc),
       suaLuc = Value(suaLuc);
  static Insertable<DongDiem> custom({
    Expression<String>? id,
    Expression<String>? ten,
    Expression<double>? viDo,
    Expression<double>? kinhDo,
    Expression<double>? caoDo,
    Expression<String>? ghiChu,
    Expression<int>? taoLuc,
    Expression<int>? suaLuc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ten != null) 'ten': ten,
      if (viDo != null) 'vi_do': viDo,
      if (kinhDo != null) 'kinh_do': kinhDo,
      if (caoDo != null) 'cao_do': caoDo,
      if (ghiChu != null) 'ghi_chu': ghiChu,
      if (taoLuc != null) 'tao_luc': taoLuc,
      if (suaLuc != null) 'sua_luc': suaLuc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiemCompanion copyWith({
    Value<String>? id,
    Value<String>? ten,
    Value<double>? viDo,
    Value<double>? kinhDo,
    Value<double?>? caoDo,
    Value<String>? ghiChu,
    Value<int>? taoLuc,
    Value<int>? suaLuc,
    Value<int>? rowid,
  }) {
    return DiemCompanion(
      id: id ?? this.id,
      ten: ten ?? this.ten,
      viDo: viDo ?? this.viDo,
      kinhDo: kinhDo ?? this.kinhDo,
      caoDo: caoDo ?? this.caoDo,
      ghiChu: ghiChu ?? this.ghiChu,
      taoLuc: taoLuc ?? this.taoLuc,
      suaLuc: suaLuc ?? this.suaLuc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ten.present) {
      map['ten'] = Variable<String>(ten.value);
    }
    if (viDo.present) {
      map['vi_do'] = Variable<double>(viDo.value);
    }
    if (kinhDo.present) {
      map['kinh_do'] = Variable<double>(kinhDo.value);
    }
    if (caoDo.present) {
      map['cao_do'] = Variable<double>(caoDo.value);
    }
    if (ghiChu.present) {
      map['ghi_chu'] = Variable<String>(ghiChu.value);
    }
    if (taoLuc.present) {
      map['tao_luc'] = Variable<int>(taoLuc.value);
    }
    if (suaLuc.present) {
      map['sua_luc'] = Variable<int>(suaLuc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiemCompanion(')
          ..write('id: $id, ')
          ..write('ten: $ten, ')
          ..write('viDo: $viDo, ')
          ..write('kinhDo: $kinhDo, ')
          ..write('caoDo: $caoDo, ')
          ..write('ghiChu: $ghiChu, ')
          ..write('taoLuc: $taoLuc, ')
          ..write('suaLuc: $suaLuc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LichSuMigrationTable extends LichSuMigration
    with TableInfo<$LichSuMigrationTable, DongLichSuMigration> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LichSuMigrationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tuMeta = const VerificationMeta('tu');
  @override
  late final GeneratedColumn<int> tu = GeneratedColumn<int>(
    'tu',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _denMeta = const VerificationMeta('den');
  @override
  late final GeneratedColumn<int> den = GeneratedColumn<int>(
    'den',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lucMeta = const VerificationMeta('luc');
  @override
  late final GeneratedColumn<int> luc = GeneratedColumn<int>(
    'luc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, tu, den, luc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lich_su_migration';
  @override
  VerificationContext validateIntegrity(
    Insertable<DongLichSuMigration> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tu')) {
      context.handle(_tuMeta, tu.isAcceptableOrUnknown(data['tu']!, _tuMeta));
    } else if (isInserting) {
      context.missing(_tuMeta);
    }
    if (data.containsKey('den')) {
      context.handle(
        _denMeta,
        den.isAcceptableOrUnknown(data['den']!, _denMeta),
      );
    } else if (isInserting) {
      context.missing(_denMeta);
    }
    if (data.containsKey('luc')) {
      context.handle(
        _lucMeta,
        luc.isAcceptableOrUnknown(data['luc']!, _lucMeta),
      );
    } else if (isInserting) {
      context.missing(_lucMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DongLichSuMigration map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DongLichSuMigration(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tu: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tu'],
      )!,
      den: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}den'],
      )!,
      luc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}luc'],
      )!,
    );
  }

  @override
  $LichSuMigrationTable createAlias(String alias) {
    return $LichSuMigrationTable(attachedDatabase, alias);
  }
}

class DongLichSuMigration extends DataClass
    implements Insertable<DongLichSuMigration> {
  final int id;
  final int tu;
  final int den;
  final int luc;
  const DongLichSuMigration({
    required this.id,
    required this.tu,
    required this.den,
    required this.luc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tu'] = Variable<int>(tu);
    map['den'] = Variable<int>(den);
    map['luc'] = Variable<int>(luc);
    return map;
  }

  LichSuMigrationCompanion toCompanion(bool nullToAbsent) {
    return LichSuMigrationCompanion(
      id: Value(id),
      tu: Value(tu),
      den: Value(den),
      luc: Value(luc),
    );
  }

  factory DongLichSuMigration.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DongLichSuMigration(
      id: serializer.fromJson<int>(json['id']),
      tu: serializer.fromJson<int>(json['tu']),
      den: serializer.fromJson<int>(json['den']),
      luc: serializer.fromJson<int>(json['luc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tu': serializer.toJson<int>(tu),
      'den': serializer.toJson<int>(den),
      'luc': serializer.toJson<int>(luc),
    };
  }

  DongLichSuMigration copyWith({int? id, int? tu, int? den, int? luc}) =>
      DongLichSuMigration(
        id: id ?? this.id,
        tu: tu ?? this.tu,
        den: den ?? this.den,
        luc: luc ?? this.luc,
      );
  DongLichSuMigration copyWithCompanion(LichSuMigrationCompanion data) {
    return DongLichSuMigration(
      id: data.id.present ? data.id.value : this.id,
      tu: data.tu.present ? data.tu.value : this.tu,
      den: data.den.present ? data.den.value : this.den,
      luc: data.luc.present ? data.luc.value : this.luc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DongLichSuMigration(')
          ..write('id: $id, ')
          ..write('tu: $tu, ')
          ..write('den: $den, ')
          ..write('luc: $luc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tu, den, luc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DongLichSuMigration &&
          other.id == this.id &&
          other.tu == this.tu &&
          other.den == this.den &&
          other.luc == this.luc);
}

class LichSuMigrationCompanion extends UpdateCompanion<DongLichSuMigration> {
  final Value<int> id;
  final Value<int> tu;
  final Value<int> den;
  final Value<int> luc;
  const LichSuMigrationCompanion({
    this.id = const Value.absent(),
    this.tu = const Value.absent(),
    this.den = const Value.absent(),
    this.luc = const Value.absent(),
  });
  LichSuMigrationCompanion.insert({
    this.id = const Value.absent(),
    required int tu,
    required int den,
    required int luc,
  }) : tu = Value(tu),
       den = Value(den),
       luc = Value(luc);
  static Insertable<DongLichSuMigration> custom({
    Expression<int>? id,
    Expression<int>? tu,
    Expression<int>? den,
    Expression<int>? luc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tu != null) 'tu': tu,
      if (den != null) 'den': den,
      if (luc != null) 'luc': luc,
    });
  }

  LichSuMigrationCompanion copyWith({
    Value<int>? id,
    Value<int>? tu,
    Value<int>? den,
    Value<int>? luc,
  }) {
    return LichSuMigrationCompanion(
      id: id ?? this.id,
      tu: tu ?? this.tu,
      den: den ?? this.den,
      luc: luc ?? this.luc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tu.present) {
      map['tu'] = Variable<int>(tu.value);
    }
    if (den.present) {
      map['den'] = Variable<int>(den.value);
    }
    if (luc.present) {
      map['luc'] = Variable<int>(luc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LichSuMigrationCompanion(')
          ..write('id: $id, ')
          ..write('tu: $tu, ')
          ..write('den: $den, ')
          ..write('luc: $luc')
          ..write(')'))
        .toString();
  }
}

class $AnhDiemTable extends AnhDiem with TableInfo<$AnhDiemTable, DongAnhDiem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnhDiemTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _diemIdMeta = const VerificationMeta('diemId');
  @override
  late final GeneratedColumn<String> diemId = GeneratedColumn<String>(
    'diem_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES diem (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _duLieuMeta = const VerificationMeta('duLieu');
  @override
  late final GeneratedColumn<Uint8List> duLieu = GeneratedColumn<Uint8List>(
    'du_lieu',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rongMeta = const VerificationMeta('rong');
  @override
  late final GeneratedColumn<int> rong = GeneratedColumn<int>(
    'rong',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caoMeta = const VerificationMeta('cao');
  @override
  late final GeneratedColumn<int> cao = GeneratedColumn<int>(
    'cao',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taoLucMeta = const VerificationMeta('taoLuc');
  @override
  late final GeneratedColumn<int> taoLuc = GeneratedColumn<int>(
    'tao_luc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, diemId, duLieu, rong, cao, taoLuc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anh_diem';
  @override
  VerificationContext validateIntegrity(
    Insertable<DongAnhDiem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('diem_id')) {
      context.handle(
        _diemIdMeta,
        diemId.isAcceptableOrUnknown(data['diem_id']!, _diemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_diemIdMeta);
    }
    if (data.containsKey('du_lieu')) {
      context.handle(
        _duLieuMeta,
        duLieu.isAcceptableOrUnknown(data['du_lieu']!, _duLieuMeta),
      );
    } else if (isInserting) {
      context.missing(_duLieuMeta);
    }
    if (data.containsKey('rong')) {
      context.handle(
        _rongMeta,
        rong.isAcceptableOrUnknown(data['rong']!, _rongMeta),
      );
    } else if (isInserting) {
      context.missing(_rongMeta);
    }
    if (data.containsKey('cao')) {
      context.handle(
        _caoMeta,
        cao.isAcceptableOrUnknown(data['cao']!, _caoMeta),
      );
    } else if (isInserting) {
      context.missing(_caoMeta);
    }
    if (data.containsKey('tao_luc')) {
      context.handle(
        _taoLucMeta,
        taoLuc.isAcceptableOrUnknown(data['tao_luc']!, _taoLucMeta),
      );
    } else if (isInserting) {
      context.missing(_taoLucMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DongAnhDiem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DongAnhDiem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      diemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diem_id'],
      )!,
      duLieu: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}du_lieu'],
      )!,
      rong: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rong'],
      )!,
      cao: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cao'],
      )!,
      taoLuc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tao_luc'],
      )!,
    );
  }

  @override
  $AnhDiemTable createAlias(String alias) {
    return $AnhDiemTable(attachedDatabase, alias);
  }
}

class DongAnhDiem extends DataClass implements Insertable<DongAnhDiem> {
  final int id;
  final String diemId;
  final Uint8List duLieu;
  final int rong;
  final int cao;
  final int taoLuc;
  const DongAnhDiem({
    required this.id,
    required this.diemId,
    required this.duLieu,
    required this.rong,
    required this.cao,
    required this.taoLuc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['diem_id'] = Variable<String>(diemId);
    map['du_lieu'] = Variable<Uint8List>(duLieu);
    map['rong'] = Variable<int>(rong);
    map['cao'] = Variable<int>(cao);
    map['tao_luc'] = Variable<int>(taoLuc);
    return map;
  }

  AnhDiemCompanion toCompanion(bool nullToAbsent) {
    return AnhDiemCompanion(
      id: Value(id),
      diemId: Value(diemId),
      duLieu: Value(duLieu),
      rong: Value(rong),
      cao: Value(cao),
      taoLuc: Value(taoLuc),
    );
  }

  factory DongAnhDiem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DongAnhDiem(
      id: serializer.fromJson<int>(json['id']),
      diemId: serializer.fromJson<String>(json['diemId']),
      duLieu: serializer.fromJson<Uint8List>(json['duLieu']),
      rong: serializer.fromJson<int>(json['rong']),
      cao: serializer.fromJson<int>(json['cao']),
      taoLuc: serializer.fromJson<int>(json['taoLuc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'diemId': serializer.toJson<String>(diemId),
      'duLieu': serializer.toJson<Uint8List>(duLieu),
      'rong': serializer.toJson<int>(rong),
      'cao': serializer.toJson<int>(cao),
      'taoLuc': serializer.toJson<int>(taoLuc),
    };
  }

  DongAnhDiem copyWith({
    int? id,
    String? diemId,
    Uint8List? duLieu,
    int? rong,
    int? cao,
    int? taoLuc,
  }) => DongAnhDiem(
    id: id ?? this.id,
    diemId: diemId ?? this.diemId,
    duLieu: duLieu ?? this.duLieu,
    rong: rong ?? this.rong,
    cao: cao ?? this.cao,
    taoLuc: taoLuc ?? this.taoLuc,
  );
  DongAnhDiem copyWithCompanion(AnhDiemCompanion data) {
    return DongAnhDiem(
      id: data.id.present ? data.id.value : this.id,
      diemId: data.diemId.present ? data.diemId.value : this.diemId,
      duLieu: data.duLieu.present ? data.duLieu.value : this.duLieu,
      rong: data.rong.present ? data.rong.value : this.rong,
      cao: data.cao.present ? data.cao.value : this.cao,
      taoLuc: data.taoLuc.present ? data.taoLuc.value : this.taoLuc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DongAnhDiem(')
          ..write('id: $id, ')
          ..write('diemId: $diemId, ')
          ..write('duLieu: $duLieu, ')
          ..write('rong: $rong, ')
          ..write('cao: $cao, ')
          ..write('taoLuc: $taoLuc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    diemId,
    $driftBlobEquality.hash(duLieu),
    rong,
    cao,
    taoLuc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DongAnhDiem &&
          other.id == this.id &&
          other.diemId == this.diemId &&
          $driftBlobEquality.equals(other.duLieu, this.duLieu) &&
          other.rong == this.rong &&
          other.cao == this.cao &&
          other.taoLuc == this.taoLuc);
}

class AnhDiemCompanion extends UpdateCompanion<DongAnhDiem> {
  final Value<int> id;
  final Value<String> diemId;
  final Value<Uint8List> duLieu;
  final Value<int> rong;
  final Value<int> cao;
  final Value<int> taoLuc;
  const AnhDiemCompanion({
    this.id = const Value.absent(),
    this.diemId = const Value.absent(),
    this.duLieu = const Value.absent(),
    this.rong = const Value.absent(),
    this.cao = const Value.absent(),
    this.taoLuc = const Value.absent(),
  });
  AnhDiemCompanion.insert({
    this.id = const Value.absent(),
    required String diemId,
    required Uint8List duLieu,
    required int rong,
    required int cao,
    required int taoLuc,
  }) : diemId = Value(diemId),
       duLieu = Value(duLieu),
       rong = Value(rong),
       cao = Value(cao),
       taoLuc = Value(taoLuc);
  static Insertable<DongAnhDiem> custom({
    Expression<int>? id,
    Expression<String>? diemId,
    Expression<Uint8List>? duLieu,
    Expression<int>? rong,
    Expression<int>? cao,
    Expression<int>? taoLuc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (diemId != null) 'diem_id': diemId,
      if (duLieu != null) 'du_lieu': duLieu,
      if (rong != null) 'rong': rong,
      if (cao != null) 'cao': cao,
      if (taoLuc != null) 'tao_luc': taoLuc,
    });
  }

  AnhDiemCompanion copyWith({
    Value<int>? id,
    Value<String>? diemId,
    Value<Uint8List>? duLieu,
    Value<int>? rong,
    Value<int>? cao,
    Value<int>? taoLuc,
  }) {
    return AnhDiemCompanion(
      id: id ?? this.id,
      diemId: diemId ?? this.diemId,
      duLieu: duLieu ?? this.duLieu,
      rong: rong ?? this.rong,
      cao: cao ?? this.cao,
      taoLuc: taoLuc ?? this.taoLuc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (diemId.present) {
      map['diem_id'] = Variable<String>(diemId.value);
    }
    if (duLieu.present) {
      map['du_lieu'] = Variable<Uint8List>(duLieu.value);
    }
    if (rong.present) {
      map['rong'] = Variable<int>(rong.value);
    }
    if (cao.present) {
      map['cao'] = Variable<int>(cao.value);
    }
    if (taoLuc.present) {
      map['tao_luc'] = Variable<int>(taoLuc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnhDiemCompanion(')
          ..write('id: $id, ')
          ..write('diemId: $diemId, ')
          ..write('duLieu: $duLieu, ')
          ..write('rong: $rong, ')
          ..write('cao: $cao, ')
          ..write('taoLuc: $taoLuc')
          ..write(')'))
        .toString();
  }
}

abstract class _$CsdlLaBan extends GeneratedDatabase {
  _$CsdlLaBan(QueryExecutor e) : super(e);
  $CsdlLaBanManager get managers => $CsdlLaBanManager(this);
  late final $DiemTable diem = $DiemTable(this);
  late final $LichSuMigrationTable lichSuMigration = $LichSuMigrationTable(
    this,
  );
  late final $AnhDiemTable anhDiem = $AnhDiemTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    diem,
    lichSuMigration,
    anhDiem,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'diem',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('anh_diem', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DiemTableCreateCompanionBuilder = DiemCompanion Function({
  required String id,
  required String ten,
  required double viDo,
  required double kinhDo,
  Value<double?> caoDo,
  Value<String> ghiChu,
  required int taoLuc,
  required int suaLuc,
  Value<int> rowid,
});
typedef $$DiemTableUpdateCompanionBuilder = DiemCompanion Function({
  Value<String> id,
  Value<String> ten,
  Value<double> viDo,
  Value<double> kinhDo,
  Value<double?> caoDo,
  Value<String> ghiChu,
  Value<int> taoLuc,
  Value<int> suaLuc,
  Value<int> rowid,
});

final class $$DiemTableReferences
    extends BaseReferences<_$CsdlLaBan, $DiemTable, DongDiem> {
  $$DiemTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AnhDiemTable, List<DongAnhDiem>>
  _anhDiemRefsTable(_$CsdlLaBan db) => MultiTypedResultKey.fromTable(
    db.anhDiem,
    aliasName: 'diem__id__anh_diem__diem_id',
  );

  $$AnhDiemTableProcessedTableManager get anhDiemRefs {
    final manager = $$AnhDiemTableTableManager(
      $_db,
      $_db.anhDiem,
    ).filter((f) => f.diemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_anhDiemRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DiemTableFilterComposer extends Composer<_$CsdlLaBan, $DiemTable> {
  $$DiemTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ten => $composableBuilder(
    column: $table.ten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get viDo => $composableBuilder(
    column: $table.viDo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kinhDo => $composableBuilder(
    column: $table.kinhDo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get caoDo => $composableBuilder(
    column: $table.caoDo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ghiChu => $composableBuilder(
    column: $table.ghiChu,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taoLuc => $composableBuilder(
    column: $table.taoLuc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get suaLuc => $composableBuilder(
    column: $table.suaLuc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> anhDiemRefs(
    Expression<bool> Function($$AnhDiemTableFilterComposer f) f,
  ) {
    final $$AnhDiemTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.anhDiem,
      getReferencedColumn: (t) => t.diemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnhDiemTableFilterComposer(
            $db: $db,
            $table: $db.anhDiem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DiemTableOrderingComposer extends Composer<_$CsdlLaBan, $DiemTable> {
  $$DiemTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ten => $composableBuilder(
    column: $table.ten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get viDo => $composableBuilder(
    column: $table.viDo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kinhDo => $composableBuilder(
    column: $table.kinhDo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get caoDo => $composableBuilder(
    column: $table.caoDo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ghiChu => $composableBuilder(
    column: $table.ghiChu,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taoLuc => $composableBuilder(
    column: $table.taoLuc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get suaLuc => $composableBuilder(
    column: $table.suaLuc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiemTableAnnotationComposer extends Composer<_$CsdlLaBan, $DiemTable> {
  $$DiemTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ten =>
      $composableBuilder(column: $table.ten, builder: (column) => column);

  GeneratedColumn<double> get viDo =>
      $composableBuilder(column: $table.viDo, builder: (column) => column);

  GeneratedColumn<double> get kinhDo =>
      $composableBuilder(column: $table.kinhDo, builder: (column) => column);

  GeneratedColumn<double> get caoDo =>
      $composableBuilder(column: $table.caoDo, builder: (column) => column);

  GeneratedColumn<String> get ghiChu =>
      $composableBuilder(column: $table.ghiChu, builder: (column) => column);

  GeneratedColumn<int> get taoLuc =>
      $composableBuilder(column: $table.taoLuc, builder: (column) => column);

  GeneratedColumn<int> get suaLuc =>
      $composableBuilder(column: $table.suaLuc, builder: (column) => column);

  Expression<T> anhDiemRefs<T extends Object>(
    Expression<T> Function($$AnhDiemTableAnnotationComposer a) f,
  ) {
    final $$AnhDiemTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.anhDiem,
      getReferencedColumn: (t) => t.diemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnhDiemTableAnnotationComposer(
            $db: $db,
            $table: $db.anhDiem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DiemTableTableManager
    extends
        RootTableManager<
          _$CsdlLaBan,
          $DiemTable,
          DongDiem,
          $$DiemTableFilterComposer,
          $$DiemTableOrderingComposer,
          $$DiemTableAnnotationComposer,
          $$DiemTableCreateCompanionBuilder,
          $$DiemTableUpdateCompanionBuilder,
          (DongDiem, $$DiemTableReferences),
          DongDiem,
          PrefetchHooks Function({bool anhDiemRefs})
        > {
  $$DiemTableTableManager(_$CsdlLaBan db, $DiemTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiemTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiemTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiemTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ten = const Value.absent(),
                Value<double> viDo = const Value.absent(),
                Value<double> kinhDo = const Value.absent(),
                Value<double?> caoDo = const Value.absent(),
                Value<String> ghiChu = const Value.absent(),
                Value<int> taoLuc = const Value.absent(),
                Value<int> suaLuc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiemCompanion(
                id: id,
                ten: ten,
                viDo: viDo,
                kinhDo: kinhDo,
                caoDo: caoDo,
                ghiChu: ghiChu,
                taoLuc: taoLuc,
                suaLuc: suaLuc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ten,
                required double viDo,
                required double kinhDo,
                Value<double?> caoDo = const Value.absent(),
                Value<String> ghiChu = const Value.absent(),
                required int taoLuc,
                required int suaLuc,
                Value<int> rowid = const Value.absent(),
              }) => DiemCompanion.insert(
                id: id,
                ten: ten,
                viDo: viDo,
                kinhDo: kinhDo,
                caoDo: caoDo,
                ghiChu: ghiChu,
                taoLuc: taoLuc,
                suaLuc: suaLuc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiemTable, DongDiem>(table),
                  $$DiemTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({anhDiemRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (anhDiemRefs) db.anhDiem],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (anhDiemRefs)
                    await $_getPrefetchedDataByColumns<
                      DongDiem,
                      $DiemTable,
                      DongAnhDiem,
                      $AnhDiemTable
                    >(
                      currentTable: table,
                      referencedTable: $$DiemTableReferences._anhDiemRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$DiemTableReferences(db, table, p0).anhDiemRefs,
                      currentColumn: 'id',
                      referencedColumn: 'diem_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DiemTableProcessedTableManager =
    ProcessedTableManager<
      _$CsdlLaBan,
      $DiemTable,
      DongDiem,
      $$DiemTableFilterComposer,
      $$DiemTableOrderingComposer,
      $$DiemTableAnnotationComposer,
      $$DiemTableCreateCompanionBuilder,
      $$DiemTableUpdateCompanionBuilder,
      (DongDiem, $$DiemTableReferences),
      DongDiem,
      PrefetchHooks Function({bool anhDiemRefs})
    >;
typedef $$LichSuMigrationTableCreateCompanionBuilder =
    LichSuMigrationCompanion Function({
      Value<int> id,
      required int tu,
      required int den,
      required int luc,
    });
typedef $$LichSuMigrationTableUpdateCompanionBuilder =
    LichSuMigrationCompanion Function({
      Value<int> id,
      Value<int> tu,
      Value<int> den,
      Value<int> luc,
    });

class $$LichSuMigrationTableFilterComposer
    extends Composer<_$CsdlLaBan, $LichSuMigrationTable> {
  $$LichSuMigrationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tu => $composableBuilder(
    column: $table.tu,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get den => $composableBuilder(
    column: $table.den,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get luc => $composableBuilder(
    column: $table.luc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LichSuMigrationTableOrderingComposer
    extends Composer<_$CsdlLaBan, $LichSuMigrationTable> {
  $$LichSuMigrationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tu => $composableBuilder(
    column: $table.tu,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get den => $composableBuilder(
    column: $table.den,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get luc => $composableBuilder(
    column: $table.luc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LichSuMigrationTableAnnotationComposer
    extends Composer<_$CsdlLaBan, $LichSuMigrationTable> {
  $$LichSuMigrationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tu =>
      $composableBuilder(column: $table.tu, builder: (column) => column);

  GeneratedColumn<int> get den =>
      $composableBuilder(column: $table.den, builder: (column) => column);

  GeneratedColumn<int> get luc =>
      $composableBuilder(column: $table.luc, builder: (column) => column);
}

class $$LichSuMigrationTableTableManager
    extends
        RootTableManager<
          _$CsdlLaBan,
          $LichSuMigrationTable,
          DongLichSuMigration,
          $$LichSuMigrationTableFilterComposer,
          $$LichSuMigrationTableOrderingComposer,
          $$LichSuMigrationTableAnnotationComposer,
          $$LichSuMigrationTableCreateCompanionBuilder,
          $$LichSuMigrationTableUpdateCompanionBuilder,
          (
            DongLichSuMigration,
            BaseReferences<
              _$CsdlLaBan,
              $LichSuMigrationTable,
              DongLichSuMigration
            >,
          ),
          DongLichSuMigration,
          PrefetchHooks Function()
        > {
  $$LichSuMigrationTableTableManager(
    _$CsdlLaBan db,
    $LichSuMigrationTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LichSuMigrationTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LichSuMigrationTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LichSuMigrationTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> tu = const Value.absent(),
            Value<int> den = const Value.absent(),
            Value<int> luc = const Value.absent(),
          }) => LichSuMigrationCompanion(id: id, tu: tu, den: den, luc: luc),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tu,
                required int den,
                required int luc,
              }) => LichSuMigrationCompanion.insert(
                id: id,
                tu: tu,
                den: den,
                luc: luc,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LichSuMigrationTable, DongLichSuMigration>(
                    table,
                  ),
                  BaseReferences<
                    _$CsdlLaBan,
                    $LichSuMigrationTable,
                    DongLichSuMigration
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LichSuMigrationTableProcessedTableManager =
    ProcessedTableManager<
      _$CsdlLaBan,
      $LichSuMigrationTable,
      DongLichSuMigration,
      $$LichSuMigrationTableFilterComposer,
      $$LichSuMigrationTableOrderingComposer,
      $$LichSuMigrationTableAnnotationComposer,
      $$LichSuMigrationTableCreateCompanionBuilder,
      $$LichSuMigrationTableUpdateCompanionBuilder,
      (
        DongLichSuMigration,
        BaseReferences<_$CsdlLaBan, $LichSuMigrationTable, DongLichSuMigration>,
      ),
      DongLichSuMigration,
      PrefetchHooks Function()
    >;
typedef $$AnhDiemTableCreateCompanionBuilder = AnhDiemCompanion Function({
  Value<int> id,
  required String diemId,
  required Uint8List duLieu,
  required int rong,
  required int cao,
  required int taoLuc,
});
typedef $$AnhDiemTableUpdateCompanionBuilder = AnhDiemCompanion Function({
  Value<int> id,
  Value<String> diemId,
  Value<Uint8List> duLieu,
  Value<int> rong,
  Value<int> cao,
  Value<int> taoLuc,
});

final class $$AnhDiemTableReferences
    extends BaseReferences<_$CsdlLaBan, $AnhDiemTable, DongAnhDiem> {
  $$AnhDiemTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DiemTable _diemIdTable(_$CsdlLaBan db) =>
      db.diem.createAlias('anh_diem__diem_id__diem__id');

  $$DiemTableProcessedTableManager get diemId {
    final $_column = $_itemColumn<String>('diem_id')!;

    final manager = $$DiemTableTableManager(
      $_db,
      $_db.diem,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_diemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AnhDiemTableFilterComposer
    extends Composer<_$CsdlLaBan, $AnhDiemTable> {
  $$AnhDiemTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get duLieu => $composableBuilder(
    column: $table.duLieu,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rong => $composableBuilder(
    column: $table.rong,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cao => $composableBuilder(
    column: $table.cao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taoLuc => $composableBuilder(
    column: $table.taoLuc,
    builder: (column) => ColumnFilters(column),
  );

  $$DiemTableFilterComposer get diemId {
    final $$DiemTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diemId,
      referencedTable: $db.diem,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiemTableFilterComposer(
            $db: $db,
            $table: $db.diem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnhDiemTableOrderingComposer
    extends Composer<_$CsdlLaBan, $AnhDiemTable> {
  $$AnhDiemTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get duLieu => $composableBuilder(
    column: $table.duLieu,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rong => $composableBuilder(
    column: $table.rong,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cao => $composableBuilder(
    column: $table.cao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taoLuc => $composableBuilder(
    column: $table.taoLuc,
    builder: (column) => ColumnOrderings(column),
  );

  $$DiemTableOrderingComposer get diemId {
    final $$DiemTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diemId,
      referencedTable: $db.diem,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiemTableOrderingComposer(
            $db: $db,
            $table: $db.diem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnhDiemTableAnnotationComposer
    extends Composer<_$CsdlLaBan, $AnhDiemTable> {
  $$AnhDiemTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get duLieu =>
      $composableBuilder(column: $table.duLieu, builder: (column) => column);

  GeneratedColumn<int> get rong =>
      $composableBuilder(column: $table.rong, builder: (column) => column);

  GeneratedColumn<int> get cao =>
      $composableBuilder(column: $table.cao, builder: (column) => column);

  GeneratedColumn<int> get taoLuc =>
      $composableBuilder(column: $table.taoLuc, builder: (column) => column);

  $$DiemTableAnnotationComposer get diemId {
    final $$DiemTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diemId,
      referencedTable: $db.diem,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiemTableAnnotationComposer(
            $db: $db,
            $table: $db.diem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnhDiemTableTableManager
    extends
        RootTableManager<
          _$CsdlLaBan,
          $AnhDiemTable,
          DongAnhDiem,
          $$AnhDiemTableFilterComposer,
          $$AnhDiemTableOrderingComposer,
          $$AnhDiemTableAnnotationComposer,
          $$AnhDiemTableCreateCompanionBuilder,
          $$AnhDiemTableUpdateCompanionBuilder,
          (DongAnhDiem, $$AnhDiemTableReferences),
          DongAnhDiem,
          PrefetchHooks Function({bool diemId})
        > {
  $$AnhDiemTableTableManager(_$CsdlLaBan db, $AnhDiemTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnhDiemTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnhDiemTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnhDiemTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> diemId = const Value.absent(),
                Value<Uint8List> duLieu = const Value.absent(),
                Value<int> rong = const Value.absent(),
                Value<int> cao = const Value.absent(),
                Value<int> taoLuc = const Value.absent(),
              }) => AnhDiemCompanion(
                id: id,
                diemId: diemId,
                duLieu: duLieu,
                rong: rong,
                cao: cao,
                taoLuc: taoLuc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String diemId,
                required Uint8List duLieu,
                required int rong,
                required int cao,
                required int taoLuc,
              }) => AnhDiemCompanion.insert(
                id: id,
                diemId: diemId,
                duLieu: duLieu,
                rong: rong,
                cao: cao,
                taoLuc: taoLuc,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnhDiemTable, DongAnhDiem>(table),
                  $$AnhDiemTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({diemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (diemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.diemId,
                        referencedTable: $$AnhDiemTableReferences._diemIdTable(
                          db,
                        ),
                        referencedColumn: $$AnhDiemTableReferences
                            ._diemIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AnhDiemTableProcessedTableManager =
    ProcessedTableManager<
      _$CsdlLaBan,
      $AnhDiemTable,
      DongAnhDiem,
      $$AnhDiemTableFilterComposer,
      $$AnhDiemTableOrderingComposer,
      $$AnhDiemTableAnnotationComposer,
      $$AnhDiemTableCreateCompanionBuilder,
      $$AnhDiemTableUpdateCompanionBuilder,
      (DongAnhDiem, $$AnhDiemTableReferences),
      DongAnhDiem,
      PrefetchHooks Function({bool diemId})
    >;

class $CsdlLaBanManager {
  final _$CsdlLaBan _db;
  $CsdlLaBanManager(this._db);
  $$DiemTableTableManager get diem => $$DiemTableTableManager(_db, _db.diem);
  $$LichSuMigrationTableTableManager get lichSuMigration =>
      $$LichSuMigrationTableTableManager(_db, _db.lichSuMigration);
  $$AnhDiemTableTableManager get anhDiem =>
      $$AnhDiemTableTableManager(_db, _db.anhDiem);
}
