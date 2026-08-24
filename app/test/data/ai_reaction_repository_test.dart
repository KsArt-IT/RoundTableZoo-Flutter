import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/data/models/ai_reaction_dto.dart';
import 'package:roundtablezoo/data/repositories/ai_reaction_repository_impl.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';

import '../support/mocks.dart';

final _requestOptions = RequestOptions(path: '/react');

const _settings = UserSettings(
  installId: 'install-123',
  themeMode: ThemePreference.system,
  locale: LocalePreference.system,
  soundEnabled: true,
  enabledCharacterIds: ['cat'],
  hasSeenOnboarding: true,
  reminderEnabled: false,
  reminderTime: ReminderTime.defaultValue,
  dayStartHour: DayStartHour.defaultValue,
);

DioException _dioError({required DioExceptionType type, int? statusCode, String? scope}) =>
    DioException(
      requestOptions: _requestOptions,
      type: type,
      response: statusCode == null
          ? null
          : Response(
              requestOptions: _requestOptions,
              statusCode: statusCode,
              data: scope == null ? null : {'error': 'rate_limited', 'scope': scope},
            ),
    );

void main() {
  late MockAiProxyClient client;
  late MockSettingsRepository settingsRepository;
  late MockAppClock clock;
  late AiReactionRepositoryImpl repository;

  setUp(() {
    client = MockAiProxyClient();
    settingsRepository = MockSettingsRepository();
    clock = MockAppClock();

    when(() => settingsRepository.load()).thenAnswer((_) async => const Result.success(_settings));
    when(() => clock.nowUtc()).thenReturn(DateTime.utc(2026, 3, 10, 12));

    repository = AiReactionRepositoryImpl(
      client: client,
      settingsRepository: settingsRepository,
      clock: clock,
    );
  });

  Future<Result<CharacterReaction>> _requestFor(AiReactionDto dto) async {
    when(
      () => client.react(
        installId: any(named: 'installId'),
        characterId: any(named: 'characterId'),
        dayText: any(named: 'dayText'),
        moodScore: any(named: 'moodScore'),
        attempt: any(named: 'attempt'),
      ),
    ).thenAnswer((_) async => dto);
    return repository.requestReaction(
      characterId: 'cat',
      dayText: 'hi',
      dayEntryId: 1,
      moodScore: 3,
      attempt: 0,
    );
  }

  group('successful response parsing (contract §3)', () {
    test('a well-formed response becomes a real, non-fallback reaction', () async {
      final result = await _requestFor(
        const AiReactionDto(character: 'cat', mood: 'warm', reply: 'Мр-р', intensity: 0.7),
      );

      expect(result.isSuccess, isTrue);
      final reaction = result.valueOrNull!;
      expect(reaction.reply, 'Мр-р');
      expect(reaction.tone, ReactionTone.warm);
      expect(reaction.intensity, 0.7);
      expect(reaction.isFallback, isFalse);
      expect(reaction.characterId, 'cat');
      expect(reaction.dayEntryId, 1);
    });

    test('character mismatch is invalidResponse', () async {
      final result = await _requestFor(const AiReactionDto(character: 'dog', reply: 'Гав'));

      expect(result.isFailure, isTrue);
      expect(
        result.errorOrNull,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.invalidResponse),
      );
    });

    test('an unrecognized mood defaults to neutral, reply still saved', () async {
      final result = await _requestFor(
        const AiReactionDto(character: 'cat', mood: 'some-unknown-value', reply: 'Мр-р'),
      );

      expect(result.isSuccess, isTrue);
      expect((result.valueOrNull!).tone, ReactionTone.neutral);
    });

    test('a missing intensity defaults to 0.5', () async {
      final result = await _requestFor(const AiReactionDto(character: 'cat', reply: 'Мр-р'));

      expect(result.isSuccess, isTrue);
      expect((result.valueOrNull!).intensity, 0.5);
    });

    test('an out-of-range intensity defaults to 0.5, reply still saved', () async {
      final result = await _requestFor(
        const AiReactionDto(character: 'cat', reply: 'Мр-р', intensity: 5),
      );

      expect(result.isSuccess, isTrue);
      expect((result.valueOrNull!).intensity, 0.5);
    });

    test('an empty reply is invalidResponse', () async {
      final result = await _requestFor(const AiReactionDto(character: 'cat', reply: '   '));

      expect(result.isFailure, isTrue);
      expect(
        result.errorOrNull,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.invalidResponse),
      );
    });

    test('a missing reply is invalidResponse', () async {
      final result = await _requestFor(const AiReactionDto(character: 'cat'));

      expect(result.isFailure, isTrue);
      expect(
        result.errorOrNull,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.invalidResponse),
      );
    });
  });

  group('transport failures → AiProxyFailure (contract §4)', () {
    Future<AppFailure?> _failureFor(DioException error) async {
      when(
        () => client.react(
          installId: any(named: 'installId'),
          characterId: any(named: 'characterId'),
          dayText: any(named: 'dayText'),
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenThrow(error);
      final result = await repository.requestReaction(
        characterId: 'cat',
        dayText: 'hi',
        dayEntryId: 1,
        moodScore: 3,
        attempt: 0,
      );
      return result.errorOrNull;
    }

    test('429 with no parseable scope maps to rateLimitedDevice (forgiving default)', () async {
      final failure = await _failureFor(
        _dioError(type: DioExceptionType.badResponse, statusCode: 429),
      );
      expect(
        failure,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.rateLimitedDevice),
      );
    });

    test('429 with scope: device maps to rateLimitedDevice', () async {
      final failure = await _failureFor(
        _dioError(type: DioExceptionType.badResponse, statusCode: 429, scope: 'device'),
      );
      expect(
        failure,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.rateLimitedDevice),
      );
    });

    test('429 with scope: global maps to rateLimitedGlobal (research.md R12/R19)', () async {
      final failure = await _failureFor(
        _dioError(type: DioExceptionType.badResponse, statusCode: 429, scope: 'global'),
      );
      expect(
        failure,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.rateLimitedGlobal),
      );
    });

    test('403 maps to integrityRejected', () async {
      final failure = await _failureFor(
        _dioError(type: DioExceptionType.badResponse, statusCode: 403),
      );
      expect(
        failure,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.integrityRejected),
      );
    });

    test('503 maps to aiDisabled', () async {
      final failure = await _failureFor(
        _dioError(type: DioExceptionType.badResponse, statusCode: 503),
      );
      expect(
        failure,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.aiDisabled),
      );
    });

    test('422 maps to invalidResponse', () async {
      final failure = await _failureFor(
        _dioError(type: DioExceptionType.badResponse, statusCode: 422),
      );
      expect(
        failure,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.invalidResponse),
      );
    });

    test('an unrecognized status maps to invalidResponse', () async {
      final failure = await _failureFor(
        _dioError(type: DioExceptionType.badResponse, statusCode: 500),
      );
      expect(
        failure,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.invalidResponse),
      );
    });

    test('connectionError maps to network', () async {
      final failure = await _failureFor(_dioError(type: DioExceptionType.connectionError));
      expect(failure, isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.network));
    });

    test('connectionTimeout maps to network', () async {
      final failure = await _failureFor(_dioError(type: DioExceptionType.connectionTimeout));
      expect(failure, isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.network));
    });

    test('receiveTimeout maps to timeout', () async {
      final failure = await _failureFor(_dioError(type: DioExceptionType.receiveTimeout));
      expect(failure, isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.timeout));
    });

    test('a client-side Future.timeout maps to timeout', () async {
      when(
        () => client.react(
          installId: any(named: 'installId'),
          characterId: any(named: 'characterId'),
          dayText: any(named: 'dayText'),
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenThrow(TimeoutException('too slow'));
      final result = await repository.requestReaction(
        characterId: 'cat',
        dayText: 'hi',
        dayEntryId: 1,
        moodScore: 3,
        attempt: 0,
      );
      expect(
        result.errorOrNull,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.timeout),
      );
    });
  });

  test(
    'logging never includes dayText or the reply (FR-034b) — a smoke check on the failure payload',
    () async {
      // Not directly observable via the public API; this asserts the
      // returned AppFailure itself carries no request/response content,
      // which is the only thing `TableCubit`/the UI ever sees.
      when(
        () => client.react(
          installId: any(named: 'installId'),
          characterId: any(named: 'characterId'),
          dayText: any(named: 'dayText'),
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenThrow(_dioError(type: DioExceptionType.connectionError));

      final result = await repository.requestReaction(
        characterId: 'cat',
        dayText: 'secret diary text',
        dayEntryId: 1,
        moodScore: 3,
        attempt: 0,
      );
      final failure = result.errorOrNull! as AiProxyFailure;
      expect(failure.message, isNot(contains('secret diary text')));
    },
  );
}
