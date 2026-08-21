class SymptomLogEntry {
  final String id;
  final String childId;
  final DateTime date;
  final double temperatureC;
  final String coughStatus; // 'none', 'mild', 'severe_fast_breathing', 'stridor'
  final int diarrheaStoolsCount;
  final String feedingStatus; // 'normal', 'poor', 'not_able_to_drink', 'vomiting_everything'
  final String notes;
  final String triageLevel; // 'RED', 'YELLOW', 'GREEN'

  SymptomLogEntry({
    required this.id,
    required this.childId,
    required this.date,
    required this.temperatureC,
    required this.coughStatus,
    required this.diarrheaStoolsCount,
    required this.feedingStatus,
    this.notes = '',
    this.triageLevel = 'GREEN',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childId': childId,
      'date': date.toIso8601String(),
      'temperatureC': temperatureC,
      'coughStatus': coughStatus,
      'diarrheaStoolsCount': diarrheaStoolsCount,
      'feedingStatus': feedingStatus,
      'notes': notes,
      'triageLevel': triageLevel,
    };
  }

  factory SymptomLogEntry.fromJson(Map<String, dynamic> json) {
    return SymptomLogEntry(
      id: json['id'] as String,
      childId: json['childId'] as String,
      date: DateTime.parse(json['date'] as String),
      temperatureC: (json['temperatureC'] as num).toDouble(),
      coughStatus: json['coughStatus'] as String? ?? 'none',
      diarrheaStoolsCount: (json['diarrheaStoolsCount'] as num?)?.toInt() ?? 0,
      feedingStatus: json['feedingStatus'] as String? ?? 'normal',
      notes: json['notes'] as String? ?? '',
      triageLevel: json['triageLevel'] as String? ?? 'GREEN',
    );
  }
}
