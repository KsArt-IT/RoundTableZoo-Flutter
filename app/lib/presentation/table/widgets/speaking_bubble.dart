import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/sharing/share_service.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// The reveal-as-you-read effect for a character's reply (research.md R8).
/// Purely presentational — `TableCubit` never emits per-character; the
/// controller lives entirely in this widget's state.
///
/// A **short tap** completes the reveal instantly (FR-017a). A restored
/// reply (`restored: true`, FR-003b) or the system's "reduce motion"
/// setting (FR-033a) shows the full text immediately, no reveal at all.
/// A **long press** shares the reply text plus the character's name
/// through [shareService] (FR-030); the same action is also exposed as a
/// named semantics action, not only as a gesture (FR-030).
class SpeakingBubble extends StatefulWidget {
  const SpeakingBubble({
    required this.reaction,
    required this.characterName,
    required this.shareService,
    this.stale = false,
    this.restored = false,
    this.onRevealed,
    super.key,
  });

  final CharacterReaction reaction;
  final String characterName;
  final ShareService shareService;
  final bool stale;
  final bool restored;

  /// Fired once the full reply is visible — on its own (`forward()`
  /// completing) or via the short-tap skip. Lets the seat widget flip its
  /// avatar from "speaking" back to "answered" (FR-011).
  final VoidCallback? onRevealed;

  @override
  State<SpeakingBubble> createState() => _SpeakingBubbleState();
}

class _SpeakingBubbleState extends State<SpeakingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _durationFor(widget.reaction.reply),
  )..addStatusListener(_onStatusChanged);

  bool _started = false;

  static Duration _durationFor(String text) {
    final ms = (text.length * 25).clamp(0, AppConstants.speakingBubbleMaxDuration.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onRevealed?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.restored || MediaQuery.disableAnimationsOf(context)) {
      // A restored reply can be part of the very first build (US3 —
      // reactions restored by `load()`). Setting `_controller.value = 1`
      // here fires its status listener synchronously, which calls
      // `setState` on an ancestor mid-build — deferred to the next frame
      // instead (harmless for the freshly-received case: this only runs
      // once, on mount).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.value = 1;
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _revealNow() => _controller.value = 1;

  Future<void> _share() =>
      widget.shareService.shareText('${widget.characterName}: ${widget.reaction.reply}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reply = widget.reaction.reply;
    final isFallback = widget.reaction.isFallback;

    return GestureDetector(
      onTap: _revealNow,
      onLongPress: () => unawaited(_share()),
      child: Semantics(
        // Re-announced whenever this subtree's semantics change — a fresh
        // bubble mounting (or `stale` toggling) reaches screen readers
        // without a separate polite-announcement channel (FR-036).
        liveRegion: true,
        label: _semanticsLabel(l10n, reply, isFallback: isFallback),
        // FR-030: "поделиться" must reach screen-reader users as a named
        // action, not only as a long-press gesture they'd have to guess.
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.tableShareAction): () => unawaited(_share()),
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final revealed = (reply.length * _controller.value).round();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reply.substring(0, revealed)),
                  if (isFallback || widget.stale) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFallback) ...[
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.tableReplyFallbackLabel,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                        if (isFallback && widget.stale) const SizedBox(width: 8),
                        if (widget.stale)
                          Text(
                            l10n.tableReplyStaleLabel,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _semanticsLabel(AppLocalizations l10n, String reply, {required bool isFallback}) {
    final parts = [reply];
    if (isFallback) parts.add(l10n.tableReplyFallbackLabel);
    if (widget.stale) parts.add(l10n.tableReplyStaleLabel);
    return parts.join('. ');
  }
}
