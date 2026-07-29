import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine cleanup (partial -- see below), idempotent.
///
/// See DUPLICATE_HADITH_INVESTIGATION.md, Category 1, for the full
/// investigation. `db/by_book/hadithunlocked/tabarani.json` has 210
/// duplicate-Arabic groups (339 excess rows), matching
/// `import_hadithunlocked.dart`'s own doc comment noting hadithunlocked's
/// raw `item.number` field has "340 duplicate numbers" for this book.
///
/// Only 23 of those 210 groups are ALSO byte-identical in their English
/// translation -- true duplicates with zero information loss either way.
/// Those are auto-resolved here (keep lowest idInBook, drop the rest).
///
/// The other 187 groups have matching Arabic but DIFFERENT English
/// translations between copies -- confirmed by direct investigation
/// (per user request, after an initial wrong assumption that the
/// difference would be "immaterial since both are machine-translated
/// anyway") to be genuine translation-quality variance with **no
/// consistent direction**: sometimes the lower idInBook copy reads better,
/// sometimes the higher one does. There is no safe automated rule here --
/// picking either "keep first" or "keep last" would silently discard the
/// better translation on close to half of these pairs. Rather than guess,
/// this script leaves those 187 groups completely untouched and writes
/// `TABARANI_DUPLICATE_TRANSLATIONS_REVIEW.md` listing every pair's full
/// English text side by side, for a human (or a future, more careful
/// heuristic) to resolve individually.
///
/// Usage: dart run tool/fix_tabarani_duplicates.dart
void main() {
  const path = 'db/by_book/hadithunlocked/tabarani.json';
  final file = File(path);
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths = (data['hadiths'] as List)
      .map((h) => Map<String, dynamic>.from(h as Map))
      .toList();

  String norm(String s) => s
      .replaceAll(RegExp('[ً-ٰٟ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final byKey = <String, List<Map<String, dynamic>>>{};
  for (final h in hadiths) {
    final arabic = h['arabic'] as String? ?? '';
    if (arabic.length < 15) continue;
    byKey.putIfAbsent(norm(arabic), () => []).add(h);
  }
  final groups = byKey.values.where((g) => g.length > 1).toList();

  final toDrop = <int>{};
  final reviewGroups = <List<Map<String, dynamic>>>[];
  for (final group in groups) {
    final texts = group.map((h) => (h['english'] as Map)['text']).toSet();
    if (texts.length == 1) {
      final sorted = group.toList()
        ..sort((a, b) => (a['idInBook'] as int).compareTo(b['idInBook'] as int));
      for (final h in sorted.skip(1)) {
        toDrop.add(h['idInBook'] as int);
      }
    } else {
      reviewGroups.add(group..sort((a, b) => (a['idInBook'] as int).compareTo(b['idInBook'] as int)));
    }
  }

  final kept = hadiths.where((h) => !toDrop.contains(h['idInBook'] as int)).toList();
  data['hadiths'] = kept;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));

  final review = StringBuffer()
    ..writeln('# Tabarani duplicate-Arabic groups with differing English translations')
    ..writeln()
    ..writeln('${reviewGroups.length} groups where hadithunlocked.com\'s raw data has the ')
    ..writeln('same Arabic matn under two different citations, but the English translation ')
    ..writeln('differs between copies -- genuine quality variance (sometimes one side reads ')
    ..writeln('better, sometimes the other; no consistent pattern found), so no automated ')
    ..writeln('rule picked a winner. Left in the data as-is (both rows kept) pending manual ')
    ..writeln('review. See DUPLICATE_HADITH_INVESTIGATION.md, Category 1.')
    ..writeln();
  for (final g in reviewGroups) {
    final ids = g.map((h) => h['idInBook']).join(', ');
    review.writeln('## idInBook $ids');
    for (final h in g) {
      review
        ..writeln('- **${h['idInBook']}** (${h['reference']['text']}): ${(h['english'] as Map)['text']}')
        ..writeln();
    }
  }
  File('TABARANI_DUPLICATE_TRANSLATIONS_REVIEW.md').writeAsStringSync(review.toString());

  stdout.writeln(
    '$path: ${hadiths.length} -> ${kept.length} rows '
    '(${toDrop.length} exact duplicates dropped; ${reviewGroups.length} groups left '
    'untouched, written to TABARANI_DUPLICATE_TRANSLATIONS_REVIEW.md for manual review)',
  );
}
