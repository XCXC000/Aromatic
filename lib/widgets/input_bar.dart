import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../services/pack_service.dart';
import '../models/data_pack.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InputBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<List<ApiKey>> onModelsChanged;
  final ValueChanged<int>? onIterationChanged;
  final void Function(String text, List<ApiKey> models, ApiKey? central, int iterations, String mode) onSubmit;
  final bool enabled;

  const InputBar({super.key, this.hintText = "\u8f93\u5165\u4f60\u7684\u95ee\u9898...", required this.onSubmit,
    required this.onModelsChanged, this.onIterationChanged, this.enabled = true});

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _ctrl = TextEditingController(), _focus = FocusNode();
  final _svc = AccountService();
  String _mode = "hexad";
  DataPackMode? _packMode;
  static const _defaultModeKey = 'aromatic_default_mode';
  Keychain? _keychain;
  List<ApiKey> _keys = [];
  ApiKey? _central;
  List<LocalAccount> _accts = [];
  bool _hasText = false;
  int _iteration = 1;

  static const _modes = [
    ("aa", "AA\u6a21\u5f0f", Icons.psychology_outlined),
    ("duel", "\u4e8c\u5143\u5bf9\u7acb", Icons.compare_arrows_outlined),
    ("hexad", "\u516d\u5143\u5206\u53d1", Icons.hub_outlined),
  ];

  int get _max {
    if (_packMode != null) return _packMode!.type == 'aa' ? 1 : _packMode!.type == 'duel' ? 2 : 6;
    return _mode == "aa" ? 1 : _mode == "duel" ? 2 : 6;
  }
  String get _modeLabel {
    if (_packMode != null) return _packMode!.label;
    try {
      return _modes.firstWhere((m) => m.$1 == _mode).$2;
    } catch (_) {
      return '\u516d\u5143\u5206\u53d1';
    }
  }

  IconData get _currentModeIcon {
    try {
      return _modes.firstWhere((m) => m.$1 == _mode).$3;
    } catch (_) {
      return Icons.inventory_2_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final v = _ctrl.text.trim();
      if ((v.isNotEmpty) != _hasText) setState(() => _hasText = v.isNotEmpty);
    });
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_defaultModeKey);
    final accts = await _svc.loadAll();
    if (!mounted) return;
    if (savedMode != null && _modes.any((m) => m.$1 == savedMode)) _mode = savedMode;
    _packMode = null;
    for (final pm in PackService.instance.enabledModes) {
      if (pm.id == _mode) { _packMode = pm; break; }
    }
    setState(() => _accts = accts);

    // Only auto-initialize keychain and active keys on first load;
    // subsequent navigations preserve the user's manual selection.
    if (_keychain != null) return;

    for (final a in accts) for (final kc in a.keychains) if (kc.keys.isNotEmpty) {
      _keychain = kc;
      final active = kc.keys.where((k) => k.isActive).toList();
      if (active.isNotEmpty) { _keys = active.take(_max).toList(); _central = _keys.first; widget.onModelsChanged(_keys); }
      return;
    }
  }

  void _onMode(String m) {
    _packMode = null;
    for (final pm in PackService.instance.enabledModes) {
      if (pm.id == m) { _packMode = pm; break; }
    }
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_defaultModeKey, m));
    setState(() {
      _mode = m;
      if (m == "aa" && _keys.length > 1) _keys = [_keys.first];
      else if (m == "duel" && _keys.length > 2) _keys = _keys.take(2).toList();
      if (_central != null && !_keys.contains(_central)) _central = _keys.isNotEmpty ? _keys.first : null;
      widget.onModelsChanged(_keys);
    });
  }

  void _toggleKey(ApiKey k) {
    setState(() {
      if (_keys.contains(k)) { _keys.remove(k); }
      else {
        if (_mode == "aa") { _keys = [k]; }
        else if (_mode == "duel" && _keys.length >= 2) return;
        else if (_mode == "hexad" && _keys.length >= 6) return;
        _keys.add(k);
      }
      _central = _keys.isEmpty ? null : (!_keys.contains(_central) ? _keys.first : _central);
      widget.onModelsChanged(_keys);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  void _submit() {
    final t = _ctrl.text.trim();
    if (t.isEmpty || !widget.enabled) return;
    if (_keys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("\u8bf7\u5148\u9009\u62e9\u81f3\u5c11\u4e00\u4e2a\u6a21\u578b"), backgroundColor: AromaticTheme.error,
        behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
      return;
    }
    widget.onSubmit(t, _keys, _central, _iteration, _mode); _ctrl.clear(); _focus.unfocus();
  }

  Future<void> _showModeDialog() async {
    final c = AromaticTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final packModes = PackService.instance.enabledModes;
    final r = await showDialog<String>(context: context, builder: (_) =>
      _buildDialog(isDark, c, "\u9009\u62e9\u534f\u4f5c\u6a21\u5f0f", 280, Column(mainAxisSize: MainAxisSize.min,
        children: [
          ..._modes.map((m) => RadioListTile<String>(
            dense: true, value: m.$1, groupValue: _mode,
            title: Row(children: [Icon(m.$3, size: 18, color: _mode == m.$1 ? c.accent : c.textMuted),
              const SizedBox(width: 8), Text(m.$2, style: TextStyle(color: c.textPrimary, fontSize: 13))]),
            activeColor: c.accent, onChanged: (v) => Navigator.pop(context, v),
          )),
          if (packModes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Text('\u6570\u636e\u5305\u6a21\u5f0f',
                  style: TextStyle(fontSize: 11, color: c.textMuted)),
            ),
          ...packModes.map((pm) => RadioListTile<String>(
            dense: true, value: pm.id, groupValue: _mode,
            title: Row(children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: _mode == pm.id ? c.accent : c.textMuted),
              const SizedBox(width: 8),
              Text(pm.label, style: TextStyle(color: c.textPrimary, fontSize: 13)),
            ]),
            activeColor: c.accent, onChanged: (v) => Navigator.pop(context, v),
          )),
        ])));
    if (r != null) _onMode(r);
  }

  Future<void> _showKeychainDialog() async {
    final c = AromaticTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = await showDialog<String>(context: context, builder: (_) =>
      _buildDialog(isDark, c, "\u9009\u62e9\u6a21\u578b\u4e32", 320,
        Column(mainAxisSize: MainAxisSize.min, children: [
          for (final a in _accts) for (final kc in a.keychains)
            RadioListTile<String>(
              dense: true, value: kc.id, groupValue: _keychain?.id,
              title: Text("${a.name} / ${kc.name}", style: TextStyle(
                  color: c.textPrimary, fontSize: 13)),
              subtitle: Text("${kc.keys.length} \u4e2a\u6a21\u578b",
                  style: TextStyle(fontSize: 11, color: c.textMuted)),
              activeColor: c.accent, onChanged: (v) => Navigator.pop(context, v),
            ),
        ])));
    if (r != null) {
      for (final a in _accts) for (final kc in a.keychains) if (kc.id == r)
        { setState(() { _keychain = kc; _keys = []; _central = null; }); widget.onModelsChanged([]); return; }
    }
  }

  Future<void> _showModelDialog() async {
    // Refresh accounts in case user added/removed models in settings
    final accts = await _svc.loadAll();
    if (mounted) setState(() => _accts = accts);

    if (_keychain == null || _keychain!.keys.isEmpty) return;
    final all = _keychain!.keys;
    final c = AromaticTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setD) => _buildDialog(isDark, c, "\u9009\u62e9\u6a21\u578b  ${_keys.length}/$_max", 280,
        Column(mainAxisSize: MainAxisSize.min, children: [
          ...all.map((k) {
            final checked = _keys.any((sk) => sk.id == k.id);
            return CheckboxListTile(
              dense: true,
              title: Text(k.modelName, style: TextStyle(fontSize: 13, color: c.textPrimary)),
              subtitle: Text("${k.format.label} . ${k.modelId}",
                  style: TextStyle(fontSize: 11, color: c.textMuted)),
              value: checked, activeColor: c.accent,
              onChanged: (checked || _keys.length < _max) ? (_) { _toggleKey(k); setD(() {}); } : null,
            );
          }),
          const Divider(height: 1),
          Align(alignment: Alignment.centerRight, child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("\u5b8c\u6210", style: TextStyle(color: c.accent, fontSize: 13)))),
        ])),
    ));
  }

  Future<void> _showCentralDialog() async {
    if (_keys.length < 2) return;
    final c = AromaticTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = await showDialog<String>(context: context, builder: (_) =>
      _buildDialog(isDark, c, "\u9009\u62e9\u4e2d\u592e\u8c03\u7528\u6a21\u578b", 260,
        Column(mainAxisSize: MainAxisSize.min, children: _keys.map((k) => RadioListTile<String>(
          dense: true, value: k.id, groupValue: _central?.id,
          title: Text(k.modelName, style: TextStyle(fontSize: 13, color: c.textPrimary)),
          subtitle: Text("${k.format.label} . ${k.modelId}",
              style: TextStyle(fontSize: 11, color: c.textMuted)),
          activeColor: c.accent, onChanged: (v) => Navigator.pop(context, v),
        )).toList())));
    if (r != null) setState(() { _central = _keys.firstWhere((k) => k.id == r); });
  }

  Future<void> _showIterationDialog() async {
    final c = AromaticTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int selected = _iteration;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => _buildDialog(
        isDark, c, "\u8fed\u4ee3\u6b21\u6570", 260,
        Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Text("\u8fed\u4ee3 $selected",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.accent)),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: c.accent,
              inactiveTrackColor: c.accent.withValues(alpha: 0.2),
              thumbColor: c.accent,
              overlayColor: c.accent.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: selected.toDouble(),
              min: 0, max: 5, divisions: 5,
              label: "$selected",
              onChanged: (v) => setD(() => selected = v.round()),
            ),
          ),
          const SizedBox(height: 8),
          Text("\u6bcf\u8f6e\u4e92\u5ba1\u6d88\u8017\u989d\u5916 token\uff0c\u5efa\u8bae 1-3",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: c.textMuted)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _iteration = selected);
                widget.onIterationChanged?.call(selected);
                Navigator.pop(ctx);
              },
              child: Text("\u786e\u5b9a", style: TextStyle(color: c.accent, fontSize: 13)),
            ),
          ),
        ]),
      ),
      ),
    );
  }

  Widget _buildDialog(bool isDark, AromaticColors c, String title, double w, Widget body) {
    return AlertDialog(
      backgroundColor: isDark ? AromaticTheme.darkOverlay : AromaticTheme.pearlWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AromaticTheme.radiusMD)),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
      content: SizedBox(width: w, child: body),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    final c = AromaticTheme.of(ctx);
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final centralOk = _keys.length >= 2;

    return Center(child: Container(
      width: AromaticTheme.inputMaxWidth,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AromaticTheme.darkOverlay.withValues(alpha: 0.55) : AromaticTheme.pearlWhite.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AromaticTheme.radiusLG),
        border: Border.all(color: c.border.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 4), child: TextField(
          controller: _ctrl, focusNode: _focus, enabled: widget.enabled, maxLines: 5, minLines: 1,
          textInputAction: TextInputAction.newline, onSubmitted: (_) => _submit(),
          style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.5),
          decoration: InputDecoration(hintText: widget.hintText,
              hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
              border: InputBorder.none, isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
        )),
        Padding(padding: const EdgeInsets.fromLTRB(8, 4, 4, 8), child: Row(children: [
          Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _Chip(label: _modeLabel, icon: _currentModeIcon, c: c, onTap: _showModeDialog),
            const SizedBox(width: 6),
            _Chip(label: _keychain?.name ?? "选择模型串", icon: Icons.folder_outlined, c: c, onTap: _showKeychainDialog),
            const SizedBox(width: 6),
            _Chip(label: _keys.isEmpty ? "选择模型" : _keys.length == 1 ? _keys.first.modelName : "${_keys.length} 个模型",
                icon: Icons.smart_toy_outlined, c: c, hl: _keys.isNotEmpty, onTap: _showModelDialog),
            const SizedBox(width: 6),
            _Chip(label: _central?.modelName ?? "中央模型", icon: Icons.center_focus_strong, c: c,
                hl: centralOk, off: !centralOk, onTap: centralOk ? _showCentralDialog : null),
          ]))),
          const SizedBox(width: 8),
          _Chip(label: "迭代 $_iteration", icon: Icons.replay_rounded, c: c,
              hl: true, onTap: _showIterationDialog),
          const SizedBox(width: 4),
          _Icn(icon: Icons.attach_file_outlined, color: c.textMuted, tip: "上传文件", onTap: () {}),
          const SizedBox(width: 4),
          AnimatedContainer(duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _hasText && widget.enabled ? c.accent : c.surfaceOverlay),
            child: IconButton(
              onPressed: _hasText && widget.enabled ? _submit : null,
              icon: Icon(Icons.arrow_upward_rounded, size: 18,
                  color: _hasText && widget.enabled ? (isDark ? AromaticTheme.darkBase : AromaticTheme.pearlWhite) : c.textMuted),
              splashRadius: 18, padding: const EdgeInsets.all(7),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ])),
      ]),
    ));
  }
}

