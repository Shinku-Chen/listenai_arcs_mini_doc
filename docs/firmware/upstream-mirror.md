# 上游镜像仓（`listenai_arcs_mini`）

> 上游固件仓在 `cloud.listenai.com`，GitHub 侧访问不到（AI 工具、搜索、issue 都用不了），
> 所以有一个只做同步的镜像仓：
> **<https://github.com/Shinku-Chen/listenai_arcs_mini>**（private）
>
> **分工**：镜像仓**只同步上游 + 放固件代码分支**；规范/流程/踩坑/文档全在本仓
> （`docs/firmware/`、`docs/hardware/`、`docs/development/`）。镜像仓的 `AGENTS.md`
> 末尾只有一条指针，指向本仓这些文档。

## 0. 固件代码在哪：镜像仓的功能分支

| 分支 | 用途 | 谁写 |
|---|---|---|
| `master` | **上游 `arcs_mini` 的快照**，只读，由同步脚本改写 | 同步脚本（不要直接提交） |
| `feat/<功能>` | 一个功能一条分支，从 `master` 切 | **我们自己**（固件代码就放这里） |

```bash
git clone git@github.com:Shinku-Chen/listenai_arcs_mini.git
cd listenai_arcs_mini
git switch -c feat/<功能> origin/master
# …改代码，构建（-DBOARD=arcs_mini3）…
git push -u origin feat/<功能>
```

- 文档**不要写进镜像仓**：一律写回本仓（`ling`）。
- 同步上游后，功能分支需要 `git merge origin/master` 跟上（冲突多为 `prj.conf` / `main.c` 的接线处）。
- 提上游 MR 时从镜像仓的分支 cherry-pick 到上游 checkout，别把镜像仓的合成历史推给上游。

## 1. 镜像仓是什么

| 项 | 值 |
|---|---|
| 上游 | `https://cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini`（公开，匿名 HTTPS 可读） |
| 镜像 | `https://github.com/Shinku-Chen/listenai_arcs_mini`（private，默认分支 `master`，唯一分支） |
| 版本 | 初始快照 `master @23fca91e`（= tag `mini-v3.0.3`），2026-10-18 |
| 内容 | 上游完整树（**不含** `arcs-sdk/samples/`）+ 一条指向本仓的 AI 指针 |
| 功能分支 | `feat/*`（固件代码）；`master` 永远只做上游快照 |

## 2. 快照式同步（不是逐提交镜像）

`master` 上每个 `sync:` 提交 = **上游 master 当时的完整快照**：

```text
sync: upstream master @23fca91e (2026-10-18)
sync: upstream master @<sha> (<date>)
...
```

好处：GitHub 上 diff 两次 sync 就能回答"上游这次改了什么"；不需要 force-push；不受上游历史体积影响。
代价：没有上游逐提交历史与 blame（要看历史去上游仓）。

## 3. master 与上游的差异（精确清单）

**目标：master 尽可能等于上游。** 只保留"不同做就同步不起来"的改动。当前实测差异：

| 类别 | 数量 | 具体 |
|---|---|---|
| **删除** | 2,024 个文件 | 全部在 `arcs-sdk/samples/`（含 205 MB `algo_emmc.bin`、90 MB `fatfs_db.bin`，超 GitHub 单文件 100 MB 上限；自定义固件用不到） |
| **修改** | 1 个文件 1 行 | `apps/arcs-mini/prj.conf`：`CONFIG_MINIAPP=n`（镜像不带 `samples/subsys`，`y` 会编译失败） |
| **追加** | 1 个文件末尾 | `AGENTS.md`：一条指针，指向文档仓 `Shinku-Chen/listenai_arcs_mini_doc` |
| **新增** | 4 个文件，全在 `.github/` 下 | `.github/workflows/sync-upstream.yml`、`.github/scripts/sync-upstream.ps1`、`.github/scripts/sync-upstream.sh`、`.github/ai-docs-pointer.md`（本仓自建数据一律收在这里，`tools/` 保持上游原样） |

除此之外**与上游逐字节一致**（29,941 − 4 = 29,937 个上游文件原样保留）。

### 踩过的坑：`git add -A` 会漏 966 个文件

上游 `arcs-sdk/.gitignore` 里有 `vendor/` 等规则，但上游对这些文件是**强制跟踪**的。
初次建镜像时用 `git add -A` 被忽略规则挡掉，`master` 比上游少了 966 个文件
（`arcs-sdk/modules` 743、`system` 218、`soc` 5）——已经用 `git add -f` 补回。

**同步流程不受影响**：`git read-tree -u --reset` 直接把索引设成上游树，绕过 `.gitignore`。
只有"从零建镜像"时要记得用 `git add -f`（或 `git read-tree`）而不是裸 `git add -A`。

### 需要这些被剔除的内容时

直接去上游仓取：`https://cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini` → `arcs-sdk/samples/`。
想要小程序能力：取回 `samples/subsys`，再把 `CONFIG_MINIAPP=y` 打开
（小程序侧规范见 [`../development/miniapp-runtime.md`](../development/miniapp-runtime.md)）。

## 4. 怎么同步

```powershell
cd <镜像仓>
.\tools\sync-upstream.ps1 -DryRun      # 先看会改什么
.\tools\sync-upstream.ps1              # 拉上游 → 重建快照 → 提交 → 推送
```

```bash
./.github/scripts/sync-upstream.sh
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
- 文档仓（`listenai_arcs_mini_doc`）是唯一真相源，`docs/firmware/`、`docs/hardware/`、`docs/development/` 都在那边，
  镜像仓的 `AGENTS.md` 只有一条指针指回来；
- 这样也避免两份规范各写一半、最后互相矛盾。
