-- BEGIN MAP FLAGS MODULE
-- 地图陣旗：部队用双面常显贴花；主副将沿用各玩家独立的 Object.UI。
-- 不生成物件、不占碰撞体、不拦截鼠标；只维护自己的 UI/贴花。
-- 接口：sgMapInit(); sgMapUpdate(byGUID, views); sgMapForget(guid)
-- byGUID[guid] = {object=物件, team=隊ID, role=main/unit/..., url=主将flag_image}
-- views[color] = {hoverGUID=guid, hoverTeam=隊ID, flagTeam=手动展开的隊ID}
-- XML/assets 仅在首次挂载/卸载时合并；之后差量修改 sgmf_ 自有节点。
-- 官方 API：https://api.tabletopsimulator.com/ui/ /ui/attributes/ /object/
-- Object.UI 的像素换算与默认平面轴向需要实机校准；下列常数集中调整。
local MAP_FLAG_BIG_HEIGHT = 0.80 -- 大旗高 / 棋子短边
local MAP_FLAG_SMALL_HEIGHT = 0.45 -- 全队小旗高 / 棋子短边
-- 部队棋面内旗：右边缘与数值栏分隔线留 24px；武将叠放时允许遮挡。
-- 部队旗固定 270×720px（1200 方形底图），不会随悬停或展开改变大小。
local MAP_FLAG_UNIT_HEIGHT = 720 / 1200
local MAP_FLAG_UNIT_RIGHT_EDGE = 976 / 1200
local MAP_FLAG_UNIT_CENTER_Y = 700 / 1200
local MAP_FLAG_ASPECT = 3 / 8
local MAP_FLAG_SIDE_GAP = 0.04 -- 旗与棋子右侧的间隙 / 棋子短边
local MAP_FLAG_LIFT = 0.03 -- 离棋子上表面的世界单位距离
local MAP_FLAG_UI_UNITS = 100 -- Object.UI 像素 / 物件局部单位
local MAP_FLAG_ROOT = "sgmf_root"
local MAP_FLAG_ASSET = "sgmf_flag"
local MAP_FLAG_FRONT_DECAL = "SG_UNIT_FLAG_FRONT"
local MAP_FLAG_BACK_DECAL = "SG_UNIT_FLAG_BACK"
local MAP_FLAG_COLORS = {
    "White", "Brown", "Red", "Orange", "Yellow", "Green",
    "Teal", "Blue", "Purple", "Pink", "Grey", "Black"
}
local mapFlagRecords = {}

local function sgMFNum(value, fallback)
    local n = tonumber(value)
    if n == nil or n ~= n or n == math.huge or n == -math.huge then return fallback end
    return n
end

local function sgMFCoord(vector, key, index, fallback)
    if vector == nil then return fallback end
    return sgMFNum(vector[key] or vector[index], fallback)
end

local function sgMFString(n)
    if math.abs(n) < 0.0005 then n = 0 end
    return string.format("%.3f", n)
end

local function sgMFPosition(x, y, z)
    return sgMFString(x) .. " " .. sgMFString(y) .. " " .. sgMFString(z)
end

local function sgMFOwnID(id)
    return type(id) == "string" and id:sub(1, 5) == "sgmf_"
end

-- getXmlTable() 返回当前运行时内容；不把启动时的旧副本写回第三方 UI。
local function sgMFStripOwned(nodes)
    local result, removed = {}, false
    for _, node in ipairs(nodes or {}) do
        if sgMFOwnID(node.attributes and node.attributes.id) then
            removed = true
        else
            if type(node.children) == "table" then
                local children, changed = sgMFStripOwned(node.children)
                if changed then node.children = children; removed = true end
            end
            table.insert(result, node)
        end
    end
    return result, removed
end

