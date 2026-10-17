# 固件仓（arcs_mini）自带手册摘要

> 来源：`https://cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini` 的 `AGENTS.md`、`README.MD`、
> `.agents/skills/*`、`res/*/partition_table.json`。
> 摘要在 2026-10-18 校对过一次；固件仓改版后**以固件仓内的原文为准**，本文只是索引与要点。
>
> 与 [conventions.md](conventions.md) / [process.md](process.md) 的分工：
> 那两份是**个人规范**（我在这台机器上的做法与踩坑记录），本文是**项目自带规则**（仓库声明的约定）。
> 冲突时先按固件仓的 skill / AGENTS.md 执行，再把差异补回本仓。

## 1. 仓库是什么

ARCS-MINI 语音助手固件（ListenAI ARCS SoC，RISC-V **AP/CP 双核**）：

| 路径 | 角色 |
|---|---|
| `apps/arcs-mini` | **CP 固件**，主要业务逻辑（日常改这里） |
| `apps/remote-ap` | **AP 固件**，跑算法 |
| `src/` | 语音交互核心：`category`（品类）/ `framework` / `middleware` / `server` / `shell` / `system` / `utils` |
| `apps-ui/` | LVGL 界面（助手页、扫码配网、设置页） |
| `arcs-sdk/` | SDK：HAL / 驱动 / 组件 / 第三方库 / 板型（`boards/arcs_mini`、`arcs_mini3`、`arcs_mini_doll_v2`、`arcs_evb`、`venusa_rd_evb`） |
| `res/<board>/` | 板型资源与 `partition_table.json`；mini 版还有串口开发用的 `boot-dev-autostart.bin` |
| `tools/` | `adb/`、`cskburn/` 等工具 |

**修改范围优先级**（`coding` skill 明写）：

1. 优先改 `apps/` 下的应用工程；
2. 只有多 app 复用或属于 PDK 公共能力时才改 `src/`；
3. **非必要不改 `arcs-sdk/`**；必须改时要先说明原因、影响范围和替代方案。

## 2. 分支约定

- 上游主分支按其 `AGENTS.md` 是 **`arcs-mini/main`**（不是 `main`）；PR / diff 基准以它为准。
- 本 fork（`mine` remote）实际用 `master` 作上游基线，功能一律开 `feat/*`：
  `feat/radio-standalone`（固件主线）、`feat/intercom`（对讲机）、`pr/*`（拟提上游的小补丁）。
  提交前用 `git branch -vv` 确认基线，别假设分支名。

## 3. 环境

```powershell
.\arcs-sdk\env.ps1            # Windows：检测 + 按需安装工具链 + 设置环境变量
.\arcs-sdk\env.ps1 check      # 完整体检
source ./arcs-sdk/env.sh      # Linux/WSL：必须用 source，直接执行会立刻退出
```

- 会设置 `ARCS_BASE` / `NUCLEI_TOOLCHAIN_PATH` / `LISTENAI_TOOLS_PATH` / `PATH`，并检查子模块与串口权限。
- macOS 用 `brew install listenai/tap/arcs-toolchain`（`env.sh` 不会替 macOS 编 GCC）。
- 其它平台用 Docker：`ghcr.io/listenai/arcs-builder:latest`。

## 4. 构建

```powershell
.\build.ps1 -S .\apps\arcs-mini -DBOARD=arcs_mini        # 默认版型
.\build.ps1 -S .\apps\arcs-mini -B build-doll_v2 -DBOARD=arcs_mini_doll_v2
.\build.ps1 -S .\apps\remote-ap -B build-remote-ap -DCONFIG_FILES=arcs_mini.conf -DBOARD=arcs_mini
```

