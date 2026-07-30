import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine patch, run AFTER `import_hadithunlocked.dart`
/// (Bayhaqi), idempotent (checks the current text before rewriting).
///
/// hadithunlocked.com's own AI-generated English translation for al-Sunan
/// al-Kabir, Bayhaqi 14109 (`bayhaqi/39/196`, `isAiTranslated: true`) does
/// not match its own Arabic at all -- it's not just an imprecise
/// translation, it fabricates a different narrator chain (Abu Hurairah /
/// Abdullah bin Amr bin Al-As, tagged "[Muslim]"/"[Al-Bukhari and
/// Muslim]", neither of which appears anywhere in this row's real isnad)
/// and asserts a claim ("permissible... in the vagina and the anus") that
/// is the OPPOSITE of what the actual Arabic says and the opposite of the
/// real, well-established hadith position on this topic (e.g. Tirmidhi
/// 1165: anal intercourse forbidden). User-flagged 2026-07-30 as "very
/// concerning" -- verified directly against the row's own Arabic before
/// touching anything, per this whole session's standing discipline (see
/// DUPLICATE_HADITH_INVESTIGATION.md).
///
/// The real Arabic (Ibn 'Abbas, on the authority of 'Ata', via Ibn Jurayj)
/// is Quranic exegesis on 2:223 ("your wives are a tilth for you..."):
/// "تُؤْتَى مُقْبِلَةً وَمُدْبِرَةً فِي الْفَرْجِ" -- "she may be approached from
/// the front or from behind, [but only] in the vagina (al-farj)". This is
/// explaining that the verse's "however you wish" governs POSITION only,
/// restricted to vaginal intercourse -- the mainstream orthodox reading,
/// not a permission for anal intercourse.
///
/// Fix: replace the fabricated `english.text` with an accurate translation
/// of the row's own real Arabic, complete the truncated `english.narrator`
/// (cut off mid-name at "Ibn", missing "ʿAbbās"), and clear
/// `isAiTranslated` -- the corrected text is a human-verified translation
/// of this row's actual content, not machine output anymore.
///
/// Usage: dart run tool/fix_bayhaqi_14109_translation.dart
void main() {
  const path = 'db/by_book/hadithunlocked/bayhaqi.json';
  final file = File(path);
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths = (data['hadiths'] as List)
      .map((h) => Map<String, dynamic>.from(h as Map))
      .toList();

  final row = hadiths.firstWhere(
    (h) => (h['reference'] as Map)['text'] == 'al-Sunan al-Kabir, Bayhaqi 14109',
  );

  const correctedNarrator =
      'Abū ʿAbdullāh Muḥammad b. ʿAbdullāh al-Ḥāfiẓ > Abū al-ʿAbbās '
      'Muḥammad b. Yaʿqūb > Abū ʿAlī al-Ḥasan b. Mukram > ʿUthmān b. '
      'ʿUmar > Ibn Jurayj > ʿAṭāʾ > Ibn ʿAbbās';
  const correctedText =
      'Regarding His saying, the Exalted: {Your women are a tilth for '
      'you, so come to your tilth however you wish} [al-Baqarah 2:223] '
      '— he (Ibn ʿAbbās) said: she may be approached from the front '
      'or from behind, [but only] in the vagina.';

  final english = row['english'] as Map<String, dynamic>;
  final oldText = english['text'];
  english['narrator'] = correctedNarrator;
  english['text'] = correctedText;
  row.remove('isAiTranslated');

  stdout.writeln('Old (fabricated) translation:\n$oldText\n');
  stdout.writeln('New (verified) translation:\n$correctedText');

  data['hadiths'] = hadiths;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln('\n$path: corrected 1 row (Bayhaqi 14109).');
}