local function sgMFAssets(ui, url)
    local current = ui.getCustomAssets() or {}
    local result, matching, ownCount, changed = {}, false, 0, false
    for _, asset in ipairs(current) do
        if sgMFOwnID(asset.name) then
            ownCount = ownCount + 1
            if asset.name == MAP_FLAG_ASSET and asset.url == url then matching = true end
        else
            table.insert(result, asset)
        end
    end
    if url and url ~= "" then
        table.insert(result, {name=MAP_FLAG_ASSET, url=url})
        changed = ownCount ~= 1 or not matching
    else
        changed = ownCount ~= 0
    end
    return result, changed
end

local function sgMFObjectReady(object, requireUI)
    if object == nil then return false, true end
    if object.isDestroyed and object.isDestroyed() then return false, true end
    if object.spawning or object.loading_custom then return false, false end
    if requireUI ~= false and (object.UI == nil or object.UI.loading) then return false, false end
    return true, false
end

local function sgMFScale(object)
    local scale = object.getScale()
    local x = math.abs(sgMFCoord(scale, "x", 1, 1))
    local y = math.abs(sgMFCoord(scale, "y", 2, 1))
    local z = math.abs(sgMFCoord(scale, "z", 3, 1))
    if x < 0.0001 or y < 0.0001 or z < 0.0001 then return nil end
    return {x=x,y=y,z=z}, sgMFPosition(x,y,z)
end

local function sgMFGeometry(record, object, refreshSurface)
    local scale, signature = sgMFScale(object)
    if not scale then return nil end
    if not refreshSurface and record.geometry and signature == record.scaleSignature then return record.geometry end
    local bounds
    -- 碰撞体不包含 Object.UI 或贴花，避免旧显示层污染宽高与表面高度。
    if object.getBoundsNormalized then
        local ok, value = pcall(function() return object.getBoundsNormalized() end)
        if ok then bounds = value end
    end
    if (type(bounds) ~= "table" or bounds.size == nil) and object.getVisualBoundsNormalized then
        local ok, value = pcall(function() return object.getVisualBoundsNormalized() end)
        if ok then bounds = value end
    end
    if type(bounds) ~= "table" or bounds.size == nil then return nil end
    local size = bounds.size
    local sx = sgMFCoord(size, "x", 1, 0)
    local sy = sgMFCoord(size, "y", 2, 0)
    local sz = sgMFCoord(size, "z", 3, 0)
    if sx <= 0 or sy < 0 or sz <= 0 then return nil end
    local offset = bounds.offset
    local geometry = {
        sizeX=sx, sizeY=sy, sizeZ=sz, short=math.min(sx,sz), scale=scale,
        offsetX=sgMFCoord(offset,"x",1,0),
        offsetY=sgMFCoord(offset,"y",2,0),
        offsetZ=sgMFCoord(offset,"z",3,0)
    }
    record.geometry, record.scaleSignature = geometry, signature
    return geometry
end

local function sgMFOwnDecal(name)
    return name == MAP_FLAG_FRONT_DECAL or name == MAP_FLAG_BACK_DECAL
end

local function sgMFSameDecal(left, right)
    if left.name ~= right.name or left.url ~= right.url then return false end
    for _, field in ipairs({"position", "rotation", "scale"}) do
        for index, axis in ipairs({"x", "y", "z"}) do
            local difference = sgMFCoord(left[field],axis,index,-99999)
                - sgMFCoord(right[field],axis,index,99999)
            if field == "rotation" then difference = (difference + 180) % 360 - 180 end
            if math.abs(difference) > 0.0005 then return false end
        end
    end
    return true
end

local function sgMFSyncDecals(object, wanted)
    if not object.getDecals or not object.setDecals then return end
    local retained, seen, changed = {}, {}, false
    -- 每次从实时列表合并：保留数字、敗走、済印以及玩家添加的其他贴花。
    for _, decal in ipairs(object.getDecals() or {}) do
        if sgMFOwnDecal(decal.name) then
            if seen[decal.name] or not wanted[decal.name]
                or not sgMFSameDecal(decal,wanted[decal.name]) then changed = true end
            seen[decal.name] = true
        else
            table.insert(retained,decal)
        end
    end
    for _, name in ipairs({MAP_FLAG_FRONT_DECAL,MAP_FLAG_BACK_DECAL}) do
        if wanted[name] then
            table.insert(retained,wanted[name])
            if not seen[name] then changed = true end
        end
    end
    if changed then object.setDecals(retained) end
