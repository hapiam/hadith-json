import 'dart:convert';
import 'dart:io';

// Same "done" logic as check_scrape_gaps.dart, applied to the two bonus
// books just finished: a line without an "error" key counts as done.
// Expected totals = max idInBook seen (amrayn numbers sequentially), so we
// report both the max and any holes below it, plus error-only ids.
void main() {
  for (final book in ['mustadrak_alhakim_bonus', 'nasai_kubra_bonus']) {
    final file = File(
      'C:/-/src/hapi/hadith-json-merge/db/scrape_cache/amrayn/$book.jsonl',
    );
    if (!file.existsSync()) {
      print('$book: MISSING FILE');
      continue;
    }
    final done = <int>{};
    final errored = <int>{};
    // allowMalformed: the nasai_kubra file has at least one line with raw
    // bytes utf-8 strict mode rejects — decode leniently for counting.
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
          done.add(id);
        }
      } catch (_) {}
    }
    final maxId = done.isEmpty ? 0 : done.reduce((a, b) => a > b ? a : b);
    final missing = <int>[];
    for (var n = 1; n <= maxId; n++) {
      if (!done.contains(n)) missing.add(n);
    }
    final unresolvedErrors = errored.where((e) => !done.contains(e)).toList();
    print('$book: ${done.length} done, max id $maxId, '
        '${missing.length} holes, ${unresolvedErrors.length} unresolved errors');
    if (missing.isNotEmpty) {
      print('  holes (first 30): ${missing.take(30).toList()}');
    }
    if (unresolvedErrors.isNotEmpty) {
      print('  unresolved error ids (first 30): '
          '${unresolvedErrors.take(30).toList()}');
    }
  }
}
