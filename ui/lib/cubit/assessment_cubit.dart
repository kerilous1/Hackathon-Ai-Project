import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/child_model.dart';
import '../models/assessment_model.dart';
import '../models/chat_message_model.dart';
import '../models/symptom_timeline_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../utils/offline_imci_engine.dart';
import 'assessment_state.dart';

class AssessmentCubit extends Cubit<AssessmentState> {
  final ApiService _apiService;
  final StorageService _storageService;
  final Uuid _uuid = const Uuid();

  AssessmentCubit({
    ApiService? apiService,
    StorageService? storageService,
  })  : _apiService = apiService ?? ApiService(),
        _storageService = storageService ?? StorageService(),
        super(const AssessmentState());

  Future<void> init() async {
    await _storageService.init();

    final children = _storageService.getAllChildren();
    final assessments = _storageService.getAllAssessments();
    final savedChildId = _storageService.getActiveChildId();
    final role = _storageService.getRole();

    ChildModel? activeChild;
    if (children.isNotEmpty) {
      if (savedChildId != null) {
        activeChild = children.firstWhere(
          (c) => c.id == savedChildId,
          orElse: () => children.first,
        );
      } else {
        activeChild = children.first;
      }
    }

    // Proactive backend health ping
    final isOnline = await _apiService.checkHealth();

    emit(state.copyWith(
      children: children,
      activeChild: activeChild,
      historyAssessments: assessments,
      userRole: role,
      isOffline: !isOnline,
    ));

    if (activeChild != null) {
      loadTimeline(activeChild.id);
      _initWelcomeMessage(activeChild);
    }
  }

  void setRole(String role) {
    _storageService.setRole(role);
    emit(state.copyWith(userRole: role));
  }

  void toggleBilingualMode() {
    emit(state.copyWith(isArabicMode: !state.isArabicMode));
  }

  void selectChild(ChildModel child) {
    _storageService.setActiveChildId(child.id);
    emit(state.copyWith(
      activeChild: child,
      currentAssessment: null,
    ));
    loadTimeline(child.id);
    _initWelcomeMessage(child);
  }

  Future<void> addChild(ChildModel child) async {
    await _storageService.saveChild(child);
    await _storageService.setActiveChildId(child.id);
    final updatedList = _storageService.getAllChildren();

    emit(state.copyWith(
      children: updatedList,
      activeChild: child,
      currentAssessment: null,
    ));
    loadTimeline(child.id);
    _initWelcomeMessage(child);
  }

  Future<void> deleteChild(String childId) async {
    await _storageService.deleteChild(childId);
    final updatedList = _storageService.getAllChildren();
    ChildModel? newActive = updatedList.isNotEmpty ? updatedList.first : null;

    if (newActive != null) {
      await _storageService.setActiveChildId(newActive.id);
      loadTimeline(newActive.id);
      _initWelcomeMessage(newActive);
    }

    emit(state.copyWith(
      children: updatedList,
      activeChild: newActive,
      currentAssessment: null,
    ));
  }

  void loadTimeline(String childId) {
    final entries = _storageService.getTimelineForChild(childId);
    emit(state.copyWith(timelineEntries: entries));
  }

  Future<void> addTimelineEntry(SymptomLogEntry entry) async {
    await _storageService.saveTimelineEntry(entry);
    if (state.activeChild != null) {
      loadTimeline(state.activeChild!.id);
    }
  }

  void _initWelcomeMessage(ChildModel child) {
    final nowTime = DateFormat('HH:mm').format(DateTime.now());
    final welcomeText = state.isArabicMode
        ? 'مرحباً بك! أنا مساعد الفرز السريري الذكي المعتمد على دليل WHO IMCI لطفلك ${child.name} (${child.ageFormattedArabic}، ${child.weightKg} كجم).\n\nما هي الأعراض التي يشتكي منها ${child.name} حالياً؟'
        : 'Hello! I am your WHO IMCI Clinical Triage Assistant for ${child.name} (${child.ageFormattedEnglish}, ${child.weightKg} kg).\n\nWhat symptoms is ${child.name} experiencing?';

    emit(state.copyWith(
      chatMessages: [
        ChatMessageModel(
          id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'ai',
          text: welcomeText,
          timestamp: nowTime,
        ),
      ],
    ));
  }

  void resetChat() {
    if (state.activeChild != null) {
      _initWelcomeMessage(state.activeChild!);
      emit(state.copyWith(currentAssessment: null));
    }
  }