end

local function sgMFUnitDecals(geometry, url)
    local wanted, scale = {}, geometry.scale
    -- getBoundsNormalized 返回消除旋转但保留缩放的尺寸；贴花参数需要局部坐标。
    local width, depth = geometry.sizeX / scale.x, geometry.sizeZ / scale.z
    local cx, cy, cz = geometry.offsetX / scale.x, geometry.offsetY / scale.y, geometry.offsetZ / scale.z
    local halfHeight = geometry.sizeY / scale.y / 2
    local flagHeight = depth * MAP_FLAG_UNIT_HEIGHT
    local flagWidth = width * MAP_FLAG_UNIT_HEIGHT * MAP_FLAG_ASPECT
    for _, back in ipairs({false,true}) do
        local name = back and MAP_FLAG_BACK_DECAL or MAP_FLAG_FRONT_DECAL
        local direction = back and -1 or 1
        -- 与数字/敗走共用两项校准值；独立武将脚本也有相同默认值。
        local gap = back and sgMFNum(UNIT_DEFEAT_BACK_GAP,-0.09)
            or sgMFNum(UNIT_DEFEAT_FRONT_GAP,-0.01)
        wanted[name] = {
            name=name,url=url,
            position={cx - direction * (width * (MAP_FLAG_UNIT_RIGHT_EDGE - 0.5) - flagWidth / 2),
                cy + direction * (halfHeight + gap + math.max(0,sgMFNum(UNIT_SURFACE_CLEARANCE,0.01))),
                cz + depth * (MAP_FLAG_UNIT_CENTER_Y - 0.5)},
            rotation=back and {270,0,0} or {90,180,0},
            scale={flagWidth,flagHeight,0.1}
        }
    end
    return wanted
end

local function sgMFVisibility(entry, guid, views)
    if entry.role == "main" then return true, "", false, "" end
    local big, small = {}, {}
    for _, color in ipairs(MAP_FLAG_COLORS) do
        local view = views[color]
        if view then
            if view.hoverGUID == guid then
                table.insert(big, color)
            elseif view.flagTeam ~= nil and view.flagTeam == entry.team then
                table.insert(small, color)
            end
        end
    end
    return #big > 0, table.concat(big,"|"), #small > 0, table.concat(small,"|")
end

local function sgMFImageAttributes(geometry, faceDown, ratio, active, visibility, imageURL)
    local height = geometry.short * ratio
    local width = height * MAP_FLAG_ASPECT
    local direction = faceDown and -1 or 1
    -- 以物件正前方作为读图方向。翻面时反转局部 X 与法线，补偿背面镜像。
    local x = geometry.offsetX + direction * (geometry.sizeX / 2
        + geometry.short * MAP_FLAG_SIDE_GAP + width / 2)
    local y = geometry.offsetY + direction * (geometry.sizeY / 2 + MAP_FLAG_LIFT)
    local z = geometry.offsetZ - geometry.sizeZ / 2 + height / 2
    local u, scale = MAP_FLAG_UI_UNITS, geometry.scale
    return {
        active=active and "true" or "false", visibility=visibility,
        -- 与已正常显示的 Global 侧栏一致，直接引用完整 URL。
        -- sgmf_flag 仍登记为资源，但不依赖同名资源在重载后自动绑定到 Image。
        image=imageURL, preserveAspect="true", color="#FFFFFF",
        raycastTarget="false", tooltip="", rectAlignment="MiddleCenter",
        width=sgMFString(width / scale.x * u),
        height=sgMFString(height / scale.z * u),
        position=sgMFPosition(x / scale.x * u, z / scale.z * u, -y / scale.y * u),
        rotation=faceDown and "0 180 0" or "0 0 0", scale="1 1 1"
    }
