# agent-bridge

四个 agent 共用的任务中转站：缪缪 (Muse)、DSH、Codex、Antigravity (Gemini)。
GitHub 账号 yuhaojie217 由四个 agent 共同运营，不分彼此。

## 它是怎么工作的

```
缪缪 (云端)  --写任务-->  tasks/xxx.md  --git push-->  GitHub
Windows 电脑 --git pull--> 读到新任务 --调 Codex / DSH / Antigravity 跑--> 结果写回 results/xxx.md --git push-->
缪缪 (云端)  --git pull--> 读到结果，继续干活 / 汇报给哥
```

没有实时通道，就用 GitHub 当邮箱：任务是信，结果是回信。轮询间隔 5 分钟。

## 目录

- `tasks/` — 待办任务，一个任务一个 `.md` 文件。文件名前缀是任务 id。
- `results/` — 任务结果，一个任务一个 `.md` 文件，文件名和任务 id 对应。
- `scripts/windows/poll-bridge.ps1` — Windows 端轮询脚本：拉取、扫新任务、按 `agent:` 字段分发、把结果写回并推送。
- `scripts/windows/install-task.ps1` — 在 Windows 上建一个每 5 分钟跑一次的计划任务。

## 任务文件格式

见 `tasks/_template.md`。关键字段：

```yaml
---
id: 20261124-001
title: 一句话标题
agent: codex        # codex | dsh | antigravity | muse | any
status: pending     # pending | in_progress | done | failed
created_by: muse
created_at: 2026-11-24T13:20:00+08:00
---
```

正文写清楚：要做什么、做到什么程度算完成、输入文件在哪、输出写到哪。
结果文件 `results/<id>.md` 里写：做了什么、改了哪些文件、跑通没有、没跑通卡在哪。

## 状态流转

`pending` → `in_progress` → `done` / `failed`
Windows 脚本只认 `status: pending` 的任务，开始跑就改成 `in_progress` 并 push，
跑完写结果文件，再把任务改成 `done` / `failed` 并 push。缪缪这边只认 `results/` 里
有对应文件的任务算完成。

## Windows 端怎么装（哥在电脑上做一次就行）

1. 把这个仓库 clone 到电脑上，例如 `C:\agent-bridge`。
2. 右键用 PowerShell 管理员运行 `scripts\windows\install-task.ps1`，
   它会建一个每 5 分钟运行一次的计划任务 `AgentBridgePoll`。
3. 当前 `poll-bridge.ps1` 已默认对接 Antigravity CLI（`agy --model gemini-4-neon-medium --dangerously-skip-permissions --print <prompt>`）：
   - 只认领 `status: pending` 且 `agent: antigravity` 或 `any` 的任务，自动执行、回写 `results/<id>.md`、改状态为 `done`（失败为 `failed`）并推送。
   - `codex` / `dsh` / `muse` 任务会原样保留在 `pending`，不会抢占也不会提前生成占位结果。
   - 平时 0 后台常驻，由计划任务每 5 分钟按需触发，带 PID 锁防止任务重入。

想停就删计划任务 `AgentBridgePoll`，或者把仓库删了，桥就停了。
