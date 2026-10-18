# 网络电台（radio）功能契约

> 来源：镜像仓分支 `cindy/happy-liskov` 的 `apps/arcs-mini/radio/`（`CONFIG_RADIO`）。
> 移植自 <https://github.com/leo0183/leo-radio>（ESP32-C3 / 240x320 / 三按键 / SoftAP 配网）。
> 本文写**行为契约与接线方式**，实现细节看代码注释。

## 1. 它是什么

固件原生的一台"网络收音机"：独立页面（导航 id **92**）+ 独占一个 `app_player`
实例（焦点通道 `radio`）播放 http(s) MP3 直播流。**不依赖小程序运行时**
（`CONFIG_MINIAPP=n` 也能用）。

| 能力 | 做法 |
|---|---|
| 台单 | `radio-browser.info` 按城市查台（最多 10 个），失败回退 6 个内置 qtfm 台 |
| 电台元信息 | 完整台名（目录原名，播放页过长循环滚播）、流派标签（英文自动翻中文）、编码、码率、语言、台单来源、剩余电量 |
| 定位 | `ip-api.com/json/`（http，8 s 超时）→ 英文城市名按内置表转中文再查 |
| 城市选择 | 自动定位 + 北京/上海/广州/深圳/长沙/杭州/成都（与 leo-radio 的 `kCityChoices` 一致） |
| 频率 | 从台名解析 FM 87.0–108.0，单位 0.1 MHz；解析不到按序号铺在刻度上 |
| 播放 | `app_player_play(url)`，直播流"暂停"= stop，恢复=重新拉流 |
| 睡眠定时 | 关闭 / 15 / 30 / 60 / 90 分钟，只在播放中计时，到期停止播放（不跨重启保留） |
| 音量 | 复用系统音量 `service_volume_*`（所有播放器同步生效，持久化 KV） |
| 持久化 | KV：`radio.station`（上次收听的台名）、`radio.city`（城市索引） |
| 开机行为 | `CONFIG_RADIO_AUTO_START`（默认 `y`）：开机 3 s 后自动进电台页并开播；**没保存过 WiFi 的设备不抢主页**（见 §6） |

## 2. 交互（单物理键）

设备只有一颗电源键，既有手势里 **四击**是空着的，电台用它做唯一入口。

| 手势 | 电台页外 | 播放页 | 设置菜单 | 台单/城市 | 音量 |
|---|---|---|---|---|---|
| 单击 | 助手原行为 | 换下一台 | 下移选中 | 下移选中 | 音量 +5（到顶回 10） |
| 双击 | 助手原行为 | 播放/暂停 | 确认 | 选台并播放 / 按城市查询 | 返回菜单 |
| 三击 | 助手原行为 | **退出电台** | 回播放页 | 回播放页 | 回菜单 |
| 长按 | 关机 | **进设置菜单** | 回播放页 | 回播放页 | 回菜单 |
| 四击 | **进电台** | **退出电台** | 退出电台 | 退出电台 | 退出电台 |
| 五/六/七击 | BLE 配网 | 先退出电台，再配网 | 同左 | 同左 | 同左 |
| 连击 8+ | 恢复出厂 | 吞掉（防误触） | 吞掉 | 吞掉 | 吞掉 |

要点：

- 电台页在前台时**吞掉 `LONG_HOLD`**，否则"长按=关机"会在设置时直接关机。
- 五/六/七击**放行**给既有 BLE 配网：配网流程一行没改，只负责先把电台页关掉，
  避免两套页面叠在一起。无网时的提示行会写"等待网络"，用户按五六七击即可配网。
- 拦截点在 `apps/arcs-mini/button/app_button.c` 的 `app_button_on_changed`，
  必须放在 `app_button_redirect_to_cloud_info()` **之前**（否则三击会被云异常
  重定向抢走）。

## 3. 接线点

| 位置 | 改动 |
|---|---|
| `apps/arcs-mini/CMakeLists.txt` | `add_subdirectory(radio)`（`CONFIG_RADIO` 门控）+ 头路径 |
| `apps/arcs-mini/Kconfig` | `rsource "radio/Kconfig"`，开关默认 `n`，`prj.conf` 里显式 `=y` |
| `apps/arcs-mini/main.c` | `lisa_ui_init()` 之后调 `radio_app_init()` |
| `apps/arcs-mini/button/app_button.c` | 按键拦截（见上） |
| `src/category/comm/voice_player_comm.c` | 新增 `radio` 焦点通道 + `app_player_create("radio")` + 音量线程 & `voice_player_is_audio_active()` 纳入统计 |

