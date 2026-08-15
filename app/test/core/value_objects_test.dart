import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/domain/value_objects/validators.dart';

void main() {
  group('MoodScore — 1..5', () {
    for (final value in [1, 3, 5]) {
      test('$value is valid', () {
        final result = MoodScore.create(value);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull?.value, value);
      });
    }

    for (final value in [0, 6, -1]) {
      test('$value is rejected', () {
        final result = MoodScore.create(value);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<ValidationFailure>());
        expect(result.errorOrNull?.code, ValidationFailure.moodScoreOutOfRange);
      });
    }
  });

  group('DayStartHour — 0..23', () {
    for (final value in [0, 12, 23]) {
      test('$value is valid', () {
        expect(DayStartHour.create(value).isSuccess, isTrue);
      });
    }

    for (final value in [-1, 24, 100]) {
      test('$value is rejected', () {
        final result = DayStartHour.create(value);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.code, ValidationFailure.dayStartHourOutOfRange);
      });
    }
  });

  group('Validators.intensity — 0.0..1.0', () {
    for (final value in [0.0, 0.5, 1.0]) {
      test('$value is valid', () {
        expect(Validators.intensity(value).isSuccess, isTrue);
      });
    }

    for (final value in [-0.01, 1.01, -1.0, 2.0]) {
      test('$value is rejected', () {
        final result = Validators.intensity(value);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.code, ValidationFailure.intensityOutOfRange);
      });
    }
  });

  group('Validators.dayText — max 2000 chars', () {
    test('exactly 2000 characters is valid', () {
      final text = 'a' * 2000;
      final result = Validators.dayText(text);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, text);
    });

    test('2001 characters is rejected', () {
      final result = Validators.dayText('a' * 2001);
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.code, ValidationFailure.dayTextTooLong);
    });

    test('empty string normalizes to null', () {
      final result = Validators.dayText('');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('null stays null', () {
      final result = Validators.dayText(null);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });
  });

  group('Validators.enabledCharacterIds — must not be empty', () {
    test('non-empty list is valid', () {
      expect(Validators.enabledCharacterIds(['cat']).isSuccess, isTrue);
    });

    test('empty list is rejected', () {
      final result = Validators.enabledCharacterIds(const []);
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.code, ValidationFailure.noCharactersEnabled);
    });
  });

  group('ReactionTone.fromStorage', () {
    test('known name maps to itself', () {
      expect(ReactionTone.fromStorage('warm'), ReactionTone.warm);
    });

    test('unknown name falls back to neutral, never fails', () {
      expect(ReactionTone.fromStorage('anger'), ReactionTone.neutral);
      expect(ReactionTone.fromStorage(null), ReactionTone.neutral);
    });
  });

  group('ThemePreference.fromStorage', () {
    test('known name maps to itself', () {
      expect(ThemePreference.fromStorage('dark'), ThemePreference.dark);
    });

    test('unknown name falls back to system', () {
      expect(ThemePreference.fromStorage('sepia'), ThemePreference.system);
    });
  });

  group('LocalePreference.fromStorage', () {
    test('known name maps to itself', () {
      expect(LocalePreference.fromStorage('uk'), LocalePreference.uk);
    });

    test('unknown name falls back to system', () {
      expect(LocalePreference.fromStorage('fr'), LocalePreference.system);
    });
  });

  group('ReminderTime', () {
    test('valid hour/minute is accepted', () {
      final result = ReminderTime.create(hour: 20, minute: 0);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.toStorageString(), '20:00');
    });

    for (final (hour, minute) in [(-1, 0), (24, 0), (0, -1), (0, 60)]) {
      test('hour=$hour minute=$minute is rejected', () {
        final result = ReminderTime.create(hour: hour, minute: minute);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.code, ValidationFailure.reminderTimeInvalid);
      });
    }

    test('fromStorage parses HH:mm', () {
      final parsed = ReminderTime.fromStorage('07:05');
      expect(parsed.hour, 7);
      expect(parsed.minute, 5);
    });

    test('fromStorage falls back to default on malformed input', () {
      expect(ReminderTime.fromStorage('garbage'), ReminderTime.defaultValue);
      expect(ReminderTime.fromStorage('25:99'), ReminderTime.defaultValue);
    });
  });
}
