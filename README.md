# ling — Arcs-mini3 手册仓与模板

**这个仓库不是产品代码仓，是「小程序 + 固件」两套开发的手册与模板**：规范、流程、板级事实、
可复制的最小 demo。真正的功能开发按下面的分工在**各自仓库的分支**上进行。

| 我要开发 | 代码放哪 | 本仓提供什么 |
|---|---|---|
| 小程序（Lua） | **本仓的分支**（每个功能一条 `feat/*`） | 目录结构、构建/上传脚本、demo 模板、编码约定 |
| 固件（C / LVGL） | `https://cloud.listenai.com/CSKG836746/arcs-sdk/public/arcs_mini` | 固件级规范与流程：[`docs/firmware/`](docs/firmware/README.md) |

## 目录

```
src/                  最基础 demo 小程序（计数器）：app.lua + lib/ui + lib/input + lib/store
tools/                构建 / 校验 / 上传 / 截图 / 复位 / 设备监听
examples/             单文件示例（hello、net-probe）
docs/
  development/        小程序：运行时契约、编码约定、开发闭环、环境搭建、云端下发
  firmware/           ★ 固件：规范（conventions）、流程（process）
  hardware/           板级事实（引脚 / 外设 / 内存上限）
  reference/          外部官方资料索引（文档中心、固件仓、SDK）
```

## 小程序：三步闭环

```powershell
.\tools\validate.ps1                 # 合并 src/ → 静态检查 → 模拟器实跑出图
.\tools\screenshot.ps1               # 只出图，肉眼确认界面
.\tools\upload.ps1 -Id counter       # 推到真机（设备需开 adb）
```

- 运行时上限、能调什么、不能调什么：`docs/development/miniapp-runtime.md`
- 代码怎么写（没有 `pcall`/`require`，每帧 ≤128 矩形 / ≤8 段文字）：`docs/development/coding-conventions.md`
- 改多文件时记得登记 `src/bundle.conf`；产物 `dist/app.lua` 不要手改。

## 小程序功能分支怎么开

```bash
git switch -c feat/<功能名> origin/main
# …改 src/、改 docs…
.\tools\validate.ps1
git commit -am "feat(<范围>): 一句话说明"
```

`main` 只放模板与 demo，**不要在 main 上做业务**。

## 固件：从这里开始读

1. [`docs/firmware/README.md`](docs/firmware/README.md) —— 分工与必读顺序
2. [`docs/firmware/conventions.md`](docs/firmware/conventions.md) —— 板型、内存预算、分区地址、BLE/LVGL/按键约定
3. [`docs/firmware/process.md`](docs/firmware/process.md) —— 构建 → 烧录 → 真机验收 → 提交 → 回滚
4. [`docs/development/flashing-and-recovery.md`](docs/development/flashing-and-recovery.md) —— 烧录与救砖细节

**两条红线**：构建必须 `-DBOARD=arcs_mini3`（`arcs_mini` 是另一块板，刷错会黑屏 + USB 不识别）；
构建通过 ≠ 真机通过，BLE / 按键 / 屏幕 / 音频只有真机能确认。

## 设备与固件现状

| 项 | 值 |
|---|---|
| 目标设备 | Arcs-mini3（LS2663） |
| 官方固件 | 3.0.2 实测；3.0.3 已发布（更新日志见 `docs/reference/README.md`） |
| 小程序 API | `app.api_version = 4` |
| 真机调试 | adb（`adb shell version` / `adb push` 到 `/miniapp/<id>.lua`） |

## 文档规则

事实只有一个真相源：硬件在 `docs/hardware/`，小程序运行时契约在 `docs/development/miniapp-runtime.md`，
固件规范在 `docs/firmware/`，外部链接在 `docs/reference/README.md`。其它文档引用，不复制正文。
