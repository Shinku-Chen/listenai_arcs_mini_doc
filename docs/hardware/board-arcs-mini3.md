# Arcs-mini3 板级事实与引脚定义（LS2663）

> **板型**：`arcs_mini3`（`BOARD_ARCS_MINI3`，SoC `LS2663`）。构建必须 `-DBOARD=arcs_mini3`，
> 资源目录 `res/arcs-mini3/`（tone / wake_word / emoji / respak 共用 `res/arcs-mini/`）。
>
> **来源**：固件仓 `arcs-sdk/boards/arcs_mini3/`（`pinmux.h` / `pinmux.c` / `board.h` / `overlay.conf` /
> `README.md`），核对于上游 `master @23fca91e`（tag `mini-v3.0.3`）。这些文件由
> **LISA Pinmux Tool** 生成，是引脚定义的**唯一代码级真相源**。
>
> **本文件不会被任何流程自动覆盖**：`ling` 仓没有同步任务；跨仓同步只发生在
> `Shinku-Chen/listenai_arcs_mini` 里（上游 → 镜像，且只保留它自己的 `docs/ai/`）。
> 风险是**变更上游后本文件变旧**——核对方式是 diff 上游这几个文件（见文末「怎么核对」）。
>
> **和 mini（LS2684）的区别**：见 [board-arcs-mini.md](board-arcs-mini.md)。两者引脚、boot/ap 镜像都不通用，
> **刷错板型 = 黑屏 + USB 不识别 + 反复重启**（实测过）。

## 1. mini3 与 mini 最容易踩的三处差异

| 项 | mini3（本板） | mini（LS2684，对照） |
|---|---|---|
| 本地功放静音 | **没有** `PA_mute_PIN` / `PA_EN_PIN`：PA mute 由外部 MCU 的 EXGPIO 控制，`CONFIG_LISA_AUDIO_PLAY_PA_ENABLE=n` | PA01 本地控制 |
| 用户 LED | **没有**主 MCU 可编程 LED | PB01 是 LED |
| TF 卡检测 | **在外部 CH32V003 的 `exgpiod` 上**，SoC 侧 SDIO 只配 CLK/CMD/DAT0–3 | 本地上拉/检测 |
| 引脚 `PB09` | **`LCD_RST`**（不是 LED） | 无/不同 |
| 构建 | `-DBOARD=arcs_mini3` | `-DBOARD=arcs_mini` |

## 2. 完整引脚别名（`pinmux.h`，编号 = GPIO 序号）

| 别名 | 序号 | 实际引脚 | 别名 | 序号 | 实际引脚 |
|---|---|---|---|---|---|
| `EXT4G_PWR_PIN` | 0 | PA00 | `LCD_PWM_PIN`（背光） | 21 | PA21 |
| `EXT4G_RST_PIN` | 1 | PA01 | `LCD_CS_PIN` | 22 | PA22 |
| `AP_LOG_RX_PIN` / `CP_LOG_TX_PIN` | 2 | PA02 | `LCD_CD_PIN`（DC） | 23 | PA23 |
| `AP_LOG_TX_PIN` | 3 | PA03 | `LCD_SPI_DATA_PIN` | 24 | PA24 |
| `POWER_EN_PIN` | 3 | PB03 | `LCD_SPI_CLK_PIN` | 25 | PA25 |
| `POWER_KEY_PIN` | 4 | PB04 | `CAM_MCLK_PIN` | 26 | PA26 |
| `BAT_ADC_PIN` | 5 | PB05 | `LCD_TE_PIN` | 27 | PA27 |
| `EX4G_TXD_PIN` | 6 | PB06 | `CAM_HSYNC_PIN` | 10 | PA10 |
| `EX4G_RXD_PIN` | 7 | PB07 | `CAM_VSYNC_PIN` | 11 | PA11 |
| `USB_DET_PIN` | 8 | PB08 | `CAM_PCLK_PIN` | 12 | PA12 |
| `LCD_RST_PIN` | 9 | PB09 | `CAM_D0…D7_PIN` | 13–20 | PA13–PA20 |

> 注意序号列是**按端口各自编号**：`POWER_EN_PIN=3` 指的是 **PB03**，`AP_LOG_TX_PIN=3` 指的是 **PA03**。
> 用 `board.h` / `pinmux.h` 里的别名，别自己写数字。

## 3. 外设映射（功能码，`README.md` 原文）

| 外设 | 引脚 | 功能码 | 说明 |
|---|---|---|---|
| UART0 | PA02 / PA03 | 2 | **CP 日志** RX/TX |
| UART1 | PB02 | 3 | **AP 日志** TX |
| UART2 | PB06 / PB07 | 4 | 外部串口 TX/RX（**烧录/救砖用**） |
| I2C1 | PB00 / PB01 | 8 | 摄像头控制总线 + CH32V003 + USB role controller |
| SDIO | PA04–PA09 | 15 | TF 卡 DAT1/DAT0/CLK/CMD/DAT3/DAT2 |
| SPI0 | PA22 / PA24 / PA25 | 5 | LCD CS / MOSI / CLK |
| PWM CH1 | PA21 | 12 | LCD 背光 |
| DVP | PA10–PA20, PA26 | 16 | 摄像头并口 |
| ADC CH3 | PB05 | 3 | 电池电压采样 |
| GPIO | PA00 / PA01 | 1 | 4G EN / RST |
| GPIO | PB03 / PB04 / PB08 / PB09 | 0 | POWER_EN / POWER_KEY / USB_DET / LCD_RST |

