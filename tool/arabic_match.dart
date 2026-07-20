/// Cross-source Arabic hadith-text matching — attaches one source's rows
/// (e.g. AhmedBaset's partial spine, which carries the only translations we
/// have) onto another source's canonical numbering (e.g. mhashim6/
/// hadith-islamware's exact-count Arabic scaffold) by comparing the Arabic
/// text itself, never by position/sequence number.
///
/// Position-based matching was tried first and rejected: for Musnad Ahmad,
/// content-matching found 99.6% of AhmedBaset's entries existed verbatim in
/// mhashim6's fuller set, but only 17% of those matches landed at the same
/// sequence number (some off by more than 25,000) -- a naive "just line them
/// up" approach would have silently attached the wrong Arabic hadith to a
/// translation over 80% of the time.
///
/// Verified against Ahmad (1,374 old-source rows) and Darimi (3,406
/// old-source rows): **100.00% matched** on both, every remaining edge case
/// traced to a real, understood cause (see the layer table in each
/// `_bestMatchInRange` branch) rather than guessed at or force-fit.
///
/// STAGE: shared library, not a standalone pipeline step. This file is
/// `library;` with no `main()` -- it's imported by whichever script needs
/// content-based reconciliation (currently `build_unified_editions.dart`'s
/// history and the original bukhari/muslim/.../ibnmajah content-match
/// rebuild). Historical note (see NUMBERING_CORRUPTION_AUDIT.md): the actual
/// one-off script that called `matchToCanonical` to produce the *current*
/// checked-in spine data for those 6 books is not present anywhere in this
/// repo or its git history -- almost certainly run locally and never
/// committed. Treat this file as the trustworthy, reproducible part of that
/// rebuild; the collision-resolution step that consumed its output is not.
library;

final _tashkeelAndQuranicMarks = RegExp('[ً-ٰٕۖ-ۭ࣓-ࣿ]');
final _alifVariants = RegExp('[آأإٱ]');
final _tatweel = RegExp('ـ');
final _rtlMarks = RegExp('[‎‏‪-‮]');
final _punctAndWs = RegExp(r'''[\s,.،؛؟"'{}()\[\]!?؛:]+''');

// Honorific/invocation phrases ("peace be upon him", "may Allah be pleased
// with him/her/them", "Allah have mercy on him") are inserted or omitted
// inconsistently across different transcriptions/editions of the same
// hadith as a matter of scribal convention, not as an actual content
// difference -- stripped for matching purposes only (never for the stored/
// displayed text).
final _honorifics = RegExp(
  'صلي الله عليه وسلم|صلي الله عليه وسلم|رضي الله عنه(ما|ا)?|رحمه الله( تعالي)?|'
  'تعالي|عز وجل',
);

// One source appends explicit Qur'an citations ("سورة البقرة اية 203") after
// an embedded verse quote; another just quotes the verse text itself with no
// citation -- same underlying content, different annotation convention. "#"
// markers are footnote/quote delimiters with no equivalent across sources.
final _quranCitation = RegExp('سورة [^0-9]* اية [0-9]+');
final _hashMarkers = RegExp('#');

/// Normalizes Arabic text for cross-source matching: strips RTL marks,
/// tatweel, tashkeel/Quranic annotation marks, folds alif variants
/// (آ/أ/إ/ٱ -> ا) and alif-maqsura/ya (ى -> ي), collapses punctuation +
/// whitespace. Deliberately narrower/more conservative than the app's own
/// `normalizeArabicForSearch` (used for user-facing search) -- this is for
/// exact cross-*source* reconciliation, not fuzzy user queries.
String normalizeForMatching(String input) {
  var s = input;
  s = s.replaceAll(_rtlMarks, '');
  s = s.replaceAll(_tatweel, '');
  s = s.replaceAll(_tashkeelAndQuranicMarks, '');
  s = s.replaceAll(_alifVariants, 'ا');
  s = s.replaceAll('ى', 'ي');
  s = s.replaceAll(_punctAndWs, ' ').trim();
  return s;
}

