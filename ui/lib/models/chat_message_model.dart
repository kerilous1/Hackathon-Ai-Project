import 'package:hive/hive.dart';

@HiveType(typeId: 2)
class ChatMessageModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sender; // 'ai' | 'user'

  @HiveField(2)
  final String text;

  @HiveField(3)
  final String timestamp;

  @HiveField(4)
  final bool isOptionPrompt;

  @HiveField(5)
  final List<String> options;

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.isOptionPrompt = false,
    this.options = const [],
  });
}

class ChatMessageModelAdapter extends TypeAdapter<ChatMessageModel> {
  @override
  final int typeId = 2;

  @override
  ChatMessageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessageModel(
      id: fields[0] as String? ?? 'msg_1',
      sender: fields[1] as String? ?? 'ai',
      text: fields[2] as String? ?? '',
      timestamp: fields[3] as String? ?? '',
      isOptionPrompt: fields[4] as bool? ?? false,
      options: (fields[5] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessageModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sender)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.isOptionPrompt)
      ..writeByte(5)
      ..write(obj.options);
  }
}
