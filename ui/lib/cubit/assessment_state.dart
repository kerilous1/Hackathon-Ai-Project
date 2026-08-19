import '../models/child_model.dart';
import '../models/assessment_model.dart';
import '../models/chat_message_model.dart';

enum AssessmentStatus { initial, loading, success, failure, validationError }

class AssessmentState {
  final AssessmentStatus status;
  final String selectedRole; // 'parent', 'doctor', 'clinic'
  final List<ChildModel> children;
  final ChildModel activeChild;
  final AssessmentResponse? currentAssessment;
  final List<AssessmentRecordModel> historyList;
  final List<ChatMessageModel> chatMessages;
  final int bottomNavIndex;
  final String? errorMessage;

  AssessmentState({
    this.status = AssessmentStatus.initial,
    this.selectedRole = 'parent',
    required this.children,
    required this.activeChild,
    this.currentAssessment,
    required this.historyList,
    required this.chatMessages,
    this.bottomNavIndex = 0,
    this.errorMessage,
  });

  factory AssessmentState.initial({
    required List<ChildModel> children,
    required List<AssessmentRecordModel> history,
  }) {
    final defaultChild = children.isNotEmpty
        ? children.first
        : ChildModel(
            id: 'child_adam',
            name: 'آدم',
            age: 4.0,
            weight: 17.0,
            gender: 'ذكر',
            birthDate: ChildModel.calculateBirthDate(4.0),
            avatarType: 'boy',
          );

    return AssessmentState(
      status: AssessmentStatus.initial,
      selectedRole: 'parent',
      children: children,
      activeChild: defaultChild,
      currentAssessment: null,
      historyList: history,
      chatMessages: [
        ChatMessageModel(
          id: 'welcome_1',
          sender: 'ai',
          text: 'مرحباً بك! أنا مساعدك السريري الذكي المعتمد على إرشادات منظمة الصحة العالمية (WHO IMCI).\nما الأعراض التي يعاني منها ${defaultChild.name}؟',
          timestamp: 'الآن',
        ),
      ],
      bottomNavIndex: 0,
    );
  }

  AssessmentState copyWith({
    AssessmentStatus? status,
    String? selectedRole,
    List<ChildModel>? children,
    ChildModel? activeChild,
    AssessmentResponse? currentAssessment,
    List<AssessmentRecordModel>? historyList,
    List<ChatMessageModel>? chatMessages,
    int? bottomNavIndex,
    String? errorMessage,
  }) {
    return AssessmentState(
      status: status ?? this.status,
      selectedRole: selectedRole ?? this.selectedRole,
      children: children ?? this.children,
      activeChild: activeChild ?? this.activeChild,
      currentAssessment: currentAssessment ?? this.currentAssessment,
      historyList: historyList ?? this.historyList,
      chatMessages: chatMessages ?? this.chatMessages,
      bottomNavIndex: bottomNavIndex ?? this.bottomNavIndex,
      errorMessage: errorMessage,
    );
  }
}
