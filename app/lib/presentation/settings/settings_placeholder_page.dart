import 'package:flutter/material.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

class SettingsPlaceholderPage extends StatelessWidget {
  const SettingsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).sectionSettings)),
    );
  }
}
