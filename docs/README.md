# 文档索引

按"我想做什么"找文档。每份文档只有一个职责，事实不重复写第二遍。

| 我想…… | 读这份 |
|---|---|
| 知道这块板子是什么、能干什么 | [hardware/board-arcs-mini.md](hardware/board-arcs-mini.md) |
| 查引脚、外设、内存/flash 上限 | [hardware/board-arcs-mini.md](hardware/board-arcs-mini.md) |
| 搞清小应用能调用什么、有什么限制 | [development/miniapp-runtime.md](development/miniapp-runtime.md) |
| 写第一份 Lua、知道代码该怎么写 | [development/coding-conventions.md](development/coding-conventions.md) |
| 搭环境（模拟器 / adb / ling CLI） | [development/environment-setup.md](development/environment-setup.md) |
| 跑模拟器、上传设备、抓日志截图 | [development/dev-loop.md](development/dev-loop.md) |
| 了解云端下发是什么、能不能上架 | [development/cloud-distribution.md](development/cloud-distribution.md) |
| **烧录固件 / 救砖 / 恢复出厂** | [development/flashing-and-recovery.md](development/flashing-and-recovery.md) |
| **开发固件（规范 / 流程 / 内存与板型红线）** | [firmware/README.md](firmware/README.md) → `conventions.md`、`process.md` |
| **固件仓自带的规则（构建/烧录/日志/skills）** | [firmware/arcs-mini-repo.md](firmware/arcs-mini-repo.md) |
| **设备黑屏、ADB 掉线，怎么判断** | [reference/device-behavior-log.md](reference/device-behavior-log.md) |
| 让 AI 在这个仓库里正确干活 | [../AGENTS.md](../AGENTS.md)、[development/ai-guide.md](development/ai-guide.md) |
| 找官方原始资料 | [reference/README.md](reference/README.md) |

## 文档规则

- 事实只有一个真相源：硬件规格在 `hardware/`，运行时契约在 `development/miniapp-runtime.md`，
  外部资料链接在 `reference/README.md`。其它文档引用它们，不复制正文。
- 文档只写"结论 + 依据"。改写事实时必须同步它的来源链接或源码路径。
- 不确定的事写"未核实"，不要写猜测当结论。
