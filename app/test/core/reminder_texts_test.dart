import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/notifications/reminder_texts.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';

/// FR-016a/FR-016b/SC-006a: none of the four notification-facing strings —
/// on any supported language — may hint at the app's actual purpose. These
/// stop words cover the concepts across ru/uk/en; matching is
/// case-insensitive and substring-based so a declined/conjugated form
/// still trips it.
const _stopWords = [
  'настроен', // mood (ru)
  'настрі', // mood (uk)
  'mood',
  'эмоци', // emotion (ru)
  'емоці', // emotion (uk)
  'emotion',
  'чувств', // feeling (ru)
  'почутт', // feeling (uk)
  'feeling',
  'самочувств', // wellbeing (ru)
  'самопочутт', // wellbeing (uk)
  'wellbeing',
  'дневник', // diary (ru)
  'щоденник', // diary (uk)
  'diary',
];

void main() {
  for (final preference in [LocalePreference.ru, LocalePreference.uk, LocalePreference.en]) {
    test('reminderTexts($preference) contains no stop words', () async {
      final texts = await reminderTexts(preference);
      _expectNeutral(texts.title, preference, 'title');
      _expectNeutral(texts.body, preference, 'body');
    });

    test('channelTexts($preference) contains no stop words', () async {
      final texts = await channelTexts(preference);
      _expectNeutral(texts.name, preference, 'channel name');
      _expectNeutral(texts.description, preference, 'channel description');
    });
  }
}

void _expectNeutral(String text, LocalePreference preference, String label) {
  final lower = text.toLowerCase();
  for (final stopWord in _stopWords) {
    expect(
      lower.contains(stopWord),
      isFalse,
      reason: '$preference $label ("$text") contains stop word "$stopWord"',
    );
  }
}
