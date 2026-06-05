# Scan multiline string + percent-format anti-patterns (does not run Godot).
$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
	$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $scriptDir) {
	$scriptDir = Join-Path (Get-Location).Path "tools"
}
$root = (Resolve-Path (Join-Path $scriptDir "..")).Path
$scripts = Join-Path $root "scripts"
if (-not (Test-Path -LiteralPath $scripts)) {
	Write-Host "ERROR: scripts folder not found: $scripts"
	exit 2
}
$hits = @()
Get-ChildItem -Path $scripts -Filter "*.gd" -Recurse | ForEach-Object {
	$lines = Get-Content -LiteralPath $_.FullName
	for ($i = 0; $i -lt $lines.Count - 1; $i++) {
		$line = $lines[$i].TrimEnd()
		$next = $lines[$i + 1].Trim()
		if ($line -match '= \($' -or $line -match '\.append\($') { continue }
		if ($line -match '"\s*$' -and $line -notmatch '\+\s*$' -and $line -notmatch '%\s*$') {
			if ($next -match '^% ') {
				$hits += "$($_.FullName):$($i + 2): $next"
			}
			if ($next -match '^"[^"]*"\s*$' -and ($i + 2) -lt $lines.Count) {
				$third = $lines[$i + 2].Trim()
				if ($third -match '^% ') {
					$hits += "$($_.FullName):$($i + 3): multiline string then %"
				}
			}
		}
	}
}
if ($hits.Count -eq 0) {
	Write-Host "OK: no suspicious multiline format patterns."
	exit 0
}
Write-Host "Suspicious patterns (review manually):"
$hits | ForEach-Object { Write-Host $_ }
exit 1
