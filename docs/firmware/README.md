# 固件级开发规范与流程

本目录是**固件开发的规范与流程手册**。固件代码本身不在本仓：

| 内容 | 位置 |
|---|---|
| 固件源码 / 分支 / 构建产物 | `https://cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini`（clone 后 `origin` 指上游、`mine` 指我的 fork） |
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
3. [../development/flashing-and-recovery.md](../development/flashing-and-recovery.md) —— 烧录/救砖细节
4. [../hardware/board-arcs-mini.md](../hardware/board-arcs-mini.md) —— 板级事实（引脚、外设）

## 一句话红线

- 构建必须 `-DBOARD=arcs_mini3`；`arcs_mini` 是另一块板，**刷错会黑屏 + USB 不识别 + 反复重启**。
- 构建通过 ≠ 真机通过：BLE、按键、屏幕时序、音频都只有真机能确认。
- 不擅自升级/刷写固件；刷写前明确写哪个分区、哪个地址、目标序列号。
