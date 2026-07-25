Add-Type -AssemblyName System.Web
$dir = "C:\Users\htezc\AppData\Local\Temp\claude\C----src-hapi-hapi-app-v2\761c1663-057a-4d18-8d4c-ef4572e50638\scratchpad"

# Explicit ordered section-heading lists per surah, as identified from the source pages.
$headings = @{
  30 = @('Name','Period of Revelation','Historical Background','Theme and Subject Matter')
  31 = @('Name','Period of Revelation','Theme and Subject Matter')
  32 = @('Name','Period of Revelation','Theme and Topics')
  33 = @('Name','Period of Revelation','Historical Background','Raids Preceding the Battle of the Trench','The Battle of the Trench','Raid on Bani Quraizah','Social Reforms','Storm of Propaganda at the Marriage of Hadrat Zainab','Preliminary Commandments of Purdah','Domestic Affairs of the Holy Prophet','Subject Matter and Topics')
  34 = @('Name','Period of Revelation','Theme and Subject Matter')
  35 = @('Name','Period of Revelation','Theme and Subject Matter')
  36 = @('Name','Period of Revelation','Theme and Subject Matter')
  37 = @('Name','Period of Revelation','Theme and Subject Matter')
  38 = @('Name','Period of Revelation','Historical Background','Subject Matter and Topics')
  39 = @('Name','Period of Revelation','Theme and Subject Matter')
  40 = @('Name','Period of Revelation','Background of Revelation','Theme and Topics')
  41 = @('Name','Period of Revelation','Theme and Subject Matter')
  42 = @('Name','Period of Revelation','Theme and Subject Matter')
  43 = @('Name','Period of Revelation','Theme and Topics')
  44 = @('Name','Period of Revelation','Subject Matter and Topics')
  45 = @('Name','Period of Revelation','Subject Matter and Topics')
  46 = @('Name','Period of Revelation','Historical Background','Subject Matter and Topics')
  47 = @('Name','Period of Revelation','Historical Background','Theme and Subject Matter')
  48 = @('Name','Period of Revelation','Historical Background')
  49 = @('Name','Period of Revelation','Subject Matter and Topics')
  50 = @('Name','Period of Revelation','Theme and Topics')
  51 = @('Name','Period of Revelation','Subject Matter and Topics')
  52 = @('Name','Period of Revelation','Subject Matter and Topics')
  53 = @('Name','Period of Revelation','Historical Background','Subject Matter and Topics')
  54 = @('Name','Period of Revelation','Theme and Subject Matter')
  55 = @('Name','Period of Revelation','Theme and Subject Matter')
  56 = @('Name','Period of Revelation','Theme and Subject Matter')
  57 = @('Name','Period of Revelation','Theme and Subject Matter')
  58 = @('Name','Period of Revelation','Subject Matter and Topics')
}

function Curl-Quotes-Line([string]$s) {
  # Curl quotes with the toggle reset per line, since this source text
  # frequently has a paragraph/list-item open a quotation that trails off
  # into unquoted narrative without ever closing it (rather than a genuine
  # mismatched-nesting case) -- each newline in the extracted text already
  # corresponds to a real block-level boundary (paragraph/list-item/heading),
  # so resetting there avoids one dangling open quote flipping the
  # open/close direction of every quote that follows it in the section.
  $sb = New-Object System.Text.StringBuilder
  $open = $true
  foreach ($ch in $s.ToCharArray()) {
    if ($ch -eq '"') {
      if ($open) { [void]$sb.Append([char]0x201C) } else { [void]$sb.Append([char]0x201D) }
      $open = -not $open
    } else {
      [void]$sb.Append($ch)
    }
  }
  return $sb.ToString()
}

function Curl-Quotes([string]$s) {
  $parts = [regex]::Split($s, "`r`n|`n")
  $curled = $parts | ForEach-Object { Curl-Quotes-Line ($_.TrimEnd("`r")) }
  return ($curled -join "`n")
}

function Clean-Text([string]$s) {
  $s = $s.Trim()
  $s = Curl-Quotes $s
  # collapse 3+ newlines to 2
  $s = [regex]::Replace($s, "(\r?\n){3,}", "`n`n")
  return $s
}

function Dart-Str([string]$s) {
  $s = $s -replace '\\', '\\\\'
  $s = $s -replace '\$', '\$'
  $s = $s -replace "`r`n", "`n"
  $s = $s -replace "`n", '\n'
  return $s
}

$results = @{}

