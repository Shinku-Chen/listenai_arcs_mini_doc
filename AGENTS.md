# AGENTS.md — AI 编程助手入口

本仓库（`github.com/Shinku-Chen/ling`）是 **Arcs-mini3 的开发手册仓与模板仓**，不是产品代码仓。
先读本文件，再按「任务路由」读对应文档。

## 仓库定位（先搞清自己在哪个仓干活）

| 我要开发 | 在哪个仓库 | 本仓的角色 |
|---|---|---|
| **小程序（Lua）** | **本仓的功能分支**（`feat/*`，从 `main` 切） | 提供模板、脚本、编码规范 |
| **固件（C / LVGL / BLE）** | `https://cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini` | 提供固件级规范与流程 `docs/firmware/` |

- `main` 只放**模板与 demo**（当前只有一个计数器小程序），不要在 `main` 上做业务。
- 固件功能文档（协议、时序、能力表）写在固件仓的 `docs/`；通用规范留在本仓，两边不重复。

## 目标与硬事实

- 目标设备：**Arcs-mini3**（`arcs_mini3`，LS2663）。固件构建必须 `-DBOARD=arcs_mini3`。
  - 同系列的 **`arcs_mini` 是另一块板**（LS2684），引脚与 boot/ap 镜像都不同：**刷错会黑屏 + USB 不识别 + 反复重启**（实测过）。
- 固件 ≥ `3.0.0` 才有小应用能力；设备实测 `3.0.2`，当前 `app.api_version = 4`。
- 小程序是**裸 Lua 文本**，由云端下发或 adb 上传，只在 PSRAM 里跑，源码不落盘。
- 单文件约束：运行时没有 `require` / `dofile` / `load`，多文件开发必须经 `tools/build.ps1` 合并成 `dist/app.lua`。
- 源码上限 65,536 字节；单实例 Lua 堆 393,216 字节；`screen` 每帧 ≤128 矩形、≤8 段文字、每段 ≤63 字节。
- 音频：官方固件的小应用**没有**播放接口；需要固件带 `CONFIG_MINIAPP_AUDIO`（补丁存档在固件仓 `docs/patches/`）。

## 项目与安全基线

- Lua 沙箱内**不存在** `pcall` / `xpcall` / `setmetatable` / `collectgarbage` / `load*` / `print` / `io` / `os` / `package` / `coroutine` / `debug` / `require`。不要写"加个 pcall 兜底"。
- 参数非法或超预算会**直接终止小应用**，没有异常兜底。所有外部输入都要显式判空判类型。
- 硬件事实只有一个真相源：`docs/hardware/`。引脚、外设、内存上限不在这里定义时，**问用户，不要猜**。
- 不把登录凭证、Product Secret、API Key、设备 SID 写进仓库、日志或提交信息。
- 不擅自升级/刷写设备固件；刷写按 `docs/firmware/process.md` 走，并先说明写哪个分区、哪个地址、目标序列号。
- 文件删除走系统回收站，不用 `rm -rf` / `git clean -fd`。

## 任务路由（编辑前先读）

| 任务 | 必读 |
|---|---|
| 写/改小程序代码 | `docs/development/miniapp-runtime.md`、`docs/development/coding-conventions.md` |
| 跑模拟器、抓截图、调试界面 | `docs/development/dev-loop.md` |
| 上传到设备 / 拉回源码 / 看日志 | `docs/development/dev-loop.md` |
| 环境从零搭起（SDK、adb、ling CLI） | `docs/development/environment-setup.md` |
| 云端下发 / 上架 / 发布相关 | `docs/development/cloud-distribution.md`（含明确的边界与未知项） |
| **开发固件（规范 / 流程 / 内存 / 板型）** | `docs/firmware/README.md` → `conventions.md`、`process.md` |
| 烧录固件、刷分区、救砖、恢复出厂 | `docs/development/flashing-and-recovery.md` |
| 设备黑屏 / ADB 掉线 / 反复重启 | `docs/reference/device-behavior-log.md`（先排查休眠，再查 USB 链路） |
| 涉及引脚、屏幕、按键、内存、SoC 能力 | `docs/hardware/board-arcs-mini.md`（`arcs_mini` / `arcs_mini3` 是两块不同的板） |
| 想知道外部权威资料在哪 | `docs/reference/README.md` |
| AI 协作方式与交付要求 | `docs/development/ai-guide.md` |

## 必需验证与交付

改动 `src/`、`tools/` 后，提交前至少跑一次：

```powershell
.\tools\validate.ps1
```

它做三件事：合并源码 → 静态检查（体积/禁用 API/必需回调）→ 用官方模拟器 headless 实跑一次并出图。
任何一步失败都不能宣称完成。交付汇报固定四字段：

```text
Build: PASS / FAIL / NOT RUN
Static checks: PASS / FAIL / NOT RUN
Simulator run: PASS / FAIL / NOT RUN
Unverified: 还需真机/人工确认的项（例如实际按键手感、屏幕观感、真机内存）
```

模拟器通过**不等于**真机通过。固件类改动按 `docs/firmware/process.md §4` 的真机验收清单执行
（构建零警告、烧录、逐项验收、既有能力回归、长跑、断电重启）。

## 变更记录

- 2026-10-18：仓库重新定位为**手册 + 模板仓**：`main` 只留一个计数器 demo 小程序，
  固件源码移出本仓（迁到固件仓 `arcs_mini` 的 `feat/intercom` 分支），
  新增 `docs/firmware/` 固件级规范与流程。
- 2026-10-02：建立仓库文档骨架与 Lua 小应用基础框架（多文件源码 + 合并/校验/上传工具），依据 LingClaw-SDK 0.1.0 与 Arcs-mini 固件 3.0.2。
- 2026-10-02：补充烧录/恢复手册、设备行为实测记录（黑屏=休眠、ADB 掉线、sync 通道故障）。
- 2026-10-02：确认目标板是 `arcs_mini3`（LS2663）而非 `arcs_mini`（LS2684），之前的黑屏/USB 故障均源于刷错板型。
