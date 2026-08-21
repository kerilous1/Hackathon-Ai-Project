class EvidenceModel {
  final String documentName;
  final String sectionTitle;
  final int page;
  final double relevanceScore;
  final String highlightTextEn;
  final String highlightTextAr;
  final String triageColor;

  EvidenceModel({
    required this.documentName,
    required this.sectionTitle,
    required this.page,
    required this.relevanceScore,
    required this.highlightTextEn,
    required this.highlightTextAr,
    this.triageColor = 'NONE',
  });

  Map<String, dynamic> toJson() {
    return {
      'document_name': documentName,
      'section_title': sectionTitle,
      'page': page,
      'relevance_score': relevanceScore,
      'highlight_text_en': highlightTextEn,
      'highlight_text_ar': highlightTextAr,
      'triage_color': triageColor,
    };
  }

  factory EvidenceModel.fromJson(Map<String, dynamic> json) {
    return EvidenceModel(
      documentName: json['document_name'] as String? ?? 'WHO IMCI Model Handbook',
      sectionTitle: json['section_title'] as String? ?? 'Clinical Guidelines',
      page: (json['page'] as num?)?.toInt() ?? 1,
      relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 0.0,
      highlightTextEn: json['highlight_text_en'] as String? ?? '',
      highlightTextAr: json['highlight_text_ar'] as String? ?? '',
      triageColor: json['triage_color'] as String? ?? 'NONE',
    );
  }
}
