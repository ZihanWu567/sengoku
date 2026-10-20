-- 旧版归档：此文件不含当前多人面板、陣旗与済印修复，请勿作为新版安装。
-- 当前完整 Global 请使用同目录「兵種与備隊面板合并版_日本漢字.lua」。
MIN_VALUE = 0

-- =========================
-- 兵种配置
-- =========================
UNIT_CONFIGS = {
    {
        tag = "unit_nagaye_ashigaru",
        name = "長柄足軽",

        max_front = 6,
        max_back = 5,

        front_move = 4,
        back_move = 3,

        front_name_color = {0, 0, 0, 1},
        back_name_color = {0.45, 0.05, 0.05, 1},

        front_number_color = {0, 0, 0, 1},
        back_number_color = {0.55, 0.05, 0.05, 1}
    }
}

-- =========================
-- 数量配置
-- =========================
COUNT_CONFIGS = {
    {
        tag = "count_100",
        label = "一\n百"
    },
    {
        tag = "count_200",
        label = "二\n百"
    },
    {
        tag = "count_300",
        label = "三\n百"
    },
    {
        tag = "count_400",
        label = "四\n百"
    }
}

DEFAULT_COUNT_LABEL = "一\n百"

-- 每个棋子的状态，按 GUID 保存
unit_state = {}

function onLoad(saved_data)
    if saved_data ~= nil and saved_data ~= "" then
        local data = JSON.decode(saved_data)

        if data ~= nil and data.unit_state ~= nil then
            unit_state = data.unit_state
        end
    end

    Wait.time(setupAllUnits, 1)
    initTeamPanel()
end

function onSave()
    return JSON.encode({
        unit_state = unit_state
    })
end

function setupAllUnits()
    for _, obj in ipairs(getAllObjects()) do
        local config_tag, config = getUnitConfig(obj)

        if config ~= nil then
            setupUnit(obj, config_tag, config)
        end
    end
end

function onObjectSpawn(obj)
    Wait.time(function()
        local config_tag, config = getUnitConfig(obj)

        if config ~= nil then
            setupUnit(obj, config_tag, config)
        end
    end, 0.5)
end

function onObjectDestroy(obj)
    local guid = obj.getGUID()

    if unit_state[guid] ~= nil then
        unit_state[guid] = nil
    end
end

-- =========================
-- 读取兵种 tag
-- =========================
function getUnitConfig(obj)
    for _, unit_config in ipairs(UNIT_CONFIGS) do
        if obj.hasTag(unit_config.tag) then
            local config = copyConfig(unit_config)
            config.count_label = getCountLabel(obj)

            return unit_config.tag, config
        end
    end

    return nil, nil
end

-- =========================
-- 读取数量 tag
-- =========================
function getCountLabel(obj)
    for _, count_config in ipairs(COUNT_CONFIGS) do
        if obj.hasTag(count_config.tag) then
            return count_config.label
        end
    end

    return DEFAULT_COUNT_LABEL
end

