import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/child_model.dart';
import '../models/assessment_model.dart';
import '../models/evidence_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Multi-host candidates for Desktop (127.0.0.1 / localhost) and Android Emulator (10.0.2.2)
  final List<String> candidateUrls = [
    'http://127.0.0.1:8000',
    'http://10.0.2.2:8000',
    'http://localhost:8000',
  ];

  String baseUrl = 'http://127.0.0.1:8000';
  bool _hasResolvedUrl = false;

  Future<String> resolveActiveBaseUrl() async {
    for (final candidate in candidateUrls) {
      try {
        final response = await http
            .get(Uri.parse('$candidate/api/v1/health'))
            .timeout(const Duration(milliseconds: 1200));
        if (response.statusCode == 200) {
          baseUrl = candidate;
          _hasResolvedUrl = true;
          return baseUrl;
        }
      } catch (_) {
        continue;
      }
    }
    return baseUrl;
  }

  Future<bool> checkHealth() async {
    try {
      if (!_hasResolvedUrl) {
        await resolveActiveBaseUrl();
      }
      final response = await http
          .get(Uri.parse('$baseUrl/api/v1/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      // Try resolving one more time
      final resolved = await resolveActiveBaseUrl();
      try {
        final res = await http
            .get(Uri.parse('$resolved/api/v1/health'))
            .timeout(const Duration(seconds: 2));
        return res.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
  }

  Future<AssessmentResponseModel> assessClinicalScenario({
    required String query,
    required ChildModel child,
    String language = 'ar',
    String? customApiKey,
  }) async {
    final payload = {
      'query': query,
      'child_name': child.name,
      'age_days': child.ageInDays,
      'age_months': child.ageInMonths,
      'weight_kg': child.weightKg,
      'gender': child.gender,
      'language': language,
      if (customApiKey != null && customApiKey.isNotEmpty) 'api_key': customApiKey,
    };

    // Ensure active URL is resolved
    if (!_hasResolvedUrl) {
      await resolveActiveBaseUrl();
    }

    Exception? lastException;

    // Attempt request with current active baseUrl and fallback to candidates if needed
    final urlsToTry = [baseUrl, ...candidateUrls.where((u) => u != baseUrl)];

    for (final url in urlsToTry) {
      try {
        final response = await http
            .post(
              Uri.parse('$url/api/v1/triage/assess'),
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          baseUrl = url;
          _hasResolvedUrl = true;
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          return AssessmentResponseModel.fromJson(data);
        } else {
          lastException = Exception('Server error (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastException = Exception('Failed to connect to $url: $e');
        continue;
      }
    }

    throw lastException ?? Exception('All backend candidate endpoints failed');
  }

  Future<List<EvidenceModel>> retrieveEvidence(String query, {int topK = 4}) async {
    final payload = {'query': query, 'top_k': topK};
    if (!_hasResolvedUrl) {
      await resolveActiveBaseUrl();
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/triage/retrieve'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final list = data['evidence'] as List<dynamic>? ?? [];
        return list.map((e) => EvidenceModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> calculateDosage({
    required String medication,
    required double weightKg,
    double? ageMonths,
  }) async {
    final payload = {
      'medication': medication,
      'weight_kg': weightKg,
      if (ageMonths != null) 'age_months': ageMonths,
    };

    if (!_hasResolvedUrl) {
      await resolveActiveBaseUrl();
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/calculator/dosage'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('Dosage calculator error: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> calculateIvFluids({
    required double weightKg,
    required double ageMonths,
  }) async {
    final payload = {
      'weight_kg': weightKg,
      'age_months': ageMonths,
    };

    if (!_hasResolvedUrl) {
      await resolveActiveBaseUrl();
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/calculator/iv-fluids'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('IV Fluid calculator error: ${response.body}');
    }
  }
}
