import 'package:dio/dio.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/network/ai_proxy_config.dart';
import 'package:roundtablezoo/data/models/ai_reaction_dto.dart';

/// Client half of the ai-proxy `/react` contract
/// (`specs/004-table-screen/contracts/ai-proxy-client.md` §1, §5). HTTP
/// status codes and `DioException`s propagate as-is — mapping them to
/// `AiProxyFailure` is `AiReactionRepositoryImpl`'s job, not this
/// client's (principle I/II: raw transport errors don't reach the
/// repository boundary un-mapped, and this interface is the one place
/// allowed to see them at all).
abstract interface class AiProxyClient {
  Future<AiReactionDto> react({required String installId, required String characterId, required String dayText});
}

/// The real implementation — talks to `AiProxyConfig.baseUrl`. Selected
/// over `StubAiProxyClient` only when a proxy address is actually
/// configured (research.md R14).
class DioAiProxyClient implements AiProxyClient {
  DioAiProxyClient({Dio? dio})
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

  @override
  Future<AiReactionDto> react({
    required String installId,
    required String characterId,
    required String dayText,
  }) async {
    // Belt-and-suspenders on top of the per-phase Dio timeouts above: a
    // slow connect *and* a slow response must still cut off at the 15s
    // client budget (FR-027a), not their sum (research.md R1/R7).
    final response = await _dio
        .post<Map<String, dynamic>>(
          '/react',
          data: {'installId': installId, 'characterId': characterId, 'dayText': dayText},
        )
        .timeout(AppConstants.aiRequestTimeout);

    return AiReactionDto.fromJson(response.data ?? const {});
  }
}
