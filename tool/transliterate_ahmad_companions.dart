// STAGE: one-time (or rare, if new un-transliterated companion entries ever
// get added) data-repair script, run directly against the spine, not part
// of the regular rebuild/build/report loop.
//
// INPUT/OUTPUT: reads and rewrites `db/by_book/the_9_books/ahmed.json` in
// place -- specifically its `chapters` list's sub-chapter (`parentId !=
// null`) entries, i.e. Musnad Ahmad's companion/Sahabah-level catalog nodes
// (see README's "Two-level chapters (Ahmad only, so far)" section for what
// `parentId` means here). Top-level Musnad-group chapters are skipped
// entirely (`m['parentId'] == null`) since those already have real English
// names from the original scrape.
//
// Fills the `en` field for every Musnad Ahmad companion/chapter entry that
// is still missing one, using:
//  1. A curated dictionary of the ~150 recurring Arabic name components
//     (kunyas, given names, tribal nisbas) that make up the vast majority of
//     companion-name text in this dataset (built from an actual token
//     frequency count over all 1,214 entries — see tool/dump_ahmad_companion_tokens.dart).
//  2. Regex templates for the handful of recurring *relational* phrasings
//     found in the raw data (e.g. "X's hadiths narrated from Y", "X's
//     narration from his grandmother") and for the ~155 `anonymousNarrator`
//     entries plus a handful of un-tagged ones, which hold a descriptive
//     Urdu phrase instead of a name.
//  3. A deterministic letter-by-letter Arabic/Urdu→Latin fallback for any
//     token neither list recognizes — real romanization, not invention, but
//     lower-confidence than the dictionary. Every entry this script writes
//     gets `transliterated: true` so a future research pass can find and
//     verify them.
//
// Every entry keeps its `needsTranslation` tag removed for "en" only once a
// value is written; anonymousNarrator entries still lack `ar`, so their
// "ar" needsTranslation tag is left untouched (out of scope here — see
// hapi_app_v2 task #254).
//
// TODO: the comment above (and the dictionary-derivation methodology it
// describes) references `tool/dump_ahmad_companion_tokens.dart` as the
// script that produced the token-frequency count `_nameDict` was built
// from -- that file does not exist anywhere in this repo's `tool/`
// directory or (as far as a quick check shows) git history. Same class of
// issue as `arabic_match.dart`'s missing caller script noted in
// NUMBERING_CORRUPTION_AUDIT.md: the dictionary itself is trustworthy and
// checked-in, but the tool that derived it is not reproducible from this
// repo alone. Worth either recovering/recommitting it or removing the dead
// reference.
import 'dart:convert';
import 'dart:io';

const _honorificStrip = <String>{
  'رضی',
  'رضِی',
  'رضى',
  'رضي',
  'اللہ',
  'الله',
  'عنہ',
  'عنه',
  'عنہا',
  'عنها',
  'عنہما',
  'عنهما',
  'عنہم',
  'عنهم',
  'تعالی',
  'تعالى',
  'علیہ',
  'عليه',
  'صلی',
  'صلى',
  'وسلم',
  'ﷺ',
};

// Urdu grammar/connective words + generic hadith-metadata nouns that show up
// mixed into the `ar` field but aren't part of the person's name.
const _noiseStrip = <String>{
  'کی',
  'کے',
  'کا',
  'سے',
  'اور',
  'ایک',
  'حدیث',
  'احادیث',
  'صحابی',
  'صحابہ',
  'صحابیہ',
  'بعض',
  'مروی',
  'روایات',
  'روایت',
  'رسول',
  'والد',
  'زوجہ',
  'خاتون',
  'نام',
  'نامی',
  'کہ',
  'چند',
  'شخص',
  'آدمی',
  'جد',
  'اصحاب',
  'وفد',
  'خادم',
  'اپنے',
  'اپنی',
  'دیہاتی',
  'صاحب',
  'جو',
  'ہیں',
  'ہے',
  'میں',
  'پر',
  'نے',
  'کو',
  'تھا',
  'تھی',
  'تھے',
  'ہو',
  'گیا',
  'گئی',
  'ان',
  'حضرت',
  'یا',
};

