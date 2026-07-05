import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../theme/app_theme.dart';
import '../services/pipeline_engine.dart';
import 'glass_card.dart';

class ThinkingResultWidget extends StatelessWidget {
  final PipelineResult result;
  const ThinkingResultWidget({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = AromaticTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildJointReport(context, colors),
        const SizedBox(height: AromaticTheme.spaceSM),
        ...result.modelResults.map((m) => _buildModelCard(context, m, colors)),
        const SizedBox(height: AromaticTheme.spaceMD),
        _buildStatsPanel(context, colors),
      ],
    );
  }

  // ---- 联合报告 (collapsible) ----

  Widget _buildJointReport(BuildContext context, AromaticColors colors) {
    return ExpandableGlassCard(
      title: '\u8054\u5408\u62a5\u544a',
      subtitle: '\u70b9\u51fb\u5c55\u5f00\u67e5\u770b\u5168\u6587',
      initiallyExpanded: false,
      accentColor: colors.accent,
      expandedContent: MarkdownBody(
        data: result.finalReport,
        selectable: true,
        styleSheet: AromaticTheme.markdownStyle(context),
      ),
    );
  }

  // ---- 单个模型卡片 (collapsible) ----

  Widget _buildModelCard(BuildContext context, ModelPhaseResult model, AromaticColors colors) {
    final totalTokens = model.inputTokens + model.outputTokens;
    final subtitle =
        '\u8f93\u5165 ${model.inputTokens} \xb7 \u8f93\u51fa ${model.outputTokens} \xb7 \u8017\u65f6 ${model.elapsed.inMilliseconds}ms';

    return ExpandableGlassCard(
      title: '\U0001f916 ${model.modelName}',
      subtitle: subtitle,
      initiallyExpanded: false,
      accentColor: colors.accent,
      expandedContent: _buildModelDetail(model, colors, context),
    );
  }

  Widget _buildModelDetail(ModelPhaseResult model, AromaticColors colors, BuildContext context) {
    final items = <Widget>[];

    items.add(_sectionTitle('\u72ec\u7acb\u56de\u7b54', colors));
    items.add(const SizedBox(height: AromaticTheme.spaceSM));
    items.add(MarkdownBody(
      data: model.initialAnswer,
      selectable: true,
      styleSheet: AromaticTheme.markdownStyle(context),
    ));

    for (int i = 0; i < model.rounds.length; i++) {
      items.add(const SizedBox(height: AromaticTheme.spaceMD));
      items.add(_sectionTitle('\u4ea4\u53c9\u5ba1\u89c6 \xb7 \u7b2c ${i + 1} \u8f6e', colors));
      items.add(const SizedBox(height: AromaticTheme.spaceSM));
      items.add(MarkdownBody(
        data: model.rounds[i].output,
        selectable: true,
        styleSheet: AromaticTheme.markdownStyle(context),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }

  Widget _sectionTitle(String text, AromaticColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.accent)),
    );
  }

  // ---- 统计面板 ----

  Widget _buildStatsPanel(BuildContext context, AromaticColors colors) {
    final names = result.modelResults.map((m) => m.modelName).join(', ');
    final stats =
        '\u603b token: ${result.totalInputTokens} \u5165 / ${result.totalOutputTokens} \u51fa'
        ' \xb7 \u603b\u8017\u65f6: ${result.totalElapsed.inSeconds}s'
        '\n\u53c2\u4e0e\u6a21\u578b: $names';

    return GlassCard(
      child: Text(stats,
          style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              height: 1.5)),
    );
  }
}
