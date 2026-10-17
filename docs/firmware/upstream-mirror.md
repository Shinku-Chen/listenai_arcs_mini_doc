# 上游镜像仓（`listenai_arcs_mini`）

> 上游固件仓在 `cloud.listenai.com`，GitHub 侧访问不到（AI 工具、搜索、issue 都用不了），
> 所以有一个只做同步的镜像仓：
> **<https://github.com/Shinku-Chen/listenai_arcs_mini>**（private）
>
> **分工**：镜像仓**只同步上游，不放个人文档**；规范/流程/踩坑全在本仓
> （`docs/firmware/`、`docs/hardware/`）。镜像仓的 `AGENTS.md` 末尾只有一条指针，
> 指向本仓这些文档。

## 1. 镜像仓是什么

| 项 | 值 |
|---|---|
| 上游 | `https://cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini`（公开，匿名 HTTPS 可读） |
| 镜像 | `https://github.com/Shinku-Chen/listenai_arcs_mini`（private，默认分支 `master`，唯一分支） |
| 版本 | 初始快照 `master @23fca91e`（= tag `mini-v3.0.3`），2026-10-18 |
| 内容 | 上游完整树（**不含** `arcs-sdk/samples/`）+ 一条指向本仓的 AI 指针 |

## 2. 快照式同步（不是逐提交镜像）

`master` 上每个 `sync:` 提交 = **上游 master 当时的完整快照**：

```text
sync: upstream master @23fca91e (2026-10-18)
sync: upstream master @<sha> (<date>)
...
```

好处：GitHub 上 diff 两次 sync 就能回答"上游这次改了什么"；不需要 force-push；不受上游历史体积影响。
代价：没有上游逐提交历史与 blame（要看历史去上游仓）。

## 3. 镜像里改了什么、剔除了什么

| 项 | 处理 | 原因 |
|---|---|---|
| `arcs-sdk/samples/` | **整个剔除**（约 188 MB） | 自定义固件用不到；其中 `algo_emmc.bin` 205 MB、`fatfs_db.bin` 90 MB 超过 GitHub 单文件 100 MB 上限 |
| `apps/arcs-mini/prj.conf` 的 `CONFIG_MINIAPP` | 同步时改写为 **`n`** | 镜像不带 `samples/subsys`（小程序 Lua 绑定源码），`y` 会编译失败；本项目是自定义固件，本就不需要小程序运行时 |
| `AGENTS.md` 末尾 | 追加一条指针（幂等） | 告诉 AI：规范和流程在 `Shinku-Chen/ling`，不要在本仓找 |
| `tools/sync-upstream.{ps1,sh}`、`.github/workflows/sync-upstream.yml` | 镜像仓自己维护 | 同步工具本身（唯一允许的非上游文件） |

需要被剔除的部分时**直接去上游仓取**。

> 想要小程序能力：从上游取回 `arcs-sdk/samples/subsys`，再把 `CONFIG_MINIAPP=y` 打开
> （小程序侧开发规范见 [`../development/miniapp-runtime.md`](../development/miniapp-runtime.md)）。

## 4. 怎么同步

```powershell
cd <镜像仓>
.\tools\sync-upstream.ps1 -DryRun      # 先看会改什么
.\tools\sync-upstream.ps1              # 拉上游 → 重建快照 → 提交 → 推送
```

```bash
./tools/sync-upstream.sh
```

GitHub Actions 每周一 04:00 UTC 自动跑一次，也可在 Actions 页手动 `Run workflow`。

脚本行为：`git fetch --depth=1 upstream master` → 用上游树重置工作区 → 删 `arcs-sdk/samples/` →
`CONFIG_MINIAPP=n` → 重写 `AGENTS.md` 指针 → 有变化才提交 `sync: upstream master @<short> (<date>)`。

## 5. 一次大推送的教训（重建镜像时用得上）

单次推送 314 MB 的 pack 被 GitHub **连续 reset 三次**（SSH 23 分钟、HTTPS 4 分钟都断）。
最终做法：用 blob 直接 `git commit-tree` 拼出 **8 个分批提交**（每批约 250 MB 原始 / 40 MB pack），
逐批推到临时分支 `importing`，最后把 tip 推成 `master`，再删临时分支——8 批全部一次通过。

## 6. 回滚

```bash
git log --oneline                 # 找到上一个 sync 提交
git revert <sync 提交>            # 或在镜像仓 git reset --hard <上一个 sync>
```

镜像仓没有受保护分支，`git push --force` 可用，但正常同步不需要它。

## 7. 文档为什么放在本仓而不是镜像仓

- 镜像仓每次同步都会用上游树重置工作区，任何个人文档都要靠"覆盖层 + 每次重放"维持，容易漂移；
- 本仓（ling）是手册仓，`docs/firmware/`、`docs/hardware/`、`docs/development/` 是唯一真相源，
  镜像仓的 `AGENTS.md` 只有一条指针指回来；
- 这样也避免两份规范各写一半、最后互相矛盾。
