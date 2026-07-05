import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../theme/app_theme.dart';
import '../widgets/thinking_result.dart';
import '../widgets/glass_card.dart';
import '../widgets/input_bar.dart';
import '../models/account.dart';
import '../models/conversation.dart';
import '../services/account_service.dart';
import '../services/conversation_service.dart';
import '../services/pack_service.dart';
import '../services/pipeline_engine.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<_ChatBubble> _bubbles = [];
  final ScrollController _scrollController = ScrollController();

  String _accountName = "Aromatic";
  final AccountService _accountService = AccountService();
  final ConversationService _conversationService = ConversationService();
  String? _currentConversationId;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _loadAccountName();
  }

  Future<void> _loadAccountName() async {
    final accounts = await _accountService.loadAll();
    if (!mounted) return;
    setState(() {
      _accountName = accounts.isNotEmpty ? accounts.first.name : "Aromatic";
    });
  }

  void _handleSubmit(String text, List<ApiKey> models, ApiKey? central, int iterations, String mode) async {
    if (_isRunning) return;
    _isRunning = true;
    if (_currentConversationId == null) {
      final title =
          text.length > 30 ? '${text.substring(0, 30)}\u2026' : text;
      final conv = await _conversationService.create(title);
      _currentConversationId = conv.id;
    }

    final userMsg = ConversationMessage(
      role: 'user',
      sender: _accountName,
      content: text,
    );
    await _conversationService.addMessage(_currentConversationId!, userMsg);

    setState(() {
      _bubbles.add(
          _ChatBubble(type: BubbleType.user, content: text));
      _bubbles.add(_ChatBubble(
          type: BubbleType.model,
          sender: "Aromatic",
          content: "\u6a21\u578b\u534f\u4f5c\u8fdb\u884c\u4e2d\u2026",
          isThinking: true));
    });
    _scrollToBottom();
    final thinkIdx = _bubbles.length - 1;

    // Validate model count per mode
    String? validationError;
    if (mode == 'aa') {
      validationError = models.length < 1 ? "AA \u6a21\u5f0f\u9700\u8981 1 \u4e2a\u6a21\u578b" : null;
    } else if (mode == 'duel') {
      validationError = models.length < 2 ? "\u4e8c\u5143\u5bf9\u7acb\u6a21\u5f0f\u81f3\u5c11\u9700\u8981 2 \u4e2a\u6a21\u578b" : null;
    } else if (mode == 'hexad') {
      validationError = models.length < 3 ? "\u516d\u5143\u5206\u53d1\u6a21\u5f0f\u81f3\u5c11\u9700\u8981 3 \u4e2a\u6a21\u578b" : null;
    } else {
      validationError = "\u672a\u77e5\u7684\u534f\u4f5c\u6a21\u5f0f: $mode";
    }

    if (validationError != null) {
      if (!mounted) return;
      setState(() {
        _bubbles.removeAt(thinkIdx);
        _bubbles.add(_ChatBubble(
          type: BubbleType.error,
          sender: "\u9519\u8bef",
          content: validationError!,
        ));
      });
      _isRunning = false;
      return;
    }

    try {
      final PipelineResult result;
      final matching = PackService.instance.enabledModes.where((m) => m.id == mode);
      final packMode = matching.isNotEmpty ? matching.first : null;
      if (packMode != null && packMode.type == 'aa') {
        result = await PipelineEngine.runAA(
          model: models.first,
          question: text,
          iterations: iterations,
          personaIds: packMode.personas.map((p) => p.promptFile.replaceAll('.txt', '')).toList(),
          personaLabels: packMode.personas.map((p) => p.id).toList(),
        );
      } else if (mode == 'hexad') {
        result = await PipelineEngine.runHexad(
          models: models,
          central: central ?? models.first,
          question: text,
          iterations: iterations,
        );
      } else if (mode == 'aa') {
        result = await PipelineEngine.runAA(
          model: models.first,
          question: text,
          iterations: iterations,
        );
      } else {
        result = await PipelineEngine.runBinary(
          models: models,
          central: central ?? models.first,
          question: text,
          iterations: iterations,
        );
      }

      if (!mounted) return;
      setState(() {
        _bubbles.removeAt(thinkIdx);
        _bubbles.add(_ChatBubble(
          type: BubbleType.result,
          sender: "Aromatic",
          content: result.finalReport,
          result: result,
        ));
      });
      _scrollToBottom();

      // Save to conversation
      for (final m in result.modelResults) {
        final buf = StringBuffer();
        buf.writeln('### \U0001f916 ${m.modelName}');
        buf.writeln();
        buf.writeln('**\u72ec\u7acb\u56de\u7b54**');
        buf.writeln(m.initialAnswer);
        buf.writeln();
        for (int r = 0; r < m.rounds.length; r++) {
          buf.writeln('**\u4ea4\u53c9\u5ba1\u89c6 \xb7 \u7b2c ${r + 1} \u8f6e**');
          buf.writeln(m.rounds[r].output);
          buf.writeln();
        }
        await _conversationService.addMessage(
          _currentConversationId!,
          ConversationMessage(
            role: 'model',
            sender: m.modelName,
            content: buf.toString(),
          ),
        );
      }
      await _conversationService.addMessage(
        _currentConversationId!,
        ConversationMessage(
          role: 'model',
          sender: '\u8054\u5408\u62a5\u544a',
          content: '\U0001f4c4 **\u8054\u5408\u62a5\u544a**\n\n${result.finalReport}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bubbles.removeAt(thinkIdx);
        _bubbles.add(_ChatBubble(
          type: BubbleType.error,
          sender: "\u9519\u8bef",
          content: "$e",
        ));
      });
    }
    _isRunning = false;
    if (mounted) setState(() {});
  }

  void _newConversation() {
    setState(() {
      _bubbles.clear();
      _currentConversationId = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final gradient = isDark
        ? AromaticTheme.bgGradientDark
        : AromaticTheme.bgGradientLight;
    final colors = AromaticTheme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, isDark, colors),
              Expanded(
                child: _bubbles.isEmpty
                    ? _buildEmptyState(context, colors)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AromaticTheme.spaceMD,
                            vertical: AromaticTheme.spaceMD),
                        itemCount: _bubbles.length,
                        itemBuilder: (_, i) => _ChatBubbleWidget(
                            bubble: _bubbles[i],
                            userSenderName: _accountName),
                      ),
              ),
              InputBar(
                hintText: "\u8f93\u5165\u4f60\u7684\u95ee\u9898...",
              onSubmit: _handleSubmit,
              enabled: !_isRunning,
               onModelsChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, bool isDark, AromaticColors colors) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AromaticTheme.spaceMD,
            vertical: AromaticTheme.spaceSM + 2),
        decoration: AromaticTheme.barDecoration(brightness),
        child: Row(
          children: [
            _AccountAvatar(
                colors: colors,
                onNavigated: () {
                  _loadAccountName();
                }),
            const SizedBox(width: AromaticTheme.spaceSM + 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(_accountName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _NavButton(
                        label: "对话库",
                        colors: colors,
                        onTap: () async {
                          await Navigator.pushNamed(context, "/conversations");
                        }),
                    const SizedBox(width: 2),
                    _NavButton(
                        label: "数据包",
                        colors: colors,
                        onTap: () async {
                          await Navigator.pushNamed(context, "/packs");
                        }),
                    const SizedBox(width: 2),
                    _NavButton(
                        label: "终端",
                        colors: colors,
                        onTap: () async {
                          await Navigator.pushNamed(context, "/terminal");
                        }),
                    const SizedBox(width: 2),
                    InkWell(
                      onTap: _newConversation,
                      borderRadius:
                          BorderRadius.circular(AromaticTheme.radiusSM),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        child: Icon(Icons.add,
                            size: 18, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _HeaderIcon(
                icon: isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                tooltip: isDark ? "浅色模式" : "深色模式",
                colors: colors,
                onTap: widget.onToggleTheme),
            const SizedBox(width: 4),
            _HeaderIcon(
                icon: Icons.settings_outlined,
                tooltip: "设置",
                colors: colors,
                onTap: () async {
                  await Navigator.pushNamed(context, "/settings");
                  _loadAccountName();
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AromaticColors colors) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AromaticTheme.spaceXL),
        child: Text(
            "\u8f93\u5165\u4f60\u7684\u95ee\u9898\uff0c\u591a\u4e2a AI \u6a21\u578b\u5c06\u5e76\u884c\u56de\u7b54\u3001\u76f8\u4e92\u5ba1\u89c6\u3001\u8054\u5408\u51b3\u7b56",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

enum BubbleType { user, model, system, error, result }

class _ChatBubble {
  final BubbleType type;
  final String? sender;
  final String content;
  final bool isThinking;
  final PipelineResult? result;

  _ChatBubble({
    required this.type,
    this.sender,
    required this.content,
    this.isThinking = false,
    this.result,
  });
}

class _ChatBubbleWidget extends StatelessWidget {
  final _ChatBubble bubble;
  final String userSenderName;

  const _ChatBubbleWidget(
      {required this.bubble, required this.userSenderName});

  @override
  Widget build(BuildContext context) {
    final colors = AromaticTheme.of(context);
    final isUser = bubble.type == BubbleType.user;
    final isError = bubble.type == BubbleType.error;
    final isResult = bubble.type == BubbleType.result;
    final displaySender = isUser
        ? userSenderName
        : (bubble.sender ?? "Aromatic");

    return Padding(
      padding: const EdgeInsets.only(bottom: AromaticTheme.spaceMD),
      child: Center(
        child: SizedBox(
          width: AromaticTheme.inputMaxWidth,
          child: Column(
            crossAxisAlignment: isError
                ? CrossAxisAlignment.center
                : isUser
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
            children: [
              if (!isError)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                  child: Text(displaySender,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isUser
                              ? colors.accent
                              : colors.textMuted)),
                ),
              GlassCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isResult && bubble.result != null)
                        ThinkingResultWidget(result: bubble.result!)
                      else ...[
                      isError
                          ? Text(bubble.content,
                              style: const TextStyle(
                                  color: AromaticTheme.error, fontSize: 14, height: 1.5))
                          : MarkdownBody(
                              data: bubble.content,
                              selectable: true,
                              styleSheet: AromaticTheme.markdownStyle(context),
                            ),
                      ],
                      if (!isResult) ...[
                      if (bubble.isThinking) ...[
                        const SizedBox(height: AromaticTheme.spaceSM),
                        Row(children: [
                          SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: colors.textMuted)),
                          const SizedBox(width: AromaticTheme.spaceSM),
                          Text(
                              "\u6a21\u578b\u534f\u4f5c\u8fdb\u884c\u4e2d\u2026",
                              style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 12)),
                        ]),
                      ],
                      if (bubble.type == BubbleType.system) ...[
                        const SizedBox(height: AromaticTheme.spaceSM),
                        const Divider(height: 1),
                        const SizedBox(height: AromaticTheme.spaceSM),
                        Text(bubble.content,
                            style: TextStyle(
                                color: colors.textMuted, fontSize: 11)),
                      ],
                      ],
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  final VoidCallback? onNavigated;
  final AromaticColors colors;

  const _AccountAvatar({required this.colors, this.onNavigated});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
        message: "\u8d26\u6237",
        child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, "/settings")
                  .then((_) => onNavigated?.call());
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withValues(alpha: 0.18),
                    border: Border.all(
                        color:
                            colors.accent.withValues(alpha: 0.35),
                        width: 1)),
                child: Icon(Icons.person_outline_rounded,
                    size: 16, color: colors.accent))));
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final AromaticColors colors;
  final VoidCallback onTap;

  const _NavButton(
      {required this.label,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, color: colors.textSecondary)),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final AromaticColors colors;
  final VoidCallback onTap;

  const _HeaderIcon(
      {required this.icon,
      required this.tooltip,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
        message: tooltip,
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(icon,
                    size: 20, color: colors.textSecondary))));
  }
}