end

local function sgMFCreateRoot(big, small)
    big.id, small.id = "sgmf_big", "sgmf_small"
    return {
        tag="Panel",
        attributes={id=MAP_FLAG_ROOT,width="1",height="1",position="0 0 0",
            rotation="0 0 0",scale="1 1 1",rectAlignment="MiddleCenter",
            color="#FFFFFF00",raycastTarget="false",active="true",tooltip=""},
        children={{tag="Image",attributes=big},{tag="Image",attributes=small}}
    }
end

local function sgMFApplyAttributes(ui, id, wanted, old)
    local changed = {}
    for name, value in pairs(wanted) do
        if name ~= "id" and (old == nil or old[name] ~= value) then changed[name] = value end
    end
    if next(changed) ~= nil then ui.setAttributes(id, changed) end
    return wanted
end

local function sgMFCleanupUI(record)
    if record.object and record.object.UI == nil then return true end
    local ready, destroyed = sgMFObjectReady(record.object)
    if destroyed then return true end
    if not ready then return false end
    local ui = record.object.UI
    local xml, removed = sgMFStripOwned(ui.getXmlTable() or {})
    local assets, changed = sgMFAssets(ui, nil)
    if changed then
        ui.setCustomAssets(assets)
        return false
    end
    if removed then
        -- 资源与 XML 分步更新，兼容不处理第二参数的安装版。
        if #xml==0 then ui.setXml("") else ui.setXmlTable(xml) end
    end
    return true
end

local function sgMFCleanup(record)
    local ready, destroyed = sgMFObjectReady(record.object,false)
    if destroyed then return true end
    if not ready then return false end
    sgMFSyncDecals(record.object,{})
    record.unitDecals = false
    return sgMFCleanupUI(record)
end

