# 生成测试存档到 Godot user:// 槽位 1
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Users\19173\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe"
if (-not (Test-Path $Godot)) {
    $found = Get-ChildItem "$env:LOCALAPPDATA" -Recurse -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $Godot = $found.FullName } else { throw "找不到 Godot console 可执行文件" }
}
Set-Location $ProjectRoot
& $Godot --headless --path . --scene res://tools/GenerateTestSave.tscn 2>&1
$saveDir = Join-Path $env:APPDATA "Godot\app_userdata\TBH Idle RPG"
Write-Host ""
Write-Host "存档目录: $saveDir"
if (Test-Path (Join-Path $saveDir "save_slot_1.json")) {
    Write-Host "已生成: save_slot_1.json"
} else {
    Write-Host "未找到 save_slot_1.json，请查看上方 Godot 输出"
}
