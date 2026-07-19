import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/data_pack.dart';
import '../services/pack_service.dart';
import '../l10n/app_localizations.dart';

class PackScreen extends StatefulWidget {
  const PackScreen({super.key});

  @override
  State<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends State<PackScreen> {
  final _svc = PackService.instance;

  @override
  void initState() {
    super.initState();
    _svc.scan().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openFolder() {
    Process.run('explorer', [PackService.packsDir]);
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
    final packs = _svc.packs;

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
                      padding: const EdgeInsets.all(AromaticTheme.spaceMD),
                      children: [
                        GlassCard(
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 18,
                                color: colors.accent,
                              ),
                              const SizedBox(width: AromaticTheme.spaceSM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.get('packFolder'),
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      PackService.packsDir,
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openFolder,
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: Text(l10n.get('open')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.accent,
                                  side: BorderSide(
                                    color: colors.accent.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AromaticTheme.spaceLG),
                        if (packs.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AromaticTheme.space2XL,
                              ),
                              child: Text(
                                l10n.get('packEmptyHint'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          ...packs.map(
                            (pack) => _buildPackCard(pack, colors, l10n),
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

  Widget _buildPackCard(
    DataPack pack,
    AromaticColors colors,
    AppLocalizations l10n,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: pack.enabled ? colors.accent : colors.textMuted,
              ),
              const SizedBox(width: AromaticTheme.spaceSM),
              Expanded(
                child: Text(
                  pack.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: pack.enabled ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
                ),
                child: Text(
                  'v${pack.version}',
                  style: TextStyle(fontSize: 11, color: colors.accent),
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: pack.enabled,
                onChanged: (v) async {
                  await _svc.setEnabled(pack.name, v);
                  setState(() {});
                },
                activeColor: colors.accent,
              ),
            ],
          ),
          const SizedBox(height: AromaticTheme.spaceSM),
          if (pack.modes.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: pack.modes.map((m) {
                final typeLabel = m.type == 'aa'
                    ? 'AA'
                    : m.type == 'duel'
                    ? l10n.get('modeDuelShort')
                    : l10n.get('modeHexadShort');
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceOverlay.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
                  ),
                  child: Text(
                    '$typeLabel ${l10n.get('dot')} ${m.label}',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                );
              }).toList(),
            ),
        ],
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
              l10n.get('dataPacks'),
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
}
