import 'dart:convert';
import 'dart:io';

void main() {
  final file = File(
    'C:/-/src/hapi/hadith-json-merge/db/scrape_cache/amrayn/bukhari.jsonl',
  );
  final done = <int>{};
  final text = const Utf8Decoder(
    allowMalformed: true,
  ).convert(file.readAsBytesSync());
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    try {
      final obj = jsonDecode(line) as Map<String, dynamic>;
      if (obj.containsKey('error')) continue;
      final id = obj['idInBook'] as int?;
      if (id != null) done.add(id);
    } catch (_) {}
  }
  const total = 7076;
  final missing = <int>[];
  for (var n = 1; n <= total; n++) {
    if (!done.contains(n)) missing.add(n);
  }
  print('bukhari done=${done.length}/$total missing=${missing.length}');
  // print contiguous ranges
  var start = -1, prev = -1;
  for (final m in missing) {
    if (start == -1) {
      start = m;
    } else if (m != prev + 1) {
      print('  $start-$prev');
      start = m;
    }
    prev = m;
  }
  if (start != -1) print('  $start-$prev');
}
