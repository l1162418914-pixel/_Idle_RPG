# 工作日志（worklogs）

**目的**：两个月后或换机接手时，不依赖 Cursor 聊天记录，在仓库里能还原「那天做了什么、测到哪、下次干什么」。

## 每次收工必做（B 机，约 3 分钟）

1. 复制 `docs/worklogs/_TEMPLATE.md` → 新建 `docs/worklogs/YYYY-MM-DD.md`（同一天多次可加 `-2`）。
2. 填：commit、改了啥、测了啥、未决问题、下次第一步。
3. 可选：把 Cursor 里**当天摘要**贴进「对话要点」一节（不必全文）。
4. 与代码一起提交：
   ```powershell
   git add docs/worklogs/YYYY-MM-DD.md
   # 若有代码改动一并 add
   git commit -m "docs: worklog YYYY-MM-DD"
   git push origin main
   ```

## 开工时

```powershell
git pull origin main
# 看最近一篇
Get-ChildItem docs\worklogs\*.md | Sort-Object Name -Descending | Select-Object -First 3
```

## 命名

- 单日一篇：`2026-06-05.md`
- 同天第二段：`2026-06-05-2.md`

不要改 `_TEMPLATE.md` 本体，只复制。
