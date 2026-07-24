import 'dart:convert';
import 'dart:io';

void main() {
  final citFile = File(
    'C:/-/src/hapi/hadith-json-merge/db/scrape_cache/amrayn/muslim.citations.json',
  );
  final citations = (jsonDecode(citFile.readAsStringSync()) as List)
      .cast<String>();
  final file = File(
    'C:/-/src/hapi/hadith-json-merge/db/scrape_cache/amrayn/muslim.jsonl',
  );
  final done = <String>{};
  final errored = <String>{};
  final text = const Utf8Decoder(
    allowMalformed: true,
  ).convert(file.readAsBytesSync());
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    try {
      final obj = jsonDecode(line) as Map<String, dynamic>;
      final citation =
          obj['citation'] as String? ?? (obj['idInBook'] as int?)?.toString();
      if (citation == null) continue;
      if (obj.containsKey('error')) {
        errored.add(citation);
      } else {
        done.add(citation);
      }
    } catch (_) {}
  }
  final stillMissing = citations.where((c) => !done.contains(c)).toList();
  print(
    'muslim: total real citations=${citations.length}, done=${done.length}, '
    'stillMissing=${stillMissing.length}',
  );
  print('sample still missing: ${stillMissing.take(15).toList()}');
}
