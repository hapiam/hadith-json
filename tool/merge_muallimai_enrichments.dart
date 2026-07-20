import 'dart:convert';
import 'dart:io';

/// STAGE: one-time/rare migration, not part of the regular build loop --
/// re-run only if the muallimai fork itself ever republishes updated
/// grade/reference data and you need to re-sync. Per README's provenance
/// table, muallimai's `grade` + `reference` are already merged into the
/// AhmedBaset spine as a one-time historical step; this script is what did
/// that merge, kept here so the merge is reproducible, not something the
/// normal `rebuild_from_fawaz.dart` -> `build_unified_editions.dart` ->
/// `gen_data_quality_report.dart` cycle depends on.
///
/// INPUT: reads every `db/by_book/**/*.json` under a sibling checkout of
/// github.com/muallimai/hadith-json (path is the 2nd CLI arg, defaulting to
/// a hardcoded local path -- see below), building an `id -> {grade,
/// reference}` map; then reads every `.json` file under this repo's own
/// `db/` (1st CLI arg, default `.`) that has a top-level `hadiths` list.
///
/// OUTPUT: rewrites any of this repo's own `db/**/*.json` files in place
/// whose hadith rows had a matching muallimai `id` with a different
/// grade/reference than what's already there -- **only** `grade` and
/// `reference` are ever changed; every other field (arabic, english,
/// idInBook, chapterId, ...) is preserved untouched from whatever was
/// already on disk. Matching is by hadith `id` only (muallimai's own id
/// numbering, assumed to agree with the base spine's `id` -- both trace back
/// to the same original AhmedBaset numbering).
///
/// TODO: the default `forkRoot` path (`C:\-\src\hapi\hadith-json-muallimai`)
/// is a hardcoded absolute local path specific to whoever ran this
/// historically -- it will silently fail (directory-not-found) on any other
/// machine unless the 2nd CLI arg is passed explicitly. Consider requiring
/// the arg instead of defaulting it.
///
/// TODO: the output-file scan walks *all* of `db/`, excluding only
/// `by_locale` -- it does not skip `db/unified/` or `db/editions/`. Both of
/// those directories are the *generated* output of `build_unified_editions.
/// dart` (unified) or a raw upstream cache (editions), not source spine
/// data. Since `db/unified/by_book/*.json` and `db/unified/files/*.json`
/// both happen to also carry a top-level `hadiths` list with `id` fields,
/// running this script today would also rewrite those generated files
/// in-place with muallimai grade/reference data -- harmless in the sense
/// that the next `build_unified_editions.dart` run wipes and regenerates
/// `db/unified/` from the spine anyway, but surprising and wasteful, and
/// inconsistent with this script's own doc comment implying it only touches
/// "the base". Should exclude `db/unified` and `db/editions` explicitly,
/// the same way `by_locale` is already excluded below.
void main(List<String> args) {
  final baseRoot = Directory(args.isNotEmpty ? args[0] : '.');
  final forkRoot = Directory(
    args.length > 1 ? args[1] : r'C:\-\src\hapi\hadith-json-muallimai',
  );

  // Load the enrichment source: every muallimai hadith that carries a
  // `grade` and/or `reference` key, keyed by its `id`. Deliberately only
  // captures those two keys -- muallimai's own arabic/english/idInBook are
  // never read here, so there's no risk of this script accidentally
  // clobbering base content with fork content for any other field.
  final enrichments = <int, Map<String, dynamic>>{};
  final forkByBook = Directory(
    '${forkRoot.path}${Platform.pathSeparator}db${Platform.pathSeparator}by_book',
  );
  for (final file
      in forkByBook
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))) {
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final hadiths = data['hadiths'] as List<dynamic>? ?? const [];
    for (final h in hadiths) {
      final map = Map<String, dynamic>.from(h as Map);
      final id = map['id'];
      if (id is! int) continue;
      final entry = <String, dynamic>{};
      if (map.containsKey('grade')) entry['grade'] = map['grade'];
      if (map.containsKey('reference')) entry['reference'] = map['reference'];
      if (entry.isNotEmpty) enrichments[id] = entry;
    }
  }
  stdout.writeln(
    'Loaded enrichments for ${enrichments.length} hadith ids from ${forkRoot.path}',
  );

  var filesTouched = 0;
  var hadithsEnriched = 0;
  var unmatched = 0;

  final dbRoot = Directory('${baseRoot.path}${Platform.pathSeparator}db');
  for (final file
      in dbRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))) {
    if (file.path.contains(
      '${Platform.pathSeparator}by_locale${Platform.pathSeparator}',
    )) {
      continue;
    }

    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final hadiths = data['hadiths'] as List<dynamic>?;
    if (hadiths == null) continue;

    var changed = false;
    for (var i = 0; i < hadiths.length; i++) {
      final h = Map<String, dynamic>.from(hadiths[i] as Map);
      final id = h['id'];
      if (id is! int) continue;
      final e = enrichments[id];
      if (e == null) {
        unmatched++;
        continue;
      }
      // Only actually write grade/reference if the value genuinely differs
      // (string equality for grade, deep JSON equality for the reference
      // object via re-encoding) -- avoids marking every file "changed" and
      // rewriting untouched JSON on a re-run where nothing new merged.
      var localChange = false;
      if (e.containsKey('grade') &&
          (!h.containsKey('grade') || h['grade'] != e['grade'])) {
        h['grade'] = e['grade'];
        localChange = true;
      }
      if (e.containsKey('reference')) {
        final ref = e['reference'];
        if (!h.containsKey('reference') ||
            jsonEncode(h['reference']) != jsonEncode(ref)) {
          h['reference'] = ref;
          localChange = true;
        }
      }
      if (localChange) {
        // Re-key the map in a fixed field order purely for readable git
        // diffs (id/idInBook/chapterId/bookId/arabic/english first, then
        // whatever else was already present, grade/reference always last)
        // -- Dart map insertion order is preserved on JSON encode, so this
        // is the only way to control output key order.
        final ordered = <String, dynamic>{};
        for (final key in [
          'id',
          'idInBook',
          'chapterId',
          'bookId',
          'arabic',
          'english',
        ]) {
          if (h.containsKey(key)) ordered[key] = h[key];
        }
        for (final key in h.keys) {
          if (!ordered.containsKey(key) &&
              key != 'grade' &&
              key != 'reference') {
            ordered[key] = h[key];
          }
        }
        if (h.containsKey('grade')) ordered['grade'] = h['grade'];
        if (h.containsKey('reference')) ordered['reference'] = h['reference'];
        hadiths[i] = ordered;
        changed = true;
        hadithsEnriched++;
      }
    }

    if (changed) {
      const encoder = JsonEncoder.withIndent('\t');
      file.writeAsStringSync('${encoder.convert(data)}\n');
      filesTouched++;
    }
  }

  stdout.writeln(
    'Updated $filesTouched files; enriched $hadithsEnriched hadith slots; base hadiths without fork match in scan: $unmatched',
  );
}
