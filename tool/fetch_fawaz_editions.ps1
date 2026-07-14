# Refresh fawazahmed0 whole-edition JSON into db/editions
# Usage (from repo root):  .\tool\fetch_fawaz_editions.ps1
# Downloads catalog + *.min.json only (no per-hadith shards).

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

$Base = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1"
$OutDir = Join-Path $RepoRoot "db\editions"
$FilesDir = Join-Path $OutDir "files"
New-Item -ItemType Directory -Force -Path $FilesDir | Out-Null

Write-Host "Downloading catalog..."
Invoke-WebRequest -Uri "$Base/editions.json" -OutFile (Join-Path $OutDir "editions.json") -UseBasicParsing
try {
  Invoke-WebRequest -Uri "$Base/editions.min.json" -OutFile (Join-Path $OutDir "editions.min.json") -UseBasicParsing
} catch {
  Write-Warning "editions.min.json not available: $($_.Exception.Message)"
}
Invoke-WebRequest -Uri "$Base/info.json" -OutFile (Join-Path $OutDir "info.json") -UseBasicParsing

$editions = Get-Content (Join-Path $OutDir "editions.json") -Raw | ConvertFrom-Json
$names = New-Object System.Collections.Generic.List[string]
foreach ($bookProp in $editions.PSObject.Properties) {
  foreach ($col in $bookProp.Value.collection) {
    [void]$names.Add($col.name)
  }
}
Write-Host "Editions to fetch: $($names.Count)"

$failed = New-Object System.Collections.Generic.List[string]
$maxParallel = 8
$i = 0
while ($i -lt $names.Count) {
  $end = [Math]::Min($i + $maxParallel - 1, $names.Count - 1)
  $batch = @($names[$i..$end])
  $jobs = @()
  foreach ($name in $batch) {
    $url = "$Base/editions/$name.min.json"
    $out = Join-Path $FilesDir "$name.min.json"
    $jobs += Start-Job -ScriptBlock {
      param($url, $out, $name)
      try {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
        return @{ ok = $true; name = $name }
      } catch {
        return @{ ok = $false; name = $name; err = $_.Exception.Message }
      }
    } -ArgumentList $url, $out, $name
  }
  foreach ($r in @($jobs | Wait-Job | Receive-Job)) {
    if (-not $r.ok) {
      [void]$failed.Add($r.name)
      Write-Warning ("FAIL {0}: {1}" -f $r.name, $r.err)
    }
  }
  $jobs | Remove-Job
  $i += $maxParallel
  Write-Host ("Progress {0}/{1}" -f ([Math]::Min($i, $names.Count)), $names.Count)
}

if ($failed.Count -gt 0) {
  Write-Host "Retrying $($failed.Count) failures sequentially..."
  $still = New-Object System.Collections.Generic.List[string]
  foreach ($name in @($failed)) {
    $url = "$Base/editions/$name.min.json"
    $out = Join-Path $FilesDir "$name.min.json"
    try {
      Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
      Write-Host ("RETRY OK {0}" -f $name)
    } catch {
      Write-Warning ("RETRY FAIL {0}: {1}" -f $name, $_.Exception.Message)
      [void]$still.Add($name)
    }
  }
  $failed = $still
}

$count = (Get-ChildItem (Join-Path $FilesDir "*.min.json")).Count
Write-Host ("Done. files/*.min.json = {0} / expected {1}" -f $count, $names.Count)
if ($count -lt 70) {
  throw "Abort: fewer than 70 edition files present ($count)."
}
if ($failed.Count -gt 0) {
  Write-Warning ("Still missing: {0}" -f ($failed -join ", "))
}