const Map<String, String> _nameDict = {
  'بن': 'ibn', 'ابن': 'ibn', 'بنت': 'bint', 'ام': 'Umm', 'ابو': 'Abu',
  'عبداللہ': 'Abdullah', 'عبیداللہ': 'Ubaydullah',
  'کعب': "Ka'b", 'عمرو': 'Amr', 'عمروبن': 'Amr ibn', 'مالک': 'Malik',
  'حارث': 'Harith', 'الحارث': 'al-Harith', 'قیس': 'Qais',
  'انصاری': 'al-Ansari', 'الانصاری': 'al-Ansari',
  'عبدالرحمن': 'Abdur Rahman', 'عبدالرحمٰن': 'Abdur Rahman',
  'الرحمن': 'al-Rahman', 'سعد': "Sa'd", 'سلمہ': 'Salama', 'عامر': 'Amir',
  'زید': 'Zayd', 'سلمی': 'Sulami', 'سفیان': 'Sufyan', 'خالد': 'Khalid',
  'عبد': 'Abd', 'سوید': 'Suwayd', 'رافع': 'Rafi', 'عثمان': 'Uthman',
  'عمر': 'Umar', 'یزید': 'Yazid', 'عقبہ': 'Uqba', 'امیہ': 'Umayya',
  'مسعود': "Mas'ud", 'عبادہ': 'Ubada', 'طالب': 'Talib',
  'معاویہ': 'Muawiya', 'سہل': 'Sahl', 'ربیعہ': "Rabi'a", 'عبید': 'Ubayd',
  'مزنی': 'Muzani', 'محمد': 'Muhammad', 'حکیم': 'Hakim',
  'غفاری': 'Ghifari', 'ثابت': 'Thabit', 'اسود': 'Aswad', 'معقل': "Ma'qil",
  'طارق': 'Tariq', 'سعید': "Sa'eed", 'ثقفی': 'Thaqafi', 'اوس': 'Aws',
  'زیاد': 'Ziyad', 'نعمان': "Nu'man", 'عباس': 'Abbas', 'جہنی': 'Juhani',
  'اسلمی': 'Aslami', 'حارثہ': 'Haritha', 'صفوان': 'Safwan', 'حکم': 'Hakam',
  'الحکم': 'al-Hakam', 'اشجعی': "Ashja'i", 'ہشام': 'Hisham',
  'خزاعی': "Khuza'i", 'عدی': 'Adi', 'سلیمان': 'Sulayman', 'خولہ': 'Khawla',
  'حنظلہ': 'Hanzala', 'انس': 'Anas', 'اشعری': "Ash'ari", 'قتادہ': 'Qatada',
  'وہب': 'Wahb', 'معاذ': "Mu'adh", 'علی': 'Ali', 'عاصم': 'Asim',
  'ابوسعید': "Abu Sa'eed", 'نعیم': "Nu'aym", 'رفاعہ': "Rifa'a",
  'شداد': 'Shaddad', 'صخر': 'Sakhr', 'حصین': 'Husayn', 'عتبہ': 'Utba',
  'مرہ': 'Murra', 'اسدی': 'Asadi', 'حبیبہ': 'Habiba', 'عطیہ': 'Atiyya',
  'بشیر': 'Bashir', 'ذی': 'Dhi', 'حابس': 'Habis', 'مغفل': 'Mughaffal',
  'قرہ': 'Qurra', 'طلحہ': 'Talha', 'حذیفہ': 'Hudhayfa',
  'السعدی': "al-Sa'di", 'کرز': 'Kurz', 'جابر': 'Jabir', 'عروہ': 'Urwa',
  'جندب': 'Jundab', 'فاتک': 'Fatik', 'خریم': 'Khuraym', 'محجن': 'Mihjan',
  'سلام': 'Salam', 'ابوبردہ': 'Abu Burda', 'ارقم': 'Arqam',
  'عباد': 'Abbad', 'السلمی': 'al-Sulami', 'زرقی': 'Zurqi',
  'العاص': 'al-As', 'عبدالمطلب': 'Abd al-Muttalib', 'عمارہ': 'Umara',
  'جاریہ': 'Jariya', 'ضحاک': 'Dahhak', 'سلیم': 'Sulaym',
  'سائب': "Sa'ib", 'خبیب': 'Khubayb', 'عرفجہ': 'Urfuja', 'سلمان': 'Salman',
  'صیفی': 'Sayfi', 'ملحان': 'Milhan', 'طفیل': 'Tufayl', 'سنان': 'Sinan',
  'مسلمہ': 'Muslama', 'قدامہ': 'Qudama', 'حبیب': 'Habib',
  'واثلہ': 'Wathila', 'فاطمہ': 'Fatima', 'خباب': 'Khabbab',
  'احوص': 'Ahwas', 'میمونہ': 'Maymuna', 'درداء': 'Darda', 'صبرہ': 'Sabra',
  'معبد': "Ma'bad", 'عبیدہ': 'Ubayda', 'سمرہ': 'Samura', 'علاء': 'Ala',
  'ثعلبہ': "Tha'laba", 'عنبری': 'Anbari', 'صرد': 'Surad', 'بدری': 'Badri',
  'عبدالقیس': 'Abd al-Qays', 'حرام': 'Haram',
  'ابوعبدالرحمن': 'Abu Abdur Rahman', 'حضرمی': 'Hadrami', 'قراد': 'Qurad',
  'حبشی': 'Habashi', 'بسر': 'Busr', 'ابوہریرہ': 'Abu Hurayrah',
  'دوسی': 'Dawsi', 'صدیق': 'as-Siddiq',
  'زبیر': 'Zubayr', 'شیخ': 'Shaykh', 'موسی': 'Musa', 'ذر': 'Dharr',
  'دردا': 'Darda', 'ایوب': 'Ayyub', 'اسید': 'Usayd', 'رمثہ': 'Rimtha',
  'غادیہ': 'Ghadiya', 'ابوبکر': 'Abu Bakr', 'یوسف': 'Yusuf', 'حمید': 'Hamid',
  'حوالہ': 'Hawala',
  // "ابی" is far more often the genitive construct "Abi" (as in the
  // extremely common patronymic "ibn Abi so-and-so") than the specific
  // companion Ubay ibn Ka'b — that one figure is handled as a
  // post-processing step on the English output (see `_transliterateName`),
  // since it only differs from the generic case in that one spot.
  'ابی': 'Abi',
};