class _Chip extends StatelessWidget {
  final String label; final IconData icon; final AromaticColors c;
  final VoidCallback? onTap; final bool hl, off;
  const _Chip({required this.label, required this.icon, required this.c,
    this.onTap, this.hl = false, this.off = false});

  @override
  Widget build(BuildContext ctx) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: off ? Colors.transparent : hl ? c.accent.withValues(alpha: 0.15) : c.surfaceOverlay.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
        border: Border.all(color: off ? c.border.withValues(alpha: 0.15) : hl ? c.accent.withValues(alpha: 0.4) : c.border.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: off ? c.textMuted.withValues(alpha: 0.3) : hl ? c.accent : c.textMuted),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: TextStyle(fontSize: 12,
            color: off ? c.textMuted.withValues(alpha: 0.3) : hl ? c.accent : c.textSecondary), overflow: TextOverflow.ellipsis)),
      ]),
    );
    if (off) return child;
    if (onTap != null) return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AromaticTheme.radiusSM), child: child);
    return child;
  }
}

class _Icn extends StatelessWidget {
  final IconData icon; final Color color; final String tip; final VoidCallback onTap;
  const _Icn({required this.icon, required this.color, required this.tip, required this.onTap});
  @override
  Widget build(BuildContext ctx) => Tooltip(message: tip,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 18, color: color))));
}


