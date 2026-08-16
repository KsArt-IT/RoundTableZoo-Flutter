import 'package:flutter/material.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:toastification/toastification.dart';

/// One-shot startup toast when the reminder is enabled but the system
/// notification permission isn't granted (FR-021b). Deliberately separate
/// from `RootBlocListener`/`FailureToastGate`: this isn't a failure, and
/// "once per process" is a plain field here rather than routed through a
/// new global Cubit (`project/process/lessons-learned.md`,
/// contracts/ui-contracts.md).
///
/// Must live inside the routed tree — `AppLocalizations.of`/
/// `ToastificationWrapper` aren't reachable above `MaterialApp.router`.
class RemindersMutedToast extends StatefulWidget {
  const RemindersMutedToast({required this.remindersMuted, required this.child, super.key});

  final bool remindersMuted;
  final Widget child;

  @override
  State<RemindersMutedToast> createState() => _RemindersMutedToastState();
}

class _RemindersMutedToastState extends State<RemindersMutedToast> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.remindersMuted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }
  }

  void _maybeShow() {
    if (_shown || !mounted) return;
    _shown = true;
    final l10n = AppLocalizations.of(context);
    toastification.show(
      context: context,
      type: ToastificationType.warning,
      title: Text(l10n.reminderPermissionRevokedToast),
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
