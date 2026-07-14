import 'dart:convert';
import 'dart:io';

/// Merge grade + reference from muallimai into AhmedBaset base by hadith id.
/// Does not overwrite arabic / english / idInBook from the base.
void main(List<String> args) {
  final baseRoot = Directory(args.isNotEmpty ? args[0] : '.');
  final forkRoot = Directory(
    args.length > 1 ? args[1] : r'C:\-\src\hapi\hadith-json-muallimai',
  );

  final enrichments = <int, Map<String, dynamic>>{};
  final forkByBook = Directory(
    '${forkRoot.path}${Platform.pathSeparator}db${Platform.pathSeparator}by_book',
  );
  for (final file in forkByBook
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
  for (final file in dbRoot
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))) {
    if (file.path.contains('${Platform.pathSeparator}by_locale${Platform.pathSeparator}')) {
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