import 'dart:convert';
import 'dart:io';

const dir = r'C:\-\src\hapi\hadith-json-merge\db\scrape_cache\amrayn';

void main() {
  for (final book in ['muslim', 'shamail_muhammadiyah', 'mustadrak_alhakim_bonus']) {
    final cits = jsonDecode(File('$dir\\$book.citations.json').readAsStringSync());
    final citSet = <String>{};
    if (cits is List) {
      citSet.addAll(cits.map((e) => e.toString()));
    } else if (cits is Map) {
      citSet.addAll(cits.keys.map((e) => e.toString()));
    }
    final ok = <String>{};
    final text = const Utf8Decoder(allowMalformed: true)
        .convert(File('$dir\\$book.jsonl').readAsBytesSync());
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      Map<String, dynamic> r;
      try {
        r = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      if (r['error'] != null) continue;
      final c = r['citation'];
      if (c != null) ok.add(c.toString());
      final id = r['idInBook'];
      if (id != null) ok.add(id.toString());
    }
    final missing = citSet.difference(ok);
    print('$book: ${citSet.length} discovered citations, '
        '${citSet.length - missing.length} fetched ok, ${missing.length} missing');
    if (missing.isNotEmpty && missing.length <= 30) {
      print('  missing: ${(missing.toList()..sort()).join(', ')}');
    }
  }
}