// Nisba/tribal words that only ever appear with the "ال" article attached
// in this dataset — listed bare here since the article is stripped and
// re-added generically (see `_lookupToken`).
const Map<String, String> _nisbaDict = {
  'انصاری': 'Ansari',
  'خزاعی': "Khuza'i",
  'ثقفی': 'Thaqafi',
  'اسلمی': 'Aslami',
  'اسدی': 'Asadi',
  'حضرمی': 'Hadrami',
  'حبشی': 'Habashi',
  'سلمی': 'Sulami',
  'دوسی': 'Dawsi',
  'قرشی': 'Qurashi',
  'مخزومی': 'Makhzumi',
  'زہری': 'Zuhri',
  'تیمی': 'Taymi',
  'عدوی': 'Adawi',
  'کندی': 'Kindi',
  'اشعری': "Ash'ari",
  'جہنی': 'Juhani',
  'ازدی': 'Azdi',
  'بصری': 'Basri',
  'کوفی': 'Kufi',
  'مدنی': 'Madani',
  'مکی': 'Makki',
  'شامی': 'Shami',
};

// Relative words for the "X's narration from his/her ___" template.
const Map<String, String> _relativeWords = {
  'نانی': 'maternal grandmother',
  'دادی': 'paternal grandmother',
  'والدہ': 'mother',
  'والد': 'father',
  'دادا': 'paternal grandfather',
  'نانا': 'maternal grandfather',
  'چچا': 'paternal uncle',
  'چچاؤں': 'paternal uncles',
  'خالہ': 'maternal aunt',
  'پھوپھی': 'paternal aunt',
  'ماں': 'mother',
};

// Urdu/Farsi letterform variants -> canonical Arabic codepoints, applied
// before the fallback letter transliteration (the `ar` field in this
// dataset is Urdu-keyboard Arabic script, mixing in Urdu-only letterforms).
const Map<String, String> _letterformNormalize = {
  'ک': 'ك',
  'ی': 'ي',
  'ے': 'ي',
  'ہ': 'ه',
  'ھ': 'ه',
  'ں': 'ن',
  'ﷲ': 'الله',
};

