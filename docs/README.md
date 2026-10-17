# 文档索引

按"我想做什么"找文档。每份文档只有一个职责，事实不重复写第二遍。

## 两条开发线

| | 小程序（Lua） | 固件（C / LVGL） |
|---|---|---|
| 代码在哪 | **本仓的分支**（每个功能一条 `feat/*`） | `cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini` |
| 入口 | [development/miniapp-runtime.md](development/miniapp-runtime.md) → [coding-conventions](development/coding-conventions.md) → [dev-loop](development/dev-loop.md) | [firmware/README.md](firmware/README.md) → [conventions](firmware/conventions.md) → [process](firmware/process.md) |
| 项目自带规则 | LingClaw SDK（模拟器 + API 文档） | [firmware/arcs-mini-repo.md](firmware/arcs-mini-repo.md)（固件仓 AGENTS.md / skills / README 摘要） |
| 改一次的成本 | 秒级（改完全量推） | 分钟级（编译 + 烧录 + 重启） |
| 该选谁 | 纯 UI、联网取数、可热更的业务 | 需要新硬件能力、实时性、BLE/音频链路 |

判断口径：**需要新增运行时能力或直连外设 → 固件；只是用现成能力 → 小程序。**

| 我想…… | 读这份 |
|---|---|
| 知道这块板子是什么、能干什么 | [hardware/board-arcs-mini.md](hardware/board-arcs-mini.md) |
| 查引脚、外设、内存/flash 上限 | [hardware/board-arcs-mini.md](hardware/board-arcs-mini.md)（mini）／[hardware/board-arcs-mini3.md](hardware/board-arcs-mini3.md)（**mini3，当前设备**） |
| 搞清小应用能调用什么、有什么限制 | [development/miniapp-runtime.md](development/miniapp-runtime.md) |
| 写第一份 Lua、知道代码该怎么写 | [development/coding-conventions.md](development/coding-conventions.md) |
| 搭环境（模拟器 / adb / ling CLI） | [development/environment-setup.md](development/environment-setup.md) |
| 跑模拟器、上传设备、抓日志截图 | [development/dev-loop.md](development/dev-loop.md) |
| 了解云端下发是什么、能不能上架 | [development/cloud-distribution.md](development/cloud-distribution.md) |
| **烧录固件 / 救砖 / 恢复出厂** | [development/flashing-and-recovery.md](development/flashing-and-recovery.md) |
| **开发固件（规范 / 流程 / 内存与板型红线）** | [firmware/README.md](firmware/README.md) → `conventions.md`、`process.md` |
| **固件仓自带的规则（构建/烧录/日志/skills）** | [firmware/arcs-mini-repo.md](firmware/arcs-mini-repo.md) |
| **固件架构 / 踩坑 / 上游镜像** | [firmware/architecture.md](firmware/architecture.md)、[pitfalls.md](firmware/pitfalls.md)、[upstream-mirror.md](firmware/upstream-mirror.md) |
| **设备黑屏、ADB 掉线，怎么判断** | [reference/device-behavior-log.md](reference/device-behavior-log.md) |
| 让 AI 在这个仓库里正确干活 | [../AGENTS.md](../AGENTS.md)、[development/ai-guide.md](development/ai-guide.md) |
| 找官方原始资料 | [reference/README.md](reference/README.md) |

## 文档规则

- 事实只有一个真相源：硬件规格在 `hardware/`，运行时契约在 `development/miniapp-runtime.md`，
  外部资料链接在 `reference/README.md`。其它文档引用它们，不复制正文。
- 文档只写"结论 + 依据"。改写事实时必须同步它的来源链接或源码路径。
- 不确定的事写"未核实"，不要写猜测当结论。
