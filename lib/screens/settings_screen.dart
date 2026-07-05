import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_detail_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool useAcrylic;
  final VoidCallback onToggleAcrylic;
  const SettingsScreen({
    super.key,
    required this.onToggleTheme,
    required this.useAcrylic,
    required this.onToggleAcrylic,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _defaultModeKey = 'aromatic_default_mode';
  final _accountService = AccountService();
  List<LocalAccount> _accounts = [];
  bool _loading = true;
  String _defaultMode = 'hexad';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await _accountService.loadAll();
    if (!mounted) return;
    setState(() { _accounts = accounts; _loading = false; _defaultMode = prefs.getString(_defaultModeKey) ?? 'hexad'; });
  }

  Future<void> _addAccount() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("新建本地账户"),
        content: TextField(controller: ctrl, autofocus: true,
            decoration: const InputDecoration(hintText: "账户名称", labelText: "名称")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text("创建")),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      await _accountService.addAccount(result);
      await _load();
    }
  }

  Future<void> _renameAccount(LocalAccount account) async {
    final ctrl = TextEditingController(text: account.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("重命名账户"),
        content: TextField(controller: ctrl, autofocus: true,
            decoration: const InputDecoration(hintText: "新名称")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text("确定")),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && mounted) {
      await _accountService.renameAccount(account.id, newName);
      await _load();
    }
  }

  Future<void> _deleteAccount(LocalAccount account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("注销账户"),
        content: Text("确定要删除「${account.name}」吗？\n该账户下所有模型串和模型将被永久删除。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AromaticTheme.error), child: const Text("注销")),
        ],
      ),
    );
    if (ok == true && mounted) { await _accountService.deleteAccount(account.id); await _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final gradient = isDark ? AromaticTheme.bgGradientDark : AromaticTheme.bgGradientLight;
    final colors = AromaticTheme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(children: [
            _buildHeader(context, colors),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: AromaticTheme.contentMaxWidth,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: AromaticTheme.spaceMD, vertical: AromaticTheme.spaceSM),
                    children: [
                      _sectionTitle(context, "账户"),
                      GlassCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text("本地账户", style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AromaticTheme.spaceSM),
                          if (_loading)
                            const Center(child: SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2)))
                          else if (_accounts.isEmpty)
                            Text("尚未创建账户", style: Theme.of(context).textTheme.bodyMedium)
                          else
                            ..._accounts.map((a) => _accountTile(context, a, colors)),
                          const SizedBox(height: AromaticTheme.spaceMD),
                          FilledButton.icon(
                            onPressed: _addAccount, icon: const Icon(Icons.add, size: 18),
                            label: const Text("新建账户"),
                            style: FilledButton.styleFrom(backgroundColor: colors.accent,
                                foregroundColor: isDark ? AromaticTheme.darkBase : AromaticTheme.pearlWhite),
                          ),
                        ]),
                      ),
                      const SizedBox(height: AromaticTheme.spaceLG),
                      _sectionTitle(context, "协作"),
                      GlassCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text("默认模式", style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AromaticTheme.spaceSM),
                          _modeOption(context, colors, "六元分发 (3-6 模型)", _defaultMode == 'hexad', () => _setDefaultMode('hexad')),
                          _modeOption(context, colors, "二元对立 (2+N)", _defaultMode == 'duel', () => _setDefaultMode('duel')),
                          _modeOption(context, colors, "单 Agent 辩论", _defaultMode == 'aa', () => _setDefaultMode('aa')),
                        ]),
                      ),
                      const SizedBox(height: AromaticTheme.spaceLG),
                      _sectionTitle(context, "外观"),
                      GlassCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text("主题", style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AromaticTheme.spaceSM),
                          Row(children: [
                            _themeToggle(context, colors, isDark, Icons.dark_mode_outlined, "深色"),
                            const SizedBox(width: AromaticTheme.spaceSM),
                            _themeToggle(context, colors, !isDark, Icons.light_mode_outlined, "浅色"),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: AromaticTheme.spaceSM),
                      GlassCard(child: buildAcrylicSection(context, colors)),
                      const SizedBox(height: AromaticTheme.spaceLG),
                      _sectionTitle(context, "语言"),
                      GlassCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text("界面语言", style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AromaticTheme.spaceSM),
                          _langOption(context, colors, "中文", true),
                          _langOption(context, colors, "English", false),
                        ]),
                      ),
                      const SizedBox(height: AromaticTheme.spaceLG),
                      _sectionTitle(context, "关于"),
                      GlassCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text("Aromatic", style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AromaticTheme.spaceXS),
                          Text("多模型协作思考平台 v0.1.0", style: Theme.of(context).textTheme.bodyMedium),
                        ]),
                      ),
                      const SizedBox(height: AromaticTheme.space2XL),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _setDefaultMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultModeKey, mode);
    if (!mounted) return;
  setState(() => _defaultMode = mode);
  }

  Widget _buildHeader(BuildContext context, AromaticColors colors) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AromaticTheme.spaceMD, vertical: AromaticTheme.spaceSM + 2),
        decoration: AromaticTheme.barDecoration(brightness),
        child: Row(children: [
          InkWell(onTap: () => Navigator.pop(context), borderRadius: BorderRadius.circular(20),
              child: Padding(padding: const EdgeInsets.all(6),
                  child: Icon(Icons.arrow_back_rounded, size: 20, color: colors.textSecondary))),
          const SizedBox(width: AromaticTheme.spaceSM),
          Text("设置", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        ]),
      ),
    );
  }

  Widget _accountTile(BuildContext context, LocalAccount account, AromaticColors colors) {
    return Container(
      margin: const EdgeInsets.only(top: AromaticTheme.spaceSM),
      decoration: BoxDecoration(
        color: colors.surfaceOverlay.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AromaticTheme.spaceSM, vertical: 2),
        title: Text(account.name, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
        subtitle: Text(
          "${account.keychains.length} 个模型串 · ${account.keychains.fold<int>(0, (s, kc) => s + kc.keys.length)} 个模型",
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(onTap: () => _deleteAccount(account), borderRadius: BorderRadius.circular(16),
              child: Padding(padding: const EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline, size: 16, color: colors.textMuted))),
          Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
        ]),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => AccountDetailScreen(accountId: account.id, accountName: account.name),
          ));
          _load();
        },
        onLongPress: () => _renameAccount(account),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AromaticTheme.spaceSM, left: 4),
      child: Text(title, style: TextStyle(color: AromaticTheme.of(context).textMuted,
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
    );
  }

  Widget _modeOption(BuildContext context, AromaticColors colors, String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: selected ? null : onTap, borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AromaticTheme.spaceSM),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18, color: selected ? colors.accent : colors.textMuted),
          const SizedBox(width: AromaticTheme.spaceSM),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ),
    );
  }

  Widget _themeToggle(BuildContext context, AromaticColors colors, bool active, IconData icon, String label) {
    return Expanded(
      child: InkWell(
        onTap: active ? null : widget.onToggleTheme, borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AromaticTheme.spaceSM),
          decoration: BoxDecoration(
            color: active ? colors.accent.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
            border: Border.all(color: active ? colors.accent.withValues(alpha: 0.3) : Colors.transparent),
          ),
          child: Column(children: [
            Icon(icon, size: 22, color: active ? colors.accent : colors.textMuted),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: active ? colors.accent : colors.textMuted)),
          ]),
        ),
      ),
    );
  }

  Column buildAcrylicSection(BuildContext context, AromaticColors colors) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("窗口半透明", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AromaticTheme.spaceXS),
          Text(widget.useAcrylic ? "亚克力模糊 — Windows / macOS" : "纯色降级 — 旧版 Win / Linux",
              style: Theme.of(context).textTheme.labelSmall),
        ])),
        Switch(value: widget.useAcrylic, onChanged: (_) => widget.onToggleAcrylic(), activeColor: colors.accent),
      ]),
      if (!widget.useAcrylic) ...[
        const SizedBox(height: AromaticTheme.spaceSM),
        Container(
          padding: const EdgeInsets.all(AromaticTheme.spaceSM),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, size: 16, color: colors.accent),
            const SizedBox(width: AromaticTheme.spaceSM),
            Expanded(child: Text("当前系统不支持半透明效果时自动使用此模式",
                style: TextStyle(fontSize: 12, color: colors.textSecondary))),
          ]),
        ),
      ],
    ]);
  }

  Widget _langOption(BuildContext context, AromaticColors colors, String label, bool selected) {
    return InkWell(
      onTap: () {}, borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AromaticTheme.spaceSM),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18, color: selected ? colors.accent : colors.textMuted),
          const SizedBox(width: AromaticTheme.spaceSM),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ),
    );
  }
}
