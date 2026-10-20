-- TTS 武将侧栏：单人 / 房主版
-- 用于 Global Lua。会生成并替换 Global UI。
-- 第一次请在 Global Lua 和 UI 均为空的测试存档运行。
-- 命令保存在令旗 Description 的 order=... 行中，随游戏手动存档保存。
-- 不需要填写物件 GUID，也不需要另贴 XML。

-- ===== 只需配置这里：键名必须与令旗 Name 完全相同 =====
local LEADERS = {
    ["太田资正"] = {
        name = "太田资正",
        stats = "能力：5    数值：9(4)", -- 按你自己的规则修改能力名称
        image = "", -- 把图片的完整 Cloud URL 粘在这两个英文双引号之间
        asset = "sg_ota_sukemasa"
    }
}

local ORDER_BY_BUTTON = {
    sg_attack = "进攻",
    sg_defend = "防御",
    sg_move = "机动",
    sg_regroup = "重整"
}

local selectedGUID = nil
local ready = false
local hasImage = {}

-- 面板默认宽 326、高 540；scale 可统一缩放，例如 0.85 0.85 1。
-- MiddleRight 是右侧居中；改成 MiddleLeft 并把 offsetXY 改为 20 0 可移到左侧。
local PANEL_XML = [[
<Panel id="sg_panel" visibility="Host" active="true"
       rectAlignment="MiddleRight" offsetXY="-20 0"
       width="326" height="540" scale="1 1 1"
       color="#20231FF5" raycastTarget="true">
    <Text id="sg_name" rectAlignment="UpperCenter" offsetXY="0 -12"
          width="246" height="32" fontSize="24" color="#F1E6C8">武将面板</Text>
    <Button id="sg_close" rectAlignment="UpperRight" offsetXY="-8 -10"
            width="30" height="28" fontSize="18" onClick="sgClose"
            colors="#514832|#756440|#3A3324|#514832" textColor="#FFFFFF">×</Button>
    <Image id="sg_portrait" active="false" rectAlignment="UpperCenter"
           offsetXY="0 -56" width="286" height="286"
           preserveAspect="true" raycastTarget="false" />
    <Text id="sg_no_image" rectAlignment="UpperCenter" offsetXY="0 -56"
          width="270" height="286" fontSize="20" color="#D8CEB4"
          horizontalOverflow="Wrap">指向桌面上名为“太田资正”的令旗</Text>
    <Text id="sg_stats" rectAlignment="UpperCenter" offsetXY="0 -352"
          width="294" height="32" fontSize="20" color="#F1E6C8"
          horizontalOverflow="Wrap">能力信息将在这里显示</Text>
    <Text id="sg_order" rectAlignment="UpperCenter" offsetXY="0 -391"
          width="294" height="32" fontSize="22" color="#E5C982">当前命令：—</Text>
    <Button id="sg_attack" rectAlignment="UpperCenter" offsetXY="-111 -436"
            width="68" height="36" fontSize="18" onClick="sgSetOrder"
            colors="#514832|#756440|#3A3324|#514832" textColor="#FFFFFF">进攻</Button>
    <Button id="sg_defend" rectAlignment="UpperCenter" offsetXY="-37 -436"
            width="68" height="36" fontSize="18" onClick="sgSetOrder"
            colors="#514832|#756440|#3A3324|#514832" textColor="#FFFFFF">防御</Button>
    <Button id="sg_move" rectAlignment="UpperCenter" offsetXY="37 -436"
            width="68" height="36" fontSize="18" onClick="sgSetOrder"
            colors="#514832|#756440|#3A3324|#514832" textColor="#FFFFFF">机动</Button>
    <Button id="sg_regroup" rectAlignment="UpperCenter" offsetXY="111 -436"
            width="68" height="36" fontSize="18" onClick="sgSetOrder"
            colors="#514832|#756440|#3A3324|#514832" textColor="#FFFFFF">重整</Button>
    <Text rectAlignment="UpperCenter" offsetXY="0 -481"
          width="294" height="24" fontSize="14" color="#BFB79F">按钮只记录已生效命令，不判定改令成败</Text>
    <Text rectAlignment="UpperCenter" offsetXY="0 -509"
          width="294" height="20" fontSize="14" color="#BFB79F">移开鼠标仍保留；关闭后重新指向令旗可打开</Text>
</Panel>
]]

