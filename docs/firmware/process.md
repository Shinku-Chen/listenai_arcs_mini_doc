# 固件开发流程

一个功能从分支到真机验收的固定动作。每一步都有**验收标准**，没过就不要进入下一步。

## 0. 开工前

```bash
cd <固件仓>
git status --short --branch     # 工作区必须干净
git fetch --all --prune
git switch -c feat/<feature>    # 语义分支，别在 feat/* 或 master 上叠活
```

- 基线：默认从 `feat/leo-radio`（网络电台功能固件主线）或 `master`（上游原样）切。
- 一个分支一件事；混入无关修复会让真机验收无法二分。

## 1. 设计（先写下来）

改动前先确定三件事，写进分支的第一条 commit 或仓内文档：

1. **开关**：`CONFIG_<FEATURE>`，默认 `n`。
2. **接线点**：初始化在哪（`main.c` / `platform.c`）、UI 用哪个 nav id、BLE 回调从哪转发。
3. **内存账**：需要多大缓冲、放 SRAM 还是 PSRAM；SRAM 只剩十几 KB，先算再写。

## 2. 构建（每次改完都跑）

见 [conventions.md §4](conventions.md#4-构建)。验收标准：

- 编译零错误；**自己的文件零警告**（既有的 `_times` 之类 libc 警告可以忽略）。
- 链接通过，且看一次内存账：`PSRAM / FLASH / SRAM` 三段百分比要有记录。

失败时的常见错误与处置：

| 报错 | 处置 |
|---|---|
| `region 'SRAM' overflowed by N bytes` | 静态缓冲搬到 `__psram_bss__` |
| `Cannot find source file: …/arcs-sdk/samples/…` | SDK 的 `samples/` 被裁了（本仓历史原因），把缺的样例目录补回来 |
| `undefined reference to lv_…` | 检查是否漏了 `listenai_include_directories` / 组件依赖 |
| CMake 配置成功但脚本报失败 | `build.ps1` 的 PowerShell 陷阱，改用 cmake/ninja 直调 |

## 3. 烧录

默认 **ADB recovery + app 模式**（只写 `0x600000`，不动 boot/ap/资源）：

```powershell
# 设备进 recovery：按住【功能键】不放 → 短按【RST】→ 松开【功能键】
# adb devices 里应出现 BOOT-*
powershell -ExecutionPolicy Bypass -File adb_download.ps1 -S res/arcs-mini3 -B build-<feature> app
```

- 烧录前必须确认：**哪个分区、哪个地址、目标序列号**（多设备时永远 `-s <serial>`）。
- 只有换了 boot/ap/资源才需要整包，见 [../development/flashing-and-recovery.md](../development/flashing-and-recovery.md)。
- 设备起不来（不进 ADB、USB 不识别）→ 串口 cskburn 兜底，不要反复试 ADB。

## 4. 真机验收

按功能列一份**可勾选**的清单，逐条跑：

| 类别 | 怎么验 | 通过标准 |
|---|---|---|
| 启动 | `adb logcat`/串口日志，`adb shell version` | 没有 panic/重启循环，`TAG` 日志按预期出现 |
| 界面 | `adb shell shot <start> <len>` 抓屏，或拍照 | 文案/布局/颜色符合设计，中文字形完整 |
| 状态 | 自建 shell 命令的 counters（如 `ic stat`） | 收/发/丢/重同步计数符合预期，没有静默失败 |
| 交互 | 物理按键：单击/双击/长按 | 每种动作都触发且**不误触**系统行为（关机/配网） |
| 既有能力回归 | 扫码配网、助手对话、音量、OTA 入口 | 全部仍可用（新功能最常见的破坏对象） |
| 长跑 | 让主链路跑 ≥10 分钟 | 无内存泄漏/OOM、无自动断连、无自动复位 |
| 断电重启 | 拔电/复位后再看 | 状态恢复符合预期，没有卡在引导页 |

能用主机侧工具验证的**先用工具**，别拿真机当调试器。例：BLE 功能可以直接用
`tools/intercom_peer.py`（固件仓里）在 PC 上跑完整协议闭环，失败信息比手机 App 清楚。

## 5. 提交

```bash
git add -A
git commit -F - <<'MSG'
feat(scope): 一句话说清交付了什么

- 关键改动 1
- 关键改动 2
- 构建实测（-DBOARD=arcs_mini3）：FLASH x% / PSRAM y% / SRAM z%
MSG
git push -u mine feat/<feature>
```

- commit 首行 `type(scope): 简述`，≤50 字符，不加句号；正文写"为什么"和实测数据。
- **commit 里要带构建数据**：内存百分比是后续判断"还能不能加功能"的唯一依据。
- 提上游 MR（`origin` = `cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini`）前先自己
  跑一遍验收清单，并把边界写进 MR 描述；没验的项要明说"未验证"。

## 6. 回滚

| 场景 | 做法 |
|---|---|
| 只想退回上一个应用版本 | 切回上一个 `build-*` 产物，再烧 `app` 模式 |
| 想退回官方原厂固件 | 用官方 `.lpk`（下载页见 [../reference/README.md](../reference/README.md)）整包烧 |
| 设备卡在 recovery / 反复重启 | 进 recovery 重烧 app；仍循环 → 串口整体恢复 |
| boot 被刷坏（USB 完全不识别） | 串口 cskburn 重写 `0x0` boot + `0x40000` ap + `0x600000` app |

## 7. 文档

- 功能级契约（协议、时序、能力表）写在**固件仓**的 `docs/` 里，跟代码同仓演进。
- 通用规范（本文、conventions）留在本仓，固件仓不复制，避免两份漂移。
