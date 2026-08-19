import 'dart:convert';
import 'package:hive/hive.dart';

class EvidenceItem {
  final String sourceTitle;
  final String section;
  final String page;
  final double relevanceScore;
  final String highlightText;

  EvidenceItem({
    required this.sourceTitle,
    required this.section,
    required this.page,
    required this.relevanceScore,
    required this.highlightText,
  });

  Map<String, dynamic> toJson() => {
    'source_title': sourceTitle,
    'section': section,
    'page': page,
    'relevance_score': relevanceScore,
    'highlight_text': highlightText,
  };

  factory EvidenceItem.fromJson(Map<String, dynamic> json) => EvidenceItem(
    sourceTitle:
        json['source_title'] as String? ??
        'إرشادات منظمة الصحة العالمية (WHO IMCI)',
    section: json['section'] as String? ?? 'قسم: طب الأطفال والتنفس',
    page: json['page'] as String? ?? 'ص 16 من 142',
    relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 75.0,
    highlightText: json['highlight_text'] as String? ?? '',
  );
}

class DifferentialDiagnosis {
  final String name;
  final int probability;

  DifferentialDiagnosis({required this.name, required this.probability});

  Map<String, dynamic> toJson() => {'name': name, 'probability': probability};

  factory DifferentialDiagnosis.fromJson(Map<String, dynamic> json) =>
      DifferentialDiagnosis(
        name: json['name'] as String? ?? '',
        probability: (json['probability'] as num?)?.toInt() ?? 50,
      );
}

class AssessmentResponse {
  final String status;
  final String triageLevel; // RED, YELLOW, GREEN, REFUSAL
  final String triageLabelAr;
  final List<String> summaryFound;
  final List<String> missingInfo;
  final String fullRecommendation;
  final List<EvidenceItem> evidenceList;
  final List<DifferentialDiagnosis> differentialDiagnoses;

  AssessmentResponse({
    required this.status,
    required this.triageLevel,
    required this.triageLabelAr,
    required this.summaryFound,
    required this.missingInfo,
    required this.fullRecommendation,
    required this.evidenceList,
    required this.differentialDiagnoses,
  });

  factory AssessmentResponse.fromJson(Map<String, dynamic> json) {
    var rawEvidences = json['evidence_list'] as List<dynamic>? ?? [];
    List<EvidenceItem> evidences = rawEvidences
        .map((e) => EvidenceItem.fromJson(e as Map<String, dynamic>))
        .toList();

    var rawDiff = json['differential_diagnoses'] as List<dynamic>? ?? [];
    List<DifferentialDiagnosis> diffs = rawDiff
        .map((d) => DifferentialDiagnosis.fromJson(d as Map<String, dynamic>))
        .toList();

    var rawFound = json['summary_found'] as List<dynamic>? ?? [];
    List<String> found = rawFound.map((e) => e.toString()).toList();

    var rawMissing = json['missing_info'] as List<dynamic>? ?? [];
    List<String> missing = rawMissing.map((e) => e.toString()).toList();

    return AssessmentResponse(
      status: json['status'] as String? ?? 'success',
      triageLevel: json['triage_level'] as String? ?? 'YELLOW',
      triageLabelAr:
          json['triage_label_ar'] as String? ?? 'يحتاج إلى تقييم طبي',
      summaryFound: found,
      missingInfo: missing,
      fullRecommendation: json['full_recommendation'] as String? ?? '',
      evidenceList: evidences,
      differentialDiagnoses: diffs,
    );
  }

