import 'dart:io';

String? extractStringField(String s, String key) {
  final re = RegExp('\\\\*"$key\\\\*"\\s*:\\s*(null|\\\\*"(.*?)(?<!\\\\)\\\\*")');
  final m = re.firstMatch(s);
  if (m == null) return null;
  if (m.group(1) == 'null') return null;
  return m.group(2);
}

String? extractRawField(String s, String key) {
  // matches string, null, number, or bool -- returns the raw token text
  final re = RegExp('\\\\*"$key\\\\*"\\s*:\\s*(null|true|false|-?\\d+(?:\\.\\d+)?|\\\\*"(?:[^"\\\\]|\\\\.)*?\\\\*")');
  final m = re.firstMatch(s);
  return m?.group(1);
}

List<String> extractStringArrayField(String s, String key) {
  final re = RegExp('\\\\*"$key\\\\*"\\s*:\\s*\\[(.*?)\\]');
  final m = re.firstMatch(s);
  if (m == null) return [];
  final itemRe = RegExp('\\\\*"(.*?)(?<!\\\\)\\\\*"');
  return itemRe.allMatches(m.group(1)!).map((im) => im.group(1)!).toList();
}

void main() {
  final full = File('tmp_amrayn/riyad1.html').readAsStringSync().replaceAll('\n', '').replaceAll('\r', '');

  // Scope to the hadith object by anchoring on its own hadithNumber value.
  final anchorRe = RegExp('\\\\*"hadithNumber\\\\*"\\s*:\\s*\\\\*"1\\\\*"');
  final am = anchorRe.firstMatch(full);
  print('anchor found: ${am != null} at ${am?.start}');
  if (am == null) return;
  final scoped = full.substring(am.start, (am.start + 3000).clamp(0, full.length));

  print('bookNumber: ${extractRawField(scoped, 'bookNumber')}');
  print('chapterNumber: ${extractRawField(scoped, 'chapterNumber')}');
  print('gradeFlag: ${extractRawField(scoped, 'gradeFlag')}');
  print('notes: ${extractRawField(scoped, 'notes')}');
  print('postscript: ${extractRawField(scoped, 'postscript')}');
  print('hasExplanationAvailable: ${extractRawField(scoped, 'hasExplanationAvailable')}');
  print('chain present: ${extractRawField(scoped, 'chain') != null}');
  print('chainArabic present: ${extractRawField(scoped, 'chainArabic') != null}');
  print('references: ${extractStringArrayField(scoped, 'references')}');
  print('intlRef: ${extractRawField(scoped, 'intlRef')}');
  print('tags: ${extractStringArrayField(scoped, 'tags')}');

  final linksRe = RegExp('\\\\*"links\\\\*"\\s*:\\s*\\[(.*?)\\]');
  final lm = linksRe.firstMatch(scoped);
  print('links match found: ${lm != null}');
  if (lm != null) {
    final linkItemRe = RegExp(
      '\\\\*"link\\\\*"\\s*:\\s*\\\\*"(.*?)\\\\*"\\s*,\\s*\\\\*"label\\\\*"\\s*:\\s*\\\\*"(.*?)\\\\*"',
    );
    for (final im in linkItemRe.allMatches(lm.group(1)!)) {
      print('  link=${im.group(1)}  label=${im.group(2)}');
    }
  }
}