// Deterministic Arabic-letter -> Latin fallback (used only for tokens not
// found in `_nameDict`). Short vowels are inherently ambiguous without full
// diacritics, so this defaults every consonant-consonant gap to "a" — a
// common simplification, not a claim of verified accuracy.
const Map<String, String> _letterFallback = {
  'ء': '', 'أ': 'a', 'إ': 'i', 'آ': 'aa', 'ا': 'a', 'ب': 'b', 'ت': 't',
  'ث': 'th', 'ج': 'j', 'ح': 'h', 'خ': 'kh', 'د': 'd', 'ذ': 'dh', 'ر': 'r',
  'ز': 'z', 'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z',
  'ع': "'", 'غ': 'gh', 'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm',
  'ن': 'n', 'ه': 'h', 'و': 'w', 'ي': 'y', 'ة': 'ah', 'گ': 'g', 'پ': 'p',
  'چ': 'ch', 'ژ': 'zh', 'ٹ': 't', 'ڈ': 'd', 'ڑ': 'r',
  // diacritics: drop (handled as no-vowel-insertion, letters carry the a/i/u)
  'َ': '', 'ً': '', 'ُ': '', 'ٌ': '', 'ِ': '', 'ٍ': '', 'ْ': '', 'ّ': '',
};

String _normalizeLetterforms(String s) {
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    buf.write(_letterformNormalize[ch] ?? ch);
  }
  return buf.toString();
}

const _consonantFallbackLetters = <String>{
  'b',
  't',
  'th',
  'j',
  'h',
  'kh',
  'd',
  'dh',
  'r',
  'z',
  's',
  'sh',
  "'",
  'gh',
  'f',
  'q',
  'k',
  'l',
  'm',
  'n',
  'g',
  'p',
  'ch',
  'zh',
};

String _fallbackTransliterateToken(String token) {
  final norm = _normalizeLetterforms(token);
  final parts = <String>[];
  for (final ch in norm.split('')) {
    final mapped = _letterFallback[ch];
    if (mapped == null) continue; // unknown glyph: drop rather than corrupt
    parts.add(mapped);
  }
  if (parts.isEmpty) return token; // nothing recognized at all; keep as-is
  // Unvocalized Arabic omits short vowels entirely in writing — inserting a
  // default "a" between two consecutive consonant sounds keeps the result
  // pronounceable (e.g. "Hdhafh" -> "Hadhafah") at the cost of not always
  // matching the real vowel; this is the deterministic-fallback trade-off
  // the user signed off on, not a claim of verified accuracy.
  final buf = StringBuffer();
  for (var i = 0; i < parts.length; i++) {
    final cur = parts[i];
    if (i > 0 &&
        _consonantFallbackLetters.contains(parts[i - 1]) &&
        _consonantFallbackLetters.contains(cur)) {
      buf.write('a');
    }
    buf.write(cur);
  }
  final out = buf.toString();
  return out.isEmpty ? token : out[0].toUpperCase() + out.substring(1);
}

class _TokenResult {
  _TokenResult(this.en, this.usedFallback);
  final String en;
  final bool usedFallback;
}

/// Resolves one whitespace-separated token to English, handling (in order):
/// an exact dictionary hit (covers concatenated forms like "ابوبکر"), the
/// "ال" tribal/nisba article (stripped + re-added as "al-"), concatenated
/// kunya prefixes ("ابو"/"ام"/"عبد" + a name with no space), then the
/// letter-by-letter fallback.
_TokenResult _lookupToken(String tok) {
  final direct = _nameDict[tok];
  if (direct != null) return _TokenResult(direct, false);

  if (tok.startsWith('ال') && tok.length > 2) {
    final rest = tok.substring(2);
    final nisba = _nisbaDict[rest] ?? _nameDict[rest];
    if (nisba != null) return _TokenResult('al-$nisba', false);
  }

  for (final prefix in const ['ابو', 'ام', 'عبد']) {
    if (tok.length > prefix.length && tok.startsWith(prefix)) {
      final rest = tok.substring(prefix.length);
      final restHit = _lookupToken(rest);
      final english = switch (prefix) {
        'ابو' => 'Abu',
        'ام' => 'Umm',
        _ => 'Abd',
      };
      return _TokenResult('$english ${restHit.en}', restHit.usedFallback);
    }
  }

  return _TokenResult(_fallbackTransliterateToken(tok), true);
}

class _Result {
  _Result(this.en, this.usedFallback, {required this.hasContent});
  final String en;
  final bool usedFallback;