local function sgMFUpdateRecord(record, guid, entry, views)
    local ready, destroyed = sgMFObjectReady(record.object,false)
    if destroyed then return true end
    if not ready then return false end
    if entry == nil then
        return sgMFCleanup(record)
    end
    if type(entry.url) ~= "string" or entry.url == "" then
        if record.mounted or record.unitDecals or not record.inspected then
            if not sgMFCleanup(record) then return false end
            record.mounted,record.inspected,record.assetURL = false,true,nil
            record.big,record.small = nil,nil
        end
        return false
    end
    if entry.role == "unit" then
        -- 升级时移除旧 sgmf_ 悬浮节点；其余 UI 与资源保持原样。
        if record.mounted or not record.inspected then
            if sgMFCleanupUI(record) then
                record.mounted,record.inspected,record.assetURL = false,true,nil
                record.big,record.small = nil,nil
            end
        end
        -- 部队旗不依赖 Object.UI 加载；旧 UI 尚在加载时，下轮再清理它。
        -- Custom Tile 加载后仍会更新碰撞边界；缩放不变并不代表表面高度不变。
        -- 部队旗与数字使用当前边界计算正背面，不能永久沿用首次读到的高度。
        local geometry = sgMFGeometry(record,record.object,true)
        if geometry then
            sgMFSyncDecals(record.object,sgMFUnitDecals(geometry,entry.url))
            record.unitDecals = true
        end
        return false
    end
    -- 标签/描述把部队改为将领时，同时清掉读档遗留的双面部队旗。
    if record.unitDecals or not record.inspected then
        sgMFSyncDecals(record.object,{})
        record.unitDecals = false
    end
    if not sgMFObjectReady(record.object) then return false end
    local ui = record.object.UI
    if record.mounted then
        -- 物件自己的脚本可能重建 XML；从当前界面重新合并，不写回旧快照。
        for _, id in ipairs({MAP_FLAG_ROOT, "sgmf_big", "sgmf_small"}) do
            local ok, value = pcall(function() return ui.getAttribute(id, "active") end)
            if not ok or value == nil or value == "" then
                record.mounted, record.big, record.small = false, nil, nil
                break
            end
        end
    end
    local bigActive,bigVisibility,smallActive,smallVisibility = sgMFVisibility(entry,guid,views)
    -- 未展开的普通棋子不建立 UI；若存档已有旧节点，第一次检查时清掉。
    if not record.mounted and not bigActive and not smallActive then
        if not record.inspected then
            if not sgMFCleanup(record) then return false end
            record.inspected = true
        end
        return false
    end
    local geometry = sgMFGeometry(record, record.object)
    if geometry == nil then return false end
    local faceDown = record.object.is_face_down == true
    local big = sgMFImageAttributes(geometry,faceDown,MAP_FLAG_BIG_HEIGHT,bigActive,bigVisibility,entry.url)
    local small = sgMFImageAttributes(geometry,faceDown,MAP_FLAG_SMALL_HEIGHT,smallActive,smallVisibility,entry.url)
    if not record.mounted then
        local xml = sgMFStripOwned(ui.getXmlTable() or {})
        table.insert(xml, sgMFCreateRoot(big,small))
        local assets, changed = sgMFAssets(ui,entry.url)
        if changed then
            ui.setCustomAssets(assets)
            return false
        end
        ui.setXmlTable(xml)
        record.mounted, record.inspected, record.assetURL = true,true,entry.url
        -- setXmlTable 异步生效；提交 XML 不代表图片已经绑定。
        -- 下次 Object.UI.loading 为 false 后，按届时最新视图重写一次自有属性。
        record.big,record.small = nil,nil
        return false
    end
    if record.assetURL ~= entry.url then
        local assets, changed = sgMFAssets(ui,entry.url)
        if changed then ui.setCustomAssets(assets) end
        record.assetURL = entry.url
        record.big,record.small = nil,nil
        -- 新画像资源加载期间不写节点；下一次更新使用最新视图，不排队旧视图。
        if ui.loading then return false end
    end
    record.big = sgMFApplyAttributes(ui,"sgmf_big",big,record.big)
    record.small = sgMFApplyAttributes(ui,"sgmf_small",small,record.small)
    return false
end

function sgMapInit()
    mapFlagRecords = {}
    -- 兼容读档后标签已删、URL已清的旧挂载节点；只检查一次，不覆盖第三方 UI。
    for _, object in ipairs(getAllObjects()) do
        local ok,guid = pcall(function() return object.getGUID() end)
        if ok and guid then mapFlagRecords[guid] = {object=object} end
    end
end

function sgMapUpdate(snapshot, views)
    snapshot, views = snapshot or {}, views or {}
    for guid, entry in pairs(snapshot) do
        if entry.object ~= nil then
            local record = mapFlagRecords[guid]
            if record == nil or record.object ~= entry.object then
                record = {object=entry.object}
                mapFlagRecords[guid] = record
            end
        end
    end
    local completed = {}
    for guid, record in pairs(mapFlagRecords) do
        local ok, remove = pcall(function()
            return sgMFUpdateRecord(record,guid,snapshot[guid],views)
        end)
        if ok and remove then table.insert(completed,guid) end
        if not ok and record.lastError ~= tostring(remove) then
            record.lastError = tostring(remove)
            print("[地図陣旗] " .. guid .. "：" .. record.lastError .. "；可在资源加载后点击更新。")
        elseif ok then
            record.lastError = nil
        end
        -- 失败留到下次，不能中断全局面板；相同错误只报告一次。
    end
    for _,guid in ipairs(completed) do mapFlagRecords[guid] = nil end
end

function sgMapForget(guid)
    local record = mapFlagRecords[guid]
    if record == nil then return end
    local ok,done = pcall(function() return sgMFCleanup(record) end)
    if ok and done then mapFlagRecords[guid] = nil end
    -- 正在 loading 的物件下次 sgMapUpdate 无 snapshot 时会完成清理。
end
-- END MAP FLAGS MODULE
