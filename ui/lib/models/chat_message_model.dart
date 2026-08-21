import 'assessment_model.dart';

class ChatMessageModel {
  final String id;
  final String sender; // 'user' or 'ai' or 'system'
  final String text;
  final String timestamp;
  final AssessmentResponseModel? assessment;
  final bool isTyping;

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.assessment,
    this.isTyping = false,
  });

  bool get isUser => sender == 'user';
  bool get isAi => sender == 'ai';
  bool get isSystem => sender == 'system';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'timestamp': timestamp,
      'assessment': assessment?.toJson(),
      'isTyping': isTyping,
    };
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      sender: json['sender'] as String,
      text: json['text'] as String,
      timestamp: json['timestamp'] as String,
      assessment: json['assessment'] != null
          ? AssessmentResponseModel.fromJson(json['assessment'] as Map<String, dynamic>)
          : null,
      isTyping: json['isTyping'] as bool? ?? false,
    );
  }
}
