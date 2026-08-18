import 'package:json_annotation/json_annotation.dart';

part 'ai_reaction_dto.g.dart';

/// Raw ai-proxy `/react` response
/// (`specs/004-table-screen/contracts/ai-proxy-client.md` §3). All fields
/// are nullable — a missing/malformed field is a parsing outcome to
/// validate, not a reason for `fromJson` itself to throw; the rules from
/// §3 (required-ness, ranges, fallbacks) are applied by
/// `AiReactionRepositoryImpl`, the single place allowed to turn this into
/// an `AiProxyFailure`.
@JsonSerializable()
class AiReactionDto {
  const AiReactionDto({this.character, this.mood, this.reply, this.intensity});

  factory AiReactionDto.fromJson(Map<String, dynamic> json) => _$AiReactionDtoFromJson(json);

  final String? character;
  final String? mood;
  final String? reply;
  final double? intensity;

  Map<String, dynamic> toJson() => _$AiReactionDtoToJson(this);
}
