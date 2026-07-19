import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              _buildHeader(context, colors, l10n),
              Expanded(child: _buildTerminalBody(colors, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AromaticColors colors,
    AppLocalizations l10n,
  ) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AromaticTheme.spaceMD,
          vertical: AromaticTheme.spaceSM + 2,
        ),
        decoration: AromaticTheme.barDecoration(brightness),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AromaticTheme.spaceSM),
            Text(
              l10n.get('terminal'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalBody(AromaticColors colors, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(AromaticTheme.spaceMD),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0A14),
        borderRadius: BorderRadius.circular(AromaticTheme.radiusMD),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 终端标题栏（PowerShell 保留不变）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161225),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AromaticTheme.radiusMD - 1),
              ),
            ),
            child: Row(
              children: [
                _dot(const Color(0xFFFF5F57)),
                const SizedBox(width: 6),
                _dot(const Color(0xFFFFBD2E)),
                const SizedBox(width: 6),
                _dot(const Color(0xFF27CA40)),
                const SizedBox(width: 12),
                Text(
                  "PowerShell",
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          // 终端内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _terminalLine("Windows PowerShell", const Color(0xFFC4B5E8)),
                  _terminalLine(
                    l10n.get('terminalCopyright'),
                    const Color(0xFF8888AA),
                  ),
                  const SizedBox(height: 4),
                  _terminalLine("", Colors.transparent),
                  _terminalPrompt(
                    "PS D:\\dev\\aromatic> ",
                    "flutter run -d windows",
                  ),
                  const SizedBox(height: 2),
                  _terminalLine(
                    "Launching lib\\main.dart on Windows in debug mode...",
                    const Color(0xFF7ECB9A),
                  ),
                  _terminalLine(
                    "Building Windows application...",
                    const Color(0xFF7ECB9A),
                  ),
                  _terminalLine(
                    "✓ Built build\\windows\\x64\\runner\\Debug\\aromatic.exe",
                    const Color(0xFF27CA40),
                  ),
                  _terminalLine("", Colors.transparent),
                  _terminalLine(
                    "══════════════════════════════════════════",
                    const Color(0xFF8888AA),
                  ),
                  _terminalLine(
                    "  ${l10n.get('terminalTitle')}",
                    const Color(0xFFC4B5E8),
                  ),
                  _terminalLine(
                    "  ${l10n.get('terminalVersion')}",
                    const Color(0xFF8888AA),
                  ),
                  _terminalLine(
                    "══════════════════════════════════════════",
                    const Color(0xFF8888AA),
                  ),
                  const SizedBox(height: 8),
                  _terminalLine("", Colors.transparent),
                  _terminalPrompt("PS D:\\dev\\aromatic> ", "_"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _terminalLine(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }

  Widget _terminalPrompt(String prompt, String command) {
    return Row(
      children: [
        Text(
          prompt,
          style: const TextStyle(
            color: Color(0xFFC4B5E8),
            fontSize: 13,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
        Text(
          command,
          style: const TextStyle(
            color: Color(0xFFE4DCF0),
            fontSize: 13,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
        const _BlinkingCursor(),
      ],
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _ctrl.value,
      child: Container(
        width: 8,
        height: 15,
        decoration: const BoxDecoration(color: Color(0xFFE4DCF0)),
      ),
    );
  }
}
