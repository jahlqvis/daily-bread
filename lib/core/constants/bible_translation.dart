enum BibleTranslation { kjv, asv, web }

extension BibleTranslationX on BibleTranslation {
  String get id {
    switch (this) {
      case BibleTranslation.kjv:
        return 'kjv';
      case BibleTranslation.asv:
        return 'asv';
      case BibleTranslation.web:
        return 'web';
    }
  }

  String get label {
    switch (this) {
      case BibleTranslation.kjv:
        return 'King James Version (KJV)';
      case BibleTranslation.asv:
        return 'American Standard Version (ASV)';
      case BibleTranslation.web:
        return 'World English Bible (WEB)';
    }
  }

  String get shortLabel {
    switch (this) {
      case BibleTranslation.kjv:
        return 'KJV';
      case BibleTranslation.asv:
        return 'ASV';
      case BibleTranslation.web:
        return 'WEB';
    }
  }

  String get assetDirectory => 'assets/bible/${id}_books';
}