local function isHost(player)
    return player ~= nil and player.host == true
end

-- 不使用 (.-) 裁剪长文本，避免触发 MoonSharp 的 pattern too complex。
local function trim(value)
    return ((value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function profileFor(object)
    if object == nil then return nil end
    local name = trim(object.getName())
    return LEADERS[name]
end

local function readOrder(object)
    for line in (object.getDescription() or ""):gmatch("[^\r\n]+") do
        local _, prefixEnd = line:find("^%s*order%s*=")
        if prefixEnd then
            local value = trim(line:sub(prefixEnd + 1))
            if value ~= "" then return value end
        end
    end
    return "未设置"
end

local function writeOrder(object, order)
    local description = (object.getDescription() or ""):gsub("\r\n", "\n")
    local lines = {}
    local replaced = false
    if description ~= "" then
        for line in (description .. "\n"):gmatch("([^\n]*)\n") do
            if line:match("^%s*order%s*=") then
                if not replaced then table.insert(lines, "order=" .. order) end
                replaced = true
            else
                table.insert(lines, line)
            end
        end
    end
    if not replaced then table.insert(lines, "order=" .. order) end
    object.setDescription(table.concat(lines, "\n"))
end

local function renderLeader(object)
    local profile = profileFor(object)
    if not profile or not ready or UI.loading then return end
    selectedGUID = object.getGUID()
    UI.setAttribute("sg_panel", "active", "true")
    UI.setValue("sg_name", profile.name)
    UI.setValue("sg_stats", profile.stats)
    UI.setValue("sg_order", "当前命令：" .. readOrder(object))
    local available = hasImage[profile.asset] == true
    UI.setAttribute("sg_portrait", "active", available and "true" or "false")
    UI.setAttribute("sg_no_image", "active", available and "false" or "true")
    if available then
        UI.setAttribute("sg_portrait", "image", profile.asset)
    else
        UI.setValue("sg_no_image", "武将已识别\n请在脚本 image 字段填写 Cloud URL")
    end
end

function onLoad()
    ready = false
    selectedGUID = nil
    hasImage = {}
    local assets = {}
    for _, profile in pairs(LEADERS) do
        local url = trim(profile.image)
        if url:match("^https?://") then
            table.insert(assets, {name = profile.asset, url = url})
            hasImage[profile.asset] = true
        end
    end
    UI.setXml(PANEL_XML, assets)
    -- UI 和图片异步载入；至少下一帧再检查状态。
    Wait.frames(function()
        Wait.condition(function()
            ready = true
            print("[武将面板] 已就绪。请将鼠标移出后，再指向名为太田资正的令旗。")
        end, function()
            return not UI.loading
        end, 30, function()
            -- 允许稍后下载完成后重新悬停；各入口仍检查 UI.loading。
            ready = true
            print("[武将面板] 载入超过30秒。检查图片URL；可暂时把 image 清空后重试。")
        end)
    end, 1)
end

function onObjectHover(player_color, object)
    if not ready or object == nil then return end
    if not isHost(Player[player_color]) then return end
    if profileFor(object) then renderLeader(object) end
    -- 指向普通部队或空地时，保留最后一名武将，方便点击面板。
end

function sgSetOrder(player, value, id)
    if not isHost(player) or not ready or UI.loading then return end
    local order = ORDER_BY_BUTTON[id]
    if not order or not selectedGUID then return end
    local object = getObjectFromGUID(selectedGUID)
    if not object or not profileFor(object) then
        selectedGUID = nil
        UI.setValue("sg_order", "令旗已移除，请重新选择")
        return
    end
    writeOrder(object, order)
    renderLeader(object)
end

function sgClose(player)
    if isHost(player) and ready and not UI.loading then
        UI.setAttribute("sg_panel", "active", "false")
    end
end