## 4. 屏幕

| 项 | 值（`overlay.conf`） |
|---|---|
| Panel | `CONFIG_LISA_DISPLAY_PANEL_ST7789P3=y`（GC9D01N 关闭） |
| 接口 | 单 SPI LCD（SPI0 + DC + PWM 背光 + RST），`COMPOSITE=n` |
| TE 同步 | `CONFIG_LISA_DISPLAY_TE_SYNC=y`（用 PA27 TE） |
| 旋转 | **`CONFIG_LV_DRIVER_ROTATE_180=y`**（v3 装配方向） |
| 触摸 | **没有**：`CONFIG_LISA_TOUCH_DEVICE=n`（v3 pinmux 里没有 touch reset/int） |
| 尺寸 | 240 × 240 |

## 5. 外部 MCU：CH32V003（全部走 I2C1）

| 项 | 值（`board.h`） |
|---|---|
| 设备名 | `ch32v003` |
| I2C 设备 / 地址 | `i2c1` / **`0x6c`** |
| CH32V003 侧 SDA/SCL | PC5 / PC6 |
| 扩展 GPIO | `exgpioa` / `exgpiob` / `exgpioc` / **`exgpiood`（`exgpiod`）** |
| 扩展 ADC / PWM | `exadc` / `expwm` |
| 归属 | **只在 CP 核**（`select ... if ARCS_CP_CORE`），避免双核争用 I2C1 |

用途举例：功放静音（PA mute）、TF 卡检测、充电检测（`CONFIG_BATTERY_COLLECTION_CHARGE_DETECT_PAD="exgpiood"`）。

## 6. USB-C 角色控制

USB-C 口由 I2C1 上的 role controller 决定谁占 MUSB：

| 项 | 值 |
|---|---|
| I2C | `i2c1` @ **`0x31`** |
| 寄存器 | `0x01` device id / `0x02` device type / `0x03` port role / `0x04`+`0x05` control / `0x11` status / `0x13` type |
| Kconfig | `CONFIG_APP_USB_ROLE_DETECT=y`、`CONFIG_CHERRYUSB_HOST=y`（含 CDC-ACM / CH34X / HID host） |

也就是说：**USB 既能当 device（ADB/烧录），也能当 host（接 USB 串口/键鼠）**，由板载控制器切换。

## 7. 电池与电源

| 项 | 值 |
|---|---|
| 电池电压 | ADC `gpiob` channel **3**（PB05） |
| 充电检测 | 外部扩展口 `exgpiood` |
| 电源锁存 | `POWER_EN_PIN` = PB03 |
| 主按键 | `POWER_KEY_PIN` = PB04 |
| USB 插入 | `USB_DET_PIN` = PB08 |

## 8. 在代码里怎么用

```c
#include "board.h"      /* 兼容别名：LCD_CS_PIN / CAM_D0_PIN / POWER_KEY_PIN … */
#include "pinmux.h"     /* 板型生成的别名与 lisa_xxx_pinmux() 声明 */
```

- **能用别名就别写数字**（`PB03` 这类字符引脚名在代码里不存在，只有序号 + 设备名）。
- `pinmux.h` 声明的 `lisa_gpioa_pinmux()` / `lisa_i2c1_pinmux()` / `lisa_dvp_pinmux()` 等由板级初始化调用，
  业务代码不要重复配置复用。
- 需要 GPIO 设备名时用 `*_DEVICE_NAME` 宏（`"gpioa"` / `"gpiob"` / `"exgpiood"`）。

## 9. 改引脚的正确姿势

**不要手改 `pinmux.c` / `pinmux.h`**——它们是生成物：

1. 打开 <https://tool.listenai.com/ls-pinmux-tool/>，导入
   `arcs-sdk/boards/arcs_mini3/projects_data.json`；
2. 在工具里改复用，导出新的 `pinmux.c` / `pinmux.h` / `projects_data.json` 覆盖回去；
3. 若同时改了板级默认外设（panel、I2C 编号、触摸…），一并改 `overlay.conf` 与 `Kconfig`；
4. 重新构建并**上真机验证**（引脚配错的典型表现是黑屏、无声音、I2C 超时）。

## 10. 怎么核对本文件是否过期

```bash
# 在固件仓根目录（或镜像仓），对比这几个文件是否变了
git diff <上次核对的提交>..HEAD -- arcs-sdk/boards/arcs_mini3/
```

变动后按 §2 / §3 表更新本文，并在下面「核对记录」加一行。

| 日期 | 核对的固件提交 | 结论 |
|---|---|---|
| 2026-10-18 | 上游 `master @23fca91e`（tag `mini-v3.0.3`） | 首次整理，与 `pinmux.h`/`README.md`/`overlay.conf` 一致 |
