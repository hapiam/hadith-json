import 'dart:convert';
import 'dart:io';

void main() {
  final file = File(
    'C:/-/src/hapi/hadith-json-merge/db/scrape_cache/amrayn/malik.jsonl',
  );
  var done = 0, err = 0, oldScheme = 0;
  final errSamples = <String>[];
  final text = const Utf8Decoder(
    allowMalformed: true,
  ).convert(file.readAsBytesSync());
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    try {
      final obj = jsonDecode(line) as Map<String, dynamic>;
      if (obj['malikChapterNum'] == null) {
        oldScheme++;
        continue;
      }
      if (obj.containsKey('error')) {
        err++;
        if (errSamples.length < 10) {
          errSamples.add(
            'ch${obj['malikChapterNum']}/${obj['malikLocalHadithNum']}: ${obj['error']}',
          );
        }
      } else {
        done++;
      }
    } catch (_) {}
  }
  print('malik: done=$done err=$err oldSchemeRows(ignored)=$oldScheme');
  print('sample errors: $errSamples');
}
