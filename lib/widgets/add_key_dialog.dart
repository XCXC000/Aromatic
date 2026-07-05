import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/account.dart';
import '../services/chat_api_client.dart';

enum _ProbeStatus { idle, testing, passed, failed }

class AddKeyDialog extends StatefulWidget {
  final ApiKey? existing;
  const AddKeyDialog({super.key, this.existing});

  @override
  State<AddKeyDialog> createState() => _AddKeyDialogState();
}

class _AddKeyDialogState extends State<AddKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelIdCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late ApiFormat _format;
  late bool _isActive;
  bool _obscureKey = true;

  _ProbeStatus _probeStatus = _ProbeStatus.idle;
  String _probeMessage = "";

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final k = widget.existing;
    _nameCtrl = TextEditingController(text: k?.modelName ?? '');
    _modelIdCtrl = TextEditingController(text: k?.modelId ?? '');
    _baseUrlCtrl = TextEditingController(
        text: k?.baseUrl ?? ApiFormat.openai.defaultUrl);
    _apiKeyCtrl = TextEditingController(text: k?.apiKey ?? '');
    _format = k?.format ?? ApiFormat.openai;
    _isActive = k?.isActive ?? true;

    // 编辑模式下已有凭据，默认视为已验证
    if (isEditing) {
      _probeStatus = _ProbeStatus.passed;
    }

    // 任意字段修改后重置检测状态
    _nameCtrl.addListener(_onFieldChanged);
    _modelIdCtrl.addListener(_onFieldChanged);
    _baseUrlCtrl.addListener(_onFieldChanged);
    _apiKeyCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_probeStatus == _ProbeStatus.passed || _probeStatus == _ProbeStatus.failed) {
      setState(() {
        _probeStatus = isEditing ? _ProbeStatus.passed : _ProbeStatus.idle;
        _probeMessage = "";
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onFieldChanged);
    _modelIdCtrl.removeListener(_onFieldChanged);
    _baseUrlCtrl.removeListener(_onFieldChanged);
    _apiKeyCtrl.removeListener(_onFieldChanged);
    _nameCtrl.dispose();
    _modelIdCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  ApiKey _buildKey() {
    return ApiKey(
      id: widget.existing?.id ?? _uuid.v4(),
      modelName: _nameCtrl.text.trim(),
      modelId: _modelIdCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      format: _format,
      isActive: _isActive,
    );
  }

  Future<void> _runProbe() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _probeStatus = _ProbeStatus.testing;
      _probeMessage = "";
    });
    final result = await ChatApiClient.probe(_buildKey());
    if (!mounted) return;
    setState(() {
      _probeStatus = result.success ? _ProbeStatus.passed : _ProbeStatus.failed;
      _probeMessage = result.message;
      if (result.success && !_isActive) {
        _isActive = true;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!isEditing && _probeStatus != _ProbeStatus.passed) return;
    Navigator.pop(context, _buildKey());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AromaticTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canAdd = isEditing || _probeStatus == _ProbeStatus.passed;

    return AlertDialog(
      backgroundColor:
          isDark ? AromaticTheme.darkOverlay : AromaticTheme.pearlWhite,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AromaticTheme.radiusLG)),
      title: Text(isEditing ? "\u7f16\u8f91\u6a21\u578b" : "\u6dfb\u52a0\u6a21\u578b",
          style: TextStyle(color: colors.textPrimary, fontSize: 18)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFormatRow(colors),
                const SizedBox(height: AromaticTheme.spaceMD),
                _buildTextField(
                    controller: _nameCtrl,
                    label: "\u6a21\u578b\u663e\u793a\u540d",
                    hint: "\u5982: GPT-4o",
                    colors: colors,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "\u5fc5\u586b" : null),
                const SizedBox(height: AromaticTheme.spaceSM),
                _buildTextField(
                    controller: _modelIdCtrl,
                    label: "\u6a21\u578b ID",
                    hint: "\u5982: gpt-4o",
                    colors: colors,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "\u5fc5\u586b" : null),
                const SizedBox(height: AromaticTheme.spaceSM),
                _buildTextField(
                    controller: _baseUrlCtrl,
                    label: "API \u5730\u5740",
                    hint: "https://api.openai.com/v1",
                    colors: colors,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "\u5fc5\u586b" : null),
                const SizedBox(height: AromaticTheme.spaceSM),
                _buildTextField(
                    controller: _apiKeyCtrl,
                    label: "API Key",
                    hint: "sk-...",
                    colors: colors,
                    obscure: _obscureKey,
                    suffix: IconButton(
                        icon: Icon(
                            _obscureKey
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: colors.textMuted),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey)),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "\u5fc5\u586b" : null),
                const SizedBox(height: AromaticTheme.spaceSM),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("\u8bbe\u4e3a\u6d3b\u8dc3",
                      style: TextStyle(
                          color: colors.textPrimary, fontSize: 14)),
                  value: _isActive,
                  activeColor: colors.accent,
                  onChanged: (v) => setState(() => _isActive = v),
                  dense: true,
                ),
                // ---- 测试连接区域 ----
                if (!isEditing) ...[
                  const SizedBox(height: AromaticTheme.spaceSM),
                  _buildProbeSection(colors, isDark),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("\u53d6\u6d88",
                style: TextStyle(color: colors.textMuted))),
        if (!isEditing)
          OutlinedButton(
            onPressed: _probeStatus == _ProbeStatus.testing
                ? null
                : _runProbe,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              side: BorderSide(
                  color: colors.accent.withValues(alpha: 0.4)),
            ),
            child: _probeStatus == _ProbeStatus.testing
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.accent))
                : const Text("\u6d4b\u8bd5\u8fde\u63a5"),
          ),
        FilledButton(
          onPressed: canAdd ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: canAdd ? colors.accent : colors.border,
            foregroundColor: isDark
                ? AromaticTheme.darkBase
                : AromaticTheme.pearlWhite,
          ),
          child: Text(isEditing ? "\u4fdd\u5b58" : "\u6dfb\u52a0"),
        ),
      ],
    );
  }

  Widget _buildProbeSection(AromaticColors colors, bool isDark) {
    final status = _probeStatus;
    Widget indicator;
    Color indicatorColor;

    switch (status) {
      case _ProbeStatus.testing:
        indicator = SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: colors.accent));
        indicatorColor = colors.accent;
        break;
      case _ProbeStatus.passed:
        indicator = const Icon(Icons.check_circle, size: 16,
            color: AromaticTheme.success);
        indicatorColor = AromaticTheme.success;
        break;
      case _ProbeStatus.failed:
        indicator = const Icon(Icons.error, size: 16,
            color: AromaticTheme.error);
        indicatorColor = AromaticTheme.error;
        break;
      case _ProbeStatus.idle:
        indicator = Icon(Icons.info_outline, size: 16,
            color: colors.textMuted);
        indicatorColor = colors.textMuted;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
        border: Border.all(
            color: indicatorColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(children: [
        indicator,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            status == _ProbeStatus.idle
                ? "\u6dfb\u52a0\u524d\u9700\u5148\u6d4b\u8bd5\u8fde\u63a5"
                : status == _ProbeStatus.testing
                    ? "\u6b63\u5728\u68c0\u6d4b\u8fde\u63a5\u2026"
                    : _probeMessage,
            style: TextStyle(
                fontSize: 12,
                color: status == _ProbeStatus.idle
                    ? colors.textMuted
                    : indicatorColor),
          ),
        ),
      ]),
    );
  }

  Widget _buildFormatRow(AromaticColors colors) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: ApiFormat.values.map((f) {
        final selected = _format == f;
        return InkWell(
          onTap: () => setState(() {
            _format = f;
            if (f.defaultUrl.isNotEmpty) _baseUrlCtrl.text = f.defaultUrl;
          }),
          borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? colors.accent.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(AromaticTheme.radiusSM),
              border: Border.all(
                color: selected
                    ? colors.accent.withValues(alpha: 0.35)
                    : colors.border.withValues(alpha: 0.3),
              ),
            ),
            child: Text(f.label,
                style: TextStyle(
                    fontSize: 12,
                    color: selected ? colors.accent : colors.textMuted,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required AromaticColors colors,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(color: colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
        suffixIcon: suffix,
        filled: true,
        fillColor: colors.inputFill.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
            borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
            borderSide:
                BorderSide(color: colors.border.withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
            borderSide: BorderSide(color: colors.accent)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
            borderSide: const BorderSide(color: AromaticTheme.error)),
      ),
    );
  }
}
