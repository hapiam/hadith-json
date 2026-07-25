$dir = "C:\Users\htezc\AppData\Local\Temp\claude\C----src-hapi-hapi-app-v2\761c1663-057a-4d18-8d4c-ef4572e50638\scratchpad"

function Escape-Dart([string]$s) {
  $s = $s -replace '\\', '\\\\'
  $s = $s -replace '"', '\"'
  $s = $s -replace '\$', '\$'
  return $s
}

$sb = New-Object System.Text.StringBuilder

for ($n = 59; $n -le 86; $n++) {
  $htmlPath = Join-Path $dir "s$n.html"
  $txtPath = Join-Path $dir "s$n.txt"
  $html = Get-Content $htmlPath -Raw -Encoding UTF8
  $headers = [regex]::Matches($html, '<h[234]>([^<]*)</h[234]>') | ForEach-Object { $_.Groups[1].Value.Trim() }

  $lines = Get-Content $txtPath -Encoding UTF8

  # Find key line indices
  $idxSurahNum = [array]::IndexOf($lines, 'Surah #')
  $meaning = $lines[$idxSurahNum + 3]
  $ayaat = $lines[$idxSurahNum + 5]
  $place = $lines[$idxSurahNum + 7].Trim()
  $revOrder = $lines[$idxSurahNum + 9].Trim()
  $rukuRaw = $lines[$idxSurahNum + 11].Trim()
  $hizbRaw = $lines[$idxSurahNum + 13].Trim()
  $juzRaw = $lines[$idxSurahNum + 15].Trim()
  $manzilRaw = $lines[$idxSurahNum + 17].Trim()

  $rukuMatch = [regex]::Match($rukuRaw, '^\d+')
  $rukuCount = if ($rukuMatch.Success) { $rukuMatch.Value } else { $null }
  $hizbMatch = [regex]::Match($hizbRaw, '^\d+')
  $hizbCount = if ($hizbMatch.Success) { $hizbMatch.Value } else { $null }
  $manzilMatch = [regex]::Match($manzilRaw, '^\d+')
  $manzilCount = if ($manzilMatch.Success) { $manzilMatch.Value } else { $null }
  $revOrderMatch = [regex]::Match($revOrder, '^\d+')
  $revOrderVal = if ($revOrderMatch.Success) { $revOrderMatch.Value } else { $null }

  $placeEnum = if ($place -match 'Medina') { 'medinan' } else { 'meccan' }

  # Find Introduction paragraph(s): between line "Introduction" and line "Details from Tafheem-ul-Qur"
  $introIdx = [array]::IndexOf($lines, 'Introduction')
  $detailsIdx = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -like 'Details from Tafheem*') { $detailsIdx = $i; break }
  }
  $introLines = @()
  for ($i = $introIdx + 1; $i -lt $detailsIdx; $i++) {
    if ($lines[$i].Trim() -ne '') { $introLines += $lines[$i] }
  }
  $introText = ($introLines -join "`n`n")

  # Find footer marker
  $footerIdx = -1
  for ($i = $detailsIdx; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -like 'PrivacyCopyright*') { $footerIdx = $i; break }
  }

  # section headers relevant (exclude "Introduction" itself, keep Name/Period of Revelation/etc.)
  $sectionHeaders = $headers # all h3/h4 in doc order: Name, Period of Revelation, [maybe Reality of Jinn], Theme...

  # Parse section body lines between detailsIdx+1 and footerIdx-1
  $bodyLines = @()
  for ($i = $detailsIdx + 1; $i -lt $footerIdx; $i++) {
    if ($lines[$i].Trim() -ne '') { $bodyLines += $lines[$i] }
  }

  # Walk bodyLines, splitting into sections based on sectionHeaders occurring as literal prefixes
  $sections = New-Object System.Collections.ArrayList
  $curTitle = $null
  $curParas = New-Object System.Collections.ArrayList
  foreach ($line in $bodyLines) {
    $matchedHeader = $null
    foreach ($h in $sectionHeaders) {
      if ($line.StartsWith($h)) { $matchedHeader = $h; break }
    }
    if ($matchedHeader) {
      if ($curTitle) {
        [void]$sections.Add(@{ title = $curTitle; body = ($curParas -join "`n`n") })
      }
      $curTitle = $matchedHeader
      $rest = $line.Substring($matchedHeader.Length)
      $curParas = New-Object System.Collections.ArrayList
      if ($rest.Trim() -ne '') { [void]$curParas.Add($rest) }
    } else {
      [void]$curParas.Add($line)
    }
  }
  if ($curTitle) {
    [void]$sections.Add(@{ title = $curTitle; body = ($curParas -join "`n`n") })
  }

  # Emit Dart
  [void]$sb.AppendLine("  $n`: SurahAbout(")
  [void]$sb.AppendLine("    surahNumber: $n,")
  [void]$sb.AppendLine("    revelationPlace: SurahRevelationPlace.$placeEnum,")
  if ($revOrderVal) { [void]$sb.AppendLine("    revelationOrder: $revOrderVal,") }
  if ($rukuCount) { [void]$sb.AppendLine("    rukuCount: $rukuCount,") }
  if ($hizbCount -or $hizbRaw -eq '0') { [void]$sb.AppendLine("    hizbCount: $hizbCount,") }
  if ($manzilCount) { [void]$sb.AppendLine("    manzil: $manzilCount,") }
  $juzEsc = Escape-Dart $juzRaw
  [void]$sb.AppendLine("    juzInfo: `"$juzEsc`",")
  $introEsc = Escape-Dart $introText
  $introEsc = $introEsc -replace "`n", '\n'
  [void]$sb.AppendLine("    intro:")
  [void]$sb.AppendLine("        `"$introEsc`",")
  [void]$sb.AppendLine("    sections: [")
  foreach ($sec in $sections) {
    $tEsc = Escape-Dart $sec.title
    $bEsc = Escape-Dart $sec.body
    $bEsc = $bEsc -replace "`n", '\n'
    [void]$sb.AppendLine("      SurahAboutSection(")
    [void]$sb.AppendLine("        title: `"$tEsc`",")
    [void]$sb.AppendLine("        body:")
    [void]$sb.AppendLine("            `"$bEsc`",")
    [void]$sb.AppendLine("      ),")
  }
  [void]$sb.AppendLine("    ],")
  [void]$sb.AppendLine("    source: 'https://amrayn.com/quran/info/$n',")
  [void]$sb.AppendLine("  ),")
}

$outPath = Join-Path $dir "entries.dart"
Set-Content -Path $outPath -Value $sb.ToString() -Encoding UTF8
"Generated $outPath"
