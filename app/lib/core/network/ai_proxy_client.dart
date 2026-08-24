import 'package:dio/dio.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/integrity/integrity_token_provider.dart';
import 'package:roundtablezoo/core/network/ai_proxy_config.dart';
import 'package:roundtablezoo/data/models/ai_reaction_dto.dart';

/// Client half of the ai-proxy `/react` contract
/// (`specs/004-table-screen/contracts/ai-proxy-client.md` §1, §5;
/// `specs/007-ai-proxy/contracts/react-api.md` §1). HTTP status codes and
/// `DioException`s propagate as-is — mapping them to `AiProxyFailure` is
/// `AiReactionRepositoryImpl`'s job, not this client's (principle I/II: raw
/// transport errors don't reach the repository boundary un-mapped, and this
/// interface is the one place allowed to see them at all).
abstract interface class AiProxyClient {
  Future<AiReactionDto> react({
    required String installId,
    required String characterId,
    required String dayText,
    required int moodScore,
    required int attempt,
  });
}

/// The real implementation — talks to `AiProxyConfig.baseUrl`. Selected
/// over `StubAiProxyClient` only when a proxy address is actually
/// configured (research.md R14).
class DioAiProxyClient implements AiProxyClient {
  DioAiProxyClient({required this._integrityTokenProvider, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AiProxyConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

  final Dio _dio;
  final IntegrityTokenProvider _integrityTokenProvider;

  @override
  Future<AiReactionDto> react({
    required String installId,
    required String characterId,
    required String dayText,
    required int moodScore,
    required int attempt,
  }) {
    // The 15s client budget wraps the whole operation, including the one
    // retry after a 403 (contracts/integrity-token-provider.md §3) — not
    // each attempt separately, or FR-010a would double the worst-case wait
    // past SC-002.
    return _react(
      installId: installId,
      characterId: characterId,
      dayText: dayText,
      moodScore: moodScore,
      attempt: attempt,
    ).timeout(AppConstants.aiRequestTimeout);
  }

  Future<AiReactionDto> _react({
    required String installId,
    required String characterId,
    required String dayText,
    required int moodScore,
    required int attempt,
  }) async {
    Future<AiReactionDto> send(String? integrityToken) async {
      final response = await _post(
        installId: installId,
        characterId: characterId,
        dayText: dayText,
        moodScore: moodScore,
        attempt: attempt,
        integrityToken: integrityToken,
      );
      return AiReactionDto.fromJson(response.data ?? const {});
    }

    final token = await _integrityTokenProvider.token();
    try {
      return await send(token);
    } on DioException catch (error) {
      if (error.response?.statusCode != 403) rethrow;

      // Exactly one retry with a freshly fetched token (FR-010a) — a
      // second 403 propagates as-is, no loop.
      _integrityTokenProvider.invalidate();
      final freshToken = await _integrityTokenProvider.token();
      return send(freshToken);
    }
  }

  Future<Response<Map<String, dynamic>>> _post({
    required String installId,
    required String characterId,
    required String dayText,
    required int moodScore,
    required int attempt,
    required String? integrityToken,
  }) {
    return _dio.post<Map<String, dynamic>>(
      '/react',
      data: {
        'installId': installId,
        'characterId': characterId,
        'dayText': dayText,
        'moodScore': moodScore,
        'attempt': attempt,
        'integrityToken': ?integrityToken,
      },
    );
  }
}
