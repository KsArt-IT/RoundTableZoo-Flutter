import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/errors/safe_call_mixin.dart';
import 'package:roundtablezoo/domain/entities/character.dart';

/// Loads and caches `assets/characters/characters.json`
/// (`specs/004-table-screen/contracts/character-config.md`). Parsed once per
/// session — the cached list is returned on every later call. Registered as
/// `@lazySingleton` in `injection_module.dart`, so that cache is shared for
/// the app's lifetime.
class CharacterCatalog with SafeCallMixin {
  /// [assetLoader] defaults to `rootBundle.loadString` — overridable so
  /// tests can feed arbitrary JSON without a real asset bundle.
  CharacterCatalog({Future<String> Function(String key)? assetLoader})
    : _assetLoader = assetLoader ?? rootBundle.loadString;

  static const _assetPath = 'assets/characters/characters.json';

  final Future<String> Function(String key) _assetLoader;

  List<Character>? _cache;

  Future<Result<List<Character>>> load() {
    final cached = _cache;
    if (cached != null) return Future.value(Result.success(cached));

    return safeCall(() async {
      final raw = await _assetLoader(_assetPath);
      final characters = _parse(raw);
      _cache = characters;
      return characters;
    });
  }

  List<Character> _parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.isEmpty) {
      throw const FormatException('characters.json must be a non-empty array');
    }

    final seenIds = <String>{};
    return decoded.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('characters.json entry must be an object');
      }
      return _parseCharacter(entry, seenIds);
    }).toList(growable: false);
  }

  Character _parseCharacter(Map<String, dynamic> json, Set<String> seenIds) {
    final id = json['id'];
    final name = json['name'];
    final colorHex = json['colorHex'];
    final fallbackReply = json['fallbackReply'];
    final maxReplyLength = json['maxReplyLength'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('characters.json entry missing non-empty "id"');
    }
    if (!seenIds.add(id)) {
      throw FormatException('characters.json duplicate id "$id"');
    }
    if (name is! String || name.isEmpty) {
      throw FormatException('characters.json entry "$id" missing non-empty "name"');
    }
    if (colorHex is! String) {
      throw FormatException('characters.json entry "$id" missing "colorHex"');
    }
    if (fallbackReply is! String || fallbackReply.isEmpty) {
      throw FormatException('characters.json entry "$id" missing non-empty "fallbackReply"');
    }
    if (maxReplyLength is! int || maxReplyLength <= 0) {
      throw FormatException('characters.json entry "$id" missing positive "maxReplyLength"');
    }

    return Character(
      id: id,
      name: name,
      colorHex: _parseColorHex(colorHex, id),
      fallbackReply: fallbackReply,
      maxReplyLength: maxReplyLength,
      idleAnimation: json['idleAnimation'] as String?,
      talkAnimation: json['talkAnimation'] as String?,
    );
  }

  int _parseColorHex(String value, String id) {
    final hex = value.startsWith('#') ? value.substring(1) : value;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) {
      throw FormatException('characters.json entry "$id" has invalid colorHex "$value"');
    }
    return 0xFF000000 | parsed;
  }
}
