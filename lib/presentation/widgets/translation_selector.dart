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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: PopupMenuButton<BibleTranslation>(
            tooltip: 'Select translation',
            onSelected: (translation) {
              bibleProvider.selectTranslation(translation);
            },
            position: PopupMenuPosition.under,
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
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    bibleProvider.selectedTranslation.shortLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
