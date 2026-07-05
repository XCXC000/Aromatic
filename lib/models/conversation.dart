import 'dart:convert';

class ConversationMessage {
  final String role; // 'user' | 'model' | 'system'
  final String sender;
  final String content;
  final DateTime timestamp;

  ConversationMessage({
    required this.role,
    required this.sender,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      role: json['role'] as String,
      sender: json['sender'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'sender': sender,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}

class Conversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  List<ConversationMessage> messages;

  Conversation({
    required this.id,
    required this.title,
    List<ConversationMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) =>
                  ConversationMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  String get preview {
    final firstUser = messages.where((m) => m.role == 'user').firstOrNull;
    if (firstUser != null) {
      final t = firstUser.content.replaceAll('\n', ' ');
      return t.length > 80 ? '${t.substring(0, 80)}…' : t;
    }
    return '';
  }

  int get messageCount => messages.length;
}
