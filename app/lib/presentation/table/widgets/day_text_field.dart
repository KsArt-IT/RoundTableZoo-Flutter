import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// The day's free-text field — capped at
/// `AppConstants.maxDayTextLength` with a visible counter (FR-007, FR-008).
/// A controlled widget: [text] is the source of truth (`TableData.dayText`
/// in `TableCubit`), [onChanged] is the only way this field's contents
/// change.
class DayTextField extends StatefulWidget {
  const DayTextField({required this.text, required this.onChanged, this.enabled = true, super.key});

  final String text;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<DayTextField> createState() => _DayTextFieldState();
}

class _DayTextFieldState extends State<DayTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(covariant DayTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reconcile from outside when it actually diverges (e.g. a day
    // switch reloading a different draft) — otherwise every keystroke's
    // own round trip through `TableCubit` would reset the cursor position.
    if (widget.text != _controller.text) {
      _controller.value = _controller.value.copyWith(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      maxLength: AppConstants.maxDayTextLength,
      maxLines: 4,
      minLines: 2,
      inputFormatters: [LengthLimitingTextInputFormatter(AppConstants.maxDayTextLength)],
      buildCounter: (context, {required currentLength, required isFocused, required maxLength}) =>
          Text(
            l10n.tableDayTextCounter(currentLength, maxLength ?? AppConstants.maxDayTextLength),
            style: Theme.of(context).textTheme.bodySmall,
          ),
      decoration: InputDecoration(
        hintText: l10n.tableDayTextPlaceholder,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
