import 'dart:async';

import 'package:dio/dio.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/network/ai_proxy_client.dart';
import 'package:roundtablezoo/core/utils/app_logger.dart';
import 'package:roundtablezoo/data/models/ai_reaction_dto.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/repositories/ai_reaction_repository.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';
import 'package:roundtablezoo/domain/value_objects/validators.dart';

/// The only place that sees HTTP statuses and `DioException`s
/// (`specs/004-table-screen/contracts/ai-proxy-client.md` §4) — everything
/// past this boundary works with `Result<CharacterReaction>` and
/// `AiProxyFailure` only (principle I/II).
class AiReactionRepositoryImpl implements AiReactionRepository {
  AiReactionRepositoryImpl({
    required AiProxyClient client,
    required SettingsRepository settingsRepository,
    required AppClock clock,
  }) : _client = client,
       _settingsRepository = settingsRepository,
       _clock = clock;

  final AiProxyClient _client;
  final SettingsRepository _settingsRepository;
  final AppClock _clock;

  @override
  Future<Result<CharacterReaction>> requestReaction({
    required String characterId,
    required String dayText,
    required int dayEntryId,
  }) async {
    final settingsResult = await _settingsRepository.load();
    final installId = settingsResult.valueOrNull?.installId;
    if (installId == null) {
      return Result.failure(settingsResult.errorOrNull ?? const UnknownFailure('settings unavailable'));
    }

    try {
      final dto = await _client.react(installId: installId, characterId: characterId, dayText: dayText);
      return _parse(dto, characterId: characterId, dayEntryId: dayEntryId);
    } on AiProxyFailure catch (failure) {
      // The stub client (research.md R14) throws these directly to
      // exercise every branch below without a real proxy.
      _logFailure(failure.code ?? AiProxyFailure.invalidResponse, characterId);
      return Result.failure(failure);
    } on TimeoutException {
      _logFailure(AiProxyFailure.timeout, characterId);
      return const Result.failure(AiProxyFailure(null, code: AiProxyFailure.timeout));
    } on DioException catch (error) {
      final code = _codeFor(error);
      _logFailure(code, characterId);
      return Result.failure(AiProxyFailure(null, code: code));
    } on Object {
      // Malformed JSON, unexpected shape — never anything DioException
      // already covers.
      _logFailure(AiProxyFailure.invalidResponse, characterId);
      return const Result.failure(AiProxyFailure(null, code: AiProxyFailure.invalidResponse));
    }
  }

  Result<CharacterReaction> _parse(
    AiReactionDto dto, {
    required String characterId,
    required int dayEntryId,
  }) {
    if (dto.character != characterId) {
      _logFailure(AiProxyFailure.invalidResponse, characterId);
      return const Result.failure(AiProxyFailure(null, code: AiProxyFailure.invalidResponse));
    }
    final reply = dto.reply?.trim();
    if (reply == null || reply.isEmpty) {
      _logFailure(AiProxyFailure.invalidResponse, characterId);
      return const Result.failure(AiProxyFailure(null, code: AiProxyFailure.invalidResponse));
    }
    final intensity = Validators.intensity(dto.intensity ?? 0.5).valueOrGet(() => 0.5);

    return Result.success(
      CharacterReaction(
        dayEntryId: dayEntryId,
        characterId: characterId,
        tone: ReactionTone.fromStorage(dto.mood),
        reply: reply,
        intensity: intensity,
        isFallback: false,
        createdAt: _clock.nowUtc(),
      ),
    );
  }

  String _codeFor(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return AiProxyFailure.network;
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return AiProxyFailure.timeout;
      case DioExceptionType.badResponse:
        return switch (error.response?.statusCode) {
          429 => AiProxyFailure.rateLimited,
          503 => AiProxyFailure.aiDisabled,
          _ => AiProxyFailure.invalidResponse,
        };
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
      case DioExceptionType.transformTimeout:
        return AiProxyFailure.invalidResponse;
    }
  }

  /// FR-034b: only the failure code and `characterId` — never `dayText`,
  /// the reply, or the raw `DioException` (its message can carry the
  /// request body).
  void _logFailure(String code, String characterId) {
    logger.w('ai-proxy request failed: $code ($characterId)');
  }
}