  /// Whether a real name token survived noise/honorific-stripping — false
  /// when the source text was entirely grammar/honorific words (e.g. "a
  /// servant of the Messenger of Allah, peace be upon him"), which would
  /// otherwise slip through as a non-empty string like " (RA)" or "Hadiths
  /// of , narrated from " (the honorific suffix or template wrapper text
  /// alone isn't "content"). Callers must check this, not `en.isEmpty` —
  /// the wrapper text means a broken result is rarely the empty string.
  final bool hasContent;
}

_Result _transliterateName(String arRaw) {
  var hadHonorific = false;
  var usedFallback = false;
  final outTokens = <String>[];
  for (final rawTok in arRaw.split(RegExp(r'\s+'))) {
    final tok = rawTok.trim();
    if (tok.isEmpty) continue;
    if (_honorificStrip.contains(tok)) {
      hadHonorific = true;
      continue;
    }
    if (_noiseStrip.contains(tok)) continue;
    final hit = _lookupToken(tok);
    if (hit.usedFallback) usedFallback = true;
    outTokens.add(hit.en);
  }
  final hasContent = outTokens.isNotEmpty;
  var joined = outTokens.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  // Ubay ibn Ka'b is the one well-known companion whose name happens to
  // collide with the far-more-common genitive construct "Abi" (see
  // `_nameDict`'s note on "ابی") — post-processed here on the plain-English
  // output instead of the Arabic source, so it only ever fires on the
  // specific "Abi ibn Ka'b" sequence this produces.
  joined = joined.replaceAll("Abi ibn Ka'b", "Ubay ibn Ka'b");
  // "ibn"/"bint" read awkwardly capitalized mid-name; only the first word
  // of the whole label should be capitalized like a sentence would be.
  if (hadHonorific) joined = '$joined (RA)';
  return _Result(joined, usedFallback, hasContent: hasContent);
}

/// Handles the three known relational templates seen in the raw data, e.g.
/// "X کی احادیث Y سے مروی" (X's hadiths, narrated from Y) and
/// "X کی اپنی نانی سے روایت" (X's narration from his grandmother). Returns
/// null if `ar` doesn't match any known shape, so the caller falls through
/// to the plain name transliteration path.
_Result? _tryRelationalTemplate(String ar) {
  // Note: no `\b` after Arabic-script groups below — Dart's default RegExp
  // treats `\w`/`\b` as ASCII-only, so a boundary check right after Arabic
  // text silently never matches and breaks the whole pattern; `\s+`/`$`
  // already anchor these correctly without it.
  final hadithsFrom = RegExp(r'^(.+?)\s+کی\s+احادیث\s+(.+?)\s+سے\s+مروی');
  final m1 = hadithsFrom.firstMatch(ar);
  if (m1 != null) {
    final x = _transliterateName(m1.group(1)!);
    final y = _transliterateName(m1.group(2)!);
    // A missing side (e.g. "صحابہ میں سے ایک شخص" — "one of the
    // companions", all noise/no name) becomes "an unnamed narrator" rather
    // than "Hadiths of , narrated from Y"/"...narrated from " — only give up
    // entirely (fall through to the anonymous-phrase path) when *neither*
    // side has a real name.
    if (x.hasContent || y.hasContent) {
      final xText = x.hasContent ? x.en : 'an unnamed narrator';
      final yText = y.hasContent ? y.en : 'an unnamed narrator';
      return _Result(
        'Hadiths of $xText, narrated from $yText',
        x.usedFallback || y.usedFallback,
        hasContent: true,
      );
    }
  }
  // "X کی [اپنی] {relative} سے (روایت|روایات|حدیث) [trailing clause]" — the
  // trailing clause (e.g. "ہے کہ اللہ تعالیٰ ان سے راضی ہو۔") is almost
  // always just more honorific/grammar noise, so it's run back through the
  // plain name path to pick up any honorific and confirm nothing else of
  // substance is in it.
  final relativeFrom = RegExp(
    r'^(.+?)\s+کی\s+(?:اپنی\s+)?(نانی|دادی|والدہ|والد|دادا|نانا|چچاؤں|چچا|خالہ|پھوپھی|ماں)\s+سے\s+(?:روایت|روایات|حدیث)(.*)$',
  );
  final m2 = relativeFrom.firstMatch(ar);
  if (m2 != null) {
    final x = _transliterateName(m2.group(1)!);
    if (x.hasContent) {
      final relative = _relativeWords[m2.group(2)!] ?? m2.group(2)!;
      final trailing = _transliterateName(m2.group(3) ?? '');
      var en = "Narration of ${x.en} from his/her $relative";
      if (trailing.en.contains('(RA)')) en = '$en (RA)';
      return _Result(en, x.usedFallback, hasContent: true);
    }
  }
  final narrationsOf = RegExp(r'^(.+?)\s+کی\s+روایات?$');
  final m3 = narrationsOf.firstMatch(ar);
  if (m3 != null) {
    final x = _transliterateName(m3.group(1)!);
    if (x.hasContent) {
      return _Result('Narrations of ${x.en}', x.usedFallback, hasContent: true);
    }
  }
  return null;
}