- `build.sh` 与 `build.ps1` 参数一一对应，都在**仓库根目录**执行。
- 配置是 Kconfig：应用级在 `apps/arcs-mini/prj.conf`，实际生效值看 `build/.config`。
- 本机已知坑：`build.ps1` 会被 PowerShell 当成失败（CMake 把 Kconfig 警告写到 stderr，
  脚本 `$ErrorActionPreference=Stop`）→ 直接调 `cmake` + `ninja` 等价，见 [conventions.md §4](conventions.md#4-构建)。

## 5. 烧录

### 5.1 ADB（首选）

```powershell
.\adb_download.ps1 -S res\arcs-mini app      # 只烧 CP app（agent 改代码默认走这条）
.\adb_download.ps1 -S res\arcs-mini          # 完整：ap + tone + wake_word + emoji + respak + app
.\adb_download.ps1 -S res\arcs-mini boot     # 整包：额外烧 boot.bin
```

脚本按 `res/<board>/partition_table.json` 自动派发分区；多设备时务必指定序列号。

### 5.2 cskburn（ADB 起不来时的兜底）

```bash
cskburn -C arcs -b 1500000 -s /dev/ttyACM0 --verify-all 0x600000 build/arcs-mini.bin
# 多分区一起写：
cskburn -C arcs -b 1500000 -s COM10 --verify-all \
  0x0 res/arcs-mini3/boot.bin  0x40000 res/arcs-mini3/ap.bin  0x600000 build/arcs-mini.bin
```

- 波特率默认 `1500000`；本机实测 `921600` 也稳定（CH340 走 COM10）。
- **⚠️ 开发 Boot 闭环（固件仓强制规则）**：串口烧录时，开发阶段必须把
  `res/arcs-mini/boot-dev-autostart.bin` 写进 `0x0`，让设备复位后**直接进业务**（不用长按）；
  开发完成后必须把 `res/arcs-mini/boot.bin` 写回 `0x0`。
- **⚠️ 但 `boot-dev-autostart.bin` 只有 mini（LS2684）有；`res/arcs-mini3/` 里没有**。
  mini3 不要拿 mini 的 boot 顶上——那是另一块板，刷错会黑屏 + USB 不识别。
  mini3 上"冷复位后要长按功能键 3 秒"目前没有官方捷径，见 [process.md](process.md) 与本仓
  [`../development/flashing-and-recovery.md`](../development/flashing-and-recovery.md)。

## 6. 日志

```bash
# 首选：重启后抓 10 秒 ADB shell 输出（仓库根目录执行）
mkdir -p ./tmp && adb shell reboot && adb wait-for-device && timeout 10 adb shell 2>&1 > ./tmp/run-log.txt
```

- 串口：Linux/macOS 用 `picocom -b 921600 --lower-dtr --lower-rts /dev/ttyACM0`；
  Windows 用 PowerShell `System.IO.Ports.SerialPort <COMx>, 921600`（轮询 `ReadExisting`）。
- **cskburn 之后串口粘滞 3~5 秒**：立刻抓日志会得到空文件或乱码，先 `sleep 3`。
- 本机另有两个坑（详见烧录手册）：`adb devices` 为空时要 `ADB_LIBUSB=1` 起 server；
  cskburn 结束的那次复位是**冷复位**，热启动意图位被清掉，需要长按开机。

## 7. 崩溃分析

```bash
riscv64-unknown-elf-addr2line -e build/arcs-mini -a 0xAAAAAAAA 0xBBBBBBBB
```

非 Linux 平台用 Docker 里的同名工具（`/opt/arcs/gcc/bin/...`）。

## 8. 提交规范（固件仓自己的要求）

- conventional commits 格式，**中文描述**，例如
  `fix(player): 修复唤醒提示音随机选择在特定数量下可能死循环的问题`。
- 以当前仓库的用户身份提交；末尾附 `Co-Authored-By: <模型> <noreply@...>`。
- 保持原子提交。

## 9. Skills（`.agents/skills/`，SDK 自带）

| skill | 触发场景 |
|---|---|
| `coding` | 新增/修改应用逻辑、PDK 公共源码、ebus 消息、AT 命令、中间件、Kconfig/CMake |
| `device` | 引脚/pinmux/GPIO/I2C/SPI/UART/LCD/panel/摄像头/音频/传感器、`adb shell`、`device set_pid/set_sid` |
| `flash` | 烧录、刷机、下载固件到设备 |
| `run-log` | 抓日志、分析日志 |
| `review` | 代码审查 |
| `commit` | Git 提交 |
| `mcp` | 端侧 MCP 工具（`apps/arcs-mini/mcp-tools`） |
| `local-memory` | 项目本地记忆（`/local-memory`） |

优先级规则（`AGENTS.md` 原文要点）：用户点名 → 加载该 skill；未点名但语义命中 → 自动加载最相关的；
多阶段任务按工作流顺序叠加；**skill 里的流程/命令/路径优先于通用说明**；
skill 与仓库实际冲突时先说明原因，再按本地上下文继续。

`.claude/skills/<name>` 只是指向 `.agents/skills/<name>` 的软链接，不要维护两份。

## 10. 本仓（ling）额外补充的事实

以下几条**不在**固件仓手册里，是本机实测后写回本仓的，做固件时一并看：

| 事实 | 位置 |
|---|---|
| `adb devices` 空但 USB 节点在 → `ADB_LIBUSB=1` | [../development/flashing-and-recovery.md](../development/flashing-and-recovery.md) §0.5.1 |
| CH340 COM10 就是烧录口，可 `cskburn -c` 探测 | 同上 §0.5.2 |
| cskburn 后的复位是冷复位，要长按开机 | 同上 §0.5.3 |
| SRAM 只剩十几 KB，大缓冲必须 `__psram_bss__` | [conventions.md §2](conventions.md#2-内存预算sram-已经接近满) |
| BLE 自定义服务要在 BLE 就绪回调里注册（主任务里注册会挂） | [conventions.md §5.3](conventions.md#53-ble) |
| 单功能键拿不到"按下/松开"边沿，要从驱动回调分发 | [conventions.md §5.4](conventions.md#54-按键) |
