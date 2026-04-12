import '../models/bible_passage_model.dart';
import '../../core/constants/app_constants.dart';

class BibleDataSource {
  static final Map<String, Map<int, List<BiblePassage>>> _kjvData = {};

  Future<void> loadBibleData() async {
    if (_kjvData.isEmpty) {
      _initializeSampleData();
    }
  }

  void _initializeSampleData() {
    final genesisChapters = <int, List<BiblePassage>>{};
    for (int ch = 1; ch <= 3; ch++) {
      genesisChapters[ch] = _getGenesisChapter(ch);
    }
    _kjvData['Genesis'] = genesisChapters;

    final johnChapters = <int, List<BiblePassage>>{};
    johnChapters[1] = _getJohnChapter1();
    johnChapters[3] = _getJohnChapter3();
    _kjvData['John'] = johnChapters;

    final psalmChapters = <int, List<BiblePassage>>{};
    psalmChapters[1] = _getPsalm1();
    psalmChapters[23] = _getPsalm23();
    _kjvData['['] = psalmChapters;
  }

  List<BiblePassage> _getGenesisChapter(int chapter) {
    final passages = <BiblePassage>[];
    if (chapter == 1) {
      passages.addAll([
        BiblePassage(book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning God created the heaven and the earth.'),
        BiblePassage(book: 'Genesis', chapter: 1, verse: 2, text: 'And the earth was without form, and void; and darkness was upon the face of the deep. And the Spirit of God moved upon the face of the waters.'),
        BiblePassage(book: 'Genesis', chapter: 1, verse: 3, text: 'And God said, Let there be light: and there was light.'),
        BiblePassage(book: 'Genesis', chapter: 1, verse: 4, text: 'And God saw the light, that it was good: and God divided the light from the darkness.'),
        BiblePassage(book: 'Genesis', chapter: 1, verse: 5, text: 'And God called the light Day, and the darkness he called Night. And the evening and the morning were the first day.'),
      ]);
    } else if (chapter == 2) {
      passages.addAll([
        BiblePassage(book: 'Genesis', chapter: 2, verse: 1, text: 'Thus the heavens and the earth were finished, and all the host of them.'),
        BiblePassage(book: 'Genesis', chapter: 2, verse: 2, text: 'And on the seventh day God ended his work which he had made; and he rested on the seventh day from all his work which he had made.'),
        BiblePassage(book: 'Genesis', chapter: 2, verse: 3, text: 'And God blessed the seventh day, and sanctified it: because that in it he had rested from all his work which God created and made.'),
        BiblePassage(book: 'Genesis', chapter: 2, verse: 7, text: 'And the LORD God formed man of the dust of the ground, and breathed into his nostrils the breath of life; and man became a living soul.'),
      ]);
    } else if (chapter == 3) {
      passages.addAll([
        BiblePassage(book: 'Genesis', chapter: 3, verse: 1, text: 'Now the serpent was more subtil than any beast of the field which the LORD God had made. And he said unto the woman, Yea, hath God said, Ye shall not eat of every tree of the garden?'),
        BiblePassage(book: 'Genesis', chapter: 3, verse: 8, text: 'And they heard the voice of the LORD God walking in the garden in the cool of the day: and Adam and his wife hid themselves from the presence of the LORD God amongst the trees of the garden.'),
        BiblePassage(book: 'Genesis', chapter: 3, verse: 9, text: 'And the LORD God called unto Adam, and said unto him, Where art thou?'),
        BiblePassage(book: 'Genesis', chapter: 3, verse: 19, text: 'In the sweat of thy face shalt thou eat bread, till thou return unto the ground; for out of it wast thou taken: for dust thou art, and unto dust shalt thou return.'),
      ]);
    }
    return passages;
  }

  List<BiblePassage> _getJohnChapter1() {
    return [
      BiblePassage(book: 'John', chapter: 1, verse: 1, text: 'In the beginning was the Word, and the Word was with God, and the Word was God.'),
      BiblePassage(book: 'John', chapter: 1, verse: 2, text: 'The same was in the beginning with God.'),
      BiblePassage(book: 'John', chapter: 1, verse: 3, text: 'All things were made by him; and without him was not any thing made that was made.'),
      BiblePassage(book: 'John', chapter: 1, verse: 4, text: 'In him was life; and the life was the light of men.'),
      BiblePassage(book: 'John', chapter: 1, verse: 14, text: 'And the Word was made flesh, and dwelt among us, (and we beheld his glory, the glory as of the only begotten of the Father,) full of grace and truth.'),
    ];
  }

  List<BiblePassage> _getJohnChapter3() {
    return [
      BiblePassage(book: 'John', chapter: 3, verse: 1, text: 'There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:'),
      BiblePassage(book: 'John', chapter: 3, verse: 2, text: 'The same came to Jesus by night, and said unto him, Rabbi, we know that thou art a teacher come from God: for no man can do these miracles that thou doest, except God be with him.'),
      BiblePassage(book: 'John', chapter: 3, verse: 16, text: 'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.'),
      BiblePassage(book: 'John', chapter: 3, verse: 17, text: 'For God sent not his Son into the world to condemn the world; but that the world through him might be saved.'),
    ];
  }

  List<BiblePassage> _getPsalm1() {
    return [
      BiblePassage(book: 'Psalms', chapter: 1, verse: 1, text: 'Blessed is the man that walketh not in the counsel of the ungodly, nor standeth in the way of sinners, nor sitteth in the seat of the scornful.'),
      BiblePassage(book: 'Psalms', chapter: 1, verse: 2, text: 'But his delight is in the law of the LORD; and in his law doth he meditate day and night.'),
      BiblePassage(book: 'Psalms', chapter: 1, verse: 3, text: 'And he shall be like a tree planted by the rivers of water, that bringeth forth his fruit in his season; his leaf also shall not wither; and whatsoever he doeth shall prosper.'),
    ];
  }

  List<BiblePassage> _getPsalm23() {
    return [
      BiblePassage(book: 'Psalms', chapter: 23, verse: 1, text: 'The LORD is my shepherd; I shall not want.'),
      BiblePassage(book: 'Psalms', chapter: 23, verse: 2, text: 'He maketh me to lie down in green pastures: he leadeth me beside the still waters.'),
      BiblePassage(book: 'Psalms', chapter: 23, verse: 3, text: 'He restoreth my soul: he leadeth me in the paths of righteousness for his name\'s sake.'),
      BiblePassage(book: 'Psalms', chapter: 23, verse: 4, text: 'Yea, though I walk through the valley of the shadow of death, I will fear no evil: for thou art with me; thy rod and thy staff they comfort me.'),
      BiblePassage(book: 'Psalms', chapter: 23, verse: 5, text: 'Thou preparest a table before me in the presence of mine enemies: thou anointest my head with oil; my cup runneth over.'),
      BiblePassage(book: 'Psalms', chapter: 23, verse: 6, text: 'Surely goodness and mercy shall follow me all the days of my life: and I will dwell in the house of the LORD for ever.'),
    ];
  }

  BibleChapter? getChapter(String book, int chapter) {
    final chapters = _kjvData[book];
    if (chapters == null || !chapters.containsKey(chapter)) {
      return null;
    }
    return BibleChapter(
      book: book,
      chapter: chapter,
      verses: chapters[chapter]!,
    );
  }

  List<String> getBooks() {
    return AppConstants.booksOfTheBible;
  }

  int getChapterCount(String book) {
    return AppConstants.chaptersPerBook[book] ?? 0;
  }
}