`src/` 只动了这 3 处（全部 `#ifdef CONFIG_RADIO`）：播放器实例必须和 tone/tts/music
在同一处创建，否则音量线程与焦点通道都不认它。

## 4. 音频焦点策略

- 通道 `radio`：priority **52**（略低于 music=50，云端歌单优先），`capture_names={"music"}`
  （电台起播时强制抢占音乐，避免两路同时出声）。
- 焦点回调**返回 true 完全接管**：直播流的 pause/resume 不可靠，改为
  "被抢 → 停止拉流 → 对方释放 → 重新拉流"；被抢占超过 5 s 会试探性重新申请一次。
- **关键坑**：自己 `app_player_stop()` 会释放焦点并触发一次焦点回调，
  回调里必须先判断 `by_which == 自己` 并忽略，否则 `s_focus` 永久为 false，
  状态机卡在 STOPPED 并反复重试（见 [pitfalls.md §13](pitfalls.md)）。

## 5. 界面约定

播放页（240x240）——"仪表卡片 + 三行文字栈"：

```
03/10                       82%  12:34     频道号（开了定时则换成倒计时）/ 电量 / 时钟
┌──────────────────────────────────┐
│            101.7                 │ 大号读数，颜色即播放状态
│  88 ━━━━━●━━━━━  108             │ 刻度盘（数字不再标注，避免撞车）
└──────────────────────────────────┘
上海流行音乐广播 动感101             目录原名（超宽循环滚播）
上海 · 新闻 · 谈话 · MP3            来源 · 流派 · 编码 · 码率
单击换台 双击暂停 长按设置           操作提示
```

- **播放状态只用颜色表达**，不写"正在播放/已暂停"：
  琥珀=在播，暗琥珀=连接中/重连，灰=暂停。指针与"已调谐"刻度段跟读数同色系，
  暂停时一并变灰（否则数字灰了刻度还亮着，看起来像还在播）。
- 左上角只有频道号 **03/10**；开了睡眠定时就整格换成倒计时 `14:52`（不带“定时”二字），
  定时不单独占位、也不进卡片。台单来源（城市/内置）放在倒数第二排开头。
- 搜台、出错时不额外加行：倒数第二排直接换成"正在搜索电台 …"/错误原因（琥珀/红）。
- 计数 `03/10` 与左上角都是纯文字，不加底纹；卡片之外的文字统一左对齐、28px 行距。
- 台单页一行两项：上排目录原名，下排流派/码率；选中行琥珀、在播行绿色。
- 大号读数只有 `rubik_bold_64`（含数字和 `.`，**没有空格和字母**）：
  有频率显示频率，没有频率显示频道号 `03`，别往里塞中英文。
- **限宽单行标签必须显式给 20px 高**：`chinese_16` 的 `line_height` 是 18，
  但 CJK 字模实际画到 +19/+20，只给一行高度会被裁掉 1~2px（真机上是"字被切了"）。
- 大字号只在本机 respak 里（`/font/lv_font_rubik_bold_64.bin`），
  中文字体只有 16px 一档（`lv_font_chinese_18` 没编进来，doll_v2 才带）。

## 6. 调试命令

```bash
adb shell "radio"                 # = radio stat
adb shell "radio stat"            # fg/page/count/index/net/busy/pb/vol + 台名/频率/来源
adb shell "radio list"            # 当前台单（名字 | url | 频率）
adb shell "radio key click"       # 模拟按键：click/double/triple/quad/five/long
adb shell "radio show" / "hide"   # 直接进/出电台页
adb shell "radio next|play|pause"
adb shell "radio city 2"          # 按城市表索引查一次目录（0=自动定位）
```

`radio stat` 的 `pb`：0=停止 1=连接中 2=播放中 3=失败重试中。

> 日志是**异步**的：`adb shell "radio stat"` 之类的短命令会在日志落盘前就退出会话，
> 想看 `LOGI/LOGW` 要在同一条命令后面挂一个耗时子命令（例如 `... ; wifi scan`）。

## 7. 开机自动进入（`CONFIG_RADIO_AUTO_START`）

默认开启，`apps/arcs-mini/prj.conf` 里显式写 `CONFIG_RADIO_AUTO_START=y`。

- 开机 3 s 后自动 `nav_to` 电台页并开播（3 s 是为了给助手主页 / 配网引导页
  第一次展示的机会，避免开机瞬间被盖住）。
- **只有 `sys_wifi_has_ap()` 为真才自动进入**。从没配过网的设备停在助手主页，
  否则用户看不到扫码绑定 / BLE 配网引导。要把一台新设备变成"纯收音机"，
  先用五六七击配网一次，之后每次开机都会直接进电台。
