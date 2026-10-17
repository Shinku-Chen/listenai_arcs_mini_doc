# 固件硬约束与代码约定

这里的每一条都是**实测结论**，不是风格偏好。违反其中任何一条，代价通常是"设备黑屏/不识别"或"运行时随机崩"。

## 1. 板型：只有 `arcs_mini3`

| 项 | `arcs_mini`（LS2684） | **`arcs_mini3`（LS2663，本工作区）** |
|---|---|---|
| 构建 | `-DBOARD=arcs_mini` | **`-DBOARD=arcs_mini3`** |
| 资源目录 | `res/arcs-mini/` | **`res/arcs-mini3/`** |
| boot / ap 镜像 | 一套 | **另一套**（不通用） |
| 刷错的后果 | — | **黑屏 + USB 不识别 + 反复重启**（已实测，排查了一整天） |

`arcs_mini3.conf` 还会覆盖 PSRAM 分区（AP 3 MB @0x28000000，CP 5 MB @0x28300000），改板型等于改内存布局。

## 2. 内存预算：SRAM 已经接近满

实测（`-DBOARD=arcs_mini3`，含对讲机功能）：

| 区域 | 用量 | 结论 |
|---|---|---|
| FLASH | 3.1 MB / 8 MB（36.7%） | 宽裕 |
| PSRAM | 5.17 MB / 5 MB（98.7%） | 几乎满，新增大缓冲要算账 |
| **SRAM** | **157 KB / 168 KB（91.3%）** | 只剩 ~11 KB，**新增静态变量必须放 PSRAM** |

做法（源自 `src/middleware/battery/battery.c` 等既有代码）：

```c
#include "sysutils.h"
static uint8_t big_buf[4096] __psram_bss__;   /* 大缓冲放 PSRAM */
```

经验值：AP SRAM 只剩几 KB 时，链接会报
`region 'SRAM' overflowed by N bytes` 或 `section .noinit will not fit in region SRAM`。
看到这两个错误不要缩功能，先把静态缓冲搬到 `__psram_bss__`。

堆分配用 `pvPortMalloc` / `vPortFree`（FreeRTOS 堆是线程安全的），不要用 `lv_mem_alloc`
跨线程分配。

## 3. 分区与烧录地址（mini3）

| 分区 | 地址 | 文件 |
|---|---|---|
| boot | `0x000000` | `res/arcs-mini3/boot.bin` |
| ap | `0x040000` | `res/arcs-mini3/ap.bin` |
| tone | `0x100000` | `res/arcs-mini/tone.bin` |
| wake_word | `0x200000` | `res/arcs-mini/wake_word.bin` |
| emoji | `0x380000` | `res/arcs-mini/emoji.bin` |
| respak | `0x440000` | `res/arcs-mini/respak.bin` |
| **app** | **`0x600000`** | **`build*/arcs-mini.bin`** |
| ota | `0xA00000` | 暂存区 5 MiB |
| kv | `0xF00000` | 1 MiB |

真相源：`res/arcs-mini3/partition_table.json`。`adb push` 的远端路径要**去掉 `0x` 与前导零**：
`0x600000` → `/RAW/NAND/600000`。

## 4. 构建

```powershell
cd <固件仓根>
$env:LISTENAI_TOOLS_PATH="C:\Users\<you>\.listenai\listenai-tools"
$env:NUCLEI_TOOLCHAIN_PATH="C:\Users\<you>\.listenai\gcc"
$env:ARCS_BASE="<固件仓根>/arcs-sdk"
& "$env:LISTENAI_TOOLS_PATH\cmake\bin\cmake.exe" -B build-<feature> -G Ninja -S apps/arcs-mini `
    -D CMAKE_MAKE_PROGRAM="$env:LISTENAI_TOOLS_PATH\ninja\ninja.exe" `
    -DBOARD=arcs_mini3 -DBOARD_SEARCH_PATH="<固件仓根>/boards"
& "$env:LISTENAI_TOOLS_PATH\ninja\ninja.exe" -C build-<feature> -j 12
```

⚠️ **不要用 `build.ps1`**：它 `$ErrorActionPreference="Stop"`，而 CMake 会把 Kconfig 的
`warning: default on the choice symbol … will have no effect` 写到 stderr，PowerShell 会
把它当成失败中断构建（配置其实成功了）。直接调 cmake/ninja 行为完全等价。

