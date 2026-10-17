# 固件级开发规范与流程

本目录是**固件开发的规范与流程手册**。固件代码本身不在本仓：

| 内容 | 位置 |
|---|---|
| 固件源码 / 分支 / 构建产物 | `https://cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini`（公开上游仓） |
| 固件功能文档（例如对讲机线协议） | 固件仓内的 `docs/` |
| 小程序（Lua）开发 | 本仓 `src/` + `docs/development/` |

**为什么规范放这里**：固件仓是上游 fork，`AGENTS.md` 之类面向 AI 的个人规则不该塞进去；
本仓是个人开发规范的家，固件仓的会话可以按 `docs/firmware/*` 执行。

## 两条线的分工

| | 小程序（本仓） | 固件（arcs_mini） |
|---|---|---|
| 运行形态 | 裸 Lua，云端下发或 adb 推送，只在 PSRAM 里跑 | native C + LVGL，编进镜像 |
| 改一次的成本 | 秒级（`build.ps1` → `upload.ps1`） | 分钟级（编译 + 烧录 + 重启） |
| 能碰硬件 | 只有运行时给的能力表 | 全部（BLE / 音频 / GPIO / 摄像头） |
| 该放哪 | 纯 UI、联网取数、可热更的业务 | 需要新硬件能力、实时性、BLE/音频链路 |

判断口径：**需要新增运行时能力或直连外设 → 固件；只是用现成能力 → 小程序。**
对讲机之所以是固件：需要 BLE 外设 + 自定义 GATT 服务，沙箱拿不到。

## 必读顺序

1. [conventions.md](conventions.md) —— 硬约束：板型、内存预算、分区、构建参数、代码约定
2. [process.md](process.md) —— 流程：分支 → 构建 → 烧录 → 真机验收 → 提交 → 回滚
3. [architecture.md](architecture.md) —— 架构：目录地图、启动流程（SYS_INIT → main → 事件循环）、
   `voice_msg` 消息总线主链路、调试入口、Kconfig
4. [pitfalls.md](pitfalls.md) —— 踩坑集（10 条真机实测：SRAM 溢出、ADB_LIBUSB、冷复位、GATT 注册时机…）
5. [arcs-mini-repo.md](arcs-mini-repo.md) —— **固件仓自带手册的摘要**：仓库结构、环境、构建、烧录三模式、
   cskburn + 开发 Boot 闭环、日志抓取、崩溃分析、提交规范、SDK 自带 skills
6. [upstream-mirror.md](upstream-mirror.md) —— 上游镜像仓：快照式同步、剔除了什么、为什么
   `CONFIG_MINIAPP=n`、怎么手动/Actions 同步、大推送教训
3. [../development/flashing-and-recovery.md](../development/flashing-and-recovery.md) —— 烧录/救砖细节
4. [../hardware/board-arcs-mini.md](../hardware/board-arcs-mini.md) —— 板级事实（引脚、外设）

## 首次上手 5 步

装工具链（[arcs-mini-repo.md §3](arcs-mini-repo.md#3-环境)）→ 构建（[process.md §2](process.md#2-构建每次改完都跑)）
→ 烧录（[process.md §3](process.md#3-烧录)）→ 抓日志（[arcs-mini-repo.md §6](arcs-mini-repo.md#6-日志)）
→ 真机验收（[process.md §4](process.md#4-真机验收)）。

## 一句话红线

- 构建必须 `-DBOARD=arcs_mini3`；`arcs_mini` 是另一块板，**刷错会黑屏 + USB 不识别 + 反复重启**。
- 构建通过 ≠ 真机通过：BLE、按键、屏幕时序、音频都只有真机能确认。
- 不擅自升级/刷写固件；刷写前明确写哪个分区、哪个地址、目标序列号。
