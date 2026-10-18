# 固件仓（arcs_mini）自带手册摘要

> 来源：官方上游仓 `https://cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini` 的 `AGENTS.md`、`README.MD`、
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

## 10. 文档仓额外补充的事实（不在固件仓手册里）

以下几条**不在**固件仓手册里，是本机实测后写回本仓的，做固件时一并看：

| 事实 | 位置 |
|---|---|
| `adb devices` 空但 USB 节点在 → `ADB_LIBUSB=1` | [../development/flashing-and-recovery.md](../development/flashing-and-recovery.md) §0.5.1 |
| CH340 COM10 就是烧录口，可 `cskburn -c` 探测 | 同上 §0.5.2 |
| cskburn 后的复位是冷复位，要长按开机 | 同上 §0.5.3 |
| SRAM 只剩十几 KB，大缓冲必须 `__psram_bss__` | [conventions.md §2](conventions.md#2-内存预算sram-已经接近满) |
| BLE 自定义服务要在 BLE 就绪回调里注册（主任务里注册会挂） | [conventions.md §5.3](conventions.md#53-ble) |
| 单功能键拿不到"按下/松开"边沿，要从驱动回调分发 | [conventions.md §5.4](conventions.md#54-按键) |

## 11. README.MD 摘要（工程结构 / 快速开始 / FAQ）

### 11.1 顶层目录职责

```
apps/        应用方案工程集合（arcs-mini = CP 业务，remote-ap = AP 算法）
arcs-sdk/    SDK 核心（HAL / 驱动 / 组件 / 第三方库 / 板型）
modules/     项目级第三方模块（ebus 消息、lschat 云端、lisaui）
res/         静态资源与 partition_table.json（每个板型一份）
src/         语音交互核心（category / framework / middleware / server / shell / system / utils）
tools/       adb、cskburn 等工具
build.sh / build.ps1   构建入口
```

`src/` 各层：`category`（品类差异实现，`comm` 为通用）/ `framework`（`voice_msg.*` 消息总线）/
`middleware`（硬件抽象与系统服务）/ `server`（云端通信与唤醒）/ `shell`（调试命令）/
`system`（`platform.c` 平台抽象、远程日志）/ `utils`。

### 11.2 FLASH 分区

分区表以 `res/<board>/partition_table.json` 为准（`flash_base` + `images[].addr/file`），
不存在全局固定表。mini3 的实际地址见 [conventions.md §3](conventions.md#3-分区与烧录地址mini3)。

### 11.3 两种烧录方式的定位

| 方式 | 适用 | 要点 |
|---|---|---|
| **ADB**（推荐） | 已有 boot 且 ADB 可用 | 仓库内置 `tools/adb/`；脚本自动让设备进 recovery、等 `BOOT-*`、推固件、重启；多设备按 `transport_id` 区分 |
| **cskburn 串口** | 首次烧录 / boot 损坏 | 需进 ROM 升级模式：**boot 引脚接地 + 复位**；boot 引脚与烧录串口复用，烧录前要悬空；连接 UART0（GPIOA2_RX0 / GPIOA3_TX0） |

README 里串口示例用 `-b 3000000`；本机实测 `921600` 稳定即可（CH340/COM10），更高速率要先确认适配器可靠。

### 11.4 FAQ（README 原文的四条，附本机经验）

| 问题 | 原文处置 | 本机补充 |
|---|---|---|
| 找不到工具链 | 检查 `NUCLEI_TOOLCHAIN_PATH` / `LISTENAI_TOOLS_PATH` | 先 `env.ps1` 一次，或手工指到 `~/.listenai/{gcc,listenai-tools}` |
| 编译失败 | `./build.sh -C` 清理重编 | `build*/` 目录删掉重建更彻底（Kconfig 缓存会残留） |
| ADB 连不上 | 查 USB → `adb devices` → `kill-server && start-server` | **`ADB_LIBUSB=1` 起 server**（见烧录手册 §0.5.1）；`adb devices` 空但 USB 节点在就是这一条 |
| 烧录后无法启动 | 查是否漏分区 → 看串口日志 → 重烧 boot | 冷复位要长按 3 秒；整包用 cskburn + `--verify-all` 更稳 |

## 12. 启动流程摘要（`doc/EVB_RUNTIME_FLOW.md`）

`arcs-evb` 与 `arcs-mini` 是同一套骨架的两份应用，流程可直接对照：

1. **上电/复位** → 启动代码初始化内存 → RTOS 起来 → `SYS_INIT` 分级初始化
   （消息系统通常在 `main()` 之前就绪，保证 `voice_msg_sub()` 可用）。
2. **`main()`**：打印版本 → 喂狗 → 订阅关键消息 → 按序初始化 `service_*`
   （led / volume / brightness / button / camera / display…）→（可选）`lisa_ui_init()`。
3. **主循环**：`while (1) { boot_watchdog_feed(); vTaskDelay(100ms); }`——业务全在事件里，不在循环里。

关键入口：`apps/<app>/main.c`、`src/framework/voice_msg.c`（消息总线）、
`apps/<app>/services/service_*.c`、`apps/<app>/voice_player*`、`src/server/lschat_server/`。

**运行方式是发布/订阅**：`voice_msg_pub(msg_id, data, len)` / `voice_msg_sub(msg_id, cb, user_data)`。
主业务链：WiFi 拿到 IP → `network_probe_start()` → `VOICE_MSG_SYSTEM_NETWORK_PROBE_SUCCESS` →
`voice_cloud_connect()` → `VOICE_MSG_CLOUD_CONNECTED` → IAT / TTS / finish 按 `VOICE_MSG_CLOUD_*` 分发；
播放器在平台 ready 后订阅 TTS/唤醒/WiFi 断开等消息。

**做固件功能时这条链路就是接线图**：新模块通常 = 初始化（`SYS_INIT` 或 `main()`）+ 订阅若干
`VOICE_MSG_*` + 自己的 UI screen；不要往主循环里塞轮询逻辑。

## 13. SDK 开发手册在哪

| 来源 | 位置 | 用途 |
|---|---|---|
| 在线文档（推荐） | <https://docs2.listenai.com/arcs-sdk/v0.1.0/zh/html/get_started.html> | 快速开始、组件、API |
| 仓库内中文源 | `arcs-sdk/docs/zh/`（`index.rst`、`get_started.rst`、`api_doc.md`、`hardware/`、`labs/`） | 与在线文档同源；Sphinx + Doxygen 构建，`arcs-sdk/docs/README.md` 有构建说明 |
| SDK README | `arcs-sdk/README.md` | 版本、目录、构建方式 |
| 模块文档 | `modules/ebus/readme.md`、`modules/lschat/README.MD` | 消息总线、云端会话 |
| 设备侧小应用契约 | `docs/miniapp.md`（固件仓内） | 小程序能拿到什么能力（本仓摘要在 [`../development/miniapp-runtime.md`](../development/miniapp-runtime.md)） |
| API 手册（生成） | `arcs-sdk/docs/doxygen/` | 头文件注释直接生成，查函数签名最快 |

**查资料顺序**：在线文档 → `arcs-sdk/docs/zh/*.rst` → 头文件注释（`arcs-sdk/**/include`）→ 本仓手册。
