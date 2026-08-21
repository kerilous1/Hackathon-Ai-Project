class ChildModel {
  final String id;
  final String name;
  final DateTime birthDate;
  final double weightKg;
  final String gender; // 'male' or 'female'
  final List<String> allergies;
  final List<String> chronicDiseases;
  final List<String> currentMedications;
  final String notes;

  ChildModel({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.weightKg,
    required this.gender,
    this.allergies = const [],
    this.chronicDiseases = const [],
    this.currentMedications = const [],
    this.notes = '',
  });

  int get ageInDays {
    final now = DateTime.now();
    return now.difference(birthDate).inDays;
  }

  double get ageInMonths {
    return ageInDays / 30.417;
  }

  String get ageFormattedArabic {
    final days = ageInDays;
    if (days < 30) {
      return '$days يوماً';
    } else if (days < 365) {
      final m = (days / 30.417).floor();
      return '$m أشهر';
    } else {
      final y = (days / 365.25).floor();
      final remM = ((days % 365.25) / 30.417).floor();
      return remM > 0 ? '$y سنوات و $remM أشهر' : '$y سنوات';
    }
  }

  String get ageFormattedEnglish {
    final days = ageInDays;
    if (days < 30) {
      return '$days days';
    } else if (days < 365) {
      final m = (days / 30.417).floor();
      return '$m months';
    } else {
      final y = (days / 365.25).floor();
      final remM = ((days % 365.25) / 30.417).floor();
      return remM > 0 ? '$y yr $remM mo' : '$y years';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'birthDate': birthDate.toIso8601String(),
      'weightKg': weightKg,
      'gender': gender,
      'allergies': allergies,
      'chronicDiseases': chronicDiseases,
      'currentMedications': currentMedications,
      'notes': notes,
    };
  }

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      id: json['id'] as String,
      name: json['name'] as String,
      birthDate: DateTime.parse(json['birthDate'] as String),
      weightKg: (json['weightKg'] as num).toDouble(),
      gender: json['gender'] as String? ?? 'male',
      allergies: List<String>.from(json['allergies'] ?? []),
      chronicDiseases: List<String>.from(json['chronicDiseases'] ?? []),
      currentMedications: List<String>.from(json['currentMedications'] ?? []),
      notes: json['notes'] as String? ?? '',
    );
  }
}