String _stripHonorifics(String normalized) => normalized
    .replaceAll(_honorifics, ' ')
    .replaceAll(_quranCitation, ' ')
    .replaceAll(_hashMarkers, ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Character-bigram Dice coefficient -- a safe, cheap fallback for small
/// single-letter spelling variants (e.g. "اسحاق" vs "اسحق" for a narrator's
/// name) that word-overlap and containment both miss, without the risk a
/// blanket "drop every mid-word alif" rule would carry (that would erase
/// real distinguishing letters and risk false matches).
Set<String> _bigrams(String s) {
  final out = <String>{};
  for (var i = 0; i + 1 < s.length; i++) {
    out.add(s.substring(i, i + 2));
  }
  return out;
}

double _bigramDice(String a, String b) {
  final ba = _bigrams(a), bb = _bigrams(b);
  if (ba.isEmpty || bb.isEmpty) return 0;
  return 2 * ba.intersection(bb).length / (ba.length + bb.length);
}

List<String> _words(String normalized) =>
    normalized.split(' ').where((w) => w.isNotEmpty).toList();

double _wordOverlap(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final setA = a.toSet();
  final setB = b.toSet();
  final inter = setA.intersection(setB).length;
  return 2 * inter / (setA.length + setB.length); // Dice coefficient
}

/// Layered match attempt within `[searchLo, searchHi]` of the canonical
/// list: word-overlap, then plain containment, then space-insensitive
/// containment (transcription gaps), then honorific-stripped word-overlap/
/// containment (scribal insertions), then character-bigram similarity
/// (small spelling variants), then a sliding fuzzy-substring window (short
/// fragments merged into a longer neighbor on one side but not the other).
/// Returns the matched canonical index, or null if nothing clears threshold.
int? _bestMatchInRange(
  int i,
  int searchLo,
  int searchHi,
  List<String> oldNorm,
  List<List<String>> oldWords,
  List<String> canonNorm,
  List<List<String>> canonWords,
) {
  double bestScore = 0;
  int bestIdx = -1;
  for (var k = searchLo; k <= searchHi; k++) {
    final score = _wordOverlap(oldWords[i], canonWords[k]);
    if (score > bestScore) {
      bestScore = score;
      bestIdx = k;
    }
  }
  if (bestScore >= 0.5) return bestIdx;

  for (var k = searchLo; k <= searchHi; k++) {
    if (oldNorm[i].length > 20 && canonNorm[k].contains(oldNorm[i])) return k;
    if (canonNorm[k].length > 20 && oldNorm[i].contains(canonNorm[k])) return k;
  }

  final oldNoSpace = oldNorm[i].replaceAll(' ', '');
  for (var k = searchLo; k <= searchHi; k++) {
    final newNoSpace = canonNorm[k].replaceAll(' ', '');
    if (oldNoSpace.length > 20 && newNoSpace.contains(oldNoSpace)) return k;
    if (newNoSpace.length > 20 && oldNoSpace.contains(newNoSpace)) return k;
  }

  final oldStripped = _stripHonorifics(oldNorm[i]);
  final oldStrippedNoSpace = oldStripped.replaceAll(' ', '');
  final oldStrippedWords = _words(oldStripped);
  for (var k = searchLo; k <= searchHi; k++) {
    final newStripped = _stripHonorifics(canonNorm[k]);
    if (oldStripped.length > 20 && newStripped.contains(oldStripped)) return k;
    if (newStripped.length > 20 && oldStripped.contains(newStripped)) return k;
    final newStrippedNoSpace = newStripped.replaceAll(' ', '');
    if (oldStrippedNoSpace.length > 20 &&
        newStrippedNoSpace.contains(oldStrippedNoSpace))
      return k;
    if (newStrippedNoSpace.length > 20 &&
        oldStrippedNoSpace.contains(newStrippedNoSpace))
      return k;
    final score = _wordOverlap(oldStrippedWords, _words(newStripped));
    if (score > bestScore) {
      bestScore = score;
      bestIdx = k;
    }
  }
  if (bestScore >= 0.5) return bestIdx;

  var bestBigram = 0.0;
  var bestBigramIdx = -1;
  for (var k = searchLo; k <= searchHi; k++) {
    final score = _bigramDice(oldNorm[i], canonNorm[k]);
    if (score > bestBigram) {
      bestBigram = score;
      bestBigramIdx = k;
    }
  }
  if (bestBigram >= 0.85) return bestBigramIdx;

  // Sliding fuzzy-substring: a short continuation fragment merged into a
  // much longer candidate dilutes whole-string similarity (Dice divides by
  // total length on both sides) even when the fragment is a near-exact
  // match to one small piece of that candidate. Comparing against
  // same-length windows of the candidate instead of the whole thing avoids
  // that dilution.
  final target = oldStripped.isNotEmpty ? oldStripped : oldNorm[i];
  if (target.length >= 15) {
    for (var k = searchLo; k <= searchHi; k++) {
      final cand = _stripHonorifics(canonNorm[k]);
      if (cand.length <= target.length) continue;
      for (var start = 0; start + target.length <= cand.length; start += 3) {
        final window = cand.substring(start, start + target.length);
        final score = _bigramDice(target, window);
        if (score >= 0.8) return k;
      }
    }
  }

  return null;
}

/// Tally of how `matchToCanonical` resolved its input: `anchorMatches` (exact
/// 60-char prefix, the trustworthy majority), `fuzzyMatches` (only cleared
/// one of the softer layers -- word-overlap, containment, bigram, or the
/// sliding-window fallback), and `unmatched` (nothing cleared any threshold).
/// The README's per-book match-rate table and `DATA_QUALITY_REPORT.md`'s
/// per-entry fuzzy-match listing are both driven off this, so a caller that
/// discards `stats` loses the only audit trail of *which* matches were
/// anchor-solid vs. merely plausible.
class MatchStats {
  int anchorMatches = 0;
  int fuzzyMatches = 0;
  int unmatched = 0;
  final List<String> unmatchedSamples = [];
  int get total => anchorMatches + fuzzyMatches;
}

/// Matches every entry in [oldArabic] to its index in [canonicalArabic] by
/// content, not position. Returns a list the same length as [oldArabic];
/// `result[i]` is the matched index into [canonicalArabic], or null if no
/// match cleared any layer's threshold.
///
/// [oldLabels] (same length as [oldArabic], e.g. `idInBook` values as
/// strings) is used only to make [stats].unmatchedSamples readable -- pass
/// an empty list to skip labeling.
///
// TODO: this function has no collision detection -- nothing stops two
// distinct entries in [oldArabic] from both matching the same canonical
// index (expected whenever a base hadith and its lettered citation sibling,
// e.g. "690a"/"690b", share almost all of their text). NUMBERING_CORRUPTION_
// AUDIT.md's "Pattern A" traces several confirmed production bugs (Sahih
// Muslim idInBook 3772/374/4153, likely all of Tirmidhi's 20 outliers) to
// exactly this: whatever downstream step decided "this one gets the
// canonical slot, that one becomes an addendum" on collision handled it
// correctly most of the time but not always, and that step isn't even
// present in this repo to fix (see the library-level doc comment above). A
// caller of this function MUST post-process [result] for duplicate indices
// and decide addendum placement explicitly -- don't assume a 1:1 mapping.
List<int?> matchToCanonical({
  required List<String> oldArabic,
  required List<String> canonicalArabic,
  List<String> oldLabels = const [],
  MatchStats? stats,
}) {
  final canonNorm = canonicalArabic.map(normalizeForMatching).toList();
  final canonWords = canonNorm.map(_words).toList();

  // Anchor index: 60-char normalized prefix -> canonical index (first
  // occurrence wins on collision).
  final prefixIndex = <String, int>{};
  for (var i = 0; i < canonNorm.length; i++) {
    final prefix = canonNorm[i].length <= 60
        ? canonNorm[i]
        : canonNorm[i].substring(0, 60);
    prefixIndex.putIfAbsent(prefix, () => i);
  }

  final oldNorm = oldArabic.map(normalizeForMatching).toList();
  final oldWords = oldNorm.map(_words).toList();
  final result = List<int?>.filled(oldArabic.length, null);

  // Pass 1: anchor matches (exact 60-char normalized prefix).
  for (var i = 0; i < oldArabic.length; i++) {
    final prefix = oldNorm[i].length <= 60
        ? oldNorm[i]
        : oldNorm[i].substring(0, 60);
    final match = prefixIndex[prefix];
    if (match != null) {
      result[i] = match;
      stats?.anchorMatches++;
    }
  }

  // Pass 2: fuzzy-fill gaps between anchors, bounded by the nearest
  // surrounding anchors' canonical positions (assumes roughly monotonic
  // ordering between the two sources, with a widening retry for the rare
  // true match that sits just outside the anchor-derived window).
  for (var i = 0; i < oldArabic.length; i++) {
    if (result[i] != null) continue;

    int? beforeNew;
    for (var j = i - 1; j >= 0; j--) {
      if (result[j] != null) {
        beforeNew = result[j];
        break;
      }
    }
    int? afterNew;
    for (var j = i + 1; j < oldArabic.length; j++) {
      if (result[j] != null) {
        afterNew = result[j];
        break;
      }
    }
    final rawLo = beforeNew ?? 0;
    final rawHi = afterNew ?? canonNorm.length - 1;
    final lo = rawLo < rawHi ? rawLo : rawHi;
    final hi = rawLo < rawHi ? rawHi : rawLo;
    final searchLo = (lo - 5).clamp(0, canonNorm.length - 1);
    final searchHi = (hi + 5).clamp(0, canonNorm.length - 1);

    var match = _bestMatchInRange(
      i,
      searchLo,
      searchHi,
      oldNorm,
      oldWords,
      canonNorm,
      canonWords,
    );
    if (match == null) {
      // Retry once with a much wider window before giving up -- verified
      // cases exist where the true match (>0.97 similarity) sat only ~55
      // rows outside the original anchor-bounded window.
      final wideLo = (lo - 300).clamp(0, canonNorm.length - 1);
      final wideHi = (hi + 300).clamp(0, canonNorm.length - 1);
      match = _bestMatchInRange(
        i,
        wideLo,
        wideHi,
        oldNorm,
        oldWords,
        canonNorm,
        canonWords,
      );
    }

    if (match != null) {
      result[i] = match;
      stats?.fuzzyMatches++;
    } else {
      stats?.unmatched++;
      if (stats != null && stats.unmatchedSamples.length < 15) {
        final label = i < oldLabels.length ? oldLabels[i] : '$i';
        final snippet = oldNorm[i].length > 50
            ? oldNorm[i].substring(0, 50)
            : oldNorm[i];
        stats.unmatchedSamples.add('$label: $snippet');
      }
    }
  }

  return result;
}
