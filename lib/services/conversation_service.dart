import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';

class ConversationService {
  static const _key = 'aromatic_conversations_v1';
  final _uuid = const Uuid();

  Future<List<Conversation>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _saveAll(List<Conversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(conversations.map((c) => c.toJson()).toList()));
  }

  Future<Conversation> create(String title) async {
    final conversations = await loadAll();
    final conv = Conversation(id: _uuid.v4(), title: title);
    conversations.insert(0, conv);
    await _saveAll(conversations);
    return conv;
  }

  Future<void> addMessage(String conversationId, ConversationMessage msg,
      {String? updateTitle}) async {
    final conversations = await loadAll();
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx == -1) return;
    final conv = conversations[idx];
    conv.messages.add(msg);
    conv.updatedAt = DateTime.now();
    if (updateTitle != null) conv.title = updateTitle;
    await _saveAll(conversations);
  }

  Future<void> deleteConversation(String conversationId) async {
    final conversations = await loadAll();
    conversations.removeWhere((c) => c.id == conversationId);
    await _saveAll(conversations);
  }

  Future<Conversation?> getById(String id) async {
    final conversations = await loadAll();
    try {
      return conversations.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  String exportToMarkdown(Conversation conv) {
    final buf = StringBuffer();
    buf.writeln('# ${conv.title}');
    buf.writeln('_${conv.createdAt.toIso8601String()}_');
    buf.writeln();
    for (final m in conv.messages) {
      buf.writeln('## ${m.sender}');
      buf.writeln();
      buf.writeln(m.content);
      buf.writeln();
    }
    return buf.toString();
  }

  String exportToText(Conversation conv) {
    final buf = StringBuffer();
    buf.writeln(conv.title);
    buf.writeln(conv.createdAt.toIso8601String());
    buf.writeln('---');
    for (final m in conv.messages) {
      buf.writeln('[${m.sender}]');
      buf.writeln(m.content);
      buf.writeln();
    }
    return buf.toString();
  }
}