for ($n = 30; $n -le 58; $n++) {
  $text = Get-Content -Raw -Encoding UTF8 "$dir\surah$n.txt"

  $place = if ($text -match 'Revelation place\r?\n\r?\n(\w+)') { $matches[1] } else { $null }
  $order = if ($text -match 'Revelation order\r?\n\r?\n(\d+)') { $matches[1] } else { $null }
  $ruku = if ($text -match "Ruk[^\r\n]*\r?\n\r?\n(\d+)") { $matches[1] } else { $null }
  $hizb = if ($text -match 'Hizb break\(s\)\r?\n\r?\n(\d+)') { $matches[1] } else { $null }
  $manzil = if ($text -match 'Manzil\[3\]\r?\n\r?\n(\d+)') { $matches[1] } else { $null }
  $juz = if ($text -match 'Juz / paara\[2\]\r?\n\r?\n(.+?)\r?\n\r?\nManzil') { $matches[1].Trim() } else { $null }

  $intro = if ($text -match '(?s)Introduction\r?\n\r?\n(.+?)\r?\n\r?\nDetails from Tafheem') { $matches[1].Trim() } else { $null }

  # Body region for sections
  $bodyMatch = [regex]::Match($text, '(?s)Details from Tafheem[^\r\n]*\r?\n\r?\n(.+?)\r?\n\r?\nPrivacyCopyrightContribute')
  $body = $bodyMatch.Groups[1].Value

  $secList = $headings[$n]
  $sections = @()
  for ($i = 0; $i -lt $secList.Count; $i++) {
    $h = [regex]::Escape($secList[$i])
    $startPat = "(?m)^$h\r?\n"
    $sm = [regex]::Match($body, $startPat)
    if (-not $sm.Success) {
      Write-Warning "Surah $n : heading not found: $($secList[$i])"
      continue
    }
    $startIdx = $sm.Index + $sm.Length
    $endIdx = $body.Length
    if ($i -lt $secList.Count - 1) {
      $hNext = [regex]::Escape($secList[$i+1])
      $emNext = [regex]::Match($body, "(?m)^$hNext\r?\n")
      if ($emNext.Success) { $endIdx = $emNext.Index }
    }
    $secBody = $body.Substring($startIdx, $endIdx - $startIdx)
    $sections += [PSCustomObject]@{ Title = $secList[$i]; Body = (Clean-Text $secBody) }
  }

  $results[$n] = [PSCustomObject]@{
    Place = $place
    Order = $order
    Ruku = $ruku
    Hizb = $hizb
    Manzil = $manzil
    Juz = $juz
    Intro = (Clean-Text $intro)
    Sections = $sections
  }
}

# Emit Dart file
$sw = New-Object System.Text.StringBuilder
[void]$sw.AppendLine("import 'package:hapi/quran/surah_about.dart';")
[void]$sw.AppendLine("")
[void]$sw.AppendLine("/// Surahs 30-58's About content, scraped from amrayn.com/quran/info/{n} --")
[void]$sw.AppendLine("/// see [SurahAbout]'s own doc comment for the field shapes and")
[void]$sw.AppendLine("/// `surahAboutFor` (in `surah_about.dart`) for how this range file is")
[void]$sw.AppendLine("/// merged with the other three.")
[void]$sw.AppendLine("const Map<int, SurahAbout> surahAboutData2 = {")

for ($n = 30; $n -le 58; $n++) {
  $r = $results[$n]
  $placeEnum = if ($r.Place -eq 'Makkah') { 'SurahRevelationPlace.meccan' } else { 'SurahRevelationPlace.medinan' }
  [void]$sw.AppendLine("  $n`: SurahAbout(")
  [void]$sw.AppendLine("    surahNumber: $n,")
  [void]$sw.AppendLine("    revelationPlace: $placeEnum,")
  if ($r.Order) { [void]$sw.AppendLine("    revelationOrder: $($r.Order),") }
  if ($r.Ruku) { [void]$sw.AppendLine("    rukuCount: $($r.Ruku),") }
  if ($r.Hizb) { [void]$sw.AppendLine("    hizbCount: $($r.Hizb),") }
  if ($r.Manzil) { [void]$sw.AppendLine("    manzil: $($r.Manzil),") }
  if ($r.Juz) {
    $juzEsc = Dart-Str $r.Juz
    [void]$sw.AppendLine("    juzInfo: '$juzEsc',")
  }
  [void]$sw.AppendLine("    intro:")
  [void]$sw.AppendLine("        `"$(Dart-Str $r.Intro)`",")
  [void]$sw.AppendLine("    source: 'https://amrayn.com/quran/info/$n',")
  [void]$sw.AppendLine("    sections: [")
  foreach ($sec in $r.Sections) {
    [void]$sw.AppendLine("      SurahAboutSection(")
    [void]$sw.AppendLine("        title: '$($sec.Title -replace "'", "\'")',")
    [void]$sw.AppendLine("        body:")
    [void]$sw.AppendLine("            `"$(Dart-Str $sec.Body)`",")
    [void]$sw.AppendLine("      ),")
  }
  [void]$sw.AppendLine("    ],")
  [void]$sw.AppendLine("  ),")
}
[void]$sw.AppendLine("};")

[System.IO.File]::WriteAllText("$dir\surah_about_data_2_generated.dart", $sw.ToString(), [System.Text.Encoding]::UTF8)
"Generated. Length: $($sw.Length)"
