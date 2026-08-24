import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/integrity/integrity_token_provider.dart';
import 'package:roundtablezoo/core/integrity/play_integrity_token_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayIntegrityTokenProvider (contracts/integrity-token-provider.md §1)', () {
    const channel = MethodChannel('life.studyway.roundtablezoo/integrity');
    late int platformCalls;
    late PlayIntegrityTokenProvider provider;

    void mockPlatform(Future<String?> Function() answer) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          platformCalls++;
          return answer();
        },
      );
    }

    setUp(() {
      platformCalls = 0;
      provider = PlayIntegrityTokenProvider(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    test('ten sequential calls make exactly one platform request (SC-005a)', () async {
      mockPlatform(() async => 'token-1');

      for (var i = 0; i < 10; i++) {
        final token = await provider.token();
        expect(token, 'token-1');
      }

      expect(platformCalls, 1);
    });

    test('concurrent calls on an empty cache make exactly one platform request', () async {
      mockPlatform(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'token-concurrent';
      });

      final results = await Future.wait(List.generate(5, (_) => provider.token()));

      expect(results, everyElement('token-concurrent'));
      expect(platformCalls, 1);
    });

    test('invalidate() clears the cache — the next token() requests a fresh one', () async {
      var call = 0;
      mockPlatform(() async => 'token-${++call}');

      final first = await provider.token();
      provider.invalidate();
      final second = await provider.token();

      expect(first, 'token-1');
      expect(second, 'token-2');
      expect(platformCalls, 2);
    });

    test('a platform failure surfaces as null, never throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'integrity_prepare_failed'),
      );

      final token = await provider.token();

      expect(token, isNull);
    });

    test('a missing platform implementation surfaces as null, never throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );

      final token = await provider.token();

      expect(token, isNull);
    });
  });

  group('UnsupportedIntegrityTokenProvider (research.md R14)', () {
    test('token() always null, invalidate() is a no-op', () async {
      const provider = UnsupportedIntegrityTokenProvider();

      expect(await provider.token(), isNull);
      provider.invalidate();
      expect(await provider.token(), isNull);
    });
  });
}