  Future<void> sendMessage(String text) async {
    if (state.activeChild == null) return;
    final child = state.activeChild!;
    final nowTime = DateFormat('HH:mm').format(DateTime.now());

    // Detect language from text
    final hasEnglish = RegExp(r'[a-zA-Z]').hasMatch(text);
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    final isQueryEnglish = hasEnglish && !hasArabic;
    final targetLang = isQueryEnglish ? 'en' : (state.isArabicMode ? 'ar' : 'en');

    // 1. Append user message
    final userMsg = ChatMessageModel(
      id: 'msg_${_uuid.v4()}',
      sender: 'user',
      text: text,
      timestamp: nowTime,
    );

    final typingMsg = ChatMessageModel(
      id: 'typing_ai',
      sender: 'ai',
      text: isQueryEnglish ? 'Evaluating against WHO IMCI Clinical Guidelines...' : 'جاري تقييم الحالة وفق دليل WHO IMCI...',
      timestamp: nowTime,
      isTyping: true,
    );

    final updatedMessages = List<ChatMessageModel>.from(state.chatMessages)
      ..add(userMsg)
      ..add(typingMsg);

    emit(state.copyWith(
      chatMessages: updatedMessages,
      status: AssessmentStatus.loading,
    ));

    AssessmentResponseModel assessmentResult;
    bool isOfflineMode = false;

    try {
      // Try online FastAPI Backend
      assessmentResult = await _apiService.assessClinicalScenario(
        query: text,
        child: child,
        language: targetLang,
      );
      isOfflineMode = false;
    } catch (_) {
      // Automatic Offline Fallback: Deterministic IMCI Engine on device
      isOfflineMode = true;
      assessmentResult = OfflineImciEngine.evaluateLocally(
        query: text,
        child: child,
      );
    }

    // Save to encrypted history
    await _storageService.saveAssessment(assessmentResult);
    final allAssessments = _storageService.getAllAssessments();

    // Also auto-add a symptom timeline entry for today
    final timelineEntry = SymptomLogEntry(
      id: 'log_${_uuid.v4()}',
      childId: child.id,
      date: DateTime.now(),
      temperatureC: text.contains('35.') ? 35.2 : (text.contains('حرارة') || text.contains('fever') ? 38.5 : 37.0),
      coughStatus: text.contains('كحة') || text.contains('cough') ? 'mild' : 'none',
      diarrheaStoolsCount: text.contains('إسهال') || text.contains('diarrhea') ? 3 : 0,
      feedingStatus: text.contains('غير قادر على الشرب') || text.contains('unable to drink') ? 'not_able_to_drink' : 'normal',
      notes: text,
      triageLevel: assessmentResult.triageLevel,
    );
    await addTimelineEntry(timelineEntry);

    // AI Response Message in detected language
    final aiMsgText = (assessmentResult.detectedLanguage == 'en' || isQueryEnglish)
        ? '${assessmentResult.triageLabelEn}\n\n${assessmentResult.fullRecommendation}'
        : '${assessmentResult.triageLabelAr}\n\n${assessmentResult.fullRecommendation}';

    final aiMsg = ChatMessageModel(
      id: 'msg_${_uuid.v4()}',
      sender: 'ai',
      text: aiMsgText,
      timestamp: DateFormat('HH:mm').format(DateTime.now()),
      assessment: assessmentResult,
    );

    final finalMessages = List<ChatMessageModel>.from(state.chatMessages)
      ..removeWhere((m) => m.id == 'typing_ai')
      ..add(aiMsg);

    emit(state.copyWith(
      chatMessages: finalMessages,
      currentAssessment: assessmentResult,
      historyAssessments: allAssessments,
      isOffline: isOfflineMode,
      status: AssessmentStatus.success,
    ));
  }

  /// 0ms Instant Verification Recalculation on Screen 04
  void recalculateWithVerification(String question, bool answer) {
    if (state.currentAssessment == null || state.activeChild == null) return;

    final currentAsmt = state.currentAssessment!;
    final child = state.activeChild!;

    final updatedAnswers = Map<String, bool>.from(currentAsmt.verificationAnswers);
    updatedAnswers[question] = answer;

    // Combine original query with the answered sign
    final querySeed = currentAsmt.summaryFound.join(' ');
    final recalculated = OfflineImciEngine.evaluateLocally(
      query: querySeed,
      child: child,
      verificationAnswers: updatedAnswers,
    );

    emit(state.copyWith(
      currentAssessment: recalculated,
    ));

    // Save updated assessment in Hive
    _storageService.saveAssessment(recalculated);
  }
}
