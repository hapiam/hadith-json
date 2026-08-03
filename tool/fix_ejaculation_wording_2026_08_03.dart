import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine patch, run after all book imports/rebuilds and
/// BEFORE `build_unified_editions.dart`. Idempotent (a row whose `oldText`
/// is gone but whose `newText` is present is counted as already applied).
///
/// User-flagged 2026-08-03: the word "ejaculation" appears across the
/// corpus and reads wrong in several places. Full review of all 43 spine
/// rows containing "ejaculat*" (see TRANSLATION_WORDING_FIXES.md for the
/// row-by-row audit, verified against each row's own Arabic):
///
/// - 22 rows KEPT: ghusl-rules hadith where "ejaculate" accurately renders
///   the Arabic (anzala / yunzil / fadakha al-ma' / dafq) and matches the
///   published sunnah.com translations. Softening those would deviate from
///   the official texts for no accuracy gain.
/// - 21 rows FIXED here, in five classes:
///   1. Archaic English: Muslim 596a/596bc (+ Tabarani 16373 copy) use
///      "ejaculations" in its obsolete sense of "short uttered prayers"
///      for Arabic "mu'aqqibat" (the post-prayer tasbih phrases).
///   2. Wrong fiqh term: Tabarani 5589/17760/17794 render "yumdhi /
///      kharaja minhu al-madhy" (madhi, pre-seminal fluid) as
///      "ejaculates" -- that inverts the ruling, since madhi requires
///      only washing + wudu while ejaculation would require ghusl.
///      Tabarani 17794 also invented a ghusl order absent from the Arabic.
///   3. Fabricated/garbled AI content: Hakim 7900's English was a borrowed
///      "Water is for Water" translation while its own Arabic is a
///      different hadith entirely ("The gift of the believer is death");
///      Bayhaqi 8051 invented an "expiation ... for the ejaculation"
///      clause not present in its Arabic (kaffarat al-zihar); Bayhaqi
///      14918 invented "What if he ejaculates?" for "a-ra'ayta in 'ajaza
///      wa-istahmaqa" (incapable / acted foolishly) and misrouted who
///      asked the Prophet; Nasai-Kubra 2943 said the Prophet's head was
///      "wet from semen" for "yaqturu ma'an nikahan" (dripping with
///      [ghusl] water due to marital relations).
///   4. Wrong word for ihtilam/juhd/ifda'/yutm: Nasai-Kubra 2978
///      ("without having any ejaculation" for "min ghayri htilam" = not
///      from a wet dream), Ibn Hibban 1178 ("then ejaculates" for
///      "jahadaha" = exerts himself -- the hadith's whole point is ghusl
///      WITHOUT emission), Bayhaqi 13919 ("ejaculation" for "ifda'" =
///      intimate conjugal contact), Bayhaqi 14881 ("no completion after
///      ejaculation" for "la yutma ba'da ihtilam" = no orphanhood after
///      puberty), Bulugh 973 ("having ejaculation during sleep" for "tara
///      fi manamiha ma yara al-rajul" = sees in her dream what a man
///      sees), Nasai 5088 / Nasai-Kubra 9310 (broken "removing to
///      ejaculate in other than the right place" for "'azl al-ma' bi-
///      ghayri mahillihi" = withdrawal), Tabarani 4374 ("before
///      ejaculation" for "qabla an afrugha" = before I had finished).
///   5. Adjacent ghusl/wudu confusion in the same reviewed rows (changes
///      the ruling): Bayhaqi 774, Tabarani 4374, Ibn Hibban 1185 all
///      rendered "ghusl / ightasala" as "ablution".
///
/// Full-text replacements (Hakim 7900, Bayhaqi 8051, Bayhaqi 14918,
/// Nasai-Kubra 2943) clear `isAiTranslated`: the new text is a
/// human-verified translation of the row's own Arabic, per the
/// fix_bayhaqi_14109_translation.dart precedent. Partial patches keep the
/// flag.
///
/// Usage: dart run tool/fix_ejaculation_wording_2026_08_03.dart
void main() {
  var applied = 0, alreadyApplied = 0;

  for (final fix in fixes) {
    final file = File('db/by_book/${fix.file}');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final hadiths = (data['hadiths'] as List).cast<Map<String, dynamic>>();

    final row = hadiths.firstWhere(
      (h) => h['idInBook'] == fix.idInBook,
      orElse: () => throw StateError(
          '${fix.file}: no row with idInBook=${fix.idInBook}'),
    );
    final ref = row['reference'];
    final refText = ref is Map ? (ref['text'] ?? ref['url'] ?? '') : '$ref';
    if (fix.refContains != null && !'$refText'.contains(fix.refContains!)) {
      throw StateError(
          '${fix.file} idInBook=${fix.idInBook}: reference "$refText" does '
          'not contain expected "${fix.refContains}" -- refusing to patch.');
    }

    final english = row['english'] as Map<String, dynamic>;
    var text = english['text'] as String;
    var changed = false;

    if (fix.fullReplacement != null) {
      if (text == fix.fullReplacement) {
        alreadyApplied++;
      } else {
        stdout.writeln('--- ${fix.file} #${fix.idInBook} ($refText) OLD:\n'
            '$text\n+++ NEW:\n${fix.fullReplacement}\n');
        text = fix.fullReplacement!;
        row.remove('isAiTranslated');
        changed = true;
      }
    }

    for (final r in fix.replacements) {
      if (text.contains(r.oldText)) {
        stdout.writeln('--- ${fix.file} #${fix.idInBook} ($refText):\n'
            '  - ${r.oldText}\n  + ${r.newText}\n');
        text = text.replaceFirst(r.oldText, r.newText);
        changed = true;
      } else if (text.contains(r.newText)) {
        alreadyApplied++;
      } else {
        throw StateError(
            '${fix.file} idInBook=${fix.idInBook}: neither old nor new text '
            'found for replacement:\n${r.oldText}');
      }
    }

    if (changed) {
      english['text'] = text;
      file.writeAsStringSync(
          const JsonEncoder.withIndent('\t').convert(data));
      applied++;
    }
  }

  stdout.writeln('Done: $applied row(s) patched, '
      '$alreadyApplied replacement(s) already applied.');
}

