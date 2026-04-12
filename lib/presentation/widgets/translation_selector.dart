import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bible_provider.dart';
import '../../core/constants/bible_translation.dart';

class TranslationSelector extends StatelessWidget {
  const TranslationSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BibleProvider>(
      builder: (context, bibleProvider, _) {
        return PopupMenuButton<BibleTranslation>(
          tooltip: 'Select translation',
          icon: const Icon(Icons.translate),
          onSelected: (translation) {
            bibleProvider.selectTranslation(translation);
          },
          itemBuilder: (context) {
            return bibleProvider.availableTranslations
                .map(
                  (translation) => PopupMenuItem<BibleTranslation>(
                    value: translation,
                    child: Row(
                      children: [
                        Expanded(child: Text(translation.label)),
                        if (translation == bibleProvider.selectedTranslation)
                          const Icon(Icons.check, size: 16),
                      ],
                    ),
                  ),
                )
                .toList();
          },
        );
      },
    );
  }
}
