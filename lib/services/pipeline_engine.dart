import '../models/account.dart';
import 'prompt_service.dart';
import 'chat_api_client.dart';

class ModelPhaseResult {
  final String modelName;
  String initialAnswer;
  final List<_CrossExamineRound> rounds;
  int inputTokens;
  int outputTokens;
  Duration elapsed;

  ModelPhaseResult({required this.modelName, String? initialAnswer, List<_CrossExamineRound>? rounds})
      : initialAnswer = initialAnswer ?? "",
        rounds = rounds ?? [],
        inputTokens = 0,
        outputTokens = 0,
        elapsed = Duration.zero;

  String get finalAnswer =>
      rounds.isNotEmpty ? rounds.last.output : initialAnswer;
}

class _CrossExamineRound {
  final String output;
  const _CrossExamineRound({required this.output});
}

class PipelineResult {
  final List<ModelPhaseResult> modelResults;
  final String finalReport;
  final int totalInputTokens;
  final int totalOutputTokens;
  final Duration totalElapsed;

  const PipelineResult({
    required this.modelResults,
    required this.finalReport,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalElapsed,
  });
}

class PipelineEngine {
  /// Binary opposition: two models cross-examine each other over N iterations,
  /// then a central model synthesizes the joint report.
  static Future<PipelineResult> runBinary({
    required List<ApiKey> models,
    required ApiKey central,
    required String question,
    required int iterations,
  }) async {
    final sw = Stopwatch()..start();
    final ps = PromptService.instance;
    final a = models[0], b = models[1];
    final resultA = ModelPhaseResult(modelName: a.modelName);
    final resultB = ModelPhaseResult(modelName: b.modelName);
    int totalIn = 0, totalOut = 0;

    // ---------- Phase 1: independent answers ----------
    final answerPrompt = ps.render('answer');
    final p1 = await Future.wait([
      ChatApiClient.send(key: a, systemPrompt: answerPrompt, messages: [
        {'role': 'user', 'content': question}
      ]),
      ChatApiClient.send(key: b, systemPrompt: answerPrompt, messages: [
        {'role': 'user', 'content': question}
      ]),
    ]);
    resultA.initialAnswer = p1[0].content;
    resultB.initialAnswer = p1[1].content;
    resultA.inputTokens += p1[0].inputTokens; resultA.outputTokens += p1[0].outputTokens;
    resultB.inputTokens += p1[1].inputTokens; resultB.outputTokens += p1[1].outputTokens;
    totalIn += p1[0].inputTokens + p1[1].inputTokens;
    totalOut += p1[0].outputTokens + p1[1].outputTokens;
    resultA.elapsed += p1[0].elapsed; resultB.elapsed += p1[1].elapsed;

    // ---------- Phase 2: N rounds of cross-examination ----------
    for (int r = 0; r < iterations; r++) {
      final prevA = r == 0 ? resultA.initialAnswer : resultA.rounds.last.output;
      final prevB = r == 0 ? resultB.initialAnswer : resultB.rounds.last.output;

      // A cross-examines B's answer, B cross-examines A's answer — in parallel
      final crossA = ps.render('cross_examine', {
        'question': question,
        'own_answer': prevA,
        'other_answers': prevB,
      });
      final crossB = ps.render('cross_examine', {
        'question': question,
        'own_answer': prevB,
        'other_answers': prevA,
      });

      final round = await Future.wait([
        ChatApiClient.send(key: a, systemPrompt: crossA, messages: [
          {'role': 'user', 'content': '.'}
        ]),
        ChatApiClient.send(key: b, systemPrompt: crossB, messages: [
          {'role': 'user', 'content': '.'}
        ]),
      ]);

      resultA.inputTokens += round[0].inputTokens; resultA.outputTokens += round[0].outputTokens;
      resultB.inputTokens += round[1].inputTokens; resultB.outputTokens += round[1].outputTokens;
      totalIn += round[0].inputTokens + round[1].inputTokens;
      totalOut += round[0].outputTokens + round[1].outputTokens;
      resultA.elapsed += round[0].elapsed; resultB.elapsed += round[1].elapsed;

      resultA.rounds.add(_CrossExamineRound(output: round[0].content));
      resultB.rounds.add(_CrossExamineRound(output: round[1].content));
    }

    // ---------- Phase 3: central synthesis ----------
    final buf = StringBuffer();
    buf.writeln('=== ${a.modelName} ===');
    buf.writeln(resultA.finalAnswer);
    buf.writeln();
    for (int i = 0; i < resultA.rounds.length; i++) {
      buf.writeln('--- round ${i + 1} ---');
      buf.writeln(resultA.rounds[i].output);
      buf.writeln();
    }
    buf.writeln('=== ${b.modelName} ===');
    buf.writeln(resultB.finalAnswer);
    buf.writeln();
    for (int i = 0; i < resultB.rounds.length; i++) {
      buf.writeln('--- round ${i + 1} ---');
      buf.writeln(resultB.rounds[i].output);
      buf.writeln();
    }

    final centralPrompt = ps.render('central_report', {
      'question': question,
      'revised_summary': buf.toString(),
    });

    final synthesis = await ChatApiClient.send(key: central, systemPrompt: centralPrompt, messages: [
      {'role': 'user', 'content': '.'}
    ]);
    totalIn += synthesis.inputTokens;
    totalOut += synthesis.outputTokens;
    sw.stop();

    return PipelineResult(
      modelResults: [resultA, resultB],
      finalReport: synthesis.content,
      totalInputTokens: totalIn,
      totalOutputTokens: totalOut,
      totalElapsed: sw.elapsed,
    );
  }

