import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/data/datasources/character_catalog.dart';

const _validJson = '''
[
  {
    "id": "cat",
    "emoji": "🐱",
    "name": "Кот",
    "colorHex": "#8A7CA8",
    "idleAnimation": "assets/lottie/cat_idle.json",
    "talkAnimation": "assets/lottie/cat_talk.json",
    "fallbackReply": "Мр-р.",
    "maxReplyLength": 220
  },
  {
    "id": "dog",
    "emoji": "",
    "name": "Пёс",
    "colorHex": "#C08A4A",
    "fallbackReply": "Гав!",
    "maxReplyLength": 200,
    "unknownField": "ignored"
  }
]
''';

CharacterCatalog _catalogWith(String json) => CharacterCatalog(assetLoader: (_) async => json);

void main() {
  test('load() parses a well-formed catalog, in asset order', () async {
    final result = await _catalogWith(_validJson).load();

    expect(result.isSuccess, isTrue);
    final characters = result.valueOrNull!;
    expect(characters.map((c) => c.id), ['cat', 'dog']);
    expect(characters.first.name, 'Кот');
    expect(characters.first.colorHex, 0xFF8A7CA8);
    expect(characters.first.idleAnimation, 'assets/lottie/cat_idle.json');
    expect(characters.first.emoji, '🐱');
    // Unknown fields are silently ignored, and missing optional animation
    // fields don't fail parsing.
    expect(characters.last.idleAnimation, isNull);
    // An empty `emoji` is normalized to null rather than reaching the
    // avatar as a blank glyph — it must fall back to the name's letter.
    expect(characters.last.emoji, isNull);
  });

  test('load() treats a missing "emoji" as absent, not as an error', () async {
    const json = '''
[
  {
    "id": "hippo",
    "name": "Бегемот",
    "colorHex": "#6E8FAE",
    "fallbackReply": "Хм.",
    "maxReplyLength": 220
  }
]
''';

    final result = await _catalogWith(json).load();

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.single.emoji, isNull);
  });

  test('load() caches the parsed result across calls', () async {
    var loadCount = 0;
    final catalog = CharacterCatalog(
      assetLoader: (_) async {
        loadCount++;
        return _validJson;
      },
    );

    await catalog.load();
    await catalog.load();

    expect(loadCount, 1);
  });

  test('load() fails with SerializationFailure on a missing required field', () async {
    const json =
        '[{"id": "cat", "colorHex": "#8A7CA8", "fallbackReply": "x", "maxReplyLength": 1}]';

    final result = await _catalogWith(json).load();

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull, isA<SerializationFailure>());
  });

  test('load() fails with SerializationFailure on a duplicate id', () async {
    const json = '''
[
  {"id": "cat", "name": "A", "colorHex": "#000000", "fallbackReply": "x", "maxReplyLength": 1},
  {"id": "cat", "name": "B", "colorHex": "#111111", "fallbackReply": "y", "maxReplyLength": 1}
]
''';

    final result = await _catalogWith(json).load();

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull, isA<SerializationFailure>());
  });

  test('load() fails with SerializationFailure on an empty array', () async {
    final result = await _catalogWith('[]').load();

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull, isA<SerializationFailure>());
  });

  test('load() parses "voice" into pitch/rate', () async {
    const json = '''
[
  {
    "id": "cat", "name": "Кот", "colorHex": "#8A7CA8",
    "fallbackReply": "x", "maxReplyLength": 220,
    "voice": {"pitch": 1.5, "rate": 0.62}
  }
]
''';

    final result = await _catalogWith(json).load();

    final voice = result.valueOrNull!.single.voice;
    expect(voice.pitch, 1.5);
    expect(voice.rate, 0.62);
  });

  test(
    'load() defaults a missing, non-object, or partial "voice" to neutral (1.0/0.5)',
    () async {
      const json = '''
[
  {"id": "cat", "name": "A", "colorHex": "#000000", "fallbackReply": "x", "maxReplyLength": 1},
  {
    "id": "dog", "name": "B", "colorHex": "#111111", "fallbackReply": "y", "maxReplyLength": 1,
    "voice": "not an object"
  },
  {
    "id": "crocodile", "name": "C", "colorHex": "#222222", "fallbackReply": "z",
    "maxReplyLength": 1, "voice": {"pitch": 1.2}
  }
]
''';

      final result = await _catalogWith(json).load();

      final characters = result.valueOrNull!;
      expect(characters[0].voice.pitch, 1.0);
      expect(characters[0].voice.rate, 0.5);
      expect(characters[1].voice.pitch, 1.0);
      expect(characters[1].voice.rate, 0.5);
      // Partial "voice": the present field parses, the missing one falls
      // back to neutral independently.
      expect(characters[2].voice.pitch, 1.2);
      expect(characters[2].voice.rate, 0.5);
    },
  );

  test('load() clamps out-of-range "voice" values instead of failing', () async {
    const json = '''
[
  {
    "id": "cat", "name": "A", "colorHex": "#000000", "fallbackReply": "x",
    "maxReplyLength": 1, "voice": {"pitch": 99, "rate": -5}
  }
]
''';

    final result = await _catalogWith(json).load();

    expect(result.isSuccess, isTrue);
    final voice = result.valueOrNull!.single.voice;
    expect(voice.pitch, 2.0);
    expect(voice.rate, 0.0);
  });

  test(
    'shipped characters.json orders pitch and rate cat > dog > crocodile > hippo (FR-003)',
    () async {
      final json = await File('assets/characters/characters.json').readAsString();
      final catalog = CharacterCatalog(assetLoader: (_) async => json);

      final result = await catalog.load();

      final byId = {for (final c in result.valueOrNull!) c.id: c};
      expect(jsonDecode(json), isA<List<dynamic>>());
      expect(byId['cat']!.voice.pitch, greaterThan(byId['dog']!.voice.pitch));
      expect(byId['dog']!.voice.pitch, greaterThan(byId['crocodile']!.voice.pitch));
      expect(byId['crocodile']!.voice.pitch, greaterThan(byId['hippo']!.voice.pitch));
      expect(byId['cat']!.voice.rate, greaterThan(byId['dog']!.voice.rate));
      expect(byId['dog']!.voice.rate, greaterThan(byId['crocodile']!.voice.rate));
      expect(byId['crocodile']!.voice.rate, greaterThan(byId['hippo']!.voice.rate));
    },
  );
}
