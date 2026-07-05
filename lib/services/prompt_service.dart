import 'package:flutter/services.dart' show rootBundle;
import 'pack_service.dart';

/// Manages bilingual prompt templates loaded from assets/prompts/{locale}/.
///
/// Usage:
///   await PromptService.instance.load('zh');
///   final prompt = PromptService.instance.render('answer', {'question': '...'});
///   await PromptService.instance.reload('en');
class PromptService {
  PromptService._();
  static final instance = PromptService._();

  String _locale = 'en';
  final Map<String, String> _templates = {};

  String get locale => _locale;

  /// Known prompt file basenames (without .txt).
  static const _names = [
    'answer',
    'cross_examine',
    'central_report',
    'aa_persona_radical_human',
    'aa_persona_radical_stem',
    'aa_persona_conservative_human',
    'aa_persona_conservative_stem',
  ];

  // ---- load / reload ----

  /// Load all prompt templates for [locale] from assets.
  Future<void> load(String locale) async {
    _locale = locale;
    _templates.clear();
    for (final name in _names) {
      final content = await _loadFile(locale, name);
      if (content != null) {
        _templates[name] = content;
      }
    }
  }

  /// Switch language (reloads all templates).
  Future<void> reload(String newLocale) => load(newLocale);

  /// Try to load a single prompt file.
  /// Falls back to English if the requested locale file is missing.
  Future<String?> _loadFile(String locale, String name) async {
    try {
      return await rootBundle.loadString('assets/prompts/$locale/$name.txt');
    } catch (_) {
      if (locale != 'en') {
        try {
          return await rootBundle.loadString('assets/prompts/en/$name.txt');
        } catch (_) {}
      }
      return null;
    }
  }

  // ---- render ----

  /// Replace {key} placeholders in the template named [name] with values from [vars].
  /// Returns the raw template text if the template is not found.
  String render(String name, [Map<String, String> vars = const {}]) {
    String template = _templates[name] ?? _loadFromPacks(name);
    for (final entry in vars.entries) {
      template = template.replaceAll('{${entry.key}}', entry.value);
    }
    return template;
  }

  /// Try to load a prompt from all enabled data packs.
  String _loadFromPacks(String name) {
    for (final pack in PackService.instance.packs) {
      if (!pack.enabled) continue;
      for (final mode in pack.modes) {
        for (final persona in mode.personas) {
          if (persona.promptFile == name ||
              persona.promptFile == '$name.txt') {
            final content = PackService.loadPromptSync(pack.path, _locale, persona.promptFile);
            if (content != null) return content;
          }
        }
      }
    }
    return '';
  }
}