  /// Hexad dispatch: M models (3-6) cross-examine each other in a fully-connected graph,
  /// then a central model synthesizes the joint report.
  static Future<PipelineResult> runHexad({
    required List<ApiKey> models,
    required ApiKey central,
    required String question,
    required int iterations,
  }) async {
    final sw = Stopwatch()..start();
    final ps = PromptService.instance;
    final results = models.map((m) => ModelPhaseResult(modelName: m.modelName)).toList();
    int totalIn = 0, totalOut = 0;

    // ---------- Phase 1: independent answers (all parallel) ----------
    final answerPrompt = ps.render('answer');
    final p1 = await Future.wait(
      models.map((m) => ChatApiClient.send(key: m, systemPrompt: answerPrompt, messages: [
        {'role': 'user', 'content': question}
      ])),
    );
    for (int i = 0; i < results.length; i++) {
      results[i].initialAnswer = p1[i].content;
      results[i].inputTokens += p1[i].inputTokens;
      results[i].outputTokens += p1[i].outputTokens;
      results[i].elapsed += p1[i].elapsed;
      totalIn += p1[i].inputTokens;
      totalOut += p1[i].outputTokens;
    }

    // ---------- Phase 2: N rounds of cross-examination ----------
    for (int r = 0; r < iterations; r++) {
      // Build cross_examine prompts for each model in parallel
      final prompts = <String>[];
      for (int i = 0; i < results.length; i++) {
        final own = r == 0 ? results[i].initialAnswer : results[i].rounds.last.output;
        final others = _formatOtherAnswers(results, i, r);
        prompts.add(ps.render('cross_examine', {
          'question': question,
          'own_answer': own,
          'other_answers': others,
        }));
      }

      final round = await Future.wait(
        List.generate(results.length, (i) => ChatApiClient.send(
          key: models[i], systemPrompt: prompts[i], messages: [
            {'role': 'user', 'content': '.'}
          ],
        )),
      );

      for (int i = 0; i < results.length; i++) {
        results[i].inputTokens += round[i].inputTokens;
        results[i].outputTokens += round[i].outputTokens;
        results[i].elapsed += round[i].elapsed;
        totalIn += round[i].inputTokens;
        totalOut += round[i].outputTokens;
        results[i].rounds.add(_CrossExamineRound(output: round[i].content));
      }
    }

    // ---------- Phase 3: central synthesis ----------
    final buf = StringBuffer();
    for (final r in results) {
      buf.writeln('=== ${r.modelName} ===');
      buf.writeln(r.finalAnswer);
      buf.writeln();
      for (int i = 0; i < r.rounds.length; i++) {
        buf.writeln('--- round ${i + 1} ---');
        buf.writeln(r.rounds[i].output);
        buf.writeln();
      }
    }

    final centralPrompt = ps.render('central_report', {
      'question': question,
      'revised_summary': buf.toString(),
    });

    final synthesis = await ChatApiClient.send(key: central, systemPrompt: centralPrompt, messages: [
      {'role': 'user', 'content': '.'}
    ]);
    totalIn += synthesis.inputTokens;
    totalOut += synthesis.outputTokens;
    sw.stop();

    return PipelineResult(
      modelResults: results,
      finalReport: synthesis.content,
      totalInputTokens: totalIn,
      totalOutputTokens: totalOut,
      totalElapsed: sw.elapsed,
    );
  }