class Rep {
  const Rep(this.oldText, this.newText);
  final String oldText;
  final String newText;
}

class Fix {
  const Fix(this.file, this.idInBook,
      {this.refContains,
      this.replacements = const [],
      this.fullReplacement});
  final String file;
  final int idInBook;
  final String? refContains;
  final List<Rep> replacements;
  final String? fullReplacement;
}

const String muaqqibatOld =
    'There are certain ejaculations, the repeaters of which or the '
    'performers of which';
const String muaqqibatNew =
    "There are certain phrases of remembrance (mu'aqqibat), the repeaters "
    'of which or the performers of which';

final List<Fix> fixes = [
  // -- Class 1: archaic "ejaculations" = the mu'aqqibat (post-prayer tasbih)
  Fix('hadithunlocked/muslim.json', 1344,
      refContains: 'Sahih Muslim 596a',
      replacements: const [Rep(muaqqibatOld, muaqqibatNew)]),
  Fix('hadithunlocked/muslim.json', 1345,
      refContains: 'Sahih Muslim 596bc',
      replacements: const [Rep(muaqqibatOld, muaqqibatNew)]),
  Fix('the_9_books/muslim.json', 1349,
      refContains: 'Sahih Muslim 596a',
      replacements: const [Rep(muaqqibatOld, muaqqibatNew)]),
  Fix('the_9_books/muslim.json', 1350,
      replacements: const [Rep(muaqqibatOld, muaqqibatNew)]),
  Fix('hadithunlocked/tabarani.json', 6158,
      refContains: 'Tabarani 16373',
      replacements: const [Rep(muaqqibatOld, muaqqibatNew)]),

  // -- Class 2: madhi mistranslated as ejaculation (inverts the ruling)
  Fix('hadithunlocked/tabarani.json', 2425,
      refContains: 'Tabarani 5589',
      replacements: const [
        Rep('about a man who approaches his wife and ejaculates.',
            'about a man who approaches his wife and emits madhi '
            '(pre-seminal fluid).'),
      ]),
  Fix('hadithunlocked/tabarani.json', 7470,
      refContains: 'Tabarani 17760',
      replacements: const [
        Rep('a man who plays with his wife and talks to her until he '
                'ejaculates.',
            'a man who plays with his wife and talks to her and so emits '
            'madhi (pre-seminal fluid).'),
      ]),
  Fix('hadithunlocked/tabarani.json', 7501,
      refContains: 'Tabarani 17794',
      replacements: const [
        Rep('about a man who experiences ejaculation when he approaches his '
                'wife, what should he do?',
            'about a man from whom madhi (pre-seminal fluid) comes out when '
            'he approaches his wife -- what must he do?'),
        Rep("'If one of you experiences it, then let him perform ghusl, "
                "cleanse his private parts, and perform ablution for "
                "prayer.'",
            "'When one of you finds that, let him rinse his private part "
            "and perform ablution as he would for prayer.'"),
      ]),

  // -- Class 3: fabricated / mismatched AI content (full replacements)
  Fix('hadithunlocked/hakim.json', 7906,
      refContains: 'Mustadrak al-Hakim 7900',
      fullReplacement: '"The gift of the believer is death."'),
  Fix('hadithunlocked/bayhaqi.json', 7417,
      refContains: 'Bayhaqi 8051',
      fullReplacement:
          'A Bedouin came to the Prophet \u{FDFA}, plucking at his hair, and '
          'said, "O Messenger of Allah, I came to my family (had marital '
          'relations) during Ramadan." So he ordered him to offer the '
          'expiation of zihar; and likewise [the narration continues].'),
  Fix('hadithunlocked/bayhaqi.json', 13710,
      refContains: 'Bayhaqi 14918',
      fullReplacement:
          'Abdullah bin Umar divorced his wife while she was menstruating, '
          'so Umar went to the Prophet \u{FDFA} and asked him. He ordered '
          'him to take her back and then divorce her at the beginning of '
          "her waiting period. I said: 'Does that (divorce) count?' He "
          "said: 'Yes -- what do you think if he had been incapable or had "
          "acted foolishly?'"),
  Fix('hadithunlocked/nasai-kubra.json', 2867,
      refContains: 'Nasai 2943',
      fullReplacement:
          'He narrated it from his father, from his grandfather, from Abu '
          'Hurairah, from Usamah bin Zayd. [2943] Aisha reported that the '
          'Prophet \u{FDFA} used to go out to the morning prayer with his '
          'head dripping with water from marital relations -- not from a '
          'wet dream -- and would then fast that day. Abdur-Rahman '
          'mentioned that to Marwan bin al-Hakam, and Marwan said: "I '
          'adjure you: go to Abu Hurairah and tell him this." Abdur-Rahman '
          'said: "May Allah forgive you -- he is my friend, and I do not '
          'like to contradict what he says." Abu Hurairah used to say: '
          '"Whoever has a wet dream or has marital relations during the '
          'night, then is overtaken by dawn and performs ghusl, should not '
          'fast." Marwan said: "I insist that you go." So Abdur-Rahman '
          'went and told him, and Abu Hurairah said: "She knows the '
          'Messenger of Allah \u{FDFA} better than we do; it was only '
          'Usamah bin Zayd who told me that." Abu Abdur-Rahman (al-Nasa\'i) '
          'said: Abu Hazim and Ibn Jurayj differed [in narrating] from '
          'Abd al-Malik bin Abi Bakr concerning it.'),

  // -- Class 4: wrong word for ihtilam / juhd / ifda' / yutm / 'azl / faragh
  Fix('hadithunlocked/nasai-kubra.json', 2901,
      refContains: 'Nasai 2978',
      replacements: const [
        Rep('in a state of janaabah without having any ejaculation',
            'in a state of janaabah -- not from a wet dream --'),
        Rep('Abu came to Aisha', 'My father went in to Aisha'),
        Rep('"I am convinced of what you have encountered with Abu '
                'Hurayrah."',
            '"I adjure you: go and meet Abu Hurayrah."'),
      ]),
  Fix('hadithunlocked/ibnhibban.json', 1120,
      refContains: 'Ibn Hibban 1178',
      replacements: const [
        Rep("between the four parts of his wife's body and then ejaculates, "
                'it becomes obligatory',
            "between the four parts of his wife's body and then exerts "
            'himself, it becomes obligatory'),
      ]),
  Fix('hadithunlocked/bayhaqi.json', 12793,
      refContains: 'Bayhaqi 13919',
      replacements: const [
        Rep('And He said, regarding touching and fondling and ejaculation, '
                'similar to that.',
            "And he said regarding touching, contact, and intimate conjugal "
            "contact (ifda'), the like of that."),
      ]),
  Fix('hadithunlocked/bayhaqi.json', 13675,
      refContains: 'Bayhaqi 14881',
      replacements: const [
        Rep('there is no breastfeeding after weaning, no completion after '
                'ejaculation',
            'there is no suckling after weaning, no orphanhood after '
            'puberty (ihtilam)'),
      ]),
  Fix('other_books/bulugh_almaram.json', 133,
      replacements: const [
        Rep('about the precept of a woman having ejaculation during sleep '
                'like a man,',
            'about a woman who sees in her dream what a man sees,'),
      ]),
  Fix('the_9_books/nasai.json', 5088,
      refContains: 'Nasa\'i 5088',
      replacements: const [
        Rep('removing to ejaculate in other than the right place',
            "withdrawing to spill semen other than in its proper place "
            "('azl)"),
      ]),
  Fix('hadithunlocked/nasai-kubra.json', 9045,
      refContains: 'Nasai 9310',
      replacements: const [
        Rep('removing to ejaculate in other than the right place',
            "withdrawing to spill semen other than in its proper place "
            "('azl)"),
      ]),
  Fix('hadithunlocked/tabarani.json', 1103,
      refContains: 'Tabarani 4374',
      replacements: const [
        Rep('Then he left and performed ablution. Then he returned and the '
                'Prophet \u{FDFA} saw the trace of the ablution on him, so '
                'the Prophet \u{FDFA} asked him about his ablution.',
            'Then he left and performed ghusl (bathed). Then he returned '
            'and the Prophet \u{FDFA} saw the trace of the ghusl on him, '
            'so the Prophet \u{FDFA} asked him about his ghusl.'),
        Rep('so I got up before ejaculation and performed ablution.',
            'so I got up before finishing and performed ghusl.'),
      ]),

  // -- Class 5: adjacent ghusl/wudu confusion in already-reviewed rows
  Fix('hadithunlocked/bayhaqi.json', 721,
      refContains: 'Bayhaqi 774',
      replacements: const [
        Rep('did not ejaculate, there is no obligation for him to perform '
                'ablution.',
            'did not ejaculate, there is no ghusl obligation on him.'),
        Rep('if the circumcision passed the circumcision, then the '
                'obligation of performing ablution arises',
            'if the circumcised part passes the circumcised part, then '
            'ghusl becomes obligatory'),
        Rep('the fatwa that water from water is permissible is the most '
                'lenient fatwa that the Messenger of Allah \u{FDFA} had '
                'issued at the beginning of Islam, and then he commanded '
                'to perform ablution.',
            "the ruling that 'water is from water' was a concession the "
            'Messenger of Allah \u{FDFA} granted at the beginning of '
            'Islam, and then he commanded ghusl.'),
      ]),
  Fix('hadithunlocked/ibnhibban.json', 1127,
      refContains: 'Ibn Hibban 1185',
      replacements: const [
        Rep('did so and we all performed ablution from it.',
            'did so and we both performed ghusl (bathed) from it.'),
      ]),
];
