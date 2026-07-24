import 'dart:convert';
import 'dart:io';

// Status table for every amrayn scrape: done rows (no "error" key, deduped
// by idInBook) vs the scraper's configured expected count, plus how many of
// the missing are logged 404s (likely citation-scheme gaps, not failures).
void main() {
  const books = {
    'riyad_assalihin': 1896,
    'aladab_almufrad': 1322,
    'shamail_muhammadiyah': 398,
    'bukhari': 7076,
    'muslim': 7190,
    'nasai': 5758,
    'abudawud': 5274,
    'tirmidhi': 3956,
    'ibnmajah': 4340,
    'malik': 1973,
    'nawawi40': 42,
    'qudsi40': 40,
    'darimi': 3546,
    'nasai_kubra_bonus': 11949,
    'mustadrak_alhakim_bonus': 8803,
  };
  for (final e in books.entries) {
    final file = File(
      'C:/-/src/hapi/hadith-json-merge/db/scrape_cache/amrayn/${e.key}.jsonl',
    );
    if (!file.existsSync()) {
      print('${e.key}: NO FILE');
      continue;
    }
    final done = <int>{};
    final err404 = <int>{};
    final errOther = <int>{};
    final text = const Utf8Decoder(
      allowMalformed: true,
    ).convert(file.readAsBytesSync());
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        final id = obj['idInBook'] as int?;
        if (id == null) continue;
        final err = obj['error'] as String?;
        if (err == null) {
          done.add(id);
        } else if (err.contains('404')) {
          err404.add(id);
        } else {
          errOther.add(id);
        }
      } catch (_) {}
    }
    var missing = 0;
    var missing404 = 0;
    var missingOther = 0;
    for (var n = 1; n <= e.value; n++) {
      if (done.contains(n)) continue;
      missing++;
      if (err404.contains(n)) {
        missing404++;
      } else if (errOther.contains(n)) {
        missingOther++;
      }
    }
    final pct = (done.length / e.value * 100).toStringAsFixed(1);
    print(
      '${e.key.padRight(24)} ${done.length.toString().padLeft(5)}/${e.value.toString().padLeft(5)} ($pct%)  '
      'missing:$missing (404:$missing404, transient:$missingOther, unattempted:${missing - missing404 - missingOther})',
    );
  }
}
