import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'assessment_state.dart';
import '../models/child_model.dart';
import '../models/assessment_model.dart';
import '../models/chat_message_model.dart';
import '../services/hive_service.dart';
import '../services/clinical_api_service.dart';

class AssessmentCubit extends Cubit<AssessmentState> {
  final ClinicalApiService _apiService;

  AssessmentCubit({ClinicalApiService? apiService})
      : _apiService = apiService ?? ClinicalApiService(),
        super(
          AssessmentState.initial(
            children: HiveService.getAllChildren(),
            history: HiveService.getAllAssessments(),
          ),
        );

  void setRole(String role) {
    emit(state.copyWith(selectedRole: role));
  }

  void setBottomNavIndex(int index) {
    emit(state.copyWith(bottomNavIndex: index));
  }

  void selectChild(ChildModel child) {
    emit(state.copyWith(
      activeChild: child,
      chatMessages: [
        ChatMessageModel(
          id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'ai',
          text: 'مرحباً! أنا هنا لمساعدتك وفق دليل منظمة الصحة العالمية (WHO IMCI).\nما الأعراض التي يعاني منها ${child.name}؟',
          timestamp: 'الآن',
        ),
      ],
    ));
  }

  Future<void> addChild(ChildModel child) async {
    await HiveService.saveChild(child);
    final updatedList = HiveService.getAllChildren();
    emit(state.copyWith(
      children: updatedList,
      activeChild: child,
      chatMessages: [
        ChatMessageModel(
          id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'ai',
          text: 'تم إنشاء ملف ${child.name} بنجاح.\nما هي الأعراض التي ترغب في تقييمها؟',
          timestamp: 'الآن',
        ),
      ],
    ));
  }

  Future<void> updateChild(ChildModel child) async {
    await HiveService.saveChild(child);
    final updatedList = HiveService.getAllChildren();
    emit(state.copyWith(children: updatedList, activeChild: child));
  }

  void setCurrentAssessment(AssessmentResponse assessment) {
    emit(state.copyWith(currentAssessment: assessment));
  }

  Future<void> sendChatMessage(String text) async {
    final now = DateFormat('HH:mm').format(DateTime.now());
    final userMsg = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'user',
      text: text,
      timestamp: now,
    );

    final updatedMessages = List<ChatMessageModel>.from(state.chatMessages)..add(userMsg);
    emit(state.copyWith(chatMessages: updatedMessages));
    await HiveService.saveChatMessage(userMsg);
  }

  Future<AssessmentResponse> assessSymptoms({
    required String symptoms,
    required int durationDays,
  }) async {
    emit(state.copyWith(status: AssessmentStatus.loading));

    try {
      final result = await _apiService.assessChild(
        childName: state.activeChild.name,
        ageYears: state.activeChild.age,
        weightKg: state.activeChild.weight,
        symptomsText: symptoms,
        timelineDays: durationDays,
      );

      // Save genuine clinical assessment to Hive local storage
      final nowFormatted = DateFormat('yyyy - MM - dd').format(DateTime.now());
      final record = AssessmentRecordModel(
        id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        childId: state.activeChild.id,
        childName: state.activeChild.name,
        date: nowFormatted,
        chiefComplaint: symptoms.length > 35 ? symptoms.substring(0, 35) + '...' : symptoms,
        durationDays: durationDays,
        triageLevel: result.triageLevel,
        triageLabelAr: result.triageLabelAr,
        symptomsSummary: result.summaryFound,
        missingQuestions: result.missingInfo,
        fullRecommendation: result.fullRecommendation,
        evidenceJson: jsonEncode(result.evidenceList.map((e) => e.toJson()).toList()),
        differentialJson: jsonEncode(result.differentialDiagnoses.map((d) => d.toJson()).toList()),
      );

      await HiveService.saveAssessment(record);
      final updatedHistory = HiveService.getAllAssessments();

      // Add AI response bubble in chat
      final aiFollowUp = ChatMessageModel(
        id: 'ai_res_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'ai',
        text: 'تم تقييم الحالة بناءً على إرشادات WHO IMCI: [${result.triageLabelAr}]',
        timestamp: DateFormat('HH:mm').format(DateTime.now()),
      );
      final updatedChat = List<ChatMessageModel>.from(state.chatMessages)..add(aiFollowUp);

      emit(state.copyWith(
        status: AssessmentStatus.success,
        currentAssessment: result,
        historyList: updatedHistory,
        chatMessages: updatedChat,
      ));

      return result;
    } on ClinicalValidationException catch (validationErr) {
      // Surface the Arabic validation message for SnackBar display
      final errorMsg = ChatMessageModel(
        id: 'ai_err_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'ai',
        text: '⛔ ${validationErr.arabicMessage}',
        timestamp: DateFormat('HH:mm').format(DateTime.now()),
      );
      final updatedChat = List<ChatMessageModel>.from(state.chatMessages)..add(errorMsg);

      emit(state.copyWith(
        status: AssessmentStatus.validationError,
        errorMessage: validationErr.arabicMessage,
        chatMessages: updatedChat,
      ));

      rethrow;
    } catch (e) {
      final errorText = e.toString().replaceAll('Exception: ', '');
      final errorMsg = ChatMessageModel(
        id: 'ai_err_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'ai',
        text: '⚠️ $errorText',
        timestamp: DateFormat('HH:mm').format(DateTime.now()),
      );
      final updatedChat = List<ChatMessageModel>.from(state.chatMessages)..add(errorMsg);

      emit(state.copyWith(
        status: AssessmentStatus.failure,
        errorMessage: errorText,
        chatMessages: updatedChat,
      ));

      rethrow;
    }
  }

  void resetChat() {
    emit(state.copyWith(
      chatMessages: [
        ChatMessageModel(
          id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'ai',
          text: 'مرحباً! أنا هنا لمساعدتك وفق دليل منظمة الصحة العالمية (WHO IMCI).\nما الأعراض التي يعاني منها ${state.activeChild.name}؟',
          timestamp: 'الآن',
        ),
      ],
    ));
  }
}
