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

// hadithunlocked.com's own transcription convention wraps enumerated
// conditions/clauses in parenthesized Arabic-Indic digits inline (e.g.
// "علي خمسة علي: (١) ان يوحد الله، (٢) واقام الصلاة...") -- fawaz's plainer
// transcription of the exact same hadith has no such markers at all. The
// general punctuation strip below removes the surrounding parens but
// leaves the bare digit "١"/"٢" as an orphan extra word, which is enough
// to fail both the word-overlap and containment layers even though the
// underlying content is identical (confirmed concretely 2026-07-29:
// fawaz's Sahih Muslim 16a and hadithunlocked's own version of the same
// hadith normalized to different strings purely because of this, plus the
// two quirks below). Stripped as a unit (digit + parens together) before
// the general punctuation collapse so no orphan digit survives.
final _parenthesizedListMarker = RegExp(r'\(\s*[0-9٠-٩]+\s*\)');

final _punctAndWs = RegExp(
  '[\\s,.،؛؟"\'{}()\\[\\]!?؛:«»' // guillemets: hadithunlocked's own quote
  // style for a narrated matn (e.g. "«بني الاسلام...»") where fawaz uses
  // plain ASCII quotes or none at all -- same "different transcription
  // convention" issue as the list-marker digits above.
  '۔' // Urdu-style full stop (۔), used by hadithunlocked as a
  // sentence-final marker fawaz's transcription doesn't use at all --
  // otherwise glues onto the end of the preceding word and makes it a
  // different token than fawaz's unpunctuated version of that same word.
  '\\-' // fawaz's OWN convention: wraps parenthetical asides in bare
  // hyphens (e.g. "- يَعْنِي حَمَّامًا -", "- قَالَ -") that hadithunlocked's
  // transcription doesn't mark at all (same underlying words, no dashes).
  // A row can carry a dozen or more of these -- surviving as orphan "-"
  // tokens doesn't hurt the word-overlap Dice score much (a set collapses
  // repeats), but each one fragments the longest-common-substring gate
  // into a shorter piece, and enough fragmentation drags a >95%
  // word-identical pair below the 0.3 LCS gate even though nothing about
  // the actual content differs (confirmed concretely 2026-07-29: fawaz
  // hadithnumber 424 vs hadithunlocked "Sahih Muslim 168", 0.977 word
  // overlap but 0.267 LCS ratio before this fix, purely from 14 stray
  // dashes).
  ']+',
);

