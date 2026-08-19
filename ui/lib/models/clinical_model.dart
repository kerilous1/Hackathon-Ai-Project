/// PEDI-GUIDE AI — Clinical Data Models
/// ======================================
/// Dart data classes for parsing the FastAPI JSON response.

class EvidenceChunk {
  final String text;
  final dynamic page; // int or "N/A"
  final String section;
  final double score;
  final bool used;

  EvidenceChunk({
    required this.text,
    required this.page,
    required this.section,
    required this.score,
    required this.used,
  });

  factory EvidenceChunk.fromJson(Map<String, dynamic> json) {
    return EvidenceChunk(
      text: json['text'] ?? '',
      page: json['page'] ?? 'N/A',
      section: json['section'] ?? 'Clinical Guidelines',
      score: (json['score'] ?? 0.0).toDouble(),
      used: json['used'] ?? false,
    );
  }

  String get pageDisplay => page?.toString() ?? 'N/A';

  String get scorePercent => '${score.toStringAsFixed(1)}%';
}

class ClinicalResult {
  final String status; // 'success' | 'refusal' | 'error'
  final String triageLevel; // 'RED' | 'YELLOW' | 'GREEN' | 'REFUSAL'
  final String responseText;
  final List<EvidenceChunk> chunks;
  final double topScore;
  final String confidence; // 'HIGH' | 'MEDIUM' | 'LOW'
  final String searchQuery;
  final List<int> citedPages;
  final List<String> differentialQuestions;

  ClinicalResult({
    required this.status,
    required this.triageLevel,
    required this.responseText,
    required this.chunks,
    required this.topScore,
    required this.confidence,
    required this.searchQuery,
    required this.citedPages,
    required this.differentialQuestions,
  });

  factory ClinicalResult.fromJson(Map<String, dynamic> json) {
    return ClinicalResult(
      status: json['status'] ?? 'error',
      triageLevel: json['triage_level'] ?? 'REFUSAL',
      responseText: json['response_text'] ?? '',
      chunks: (json['chunks'] as List<dynamic>? ?? [])
          .map((c) => EvidenceChunk.fromJson(c as Map<String, dynamic>))
          .toList(),
      topScore: (json['top_score'] ?? 0.0).toDouble(),
      confidence: json['confidence'] ?? 'LOW',
      searchQuery: json['search_query'] ?? '',
      citedPages: (json['cited_pages'] as List<dynamic>? ?? [])
          .map((p) => p as int)
          .toList(),
      differentialQuestions:
          (json['differential_questions'] as List<dynamic>? ?? [])
              .map((q) => q.toString())
              .toList(),
    );
  }

  bool get isSuccess => status == 'success';
  bool get isRefusal => status == 'refusal';
  bool get isError => status == 'error';
}

/// Wraps a query + its result for session history.
class SessionEntry {
  final String query;
  final ClinicalResult result;
  final DateTime timestamp;

  SessionEntry({
    required this.query,
    required this.result,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
