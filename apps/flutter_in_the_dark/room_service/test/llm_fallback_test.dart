/// Tests for the LLM provider fallback chain (llm_providers.dart):
/// FallbackGenerator tries the primary first, falls back on
/// GenerationException, logs the serving provider, and does NOT swallow
/// non-generation errors. Also covers stripCodeFence and the env gating in
/// buildGeneratorFromEnv.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_in_the_dark_room_service/llm_providers.dart';
import 'package:test/test.dart';

/// A scripted provider: each entry in [outcomes] is either a string (return
/// it) or an exception (throw it). Records every call so tests can assert
/// which provider was exercised.
class FakeGenerator implements CodeGenerator {
  FakeGenerator(this._name, this.outcomes);

  final String _name;
  final List<Object> outcomes;
  final List<String> calls = [];

  @override
  String get name => _name;

  Object _next(String label) {
    calls.add(label);
    if (outcomes.isEmpty) {
      throw StateError('$_name: no scripted outcome for $label');
    }
    return outcomes.removeAt(0);
  }

  @override
  Future<String> generateCode({
    required String prompt,
    required String model,
    String? reasoningEffort,
  }) async {
    switch (_next('generateCode:$prompt')) {
      case final String s:
        return s;
      case final Exception e:
        throw e;
      default:
        throw StateError('bad scripted outcome');
    }
  }

  @override
  Future<String> suggestFix({
    required String source,
    required String errorMessage,
    required String model,
  }) async {
    switch (_next('suggestFix')) {
      case final String s:
        return s;
      case final Exception e:
        throw e;
      default:
        throw StateError('bad scripted outcome');
    }
  }
}

