import 'dart:convert';
import 'dart:io';

// Mirrors scrape_amrayn.dart's own "done" logic: a line without an "error"
// key counts as done, regardless of how many stale error lines exist for
// that same idInBook from earlier failed attempts.
void main() {
  final books = {
    'riyad_assalihin': 1896,
    'aladab_almufrad': 1322,
    'shamail_muhammadiyah': 398,
    'bukhari': 7076,
    'muslim': 7190,
  };
  for (final entry in books.entries) {
    final file = File(
      'C:/-/src/hapi/hadith-json-merge/db/scrape_cache/amrayn/${entry.key}.jsonl',
    );
    if (!file.existsSync()) {
      print('${entry.key}: MISSING FILE');
      continue;
    }
    final done = <int>{};
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        if (!obj.containsKey('error')) done.add(obj['idInBook'] as int);
      } catch (_) {}
    }
    final missing = <int>[];
    for (var n = 1; n <= entry.value; n++) {
      if (!done.contains(n)) missing.add(n);
    }
    print('${entry.key}: ${done.length}/${entry.value} done, ${missing.length} still missing');
    if (missing.isNotEmpty && missing.length <= 30) {
      print('  missing ids: $missing');
    } else if (missing.isNotEmpty) {
      print('  missing ids (first 30): ${missing.take(30).toList()}');
    }
  }
}
