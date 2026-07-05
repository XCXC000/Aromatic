import 'dart:convert';

// ==================== API 接口格式 ====================
enum ApiFormat {
  openai('OpenAI', 'https://api.openai.com/v1'),
  anthropic('Anthropic', 'https://api.anthropic.com'),
  deepseek('DeepSeek', 'https://api.deepseek.com/v1'),
  moonshot('Moonshot', 'https://api.moonshot.cn/v1'),
  zhipu('GLM', 'https://open.bigmodel.cn/api/paas/v4'),
  qwen('Qwen', 'https://dashscope.aliyuncs.com/compatible-mode/v1'),
  google('Gemini', 'https://generativelanguage.googleapis.com/v1beta'),
  custom('Custom', '');

  const ApiFormat(this.label, this.defaultUrl);
  final String label;
  final String defaultUrl;
}

// ==================== 模型 ====================
class ApiKey {
  final String id;
  String modelName;
  String modelId;
  String baseUrl;
  String apiKey;
  ApiFormat format;
  bool isActive;
  final DateTime createdAt;
  DateTime updatedAt;

  ApiKey({
    required this.id,
    required this.modelName,
    required this.modelId,
    required this.baseUrl,
    required this.apiKey,
    this.format = ApiFormat.openai,
    this.isActive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ApiKey.fromJson(Map<String, dynamic> json) {
    return ApiKey(
      id: json['id'] as String,
      modelName: json['modelName'] as String,
      modelId: json['modelId'] as String,
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String,
      format: ApiFormat.values.firstWhere(
        (f) => f.name == json['format'],
        orElse: () => ApiFormat.openai,
      ),
      isActive: json['isActive'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'modelName': modelName,
        'modelId': modelId,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'format': format.name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  ApiKey copyWith({
    String? modelName,
    String? modelId,
    String? baseUrl,
    String? apiKey,
    ApiFormat? format,
    bool? isActive,
  }) =>
      ApiKey(
        id: id,
        modelName: modelName ?? this.modelName,
        modelId: modelId ?? this.modelId,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        format: format ?? this.format,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

// ==================== 模型串 ====================
class Keychain {
  final String id;
  String name;
  List<ApiKey> keys;
  final DateTime createdAt;

  Keychain({
    required this.id,
    required this.name,
    List<ApiKey>? keys,
    DateTime? createdAt,
  })  : keys = keys ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory Keychain.fromJson(Map<String, dynamic> json) {
    return Keychain(
      id: json['id'] as String,
      name: json['name'] as String,
      keys: (json['keys'] as List<dynamic>?)
              ?.map((e) => ApiKey.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'keys': keys.map((k) => k.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}

// ==================== 本地账户 ====================
class LocalAccount {
  final String id;
  String name;
  List<Keychain> keychains;
  final DateTime createdAt;

  LocalAccount({
    required this.id,
    required this.name,
    List<Keychain>? keychains,
    DateTime? createdAt,
  })  : keychains = keychains ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory LocalAccount.fromJson(Map<String, dynamic> json) {
    return LocalAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      keychains: (json['keychains'] as List<dynamic>?)
              ?.map((e) => Keychain.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'keychains': keychains.map((kc) => kc.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  /// 获取所有活跃的模型（供 Pipeline 使用）
  List<ApiKey> get activeKeys {
    final result = <ApiKey>[];
    for (final kc in keychains) {
      for (final key in kc.keys) {
        if (key.isActive) result.add(key);
      }
    }
    return result;
  }
}
