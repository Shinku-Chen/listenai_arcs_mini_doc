# 固件踩坑集（都是真机实测，不是推测）

## 1. 构建：`build.ps1` 被 PowerShell 判成失败

**现象**：CMake 输出 `-- Configuring done` 后脚本报错退出（exit 1），什么都没编。

**原因**：CMake 会把 Kconfig 的警告 `warning: default on the choice symbol APP_USB_ROLE_DRP … will have no effect`
写到 **stderr**；`build.ps1` 顶部有 `$ErrorActionPreference = "Stop"`，PowerShell 把
NativeCommandError 当致命错误。

**处置**：直接调 cmake + ninja（行为等价）：

```powershell
$env:LISTENAI_TOOLS_PATH="C:\Users\<you>\.listenai\listenai-tools"
$env:NUCLEI_TOOLCHAIN_PATH="C:\Users\<you>\.listenai\gcc"
$env:ARCS_BASE="<repo>/arcs-sdk"
& "$env:LISTENAI_TOOLS_PATH\cmake\bin\cmake.exe" -B build-x -G Ninja -S apps/arcs-mini `
    -D CMAKE_MAKE_PROGRAM="$env:LISTENAI_TOOLS_PATH\ninja\ninja.exe" `
    -DBOARD=arcs_mini3 -DBOARD_SEARCH_PATH="<repo>/boards"
& "$env:LISTENAI_TOOLS_PATH\ninja\ninja.exe" -C build-x -j 12
```

## 2. SRAM 只剩十几 KB：`region 'SRAM' overflowed`

**实测**（`arcs_mini3`，含对讲机功能）：FLASH 3.1 MB/8 MB（37%）、PSRAM 5.17 MB/5 MB（98.7%）、
**SRAM 157 KB/168 KB（91.3%）**。

新增静态大缓冲必然撞这个错：`region 'SRAM' overflowed by N bytes` /
`section .noinit will not fit in region SRAM`。

**处置**：大缓冲搬到 PSRAM——

```c
#include "sysutils.h"
static uint8_t big_buf[4096] __psram_bss__;
```

堆分配用 `pvPortMalloc` / `vPortFree`（FreeRTOS 堆线程安全）。不要用 `lv_mem_alloc` 跨线程分配。

## 3. `adb devices` 空，但 USB 节点在

**现象**：`Get-PnpDevice` 能看到 `USB\VID_0483&PID_0ADB\<chip-id>`（Status OK），
ADB 接口绑的是 **inbox WinUSB**（Service=WINUSB），但 `adb devices` 一直空。

**原因**：Google adb 默认后端按设备接口 GUID 找设备；inbox WinUSB 没带 ADB 的 GUID。

**处置**（不需要管理员、不改驱动）：

```powershell
$env:ADB_LIBUSB=1
adb start-server      # 后端在 server 里，起一次后续普通 adb 命令都能用
adb devices -l        # 6d7b101a252fcaa5 device product:arcs_mini3
```

## 4. cskburn 之后黑屏、USB 消失

**原因**：cskburn 写完 `Resetting...` 是**冷复位**，AON 里的热启动意图位被清掉，
boot 不拉 USB、屏幕不亮。看起来像刷砖，其实只差一次长按。

**处置**：长按功能键 3 秒。**软复位**（`adb shell reboot` / `adb shell recovery` 之后）不受影响。

## 5. BLE 自定义 GATT 服务不能在主任务里注册

**现象**：新加的 BLE 服务代码编译通过，真机**开机即黑屏 + USB 完全消失**（adbd 也没起来）。

**原因**：`ic_app_init()`（主任务）里直接 `ble_gatt_user_register()`，此时协议栈未就绪 → 挂住。

**处置**：注册放到 BLE 初始化完成回调里（该回调由 **BT 任务**调用）：

