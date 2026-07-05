import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/data_pack.dart';

class PackService {
  PackService._();
  static final instance = PackService._();

  static const _enabledKey = 'aromatic_pack_enabled';
  final List<DataPack> _packs = [];
  final Map<String, String> _promptCache = {};
  List<DataPack> get packs => List.unmodifiable(_packs);

  /// Built-in mode IDs that data packs must not conflict with.
  static const _builtInIds = {'aa', 'duel', 'hexad'};

  /// Path to the packs directory.
  static String get packsDir {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return '$home${Platform.pathSeparator}Aromatic_packs';
  }

  /// Scan the packs directory and load valid data packs.
  Future<void> scan() async {
    _packs.clear();
    final dir = Directory(packsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final enabledSet = prefs.getStringList(_enabledKey)?.toSet() ?? <String>{};

    final subdirs = await dir.list().toList();
    for (final entity in subdirs) {
      if (entity is! Directory) continue;
      final packFile = File('${entity.path}${Platform.pathSeparator}pack.json');
      if (!await packFile.exists()) continue;

      try {
        final raw = await packFile.readAsString();
        _loadPackPrompts(entity.path, locale: "en");
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final pack = DataPack.fromJson(entity.path, json);

        if (pack.modes.isEmpty) continue;

        // Validate: no ID conflicts with built-in modes
        final conflict = pack.modes.any((m) => _builtInIds.contains(m.id));
        if (conflict) continue;

        // Restore enable state; defaults to enabled if not previously disabled
        pack.enabled = !enabledSet.contains(pack.name);

        _packs.add(pack);
      } catch (_) {
        // Skip malformed packs silently
      }
    }
  }

  /// Enable or disable a pack by name.
  Future<void> setEnabled(String packName, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_enabledKey)?.toList() ?? [];
    if (enabled) {
      list.remove(packName);
    } else if (!list.contains(packName)) {
      list.add(packName);
    }
    await prefs.setStringList(_enabledKey, list);

    final pack = _packs.firstWhere((p) => p.name == packName, orElse: () => DataPack(path: "", name: packName, version: "", modes: []));
    pack.enabled = enabled;
  }

  /// Get all enabled modes from all enabled packs.
  List<DataPackMode> get enabledModes {
    final result = <DataPackMode>[];
    for (final pack in _packs) {
      if (pack.enabled) {
        result.addAll(pack.modes);
      }
    }
    return result;
  }

  /// Find a pack that contains a given mode ID.
  DataPack? findPackByModeId(String modeId) {
    for (final pack in _packs) {
      for (final mode in pack.modes) {
        if (mode.id == modeId) return pack;
      }
    }
    return null;
  }

  /// Load a prompt file from a pack's prompts directory.
  static Future<String?> loadPrompt(String packPath, String locale, String fileName) async {
    final filePath = '${packPath}${Platform.pathSeparator}prompts${Platform.pathSeparator}$locale${Platform.pathSeparator}$fileName';
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    // Fallback to English
    final enPath = '${packPath}${Platform.pathSeparator}prompts${Platform.pathSeparator}en${Platform.pathSeparator}$fileName';
    final enFile = File(enPath);
    if (await enFile.exists()) {
      return await enFile.readAsString();
    }
    return null;
  }

  /// Preload all prompt files from a pack into memory cache.
  void _loadPackPrompts(String packPath, {String locale = "en"}) {
    final promptsDir = Directory('$packPath${Platform.pathSeparator}prompts');
    if (!promptsDir.existsSync()) return;
    for (final langDir in promptsDir.listSync()) {
      if (langDir is! Directory) continue;
      final lng = langDir.path.split(Platform.pathSeparator).last;
      for (final file in langDir.listSync()) {
        if (file is! File || !file.path.endsWith(".txt")) continue;
        try {
          final content = file.readAsStringSync();
          final key = '$packPath:$lng:${file.path.split(Platform.pathSeparator).last}';
          _promptCache[key] = content;
        } catch (_) {}
      }
    }
  }

  /// Synchronous variant of [loadPrompt] that returns null instead of a Future.
  static String? loadPromptSync(String packPath, String locale, String fileName) {
    final filePath = '${packPath}${Platform.pathSeparator}prompts${Platform.pathSeparator}$locale${Platform.pathSeparator}$fileName';
    final file = File(filePath);
    if (file.existsSync()) {
      return file.readAsStringSync();
    }
    final enPath = '${packPath}${Platform.pathSeparator}prompts${Platform.pathSeparator}en${Platform.pathSeparator}$fileName';
    final enFile = File(enPath);
    if (enFile.existsSync()) {
      return enFile.readAsStringSync();
    }
    return null;
  }
}
