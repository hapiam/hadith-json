import 'dart:convert';
import 'dart:io';

const dir = r'C:\-\src\hapi\hadith-json-merge\db\scrape_cache\amrayn';

void main() {
  final books = [
    'bukhari',
    'muslim',
    'nasai',
    'abudawud',
    'tirmidhi',
    'ibnmajah',
    'darimi',
    'malik',
    'riyad_assalihin',
    'aladab_almufrad',
    'nawawi40',
    'qudsi40',
    'shamail_muhammadiyah',
    'nasai_kubra_bonus',
    'mustadrak_alhakim_bonus',
  ];
  for (final b in books) {
    final f = File('$dir\\$b.jsonl');
    if (!f.existsSync()) {
      print('$b: NO CACHE FILE');
      continue;
    }
    final ok = <String>{};
    final err = <String>{};
    final text = const Utf8Decoder(
      allowMalformed: true,
    ).convert(f.readAsBytesSync());
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      Map<String, dynamic> r;
      try {
        r = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final key = (r['citation'] ?? r['idInBook']).toString();
      if (r['error'] != null) {
        err.add(key);
      } else {
        ok.add(key);
      }
    }
    err.removeAll(ok);
    var citInfo = '';
    final cf = File('$dir\\$b.citations.json');
    if (cf.existsSync()) {
      final cits = jsonDecode(cf.readAsStringSync());
      final n = cits is List
          ? cits.length
          : (cits is Map ? cits.length : -1);
      citInfo = ' | citations discovered: $n';
    }
    print(
      '$b: ok=${ok.length} errOnly=${err.length}$citInfo '
      '(mtime ${f.lastModifiedSync()})',
    );
  }
}