```c
static void ble_ready_cb(uint16_t status) {
    if (status == 0) { ic_link_init(); }   /* 在这里注册 GATT 服务 */
}
lisa_bluetooth_init(ble_ready_cb);          /* platform.c */
```

## 6. 主功能键拿不到"按下 / 松开"边沿

**现象**：想做"按住说话 / 长按录音"，但 `VOICE_MSG_BUTTON_CHANGE` 只给 `CLICK…CLICK / LONG_HOLD`。

**原因**：`apps/arcs-mini/services/service_button.c` 里对主功能键做了过滤
（`service_button_power_key_accepts_action`），只放行点击序列与 `LONG_HOLD`。

**处置**：不要放宽共享过滤器（会影响助手页、配网、关机）。在**驱动回调**里直接分发原始边沿：

```c
static void btn_event_callback(lisa_btn_event_t event, uint8_t btn_id, void *user)
{
#ifdef CONFIG_INTERCOM
    ic_app_on_raw_button(event, btn_id);    /* 自己用按下/松开 */
#endif
    publish_button_event(btn_id, event, true);
}
```

配套要求：任何"按住"类功能在前台时必须**消费掉 `LONG_HOLD`**，否则用户说话时设备直接关机
（长按 = 关机是系统行为）。

## 7. BLE 握手要等 CCCD 打开

手机没订阅 notify 时，设备发出去的帧**全部会被丢掉**（发送环返回失败）。
握手（hello/status）必须放在 `CCCD 由关变开`的时刻，不能放在连接建立那一刻。

## 8. 广播包只有 31 字节

广播包已被 `flags + 名字 + 厂商数据` 占满（BLE 配网小程序依赖厂商数据）。
新增 128-bit 服务 UUID 之类要放**扫描响应**（`lisa_bt_get_scan_rsp_data` 是 weak 可覆盖），
安卓侧会把 adv 与 scan response 合并解析。

## 9. 串口抓日志：cskburn 之后要等一下

cskburn 烧完立刻开串口，可能抓到空文件或乱码——串口还没释放稳定。**先 sleep 3~5 秒**。

## 10. 设备"黑屏 + ADB 掉线"先怀疑休眠

空闲 30 s 降亮度、5 min hibernate（`home_enter_hibernate` 会挂起 USB 与 LVGL），
表现就是黑屏 + ADB 不应答 + 无日志。一次按键即可唤醒；跑小应用时固件会抑制休眠。

## 11. 用 PowerShell 改 `prj.conf` 会把文件转成 GBK

**现象**：镜像仓 `master` 建好后 `cmake` 直接失败：

```text
Malformed utf-8 in 'apps/arcs-mini/prj.conf'
Problematic data: b'ç½'
kconfiglib.KconfigError  → Kconfig parse failed
```

**原因**：`prj.conf` 是 **UTF-8（含中文注释）**。用 PowerShell 的
`Set-Content` / `Out-File` / `>` 写入时，5.1 默认按**系统 ANSI（zh-CN = GBK）**编码落盘，
中文注释变成非法 UTF-8，kconfiglib 直接拒绝解析。

**处置**：改这个文件必须按字节读写：

```powershell
$enc  = New-Object System.Text.UTF8Encoding($false)
$text = $enc.GetString([System.IO.File]::ReadAllBytes($prj))
$text = [regex]::Replace($text, '(?m)^CONFIG_MINIAPP=.*$', 'CONFIG_MINIAPP=n')
[System.IO.File]::WriteAllText($prj, $text, $enc)
```

或者用 `sed -i`（bash，字节安全）、Python 的 `read_bytes/write_bytes`。
**凡是带中文注释的 `.conf` / `.c` / `.h`，都不要用 PowerShell 的文本管道去写。**

**连带教训**：脚本化改配置文件时，先确认目标文件编码，再选写入方式；
自动化流程（同步脚本）尤其要复核，否则每次跑都重新破坏一次。

## 12. 镜像仓没有上游提交历史 → 补丁要用 `git apply --reject` 手工接