每个构建目录一个名字（`build-<feature>`），便于回滚与对比；`.gitignore` 已忽略 `build*/`。

## 5. 代码约定

### 5.1 开关与注册

- 每个新功能必须有自己的 `Kconfig` 开关（默认 `n`），在 `apps/arcs-mini/prj.conf` 里显式打开；
  这样上游 MR 时能被 reviewer 一眼关掉。
- 新模块放在 `apps/arcs-mini/<feature>/`，`CMakeLists.txt` 用 `listenai_library_named` +
  `listenai_library_sources`，并在 `apps/arcs-mini/CMakeLists.txt` / `Kconfig` 里挂一行。
- 初始化点在 `apps/arcs-mini/main.c`（UI 相关）或 `src/system/platform.c`（BLE/WiFi 相关），
  用 `#ifdef CONFIG_<FEATURE>` 包住，保持关掉时零代价。

### 5.2 UI（LVGL）

- **不要改 `apps-ui/apps/llm/**`**（助手页 / 扫码配网 / 设置页）。新界面做独立 screen，
  用 `lisa_ui_nav_scr_add()` + `lisa_ui_nav_scr_nav_to(id)` 进出，`unique_id` 自己挑一个未占用的（如 90/91）。
- 中文字体用 `lv_font_chinese_16`（`lisa_ui_fonts.h`），不要自带字库。
- **LVGL 不是线程安全的**：从非 LVGL 任务（BT 任务、shell）改界面必须
  `lv_async_call(cb, arg)` 投递，参数放堆上，在回调里释放。
- 画布 240×240；助手页/引导页的返回路径要留着（`lisa_ui_nav_scr_nav_default()`）。

### 5.3 BLE

- 固件已经初始化蓝牙（`platform.c`: `lisa_bluetooth_init(NULL)` + BLE 配网），**不要重复初始化**。
- SDK 的连接/断开/配对回调是**单槽位**（`lisa_ble_register_conn_cb` 等），直接再注册会顶掉配网；
  新功能要通过 `src/middleware/ble/app_ble_common.c` 的既有回调**转发**进去。
- 自定义 GATT 服务用 `ble_gatt_user_register` + `ble_gatt_db_svc_add`（支持 128-bit UUID），
  通知用 `ble_gatt_srv_event_send(..., BLE_GATT_NOTIFY, hdl, ...)`，且必须等 `cb_event_sent`
  回来再发下一帧（协议栈不支持并发发送）。
- **握手/推送要等 CCCD 打开**：手机没订阅时 notify 是发不出去的（对讲机踩过这个坑）。
- 广播包受 31 字节限制：`firmware` 里广播包已被 flags + 名字 + 厂商数据占满，
  128-bit UUID 之类要放**扫描响应**（安卓会把 adv 与 scan rsp 合并解析）。

### 5.4 按键

- 主功能键的消息总线只放行点击序列与 `LONG_HOLD`；需要"按下/松开"边沿（按住说话、
  长按录音）必须从 `apps/arcs-mini/services/service_button.c` 的**驱动回调**分发原始事件，
  不要放宽共享过滤器（会影响助手页/配网/关机逻辑）。
- 长按 → 关机 是系统行为。任何"按住说话"类功能必须在前台时**消费掉 `LONG_HOLD`**，
  否则用户说话时设备直接关机。

### 5.5 日志与调试

- 日志统一 `LISA_LOGI/W/E(TAG, ...)`，`TAG` 用 `"模块.子模块"` 风格（如 `ic.link`）。
- 需要现场验证的能力，做一个 shell 命令（`SHELL_EXPORT_CMD`），例如
  `radio show|hide`、`ic show|hide|stat|text`；比反复烧录快得多。
- 状态类数据用 counters 暴露（收/发/丢/重同步次数），出问题时有数字可看。

## 6. 禁止

- 沙箱外的 C 侧同样没有"异常兜底"：所有外部输入（BLE 写入、HTTP、KV、时间）都要判空判长度。
- 不要关闭/改写既有能力（配网、OTA、闹钟、音量）来给新功能腾地方。
- 不要把凭证（Product Secret / API Key / 设备 SID）写进源码、日志或提交信息。
