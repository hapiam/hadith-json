import 'dart:convert';
import 'dart:io';
import 'arabic_match.dart';

/// STAGE: one-time spine enrichment, repeatable/idempotent.
///
/// amrayn's per-hadith `grades: [{class, text}]` (scraped from sunnah.com's
/// own grading widget) is genuinely new value the unified schema doesn't
/// have for Bukhari/Muslim/Nawawi40/Qudsi40: fawaz's own raw editions carry
/// no per-hadith authenticity grading at all for these four (see
/// `build_unified_editions.dart`'s `_gradesFromSpine` -- it returns `[]`
/// whenever the spine's own `grade` field is absent, which it was for all
/// four before this tool ran, verified by inspecting each spine's own
/// keys). Darimi/Riyad as-Salihin/Shamail were considered too but don't
/// qualify: `build_unified_editions.dart`'s own `BookDef` doc comment notes
/// these three have no cached fawaz edition to content-match against at
/// all (`fawazBook == null`), so this tool's join has nothing to anchor on
/// for them -- would need a different join key entirely, not attempted
/// here.
///
/// Rather than teach `build_unified_editions.dart` a new join (a second,
/// parallel mechanism to the existing fawaz-language join), this writes
/// directly onto the SPINE's own `grade` field in the exact shape
/// `_gradesFromSpine` already knows how to absorb (a List of `{name,
/// grade}` maps) -- so the very next `build_unified_editions.dart` run
/// picks it up for free, and the enrichment survives every future rebuild
/// without any pipeline-code change.
///
/// Matching: content-matches every amrayn citation onto its fawaz row
/// (`arabic_match.dart`, verified accurate this session after the anchor-
/// collision fix), then uses that row's `hadithnumber` as the target
/// `idInBook` -- verified earlier this session that canonical `idInBook`
/// equals fawaz's own `hadithnumber`, not raw array position, for exactly
/// these fawaz-rebuilt books.
///
/// Text parsing: amrayn's `grades[].text` is either a bare grade
/// ("Sahih (Authentic)") or grade + bracketed attribution
/// ("Sahih (Authentic) [Al-Albani]"). Splits the bracket into `grade`/
/// `name`; unattributed text is attributed to "Sunnah.com" (matching the
/// existing convention `_mergeGrades` already uses for unattributed plain-
/// string sources) since that's the actual origin of amrayn's own grading
/// widget.
///
/// Per-book config: [bookKey] names the spine file + amrayn processed file
/// (they always match); [fawazKey] is the fawaz edition file's own name,
/// which sometimes differs (nawawi40/qudsi40's fawaz files are named
/// `ara-nawawi.min.json`/`ara-qudsi.min.json`, no "40" suffix -- verified
/// by listing `db/editions/files/`).
class _BookConfig {
  const _BookConfig(this.bookKey, this.spinePath, {String? fawazKey})
    : fawazKey = fawazKey ?? bookKey;

  final String bookKey;
  final String spinePath;
  final String fawazKey;
}

/// Usage: dart run tool/apply_amrayn_grades.dart
void main() {
  const books = [
    _BookConfig('bukhari', 'db/by_book/the_9_books/bukhari.json'),
    _BookConfig('muslim', 'db/by_book/the_9_books/muslim.json'),
    _BookConfig(
      'nawawi40',
      'db/by_book/forties/nawawi40.json',
      fawazKey: 'nawawi',
    ),
    _BookConfig(
      'qudsi40',
      'db/by_book/forties/qudsi40.json',
      fawazKey: 'qudsi',
    ),
  ];
  final bracketRe = RegExp(r'^(.*?)\s*\[([^\]]+)\]$');

  for (final book in books) {
    final fawazData = jsonDecode(File('db/editions/files/ara-${book.fawazKey}.min.json').readAsStringSync()) as Map<String, dynamic>;
    final fawazHadiths = (fawazData['hadiths'] as List).cast<Map<String, dynamic>>();
    final fawazArabic = fawazHadiths.map((h) => (h['text'] as String?) ?? '').toList();
    final fawazNumbers = fawazHadiths.map((h) => (h['hadithnumber'] as num).toInt()).toList();

    final amraynData = jsonDecode(File('sources/amrayn.com/processed/${book.bookKey}.json').readAsStringSync()) as Map<String, dynamic>;
    final amraynHadiths = (amraynData['hadiths'] as List).cast<Map<String, dynamic>>();
    final amraynArabic = amraynHadiths.map((h) => (h['arabic'] as String?) ?? '').toList();
    final amraynKeys = amraynHadiths.map((h) => (h['citation'] as String?) ?? '${h['idInBook']}').toList();

    final result = matchToCanonical(
      oldArabic: amraynArabic,
      canonicalArabic: fawazArabic,
      oldLabels: amraynKeys,
    );

    // idInBook -> list of {name, grade}, deduped by (name, grade) pair --
    // multiple amrayn citations can land on the same fawaz row (lettered
    // splits), each potentially carrying its own grades[] list.
    final gradesByIdInBook = <int, List<Map<String, String>>>{};
    var matchedWithGrades = 0;

    for (var i = 0; i < amraynHadiths.length; i++) {
      final grades = amraynHadiths[i]['grades'] as List?;
      if (grades == null || grades.isEmpty) continue;
      final fawazIdx = result[i];
      if (fawazIdx == null) continue;
      final idInBook = fawazNumbers[fawazIdx];

      final list = gradesByIdInBook.putIfAbsent(idInBook, () => []);
      final seen = list.map((g) => '${g['name']}|${g['grade']}'.toLowerCase()).toSet();
      for (final g in grades) {
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
      matchedWithGrades++;
    }

    final spineFile = File(book.spinePath);
    final spineData = jsonDecode(spineFile.readAsStringSync()) as Map<String, dynamic>;
    final spineHadiths = (spineData['hadiths'] as List).cast<Map<String, dynamic>>();

    var written = 0;
    for (final h in spineHadiths) {
      final idInBook = (h['idInBook'] as num).toInt();
      final grades = gradesByIdInBook[idInBook];
      if (grades == null) continue;
      h['grade'] = grades;
      written++;
    }

    spineFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(spineData));
    stdout.writeln(
      '${book.bookKey}: ${amraynHadiths.length} amrayn citations, $matchedWithGrades matched with grades, '
      '${gradesByIdInBook.length} distinct idInBook targets, $written spine rows written -> ${spineFile.path}',
    );
  }
}
