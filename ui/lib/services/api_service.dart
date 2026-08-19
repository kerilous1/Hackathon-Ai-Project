/// PEDI-GUIDE AI — API Service
/// ============================
/// HTTP client for communicating with the FastAPI backend.

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/clinical_model.dart';

class ApiService {
  /// Base URL for the FastAPI server.
  /// - Android emulator: 10.0.2.2 (maps to host localhost)
  /// - iOS simulator / desktop / web: 127.0.0.1
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  /// Override base URL (e.g. from settings).
  static String? customBaseUrl;

  static String get _effectiveBaseUrl => customBaseUrl ?? baseUrl;

  /// Test connectivity to the backend server.
  static Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$_effectiveBaseUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send a clinical query and receive a structured result.
  static Future<ClinicalResult> analyzeCase({
    required String query,
    String backend = 'chroma',
    int topK = 4,
    double threshold = 43.5,
  }) async {
    final uri = Uri.parse('$_effectiveBaseUrl/api/analyze');

    final body = jsonEncode({
      'query': query,
      'backend': backend,
      'top_k': topK,
      'threshold': threshold,
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return ClinicalResult.fromJson(json as Map<String, dynamic>);
      } else {
        final detail = _extractDetail(response.body);
        return ClinicalResult(
          status: 'error',
          triageLevel: 'REFUSAL',
          responseText: 'Server error (${ response.statusCode}): $detail',
          chunks: [],
          topScore: 0,
          confidence: 'LOW',
          searchQuery: query,
          citedPages: [],
          differentialQuestions: [],
        );
      }
    } catch (e) {
      return ClinicalResult(
        status: 'error',
        triageLevel: 'REFUSAL',
        responseText: 'Connection failed: $e\n\n'
            'Make sure the FastAPI server is running:\n'
            'uvicorn server:app --host 0.0.0.0 --port 8000',
        chunks: [],
        topScore: 0,
        confidence: 'LOW',
        searchQuery: query,
        citedPages: [],
        differentialQuestions: [],
      );
    }
  }

  static String _extractDetail(String body) {
    try {
      final json = jsonDecode(body);
      return json['detail']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}
