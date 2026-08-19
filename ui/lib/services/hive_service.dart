import 'package:hive_flutter/hive_flutter.dart';
import '../models/child_model.dart';
import '../models/assessment_model.dart';
import '../models/chat_message_model.dart';

class HiveService {
  static const String childrenBoxName = 'children_box';
  static const String assessmentsBoxName = 'assessments_box';
  static const String chatBoxName = 'chat_box';

  static Box<ChildModel>? _childrenBox;
  static Box<AssessmentRecordModel>? _assessmentsBox;
  static Box<ChatMessageModel>? _chatBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register TypeAdapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChildModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AssessmentRecordModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ChatMessageModelAdapter());
    }

    _childrenBox = await Hive.openBox<ChildModel>(childrenBoxName);
    _assessmentsBox = await Hive.openBox<AssessmentRecordModel>(assessmentsBoxName);
    _chatBox = await Hive.openBox<ChatMessageModel>(chatBoxName);

    // ZERO MOCK DATA: Boxes start empty if user has not added data yet.
  }

  // Children operations (100% User-Driven)
  static List<ChildModel> getAllChildren() {
    return _childrenBox?.values.toList() ?? [];
  }

  static Future<void> saveChild(ChildModel child) async {
    await _childrenBox?.put(child.id, child);
  }

  static Future<void> deleteChild(String id) async {
    await _childrenBox?.delete(id);
  }

  // Assessment operations (100% Real User Consultations)
  static List<AssessmentRecordModel> getAllAssessments() {
    return _assessmentsBox?.values.toList().reversed.toList() ?? [];
  }

  static Future<void> saveAssessment(AssessmentRecordModel record) async {
    await _assessmentsBox?.put(record.id, record);
  }

  // Chat operations
  static List<ChatMessageModel> getChatHistory() {
    return _chatBox?.values.toList() ?? [];
  }

  static Future<void> saveChatMessage(ChatMessageModel message) async {
    await _chatBox?.put(message.id, message);
  }

  static Future<void> clearChatHistory() async {
    await _chatBox?.clear();
  }
}