// Honorific/invocation phrases ("peace be upon him", "may Allah be pleased
// with him/her/them", "Allah have mercy on him") are inserted or omitted
// inconsistently across different transcriptions/editions of the same
// hadith as a matter of scribal convention, not as an actual content
// difference -- stripped for matching purposes only (never for the stored/
// displayed text). Includes the single-glyph ﷺ ligature (U+FDFA) some
// sources use in place of the spelled-out phrase -- verified this exact
// substitution alone (amrayn: ﷺ, fawaz: صلى الله عليه وسلم spelled out) was
// making otherwise-identical hadith score as a "mismatch" under a naive
// whole-string comparison, by splitting one long shared run of text into
// two shorter ones around the substitution point.
final _honorifics = RegExp(
  'صلي الله عليه وسلم|صلي الله عليه وسلم|رضي الله عنه(ما|ا)?|رحمه الله( تعالي)?|'
  'تعالي|عز وجل|ﷺ',
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
  s = s.replaceAll(_parenthesizedListMarker, ' ');
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

/// Classic O(n*m) dynamic-programming longest-common-substring length.
int _longestCommonSubstringLength(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  var prev = List<int>.filled(b.length + 1, 0);
  var best = 0;
  for (var i = 1; i <= a.length; i++) {
    final curr = List<int>.filled(b.length + 1, 0);
    for (var j = 1; j <= b.length; j++) {
      if (a[i - 1] == b[j - 1]) {
        curr[j] = prev[j - 1] + 1;
        if (curr[j] > best) best = curr[j];
      }
    }
    prev = curr;
  }
  return best;
}

/// Longest common substring as a fraction of the SHORTER text's length.
/// Used as a safety gate on the bag-of-words/whole-string similarity layers
/// below: those measure content overlap with no notion of contiguity, so two
/// texts sharing only a long, common ISNAD chain (many hadiths reuse the
/// exact same narrator chain word-for-word, e.g. "AbdAllah ibn Yusuf ->
/// Malik -> Hisham ibn Urwah -> his father -> A'isha") can clear a bag-of-
/// words or bigram threshold despite having a completely different MATN
/// (the actual report content) -- confirmed concretely: content-matching
/// amrayn's book/chapter assignment against fawaz found 27.5% of "book
/// mismatches" were actually the matcher pairing two unrelated hadiths this
/// way (e.g. amrayn's "a baby urinated on the Prophet's ﷺ clothes" citation
/// matched to fawaz's "how does revelation come to you?", sharing only the
/// isnad opening). A genuine match -- even a short excerpt that only
/// captures part of a longer candidate's matn -- always has a long
/// contiguous shared run; an isnad-only collision does not. Always compare
/// honorific-stripped text (a mid-string honorific substitution, e.g. amrayn
/// using the single-glyph ﷺ where fawaz spells out the phrase, otherwise
/// splits one long shared run into two shorter ones and can deflate a
/// genuine match below the gate).
double _lcsRatio(String strippedA, String strippedB) {
  if (strippedA.isEmpty || strippedB.isEmpty) return 0;
  final lcs = _longestCommonSubstringLength(strippedA, strippedB);
  final shorter =
      strippedA.length < strippedB.length ? strippedA.length : strippedB.length;
  return shorter == 0 ? 0 : lcs / shorter;
}

// Below this ratio, two texts do not share a long enough contiguous run to
// be the same report -- matches the "real mismatch" boundary already
// empirically validated in FUZZY_MATCH_ANALYSIS.md/BOOK_MISMATCH_QUALITY.md
// (confirmed false positives clustered at 0.13-0.28; confirmed genuine
// matches, including truncated-isnad excerpts, at 0.6-0.97).
const _lcsGateThreshold = 0.3;

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
    if (score >= 0.5 &&
        score > bestScore &&
        _lcsRatio(_stripHonorifics(oldNorm[i]), _stripHonorifics(canonNorm[k])) >=
            _lcsGateThreshold) {
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
    if (score >= 0.5 &&
        score > bestScore &&
        _lcsRatio(oldStripped, newStripped) >= _lcsGateThreshold) {
      bestScore = score;
      bestIdx = k;
    }
  }
  if (bestScore >= 0.5) return bestIdx;

  var bestBigram = 0.0;
  var bestBigramIdx = -1;
  for (var k = searchLo; k <= searchHi; k++) {
    final score = _bigramDice(oldNorm[i], canonNorm[k]);
    if (score >= 0.85 &&
        score > bestBigram &&
        _lcsRatio(_stripHonorifics(oldNorm[i]), _stripHonorifics(canonNorm[k])) >=
            _lcsGateThreshold) {
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

  // Anchor index: 60-char normalized prefix -> every canonical index sharing
  // that prefix (plural -- see Pass 1 below for why a single "first
  // occurrence wins" index is unsafe here).
  final prefixIndex = <String, List<int>>{};
  for (var i = 0; i < canonNorm.length; i++) {
    final prefix = canonNorm[i].length <= 60
        ? canonNorm[i]
        : canonNorm[i].substring(0, 60);
    prefixIndex.putIfAbsent(prefix, () => []).add(i);
  }

  final oldNorm = oldArabic.map(normalizeForMatching).toList();
  final oldWords = oldNorm.map(_words).toList();
  final result = List<int?>.filled(oldArabic.length, null);

  // Pass 1: anchor matches (exact 60-char normalized prefix). A 60-char
  // prefix is NOT always unique in hadith literature: many different hadiths
  // share the exact same isnad opening word-for-word (e.g. "AbdAllah ibn
  // Yusuf -> Malik -> Hisham ibn Urwah -> his father -> A'isha" is reused
  // across dozens of unrelated reports in Bukhari alone, and that chain
  // alone already exceeds 60 normalized characters). Blindly taking "first
  // occurrence wins" on such a collision silently attaches the wrong hadith
  // -- confirmed concretely: this was the actual root cause behind several
  // "book mismatch" false positives the LCS gate on the *fuzzy* layers below
  // didn't catch, because these pairs never reached the fuzzy layers at all
  // -- they were already (wrongly) resolved right here in Pass 1.
  for (var i = 0; i < oldArabic.length; i++) {
    final prefix = oldNorm[i].length <= 60
        ? oldNorm[i]
        : oldNorm[i].substring(0, 60);
    final candidates = prefixIndex[prefix];
    if (candidates == null) continue;
    if (candidates.length == 1) {
      result[i] = candidates[0];
      stats?.anchorMatches++;
      continue;
    }
    // Ambiguous prefix: only trust it if the FULL normalized text also
    // matches one of the candidates exactly -- that's still a genuine
    // content match (or a real duplicate hadith in the canonical set, in
    // which case any one of the identical candidates is a correct answer).
    // Otherwise leave unresolved so Pass 2's content-aware fuzzy layers
    // (which look at the actual matn, not just the shared isnad prefix)
    // pick the right one instead of guessing.
    final exact = candidates.where((k) => canonNorm[k] == oldNorm[i]);
    if (exact.isNotEmpty) {
      result[i] = exact.first;
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
    if (match == null) {
      // Last resort: search the ENTIRE canonical corpus, no window at all.
      // Verified necessary (not just theoretical) against amrayn's Tirmidhi
      // cross-check: 129 of 175 entries the windowed passes above called
      // "unmatched" turned out to have a real, high-confidence match
      // (median distance 1,733 rows from the nearest anchor, some past
      // 3,700) once searched unboundedly -- amrayn's own citation order
      // drifts from fawaz's canonical order far more, in some stretches,
      // than the anchor±300 retry above ever accounted for. Only reached
      // for the (typically small) residual still unmatched after both
      // windowed passes, so the extra full-corpus scan's cost stays
      // bounded regardless of how large canonicalArabic is overall.
      match = _bestMatchInRange(
        i,
        0,
        canonNorm.length - 1,
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
