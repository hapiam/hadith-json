import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine enrichment, repeatable/idempotent.
///
/// Follow-up fix to `tool/merge_amrayn_missing_hadith.dart`: that tool
/// skipped backfilling a blank-Arabic spine row whenever amrayn's content
/// for that exact citation number happened to content-match some OTHER
/// row elsewhere in the spine (via `matchToCanonical`) -- e.g. Muslim's
/// well-known citation #1 ("Do not lie about me...") stayed blank because
/// its Arabic text apparently cross-matched a different row with a
/// similar isnad opening. That's the wrong check for backfilling: a blank
/// slot is blank regardless of what its content superficially resembles
/// elsewhere -- if our spine already has a row AT amrayn's own idInBook
/// number and that row's `arabic` is empty, amrayn's content unambiguously
/// belongs there (same citation number, same book), full stop.
///
/// This does the direct, no-content-matching version: for every remaining
/// blank-Arabic row, look up amrayn's own record at the identical
/// `idInBook` and fill it in if found. Purely additive on top of whatever
/// `merge_amrayn_missing_hadith.dart` already did -- the addenda it added
/// are untouched and still correct (those were content-matcher-confirmed
/// as absent from the ENTIRE spine, which is the right check for "is this
/// genuinely new content", just not for "does this exact numbered slot
/// have its content").
///
/// Usage: dart run tool/backfill_blank_from_amrayn.dart
void main() {
  const books = [
    _BookConfig('muslim', 'db/by_book/the_9_books/muslim.json'),
    _BookConfig('nasai', 'db/by_book/the_9_books/nasai.json'),
    _BookConfig('abudawud', 'db/by_book/the_9_books/abudawud.json'),
    _BookConfig('tirmidhi', 'db/by_book/the_9_books/tirmidhi.json'),
    _BookConfig('ibnmajah', 'db/by_book/the_9_books/ibnmajah.json'),
    _BookConfig('malik', 'db/by_book/the_9_books/malik.json'),
  ];
  final bracketRe = RegExp(r'^(.*?)\s*\[([^\]]+)\]$');

  for (final book in books) {
    final spineFile = File(book.spinePath);
    final spineData = jsonDecode(spineFile.readAsStringSync()) as Map<String, dynamic>;
    final spineHadiths = (spineData['hadiths'] as List)
        .map((h) => Map<String, dynamic>.from(h as Map))
        .toList();
    final byIdInBook = <int, Map<String, dynamic>>{
      for (final h in spineHadiths)
        if (h['idInBook'] != null) (h['idInBook'] as num).toInt(): h,
    };

    final amraynData = jsonDecode(
      File('sources/amrayn.com/processed/${book.bookKey}.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final amraynHadiths = (amraynData['hadiths'] as List).cast<Map<String, dynamic>>();

    List<Map<String, String>>? parseGrades(dynamic gradesRaw) {
      if (gradesRaw is! List || gradesRaw.isEmpty) return null;
      final list = <Map<String, String>>[];
      final seen = <String>{};
      for (final g in gradesRaw) {
        if (g is! Map) continue;
        final text = (g['text'] as String?)?.trim();
        if (text == null || text.isEmpty) continue;
        final m = bracketRe.firstMatch(text);
        final name = m != null ? m.group(2)!.trim() : 'Sunnah.com';
        final grade = m != null ? m.group(1)!.trim() : text;
        final key = '${name.toLowerCase()}|${grade.toLowerCase()}';
        if (seen.contains(key)) continue;
        seen.add(key);
        list.add({'name': name, 'grade': grade});
      }
      return list.isEmpty ? null : list;
    }

    var backfilled = 0;
    final claimed = <int>{};

    for (final h in amraynHadiths) {
      final arabic = (h['arabic'] as String?)?.trim() ?? '';
      if (arabic.isEmpty) continue;
      final amraynIdInBook = (h['idInBook'] as num).toInt();
      if (claimed.contains(amraynIdInBook)) continue;

      final row = byIdInBook[amraynIdInBook];
      if (row == null) continue;
      final rowArabic = ((row['arabic'] as String?) ?? '').trim();
      if (rowArabic.isNotEmpty) continue; // not actually blank, leave alone

      claimed.add(amraynIdInBook);
      row['arabic'] = arabic;
      final english = ((h['body'] as String?)?.trim().isNotEmpty ?? false)
          ? (h['body'] as String).trim()
          : ((h['englishRaw'] as String?)?.trim() ?? '');
      final englishMap = (row['english'] as Map?)?.cast<String, dynamic>() ?? {};
      if ((englishMap['text'] as String?)?.trim().isEmpty ?? true) {
        englishMap['text'] = english;
      }
      row['english'] = englishMap;
      final grades = parseGrades(h['grades']);
      if (grades != null && row['grade'] == null) row['grade'] = grades;
      row['source'] = 'amrayn';
      final isOpinion = book.bookKey == 'malik' &&
          !arabic.contains('رَسُولُ اللَّهِ') &&
          !arabic.contains('ﷺ') &&
          !arabic.contains('النَّبِيّ');
      if (isOpinion) row['contentType'] = 'opinion';
      backfilled++;
    }

    spineData['hadiths'] = spineHadiths;
    spineFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(spineData));
    final stillBlank = spineHadiths
        .where((h) => ((h['arabic'] as String?) ?? '').trim().isEmpty)
        .length;
    stdout.writeln(
      '${book.bookKey}: $backfilled additional blank slots backfilled directly by idInBook, '
      '$stillBlank still blank',
    );
  }
}

class _BookConfig {
  const _BookConfig(this.bookKey, this.spinePath);
  final String bookKey;
  final String spinePath;
}