镜像 `master` 是**合成快照**（一个 sync 提交一棵树），没有上游逐提交历史。
把别的分支的功能移植过来时：

- `git apply -3` **一定失败**（报 `repository lacks the necessary blob to perform 3-way merge`）；
- 用 `git apply --reject`：新文件与能匹配的 hunk 会自动落地，冲突文件留下 `.rej`；
- `.rej` 里的都是一两行的接线（`CMakeLists` / `Kconfig` / `main.c` / `prj.conf`），
  照着重放即可；上游文件结构可能与原分支不同（例如上游 `apps/arcs-mini` 没有 `radio_ui`），
  锚点要按上游实际内容找。

## 13. LVGL 新页面不能用 `lv_scr_load` 切成独立 screen

**现象**：电台页（`apps/arcs-mini/radio/radio_ui.c` 初版）退出后，界面冻住，
`adb shell` 也一起没反应（`adb devices` 还是 `device`，但任何命令都超时）。

**根因**：`lisa_ui_nav_scr_nav_default()` 的顺序是 **pop → pause → close → 再 resume 目标页**。
如果页面是独立 LVGL screen（`lv_scr_load` 切过去的），`close` 里 `lv_obj_del(s_scr)`
删掉的正是 **当前活动屏幕**，LVGL 的 `act_scr` 变成 NULL，渲染循环随后崩/卡死。

**对照**：内置页面（home / info / ota / quota）都不切 screen，而是
`view_create(lv_scr_act())` 建**子对象**，用 `LV_OBJ_FLAG_HIDDEN` 切显隐。
新页面照这个做，`close` 里删自己的子对象就安全了。

## 14. 播放器自己 stop 会释放焦点，把状态机锁死

**现象**：电台能进、能播，换台一次后停在 `STOPPED` 再也不恢复，而且日志狂刷
到把控制台拖死（`adb shell` 无响应）。

**根因**：焦点回调里把 `NONE/BACKGROUND` 一律当成"被别的播放器抢占"，
于是 `app_player_stop()`（换台、暂停、退页都会调）→ 释放焦点 → 焦点回调把
`s_focus=false` → 起播条件 `wanted && net_ok && focus` 永远不成立。

**处置**：焦点回调里先看 `by_which`——**指向自己时直接忽略**（这是自己的
stop/pause 引起的）。另外给起播加最小间隔（2 s），任何异常状态都不会变成忙循环
刷日志。教训：**给一个可能被清空的状态加"必须为真"的门槛，要先确认清空它的
路径不会由自己触发。**

## 15. ADB recovery 的 `push` 收尾报 EOF，用 cskburn 串口才是稳的

**现象**：`adb push <app.bin> /RAW/NAND/600000` 打印
`1 file pushed ... 3136012 bytes`，但紧接着 `adb: error: failed to read copy response: EOF`，
之后设备变成 `BOOT-xxxx offline`，任何 adb 命令超时；**必须物理长按才能恢复**。

**结论**：走的是 recovery 的大文件 `sync` 通道，与本仓早期记录一致（"小命令通、
大传输断"）。反复重试只会反复把设备打进 offline。

**处置**：直接走串口兜底，速度稳定且回读可校验（约 60 s 写完 3 MB）：

```powershell
.\tools\cskburn\cskburn.exe -C arcs -s COM10 -b 921600 --verify-all `
  0x600000 build-radio\arcs-mini.bin
```

- `md5 (0x00600000-0x008FDxxx): ...` 打印出来的就是**回读摘要**，与本地
  `md5sum build-radio/arcs-mini.bin` 逐字节比对即可确认写入正确。
- 写完是**冷复位**，仍要**长按功能键 3 s** 开机。
- 本机串口是 `USB-SERIAL CH340 (COM10)`；它与 ADB 是两条独立通道，
  ADB 卡死时它照常可用（`cskburn -C arcs -s COM10 -b 921600 -c` 只探测）。
