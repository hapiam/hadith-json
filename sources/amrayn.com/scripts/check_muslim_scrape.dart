import 'dart:convert';
import 'dart:io';

// Definitive Sahih Muslim scrape audit: done rows (no "error" key) vs the
// scraper's own expected 7190, holes, unresolved errors, duplicates, and a
// content sanity check (non-empty arabic + english on sampled rows).
void main() {
  final file = File(
    'C:/-/src/hapi/hadith-json-merge/db/scrape_cache/amrayn/muslim.jsonl',
  );
  const expected = 7190;
  final done = <int, Map<String, dynamic>>{};
  final errored = <int>{};
  var duplicateDoneRows = 0;
  final text = const Utf8Decoder(
    allowMalformed: true,
  ).convert(file.readAsBytesSync());
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    try {
      final obj = jsonDecode(line) as Map<String, dynamic>;
      final id = obj['idInBook'] as int?;
      if (id == null) continue;
      if (obj.containsKey('error')) {
        errored.add(id);
      } else {
        if (done.containsKey(id)) duplicateDoneRows++;
        done[id] = obj;
      }
    } catch (_) {}
  }
  final missing = <int>[];
  for (var n = 1; n <= expected; n++) {
    if (!done.containsKey(n)) missing.add(n);
  }
  final unresolvedErrors = errored.where((e) => !done.containsKey(e)).toList();
  var emptyArabic = 0;
  var emptyEnglish = 0;
  for (final obj in done.values) {
    if ((obj['arabic'] as String? ?? '').trim().isEmpty) emptyArabic++;
    final body = obj['body'] as String? ?? obj['englishRaw'] as String? ?? '';
    if (body.trim().isEmpty) emptyEnglish++;
  }
  print('Sahih Muslim: ${done.length}/$expected done');
  print('missing ids: ${missing.length} $missing');
  print('unresolved error ids: ${unresolvedErrors.length} $unresolvedErrors');
  print('duplicate done rows (multi-process overlap): $duplicateDoneRows');
  print('rows with empty arabic: $emptyArabic, empty english: $emptyEnglish');
}
