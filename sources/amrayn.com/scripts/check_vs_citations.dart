import 'dart:convert';
import 'dart:io';

// Definitive completion check for a citation-discovery book: every citation
// in the discovered list must have a successful (error-free) row in the
// jsonl, keyed by citation string (old pre-discovery rows fall back to
// their integer idInBook).
void main(List<String> args) {
  final book = args[0];
  final dir = 'C:/-/src/hapi/hadith-json-merge/db/scrape_cache/amrayn';
  final citations = (jsonDecode(
    File('$dir/$book.citations.json').readAsStringSync(),
  ) as List).cast<String>();
  final done = <String>{};
  final text = const Utf8Decoder(
    allowMalformed: true,
  ).convert(File('$dir/$book.jsonl').readAsBytesSync());
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    try {
      final obj = jsonDecode(line) as Map<String, dynamic>;
      if (obj.containsKey('error')) continue;
      final citation =
          obj['citation'] as String? ?? (obj['idInBook'] as int?)?.toString();
      if (citation != null) done.add(citation);
    } catch (_) {}
  }
  final missing = citations.where((c) => !done.contains(c)).toList();
  print(
    '$book: discovered=${citations.length} done-of-discovered='
    '${citations.length - missing.length} missing=${missing.length} '
    '${missing.take(20).toList()}',
  );
}
