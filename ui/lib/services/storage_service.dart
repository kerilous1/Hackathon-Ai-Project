import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/child_model.dart';
import '../models/assessment_model.dart';
import '../models/symptom_timeline_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String childrenBoxName = 'children_box_sec';
  static const String assessmentsBoxName = 'assessments_box_sec';
  static const String timelineBoxName = 'timeline_box_sec';
  static const String settingsBoxName = 'settings_box_sec';

  late Box<String> _childrenBox;
  late Box<String> _assessmentsBox;
  late Box<String> _timelineBox;
  late Box<dynamic> _settingsBox;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await Hive.initFlutter();

    // 256-bit AES Encryption Key derived via SHA-256 for local medical records
    final keyBytes = utf8.encode('PediaCare_WHO_IMCI_Clinical_AES256_SecretKey_2026');
    final encryptionKey = sha256.convert(keyBytes).bytes;
    final cipher = HiveAesCipher(encryptionKey);

    _childrenBox = await Hive.openBox<String>(childrenBoxName, encryptionCipher: cipher);
    _assessmentsBox = await Hive.openBox<String>(assessmentsBoxName, encryptionCipher: cipher);
    _timelineBox = await Hive.openBox<String>(timelineBoxName, encryptionCipher: cipher);
    _settingsBox = await Hive.openBox(settingsBoxName);

    _isInitialized = true;
  }

  // --- CHILDREN ---

  List<ChildModel> getAllChildren() {
    return _childrenBox.values.map((s) => ChildModel.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  Future<void> saveChild(ChildModel child) async {
    await _childrenBox.put(child.id, jsonEncode(child.toJson()));
  }

  Future<void> deleteChild(String id) async {
    await _childrenBox.delete(id);
  }

  // --- ASSESSMENTS ---

  List<AssessmentResponseModel> getAllAssessments() {
    final list = _assessmentsBox.values
        .map((s) => AssessmentResponseModel.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> saveAssessment(AssessmentResponseModel assessment) async {
    await _assessmentsBox.put(assessment.id, jsonEncode(assessment.toJson()));
  }

  Future<void> deleteAssessment(String id) async {
    await _assessmentsBox.delete(id);
  }

  // --- TIMELINE ---

  List<SymptomLogEntry> getTimelineForChild(String childId) {
    final list = _timelineBox.values
        .map((s) => SymptomLogEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .where((e) => e.childId == childId)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> saveTimelineEntry(SymptomLogEntry entry) async {
    await _timelineBox.put(entry.id, jsonEncode(entry.toJson()));
  }

  // --- SETTINGS ---

  String? getActiveChildId() {
    return _settingsBox.get('active_child_id') as String?;
  }

  Future<void> setActiveChildId(String id) async {
    await _settingsBox.put('active_child_id', id);
  }

  String getRole() {
    return _settingsBox.get('user_role', defaultValue: 'parent') as String;
  }

  Future<void> setRole(String role) async {
    await _settingsBox.put('user_role', role);
  }
}