- 页面若被其他页面（扫码绑定页等）盖住，按键交还既有逻辑（不抢），
  四击可随时把电台页提到最前；导航补投递只在"从未成功上到前台"期间发生，
  不会每 400 ms 把上层页面顶下去。
- 电台页在前台时用 `service_power_policy_set_miniapp_active(true)`，
  即**不进 IDLE/HIBERNATE**（屏幕不自动熄），这是当前版本与 leo-radio 的差异，
  长时间开着的烧屏风险未处理。

## 8. 分支与自动发布

- 分支：**`feat/leo-radio`**（原 `cindy/happy-liskov`，已改名）。master 仍是上游快照。
- **流水线本体在 master**：`.github/workflows/release-firmware.yml`，`workflow_call` 可复用，
  也可 `workflow_dispatch` 手动选分支/板型。放 master 的 `.github/` 是因为每周上游同步会
  `git checkout HEAD -- .github`，这一层是唯一能长期存活、供所有分支复用的位置。
- **功能分支只留一个瘦 caller**：`.github/workflows/release-leo-radio.yml`（十几个 with 参数），
  换新功能固件时复制它改 `board` / `app_dir` / `build_name` / `notes_file` 即可。
- **打 tag 自动发版**：

  ```bash
  git switch feat/leo-radio && git pull
  git tag -a leo-radio-v3.0.4 -m "LEO 网络电台 3.0.4"
  git push origin leo-radio-v3.0.4
  ```

  → `release-leo-radio`（tag `leo-radio-*` 触发）→ 调用 master 的 `release-firmware`
  → 构建 + 打包 → 创建 Release（tag 名即 release tag，自动 `--latest`）。
- 产物：`*-app.bin`（cskburn `0x600000`）、`*-full.lpk`（整包）、`*.ota.txz`、`*.combined.hex`。
- CI 坑（都已修）：`env.sh` 在 Actions 的 `bash -e` 下**静默退出**（改直接调
  `prepare_toolchain.sh` / `prepare_listenai_tools.sh` 并写 `GITHUB_ENV`）；仓库里
  `build.sh` 是 **644**，必须 `bash build.sh`；产物名带板型后缀（`arcs-mini3.*`），
  收集时要用 glob 兜住而不是写死 `arcs-mini-v*`。
- Release 正文在 `.github/release-notes-leo-radio.md`（刷哪个文件、板型红线、交互、发版步骤）。

## 9. OTA 与自定义固件的关系

- **官方 app OTA 会把 app 分区（`0x600000`）整块替换**，网络电台等自建功能随之消失。
  本固件已经在 `prj.conf` 打开 `CONFIG_OTA_DISABLE_APP_UPDATE=y`，app 升级不再检查。
- 资源包 OTA（`tone` / `wake_word` / `emoji`）走独立分区，app 不动，可以继续收。
- KV 分区（`0xF00000`）不被任何 OTA 触碰，`radio.station` / `radio.city` / 音量都在；
  重新刷回带电台的固件后设置自动恢复。
- 想长期维护电台版本：用构建产物 `build/<board>/arcs-mini3-v<ver>.ota.txz`
  发布到自己的产品下，云端下发的就是带电台的包。
- 临时恢复自动升级：`adb shell kv set int user.disable_app_update 0`（KV 优先级低于
  `CONFIG_OTA_DISABLE_APP_UPDATE`，编了 `=y` 时 KV 无效）。
- **电台页必须给这些页面让位**：闹钟响铃、OTA 确认页、小应用、日志上传
  （OTA 确认页 `portMAX_DELAY` 等按键，被顶掉会把流程卡死）。

## 10. 已知限制

- 直播流不支持 seek / 时长，`COMPLETED` 事件按"断流"处理（重连，不切台）。
- 断线自动重连：单台连续失败 3 次自动换下一台（公共目录死链很多）。
- 只播 `.mp3` 直链（目录侧按 `codec=MP3` 过滤，HLS 条目直接丢弃）。
- 没有 ICY metadata / 自定义 User-Agent（SDK 的 URL 播放接口不暴露请求头）。
- 电台页在前台时**不进休眠**（复用 `service_power_policy_set_miniapp_active(true)`），
  屏幕常亮；没有做 leo-radio 的自动熄屏与亮度档位。
- 未做 leo-radio 的"蓝牙彩蛋视频"（与本功能无关，且需要额外资源分区）。
- 时钟依赖 SNTP 校时，未校时显示 `--:--`。
