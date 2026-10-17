-- 计数器 demo —— 本仓库的标准模板（最基础一个能跑的小程序）
--
-- 演示这套仓库约定的最小闭环：
--   帧式绘制（ui）→ 单击/双击（input）→ 延迟落盘（store）→ 生命周期回调
-- 运行时没有 pcall / require / io：所有能力都要先判空，见 docs/development/coding-conventions.md。
--
-- 交互：
--   单击     +1（计数落盘，10 秒内多次点击只写一次）
--   双击     归零
--   长按退出 由系统处理（脚本里不实现）

--------------------------------------------------------------------------
-- 配色与布局（0xRRGGBB）
--------------------------------------------------------------------------
local BG = 0x071017
local PANEL = 0x0D1B23
local TEXT = 0xE6F0F2
local MUTED = 0x849BA0
local AMBER = 0xFFB74D

local PANEL_X = 13
local PANEL_W = 214
local PANEL_Y = 62
local PANEL_H = 96

--------------------------------------------------------------------------
-- 状态
--------------------------------------------------------------------------
local count = 0
local started = false
local needs_redraw = true

local function load_state()
    -- 存档是"可丢失"的：读回什么都当脏数据，逐字段判类型
    if not store.load() then
        return
    end
    local v = store.get("count", 0)
    if type(v) == "number" and v >= 0 then
        count = math.floor(v)
    end
end

--------------------------------------------------------------------------
-- 绘制
--------------------------------------------------------------------------
local function clock_text()
    -- clock 未校时时返回 nil：显示占位，不要当成 00:00 骗人
    local t = clock and clock.localtime and clock.localtime()
    if type(t) ~= "table" then
        return "--:--"
    end
    local h = tonumber(t.hour) or 0
    local m = tonumber(t.min) or 0
    return string.format("%02d:%02d", h, m)
end

local function draw()
    ui.begin(BG)

    -- 顶栏：标题 + 时间
    ui.text("计数器 demo", 12, 8, AMBER)
    ui.text(clock_text(), ui.W - 12 - ui.text_width("00:00"), 8, MUTED)

    -- 数值面板
    ui.round_rect(PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 10, PANEL)

    local big = tostring(count)
    -- 数字用 16px 字体也放得下：居中画在面板中线偏上
    ui.text_center_v(big, PANEL_Y + 40, TEXT)

    ui.text_center("已计 " .. count .. " 次", PANEL_Y + 68, MUTED)

    -- 底部说明行
    ui.text_center("单击 +1   双击归零   长按退出", ui.H - 28, MUTED)

    ui.present()
    needs_redraw = false
end

--------------------------------------------------------------------------
-- 生命周期（回调名由运行时约定，不能改）
--------------------------------------------------------------------------
function on_start()
    load_state()
    input.reset()
    -- 启用屏幕时，启动阶段必须至少提交一帧
    draw()
    started = true
end

function on_tick(dt_ms)
    -- 多击判定与延迟落盘都靠 tick 的 dt 累加，不假设 tick 精确
    input.tick(dt_ms)
    store.tick(dt_ms)

    if needs_redraw then
        draw()
    end
end

function on_button_click(button_id)
    if button_id ~= "function" then
        return
    end
    input.button(button_id)
end

function on_exit()
    -- 退出前尽量把计数写下去（写失败无所谓，存档是可丢失的）
    store.set("count", count)
    store.flush(true)
    started = false
end

--------------------------------------------------------------------------
-- 交互绑定
--------------------------------------------------------------------------
input.bind(
    function()
        count = count + 1
        store.set("count", count)
        needs_redraw = true
    end,
    function()
        count = 0
        store.set("count", count)
        needs_redraw = true
    end,
    nil
)