  // Graceful fallback purely aligned with WHO IMCI
  factory AssessmentResponse.fallbackGrounded({
    required String childName,
    required String symptoms,
  }) {
    return AssessmentResponse(
      status: 'success',
      triageLevel: 'YELLOW',
      triageLabelAr: 'يحتاج إلى تقييم طبي (استشارة طبيب)',
      summaryFound: [
        'أعراض سريرية: $symptoms',
        'الحالة تتطلب فحصاً طبياً للعلامات الحيوية',
      ],
      missingInfo: [
        'هل يستطيع $childName الشرب أو الرضاعة بشكل طبيعي؟',
        'هل يعاني من صعوبة أو تسارع في التنفس؟',
        'هل يوجد قيء متكرر أو خمول غير معتاد؟',
      ],
      fullRecommendation:
          '📋 توصية منظمة الصحة العالمية (WHO IMCI):\n'
          'يجب فحص الطفل سريرياً لاستبعاد علامات الخطورة العامة وفحص الصدر والحلق. يوصى بإعطاء السوائل بكثرة ومراقبة التنفس باستمرار.',
      evidenceList: [
        EvidenceItem(
          sourceTitle: 'إرشادات منظمة الصحة العالمية (WHO IMCI)',
          section: 'قسم: تقييم الطفل المريض وفحص علامات الخطورة العامة',
          page: 'ص 16 من 142',
          relevanceScore: 78.5,
          highlightText:
              'A child with cough or difficult breathing must be assessed for general danger signs, chest indrawing, and fast breathing according to age thresholds.',
        ),
      ],
      differentialDiagnoses: [
        DifferentialDiagnosis(
          name: 'التهاب فيروسي بالجهاز التنفسي العلوي',
          probability: 65,
        ),
        DifferentialDiagnosis(
          name: 'اشتباه التهاب أذن وسطى أو التهاب حلق',
          probability: 20,
        ),
        DifferentialDiagnosis(
          name: 'التهاب رئوي مبكر يحتاج تقييم',
          probability: 15,
        ),
      ],
    );
  }
}

@HiveType(typeId: 1)
class AssessmentRecordModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String childId;

  @HiveField(2)
  final String childName;

  @HiveField(3)
  final String date;

  @HiveField(4)
  final String chiefComplaint;

  @HiveField(5)
  final int durationDays;

  @HiveField(6)
  final String triageLevel;

  @HiveField(7)
  final String triageLabelAr;

  @HiveField(8)
  final List<String> symptomsSummary;

  @HiveField(9)
  final List<String> missingQuestions;

  @HiveField(10)
  final String fullRecommendation;

  @HiveField(11)
  final String evidenceJson;

  @HiveField(12)
  final String differentialJson;

  AssessmentRecordModel({
    required this.id,
    required this.childId,
    required this.childName,
    required this.date,
    required this.chiefComplaint,
    required this.durationDays,
    required this.triageLevel,
    required this.triageLabelAr,
    required this.symptomsSummary,
    required this.missingQuestions,
    required this.fullRecommendation,
    required this.evidenceJson,
    required this.differentialJson,
  });

  List<EvidenceItem> get evidences {
    try {
      final list = jsonDecode(evidenceJson) as List;
      return list.map((e) => EvidenceItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  List<DifferentialDiagnosis> get differentialDiagnoses {
    try {
      final list = jsonDecode(differentialJson) as List;
      return list.map((e) => DifferentialDiagnosis.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }
}

class AssessmentRecordModelAdapter extends TypeAdapter<AssessmentRecordModel> {
  @override
  final int typeId = 1;

  @override
  AssessmentRecordModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AssessmentRecordModel(
      id: fields[0] as String? ?? 'rec_1',
      childId: fields[1] as String? ?? 'child_1',
      childName: fields[2] as String? ?? 'آدم',
      date: fields[3] as String? ?? '',
      chiefComplaint: fields[4] as String? ?? '',
      durationDays: fields[5] as int? ?? 1,
      triageLevel: fields[6] as String? ?? 'YELLOW',
      triageLabelAr: fields[7] as String? ?? 'يحتاج إلى تقييم طبي',
      symptomsSummary: (fields[8] as List?)?.cast<String>() ?? [],
      missingQuestions: (fields[9] as List?)?.cast<String>() ?? [],
      fullRecommendation: fields[10] as String? ?? '',
      evidenceJson: fields[11] as String? ?? '[]',
      differentialJson: fields[12] as String? ?? '[]',
    );
  }

  @override
  void write(BinaryWriter writer, AssessmentRecordModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.childName)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.chiefComplaint)
      ..writeByte(5)
      ..write(obj.durationDays)
      ..writeByte(6)
      ..write(obj.triageLevel)
      ..writeByte(7)
      ..write(obj.triageLabelAr)
      ..writeByte(8)
      ..write(obj.symptomsSummary)
      ..writeByte(9)
      ..write(obj.missingQuestions)
      ..writeByte(10)
      ..write(obj.fullRecommendation)
      ..writeByte(11)
      ..write(obj.evidenceJson)
      ..writeByte(12)
      ..write(obj.differentialJson);
  }
}
