import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/assessment_model.dart';

/// Typed exception for server validation errors (HTTP 400).
/// Carries the Arabic error message from the backend for display in a SnackBar.
class ClinicalValidationException implements Exception {
  final String arabicMessage;
  final int statusCode;

  ClinicalValidationException({
    required this.arabicMessage,
    this.statusCode = 400,
  });

  @override
  String toString() => arabicMessage;
}

/// Typed exception for connection and server errors.
class ClinicalApiException implements Exception {
  final String message;
  final int? statusCode;

  ClinicalApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ClinicalApiService {
  late final Dio _dio;

  ClinicalApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _determineBaseUrl(),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  String _determineBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    if (Platform.isAndroid) {
      // 10.0.2.2 is the special IP for Android emulator host loopback
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  Future<AssessmentResponse> assessChild({
    required String childName,
    required double ageYears,
    required double weightKg,
    required String symptomsText,
    int timelineDays = 1,
    String backend = 'chroma',
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/assess',
        data: {
          'child_name': childName,
          'age_years': ageYears,
          'weight_kg': weightKg,
          'symptoms_text': symptomsText,
          'timeline_days': timelineDays,
          'backend': backend,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return AssessmentResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else {
        throw ClinicalApiException(
          'استجابة غير متوقعة من الخادم (رمز الحالة: ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (dioErr) {
      if (dioErr.type == DioExceptionType.badResponse &&
          dioErr.response != null &&
          dioErr.response!.statusCode == 400) {
        final data = dioErr.response!.data;
        String arabicDetail = 'بيانات غير مطابقة لبروتوكول طب الأطفال IMCI.';
        if (data is Map<String, dynamic> && data.containsKey('detail')) {
          arabicDetail = data['detail'].toString();
        }
        throw ClinicalValidationException(arabicMessage: arabicDetail);
      }

      debugPrint('⚠️ Dio error: ${dioErr.type} — ${dioErr.message}');
      if (dioErr.type == DioExceptionType.receiveTimeout ||
          dioErr.type == DioExceptionType.connectionTimeout) {
        throw ClinicalApiException(
          'انتهت مهلة الاتصال بالخادم (Timeout). يرجى التأكد من تشغيل السيرفر ومن استقرار الشبكة.',
        );
      }

      throw ClinicalApiException(
        'تعذر الاتصال بخادم التقييم السريري (FastAPI على المنفذ 8000).\nيرجى التأكد من تشغيل السيرفر (python server.py).',
        statusCode: dioErr.response?.statusCode,
      );
    } catch (e) {
      if (e is ClinicalValidationException || e is ClinicalApiException) {
        rethrow;
      }
      debugPrint('⚠️ Network/API error: $e');
      throw ClinicalApiException('حدث خطأ أثناء تقييم الحالة السريرية: $e');
    }
  }
}
