import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/network/ai_proxy_client.dart';

import '../support/mocks.dart';

/// Answers `/react` from an in-memory queue instead of a real network call —
/// resolves inside `onRequest` so no `HttpClientAdapter` mocking is needed.
class _QueuedInterceptor extends Interceptor {
  final List<Map<String, dynamic>> requestBodies = [];
  final List<dynamic> _answers = [];

  void enqueue(dynamic answer) => _answers.add(answer);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requestBodies.add(Map<String, dynamic>.from(options.data as Map));
    final answer = _answers.removeAt(0);
    if (answer is int) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: answer),
        ),
      );
    } else {
      handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: answer as Map<String, dynamic>,
        ),
      );
    }
  }
}

void main() {
  late MockIntegrityTokenProvider tokenProvider;
  late _QueuedInterceptor queue;
  late Dio dio;
  late DioAiProxyClient client;

  const okBody = {'character': 'cat', 'mood': 'warm', 'reply': 'Мр-р', 'intensity': 0.5};

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/react'));
  });

  setUp(() {
    tokenProvider = MockIntegrityTokenProvider();
    queue = _QueuedInterceptor();
    dio = Dio(BaseOptions(baseUrl: 'https://proxy.test'))..interceptors.add(queue);
    client = DioAiProxyClient(integrityTokenProvider: tokenProvider, dio: dio);
  });

  Future<AiReactionResult> _react() async {
    final dto = await client.react(
      installId: 'install-1',
      characterId: 'cat',
      dayText: 'today',
      moodScore: 3,
      attempt: 0,
    );
    return AiReactionResult(dto.character, dto.reply);
  }

  test('a 200 on the first attempt makes exactly one request', () async {
    when(() => tokenProvider.token()).thenAnswer((_) async => 'token-1');
    queue.enqueue(okBody);

    final result = await _react();

    expect(result.character, 'cat');
    expect(result.reply, 'Мр-р');
    expect(queue.requestBodies, hasLength(1));
    expect(queue.requestBodies.single['integrityToken'], 'token-1');
    verifyNever(() => tokenProvider.invalidate());
  });

  test(
    'a 403 triggers exactly one retry with a freshly fetched token (FR-010a)',
    () async {
      var tokenCall = 0;
      when(() => tokenProvider.token()).thenAnswer((_) async => 'token-${++tokenCall}');
      queue.enqueue(403);
      queue.enqueue(okBody);

      final result = await _react();

      expect(result.character, 'cat');
      expect(queue.requestBodies, hasLength(2));
      expect(queue.requestBodies[0]['integrityToken'], 'token-1');
      expect(queue.requestBodies[1]['integrityToken'], 'token-2');
      verify(() => tokenProvider.invalidate()).called(1);
    },
  );

  test('a second consecutive 403 propagates — no retry loop', () async {
    when(() => tokenProvider.token()).thenAnswer((_) async => 'stale-token');
    queue.enqueue(403);
    queue.enqueue(403);

    await expectLater(_react(), throwsA(isA<DioException>()));

    expect(queue.requestBodies, hasLength(2));
    verify(() => tokenProvider.invalidate()).called(1);
  });

  test('a non-403 failure is not retried', () async {
    when(() => tokenProvider.token()).thenAnswer((_) async => 'token-1');
    queue.enqueue(429);

    await expectLater(_react(), throwsA(isA<DioException>()));

    expect(queue.requestBodies, hasLength(1));
    verifyNever(() => tokenProvider.invalidate());
  });

  test('a null token omits integrityToken from the request body (research.md R14)', () async {
    when(() => tokenProvider.token()).thenAnswer((_) async => null);
    queue.enqueue(okBody);

    await _react();

    expect(queue.requestBodies.single.containsKey('integrityToken'), isFalse);
  });
}

class AiReactionResult {
  AiReactionResult(this.character, this.reply);
  final String? character;
  final String? reply;
}
