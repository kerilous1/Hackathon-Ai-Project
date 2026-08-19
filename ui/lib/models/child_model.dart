import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class ChildModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double age; // Fractional years: 0.17 = ~2 months, 0.5 = 6 months, 4.0 = 4 years (WHO IMCI: 0–5 years)

  @HiveField(3)
  final double weight; // Strictly 2.0 to 35.0 kg

  @HiveField(4)
  final String gender; // 'ذكر' | 'أنثى'

  @HiveField(5)
  final String birthDate; // e.g. '2022 - 05 - 10'

  @HiveField(6)
  final String allergies; // 'لا يوجد'

  @HiveField(7)
  final String chronicDiseases; // 'لا يوجد'

  @HiveField(8)
  final String medications; // 'لا يوجد'

  @HiveField(9)
  final String notes; // 'لا توجد ملاحظات'

  @HiveField(10)
  final String avatarType; // 'boy' | 'girl'

  ChildModel({
    required this.id,
    required this.name,
    required this.age,
    required this.weight,
    this.gender = 'ذكر',
    String? birthDate,
    this.allergies = 'لا يوجد',
    this.chronicDiseases = 'لا يوجد',
    this.medications = 'لا يوجد',
    this.notes = 'لا توجد ملاحظات',
    this.avatarType = 'boy',
  }) : birthDate = birthDate ?? calculateBirthDate(age);

  /// Converts fractional age to a birth date string.
  /// E.g. age 0.5 → born ~6 months ago, age 4 → born ~4 years ago.
  static String calculateBirthDate(double ageInYears) {
    final now = DateTime.now();
    final totalMonths = (ageInYears * 12).round();
    final birthYear = now.year - (totalMonths ~/ 12);
    final birthMonth = now.month - (totalMonths % 12);
    final adjustedYear = birthMonth <= 0 ? birthYear - 1 : birthYear;
    final adjustedMonth = birthMonth <= 0 ? birthMonth + 12 : birthMonth;
    return '$adjustedYear - ${adjustedMonth.toString().padLeft(2, '0')} - ${now.day.toString().padLeft(2, '0')}';
  }

  /// Human-readable Arabic age string.
  /// - < 1 month: "X أسبوع"
  /// - < 1 year: "X شهر"
  /// - ≥ 1 year with fractional months: "X سنة و Y شهر"
  /// - ≥ 1 year whole: "X سنوات"
  String get ageDisplayAr {
    final totalMonths = (age * 12).round();
    if (totalMonths < 1) {
      final weeks = (age * 52).round().clamp(1, 4);
      return '$weeks أسبوع';
    } else if (totalMonths < 12) {
      return '$totalMonths شهر';
    } else {
      final years = totalMonths ~/ 12;
      final remainingMonths = totalMonths % 12;
      if (remainingMonths == 0) {
        return '$years سنوات';
      }
      return '$years سنة و $remainingMonths شهر';
    }
  }

  /// The integer year component for the API (floor).
  int get ageYearsInt => age.floor();

  ChildModel copyWith({
    String? id,
    String? name,
    double? age,
    double? weight,
    String? gender,
    String? birthDate,
    String? allergies,
    String? chronicDiseases,
    String? medications,
    String? notes,
    String? avatarType,
  }) {
    return ChildModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      allergies: allergies ?? this.allergies,
      chronicDiseases: chronicDiseases ?? this.chronicDiseases,
      medications: medications ?? this.medications,
      notes: notes ?? this.notes,
      avatarType: avatarType ?? this.avatarType,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'weight': weight,
        'gender': gender,
        'birthDate': birthDate,
        'allergies': allergies,
        'chronicDiseases': chronicDiseases,
        'medications': medications,
        'notes': notes,
        'avatarType': avatarType,
      };

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    final age = (json['age'] as num?)?.toDouble() ?? 3.0;
    return ChildModel(
      id: json['id'] as String? ?? 'child_1',
      name: json['name'] as String? ?? 'طفل',
      age: age,
      weight: (json['weight'] as num?)?.toDouble() ?? 15.0,
      gender: json['gender'] as String? ?? 'ذكر',
      birthDate: json['birthDate'] as String? ?? calculateBirthDate(age),
      allergies: json['allergies'] as String? ?? 'لا يوجد',
      chronicDiseases: json['chronicDiseases'] as String? ?? 'لا يوجد',
      medications: json['medications'] as String? ?? 'لا يوجد',
      notes: json['notes'] as String? ?? 'لا توجد ملاحظات',
      avatarType: json['avatarType'] as String? ?? 'boy',
    );
  }
}

class ChildModelAdapter extends TypeAdapter<ChildModel> {
  @override
  final int typeId = 0;

  @override
  ChildModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final age = (fields[2] as num?)?.toDouble() ?? 3.0;
    return ChildModel(
      id: fields[0] as String? ?? 'child_1',
      name: fields[1] as String? ?? 'طفل',
      age: age,
      weight: (fields[3] as num?)?.toDouble() ?? 15.0,
      gender: fields[4] as String? ?? 'ذكر',
      birthDate: fields[5] as String? ?? ChildModel.calculateBirthDate(age),
      allergies: fields[6] as String? ?? 'لا يوجد',
      chronicDiseases: fields[7] as String? ?? 'لا يوجد',
      medications: fields[8] as String? ?? 'لا يوجد',
      notes: fields[9] as String? ?? 'لا توجد ملاحظات',
      avatarType: fields[10] as String? ?? 'boy',
    );
  }

  @override
  void write(BinaryWriter writer, ChildModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.age)
      ..writeByte(3)
      ..write(obj.weight)
      ..writeByte(4)
      ..write(obj.gender)
      ..writeByte(5)
      ..write(obj.birthDate)
      ..writeByte(6)
      ..write(obj.allergies)
      ..writeByte(7)
      ..write(obj.chronicDiseases)
      ..writeByte(8)
      ..write(obj.medications)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.avatarType);
  }
}