/// Translates (not transliterates — these hold a description, not a name)
/// the ~155 `anonymousNarrator` entries plus the handful of un-tagged
/// entries whose `ar`/`ur` is a plain "an unnamed X" phrase rather than a
/// real name (both only ever hold a `ur` phrase, or reduce to nothing once
/// noise-stripped).
String _translateAnonymousPhrase(String phrase) {
  final t = phrase.trim();
  if (t.contains('اصحاب رسول میں سے ایک شخص')) {
    return 'Narrations of an Unnamed Companion';
  }
  if (t.contains('ملاقات کی')) {
    return 'Hadith of a Man Who Met the Messenger of Allah (peace be upon him)';
  }
  if (t.contains('اذان سننے والے')) {
    return "Hadith of the One Who Heard the Prophet's Call to Prayer (peace be upon him)";
  }
  if (t.contains('حدیث نبوی')) {
    return 'Hadith of the Prophet (peace be upon him)';
  }
  if (t.contains('دیہاتی')) {
    return 'Hadith of an Unnamed Bedouin Companion';
  }
  if (t.contains('عورت') || t.contains('خاتون')) {
    return 'Hadith of an Unnamed Woman';
  }
  if (t.contains('آدمی کی حدیث') || t.contains('ایک آدمی')) {
    return 'Hadith of an Unnamed Man, Narrated from the Messenger of Allah (peace be upon him)';
  }
  return 'Hadith of an Unnamed Companion';
}

void main() {
  final path = 'db/by_book/the_9_books/ahmed.json';
  final file = File(path);
  final data = jsonDecode(file.readAsStringSync());
  final chapters = (data is List) ? data : (data['chapters'] as List);

  var filled = 0, dictOnly = 0, usedFallback = 0, anonymous = 0, skipped = 0;
  for (final c in chapters) {
    final m = c as Map;
    if (m['parentId'] == null) continue; // top-level section, already named
    final names = (m['names'] as Map).cast<String, dynamic>();
    if (names['en'] != null) {
      skipped++;
      continue;
    }
    final ar = names['ar'] as String?;
    final ur = names['ur'] as String?;
    // Some entries tagged anonymousNarrator (ar == null) actually name the
    // narrator inside the `ur` sentence (e.g. "X کی حدیث جو ... اصحاب میں
    // سے ایک ہیں" — "hadith of X, one of the companions") rather than
    // being genuinely nameless — so every entry gets a real attempt at
    // `ar ?? ur` first, and only falls back to the canned "Unnamed ..."
    // phrase if that attempt truly finds no name at all.
    final source = ar ?? ur;
    if (source == null) {
      skipped++;
      continue;
    }
    final rel = _tryRelationalTemplate(source);
    final result = rel ?? _transliterateName(source);
    if (!result.hasContent) {
      names['en'] = _translateAnonymousPhrase(source);
      m['anonymousNarrator'] = true;
      anonymous++;
    } else {
      names['en'] = result.en;
      m['transliterated'] = true;
      // A real name was found after all — the anonymousNarrator tag (if
      // any) was a false positive from the source data; drop it.
      m.remove('anonymousNarrator');
      if (result.usedFallback) {
        usedFallback++;
      } else {
        dictOnly++;
      }
    }
    filled++;
    final nt = (m['needsTranslation'] as List?)?.cast<String>();
    if (nt != null) {
      nt.remove('en');
      if (nt.isEmpty) {
        m.remove('needsTranslation');
      } else {
        m['needsTranslation'] = nt;
      }
    }
  }

  file.writeAsStringSync(const JsonEncoder.withIndent('\t').convert(data));

  print(
    'filled: $filled (dict-only: $dictOnly, used fallback: $usedFallback, anonymous: $anonymous)',
  );
  print('already had en / skipped: $skipped');
}
