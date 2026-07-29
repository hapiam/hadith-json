import 'dart:convert';
import 'dart:io';

import 'arabic_match.dart';

/// STAGE: one-time spine patch, run AFTER `import_hadithunlocked.dart`
/// (Muslim) and `fix_muslim_introduction.dart`, idempotent (re-matching
/// and re-writing the same `translations` map is a no-op on a clean
/// re-run).
///
/// Muslim's 6 non-English languages (Bengali, French, Indonesian, Russian,
/// Tamil, Turkish, Urdu) only ever existed via fawaz, joined onto the old
/// fawaz-numbered spine by matching `hadithnumber` directly against
/// `idInBook` (`build_unified_editions.dart`'s generic `_joinFawazLanguage`).
/// That join is exactly the numbering-scheme conflation this whole rebuild
/// fixes -- fawaz's `hadithnumber` never reliably tracked sunnah.com's real
/// citation numbering for Muslim (see DUPLICATE_HADITH_INVESTIGATION.md).
/// Naively re-running that same join against the NEW hadithunlocked-based
/// `idInBook` sequence would reproduce the identical bug, just relocated.
///
/// Fix: match fawaz's own Arabic text (from `db/editions/files/
/// ara-muslim.min.json`) onto the new spine's Arabic text by CONTENT, using
/// the same `arabic_match.dart` technique this pipeline already trusts for
/// exactly this kind of cross-source reconciliation (100.00% verified
/// match rate on Ahmad and Darimi). Once a fawaz row is matched to a new
/// spine row, every language's translation for that same fawaz
/// `hadithnumber` is attached directly onto the new spine row's own
/// `translations` map -- `build_unified_editions.dart`'s generic
/// masters-building loop reads this field directly (see its own doc
/// comment on `preAttached`), no further per-language matching needed
/// there.
///
/// Usage: dart run tool/rebuild_muslim_translations.dart
void main() {
  const spinePath = 'db/by_book/hadithunlocked/muslim.json';
  const langs = {
    'ben': 'bn',
    'fra': 'fr',
    'ind': 'id',
    'rus': 'ru',
    'tam': 'ta',
    'tur': 'tr',
    'urd': 'ur',
  };

  final araRaw =
      jsonDecode(File('db/editions/files/ara-muslim.min.json').readAsStringSync())
          as Map<String, dynamic>;
  final araHadiths = (araRaw['hadiths'] as List).cast<Map>();
  final oldHadithNumbers = <int>[];
  final oldArabic = <String>[];
  for (final h in araHadiths) {
    oldHadithNumbers.add((h['hadithnumber'] as num).toInt());
    oldArabic.add((h['text'] ?? '').toString());
  }

  final spineFile = File(spinePath);
  final spine = jsonDecode(spineFile.readAsStringSync()) as Map<String, dynamic>;
  final newHadiths = (spine['hadiths'] as List)
      .map((h) => Map<String, dynamic>.from(h as Map))
      .toList();
  final canonicalArabic = newHadiths.map((h) => (h['arabic'] ?? '').toString()).toList();

  final stats = MatchStats();
  final matches = matchToCanonical(
    oldArabic: oldArabic,
    canonicalArabic: canonicalArabic,
    oldLabels: [for (final n in oldHadithNumbers) 'fawaz:$n'],
    stats: stats,
  );
  stdout.writeln(
    'Arabic content match: ${matches.where((m) => m != null).length}/'
    '${matches.length} fawaz rows matched onto the new spine '
    '(anchor=${stats.anchorMatches}, fuzzy=${stats.fuzzyMatches}, unmatched=${stats.unmatched}).',
  );

  final hnToNewIndex = <int, int>{};
  for (var i = 0; i < matches.length; i++) {
    if (matches[i] != null) hnToNewIndex[oldHadithNumbers[i]] = matches[i]!;
  }

  for (final entry in langs.entries) {
    final prefix = entry.key;
    final iso = entry.value;
    final langFile = File('db/editions/files/$prefix-muslim.min.json');
    if (!langFile.existsSync()) {
      stdout.writeln('$prefix: no fawaz edition file, skipped.');
      continue;
    }
    final langRaw = jsonDecode(langFile.readAsStringSync()) as Map<String, dynamic>;
    final langHadiths = (langRaw['hadiths'] as List).cast<Map>();
    var attached = 0;
    var withText = 0;
    for (final h in langHadiths) {
      final hn = (h['hadithnumber'] as num).toInt();
      final text = (h['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      withText++;
      final newIdx = hnToNewIndex[hn];
      if (newIdx == null) continue;
      final row = newHadiths[newIdx];
      final translations = (row['translations'] as Map?) ?? <String, dynamic>{};
      translations[iso] = {'narrator': '', 'text': text};
      row['translations'] = translations;
      attached++;
    }
    stdout.writeln('$prefix ($iso): $attached/$withText fawaz rows with text attached to the new spine.');
  }

  spine['hadiths'] = newHadiths;
  spineFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(spine));
  stdout.writeln('$spinePath updated.');
}
