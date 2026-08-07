$ErrorActionPreference = 'Stop'

$files = @(
  'C:\devlop\devecostudio\workspace\zhizon\entry\src\main\ets\pages\PveNodeDetail.ets',
  'C:\devlop\devecostudio\workspace\zhizon\entry\src\main\ets\pages\ServerDetail.ets',
  'C:\devlop\devecostudio\workspace\zhizon\entry\src\main\ets\pages\VmDetail.ets'
)

function Test-DelimiterBalance([string]$path) {
  $text = [System.IO.File]::ReadAllText($path)
  $stack = [System.Collections.Generic.List[object]]::new()
  $errors = [System.Collections.Generic.List[string]]::new()
  $pairs = @{ ')' = '('; ']' = '['; '}' = '{' }
  $line = 1
  $column = 0
  $state = 'code'
  $quote = [char]0
  $escaped = $false

  for ($i = 0; $i -lt $text.Length; $i++) {
    $ch = $text[$i]
    $next = if ($i + 1 -lt $text.Length) { $text[$i + 1] } else { [char]0 }
    $column++

    if ($ch -eq "`n") {
      $line++
      $column = 0
      if ($state -eq 'lineComment') { $state = 'code' }
      continue
    }
    if ($state -eq 'lineComment') { continue }
    if ($state -eq 'blockComment') {
      if ($ch -eq '*' -and $next -eq '/') {
        $state = 'code'
        $i++
        $column++
      }
      continue
    }
    if ($state -eq 'string') {
      if ($escaped) {
        $escaped = $false
      } elseif ($ch -eq '\') {
        $escaped = $true
      } elseif ($ch -eq $quote) {
        $state = 'code'
      }
      continue
    }
    if ($ch -eq '/' -and $next -eq '/') {
      $state = 'lineComment'
      $i++
      $column++
      continue
    }
    if ($ch -eq '/' -and $next -eq '*') {
      $state = 'blockComment'
      $i++
      $column++
      continue
    }
    if ($ch -eq "'" -or $ch -eq '"' -or $ch -eq '`') {
      $state = 'string'
      $quote = $ch
      continue
    }
    if ($ch -eq '(' -or $ch -eq '[' -or $ch -eq '{') {
      $stack.Add([pscustomobject]@{ Char = $ch; Line = $line; Column = $column })
      continue
    }
    if ($pairs.ContainsKey([string]$ch)) {
      if ($stack.Count -eq 0) {
        $errors.Add("unexpected '$ch' at ${line}:${column}")
        continue
      }
      $top = $stack[$stack.Count - 1]
      if ($top.Char -ne $pairs[[string]$ch]) {
        $errors.Add("mismatched '$ch' at ${line}:${column}; opened '$($top.Char)' at $($top.Line):$($top.Column)")
      } else {
        $stack.RemoveAt($stack.Count - 1)
      }
    }
  }

  foreach ($open in $stack) {
    $errors.Add("unclosed '$($open.Char)' at $($open.Line):$($open.Column)")
  }
  [pscustomobject]@{
    File = $path
    LineCount = ([System.IO.File]::ReadAllLines($path)).Length
    Balanced = $errors.Count -eq 0
    Errors = @($errors)
  }
}

$results = @($files | ForEach-Object { Test-DelimiterBalance $_ })
$results | ConvertTo-Json -Depth 5
if ($results.Where({ -not $_.Balanced }).Count -gt 0) { exit 1 }