void main() {
  group('FallbackGenerator', () {
    test('serves from primary when primary succeeds; fallback untouched',
        () async {
      final primary = FakeGenerator('primary', ['code-from-primary']);
      final fallback = FakeGenerator('fallback', ['code-from-fallback']);
      final chain = FallbackGenerator(primary: primary, fallback: fallback);

      final result = await chain.generateCode(prompt: 'p', model: 'm');

      expect(result, 'code-from-primary');
      expect(primary.calls, ['generateCode:p']);
      expect(fallback.calls, isEmpty);
    });

    test('falls back when primary throws GenerationException', () async {
      final primary = FakeGenerator('primary', [
        GenerationException('primary', 'HTTP 502: bad gateway'),
      ]);
      final fallback = FakeGenerator('fallback', ['code-from-fallback']);
      final chain = FallbackGenerator(primary: primary, fallback: fallback);

      final result = await chain.generateCode(prompt: 'p', model: 'm');

      expect(result, 'code-from-fallback');
      expect(primary.calls, ['generateCode:p']);
      expect(fallback.calls, ['generateCode:p']);
    });

    test('suggestFix falls back the same way', () async {
      final primary = FakeGenerator('primary', [
        GenerationException('primary', 'connect timed out'),
      ]);
      final fallback = FakeGenerator('fallback', ['fixed-code']);
      final chain = FallbackGenerator(primary: primary, fallback: fallback);

      final result = await chain.suggestFix(
        source: 'broken',
        errorMessage: 'err',
        model: 'm',
      );

      expect(result, 'fixed-code');
      expect(fallback.calls, ['suggestFix']);
    });

    test('propagates the fallback failure when both providers fail', () async {
      final primary = FakeGenerator('primary', [
        GenerationException('primary', 'HTTP 503'),
      ]);
      final fallback = FakeGenerator('fallback', [
        GenerationException('fallback', 'HTTP 429 quota'),
      ]);
      final chain = FallbackGenerator(primary: primary, fallback: fallback);

      expect(
        () => chain.generateCode(prompt: 'p', model: 'm'),
        throwsA(
          isA<GenerationException>()
              .having((e) => e.provider, 'provider', 'fallback')
              .having((e) => e.message, 'message', contains('429')),
        ),
      );
    });
  });

  group('ProviderMode override', () {
    test('boots in auto mode', () {
      final chain = FallbackGenerator(
        primary: FakeGenerator('primary', []),
        fallback: FakeGenerator('fallback', []),
      );
      expect(chain.mode, ProviderMode.auto);
    });

    test('forced berget serves only primary, even when it fails', () async {
      final primary = FakeGenerator('primary', [
        GenerationException('primary', 'HTTP 503'),
      ]);
      final fallback = FakeGenerator('fallback', ['never-used']);
      final chain = FallbackGenerator(primary: primary, fallback: fallback)
        ..setMode(ProviderMode.berget);

      await expectLater(
        () => chain.generateCode(prompt: 'p', model: 'm'),
        throwsA(isA<GenerationException>()),
      );
      expect(primary.calls, ['generateCode:p']);
      expect(fallback.calls, isEmpty,
          reason: 'berget mode never touches Gemini');
    });

    test('forced gemini serves only fallback, primary untouched', () async {
      final primary = FakeGenerator('primary', ['never-used']);
      final fallback = FakeGenerator('fallback', ['gemini-code']);
      final chain = FallbackGenerator(primary: primary, fallback: fallback)
        ..setMode(ProviderMode.gemini);

      final result = await chain.generateCode(prompt: 'p', model: 'm');

      expect(result, 'gemini-code');
      expect(primary.calls, isEmpty,
          reason: 'gemini mode never touches Berget');
      expect(fallback.calls, ['generateCode:p']);
    });

    test('forced gemini suggestFix serves only fallback', () async {
      final primary = FakeGenerator('primary', ['never-used']);
      final fallback = FakeGenerator('fallback', ['gemini-fix']);
      final chain = FallbackGenerator(primary: primary, fallback: fallback)
        ..setMode(ProviderMode.gemini);

      final result = await chain.suggestFix(
        source: 's',
        errorMessage: 'e',
        model: 'm',
      );

      expect(result, 'gemini-fix');
      expect(primary.calls, isEmpty);
    });

    test('returning to auto restores fallback behaviour', () async {
      final primary = FakeGenerator('primary', [
        GenerationException('primary', 'HTTP 502'),
      ]);
      final fallback = FakeGenerator('fallback', ['gemini-code', 'fb-code']);
      final chain = FallbackGenerator(primary: primary, fallback: fallback)
        ..setMode(ProviderMode.gemini);
      await chain.generateCode(prompt: 'a', model: 'm'); // forced gemini
      chain.setMode(ProviderMode.auto);

      final result = await chain.generateCode(prompt: 'b', model: 'm');

      expect(result, 'fb-code', reason: 'auto falls back after primary fails');
      expect(primary.calls, ['generateCode:b']);
    });

    test('setMode(gemini) with no fallback throws StateError', () {
      final chain = FallbackGenerator(primary: FakeGenerator('primary', []));
      expect(chain.geminiAvailable, isFalse);
      expect(
        () => chain.setMode(ProviderMode.gemini),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('GEMINI_API_KEY not set'),
          ),
        ),
      );
      expect(chain.mode, ProviderMode.auto,
          reason: 'failed setMode must not stick');
    });

    test('setMode is a no-op when mode is unchanged', () async {
      final primary = FakeGenerator('primary', ['p-code']);
      final chain = FallbackGenerator(
        primary: primary,
        fallback: FakeGenerator('fallback', []),
      );
      chain.setMode(ProviderMode.auto); // same as current — no throw, no log
      expect(chain.mode, ProviderMode.auto);
      final result = await chain.generateCode(prompt: 'p', model: 'm');
      expect(result, 'p-code');
    });

    test('auto mode with no fallback propagates primary failure (no retry)',
        () async {
      final primary = FakeGenerator('primary', [
        GenerationException('primary', 'HTTP 503'),
      ]);
      final chain = FallbackGenerator(primary: primary);

      await expectLater(
        () => chain.generateCode(prompt: 'p', model: 'm'),
        throwsA(isA<GenerationException>()),
      );
      expect(primary.calls, ['generateCode:p'],
          reason: 'no fallback → single attempt');
    });
  });

  group('stripCodeFence', () {
    test('strips a standard fence', () {
      expect(
        stripCodeFence('Here you go:\n```dart\nvoid main() {}\n```\nDone.'),
        'void main() {}',
      );
    });

    test('returns text unchanged when no start marker', () {
      expect(stripCodeFence('  void main() {}  '), 'void main() {}');
    });

    test('tolerates a missing end marker', () {
      expect(stripCodeFence('```dart\nvoid main() {}'), 'void main() {}');
    });
  });

  group('buildGeneratorFromEnv gating', () {
    test('GEMINI_API_KEY unset → chain with no fallback, gemini unavailable',
        () {
      final result = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {},
      );
      expect(result.generator, isA<FallbackGenerator>());
      expect(result.generator.primary, isA<DartServicesGenerator>());
      expect(result.generator.fallback, isNull);
      expect(result.generator.geminiAvailable, isFalse);
      expect(result.providersDescription, contains('no fallback'));
    });

    test('GEMINI_API_KEY empty → chain with no fallback', () {
      final result = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {'GEMINI_API_KEY': ''},
      );
      expect(result.generator, isA<FallbackGenerator>());
      expect(result.generator.fallback, isNull);
      expect(result.generator.geminiAvailable, isFalse);
    });

    test('GEMINI_API_KEY set → fallback chain with Gemini', () {
      final result = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {'GEMINI_API_KEY': 'test-key'},
      );
      final chain = result.generator;
      expect(chain.primary, isA<DartServicesGenerator>());
      expect(chain.fallback, isA<GeminiGenerator>());
      expect(chain.geminiAvailable, isTrue);
      expect(result.providersDescription, contains('FALLBACK'));
    });

    test('GEMINI_MODEL overrides the fallback model', () {
      final result = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {
          'GEMINI_API_KEY': 'test-key',
          'GEMINI_MODEL': 'gemini-3.6-flash',
        },
      );
      expect(
        (result.generator.fallback as GeminiGenerator).model,
        'gemini-3.6-flash',
      );
    });

    test('GEMINI_API_URL overrides the fallback apiBase', () {
      final result = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {
          'GEMINI_API_KEY': 'test-key',
          'GEMINI_API_URL': 'http://127.0.0.1:8309',
        },
      );
      expect(
        (result.generator.fallback as GeminiGenerator).apiBase,
        'http://127.0.0.1:8309',
      );
    });

    test('GEMINI_API_URL empty → production endpoint', () {
      final result = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {
          'GEMINI_API_KEY': 'test-key',
          'GEMINI_API_URL': '',
        },
      );
      expect(
        (result.generator.fallback as GeminiGenerator).apiBase,
        'https://generativelanguage.googleapis.com/v1beta',
      );
    });
  });

  group('DartServicesGenerator transport failures', () {
    // dart_services' disabled-generation path answers HTTP 200 then throws
    // asynchronously, dropping the socket before full headers — observed
    // live as `Empty reply from server`. The primary must translate that
    // into a GenerationException so the fallback chain engages.
    Future<ServerSocket> bindDropper() async {
      final server = await ServerSocket.bind('127.0.0.1', 0);
      server.listen((client) {
        // Accept and destroy with no bytes: the observed
        // "empty reply from server" / ClientException case.
        client.destroy();
      });
      return server;
    }

    Future<HttpServer> bindEmptyBodyServer() async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        await request.drain<void>();
        await request.response.close(); // <body> = empty
      });
      return server;
    }

    test('connection closed with no bytes becomes a fallback trigger',
        () async {
      final dropper = await bindDropper();
      final primary = DartServicesGenerator(
        backendBase: 'http://127.0.0.1:${dropper.port}',
      );
      final chain = FallbackGenerator(
        primary: primary,
        fallback: FakeGenerator('fallback', ['gemini-code']),
      );

      final result = await chain.generateCode(prompt: 'p', model: 'm');

      expect(result, 'gemini-code',
          reason: 'an empty-reply primary must NOT bypass the fallback');
      await dropper.close();
    });

    test('200 with an empty body becomes a fallback trigger', () async {
      final emptier = await bindEmptyBodyServer();
      final primary = DartServicesGenerator(
        backendBase: 'http://127.0.0.1:${emptier.port}',
      );
      final chain = FallbackGenerator(
        primary: primary,
        fallback: FakeGenerator('fallback', ['gemini-code']),
      );

      final result = await chain.generateCode(prompt: 'p', model: 'm');

      expect(result, 'gemini-code',
          reason: 'a 0-byte 200 parses as success — must be treated as '
              'an empty, invalid generation');
      await emptier.close(force: true);
    });

    test('connection refused becomes a fallback trigger', () async {
      final socket = await ServerSocket.bind('127.0.0.1', 0);
      final port = socket.port;
      await socket.close();
      // Nothing listens on [port] any more (closed ephemeral socket):
      // connecting there is refused (SocketException path).
      final primary =
          DartServicesGenerator(backendBase: 'http://127.0.0.1:$port');
      final chain = FallbackGenerator(
        primary: primary,
        fallback: FakeGenerator('fallback', ['gemini-code']),
      );

      final result = await chain.generateCode(prompt: 'p', model: 'm');

      expect(result, 'gemini-code');
    });
  });

  group('GeminiGenerator thinkingConfig payload', () {
    // Captures the generateContent request bodies so tests can assert the
    // generationConfig.thinkingConfig contract without the real API.
    // Lists (not strings) so the record holds a LIVE reference — the server
    // fills them only once a request arrives.
    Future<
        (
          HttpServer server,
          List<String> paths,
          List<String> bodies,
        )> bindCapture() async {
      final paths = <String>[];
      final bodies = <String>[];
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        paths.add(request.uri.path);
        bodies.add(await utf8.decoder.bind(request).join());
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          '{"candidates":[{"content":{"parts":[{"text":"```dart'
          '\\nvoid main() {}\\n```"}]}}]}',
        );
        await request.response.close();
      });
      return (server, paths, bodies);
    }

    test('thinkingBudget set → generationConfig.thinkingConfig sent', () async {
      final (server, _, bodies) = await bindCapture();
      final gemini = GeminiGenerator(
        apiKey: 'test-key',
        apiBase: 'http://127.0.0.1:${server.port}',
        thinkingBudget: 0,
      );
      await gemini.generateCode(prompt: 'p', model: 'm');
      expect(bodies, hasLength(1));

      final body = jsonDecode(bodies.single) as Map<String, dynamic>;
      final genCfg = body['generationConfig'] as Map<String, dynamic>?;
      expect(genCfg, isNotNull,
          reason: 'an explicit thinkingBudget must reach the wire');
      expect(
        (genCfg!['thinkingConfig'] as Map<String, dynamic>)['thinkingBudget'],
        0,
      );
      await server.close(force: true);
    });

    test('thinkingBudget null → no thinkingConfig in payload', () async {
      final (server, _, bodies) = await bindCapture();
      final gemini = GeminiGenerator(
        apiKey: 'test-key',
        apiBase: 'http://127.0.0.1:${server.port}',
      );
      await gemini.generateCode(prompt: 'p', model: 'm');
      expect(bodies, hasLength(1));

      final body = jsonDecode(bodies.single) as Map<String, dynamic>;
      expect(body.containsKey('generationConfig'), isFalse,
          reason: 'unset knob must omit the field (model default applies)');
      await server.close(force: true);
    });

    test('GEMINI_THINKING_BUDGET: explicit values win, absence → 512', () {
      final set = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {'GEMINI_API_KEY': 'k', 'GEMINI_THINKING_BUDGET': '512'},
      );
      expect((set.generator.fallback as GeminiGenerator).thinkingBudget, 512);

      final zero = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {'GEMINI_API_KEY': 'k', 'GEMINI_THINKING_BUDGET': '0'},
      );
      expect((zero.generator.fallback as GeminiGenerator).thinkingBudget, 0,
          reason: 'explicit operator intent is honored even though the API '
              'currently 400s this model on 0');

      final absent = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {'GEMINI_API_KEY': 'k'},
      );
      expect((absent.generator.fallback as GeminiGenerator).thinkingBudget, 512,
          reason:
              'absence → GemGenerator.defaultThinkingBudget (measured fastest '
              'end-to-end)');

      final junk = buildGeneratorFromEnv(
        backendBase: 'http://unused',
        env: const {'GEMINI_API_KEY': 'k', 'GEMINI_THINKING_BUDGET': 'lots'},
      );
      expect((junk.generator.fallback as GeminiGenerator).thinkingBudget, 512,
          reason: 'unparseable → same measured default, never null');
    });
  });
}