function copyConfig(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

function setupUnit(obj, config_tag, config)
    local guid = obj.getGUID()

    if unit_state[guid] == nil then
        unit_state[guid] = {
            front_value = 0,
            back_value = 0,
            manual_defeat_visible = false,
            config_tag = config_tag
        }
    end

    if unit_state[guid].front_value == nil then
        unit_state[guid].front_value = 0
    end

    if unit_state[guid].back_value == nil then
        unit_state[guid].back_value = 0
    end

    if unit_state[guid].manual_defeat_visible == nil then
        unit_state[guid].manual_defeat_visible = false
    end

    unit_state[guid].config_tag = config_tag

    createCounter(obj, config)
end

function getStateAndConfig(obj)
    local guid = obj.getGUID()
    local config_tag, config = getUnitConfig(obj)

    if config == nil then
        return nil, nil
    end

    if unit_state[guid] == nil then
        unit_state[guid] = {
            front_value = 0,
            back_value = 0,
            manual_defeat_visible = false,
            config_tag = config_tag
        }
    end

    return unit_state[guid], config
end

-- =========================
-- 创建按钮
-- =========================
function createCounter(obj, config)
    local state = unit_state[obj.getGUID()]

    obj.clearButtons()

    -- index 0：正面士气
    obj.createButton({
        label = tostring(state.front_value),
        click_function = "changeFrontValue",
        function_owner = Global,

        position = {0.3, 0.11, 0.73},
        rotation = {0, 0, 0},
        scale = {0.5, 0.5, 0.5},

        width = 450,
        height = 450,
        font_size = 550,

        color = {1, 1, 1, 1},
        font_color = config.front_number_color,

        tooltip = "士气上限：" .. tostring(config.max_front)
    })

    -- index 1：背面士气
    obj.createButton({
        label = tostring(state.back_value),
        click_function = "changeBackValue",
        function_owner = Global,

        position = {-0.3, -0.01, 0.73},
        rotation = {0, 0, 180},
        scale = {0.5, 0.5, 0.5},

        width = 450,
        height = 450,
        font_size = 550,

        color = {1, 1, 1, 1},
        font_color = config.back_number_color,

        tooltip = "士气上限：" .. tostring(config.max_back)
    })

    -- index 2：背面敗走文字
    obj.createButton({
        label = getDefeatText(state),
        click_function = "null",
        function_owner = Global,

        position = {0, -0.01, 0},
        rotation = {0, 0, 180},
        scale = {0.5, 0.5, 0.5},

        width = 0,
        height = 0,
        font_size = 1500,

        font_color = {1, 1, 1, 1},

        tooltip = ""
    })

    -- index 3：背面切替按钮
    obj.createButton({
        label = "切替",
        click_function = "toggleDefeatText",
        function_owner = Global,

        position = {0.8, -0.01, -0.55},
        rotation = {0, 0, 180},
        scale = {0.5, 0.5, 0.5},

        width = 300,
        height = 125,
        font_size = 110,

        color = {1, 1, 1, 1},
        font_color = {0, 0, 0, 1},

        tooltip = "手动切换是否敗走"
    })

    -- index 4：正面敗走文字
    obj.createButton({
        label = getDefeatText(state),
        click_function = "null",
        function_owner = Global,

        position = {0, 0.11, 0},
        rotation = {0, 0, 0},
        scale = {0.5, 0.5, 0.5},

        width = 0,
        height = 0,
        font_size = 1500,

        font_color = {1, 1, 1, 1},

        tooltip = ""
    })

    -- index 5：正面切替按钮
    obj.createButton({
        label = "切替",
        click_function = "toggleDefeatText",
        function_owner = Global,

        position = {-0.8, 0.11, -0.55},
        rotation = {0, 0, 0},
        scale = {0.5, 0.5, 0.5},

        width = 300,
        height = 125,
        font_size = 110,

        color = {1, 1, 1, 1},
        font_color = {0, 0, 0, 1},

        tooltip = "手动切换是否敗走"
    })

    -- index 6：正面移动力
    obj.createButton({
        label = tostring(config.front_move),
        click_function = "null",
        function_owner = Global,

        position = {0.75, 0.11, 0.73},
        rotation = {0, 0, 0},
        scale = {0.5, 0.5, 0.5},

        width = 450,
        height = 450,
        font_size = 550,

        color = {1, 1, 1, 1},
        font_color = config.front_number_color,

        tooltip = "移动力：" .. tostring(config.front_move)
    })

    -- index 7：背面移动力
    obj.createButton({
        label = tostring(config.back_move),
        click_function = "null",
        function_owner = Global,

        position = {-0.75, -0.01, 0.73},
        rotation = {0, 0, 180},
        scale = {0.5, 0.5, 0.5},

        width = 450,
        height = 450,
        font_size = 550,

        color = {1, 1, 1, 1},
        font_color = config.back_number_color,

        tooltip = "移动力：" .. tostring(config.back_move)
    })

    -- index 8：正面兵种名
    obj.createButton({
        label = config.name,
        click_function = "null",
        function_owner = Global,

        position = {-0.32, 0.11, -0.81},
        rotation = {0, 0, 0},
        scale = {0.5, 0.5, 0.5},

        width = 0,
        height = 0,
        font_size = 290,

        font_color = config.front_name_color
    })

    -- index 9：背面兵种名
    obj.createButton({
        label = config.name,
        click_function = "null",
        function_owner = Global,

        position = {0.32, -0.01, -0.81},
        rotation = {0, 0, 180},
        scale = {0.5, 0.5, 0.5},

        width = 0,
        height = 0,
        font_size = 290,

        font_color = config.back_name_color
    })

    -- index 10：正面人数
    obj.createButton({
        label = config.count_label,
        click_function = "null",
        function_owner = Global,

        position = {0.19, 0.11, -0.3},
        rotation = {0, 0, 0},
        scale = {0.5, 0.5, 0.5},

        width = 0,
        height = 0,
        font_size = 255,

        font_color = config.front_name_color
    })

    -- index 11：背面人数
    obj.createButton({
        label = config.count_label,
        click_function = "null",
        function_owner = Global,

        position = {-0.19, -0.01, -0.3},
        rotation = {0, 0, 180},
        scale = {0.5, 0.5, 0.5},

        width = 0,
        height = 0,
        font_size = 255,

        font_color = config.back_name_color
    })
end

-- =========================
-- 士气按钮逻辑
-- =========================
function changeFrontValue(obj, _player_color, alt_click)
    local state, config = getStateAndConfig(obj)

    if state == nil then
        return
    end

    local change = alt_click and -1 or 1

    state.front_value = math.min(
        math.max(state.front_value + change, MIN_VALUE),
        config.max_front
    )

    updateFrontButton(obj)
end

function changeBackValue(obj, _player_color, alt_click)
    local state, config = getStateAndConfig(obj)

    if state == nil then
        return
    end

    local change = alt_click and -1 or 1

    state.back_value = math.min(
        math.max(state.back_value + change, MIN_VALUE),
        config.max_back
    )

    updateBackButton(obj)
    updateDefeatText(obj)
end

-- =========================
-- 敗走文字逻辑
-- =========================
function toggleDefeatText(obj)
    local state, _config = getStateAndConfig(obj)

    if state == nil then
        return
    end

    state.manual_defeat_visible = not state.manual_defeat_visible

    updateDefeatText(obj)
end

function getDefeatText(state)
    if state.back_value == 0 or state.manual_defeat_visible then
        return "敗走"
    else
        return ""
    end
end

-- =========================
-- 更新按钮
-- =========================
function updateFrontButton(obj)
    local state, _config = getStateAndConfig(obj)

    if state == nil then
        return
    end

    obj.editButton({
        index = 0,
        label = tostring(state.front_value)
    })
end

function updateBackButton(obj)
    local state, _config = getStateAndConfig(obj)

    if state == nil then
        return
    end

    obj.editButton({
        index = 1,
        label = tostring(state.back_value)
    })
end

function updateDefeatText(obj)
    local state, _config = getStateAndConfig(obj)

    if state == nil then
        return
    end

    local text = getDefeatText(state)

    obj.editButton({
        index = 2,
        label = text
    })

    obj.editButton({
        index = 4,
        label = text
    })
end

function updateCountLabel(obj)
    local state, config = getStateAndConfig(obj)

    if state == nil then
        return
    end

    obj.editButton({
        index = 10,
        label = config.count_label
    })

    obj.editButton({
        index = 11,
        label = config.count_label
    })
end

function resetUnit(obj)
    local state, _config = getStateAndConfig(obj)

    if state == nil then
        return
    end

    state.front_value = 0
    state.back_value = 0
    state.manual_defeat_visible = false

    updateFrontButton(obj)
    updateBackButton(obj)
    updateDefeatText(obj)
end

function null()
end



-- TTS 备队武将面板：任意一枚成员令牌都显示整支备队
--
-- 用于 Global Lua。会生成并替换 Global UI。
-- 第一次请在 Global Lua 和 UI 均为空的测试存档运行。
--
-- 令牌 Description 识别字段（每枚令牌都要有）：
--   team=ota_iwatsuki
--   role=main / deputy1 / deputy2
--   status=健康 / 轻伤 / 重伤
-- 主将令牌另有 order=防御 等命令字段。
-- 令牌正面朝上显示“行动：未”，翻面显示“行动：已”。

-- ===== 全局年份：年龄 = CURRENT_YEAR - birthYear =====
local CURRENT_YEAR = 1563

-- ===== 只需在这里登记备队资料 =====
-- roleLabel 可改成“备大将”“大将”“侍大将”等你采用的称呼。
-- 副将的数值、出生年和图片先留空也可以，面板会显示“—”。
local FORMATIONS = {
    ["ota_iwatsuki"] = {
        title = "太田家 岩付众",
        main = {
            tokenName = "太田资正",
            roleLabel = "备大将",
            name = "太田资正",
            birthYear = 1522,
            command = 5,
            mobility = 9,
            woundedMobility = 4,
            image = "", -- 粘贴完整 Cloud URL
            asset = "sg_ota_sukemasa",
            defaultStatus = "健康"
        },
        deputies = {
            {
                tokenName = "岩付众副将一",
                roleLabel = "副将",
                name = "副将一",
                birthYear = nil,
                command = nil,
                mobility = nil,
                woundedMobility = nil,
                image = "",
                asset = "sg_ota_iwatsuki_deputy1",
                defaultStatus = "健康"
            },
            {
                tokenName = "岩付众副将二",
                roleLabel = "副将",
                name = "副将二",
                birthYear = nil,
                command = nil,
                mobility = nil,
                woundedMobility = nil,
                image = "",
                asset = "sg_ota_iwatsuki_deputy2",
                defaultStatus = "健康"
            }
        }
    }
}

local ORDER_BY_BUTTON = {
    sg_attack = "进攻",
    sg_defend = "防御",
    sg_move = "机动",
    sg_regroup = "重整"
}

local selectedTeamId = nil
local ready = false
local hasImage = {}
local tokenNameIndex = {}
local teamObjectCache = {}

-- Panel 宽 440、高 760。主将画像较大；两名副将并列较小。
-- MiddleRight 是右侧居中；可改为 MiddleLeft / offsetXY="20 0"。
local PANEL_XML = [[
<Panel id="sg_panel" visibility="Host" active="true"
       rectAlignment="MiddleRight" offsetXY="-20 0"
       width="440" height="760" scale="1 1 1"
       color="#20231FF5" raycastTarget="true">
    <Text id="sg_formation" rectAlignment="UpperCenter" offsetXY="0 -12"
          width="350" height="32" fontSize="25" color="#F1E6C8">备队</Text>
    <Button id="sg_close" rectAlignment="UpperRight" offsetXY="-8 -10"
            width="30" height="28" fontSize="18" onClick="sgClose"
            colors="#514832|#756440|#3A3324|#514832" textColor="#FFFFFF">×</Button>

    <Text id="sg_main_role" rectAlignment="UpperCenter" offsetXY="0 -45"
          width="300" height="25" fontSize="17" color="#D6BA73">备大将</Text>
    <Image id="sg_main_portrait" active="false" rectAlignment="UpperCenter"
           offsetXY="0 -70" width="220" height="220"
           preserveAspect="true" raycastTarget="false" />
    <Text id="sg_main_no_image" active="true" rectAlignment="UpperCenter"
          offsetXY="0 -70" width="210" height="220" fontSize="18"
          color="#D8CEB4" horizontalOverflow="Wrap">画像未登记</Text>
    <Text id="sg_main_name" rectAlignment="UpperCenter" offsetXY="0 -303"
          width="350" height="30" fontSize="24" color="#F1E6C8">大将</Text>
    <Text id="sg_main_info" rectAlignment="UpperCenter" offsetXY="0 -337"
          width="390" height="58" fontSize="17" color="#F1E6C8"
          horizontalOverflow="Wrap">年龄：—    统率：—
机动：—</Text>
    <Text id="sg_main_action" rectAlignment="UpperCenter" offsetXY="-100 -401"
          width="180" height="25" fontSize="17" color="#CFE3C2">行动：未</Text>
    <Text id="sg_main_status" rectAlignment="UpperCenter" offsetXY="100 -401"
          width="180" height="25" fontSize="17" color="#E5C982">状态：健康</Text>

    <Panel id="sg_deputy1_card" rectAlignment="UpperCenter" offsetXY="-108 -445"
           width="202" height="204" color="#2A2C27F0" raycastTarget="false">
        <Text id="sg_deputy1_role" rectAlignment="UpperCenter" offsetXY="0 -9"
              width="180" height="22" fontSize="15" color="#D6BA73">副将</Text>
        <Image id="sg_deputy1_portrait" active="false" rectAlignment="UpperCenter"
               offsetXY="0 -34" width="94" height="94" preserveAspect="true"
               raycastTarget="false" />
        <Text id="sg_deputy1_no_image" active="true" rectAlignment="UpperCenter"
              offsetXY="0 -34" width="90" height="94" fontSize="13"
              color="#D8CEB4">未登记画像</Text>
        <Text id="sg_deputy1_name" rectAlignment="UpperCenter" offsetXY="0 -138"
              width="185" height="23" fontSize="17" color="#F1E6C8">副将一</Text>
        <Text id="sg_deputy1_info" rectAlignment="UpperCenter" offsetXY="0 -163"
              width="190" height="30" fontSize="12" color="#F1E6C8"
              horizontalOverflow="Wrap">年龄：—  统率：—
机动：—</Text>
        <Text id="sg_deputy1_action" rectAlignment="UpperCenter" offsetXY="-49 -190"
              width="92" height="20" fontSize="12" color="#CFE3C2">行动：未</Text>
        <Text id="sg_deputy1_status" rectAlignment="UpperCenter" offsetXY="49 -190"
              width="92" height="20" fontSize="12" color="#E5C982">状态：健康</Text>
    </Panel>

    <Panel id="sg_deputy2_card" rectAlignment="UpperCenter" offsetXY="108 -445"
           width="202" height="204" color="#2A2C27F0" raycastTarget="false">
        <Text id="sg_deputy2_role" rectAlignment="UpperCenter" offsetXY="0 -9"
              width="180" height="22" fontSize="15" color="#D6BA73">副将</Text>
        <Image id="sg_deputy2_portrait" active="false" rectAlignment="UpperCenter"
               offsetXY="0 -34" width="94" height="94" preserveAspect="true"
               raycastTarget="false" />
        <Text id="sg_deputy2_no_image" active="true" rectAlignment="UpperCenter"
              offsetXY="0 -34" width="90" height="94" fontSize="13"
              color="#D8CEB4">未登记画像</Text>
        <Text id="sg_deputy2_name" rectAlignment="UpperCenter" offsetXY="0 -138"
              width="185" height="23" fontSize="17" color="#F1E6C8">副将二</Text>
        <Text id="sg_deputy2_info" rectAlignment="UpperCenter" offsetXY="0 -163"
              width="190" height="30" fontSize="12" color="#F1E6C8"
              horizontalOverflow="Wrap">年龄：—  统率：—
机动：—</Text>
        <Text id="sg_deputy2_action" rectAlignment="UpperCenter" offsetXY="-49 -190"
              width="92" height="20" fontSize="12" color="#CFE3C2">行动：未</Text>
        <Text id="sg_deputy2_status" rectAlignment="UpperCenter" offsetXY="49 -190"
              width="92" height="20" fontSize="12" color="#E5C982">状态：健康</Text>
    </Panel>

    <Text id="sg_order" rectAlignment="UpperCenter" offsetXY="0 -670"
          width="390" height="28" fontSize="20" color="#E5C982">当前命令：—</Text>
    <Button id="sg_attack" rectAlignment="UpperCenter" offsetXY="-129 -710"
            width="76" height="34" fontSize="16" onClick="sgSetOrder"
            colors="#514832|#756440|#3A3324|#514832" textColor="#FFFFFF">进攻</Button>
    <Button id="sg_defend" rectAlignment="UpperCenter" offsetXY="-43 -710"
            width="76" height="34" fontSize="16" onClick="sgSetOrder"
            colors="#514832|#756440|#3A3324|#514832" textColor="#FFFFFF">防御</Button>
    <Button id="sg_move" rectAlignment="UpperCenter" offsetXY="43 -710"
            width="76" height="34" fontSize="16" onClick="sgSetOrder"
            colors="#514832|#756440|#3A3324|#514832" textColor="#FFFFFF">机动</Button>
    <Button id="sg_regroup" rectAlignment="UpperCenter" offsetXY="129 -710"
            width="76" height="34" fontSize="16" onClick="sgSetOrder"
            colors="#514832|#756440|#3A3324|#514832" textColor="#FFFFFF">重整</Button>
</Panel>
]]

local function isHost(player)
    return player ~= nil and player.host == true
end

-- 不使用 (.-) 裁剪长文本，避免 MoonSharp 的 pattern too complex。
local function trim(value)
    return ((value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- 从 Description 读取 team、role、status、order 等短字段。
-- 只匹配字段开头，字段值用 sub 取出，不对长值做非贪婪回溯。
local function readField(description, key)
    for line in (description or ""):gmatch("[^\r\n]+") do
        local _, prefixEnd = line:find("^%s*" .. key .. "%s*=")
        if prefixEnd then return trim(line:sub(prefixEnd + 1)) end
    end
    return nil
end

local function memberProfile(formation, role)
    if not formation then return nil end
    if role == "main" then return formation.main end
    if role == "deputy1" then return formation.deputies[1] end
    if role == "deputy2" then return formation.deputies[2] end
    return nil
end

local function memberRoles()
    return {"main", "deputy1", "deputy2"}
end

local function buildTokenNameIndex()
    tokenNameIndex = {}
    for teamId, formation in pairs(FORMATIONS) do
        tokenNameIndex[trim(formation.main.tokenName)] = {team = teamId, role = "main"}
        tokenNameIndex[trim(formation.deputies[1].tokenName)] = {team = teamId, role = "deputy1"}
        tokenNameIndex[trim(formation.deputies[2].tokenName)] = {team = teamId, role = "deputy2"}
    end
end

local function identifyToken(object)
    if object == nil then return nil, nil end
    local team = readField(object.getDescription(), "team")
    local role = readField(object.getDescription(), "role")
    -- 只要有有效 team，就允许普通部队令牌也打开整队面板；
    -- main/deputy1/deputy2 用于寻找三名武将，unit 只用于识别所属备队。
    if team and FORMATIONS[team] then
        return team, role
    end
    local fallback = tokenNameIndex[trim(object.getName())]
    if fallback then return fallback.team, fallback.role end
    return nil, nil
end

local function actionText(object)
    if object == nil then return "行动：未找到令牌" end
    if object.is_face_down == true then return "行动：已" end
    return "行动：未"
end

local function statusText(object, profile)
    if object == nil then return "未放置" end
    return readField(object.getDescription(), "status") or profile.defaultStatus or "健康"
end

local function ageText(profile)
    if type(profile.birthYear) == "number" then
        return tostring(CURRENT_YEAR - profile.birthYear)
    end
    return "—"
end

local function statText(value)
    if value == nil then return "—" end
    return tostring(value)
end

local function infoText(profile)
    local mobility = statText(profile.mobility)
    local wounded = statText(profile.woundedMobility)
    return "年龄：" .. ageText(profile) .. "  统率：" .. statText(profile.command)
        .. "\n机动：" .. mobility .. "（受伤时 " .. wounded .. "）"
end

local function cacheObject(teamId, role, object)
    if not teamId or not role or not object then return end
    teamObjectCache[teamId] = teamObjectCache[teamId] or {}
    teamObjectCache[teamId][role] = object.getGUID()
end

local function objectFromCache(teamId, role)
    local cache = teamObjectCache[teamId]
    if not cache or not cache[role] then return nil end
    local object = getObjectFromGUID(cache[role])
    if object == nil then cache[role] = nil end
    return object
end

-- 第一次查看某支备队时扫描全桌；找到后缓存 GUID，之后翻面刷新不会反复扫描。
local function locateTeam(teamId, hoveredObject)
    local formation = FORMATIONS[teamId]
    if not formation then return {} end
    local result = {}
    for _, role in ipairs(memberRoles()) do
        result[role] = objectFromCache(teamId, role)
    end
    local hoveredTeam, hoveredRole = identifyToken(hoveredObject)
    if hoveredTeam == teamId and hoveredRole then
        result[hoveredRole] = hoveredObject
        cacheObject(teamId, hoveredRole, hoveredObject)
    end

    local missing = false
    for _, role in ipairs(memberRoles()) do
        if result[role] == nil then missing = true end
    end
    if missing then
        for _, object in ipairs(getObjects()) do
            local foundTeam, foundRole = identifyToken(object)
            if foundTeam == teamId and foundRole
                and memberProfile(formation, foundRole)
                and result[foundRole] == nil then
                result[foundRole] = object
                cacheObject(teamId, foundRole, object)
            end
            if result.main and result.deputy1 and result.deputy2 then break end
        end
    end
    return result
end

local function setPersonUI(prefix, profile, object, main)
    if not profile then return end
    UI.setValue(prefix .. "_role", profile.roleLabel or (main and "备大将" or "副将"))
    UI.setValue(prefix .. "_name", profile.name or "未命名")
    UI.setValue(prefix .. "_info", infoText(profile))
    UI.setValue(prefix .. "_action", actionText(object))
    UI.setValue(prefix .. "_status", "状态：" .. statusText(object, profile))

    local available = hasImage[profile.asset] == true
    UI.setAttribute(prefix .. "_portrait", "active", available and "true" or "false")
    UI.setAttribute(prefix .. "_no_image", "active", available and "false" or "true")
    if available then
        UI.setAttribute(prefix .. "_portrait", "image", profile.asset)
    end
end

local function renderTeam(teamId, hoveredObject)
    local formation = FORMATIONS[teamId]
    if not formation or not ready or UI.loading then return end
    selectedTeamId = teamId
    local objects = locateTeam(teamId, hoveredObject)
    UI.setAttribute("sg_panel", "active", "true")
    UI.setValue("sg_formation", formation.title)
    setPersonUI("sg_main", formation.main, objects.main, true)
    setPersonUI("sg_deputy1", formation.deputies[1], objects.deputy1, false)
    setPersonUI("sg_deputy2", formation.deputies[2], objects.deputy2, false)
    if objects.main then
        UI.setValue("sg_order", "当前命令：" .. (readField(objects.main.getDescription(), "order") or "未设置"))
    else
        UI.setValue("sg_order", "当前命令：未找到备大将令牌")
    end
end

function initTeamPanel()
    ready = false
    selectedTeamId = nil
    hasImage = {}
    teamObjectCache = {}
    buildTokenNameIndex()
    local assets = {}
    for _, formation in pairs(FORMATIONS) do
        local profiles = {formation.main, formation.deputies[1], formation.deputies[2]}
        for _, profile in ipairs(profiles) do
            local url = trim(profile.image)
            if url:match("^https?://") then
                table.insert(assets, {name = profile.asset, url = url})
                hasImage[profile.asset] = true
            end
        end
    end
    UI.setXml(PANEL_XML, assets)
    Wait.frames(function()
        Wait.condition(function()
            ready = true
            print("[备队面板] 已就绪。请指向带有 team= 和 role= 的任一令牌。")
        end, function()
            return not UI.loading
        end, 30, function()
            ready = true
            print("[备队面板] 载入超过30秒。可先清空图片URL检查令牌识别。");
        end)
    end, 1)
end

function onObjectHover(player_color, object)
    if not ready or object == nil then return end
    if not isHost(Player[player_color]) then return end
    local teamId = identifyToken(object)
    if teamId then renderTeam(teamId, object) end
end

-- 令牌翻面后立即刷新已显示备队的行动状态。
function onObjectRotate(object, spin, flip, player_color, old_spin, old_flip)
    if not ready or object == nil or selectedTeamId == nil then return end
    local teamId = identifyToken(object)
    if teamId == selectedTeamId then renderTeam(teamId, object) end
end

function sgSetOrder(player, value, id)
    if not isHost(player) or not ready or UI.loading or not selectedTeamId then return end
    local order = ORDER_BY_BUTTON[id]
    if not order then return end
    local objects = locateTeam(selectedTeamId, nil)
    if not objects.main then
        UI.setValue("sg_order", "未找到备大将令牌")
        return
    end
    local description = (objects.main.getDescription() or ""):gsub("\r\n", "\n")
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
    objects.main.setDescription(table.concat(lines, "\n"))
    renderTeam(selectedTeamId, objects.main)
end

function sgClose(player)
    if isHost(player) and ready and not UI.loading then
        UI.setAttribute("sg_panel", "active", "false")
    end
end

