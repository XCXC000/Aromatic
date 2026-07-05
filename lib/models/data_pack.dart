import 'dart:convert';

class PersonaConfig {
  final String id;
  final String promptFile;

  const PersonaConfig({required this.id, required this.promptFile});

  factory PersonaConfig.fromJson(Map<String, dynamic> json) {
    return PersonaConfig(
      id: json['id'] as String,
      promptFile: json['prompt'] as String,
    );
  }
}

class DataPackMode {
  final String id;
  final String type; // 'aa', 'duel', 'hexad'
  final String label;
  final String labelEn;
  final int defaultIterations;
  final int minIterations;
  final int maxIterations;
  final List<PersonaConfig> personas;

  const DataPackMode({
    required this.id,
    required this.type,
    required this.label,
    required this.labelEn,
    this.defaultIterations = 1,
    this.minIterations = 0,
    this.maxIterations = 5,
    this.personas = const [],
  });

  factory DataPackMode.fromJson(Map<String, dynamic> json) {
    return DataPackMode(
      id: json['id'] as String,
      type: json['type'] as String,
      label: json['label'] as String,
      labelEn: json['label_en'] as String? ?? json['label'] as String,
      defaultIterations: json['iterations']?['default'] as int? ?? 1,
      minIterations: json['iterations']?['min'] as int? ?? 0,
      maxIterations: json['iterations']?['max'] as int? ?? 5,
      personas: (json['personas'] as List<dynamic>?)
              ?.map((e) => PersonaConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isValid =>
      ['aa', 'duel', 'hexad'].contains(type) &&
      id.isNotEmpty &&
      label.isNotEmpty;
}

class DataPack {
  final String path;
  final String name;
  final String version;
  final List<DataPackMode> modes;
  bool enabled;

  DataPack({
    required this.path,
    required this.name,
    required this.version,
    required this.modes,
    this.enabled = true,
  });

  factory DataPack.fromJson(String path, Map<String, dynamic> json) {
    return DataPack(
      path: path,
      name: json['name'] as String,
      version: json['version'] as String? ?? '0.1',
      modes: (json['modes'] as List<dynamic>?)
              ?.map((e) => DataPackMode.fromJson(e as Map<String, dynamic>))
              .where((m) => m.isValid)
              .toList() ??
          [],
    );
  }
}
