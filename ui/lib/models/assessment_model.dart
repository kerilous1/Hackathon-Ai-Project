import 'evidence_model.dart';

class DifferentialDiagnosis {
  final String name;
  final int probability;

  DifferentialDiagnosis({required this.name, required this.probability});

  factory DifferentialDiagnosis.fromJson(Map<String, dynamic> json) {
    return DifferentialDiagnosis(
      name: json['name'] as String? ?? 'General Pediatric Condition',
      probability: (json['probability'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'probability': probability};
}

class AssessmentResponseModel {
  final String id;
  final String status;
  final String detectedLanguage;
  final String triageLevel; // 'RED', 'YELLOW', 'GREEN', 'GRAY'
  final String triageLabelAr;
  final String triageLabelEn;
  final List<String> summaryFound;
  final List<String> missingInfo;
  final String fullRecommendation;
  final List<DifferentialDiagnosis> differentialDiagnoses;
  final List<EvidenceModel> evidenceList;
  final Map<String, bool> verificationAnswers; // question text -> true/false
  final DateTime timestamp;

  AssessmentResponseModel({
    required this.id,
    required this.status,
    required this.detectedLanguage,
    required this.triageLevel,
    required this.triageLabelAr,
    required this.triageLabelEn,
    required this.summaryFound,
    required this.missingInfo,
    required this.fullRecommendation,
    required this.differentialDiagnoses,
    required this.evidenceList,
    this.verificationAnswers = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isRed => triageLevel == 'RED';
  bool get isYellow => triageLevel == 'YELLOW';
  bool get isGreen => triageLevel == 'GREEN';
  bool get isRefusal => status == 'refusal' || triageLevel == 'GRAY';

  double get temperatureC {
    final allText = '${summaryFound.join(" ")} $fullRecommendation';
    final match = RegExp(r'(\d{2}(?:\.\d+)?)\s*(?:°C|C|درجة)').firstMatch(allText);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 37.5;
    }
    if (allText.contains('hypothermia') || allText.contains('انخفاض حرارة') || allText.contains('35.2')) {
      return 35.2;
    }
    if (allText.contains('fever') || allText.contains('حمى') || allText.contains('حرارة')) {
      return 38.5;
    }
    return 37.0;
  }

  int? get respiratoryRate {
    final allText = summaryFound.join(" ");
    final match = RegExp(r'(\d{2,3})\s*(?:نفس|breath|breaths|bpm|/min)').firstMatch(allText);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  String get durationText {
    final allText = summaryFound.join(" ");
    if (allText.contains('أقل من 24 ساعة') || allText.contains('< 24h')) return 'أقل من 24 ساعة (< 24h)';
    if (allText.contains('1 إلى 3 أيام') || allText.contains('1-3 days')) return 'منذ 1 إلى 3 أيام';
    if (allText.contains('أكثر من 3 أيام') || allText.contains('> 3 days')) return 'أكثر من 3 أيام';
    return 'منذ يومين (حالة حادة)';
  }

  String get chiefComplaint {
    if (summaryFound.isNotEmpty) {
      return summaryFound.first;
    }
    if (differentialDiagnoses.isNotEmpty) {
      return differentialDiagnoses.first.name;
    }
    return 'أعراض حادة مستجدة';
  }

  AssessmentResponseModel copyWith({
    String? id,
    String? status,
    String? detectedLanguage,
    String? triageLevel,
    String? triageLabelAr,
    String? triageLabelEn,
    List<String>? summaryFound,
    List<String>? missingInfo,
    String? fullRecommendation,
    List<DifferentialDiagnosis>? differentialDiagnoses,
    List<EvidenceModel>? evidenceList,
    Map<String, bool>? verificationAnswers,
    DateTime? timestamp,
  }) {
    return AssessmentResponseModel(
      id: id ?? this.id,
      status: status ?? this.status,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      triageLevel: triageLevel ?? this.triageLevel,
      triageLabelAr: triageLabelAr ?? this.triageLabelAr,
      triageLabelEn: triageLabelEn ?? this.triageLabelEn,
      summaryFound: summaryFound ?? this.summaryFound,
      missingInfo: missingInfo ?? this.missingInfo,
      fullRecommendation: fullRecommendation ?? this.fullRecommendation,
      differentialDiagnoses: differentialDiagnoses ?? this.differentialDiagnoses,
      evidenceList: evidenceList ?? this.evidenceList,
      verificationAnswers: verificationAnswers ?? this.verificationAnswers,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'detected_language': detectedLanguage,
      'triage_level': triageLevel,
      'triage_label_ar': triageLabelAr,
      'triage_label_en': triageLabelEn,
      'summary_found': summaryFound,
      'missing_info': missingInfo,
      'full_recommendation': fullRecommendation,
      'differential_diagnoses': differentialDiagnoses.map((d) => d.toJson()).toList(),
      'evidence_list': evidenceList.map((e) => e.toJson()).toList(),
      'verification_answers': verificationAnswers,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AssessmentResponseModel.fromJson(Map<String, dynamic> json) {
    return AssessmentResponseModel(
      id: json['id'] as String? ?? 'asmt_${DateTime.now().millisecondsSinceEpoch}',
      status: json['status'] as String? ?? 'success',
      detectedLanguage: json['detected_language'] as String? ?? 'ar',
      triageLevel: json['triage_level'] as String? ?? 'YELLOW',
      triageLabelAr: json['triage_label_ar'] as String? ?? 'علاج في العيادة 🟡',
      triageLabelEn: json['triage_label_en'] as String? ?? 'CLINIC TREATMENT 🟡',
      summaryFound: List<String>.from(json['summary_found'] ?? []),
      missingInfo: List<String>.from(json['missing_info'] ?? []),
      fullRecommendation: json['full_recommendation'] as String? ?? json['message'] as String? ?? '',
      differentialDiagnoses: (json['differential_diagnoses'] as List<dynamic>?)
              ?.map((d) => DifferentialDiagnosis.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      evidenceList: (json['evidence_list'] as List<dynamic>?)
              ?.map((e) => EvidenceModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      verificationAnswers: (json['verification_answers'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as bool),
          ) ??
          {},
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : DateTime.now(),
    );
  }
}
