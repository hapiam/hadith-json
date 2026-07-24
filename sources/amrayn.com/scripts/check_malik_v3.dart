import 'dart:convert';
import 'dart:io';

void main() {
  final file = File(
    'C:/-/src/hapi/hadith-json-merge/db/scrape_cache/amrayn/malik.jsonl',
  );
  final done = <String>{};
  final errorKeys = <String>{};
  final errorMsgs = <String, String>{};
  var oldScheme = 0;
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
      final key = '${obj['malikChapterNum']}/${obj['malikLocalHadithNum']}';
      if (obj.containsKey('error')) {
        errorKeys.add(key);
        errorMsgs[key] = obj['error'].toString();
      } else {
        done.add(key);
      }
    } catch (_) {}
  }
  final stillFailing = errorKeys.difference(done);
  print(
    'malik: done=${done.length} stillFailing=${stillFailing.length} '
    'oldSchemeRows(ignored)=$oldScheme',
  );
  for (final k in stillFailing.toList()..sort()) {
    print('  $k: ${errorMsgs[k]}');
  }
}
