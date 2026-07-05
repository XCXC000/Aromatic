import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/conversation.dart';
import '../services/conversation_service.dart';

class ConversationLibraryScreen extends StatefulWidget {
  const ConversationLibraryScreen({super.key});

  @override
  State<ConversationLibraryScreen> createState() =>
      _ConversationLibraryScreenState();
}

class _ConversationLibraryScreenState
    extends State<ConversationLibraryScreen> {
  final _svc = ConversationService();
  List<Conversation> _conversations = [];
  Conversation? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _svc.loadAll();
    if (!mounted) return;
    setState(() {
      _conversations = list;
      _loading = false;
      if (_selected != null) {
        final idx = _conversations.indexWhere((c) => c.id == _selected!.id);
        _selected = idx >= 0 ? _conversations[idx] : null;
      }
    });
  }

  Future<void> _deleteConversation(Conversation conv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("删除对话"),
        content: Text("确定删除「${conv.title}」？"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消")),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: AromaticTheme.error),
              child: const Text("删除")),
        ],
      ),
    );
    if (ok == true) {
      await _svc.deleteConversation(conv.id);
      if (_selected?.id == conv.id) _selected = null;
      await _load();
    }
  }

  Future<void> _export(Conversation conv, String format) async {
    final content = format == 'md'
        ? _svc.exportToMarkdown(conv)
        : _svc.exportToText(conv);
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final dir = Directory('$home${Platform.pathSeparator}Aromatic_exports');
    if (!await dir.exists()) await dir.create(recursive: true);
    final safeName = conv.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/$safeName.$format');
    await file.writeAsString(content, flush: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("已导出到: ${file.path}"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final gradient =
        isDark ? AromaticTheme.bgGradientDark : AromaticTheme.bgGradientLight;
    final colors = AromaticTheme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(children: [
            _buildHeader(context, colors),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(children: [
                      _buildLeftPanel(colors, isDark),
                      Container(
                          width: 1,
                          color: colors.border.withValues(alpha: 0.4)),
                      _buildRightPanel(colors),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AromaticColors colors) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AromaticTheme.spaceMD,
            vertical: AromaticTheme.spaceSM + 2),
        decoration: AromaticTheme.barDecoration(brightness),
        child: Row(children: [
          InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 20, color: colors.textSecondary))),
          const SizedBox(width: AromaticTheme.spaceSM),
          Text("对话库",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary)),
        ]),
      ),
    );
  }

  Widget _buildLeftPanel(AromaticColors colors, bool isDark) {
    if (_conversations.isEmpty) {
      return SizedBox(
        width: 280,
        child: Center(
          child: Text("暂无对话记录",
              style: TextStyle(color: colors.textMuted, fontSize: 13)),
        ),
      );
    }

    return SizedBox(
      width: 280,
      child: ListView.builder(
        padding: const EdgeInsets.all(AromaticTheme.spaceSM),
        itemCount: _conversations.length,
        itemBuilder: (_, i) {
          final conv = _conversations[i];
          final selected = _selected?.id == conv.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: selected
                  ? colors.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AromaticTheme.spaceSM, vertical: 2),
              title: Text(conv.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected
                          ? colors.accent
                          : colors.textPrimary)),
              subtitle: Text(
                _formatDate(conv.updatedAt),
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
              trailing: selected
                  ? PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz,
                          size: 16, color: colors.textMuted),
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'delete') _deleteConversation(conv);
                        if (v == 'md') _export(conv, 'md');
                        if (v == 'txt') _export(conv, 'txt');
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'md', child: Text("导出 .md")),
                        const PopupMenuItem(
                            value: 'txt', child: Text("导出 .txt")),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text("删除",
                                style: TextStyle(color: AromaticTheme.error))),
                      ],
                    )
                  : null,
              onTap: () => setState(() => _selected = conv),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightPanel(AromaticColors colors) {
    if (_selected == null) {
      return Expanded(
        child: Center(
          child: Text("选择左侧对话查看详情",
              style: TextStyle(color: colors.textMuted, fontSize: 14)),
        ),
      );
    }

    final conv = _selected!;
    return Expanded(
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AromaticTheme.spaceMD,
              vertical: AromaticTheme.spaceSM + 4),
          decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: colors.border.withValues(alpha: 0.3))),
          ),
          child: Row(children: [
            Expanded(
              child: Text(conv.title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary)),
            ),
            const SizedBox(width: 8),
            Text("${conv.messageCount} 条消息 · ${_formatDate(conv.createdAt)}",
                style: TextStyle(fontSize: 11, color: colors.textMuted)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AromaticTheme.spaceMD),
            itemCount: conv.messages.length,
            itemBuilder: (_, i) {
              final msg = conv.messages[i];
              final isUser = msg.role == 'user';
              return Padding(
                padding: const EdgeInsets.only(bottom: AromaticTheme.spaceMD),
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 4, right: 4, bottom: 4),
                      child: Text(msg.sender,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isUser
                                  ? colors.accent
                                  : colors.textMuted)),
                    ),
                    Container(
                      constraints:
                          const BoxConstraints(maxWidth: 560),
                      padding: const EdgeInsets.all(AromaticTheme.spaceMD),
                      decoration: AromaticTheme.glassDecoration(
                          Theme.of(context).brightness),
                      child: msg.role == 'user'
                          ? Text(msg.content,
                              style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                  height: 1.5))
                          : MarkdownBody(
                              data: msg.content,
                              selectable: true,
                              styleSheet: AromaticTheme.markdownStyle(context),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
