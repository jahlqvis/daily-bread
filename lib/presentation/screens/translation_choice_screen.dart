import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/bible_translation.dart';
import '../providers/bible_provider.dart';

class TranslationChoiceGate extends StatelessWidget {
  const TranslationChoiceGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return context.watch<BibleProvider>().hasChosenTranslation
        ? child
        : const TranslationChoiceScreen();
  }
}

class TranslationChoiceScreen extends StatefulWidget {
  const TranslationChoiceScreen({super.key});

  @override
  State<TranslationChoiceScreen> createState() =>
      _TranslationChoiceScreenState();
}

class _TranslationChoiceScreenState extends State<TranslationChoiceScreen> {
  BibleTranslation? _selection;
  bool _saving = false;

  Future<void> _continue() async {
    final selection = _selection;
    if (selection == null || _saving) return;
    setState(() => _saving = true);
    await context.read<BibleProvider>().selectTranslation(selection);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final error = context.watch<BibleProvider>().translationSaveError;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose your Bible translation',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Read offline without an account. You can change your translation later.',
                  ),
                  const SizedBox(height: 24),
                  RadioGroup<BibleTranslation>(
                    groupValue: _selection,
                    onChanged: (value) {
                      if (!_saving) setState(() => _selection = value);
                    },
                    child: Column(
                      children: [
                        for (final translation in BibleTranslation.values)
                          RadioListTile<BibleTranslation>(
                            title: Text(translation.label),
                            value: translation,
                            enabled: !_saving,
                          ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _selection == null || _saving ? null : _continue,
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
