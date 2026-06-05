# 扫描易错的「多行括号 + 单独一行 %」写法（不运行 Godot）
$here = Split-Path -Parent $PSCommandPath
$root = (Resolve-Path (Join-Path $here "..")).Path
$scripts = Join-Path $root "scripts"
$hits = @()
Get-ChildItem -Path $scripts -Filter "*.gd" -Recurse | ForEach-Object {
	$lines = Get-Content $_.FullName
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
