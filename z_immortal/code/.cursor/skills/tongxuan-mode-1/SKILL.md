---
name: tongxuan-mode-1
description: >-
  Mode-1: when the user sends exactly "1", add clear comments to current game
  changes, create a git commit, and push to origin. No mid-run questions.
---

# 通玄之上 · Mode-1（按 1：注释 + 提交 + 推送）

用户消息**仅为** `1`（可带首尾空白）时，立即执行。不要确认、不要问要不要提交/推送。

## 步骤

1. **看清改动**（git 根目录通常是仓库 `design`，游戏改动前缀 `z_immortal/code/`）  
   并行：`git status`、`git diff`（含已暂存）、`git log -5 --oneline`。

2. **写好注释**（只针对本次相关改动，禁止大范围无关文件）  
   - 给**非显而易见**的逻辑补简短中文或英文注释（意图、约束、为何这样写）。  
   - 不写废话注释（如「增加变量」「返回结果」）。  
   - 不删既有有用注释；不改无关格式大扫荡。  
   - 优先：`src/**/*.gd`、关键场景脚本、`.cursor` 里相关钩子/脚本的模块头说明。

3. **提交**（用户规则：仅 Mode-1 / 明确要求时才 commit）  
   - 不要 commit 密钥（`.env`、credentials 等）。  
   - Mode-2 运行时文件可忽略：`.cursor/mode2-session.json` 等已在 `.gitignore`。  
   - `git add` 相关文件后 commit。  
   - Windows PowerShell 用：
     ```powershell
     git commit -m @"
     简短说明为何改。

     "@
     ```
   - 消息 1–2 句，写**为什么**，贴合仓库近期文风。  
   - **禁止** `--no-verify`、改 git config、amend（除非用户规则里的 amend 条件全满足）。  
   - hook 失败则修问题后**新开** commit，不要 amend 凑。

4. **推送**  
   - 提交成功后立刻推当前分支到 `origin`（常见为 `dev`）。  
   - Windows 若 SSL 不稳，用：
     ```powershell
     git -c http.sslBackend=schannel push -u origin HEAD
     ```
   - 推送失败：换网络/重试一次；仍失败则用中文说明错误，**不要**假装已推送。

5. **收尾**  
   - `git status` 确认干净或只剩有意未提交项。  
   - 用两三句中文说明：注释补在哪、commit hash/标题、是否已推送成功。

## 无改动时

若没有可提交变更：说明「无可提交改动」，不要空 commit；若本地已领先远程则仍可只做 push。
