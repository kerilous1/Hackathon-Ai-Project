import '../models/child_model.dart';
import '../models/assessment_model.dart';
import '../models/chat_message_model.dart';
import '../models/symptom_timeline_model.dart';

enum AssessmentStatus { initial, loading, success, error }

class AssessmentState {
  final AssessmentStatus status;
  final ChildModel? activeChild;
  final List<ChildModel> children;
  final List<ChatMessageModel> chatMessages;
  final AssessmentResponseModel? currentAssessment;
  final List<AssessmentResponseModel> historyAssessments;
  final List<SymptomLogEntry> timelineEntries;
  final bool isOffline;
  final bool isArabicMode;
  final String userRole; // 'parent', 'doctor', 'clinic'
  final String? errorMessage;

  const AssessmentState({
    this.status = AssessmentStatus.initial,
    this.activeChild,
    this.children = const [],
    this.chatMessages = const [],
    this.currentAssessment,
    this.historyAssessments = const [],
    this.timelineEntries = const [],
    this.isOffline = false,
    this.isArabicMode = true,
    this.userRole = 'parent',
    this.errorMessage,
  });

  bool get isLoading => status == AssessmentStatus.loading;
  bool get hasActiveChild => activeChild != null;

  AssessmentState copyWith({
    AssessmentStatus? status,
    ChildModel? activeChild,
    List<ChildModel>? children,
    List<ChatMessageModel>? chatMessages,
    AssessmentResponseModel? currentAssessment,
    List<AssessmentResponseModel>? historyAssessments,
    List<SymptomLogEntry>? timelineEntries,
    bool? isOffline,
    bool? isArabicMode,
    String? userRole,
    String? errorMessage,
  }) {
    return AssessmentState(
      status: status ?? this.status,
      activeChild: activeChild ?? this.activeChild,
      children: children ?? this.children,
      chatMessages: chatMessages ?? this.chatMessages,
      currentAssessment: currentAssessment ?? this.currentAssessment,
      historyAssessments: historyAssessments ?? this.historyAssessments,
      timelineEntries: timelineEntries ?? this.timelineEntries,
      isOffline: isOffline ?? this.isOffline,
      isArabicMode: isArabicMode ?? this.isArabicMode,
      userRole: userRole ?? this.userRole,
      errorMessage: errorMessage,
    );
  }
}
