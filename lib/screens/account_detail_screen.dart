import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/add_key_dialog.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../l10n/app_localizations.dart';

class AccountDetailScreen extends StatefulWidget {
  final String accountId;
  final String accountName;
  const AccountDetailScreen({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final _service = AccountService();
  LocalAccount? _account;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await _service.loadAll();
    if (!mounted) return;
    setState(() {
      _account = accounts.firstWhere(
        (a) => a.id == widget.accountId,
        orElse: () => LocalAccount(id: "", name: ""),
      );
      _loading = false;
    });
  }

  Future<void> _renameKeychain(Keychain keychain) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: keychain.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.get('renameKeychainTitle')),
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
      await _service.renameKeychain(widget.accountId, keychain.id, newName);
      await _load();
    }
  }

  Future<void> _deleteKeychain(Keychain keychain) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.get('deleteKeychainTitle')),
        content: Text(
          l10n.get('deleteKeychainConfirm').replaceAll('{name}', keychain.name),
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
      await _service.deleteKeychain(widget.accountId, keychain.id);
      await _load();
    }
  }

  Future<void> _addKey(Keychain keychain) async {
    final result = await showDialog<ApiKey>(
      context: context,
      builder: (_) => const AddKeyDialog(),
    );
    if (result == null || !mounted) return;
    await _service.addKey(widget.accountId, keychain.id, result);
    await _load();
  }

  Future<void> _editKey(Keychain keychain, ApiKey key) async {
    final result = await showDialog<ApiKey>(
      context: context,
      builder: (_) => AddKeyDialog(existing: key),
    );
    if (result == null || !mounted) return;
    await _service.updateKey(widget.accountId, keychain.id, result);
    await _load();
  }

  Future<void> _deleteKey(Keychain keychain, ApiKey key) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.get('deleteModelTitle')),
        content: Text(
          l10n.get('deleteModelConfirm').replaceAll('{name}', key.modelName),
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
      await _service.deleteKey(widget.accountId, keychain.id, key.id);
      await _load();
    }
  }

  Future<void> _toggleActive(Keychain keychain, ApiKey key) async {
    if (key.isActive) return;
    await _service.setKeyActive(widget.accountId, keychain.id, key.id);
    await _load();
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
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _account == null || _account!.id.isEmpty
                        ? Center(child: Text(l10n.get('accountNotFound')))
                        : ListView(
                            padding: const EdgeInsets.all(
                              AromaticTheme.spaceMD,
                            ),
                            children: [
                              for (final kc in _account!.keychains)
                                _buildKeychainCard(
                                  context,
                                  kc,
                                  colors,
                                  isDark,
                                  l10n,
                                ),
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
            Expanded(
              child: Text(
                widget.accountName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeychainCard(
    BuildContext context,
    Keychain keychain,
    AromaticColors colors,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AromaticTheme.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 16, color: colors.accent),
              const SizedBox(width: AromaticTheme.spaceSM),
              GestureDetector(
                onTap: () => _renameKeychain(keychain),
                child: Text(
                  keychain.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Spacer(),
              Text(
                l10n
                    .get('modelCount')
                    .replaceAll('{count}', keychain.keys.length.toString()),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _deleteKeychain(keychain),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (keychain.keys.isEmpty) ...[
            const SizedBox(height: AromaticTheme.spaceMD),
            Text(
              l10n.get('keychainEmpty'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else
            ...keychain.keys.map(
              (key) => _buildKeyTile(context, keychain, key, colors, l10n),
            ),
          const SizedBox(height: AromaticTheme.spaceMD),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _addKey(keychain),
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.get('addModel')),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.accent,
                side: BorderSide(color: colors.accent.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyTile(
    BuildContext context,
    Keychain keychain,
    ApiKey key,
    AromaticColors colors,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: AromaticTheme.spaceSM),
      padding: const EdgeInsets.all(AromaticTheme.spaceSM + 2),
      decoration: BoxDecoration(
        color: colors.surfaceOverlay.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleActive(keychain, key),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: key.isActive ? AromaticTheme.success : colors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AromaticTheme.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key.modelName,
                  style: TextStyle(fontSize: 14, color: colors.textPrimary),
                ),
                Text(
                  "${key.format.label} · ${key.modelId}",
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _editKey(keychain, key),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.edit_outlined,
                size: 16,
                color: colors.textMuted,
              ),
            ),
          ),
          InkWell(
            onTap: () => _deleteKey(keychain, key),
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
        ],
      ),
    );
  }
}
