# TBH Idle RPG — GitHub 双仓迁移脚本
# 前置：gh auth login（或设置 GH_TOKEN）
# 用法：powershell -ExecutionPolicy Bypass -File tools\setup_github_repos.ps1

$ErrorActionPreference = "Stop"
$Owner = "l1162418914-pixel"
$LegacyRemote = "https://github.com/$Owner/TBH-Idle-RPG-legacy.git"
$V2Remote = "https://github.com/$Owner/TBH-Idle-RPG.git"
$LegacyLocal = "C:\Users\19173\Desktop\TBH_Idle_RPG"
$V2Local = "C:\Users\19173\Desktop\TBH_Idle_RPG_v2"
$OldRepo = "$Owner/_Idle_RPG"

function Require-Gh {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "未找到 gh。请安装 GitHub CLI 后执行 gh auth login"
    }
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "gh 未登录。请执行: gh auth login"
    }
}

function Repo-Exists($Name) {
    gh repo view "$Owner/$Name" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

Write-Host "== 检查 gh 登录 ==" -ForegroundColor Cyan
Require-Gh

# --- 步骤 1：legacy 仓（推荐 rename，保留历史）---
Write-Host "`n== 步骤 1 · legacy 仓 ==" -ForegroundColor Cyan
if (Repo-Exists "TBH-Idle-RPG-legacy") {
    Write-Host "TBH-Idle-RPG-legacy 已存在，跳过创建/改名"
}
elseif (Repo-Exists "_Idle_RPG") {
    Write-Host "将 _Idle_RPG 改名为 TBH-Idle-RPG-legacy ..."
    gh repo rename TBH-Idle-RPG-legacy --repo $OldRepo --yes
}
else {
    Write-Host "创建 TBH-Idle-RPG-legacy 空仓 ..."
    gh repo create "$Owner/TBH-Idle-RPG-legacy" --public --description "ARCHIVED: WORLD-REEL v2 之前的实现，仅供参考"
}

# --- 步骤 2：v2 空仓 ---
Write-Host "`n== 步骤 2 · v2 空仓 ==" -ForegroundColor Cyan
if (Repo-Exists "TBH-Idle-RPG") {
    Write-Host "TBH-Idle-RPG 已存在，跳过创建"
}
else {
    Write-Host "创建 TBH-Idle-RPG 空仓 ..."
    gh repo create "$Owner/TBH-Idle-RPG" --public --description "TBH Idle RPG v2 — WORLD-REEL 主开发"
}

# --- 步骤 3：legacy 本地推送 ---
Write-Host "`n== 步骤 3 · legacy 推送 ==" -ForegroundColor Cyan
Push-Location $LegacyLocal
git remote set-url origin $LegacyRemote
git push -u origin main
git push origin archive/pre-world-reel
Pop-Location

# --- 步骤 4：v2 首提交 + 推送 ---
Write-Host "`n== 步骤 4 · v2 推送 ==" -ForegroundColor Cyan
Push-Location $V2Local
git remote remove origin 2>$null
git remote add origin $V2Remote
if (-not (git rev-parse HEAD 2>$null)) {
    git commit -m "chore(v2): scaffold WORLD-REEL shell from legacy whitelist"
}
git push -u origin main
Pop-Location

Write-Host "`n完成。请确认：" -ForegroundColor Green
Write-Host "  legacy: $LegacyRemote"
Write-Host "  v2:     $V2Remote"
Write-Host "建议在 GitHub 将 TBH-Idle-RPG-legacy 标记为 Archived（Settings -> Archive this repository）"
