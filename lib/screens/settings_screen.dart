import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../l10n/app_localizations.dart'; // 新增
import 'package:shared_preferences/shared_preferences.dart';
import 'account_detail_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool useAcrylic;
  final VoidCallback onToggleAcrylic;
  final String currentLocale;
  final ValueChanged<String> onLocaleChanged;

  const SettingsScreen({
    super.key,
    required this.onToggleTheme,
    required this.useAcrylic,
    required this.onToggleAcrylic,
    required this.currentLocale,
    required this.onLocaleChanged,
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
    setState(() {
      _accounts = accounts;
      _loading = false;
      _defaultMode = prefs.getString(_defaultModeKey) ?? 'hexad';
    });
  }

  Future<void> _addAccount() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.get('newAccountTitle')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.get('accountNameHint'),
            labelText: l10n.get('accountNameLabel'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(l10n.get('create')),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      await _accountService.addAccount(result);
      await _load();
    }
  }

  Future<void> _renameAccount(LocalAccount account) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: account.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.get('renameAccountTitle')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.get('newNameHint')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(l10n.get('confirm')),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && mounted) {
      await _accountService.renameAccount(account.id, newName);
      await _load();
    }
  }

  Future<void> _deleteAccount(LocalAccount account) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.get('deleteAccountTitle')),
        content: Text(
          l10n.get('deleteConfirmContent').replaceAll('{name}', account.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AromaticTheme.error),
            child: Text(l10n.get('delete')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _accountService.deleteAccount(account.id);
      await _load();
    }
  }

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
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: AromaticTheme.contentMaxWidth,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AromaticTheme.spaceMD,
                        vertical: AromaticTheme.spaceSM,
                      ),
                      children: [
                        _sectionTitle(context, l10n.get('accounts')),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.get('localAccounts'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AromaticTheme.spaceSM),
                              if (_loading)
                                const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else if (_accounts.isEmpty)
                                Text(
                                  l10n.get('noAccounts'),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                )
                              else
                                ..._accounts.map(
                                  (a) => _accountTile(context, a, colors, l10n),
                                ),
                              const SizedBox(height: AromaticTheme.spaceMD),
                              FilledButton.icon(
                                onPressed: _addAccount,
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(l10n.get('newAccount')),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.accent,
                                  foregroundColor: isDark
                                      ? AromaticTheme.darkBase
                                      : AromaticTheme.pearlWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AromaticTheme.spaceLG),
                        _sectionTitle(context, l10n.get('collaboration')),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.get('defaultMode'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AromaticTheme.spaceSM),
                              _modeOption(
                                context,
                                colors,
                                l10n.get('modeHexad'),
                                _defaultMode == 'hexad',
                                () => _setDefaultMode('hexad'),
                              ),
                              _modeOption(
                                context,
                                colors,
                                l10n.get('modeDuel'),
                                _defaultMode == 'duel',
                                () => _setDefaultMode('duel'),
                              ),
                              _modeOption(
                                context,
                                colors,
                                l10n.get('modeAA'),
                                _defaultMode == 'aa',
                                () => _setDefaultMode('aa'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AromaticTheme.spaceLG),
                        _sectionTitle(context, l10n.get('appearance')),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.get('theme'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AromaticTheme.spaceSM),
                              Row(
                                children: [
                                  _themeToggle(
                                    context,
                                    colors,
                                    isDark,
                                    Icons.dark_mode_outlined,
                                    l10n.get('dark'),
                                  ),
                                  const SizedBox(width: AromaticTheme.spaceSM),
                                  _themeToggle(
                                    context,
                                    colors,
                                    !isDark,
                                    Icons.light_mode_outlined,
                                    l10n.get('light'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AromaticTheme.spaceSM),
                        GlassCard(
                          child: buildAcrylicSection(context, colors, l10n),
                        ),
                        const SizedBox(height: AromaticTheme.spaceLG),
                        _sectionTitle(context, l10n.get('language')),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.get('interfaceLanguage'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AromaticTheme.spaceSM),
                              _langOption(
                                context,
                                colors,
                                l10n.get('chinese'),
                                widget.currentLocale == 'zh',
                                'zh',
                              ),
                              _langOption(
                                context,
                                colors,
                                l10n.get('english'),
                                widget.currentLocale == 'en',
                                'en',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AromaticTheme.spaceLG),
                        _sectionTitle(context, l10n.get('about')),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Aromatic',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AromaticTheme.spaceXS),
                              Text(
                                l10n.get('version'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AromaticTheme.space2XL),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
              l10n.get('settings'),
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

  Widget _accountTile(
    BuildContext context,
    LocalAccount account,
    AromaticColors colors,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: AromaticTheme.spaceSM),
      decoration: BoxDecoration(
        color: colors.surfaceOverlay.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AromaticTheme.spaceSM,
            vertical: 2,
          ),
          title: Text(
            account.name,
            style: TextStyle(fontSize: 14, color: colors.textPrimary),
          ),
          subtitle: Text(
            l10n
                .get('accountSummary')
                .replaceAll('{chains}', account.keychains.length.toString())
                .replaceAll(
                  '{models}',
                  account.keychains
                      .fold<int>(0, (s, kc) => s + kc.keys.length)
                      .toString(),
                ),
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _deleteAccount(account),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
            ],
          ),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountDetailScreen(
                  accountId: account.id,
                  accountName: account.name,
                ),
              ),
            );
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
      child: Text(
        title,
        style: TextStyle(
          color: AromaticTheme.of(context).textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _modeOption(
    BuildContext context,
    AromaticColors colors,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AromaticTheme.spaceSM),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? colors.accent : colors.textMuted,
            ),
            const SizedBox(width: AromaticTheme.spaceSM),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _themeToggle(
    BuildContext context,
    AromaticColors colors,
    bool active,
    IconData icon,
    String label,
  ) {
    return Expanded(
      child: InkWell(
        onTap: active ? null : widget.onToggleTheme,
        borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AromaticTheme.spaceSM),
          decoration: BoxDecoration(
            color: active
                ? colors.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
            border: Border.all(
              color: active
                  ? colors.accent.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: active ? colors.accent : colors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: active ? colors.accent : colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Column buildAcrylicSection(
    BuildContext context,
    AromaticColors colors,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('acrylic'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AromaticTheme.spaceXS),
                  Text(
                    widget.useAcrylic
                        ? l10n.get('acrylicOn')
                        : l10n.get('acrylicOff'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: widget.useAcrylic,
              onChanged: (_) => widget.onToggleAcrylic(),
              activeColor: colors.accent,
            ),
          ],
        ),
        if (!widget.useAcrylic) ...[
          const SizedBox(height: AromaticTheme.spaceSM),
          Container(
            padding: const EdgeInsets.all(AromaticTheme.spaceSM),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: colors.accent),
                const SizedBox(width: AromaticTheme.spaceSM),
                Expanded(
                  child: Text(
                    l10n.get('acrylicFallback'),
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _langOption(
    BuildContext context,
    AromaticColors colors,
    String label,
    bool selected,
    String localeValue,
  ) {
    return InkWell(
      onTap: selected ? null : () => widget.onLocaleChanged(localeValue),
      borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AromaticTheme.spaceSM),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? colors.accent : colors.textMuted,
            ),
            const SizedBox(width: AromaticTheme.spaceSM),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
