import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/account.dart';

class ProbeResult {
  final bool success;
  final String message;

  const ProbeResult({required this.success, required this.message});
}

class ChatResponse {
  final String content;
  final int inputTokens;
  final int outputTokens;
  final Duration elapsed;

  const ChatResponse({
    required this.content,
    required this.inputTokens,
    required this.outputTokens,
    required this.elapsed,
  });
}

class ChatApiClient {
  static http.Client? __client;
  static http.Client get _client => __client ??= http.Client();
  static void dispose() { __client?.close(); __client = null; }

  // ---- 鎺㈡祴 ----

  static Future<ProbeResult> probe(ApiKey key) async {
    try {
      final (uri, headers, body) = _buildProbeRequest(key);
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return const ProbeResult(success: true, message: "\u8fde\u63a5\u6210\u529f");
      }

      String detail = "";
      try {
        final decoded = jsonDecode(response.body);
        detail = _extractError(key.format, decoded);
      } catch (_) {}

      if (response.statusCode == 401 || response.statusCode == 403) {
        return ProbeResult(
            success: false,
            message: "API Key \u65e0\u6548${detail.isNotEmpty ? ': $detail' : ''}");
      }
      if (response.statusCode == 404) {
        return ProbeResult(
            success: false,
            message: "\u6a21\u578b ID \u4e0d\u5b58\u5728${detail.isNotEmpty ? ': $detail' : ''}");
      }
      return ProbeResult(
          success: false,
          message: "\u8bf7\u6c42\u5931\u8d25 (${response.statusCode})${detail.isNotEmpty ? ': $detail' : ''}");
    } on SocketException {
      return const ProbeResult(
          success: false, message: "\u65e0\u6cd5\u8fde\u63a5\u5230\u670d\u52a1\u5668");
    } on TimeoutException {
      return const ProbeResult(
          success: false, message: "\u8fde\u63a5\u8d85\u65f6\uff0c\u8bf7\u68c0\u67e5\u5730\u5740");
    } on http.ClientException catch (e) {
      return ProbeResult(
          success: false, message: "\u7f51\u7edc\u9519\u8bef: ${e.message}");
    } catch (e) {
      return ProbeResult(
          success: false, message: "\u672a\u77e5\u9519\u8bef: $e");
    }
  }

  // ---- 瀹屾暣瀵硅瘽 ----

  static Future<ChatResponse> send({
    required ApiKey key,
    String systemPrompt = "",
    required List<Map<String, String>> messages,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final (uri, headers, body) =
          _buildSendRequest(key, systemPrompt, messages);
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 120));
      sw.stop();

      if (response.statusCode != 200) {
        String err = "HTTP ${response.statusCode}";
        try {
          final decoded = jsonDecode(response.body);
          err = _extractError(key.format, decoded);
          if (err.isEmpty) err = "HTTP ${response.statusCode}";
        } catch (_) {}
        throw Exception("${key.modelName}: $err");
      }

      final decoded = jsonDecode(response.body);
      return _parseSendResponse(key.format, decoded, sw.elapsed);
    } catch (e) {
      sw.stop();
      if (e is Exception) rethrow;
      throw Exception("${key.modelName}: $e");
    }
  }

  // ---- 鍐呴儴 ----

  static String _extractError(ApiFormat format, Map<String, dynamic> body) {
    switch (format) {
      case ApiFormat.anthropic:
        return body['error']?['message'] as String? ?? "";
      case ApiFormat.google:
        return body['error']?['message'] as String? ?? "";
      default:
        return body['error']?['message'] as String? ??
            (body['error'] as String?) ??
            "";
    }
  }

  // -- 鎺㈡祴璇锋眰鏋勯€?--

  static (Uri, Map<String, String>, Map<String, dynamic>)
      _buildProbeRequest(ApiKey key) {
    return switch (key.format) {
      ApiFormat.anthropic => _anthropicProbe(key),
      ApiFormat.google => _geminiProbe(key),
      _ => _openAICompatibleProbe(key),
    };
  }

  static (Uri, Map<String, String>, Map<String, dynamic>)
      _openAICompatibleProbe(ApiKey key) {
    final base = _normUrl(key.baseUrl);
    return (
      Uri.parse('$base/chat/completions'),
      {
        'Authorization': 'Bearer ${key.apiKey}',
        'Content-Type': 'application/json',
      },
      {
        'model': key.modelId,
        'messages': [
          {'role': 'user', 'content': 'hi'}
        ],
        'max_tokens': 1,
      },
    );
  }

  static (Uri, Map<String, String>, Map<String, dynamic>)
      _anthropicProbe(ApiKey key) {
    final base = _normUrl(key.baseUrl);
    return (
      Uri.parse('$base/v1/messages'),
      {
        'x-api-key': key.apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      {
        'model': key.modelId,
        'max_tokens': 1,
        'messages': [
          {'role': 'user', 'content': 'hi'}
        ],
      },
    );
  }

  static (Uri, Map<String, String>, Map<String, dynamic>)
      _geminiProbe(ApiKey key) {
    final base = _normUrl(key.baseUrl);
    return (
      Uri.parse(
          '$base/models/${Uri.encodeComponent(key.modelId)}:generateContent?key=${Uri.encodeComponent(key.apiKey)}'),
      {'Content-Type': 'application/json'},
      {
        'contents': [
          {
            'parts': [
              {'text': 'hi'}
            ]
          }
        ],
      },
    );
  }

  // -- 瀹屾暣瀵硅瘽璇锋眰鏋勯€?--

  static (Uri, Map<String, String>, Map<String, dynamic>) _buildSendRequest(
      ApiKey key, String system, List<Map<String, String>> msgs) {
    return switch (key.format) {
      ApiFormat.anthropic => _anthropicSend(key, system, msgs),
      ApiFormat.google => _geminiSend(key, system, msgs),
      _ => _openAICompatibleSend(key, system, msgs),
    };
  }

  static (Uri, Map<String, String>, Map<String, dynamic>)
      _openAICompatibleSend(
          ApiKey key, String system, List<Map<String, String>> msgs) {
    final base = _normUrl(key.baseUrl);
    final messages = <Map<String, dynamic>>[];
    if (system.isNotEmpty) {
      messages.add({'role': 'system', 'content': system});
    }
    for (final m in msgs) {
      messages.add({'role': m['role'], 'content': m['content']});
    }
    return (
      Uri.parse('$base/chat/completions'),
      {
        'Authorization': 'Bearer ${key.apiKey}',
        'Content-Type': 'application/json',
      },
      {
        'model': key.modelId,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 4096,
      },
    );
  }

  static (Uri, Map<String, String>, Map<String, dynamic>) _anthropicSend(
      ApiKey key, String system, List<Map<String, String>> msgs) {
    final base = _normUrl(key.baseUrl);
    final messages = msgs
        .map((m) => {
              'role': m['role'],
              'content': m['content'],
            })
        .toList();
    return (
      Uri.parse('$base/v1/messages'),
      {
        'x-api-key': key.apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      {
        'model': key.modelId,
        'system': system,
        'messages': messages,
        'max_tokens': 4096,
      },
    );
  }

  static (Uri, Map<String, String>, Map<String, dynamic>) _geminiSend(
      ApiKey key, String system, List<Map<String, String>> msgs) {
    final base = _normUrl(key.baseUrl);
    final contents = msgs
        .map((m) => {
              'role': m['role'] == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': m['content']}
              ],
            })
        .toList();
    final body = <String, dynamic>{
      'contents': contents,
    };
    if (system.isNotEmpty) {
      body['system_instruction'] = {
        'parts': [
          {'text': system}
        ],
      };
    }
    return (
      Uri.parse(
          '$base/models/${Uri.encodeComponent(key.modelId)}:generateContent?key=${Uri.encodeComponent(key.apiKey)}'),
      {'Content-Type': 'application/json'},
      body,
    );
  }

  // -- 鍝嶅簲瑙ｆ瀽 --

  static ChatResponse _parseSendResponse(
      ApiFormat format, Map<String, dynamic> body, Duration elapsed) {
    return switch (format) {
      ApiFormat.anthropic => ChatResponse(
          content: body['content']?[0]?['text'] as String? ?? "",
          inputTokens: body['usage']?['input_tokens'] as int? ?? 0,
          outputTokens: body['usage']?['output_tokens'] as int? ?? 0,
          elapsed: elapsed,
        ),
      ApiFormat.google => ChatResponse(
          content: body['candidates']?[0]?['content']?['parts']?[0]?['text']
                  as String? ??
              "",
          inputTokens:
              body['usageMetadata']?['promptTokenCount'] as int? ?? 0,
          outputTokens:
              body['usageMetadata']?['candidatesTokenCount'] as int? ?? 0,
          elapsed: elapsed,
        ),
      _ => ChatResponse(
          content: body['choices']?[0]?['message']?['content'] as String? ??
              "",
          inputTokens: body['usage']?['prompt_tokens'] as int? ?? 0,
          outputTokens: body['usage']?['completion_tokens'] as int? ?? 0,
          elapsed: elapsed,
        ),
    };
  }

  static String _normUrl(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