  /// Format all other models' answers for the cross_examine prompt.
  static String _formatOtherAnswers(List<ModelPhaseResult> results, int selfIndex, int round) {
    final buf = StringBuffer();
    for (int i = 0; i < results.length; i++) {
      if (i == selfIndex) continue;
      final answer = round == 0
          ? results[i].initialAnswer
          : results[i].rounds[round - 1].output;
      buf.writeln('=== ${results[i].modelName} ===');
      buf.writeln(answer);
      buf.writeln();
    }
    return buf.toString();
  }

  /// Single-agent argument: one model impersonates four personas
  /// (radical/conservative x humanist/STEM) in a fully-connected cross-examination.
  static Future<PipelineResult> runAA({
    required ApiKey model,
    required String question,
    required int iterations,
    List<String>? personaIds,
    List<String>? personaLabels,
  }) async {
    final sw = Stopwatch()..start();
    final ps = PromptService.instance;
    final personas = personaIds ?? [
      'aa_persona_radical_human',
      'aa_persona_radical_stem',
      'aa_persona_conservative_human',
      'aa_persona_conservative_stem',
    ];
    final label = personaLabels ?? [
      '\u6fc0\u8fdb\u6587\u54f2',
      '\u6fc0\u8fdb\u7406\u5de5',
      '\u4fdd\u5b88\u6587\u54f2',
      '\u4fdd\u5b88\u7406\u5de5',
    ];
    final results = personas.map((_) => ModelPhaseResult(modelName: '')).toList();
    int totalIn = 0, totalOut = 0;

    // ---------- Phase 1: 4 personas answer independently ----------
    final p1 = await Future.wait(
      personas.map((p) => ChatApiClient.send(
        key: model,
        systemPrompt: ps.render(p),
        messages: [{'role': 'user', 'content': question}],
      )),
    );
    for (int i = 0; i < results.length; i++) {
      results[i] = ModelPhaseResult(modelName: '${model.modelName} \xb7 ${label[i]}');
      results[i].initialAnswer = p1[i].content;
      results[i].inputTokens += p1[i].inputTokens;
      results[i].outputTokens += p1[i].outputTokens;
      results[i].elapsed += p1[i].elapsed;
      totalIn += p1[i].inputTokens;
      totalOut += p1[i].outputTokens;
    }

    // ---------- Phase 2: N rounds of cross-examination ----------
    for (int r = 0; r < iterations; r++) {
      final prompts = <String>[];
      for (int i = 0; i < results.length; i++) {
        final own = r == 0 ? results[i].initialAnswer : results[i].rounds.last.output;
        final others = _formatOtherAnswers(results, i, r);
        prompts.add(ps.render('cross_examine', {
          'question': question,
          'own_answer': own,
          'other_answers': others,
        }));
      }

      final round = await Future.wait(
        List.generate(results.length, (i) => ChatApiClient.send(
          key: model,
          systemPrompt: prompts[i],
          messages: [{'role': 'user', 'content': '.'}],
        )),
      );

      for (int i = 0; i < results.length; i++) {
        results[i].inputTokens += round[i].inputTokens;
        results[i].outputTokens += round[i].outputTokens;
        results[i].elapsed += round[i].elapsed;
        totalIn += round[i].inputTokens;
        totalOut += round[i].outputTokens;
        results[i].rounds.add(_CrossExamineRound(output: round[i].content));
      }
    }

    // ---------- Phase 3: central synthesis ----------
    final buf = StringBuffer();
    for (final r in results) {
      buf.writeln('=== ${r.modelName} ===');
      buf.writeln(r.finalAnswer);
      buf.writeln();
      for (int i = 0; i < r.rounds.length; i++) {
        buf.writeln('--- round ${i + 1} ---');
        buf.writeln(r.rounds[i].output);
        buf.writeln();
      }
    }

    final centralPrompt = ps.render('central_report', {
      'question': question,
      'revised_summary': buf.toString(),
    });

    final synthesis = await ChatApiClient.send(
      key: model,
      systemPrompt: centralPrompt,
      messages: [{'role': 'user', 'content': '.'}],
    );
    totalIn += synthesis.inputTokens;
    totalOut += synthesis.outputTokens;
    sw.stop();

    return PipelineResult(
      modelResults: results,
      finalReport: synthesis.content,
      totalInputTokens: totalIn,
      totalOutputTokens: totalOut,
      totalElapsed: sw.elapsed,
    );
  }
}
