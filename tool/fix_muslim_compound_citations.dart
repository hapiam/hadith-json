import 'dart:convert';
import 'dart:io';

/// STAGE: one-time spine patch, run AFTER `rebuild_muslim_introduction_full.dart`,
/// idempotent (checks the current `reference.text` before rewriting).
///
/// 3 of the "16 known main-body gaps" this rebuild originally documented as
/// confirmed-absent from every source turned out to be wrong -- caught only
/// because the user supplied direct sunnah.com leads and asked "are they
/// found on any of our other resources?" rather than accepting the earlier
/// verdict. Checked each directly (2026-07-29): citations 1489, 1697, and
/// 2293 are NOT missing at all -- they're the trailing member of a
/// sunnah.com compound-citation page, exactly Bukhari's already-handled
/// "272, 273 merged into one page" pattern (see
/// `fix_bukhari_compound_citations.dart`), just never recognized as such
/// for Muslim:
///
/// - `sunnah.com/muslim:1486a` -> "Sahih Muslim 1486a, 1487a, 1488a, 1489"
/// - `sunnah.com/urn/242090`   -> "Sahih Muslim 1697/1698a"
/// - `sunnah.com/urn/256840`   -> "Sahih Muslim 2292, 2293"
///
/// hadithunlocked's own scrape already merges each compound group's content
/// into a single item (it only ever recorded ONE of the numbers as that
/// item's own citation label -- 1486a, 1698a, and 2292 respectively -- and
/// never created separate rows for the others), so unlike Bukhari's fix
/// this one needs no row-merging: just rewrite each existing row's
/// `reference.text` to the FULL compound citation string so
/// `_citationCount()` in `build_unified_editions.dart` (which parses a
/// trailing comma-separated number list) counts the folded-in numbers
/// toward the book's real total. Normalized to comma-separated form even
/// for the "1697/1698a" case (sunnah.com's own display uses a slash there)
/// for consistency with the one convention `_citationCount()` already
/// parses, rather than adding a second separator format it has to
/// recognize.
///
/// The other 6 originally-flagged gaps (1824, 2483, 2503, 2828, 2931,
/// 3007-3014) were independently re-verified the same way (direct
/// sunnah.com fetches of the citation itself plus both immediate
/// neighbors) and confirmed to still be genuinely absent -- no compound
/// page, no redirect, nothing. Left untouched.
///
/// Usage: dart run tool/fix_muslim_compound_citations.dart
void main() {
  const path = 'db/by_book/hadithunlocked/muslim.json';
  final file = File(path);
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final hadiths = (data['hadiths'] as List)
      .map((h) => Map<String, dynamic>.from(h as Map))
      .toList();

  const fixes = {
    '1486a': 'Sahih Muslim 1486a, 1487a, 1488a, 1489',
    '1698a': 'Sahih Muslim 1697, 1698a',
    '2292': 'Sahih Muslim 2292, 2293',
  };

  var fixed = 0;
  for (final h in hadiths) {
    final ref = h['reference'] as Map<String, dynamic>;
    final currentLabel = (ref['text'] as String).replaceFirst('Sahih Muslim ', '');
    final newText = fixes[currentLabel];
    if (newText != null && ref['text'] != newText) {
      stdout.writeln('${ref['text']} -> $newText');
      ref['text'] = newText;
      fixed++;
    }
  }

  data['hadiths'] = hadiths;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln('$path: rewrote $fixed row(s) to their full compound citation.');
}
