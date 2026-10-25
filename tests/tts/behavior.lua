-- 开发用 TTS API 模拟；不导入游戏。
local checks, scans, changes = 0, 0, 0
local objects, frames, conditions, delays, timers = {}, {}, {}, {}, {}
local nextTimer = 0
local hotkeys, hotkeyRegistrations = {}, {}
addHotkey = function(label,callback,triggerOnKeyUp)
    assert(type(label)=="string" and type(callback)=="function","addHotkey requires a label and callback")
    hotkeys[label]={callback=callback,triggerOnKeyUp=triggerOnKeyUp}
    hotkeyRegistrations[#hotkeyRegistrations+1]={label=label,triggerOnKeyUp=triggerOnKeyUp}
end
local STAMP_URL = "https://steamusercontent-a.akamaihd.net/ugc/16127482967476073358/AB4E3857AE6ECD0830ECE8C32682AE244709D8B5/"
local STAMP_NAME = "SG_済_背面"
local function eq(actual, expected, message)
    if actual ~= expected then error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
    checks = checks + 1
end
Player = {White = {host = true, color = "White"}, Red = {host = false, color = "Red"}, Blue = {host = false, color = "Blue"}, Grey = {host = false, color = "Grey"}, Black = {host = false, color = "Black"}}
Global = {}
UI = {loading=false, values={}, attributes={}, attributeWrites={}, assets={{name="other",url="https://example.invalid/other.png"}}, xmlCalls=0, assetCalls=0}
UI.getCustomAssets = function() return UI.assets end
UI.setXml = function(xml, assets)
    UI.xml, UI.assets, UI.values, UI.attributes = xml, assets, {}, {}
    UI.buttons = {}
    for element in xml:gmatch("<Button[^>]*>") do
        local id = element:match('id="([^"]+)"')
        local callback = element:match('onClick="([^"]+)"')
        if id and callback then UI.buttons[id] = callback end
    end
    UI.xmlCalls = UI.xmlCalls + 1
end
UI.setCustomAssets = function(assets)
    UI.assets = assets
    UI.assetCalls = UI.assetCalls + 1
    UI.loading = UI.holdAssets == true
end
UI.setValue = function(id,value)
    assert(not id:match("_command_bar$"), "Command bar Panel cannot receive text: " .. id)
    UI.values[id]=value; changes=changes+1
end
UI.setAttribute = function(id,key,value)
    UI.attributes[id]=UI.attributes[id] or {}
    UI.attributes[id][key]=value
    local field=id..":"..key
    UI.attributeWrites[field]=(UI.attributeWrites[field] or 0)+1
    changes=changes+1
end
Wait = {}
Wait.frames = function(callback) table.insert(frames,callback) end
Wait.condition = function(callback,condition,timeout,failure) table.insert(conditions,{callback=callback,condition=condition,failure=failure}) end
Wait.time = function(callback,seconds,repeats)
    nextTimer=nextTimer+1
    if repeats == -1 then timers[nextTimer]=callback else table.insert(delays,callback) end
    return nextTimer
end
Wait.stop = function(id) timers[id]=nil end
local function flush()
    for step=1,50 do
        local work=false
        local batch=frames; frames={}
        for _,callback in ipairs(batch) do callback(); work=true end
        local pending=conditions; conditions={}
        for _,item in ipairs(pending) do
            if item.condition() then item.callback(); work=true else table.insert(conditions,item) end
        end
        if not work then return end
    end
    error("Runaway UI callbacks")
end
local function tick()
    local pending=delays; delays={}
    for _,callback in ipairs(pending) do callback() end
    for _,callback in pairs(timers) do callback() end
    flush()
end
print=function() end
getObjectFromGUID=function(guid) return objects[guid] end
getAllObjects=function()
    scans=scans+1
    local result={}
    for _,object in pairs(objects) do table.insert(result,object) end
    return result
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}
    for key,item in pairs(value) do result[key]=copy(item) end
    return result
end
local saveSlot
Global.decals,Global.decalReads,Global.decalWrites={ },0,0
Global.getDecals=function() Global.decalReads=Global.decalReads+1; return copy(Global.decals) end
Global.setDecals=function(decals) Global.decals=copy(decals); Global.decalWrites=Global.decalWrites+1 end
JSON={encode=function(value) saveSlot=copy(value); return "saved" end, decode=function() return copy(saveSlot) end}
local function findNode(nodes,id)
    for _,node in ipairs(nodes or {}) do
        if node.attributes and node.attributes.id == id then return node end
        local child=findNode(node.children,id)
        if child then return child end
    end
end
local function objectUI()
    local ui={loading=false,xmlTable={},assets={},xmlCalls=0,assetCalls=0,attributeCalls=0,imageWrites={},attributeLog={}}
    ui.getXmlTable=function() return copy(ui.xmlTable) end
    ui.setXmlTable=function(xml,assets)
        assert(type(xml)=="table" and #xml>0,"installed TTS setXmlTable rejects an empty Lua table; use setXml('')")
        ui.xmlTable=copy(xml); ui.xmlCalls=ui.xmlCalls+1
        -- Installed TTS ignores extra assets here; resources must use setCustomAssets().
    end
    ui.setXml=function(xml,assets)
        assert(xml=="","Object.UI test mock supports setXml only for clearing all XML")
        ui.xmlTable={}; ui.xmlCalls=ui.xmlCalls+1
        -- Installed TTS ignores extra assets here; resources must use setCustomAssets().
    end
    ui.getCustomAssets=function() return copy(ui.assets) end
    ui.setCustomAssets=function(assets)
        ui.assets=copy(assets); ui.assetCalls=ui.assetCalls+1; ui.loading=ui.holdAssets == true
    end
    ui.getAttribute=function(id,key)
        assert(#ui.xmlTable>0,"Object reference not set to an instance of an object: cold Object.UI has no XmlLayout")
        local node=findNode(ui.xmlTable,id)
        return node and node.attributes and node.attributes[key]
    end
    ui.setAttribute=function(id,key,value)
        assert(not (id:sub(1,5)=="sgub_" and key=="id"),"back UI node IDs are XML identity and must not be rewritten dynamically")
        if key=="image" and type(value)=="string" and value:sub(1,10)=="sgub_band_" then
            local registered=false
            for _,asset in ipairs(ui.assets) do if asset.name==value and asset.url~="" then registered=true end end
            assert(registered,"morale band Sprite name must be explicitly registered before binding: "..value)
        end
        local node=findNode(ui.xmlTable,id)
        assert(node,"Object UI update refers to missing node: "..id)
        node.attributes=node.attributes or {}; node.attributes[key]=value
        ui.attributeCalls=ui.attributeCalls+1
        ui.attributeLog[#ui.attributeLog+1]={id=id,key=key,value=value}
        if key == "image" then ui.imageWrites[id]=(ui.imageWrites[id] or 0)+1 end
    end
    ui.setAttributes=function(id,attributes)
        for key,value in pairs(attributes) do ui.setAttribute(id,key,value) end
    end
    return ui
end
local function token(name,description,guid)
    local result={name=name,description=description,guid=guid,is_face_down=false,flipCalls=0,tags={},buttons={},
        decals={},decalWrites=0,decalReads=0,boundsReads=0,spawning=false,loading_custom=false,
        bounds={size={x=2,y=0.2,z=2},offset={x=0,y=0,z=0}},scale={x=1,y=1,z=1},
        UI=objectUI(),highlightStarts=0,highlightStops=0,contextMenu={},contextMenuClears=0,contextInvocations={}}
    result.getName=function() return result.name end
    result.getDescription=function() return result.description end
    result.setDescription=function(value) result.description=value end
    result.getGUID=function() return result.guid end
    result.flip=function()
        result.flipCalls=result.flipCalls+1
        result.is_face_down=not result.is_face_down
    end
    result.getVisualBoundsNormalized=function() result.boundsReads=result.boundsReads+1; return copy(result.bounds) end
    result.getBoundsNormalized=function() result.boundsReads=result.boundsReads+1; return copy(result.bounds) end
    result.getScale=function() return copy(result.scale) end
    result.getDecals=function() result.decalReads=result.decalReads+1; return copy(result.decals) end
    result.setDecals=function(decals)
        result.decals=copy(decals)
        result.decalWrites=result.decalWrites+1
    end
    result.hasTag=function(tag) return result.tags[tag] == true end
    result.getTags=function()
        local tags={}; for tag,enabled in pairs(result.tags) do if enabled then table.insert(tags,tag) end end
        table.sort(tags); return tags
    end
    result.addTag=function(tag) result.tags[tag]=true; return true end
    result.removeTag=function(tag) result.tags[tag]=nil; return true end
    result.highlightOn=function(color,duration)
        result.highlight=copy(color); result.highlightDuration=duration
        result.highlightStarts=result.highlightStarts+1
    end
    result.highlightOff=function()
        result.highlight=nil; result.highlightStops=result.highlightStops+1
    end
    result.clearButtons=function() result.buttons={} end
    result.addContextMenuItem=function(label,callback,keepOpen)
        table.insert(result.contextMenu,{label=label,callback=callback,keepOpen=keepOpen})
    end
    result.clearContextMenu=function()
        result.contextMenuClears=result.contextMenuClears+1; result.contextMenu={}
    end
    result.invokeContextMenu=function(label,color,position,target)
        target=target or result
        for _,entry in ipairs(result.contextMenu) do
            if entry.label == label then
                table.insert(result.contextInvocations,{label=label,color=color,position=copy(position),object=target})
                entry.callback(color,position,target); return
            end
        end
        error("Missing context menu entry: "..label)
    end
    result.getButtons=function() return copy(result.buttons) end
    result.createButton=function(button)
        button.index=#result.buttons
        table.insert(result.buttons,button)
    end
    result.removeButton=function(index)
        assert(index>=0 and index<#result.buttons,"removeButton index must exist")
        table.remove(result.buttons,index+1)
        for current,button in ipairs(result.buttons) do button.index=current-1 end
    end
    result.editButton=function(update)
        local button=result.buttons[update.index+1]
        assert(button,"missing counter button")
        for key,value in pairs(update) do button[key]=value end
    end
    objects[guid]=result
    return result
end
local function managedStamp(object)
    local result,count=nil,0
    for _,decal in ipairs(object.decals) do
        if decal.name == STAMP_NAME then result=decal; count=count+1 end
    end
    return result,count
end
local function near(actual,expected,message)
    if type(actual) ~= "number" or math.abs(actual-expected) > 0.00001 then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
    checks=checks+1
end
-- 安装版 LuaObject.SetUI 把 API (x,y,z) 写成子位置 (x,z,y)，
-- 父 LuaPanel 再旋转 (-90,180,0)，真实对象局部位置为 (-x,y,z)。
-- 不能直接把 API position 与贴花 localPosition 比较。
local function classicButtonObjectPosition(button)
    local p=button.position
    return {-p[1],p[2],p[3]}
end
local function classicButtonOrientation(button,back,message)
    near(button.rotation[1],0,message.." button API rotation X")
    near(button.rotation[2],0,message.." button API rotation Y")
    near(button.rotation[3],back and 180 or 0,message.." button API rotation Z")
end
local function buttonAboveDecal(button,decal,back,message)
    local p=classicButtonObjectPosition(button)
    near(p[1],decal.position[1],message.." engine-local X aligns with image")
    near(p[3],decal.position[3],message.." engine-local Z aligns with image")
    near(p[2],decal.position[2]+(back and -.004 or .004),message.." engine-local plane lies above image")
    classicButtonOrientation(button,back,message)
end
local function commandSlots(prefix)
    local parts={}
    for n=1,6 do
        local id=prefix.."_command_slot"..n
        assert(type(UI.values[id]) == "string", "Missing command slot text: "..id)
        parts[n]=UI.values[id]
    end
    return table.concat(parts)
end
local function slotLayout(prefix,message)
    local isMain=prefix:match("_main$") ~= nil
    local width=isMain and 28 or 24
    for n=1,6 do
        local id=prefix.."_command_slot"..n
        local attrs=UI.attributes[id] or {}
        local crossed=UI.values[id] == "X"
        local expectedFont=isMain and (crossed and 24 or 30) or (crossed and 20 or 24)
        eq(tonumber(attrs.fontSize),expectedFont,message.." font slot "..n)
        local x,y=tostring(attrs.offsetXY):match("^([^ ]+) ([^ ]+)$")
        near(tonumber(x),width*(n-3.5),message.." horizontal slot "..n)
        near(tonumber(y),crossed and 0 or (isMain and 2 or 1),message.." optical vertical slot "..n)
    end
end
local function sameSlots(left,right,message)
    for n=1,6 do
        local a,b=left.."_command_slot"..n,right.."_command_slot"..n
        eq(UI.values[a],UI.values[b],message.." value slot "..n)
        eq(UI.attributes[a].color,UI.attributes[b].color,message.." color slot "..n)
        eq(UI.attributes[a].fontSize,UI.attributes[b].fontSize,message.." font slot "..n)
        eq(UI.attributes[a].offsetXY,UI.attributes[b].offsetXY,message.." offset slot "..n)
    end
end
local function slotColors(prefix,color,message)
    for n=1,6 do eq(UI.attributes[prefix.."_command_slot"..n].color,color,message.." color slot "..n) end
    local barAttributes=UI.attributes[prefix.."_command_bar"]
    eq(barAttributes == nil or barAttributes.color == nil or barAttributes.color == "#FFFFFF00",true,message.." bar stays transparent")
end
local function noStatusTooltip(prefix,message)
    for _,suffix in ipairs({"_status","_status_text","_status_label"}) do
        eq(UI.attributes[prefix..suffix].tooltip,"",message..suffix)
    end
end
local function flagLayout(color,x,message)
    local attrs=UI.attributes["sg_"..color.."_main_visual_group"] or {}
    local actualX,actualY=tostring(attrs.offsetXY):match("^([^ ]+) ([^ ]+)$")
    near(tonumber(actualX),x,message.." portrait group horizontal center")
    near(tonumber(actualY),-37,message.." portrait group top")
    local roleAttrs=UI.attributes["sg_"..color.."_main_role"] or {}
    local roleX,roleY=tostring(roleAttrs.offsetXY):match("^([^ ]+) ([^ ]+)$")
    near(tonumber(roleX),x,message.." commander title follows portrait center")
    near(tonumber(roleY),-8,message.." commander title stays above portrait")
end
local function assetURL(name)
    for _,asset in ipairs(UI.assets) do if asset.name == name then return asset.url end end
end
-- 从实际输出的 XML 查找 Button 和回调，防止只测试 Lua 而漏掉 UI 仍为 Text。
local function clickUI(player, id)
    local callback = UI.buttons[id]
    assert(callback, "No clickable XML button: " .. id)
    assert(type(_G[callback]) == "function", "Missing UI callback: " .. callback)
    if UI.attributes[id] and UI.attributes[id].interactable == "false" then return end
    _G[callback](player, nil, id)
end
local function mapVisible(object,size,color)
    local node=findNode(object.UI.xmlTable,"sgmf_"..size)
    if not node or node.attributes.active == "false" then return false end
    local visibility=tostring(node.attributes.visibility or "")
    if visibility == "" then return true end
    for seat in visibility:gmatch("[A-Za-z]+") do if seat == color then return true end end
    return false
end
local function mapAsset(object)
    for _,asset in ipairs(object.UI.assets) do if asset.name == "sgmf_flag" then return asset.url end end
end
local function mapImage(object,size)
    local node=findNode(object.UI.xmlTable,"sgmf_"..size)
    return node and node.attributes.image
end
local function mapVector(object,id,key,x,y,z,message)
    local node=findNode(object.UI.xmlTable,id)
    assert(node,"Missing map node: "..id)
    local values={}
    for value in tostring(node.attributes[key]):gmatch("[^ ]+") do table.insert(values,tonumber(value)) end
    eq(#values,3,message.." component count")
    near(values[1],x,message.." X"); near(values[2],y,message.." Y"); near(values[3],z,message.." Z")
end
local function managedDecal(object,name)
    local result,count=nil,0
    for _,decal in ipairs(object.decals) do
        if decal.name==name then result=decal; count=count+1 end
    end
    return result,count
end
local function vector(value)
    local result={}
    for item in tostring(value or ""):gmatch("[^ ]+") do result[#result+1]=tonumber(item) end
    return result
end
local function objectAssetURL(object,name)
    for _,asset in ipairs(object.UI.assets) do if asset.name==name then return asset.url end end
end
-- 把实际 XML 的坐标换算成棋子局部坐标，独立检查 UI 与经典按钮的命中位置。
-- TTS 的物件 Canvas 自带 +90° X / .01 缩放；背面根节点再旋转 180° X。
local function backGraphic(object,kind)
    flush()
    local root=findNode(object.UI.xmlTable,"sgub_root")
    assert(root,"Missing troop back Object.UI root")
    local node=findNode(root.children,"sgub_"..kind)
    assert(node,"Missing troop back Image: "..kind)
    local attrs=node.attributes or {}
    local rootPosition,rootScale=vector(root.attributes.position),vector(root.attributes.scale)
    local offset=vector(attrs.position or attrs.offsetXY or "0 0 0")
    near(offset[3] or 0,0,"back "..kind.." shares one Canvas plane")
    local imageURL=attrs.image
    return {
        -- 必须检查真正写入 Image.image 的直链；不能把短资源名在测试里解析成 URL。
        url=imageURL,
        position={rootPosition[1]/100+(offset[1] or 0)*rootScale[1]/100,
            -rootPosition[3]/100,
            rootPosition[2]/100-(offset[2] or 0)*rootScale[2]/100},
        scale={tonumber(attrs.width)*rootScale[1]/100,tonumber(attrs.height)*rootScale[2]/100,.1},
        rotation={270,0,0},node=node,root=root
    }
end
local function unitGraphic(object,side,kind)
    if side=="BACK" then return backGraphic(object,kind:lower()) end
    return managedDecal(object,"SG_UNIT_"..(kind=="ACTION" and "ACTION_FRONT" or "NUM_FRONT_"..kind))
end
local function numberImage(object,side,kind,value,message)
    local graphic=unitGraphic(object,side,kind)
    if side=="BACK" then
        eq(select(2,managedDecal(object,"SG_UNIT_NUM_BACK_"..kind)),0,message.." has no independently sorted rear decal")
        eq(graphic.node.tag,"Image",message.." uses rear Canvas Image")
        eq(graphic.node.attributes.active,"true",message.." rear image is enabled")
    else
        eq(select(2,managedDecal(object,"SG_UNIT_NUM_FRONT_"..kind)),1,message.." exact single front numeral decal")
    end
    eq(graphic.url,(side=="BACK" and UNIT_NUMBER_BACK_IMAGES or UNIT_NUMBER_IMAGES)[value],message.." selected digit asset")
    return graphic
end
local function runMapFlagChecks(roster)
    for _,color in ipairs({"White","Brown","Red","Orange","Yellow","Green","Teal","Blue","Purple","Pink","Grey","Black"}) do sgClose({color=color}) end
    flush(); tick()
    for index,team in ipairs({"ota_honjin","iwatsuke_shu","edo_shu","matsuyama_shu"}) do
        local tagged=token("標籤足軽"..index,"","tagb0"..index)
        tagged.tags[team]=true; tagged.tags.unit_nagaye_ashigaru=true
        onObjectSpawn(tagged); flush(); onObjectHover("White",tagged); flush(); tick()
        local expected=roster[(index-1)*3+1].getName()
        eq(UI.values.sg_White_main_name:find(expected,1,true)==1,true,"English tag selects formation "..team)
        eq(select(2,managedStamp(tagged)),0,"ordinary units never acquire leader stamp "..team)
    end
    local urlA="https://example.invalid/map-alpha.png?part=a=b&v=1"
    local urlA2="https://example.invalid/map-alpha-replaced.png"
    local urlB="https://example.invalid/map-beta.png"
    local mainA=token("標籤甲大将","team=ignored_team\nrole=main\nname=標籤甲大将\ncommand=5\nimage=-\nflag_image="..urlA,"taga00")
    mainA.tags.sg_team_tagalpha=true; mainA.UI.holdAssets=true
    local deputy=token("標籤甲副将","team=tagalpha\nrole=deputy1\nname=標籤甲副将\ncommand=2\nimage=-","tagad1")
    local unitA=token("標籤甲足軽","team=tagbeta","taga01")
    unitA.tags.sg_team_tagalpha=true
    unitA.UI.xmlTable={{tag="Panel",attributes={id="foreign_panel",width="30",height="20"},children={{tag="Text",attributes={id="foreign_text",fontSize="12"},value="保留"}}},
        {tag="Panel",attributes={id="sgmf_root"},children={{tag="Image",attributes={id="sgmf_big",image="old"}}}}}
    unitA.UI.assets={{name="foreign_asset",url="https://example.invalid/foreign.png"},{name="sgmf_flag",url="old"}}
    unitA.buttons={{label="既存按钮"}}
    local foreign={name="別脚本貼花",url="https://example.invalid/foreign-decal.png",position={1,2,3},rotation={0,90,0},scale={.4,.5,.1}}
    local num={name="SG_UNIT_NUM_FRONT_MORALE",url="https://example.invalid/number-4.png",position={.8,.09,.2},rotation={90,0,0},scale={.2,.2,.1}}
    local defeat={name="SG_UNIT_DEFEAT_FRONT",url="https://example.invalid/defeat.png",position={0,.09,0},rotation={90,0,0},scale={.6,.3,.1}}
    local similar={name="SG_UNIT_FLAG_FRONT_EXTRA",url="https://example.invalid/extra.png",position={0,0,0},rotation={0,0,0},scale={.2,.2,.1}}
    unitA.decals={copy(foreign),copy(similar)}
    local unitA2=token("標籤甲弓足軽","","taga02"); unitA2.tags.sg_team_tagalpha=true
    local mainB=token("標籤乙大将","team=tagbeta\nrole=main\nname=標籤乙大将\ncommand=3\nimage=-\nflag_image="..urlB,"tagb00")
    mainB.tags.sg_team_tagbeta=true
    local unitB=token("標籤乙足軽","","tagb01"); unitB.tags.sg_team_tagbeta=true
    for _,object in ipairs({mainA,deputy,unitA,unitA2,mainB,unitB}) do onObjectSpawn(object) end
    flush(); tick()
    -- 先完成无兵种标签对象的 spawn 清理，再注入其他显示层的贴花，单独检验阵旗更新不会擦除它们。
    table.insert(unitA.decals,copy(num)); table.insert(unitA.decals,copy(defeat))
    tick()
    -- Commander Object.UI still waits for loading and rebinds real image URLs once.
    eq(mainA.UI.loading,true,"commander map XML can load asynchronously")
    local initialXML,initialAttributes=mainA.UI.xmlCalls,mainA.UI.attributeCalls
    for n=1,2 do tick() end
    eq(mainA.UI.xmlCalls,initialXML,"loading commander never rebuilds XML repeatedly")
    eq(mainA.UI.attributeCalls,initialAttributes,"loading commander does not receive premature attributes")
    eq(mainA.UI.imageWrites.sgmf_big or 0,0,"loading postpones commander Image binding")
    mainA.UI.holdAssets=false; mainA.UI.loading=false; tick(); tick()
    eq(mainA.UI.imageWrites.sgmf_big,1,"ready commander binds large Image once")
    eq(mainA.UI.imageWrites.sgmf_small,1,"ready commander binds small Image once")
    local readyAttributes=mainA.UI.attributeCalls; tick()
    eq(mainA.UI.attributeCalls,readyAttributes,"ready commander is not rebound every refresh")
    eq(mapVisible(mainA,"big","White"),true,"main retains persistent external flag")
    eq(mapVisible(mainA,"big","Red"),true,"main flag remains shared")
    eq(mapAsset(mainA),urlA,"main resource keeps exact Description URL")
    eq(mapImage(mainA,"big"),urlA,"main Image binds direct URL")
    mapVector(mainA,"sgmf_big","position",138,-20,-13,"commander external position unchanged")
    local function flags(object,url,message)
        for _,side in ipairs({"FRONT","BACK"}) do
            local decal,count=managedDecal(object,"SG_UNIT_FLAG_"..side)
            eq(count,url and 1 or 0,message.." exact single "..side)
            if url then eq(decal.url,url,message.." URL "..side) end
        end
        eq(findNode(object.UI.xmlTable,"sgmf_root"),nil,message.." has no old floating Object.UI root")
    end
    local function retained(message)
        for _,item in ipairs({foreign,num,defeat,similar}) do
            local decal,count=managedDecal(unitA,item.name)
            eq(count,1,message.." preserves "..item.name)
            eq(decal.url,item.url,message.." retains URL "..item.name)
            near(decal.position[1],item.position[1],message.." retains position "..item.name)
        end
        eq(findNode(unitA.UI.xmlTable,"foreign_text").value,"保留",message.." retains third-party XML")
        eq(unitA.UI.assets[1].name,"foreign_asset",message.." retains foreign asset")
        eq(unitA.buttons[1].label,"既存按钮",message.." retains classic buttons")
    end
    flags(unitA,urlA,"unhovered unit")
    flags(unitA2,urlA,"second unhovered unit")
    flags(unitB,urlB,"other team unit")
    retained("initial mount")
    eq(mapAsset(unitA),nil,"obsolete unit UI asset removed")
    local function geometry(object,message)
        local bounds,scale=object.bounds,object.scale
        local w,d=bounds.size.x/scale.x,bounds.size.z/scale.z
        local cx,cy,cz=bounds.offset.x/scale.x,bounds.offset.y/scale.y,bounds.offset.z/scale.z
        local half=bounds.size.y/scale.y/2
        for _,back in ipairs({false,true}) do
            local side=back and "BACK" or "FRONT"
            local decal=managedDecal(object,"SG_UNIT_FLAG_"..side)
            near(decal.position[1],cx+(back and 1 or -1)*(841/1200-.5)*w,message.." X "..side)
            near(decal.position[3],cz+(700/1200-.5)*d,message.." Z "..side)
            local clearance=UNIT_SURFACE_CLEARANCE or .01
            local calibrated=back and cy-half-(UNIT_DEFEAT_BACK_GAP or -.09) or cy+half+(UNIT_DEFEAT_FRONT_GAP or -.01)
            local outward=back and -1 or 1
            near((decal.position[2]-calibrated)*outward,clearance,message.." flag clearance outside calibrated face "..side)
            eq((decal.position[2]-calibrated)*outward*scale.y>0,true,message.." flag remains outward after nonuniform scaling "..side)
            near(decal.scale[1],w*270/1200,message.." width "..side)
            near(decal.scale[2],d*720/1200,message.." height "..side)
            near(decal.rotation[1],back and 270 or 90,message.." projection X "..side)
            near(decal.rotation[2],back and 0 or 180,message.." upright artwork yaw "..side)
        end
    end
    geometry(unitA,"default flag")
    local beforeResize=unitA.decalWrites
    unitA.bounds.size.y=.4; unitA.bounds.offset.y=.07
    tick(); geometry(unitA,"collider changed without object rescaling")
    eq(unitA.decalWrites,beforeResize+1,"surface change updates both permanent flag decals once")
    local stableResize=unitA.decalWrites
    tick(); eq(unitA.decalWrites,stableResize,"unchanged refreshed geometry avoids repeated writes")
    unitA.bounds.size.y=.2; unitA.bounds.offset.y=0
    tick(); geometry(unitA,"restored loaded surface")
    onObjectHover("White",unitA); flush(); tick()
    eq(UI.values.sg_White_main_name,"標籤甲大将　年齢 —","team tag overrides conflicting Description team")
    eq(unitA2.highlight ~= nil,true,"ordinary hover retains team highlighting")
    eq(unitB.highlight == nil,true,"highlight excludes other team")
    flags(unitA,urlA,"White hover"); flags(unitA2,urlA,"White hover other unit")
    onObjectHover("Red",unitA2); flush(); tick()
    flags(unitA,urlA,"second player hover")
    clickUI(Player.White,"sg_White_mapflags"); flush(); tick()
    flags(unitA,urlA,"seat toggle cannot hide shared unit flag")
    onObjectHover("White",deputy); flush(); tick()
    eq(mapVisible(deputy,"big","White"),true,"deputy retains hover flag")
    eq(mapVisible(deputy,"big","Blue"),false,"deputy hover stays seat-specific")
    onObjectHover("White",nil); onObjectHover("Red",nil); flush(); tick()
    flags(unitA,urlA,"all players stop hovering")
    eq(unitA.highlight == nil,true,"last hover exit clears team highlight")
    sgClose(Player.White); sgClose(Player.Red); flush(); tick()
    flags(unitA,urlA,"all panels closed")
    eq(mapVisible(mainA,"big","White"),true,"closing panels keeps main leader flag")
    local writes=unitA.decalWrites
    for n=1,4 do tick() end
    eq(unitA.decalWrites,writes,"idle refresh never rewrites unchanged unit decals")
    unitA.is_face_down=true; onObjectRotate(unitA,0,180,"White",0,0); flush(); tick()
    flags(unitA,urlA,"flipped unit"); geometry(unitA,"flipped unit")
    eq(unitA.decalWrites,writes,"flipping never rewrites permanent face decals")
    unitA.scale={x=2,y=3,z=.5}; unitA.bounds={size={x=4,y=.6,z=1},offset={x=.4,y=.3,z=-.2}}
    tick(); geometry(unitA,"scaled offset flag")
    local savedClearance=UNIT_SURFACE_CLEARANCE
    local frontPlane=managedDecal(unitA,"SG_UNIT_FLAG_FRONT").position[2]
    local backPlane=managedDecal(unitA,"SG_UNIT_FLAG_BACK").position[2]
    UNIT_SURFACE_CLEARANCE=(savedClearance or .01)+.015
    tick(); geometry(unitA,"adjusted safety clearance")
    near((managedDecal(unitA,"SG_UNIT_FLAG_FRONT").position[2]-frontPlane)*unitA.scale.y,.045,"front flag safety adjustment remains outward in world space")
    near((backPlane-managedDecal(unitA,"SG_UNIT_FLAG_BACK").position[2])*unitA.scale.y,.045,"back flag safety adjustment remains outward in world space")
    UNIT_SURFACE_CLEARANCE=savedClearance
    tick(); geometry(unitA,"restored safety clearance including standalone default")
    unitA.scale={x=1,y=1,z=1}; unitA.bounds={size={x=2,y=.2,z=2},offset={x=0,y=0,z=0}}; tick()
    geometry(unitA,"restored flag")
    table.insert(unitA.decals,copy(managedDecal(unitA,"SG_UNIT_FLAG_FRONT"))); tick()
    flags(unitA,urlA,"duplicate cleanup"); retained("duplicate cleanup")
    mainA.description=mainA.description:gsub("flag_image=[^\n]*","flag_image="..urlA2); tick(); flush()
    flags(unitA,urlA2,"shared Description URL replacement")
    eq(mapImage(mainA,"big"),urlA2,"commander direct Image also changes")
    local normalGet,normalSet=unitA.getDecals,unitA.setDecals
    unitA.getDecals=function() error("simulated unit decal read failure") end
    local ok=pcall(tick); eq(ok,true,"flag read failure cannot abort refresh")
    unitA.getDecals=normalGet
    unitA.setDecals=function() error("simulated unit decal write failure") end
    mainA.description=mainA.description:gsub("flag_image=[^\n]*","flag_image="..urlA); ok=pcall(tick)
    eq(ok,true,"flag write failure cannot abort refresh")
    unitA.setDecals=normalSet; tick(); flags(unitA,urlA,"recovery after API error")
    -- Commander asynchronous image replacement retains previous regression coverage.
    local loadingURL="https://example.invalid/map-loading.png"
    local latestURL="https://example.invalid/map-latest.png"
    mainA.UI.holdAssets=true
    mainA.description=mainA.description:gsub("flag_image=[^\n]*","flag_image="..loadingURL); tick()
    eq(mainA.UI.loading,true,"commander replacement can remain loading")
    local loadingWrites=mainA.UI.attributeCalls
    mainA.description=mainA.description:gsub("flag_image=[^\n]*","flag_image="..latestURL); tick()
    eq(mainA.UI.attributeCalls,loadingWrites,"commander URL changes wait for UI readiness")
    flags(unitA,latestURL,"unit decals do not wait for unrelated commander UI")
    mainA.UI.holdAssets=false; mainA.UI.loading=false; tick()
    eq(mapImage(mainA,"big"),latestURL,"commander readiness selects latest URL")
    local duplicate=token("重複大将","team=tagalpha\nrole=main\nflag_image="..urlA,"tagdup")
    onObjectSpawn(duplicate); flush(); tick()
    flags(unitA,nil,"ambiguous main suppresses inherited flag")
    eq(mapVisible(mainA,"big","White"),false,"ambiguous main suppresses commander flag")
    onObjectDestroy(duplicate); objects.tagdup=nil; flush(); tick()
    flags(unitA,latestURL,"duplicate removal restores inherited flag")
    mainA.description=mainA.description:gsub("flag_image=[^\n]*","flag_image=-"); tick(); flush()
    flags(unitA,nil,"missing URL removes old decals"); retained("missing URL cleanup")
    mainA.description=mainA.description:gsub("flag_image=[^\n]*","flag_image="..urlA); tick()
    unitA.tags.sg_team_tagbeta=true; onObjectDrop("White",unitA); flush(); tick()
    flags(unitA,nil,"conflicting affiliation removes flag")
    unitA.tags.sg_team_tagbeta=nil; onObjectDrop("White",unitA); flush(); tick()
    flags(unitA,urlA,"resolved affiliation restores flag")
    unitA.tags.sg_team_tagalpha=nil; onObjectDrop("White",unitA); flush(); tick()
    flags(unitA,urlB,"Description fallback changes inherited flag")
    onObjectEnterContainer({},unitB); objects.tagb01=nil; flush(); tick()
    flags(unitB,nil,"container entry removes permanent flag")
    objects.tagb01=unitB; onObjectLeaveContainer({},unitB); flush(); tick()
    flags(unitB,urlB,"container exit recreates permanent flag")
    local replaced=token("乙足軽新状態","","tagb02"); replaced.tags.sg_team_tagbeta=true
    objects.tagb01=nil; onObjectStateChange(replaced,"tagb01"); flush(); tick()
    flags(unitB,nil,"state change cleans old GUID")
    flags(replaced,urlB,"state change mounts new GUID without hover")
    unitA.description="team=tagbeta\nrole=deputy1\nname=臨時副将"
    onObjectDrop("White",unitA); flush(); tick()
    eq(select(2,managedDecal(unitA,"SG_UNIT_FLAG_FRONT")),0,"unit converted to leader loses front unit flag")
    eq(select(2,managedDecal(unitA,"SG_UNIT_FLAG_BACK")),0,"unit converted to leader loses back unit flag")
    unitA.description="team=tagbeta"; onObjectDrop("White",unitA); flush(); tick()
    flags(unitA,urlB,"leader converted back to unit regains decal")
    onObjectDestroy(unitA2); objects.taga02=nil; flush(); tick()
    flags(unitA2,nil,"destroy removes owned unit flags")
    retained("all lifecycle transitions")
    for _,object in ipairs({mainA,mainB}) do object.description=object.description:gsub("flag_image=[^\n]*","flag_image=-") end
    tick(); flush()
    flags(unitA,nil,"final URL cleanup"); flags(replaced,nil,"final second team cleanup")
end
local function runUnitLayoutChecks()
    local modern=token("新棋面部队","","uimod1")
    modern.tags.unit_nagaye_ashigaru=true; modern.tags.count_100=true
    modern.UI.xmlTable={{tag="Text",attributes={id="foreign_unit_text"},value="保留"}}
    modern.UI.assets={{name="foreign_asset",url="https://example.invalid/foreign.png"}}
    local flag={name="SG_UNIT_FLAG_FRONT",url="https://example.invalid/flag.png",position={.4,.09,.1},rotation={90,0,0},scale={.45,1.2,.1}}
    local similar={name="SG_UNIT_NUM_FRONT_COUNT_EXTRA",url="https://example.invalid/foreign.png",position={0,0,0},rotation={0,0,0},scale={.2,.2,.1}}
    modern.decals={copy(flag),copy(similar)}
    local foreignCalls=0
    modern.addContextMenuItem("原有菜单",function() foreignCalls=foreignCalls+1 end)
    unit_state.uimod1={front_value=4,back_value=3,manual_defeat_visible=false}
    setupUnit(modern,getUnitConfig(modern)); flush()
    eq(#modern.buttons,6,"troop uses two morale hit areas, two defeat fallbacks and two action hit areas")
    eq(modern.buttons[1].label,"","front morale no longer renders classic text")
    eq(modern.buttons[2].label,"","back morale no longer renders classic text")
    numberImage(modern,"FRONT","COUNT",1,"front hundred-person count")
    numberImage(modern,"BACK","COUNT",1,"rear hundred-person count")
    numberImage(modern,"FRONT","MORALE",4,"front independent morale")
    numberImage(modern,"BACK","MORALE",3,"rear independent morale")
    numberImage(modern,"FRONT","MOVE",4,"front fixed movement")
    numberImage(modern,"BACK","MOVE",3,"rear fixed movement")
    eq(modern.UI.xmlCalls,1,"rear rail mounts one Object.UI tree")
    eq(objectAssetURL(modern,"foreign_asset"),"https://example.invalid/foreign.png","rear resources preserve foreign asset")
    eq(findNode(modern.UI.xmlTable,"foreign_unit_text").value,"保留","foreign XML survives")
    eq(managedDecal(modern,flag.name).url,flag.url,"numeric update preserves clan flag")
    eq(managedDecal(modern,similar.name).url,similar.url,"similar numeric prefix is not owned")
    for index,button in ipairs(modern.buttons) do
        eq(button.label ~= "長柄足軽" and button.label ~= "切替",true,"baked name and old toggle omitted")
        eq(button.label ~= "士気" and button.label ~= "移動" and button.label ~= "兵数",true,"baked headings not duplicated")
        if index<=2 then
            eq(button.width>=60 and button.height>=60,true,"morale hit area accepts engine clicks")
            eq(button.color[4],0,"morale hit area transparent")
            near(button.hover_color[4],0.14,"morale hover gently identifies clickable numeral")
            near(button.press_color[4],0.20,"morale press gives feedback without hiding numeral")
            local maximum=index==1 and 6 or 5
            eq(button.tooltip,"基礎士氣上限："..maximum.."\n實際士氣上限："..maximum,"morale hover shows this face's base and effective maximum")
            eq(button.click_function,index==1 and "changeFrontValue" or "changeBackValue","morale callback retained")
        elseif index<=4 then
            eq(button.width,0,"defeat fallback width zero")
            eq(button.height,0,"defeat fallback height zero")
            eq(button.click_function,"unitDefeatFallback","defeat fallback read only and identifiable")
        else
            eq(button.click_function,"toggleUnitActed","action control callback")
            eq(button.width>0 and button.height>0,true,"action control has a hit area")
            eq(button.tooltip,"","action control has no tooltip")
        end
    end
    local function geometry(object,message)
        local bounds,scale=object.bounds,object.scale
        local w,d=bounds.size.x/scale.x,bounds.size.z/scale.z
        local cx,cy,cz=bounds.offset.x/scale.x,bounds.offset.y/scale.y,bounds.offset.z/scale.z
        local half=bounds.size.y/scale.y/2
        for _,row in ipairs({{"COUNT",374.5},{"MORALE",748},{"MOVE",1081.5}}) do
            for _,back in ipairs({false,true}) do
                local side=back and "BACK" or "FRONT"
                local decal=unitGraphic(object,side,row[1])
                near(decal.position[1],cx+(back and 1 or -1)*(1100/1200-.5)*w,message.." artwork X "..side..row[1])
                near(decal.position[3],cz+(row[2]/1200-.5)*d,message.." artwork row "..side..row[1])
                local calibrated=back and cy-half or cy+half+UNIT_DEFEAT_FRONT_GAP
                local clearance=back and -.099 or UNIT_SURFACE_CLEARANCE
                near((decal.position[2]-calibrated)*(back and -1 or 1),clearance,message.." number offset from face reference "..side..row[1])
                if back then
                    near(decal.position[2]*scale.y,(cy-half+.099)*scale.y,message.." rear number retains user-calibrated plane after nonuniform scaling "..row[1])
                else
                    eq((decal.position[2]-calibrated)*scale.y>0,true,message.." front number stays outward after nonuniform scaling "..row[1])
                end
                near(decal.scale[1],w*176/1200,message.." digit width "..side..row[1])
                near(decal.scale[2],d*176/1200,message.." digit height "..side..row[1])
                near(decal.rotation[1],back and 270 or 90,message.." projection X "..side..row[1])
                near(decal.rotation[2],back and 0 or 180,message.." upright artwork yaw "..side..row[1])
            end
        end
    end
    geometry(modern,"default")
    for index,side in ipairs({"FRONT","BACK"}) do
        local numeral=unitGraphic(modern,side,"MORALE")
        buttonAboveDecal(modern.buttons[index],numeral,index==2,"morale "..side)
        local enginePosition=classicButtonObjectPosition(modern.buttons[index])
        local screenX=600+(index==1 and -1 or 1)*enginePosition[1]/2*1200
        near(screenX,1100,"screenshot-calibrated "..side.." hit lands in right-hand column")
        buttonAboveDecal(modern.buttons[index+4],unitGraphic(modern,side,"ACTION"),index==2,"action "..side)
    end
    modern.scale={x=2,y=3,z=.5}; modern.bounds={size={x=4,y=.6,z=1},offset={x=.4,y=.3,z=-.2}}
    updateDefeatText(modern); geometry(modern,"scaled offset without rebuilding buttons")
    for index,side in ipairs({"FRONT","BACK"}) do
        local numeral=unitGraphic(modern,side,"MORALE")
        buttonAboveDecal(modern.buttons[index],numeral,index==2,"nonzero model offset morale refresh "..side)
        buttonAboveDecal(modern.buttons[index+4],unitGraphic(modern,side,"ACTION"),index==2,"nonzero model offset action refresh "..side)
    end
    setupUnit(modern,getUnitConfig(modern))
    for index,side in ipairs({"FRONT","BACK"}) do
        buttonAboveDecal(modern.buttons[index],unitGraphic(modern,side,"MORALE"),index==2,"nonzero model offset morale creation "..side)
        buttonAboveDecal(modern.buttons[index+4],unitGraphic(modern,side,"ACTION"),index==2,"nonzero model offset action creation "..side)
        local fallback=modern.buttons[index==1 and 4 or 3]
        local p=classicButtonObjectPosition(fallback)
        near(p[1],.2,"nonzero model offset defeat text uses actual object center X "..side)
        near(p[3],-.4,"nonzero model offset defeat text uses actual object center Z "..side)
        classicButtonOrientation(fallback,index==2,"defeat text "..side)
    end
    modern.scale={x=1,y=1,z=1}; modern.bounds={size={x=2,y=.2,z=2},offset={x=0,y=0,z=0}}
    setupUnit(modern,getUnitConfig(modern)); geometry(modern,"restored")
    _G[modern.buttons[1].click_function](modern,"Red",false)
    eq(unit_state.uimod1.front_value,5,"clicking front numeral directly increases morale")
    numberImage(modern,"FRONT","MORALE",5,"direct front click changes the image")
    _G[modern.buttons[1].click_function](modern,"Red",true)
    eq(unit_state.uimod1.front_value,4,"right-clicking front numeral directly decreases morale")
    _G[modern.buttons[2].click_function](modern,"Blue",false)
    eq(unit_state.uimod1.back_value,4,"clicking rear numeral directly increases morale")
    _G[modern.buttons[2].click_function](modern,"Blue",true)
    eq(unit_state.uimod1.back_value,3,"right-clicking rear numeral directly decreases morale")
    eq(modern.is_face_down,false,"numeral callbacks never flip token")
    local unchanged=modern.decalWrites
    for n=1,3 do setupUnit(modern,getUnitConfig(modern)) end
    eq(modern.decalWrites,unchanged,"identical full setup avoids redundant decal writes")
    table.insert(modern.decals,copy(managedDecal(modern,"SG_UNIT_NUM_FRONT_COUNT")))
    setupUnit(modern,getUnitConfig(modern))
    numberImage(modern,"FRONT","COUNT",1,"duplicate digit cleanup")
    null(modern,"Red",false)
    eq(unit_state.uimod1.front_value,4,"read-only callback keeps front morale")
    eq(unit_state.uimod1.back_value,3,"read-only callback keeps back morale")
    for n=1,12 do changeFrontValue(modern,"Red",false) end
    eq(unit_state.uimod1.front_value,6,"front morale retains unit-specific upper bound")
    eq(unit_state.uimod1.back_value,3,"front click preserves rear morale")
    numberImage(modern,"FRONT","MORALE",6,"front click changes numeric image")
    for n=1,12 do changeBackValue(modern,"Blue",false) end
    eq(unit_state.uimod1.back_value,5,"rear morale retains unit-specific upper bound")
    eq(modern.buttons[3].label,"","positive rear clears defeat")
    for n=1,12 do changeFrontValue(modern,"Red",true) end
    eq(unit_state.uimod1.front_value,0,"front lower bound")
    numberImage(modern,"FRONT","MORALE",0,"zero has dedicated image")
    eq(modern.buttons[4].label,"","front zero alone does not force defeat")
    tick() -- Let the physical flip animation guard elapse before later correction clicks.
    for n=1,12 do changeBackValue(modern,"Blue",true) end
    eq(unit_state.uimod1.back_value,0,"rear lower bound")
    numberImage(modern,"BACK","MORALE",0,"rear zero image")
    eq(modern.buttons[3].label,"敗走","rear zero retains defeat fallback")
    eq(modern.buttons[4].label,"敗走","rear zero retains front defeat fallback")
    numberImage(modern,"FRONT","MOVE",4,"morale cannot alter front movement")
    numberImage(modern,"BACK","MOVE",3,"morale cannot alter rear movement")
    for index,count in ipairs({100,200,300,400}) do
        for _,other in ipairs({100,200,300,400}) do modern.tags["count_"..other]=nil end
        modern.tags["count_"..count]=true; updateCountLabel(modern)
        numberImage(modern,"FRONT","COUNT",index,"count tag front "..count)
        numberImage(modern,"BACK","COUNT",index,"count tag rear "..count)
    end
    modern.tags.count_400=nil; updateCountLabel(modern)
    numberImage(modern,"FRONT","COUNT",1,"no count tag defaults to one hundred")
    eq(#modern.contextMenu,1,"troop setup adds no context actions and retains foreign menu")
    modern.invokeContextMenu("原有菜单","Red",{1,2,3})
    eq(foreignCalls,1,"foreign context callback remains callable")
    eq(modern.contextMenuClears,0,"setup never clears context menus")
    changeBackValue(modern,"Red",false)
    toggleDefeatText(modern)
    eq(unit_state.uimod1.manual_defeat_visible,true,"legacy defeat API remains compatible")
    eq(modern.buttons[3].label,"敗走","legacy defeat API updates rear fallback")
    toggleDefeatText(modern)
    eq(unit_state.uimod1.manual_defeat_visible,false,"legacy defeat API switches back off")
    local clone=token("复制棋面部队","","uimod2"); clone.tags=copy(modern.tags)
    unit_state.uimod2={front_value=2,back_value=2,manual_defeat_visible=false}
    setupUnit(clone,getUnitConfig(clone))
    eq(#clone.contextMenu,0,"fresh troop has no custom context actions")
    toggleDefeatText(clone)
    eq(unit_state.uimod2.manual_defeat_visible,true,"legacy defeat API targets given object")
    eq(unit_state.uimod1.manual_defeat_visible,false,"copy does not mutate original")
    clone.tags.unit_nagaye_ashigaru=nil
    toggleDefeatText(clone)
    eq(unit_state.uimod2.manual_defeat_visible,true,"removed troop tag disables legacy defeat API")
    clone.tags.unit_nagaye_ashigaru=true
    clone.is_face_down=false
    _G[clone.buttons[1].click_function](clone,"Red",false)
    eq(unit_state.uimod2.front_value,3,"direct click increases clone front morale")
    eq(unit_state.uimod2.back_value,2,"front click retains rear face")
    clone.is_face_down=true
    _G[clone.buttons[2].click_function](clone,"Blue",true)
    eq(unit_state.uimod2.back_value,1,"direct right click decreases clone rear morale")
    eq(unit_state.uimod2.front_value,3,"rear click retains front face")
    modern.tags.unit_ui_v2=true; setupUnit(modern,getUnitConfig(modern))
    eq(#modern.buttons,6,"stale opt-in tag cannot restore obsolete numeric text")
    modern.tags.unit_ui_v2=nil
    changeFrontValue(modern,"White",false); toggleDefeatText(modern)
    local saved=onSave(); unit_state={}; onLoad(saved); flush(); tick()
    eq(unit_state.uimod1.front_value,1,"front morale saved")
    eq(unit_state.uimod1.back_value,1,"rear morale saved")
    eq(unit_state.uimod1.manual_defeat_visible,true,"manual defeat saved")
    numberImage(modern,"FRONT","MORALE",1,"front saved image")
    numberImage(modern,"BACK","MORALE",1,"rear saved image")
    eq(#modern.contextMenu,1,"reload never introduces troop context actions")
    -- Missing and restored image config updates sprites but never loses game state.
    local previous=UNIT_NUMBER_IMAGES[1]
    UNIT_NUMBER_IMAGES[1]=""; setupUnit(modern,getUnitConfig(modern))
    eq(select(2,managedDecal(modern,"SG_UNIT_NUM_FRONT_COUNT")),0,"missing count asset clears previous image")
    eq(select(2,managedDecal(modern,"SG_UNIT_NUM_FRONT_MORALE")),0,"missing morale asset clears previous image")
    eq(modern.buttons[1].label,"","missing morale asset does not render fallback text")
    eq(unit_state.uimod1.front_value,1,"missing image never changes counter state")
    local previousSetDecals=modern.setDecals
    modern.setDecals=function() error("simulated numeral decal write failure") end
    _G[modern.buttons[1].click_function](modern,"White",false)
    eq(unit_state.uimod1.front_value,2,"morale hit area remains usable when numeral submission fails")
    eq(modern.buttons[1].label,"","failed numeral submission does not render fallback text")
    modern.setDecals=previousSetDecals
    _G[modern.buttons[1].click_function](modern,"White",true)
    eq(unit_state.uimod1.front_value,1,"morale click can return to a value with no configured image")
    eq(modern.buttons[1].label,"","missing numeral keeps transparent hit area after a click")
    UNIT_NUMBER_IMAGES[1]=previous; setupUnit(modern,getUnitConfig(modern))
    numberImage(modern,"FRONT","COUNT",1,"restored count asset")
    numberImage(modern,"FRONT","MORALE",1,"restored morale asset")
    eq(modern.buttons[1].label,"","restored image keeps transparent hit area")
    local longURL="https://example.invalid/"..string.rep("x",4096)..".png?part=a=b&v=1"
    UNIT_NUMBER_IMAGES[1]=" \t"..longURL.." "
    setupUnit(modern,getUnitConfig(modern))
    eq(managedDecal(modern,"SG_UNIT_NUM_FRONT_COUNT").url,longURL,"long number URL trims surrounding whitespace without pattern overflow")
    UNIT_NUMBER_IMAGES[1]=previous; setupUnit(modern,getUnitConfig(modern))
    local actual=token("实测厚度棋子","","uihigh")
    actual.tags.unit_nagaye_ashigaru=true; actual.scale={x=.4,y=1,z=.4}
    actual.bounds={size={x=.8,y=.1,z=.8},offset={x=0,y=.05,z=0}}
    local visualReads=0
    actual.getVisualBoundsNormalized=function() visualReads=visualReads+1; return {size={x=200,y=400,z=300},offset={x=90,y=180,z=60}} end
    setupUnit(actual,getUnitConfig(actual)); geometry(actual,"actual bottom-pivot tile")
    near(managedDecal(actual,"SG_UNIT_NUM_FRONT_COUNT").position[2],.1+UNIT_DEFEAT_FRONT_GAP+UNIT_SURFACE_CLEARANCE,"bottom-pivot front number retains configured surface clearance")
    near(backGraphic(actual,"count").position[2],.099,"bottom-pivot rear Canvas retains user-calibrated plane")
    eq(visualReads,0,"number decals ignore inflated display renderers")
    local bad=token("损坏模型足軽","","uifail"); bad.tags.unit_nagaye_ashigaru=true
    bad.getBoundsNormalized=function() error("invalid collider") end
    bad.getVisualBoundsNormalized=function() error("invalid renderer") end
    local good=token("后续部队","","uinext"); good.tags.unit_nagaye_ashigaru=true
    local oldObjects=getAllObjects; getAllObjects=function() return {bad,good} end
    local completed,reason=pcall(setupAllUnits); getAllObjects=oldObjects
    eq(completed,true,"invalid model cannot abort subsequent setup: "..tostring(reason))
    eq(#good.buttons,6,"subsequent valid troop gets usable counter")
    numberImage(good,"FRONT","MORALE",6,"subsequent valid troop starts with full morale")
    objects.uifail=nil
    local range=token("九数字覆盖足軽","","uirang")
    range.tags.unit_nagaye_ashigaru=true
    local oldMax=UNIT_CONFIGS[1].max_front
    UNIT_CONFIGS[1].max_front=8
    for value=0,8 do
        unit_state.uirang={front_value=value,back_value=1,manual_defeat_visible=false}
        setupUnit(range,getUnitConfig(range))
        numberImage(range,"FRONT","MORALE",value,"all nine configured digits "..value)
    end
    local eightURL=UNIT_NUMBER_IMAGES[8]
    UNIT_NUMBER_IMAGES[8]="C:/Users/HP/Documents/ChatGPT/日本战国/TTS武将面板/数字贴图_v1/PNG/8.png"
    setupUnit(range,getUnitConfig(range))
    numberImage(range,"FRONT","MORALE",8,"absolute Windows PNG path accepted without URL encoding")
    UNIT_NUMBER_IMAGES[8]="file:///C:/Users/HP/Documents/ChatGPT/日本战国/TTS武将面板/数字贴图_v1/PNG/8.png"
    setupUnit(range,getUnitConfig(range))
    numberImage(range,"FRONT","MORALE",8,"local file URI with Unicode directories accepted")
    local warningPrint,warningCount=print,0
    print=function() warningCount=warningCount+1 end
    UNIT_NUMBER_IMAGES[8]=""
    for n=1,4 do setupUnit(range,getUnitConfig(range)) end
    print=warningPrint
    eq(warningCount,1,"repeated missing digit warns once globally")
    eq(range.buttons[1].label,"","missing eighth image leaves no numeral text")
    eq(unit_state.uirang.front_value,8,"missing eighth image preserves stored value")
    UNIT_NUMBER_IMAGES[8]=eightURL; UNIT_CONFIGS[1].max_front=oldMax
    objects.uirang=nil; unit_state.uirang=nil
    local cleanup=token("标签移除清理足軽","","uiclea")
    cleanup.tags.unit_nagaye_ashigaru=true
    unit_state.uiclea={front_value=3,back_value=2,manual_defeat_visible=true}
    setupUnit(cleanup,getUnitConfig(cleanup))
    local preserved={
        {name="SG_UNIT_FLAG_FRONT",url="https://example.invalid/preserve-flag.png",position={1,2,3},rotation={90,0,0},scale={.4,.5,.1}},
        {name=STAMP_NAME,url=STAMP_URL,position={0,.099,0},rotation={270,180,0},scale={1,1,.1}},
        {name="外部保留",url="https://example.invalid/preserve-foreign.png",position={4,5,6},rotation={0,90,0},scale={.2,.3,.1}},
        {name="SG_UNIT_NUM_FRONT_COUNT_EXTRA",url="https://example.invalid/preserve-prefix.png",position={0,0,0},rotation={0,0,0},scale={.1,.1,.1}}
    }
    for _,item in ipairs(preserved) do table.insert(cleanup.decals,copy(item)) end
    for _,side in ipairs({"FRONT","BACK"}) do
        table.insert(cleanup.decals,{name="SG_UNIT_DEFEAT_"..side,url="https://example.invalid/stale-defeat.png",position={0,0,0},rotation={0,0,0},scale={.1,.1,.1}})
    end
    cleanup.createButton({label="外部按鈕一",click_function="externalOne",width=60,height=60})
    cleanup.createButton({label="外部按鈕二",click_function="changeFrontValueForeign",width=60,height=60})
    cleanup.tags.unit_nagaye_ashigaru=nil
    local normalObjects=getAllObjects
    getAllObjects=function() return {cleanup} end
    setupAllUnits()
    getAllObjects=normalObjects
    for _,side in ipairs({"FRONT","BACK"}) do
        for _,kind in ipairs({"COUNT","MORALE","MOVE"}) do
            eq(select(2,managedDecal(cleanup,"SG_UNIT_NUM_"..side.."_"..kind)),0,"removed troop tag clears "..side..kind)
        end
        eq(select(2,managedDecal(cleanup,"SG_UNIT_DEFEAT_"..side)),0,"removed troop tag clears defeat "..side)
        eq(select(2,managedDecal(cleanup,"SG_UNIT_ACTION_"..side)),0,"removed troop tag clears action "..side)
    end
    eq(select(2,managedDecal(cleanup,"SG_UNIT_BACK_RAIL")),0,"removed troop tag clears back rail")
    for _,item in ipairs(preserved) do
        local decal,count=managedDecal(cleanup,item.name)
        eq(count,1,"numeric cleanup retains unrelated decal "..item.name)
        eq(decal.url,item.url,"numeric cleanup retains unrelated URL "..item.name)
        near(decal.position[1],item.position[1],"numeric cleanup retains unrelated geometry "..item.name)
    end
    eq(#cleanup.buttons,2,"numeric cleanup removes only six owned buttons")
    eq(cleanup.buttons[1].label,"外部按鈕一","foreign first button retains order")
    eq(cleanup.buttons[2].label,"外部按鈕二","similar callback name is not owned")
    eq(cleanup.buttons[1].index,0,"remaining button first index normalized")
    eq(cleanup.buttons[2].index,1,"remaining button second index normalized")
    eq(unit_state.uiclea.front_value,3,"tag removal keeps front morale data")
    eq(unit_state.uiclea.back_value,2,"tag removal keeps rear morale data")
    eq(unit_state.uiclea.manual_defeat_visible,true,"tag removal keeps manual defeat data")
    clearUnitCounterVisuals(cleanup)
    eq(#cleanup.buttons,2,"repeated cleanup retains foreign buttons")
    cleanup.tags.unit_nagaye_ashigaru=true
    setupUnit(cleanup,getUnitConfig(cleanup))
    numberImage(cleanup,"FRONT","MORALE",3,"readding troop tag restores previous front morale")
    numberImage(cleanup,"BACK","MORALE",2,"readding troop tag restores previous rear morale")
    cleanup.tags.unit_nagaye_ashigaru=nil
    onObjectSpawn(cleanup); flush(); tick()
    eq(select(2,managedDecal(cleanup,"SG_UNIT_NUM_FRONT_MORALE")),0,"spawning an untagged stale troop clears old digits")
    eq(unit_state.uiclea.front_value,3,"spawn cleanup retains saved morale")
    objects.uiclea=nil; unit_state.uiclea=nil
end
local function runUnitDefeatImageChecks()
    local previousURL,previousAspect,previousLayout=UNIT_DEFEAT_IMAGE_URL,UNIT_DEFEAT_IMAGE_ASPECT,copy(UNIT_ROUT_LAYOUT)
    UNIT_DEFEAT_IMAGE_URL=""
    UNIT_DEFEAT_IMAGE_ASPECT=2
    setUnitRoutSnapshot({})
    local created={}
    local function make(guid)
        local object=token("敗走画像足軽","",guid)
        object.tags.unit_nagaye_ashigaru=true; object.tags.count_100=true
        unit_state[guid]={front_value=5,back_value=4,manual_defeat_visible=true}
        created[#created+1]=object
        return object
    end
    local function roots(object,side)
        return findNode(object.UI.xmlTable,"sgub_rout_"..side),findNode(object.UI.xmlTable,"sgub_rout_"..side.."_image")
    end
    local function visible(object,side)
        local root,node=roots(object,side)
        return root~=nil and node~=nil and root.attributes.active=="true" and node.attributes.active=="true"
    end
    local function graphic(object,side)
        local root,node=roots(object,side)
        assert(root and node,"Missing rout Canvas: "..side)
        local p,scale=vector(root.attributes.position),vector(root.attributes.scale)
        return {root=root,node=node,url=objectAssetURL(object,node.attributes.image) or node.attributes.image,
            position={p[1]/100,-p[3]/100,p[2]/100},
            width=tonumber(node.attributes.width)*scale[1]/100,
            height=tonumber(node.attributes.height)*scale[2]/100}
    end
    local function hidden(object,message)
        eq(visible(object,"front"),false,message.." no front overlay")
        eq(visible(object,"back"),false,message.." no rear overlay")
    end
    local function displayed(object,url,message)
        local side=object.is_face_down and "back" or "front"
        eq(visible(object,side),true,message.." current physical face is active")
        eq(visible(object,side=="back" and "front" or "back"),false,message.." opposite face is inactive")
        for _,face in ipairs({"front","back"}) do
            local g=graphic(object,face)
            eq(g.url,url,message.." exact asset on "..face)
            eq(g.node.tag,"Image",message.." Canvas Image on "..face)
            eq(g.node.attributes.raycastTarget,"false",message.." image passes mouse through "..face)
            eq(g.root.attributes.raycastTarget,"false",message.." root passes mouse through "..face)
            eq(g.node.attributes.onClick,nil,message.." no image click handler "..face)
        end
        eq(select(2,managedDecal(object,"SG_UNIT_DEFEAT_FRONT")),0,message.." removes legacy front decal")
        eq(select(2,managedDecal(object,"SG_UNIT_DEFEAT_BACK")),0,message.." removes legacy rear decal")
    end
    local unit=make("udi001")
    local foreign={name="既存家紋",url="https://example.invalid/foreign-decal.png",position={1,2,3},rotation={0,90,0},scale={.4,.5,.1}}
    local similar={name="SG_UNIT_DEFEAT_FRONT_EXTRA",url="https://example.invalid/similar-name.png",position={2,3,4},rotation={0,0,0},scale={.2,.3,.1}}
    unit.decals={copy(foreign),copy(similar),{name="SG_UNIT_DEFEAT_FRONT",url="https://example.invalid/old-rout.png"},
        {name="SG_UNIT_DEFEAT_BACK",url="https://example.invalid/old-rout.png"}}
    unit.UI.xmlTable={{tag="Panel",attributes={id="foreign_rout_neighbor",active="true"}}}
    unit.UI.assets={{name="foreign_rout_asset",url="https://example.invalid/foreign-ui.png"}}
    local function checkForeign(message)
        local retained=managedDecal(unit,"既存家紋")
        eq(retained and retained.url,foreign.url,message.." foreign decal URL")
        near(retained.position[1],foreign.position[1],message.." foreign position")
        near(retained.rotation[2],foreign.rotation[2],message.." foreign rotation")
        near(retained.scale[2],foreign.scale[2],message.." foreign scale")
        eq(managedDecal(unit,"SG_UNIT_DEFEAT_FRONT_EXTRA").url,similar.url,message.." similar prefix retained")
        eq(findNode(unit.UI.xmlTable,"foreign_rout_neighbor").attributes.active,"true",message.." foreign UI retained")
        eq(objectAssetURL(unit,"foreign_rout_asset"),"https://example.invalid/foreign-ui.png",message.." foreign asset retained")
    end
    setupUnit(unit,getUnitConfig(unit)); flush()
    eq(unit.buttons[3].label,"敗走","empty image URL retains rear defeat text")
    eq(unit.buttons[4].label,"敗走","empty image URL retains front defeat text")
    hidden(unit,"missing image")
    eq(select(2,managedDecal(unit,"SG_UNIT_DEFEAT_FRONT")),0,"missing image cleans stale front decal")
    eq(select(2,managedDecal(unit,"SG_UNIT_DEFEAT_BACK")),0,"missing image cleans stale rear decal")
    local imageA="https://example.invalid/unit-defeat-a.png?part=a=b&v=1"
    local imageB="https://example.invalid/unit-defeat-b.png"
    local function checkURL(value,expected,message)
        UNIT_DEFEAT_IMAGE_URL=value; updateDefeatText(unit); flush()
        displayed(unit,expected,message)
        eq(unit.buttons[3].label,"",message.." suppresses rear text fallback")
        eq(unit.buttons[4].label,"",message.." suppresses front text fallback")
    end
    checkURL(" \t"..imageA.."\194\160",imageA,"trim spaces and UTF-8 NBSP")
    local steamURL="https://steamusercontent-a.akamaihd.net/ugc/17054381960929243766/8D21B8759B3A9DFDEF549D1E5ECCE4E8D5DC9E5E/"
    checkURL(steamURL,steamURL,"real Steam CDN URL")
    local prefix="https://example.invalid/"
    for _,length in ipairs({64,65,106,200,512,2048,4096,16384}) do
        local longURL=prefix..string.rep("a",length-#prefix)
        checkURL(longURL,longURL,"URL length "..length)
    end
    local queryURL="https://example.invalid/mark(1).png?path=a=b&filter=[one](two)&escaped=%20%25&tail=++#image"
    checkURL(queryURL,queryURL,"query punctuation remains literal")
    for _,whitespace in ipairs({" \t\r\n"," ","\194\160","　","\227\128\128","﻿","\239\187\191"}) do
        checkURL(whitespace..steamURL..whitespace,steamURL,"surrounding ASCII or Unicode whitespace")
    end
    checkURL(imageA,imageA,"restore URL after long-address regression")
    local front,back=graphic(unit,"front"),graphic(unit,"back")
    near(front.position[1],1/6,"front rout centered in 1000-pixel body at X500")
    near(back.position[1],-1/6,"rear rout mirrors body center X")
    near(front.position[3],1/6,"rout body center Y700")
    near(back.position[3],1/6,"rear rout body center Y700")
    near(front.position[2],.1+UNIT_ROUT_LAYOUT.surface_clearance,"front rout follows real surface")
    near(back.position[2],-.1+.099-UNIT_ROUT_LAYOUT.surface_clearance,"rear rout retains calibrated near plane")
    near(front.width,1,"default rout width uses 600 pixels")
    near(front.height,.5,"two-to-one rout aspect")
    eq(front.root.attributes.rotation,"0 0 180","front rout art upright")
    eq(back.root.attributes.rotation,"180 0 0","rear rout art upright")
    checkForeign("initial rout mount")
    local writes,xml,assets,attributes=unit.decalWrites,unit.UI.xmlCalls,unit.UI.assetCalls,unit.UI.attributeCalls
    local scanBefore=scans
    for n=1,3 do refreshUnitRoutOverlays(); flush() end
    eq(scans,scanBefore,"rout refresh never scans all objects")
    eq(unit.decalWrites,writes,"stable rout refresh does not rewrite decals")
    eq(unit.UI.xmlCalls,xml,"stable rout refresh does not rebuild XML")
    eq(unit.UI.assetCalls,assets,"stable rout refresh does not reload images")
    eq(unit.UI.attributeCalls,attributes,"stable rout refresh writes no unchanged UI attributes")
    checkURL(imageB,imageB,"new rout URL replaces both face assets")
    unit.is_face_down=true; refreshUnitRoutOverlays(); flush()
    displayed(unit,imageB,"physical flip swaps visible face")
    unit.scale={x=2,y=3,z=.5}; unit.bounds={size={x=4,y=.6,z=1},offset={x=.4,y=.3,z=-.2}}
    updateDefeatText(unit); flush()
    front,back=graphic(unit,"front"),graphic(unit,"back")
    near(front.position[1],.2+1/6,"scaled front includes model center offset")
    near(back.position[1],.2-1/6,"scaled rear mirrors around model center")
    near(front.position[3],-.4+1/6,"scaled rout uses normalized model depth")
    near(front.position[2],.2+UNIT_ROUT_LAYOUT.surface_clearance,"scaled front surface clearance")
    near(back.position[2],.099-UNIT_ROUT_LAYOUT.surface_clearance,"scaled rear surface clearance")
    near(front.width,1,"nonuniform scaling retains artwork proportion")
    unit.scale={x=1,y=1,z=1}; unit.bounds={size={x=2,y=.2,z=2},offset={x=0,y=0,z=0}}
    UNIT_DEFEAT_IMAGE_ASPECT=.25; updateDefeatText(unit); flush()
    front=graphic(unit,"front")
    near(front.height,UNIT_ROUT_LAYOUT.max_height/1200*2,"tall marker stays inside body height limit")
    near(front.width/front.height,.25,"tall marker retains aspect ratio")
    for _,aspect in ipairs({0,-1,math.huge,0/0}) do
        UNIT_DEFEAT_IMAGE_ASPECT=aspect; updateDefeatText(unit); flush()
        front=graphic(unit,"front")
        eq(front.width>0 and front.height>0 and front.width<math.huge and front.height<math.huge,true,"invalid aspect stays finite")
        eq(front.height<=UNIT_ROUT_LAYOUT.max_height/1200*2+.00001,true,"invalid aspect stays within height limit")
    end
    UNIT_DEFEAT_IMAGE_ASPECT=2
    for _,invalid in ipairs({"","file:///local/mark.png","https://example.invalid/a b.png","https://example.invalid/a\tb.png",
        "https://example.invalid/a\nb.png","https://example.invalid/a b.png","https://example.invalid/a\194\160b.png",
        "https://example.invalid/a　b.png","https://example.invalid/a\227\128\128b.png","https://example.invalid/a﻿b.png",
        "https://example.invalid/a\239\187\191b.png",17}) do
        checkURL(imageA,imageA,"restore valid URL before invalid test")
        UNIT_DEFEAT_IMAGE_URL=invalid; updateDefeatText(unit); flush()
        hidden(unit,"invalid rout URL")
        eq(unit.buttons[3].label,"敗走","invalid image retains rear text fallback")
        eq(unit.buttons[4].label,"敗走","invalid image retains front text fallback")
        checkForeign("invalid URL cleanup")
    end
    checkURL(imageA,imageA,"restore rout image")
    -- A duplicate URL must reuse its registered asset, not enqueue the same image twice.
    UNIT_DEFEAT_IMAGE_URL=UNIT_NUMBER_BACK_IMAGES[4]; updateDefeatText(unit); flush()
    displayed(unit,UNIT_NUMBER_BACK_IMAGES[4],"duplicate registered rout URL")
    local duplicateCount=0
    for _,asset in ipairs(unit.UI.assets) do if asset.url==UNIT_DEFEAT_IMAGE_URL then duplicateCount=duplicateCount+1 end end
    eq(duplicateCount,1,"duplicate rout/digit URL registered only once")
    UNIT_DEFEAT_IMAGE_URL="https://example.invalid/foreign-ui.png"; updateDefeatText(unit); flush()
    displayed(unit,UNIT_DEFEAT_IMAGE_URL,"duplicate foreign asset URL")
    duplicateCount=0
    for _,asset in ipairs(unit.UI.assets) do if asset.url==UNIT_DEFEAT_IMAGE_URL then duplicateCount=duplicateCount+1 end end
    eq(duplicateCount,1,"rout reuses foreign URL without duplicating or deleting it")
    checkForeign("duplicate URL handling")
    checkURL(imageA,imageA,"restore independent rout URL")
    unit_state.udi001.manual_defeat_visible=false; unit_state.udi001.back_value=3
    updateDefeatText(unit); flush(); hidden(unit,"clear rout state")
    eq(unit.buttons[3].label,"","clear rout hides text too")
    unit_state.udi001.back_value=0; updateDefeatText(unit); flush()
    displayed(unit,imageA,"automatic rear-zero rout")
    changeBackValue(unit,"White",false); flush(); hidden(unit,"positive recovery removes rout")
    toggleDefeatText(unit); flush(); displayed(unit,imageA,"manual rout toggle")
    local saved=onSave(); unit_state={}; onLoad(saved); flush(); tick()
    eq(unit_state.udi001.manual_defeat_visible,true,"manual rout survives save/load")
    displayed(unit,imageA,"saved rout reappears without decal duplication")
    checkForeign("save/load")
    resetUnit(unit); flush(); hidden(unit,"explicit unit reset")
    unit_state.udi001.back_value=0; updateDefeatText(unit); flush()
    hotkeys["士気快捷調整"].callback("White",unit,nil,false)
    changeBackValue(unit,"White",false)
    hotkeys["士気快捷調整"].callback("White",unit,nil,true)
    flush(); hidden(unit,"quick refill immediately removes rout overlay")
    -- Physics fixture uses world AABBs and inverse transforms, independently of UI positions.
    -- Deliberately avoid changing token() globally; older tests model no physics.
    local physical=make("urphys")
    physical.world={x=31,y=8,z=-19}; physical.yaw=0
    physical.positionToLocal=function(p)
        local x,y,z=(p.x or p[1])-physical.world.x,(p.y or p[2])-physical.world.y,(p.z or p[3])-physical.world.z
        local a=math.rad(physical.yaw); local rx,rz=x*math.cos(a)-z*math.sin(a),x*math.sin(a)+z*math.cos(a)
        if physical.is_face_down then y,rz=-y,-rz end
        return {x=rx/physical.scale.x,y=y/physical.scale.y,z=rz/physical.scale.z}
    end
    physical.positionToWorld=function(p)
        local x,y,z=(p.x or p[1])*physical.scale.x,(p.y or p[2])*physical.scale.y,(p.z or p[3])*physical.scale.z
        if physical.is_face_down then y,z=-y,-z end
        local a=math.rad(physical.yaw)
        return {x=physical.world.x+x*math.cos(a)+z*math.sin(a),y=physical.world.y+y,z=physical.world.z-x*math.sin(a)+z*math.cos(a)}
    end
    physical.getPosition=function() return copy(physical.world) end
    physical.getRotation=function() return {x=0,y=physical.yaw,z=physical.is_face_down and 180 or 0} end
    local commander=token("武將","team=iwatsuke_shu\nrole=main","urcmd1")
    created[#created+1]=commander
    commander.collider={center={x=31,y=8.25,z=-19},size={x=.8,y=.3,z=.8}}
    commander.getBounds=function() commander.boundsReads=commander.boundsReads+1; return copy(commander.collider) end
    local snapshot={urcmd1={object=commander,team="iwatsuke_shu",role="main"}}
    setUnitRoutSnapshot(snapshot)
    setupUnit(physical,getUnitConfig(physical)); flush()
    near(graphic(physical,"front").position[2],.42,"commander top lifts rout plus small clearance")
    local function refreshHeight(expected,message)
        refreshUnitRoutOverlays(); flush()
        near(graphic(physical,physical.is_face_down and "back" or "front").position[2],expected,message)
    end
    local baseline=.1+UNIT_ROUT_LAYOUT.surface_clearance
    commander.held_by_color="White"; refreshHeight(baseline,"held commander is excluded")
    commander.held_by_color=nil; commander.loading_custom=true; refreshHeight(baseline,"loading commander is excluded")
    commander.loading_custom=false; commander.spawning=true; refreshHeight(baseline,"spawning commander is excluded")
    commander.spawning=false
    commander.collider.center.x=33; refreshHeight(baseline,"neighbor commander cannot raise marker")
    commander.collider.center.x=31; commander.collider.center.y=9
    refreshHeight(baseline,"airborne commander cannot raise marker")
    commander.collider.center.y=8.25
    snapshot.urcmd1.role="unit"; setUnitRoutSnapshot(snapshot); refreshHeight(baseline,"unit role is not treated as commander")
    for _,role in ipairs({"main","deputy1","deputy2"}) do
        snapshot.urcmd1.role=role; setUnitRoutSnapshot(snapshot); refreshHeight(.42,"eligible commander role "..role)
    end
    objects.urcmd1=nil; refreshHeight(baseline,"removed commander is excluded from stale snapshot")
    objects.urcmd1=commander
    commander.collider.center.y=8.1
    refreshHeight(baseline,"same-table commander is not stacked on top")
    commander.collider.center.y=8.25
    physical.is_face_down=true; refreshHeight(-.42,"rear rout lifts outward above stacked commander")
    displayed(physical,imageA,"stacked rear only displays rear image")
    physical.is_face_down=false; physical.yaw=90
    refreshHeight(.42,"rotated and translated tile still finds commander")
    physical.scale={x=2,y=3,z=.5}; physical.bounds={size={x=4,y=.6,z=1},offset={x=0,y=0,z=0}}
    commander.collider.center.y=8.45
    refreshHeight(.22,"scaled tile transforms commander world height into local space")
    physical.is_face_down=true; refreshHeight(-.22,"scaled rear commander height points outward")
    setUnitRoutSnapshot({}); refreshHeight(-.011,"removing last commander returns rear to calibrated near plane")
    onObjectDrop("White",commander); flush(); tick()
    near(graphic(physical,"back").position[2],-.22,"existing panel timer refreshes newly registered commander")
    onObjectEnterContainer(nil,commander); flush(); tick()
    near(graphic(physical,"back").position[2],-.011,"commander in container removed from registry even if object still exists")
    local readBefore=commander.boundsReads
    local scanBeforeRefresh=scans
    refreshUnitRoutOverlays(); flush()
    eq(scans,scanBeforeRefresh,"commander refresh uses supplied registry without world scan")
    eq(commander.boundsReads,readBefore,"empty snapshot does not inspect removed commander")
    -- Resource loads must resolve against current rout state and current physical face.
    local loading=make("urload"); loading.UI.holdAssets=true
    setupUnit(loading,getUnitConfig(loading)); flush()
    hidden(loading,"pending custom assets")
    unit_state.urload.manual_defeat_visible=false
    loading.is_face_down=true
    updateDefeatText(loading)
    loading.UI.holdAssets=false; loading.UI.loading=false; flush()
    hidden(loading,"rout cleared while image was loading")
    unit_state.urload.manual_defeat_visible=true; updateDefeatText(loading); flush()
    displayed(loading,imageA,"later rout uses current rear face")
    loading.tags.unit_nagaye_ashigaru=nil; clearUnitCounterVisuals(loading); flush()
    hidden(loading,"removed unit tag cleans rout UI")
    -- Model readiness regression: do not measure or build while model is spawning/loading.
    UNIT_DEFEAT_IMAGE_URL=""
    local model=token("加载中的足軽","","udload")
    created[#created+1]=model
    model.tags.unit_nagaye_ashigaru=true; model.tags.count_100=true; model.loading_custom=true
    unit_state.udload={front_value=2,back_value=2,manual_defeat_visible=false}
    local queued=#conditions
    setupUnit(model,getUnitConfig(model)); setupUnit(model,getUnitConfig(model))
    eq(#conditions,queued+1,"repeated setup queues one model readiness waiter")
    eq(#model.buttons,0,"loading model has no prematurely positioned buttons")
    eq(model.boundsReads,0,"loading model bounds are not measured prematurely")
    model.tags.count_100=nil; model.tags.count_200=true; model.loading_custom=false; flush()
    eq(model.buttons[1].click_function,"changeFrontValue","loaded model gets front morale button")
    eq(model.buttons[6].click_function,"toggleUnitActed","loaded model gets rear action button")
    numberImage(model,"FRONT","COUNT",2,"readiness uses latest quantity tag")
    eq(unit_state.udload.front_value,2,"readiness preserves morale")
    local destroyed=token("移除中的足軽","","udgone")
    destroyed.tags.unit_nagaye_ashigaru=true; destroyed.spawning=true
    setupUnit(destroyed,getUnitConfig(destroyed)); objects.udgone=nil; flush()
    eq(#destroyed.buttons,0,"destroyed pending model is not rebuilt")
    for _,object in ipairs(created) do
        if unit_state[object.guid] then
            unit_state[object.guid].manual_defeat_visible=false; unit_state[object.guid].back_value=3
            if object.tags.unit_nagaye_ashigaru then updateDefeatText(object) end
        end
    end
    flush(); setUnitRoutSnapshot({})
    UNIT_DEFEAT_IMAGE_URL,UNIT_DEFEAT_IMAGE_ASPECT,UNIT_ROUT_LAYOUT=previousURL,previousAspect,previousLayout
    eq(UNIT_DEFEAT_IMAGE_URL,previousURL,"rout tests restore global image URL")
end
local function runUnitProgressionChecks()
    local originalDefeatURL=UNIT_DEFEAT_IMAGE_URL
    UNIT_DEFEAT_IMAGE_URL=""
    local unit=token("二段階士気検証","","prog01")
    unit.tags.unit_nagaye_ashigaru=true; unit.tags.count_200=true
    setupUnit(unit,getUnitConfig(unit))
    eq(unit_state.prog01.front_value,6,"new troop starts with full front morale")
    eq(unit_state.prog01.back_value,5,"new troop starts with full back morale")
    eq(unit_state.prog01.acted,false,"new troop starts unacted")
    eq(unit_state.prog01.manual_defeat_visible,false,"new troop has no manual defeat")
    eq(unit.flipCalls,0,"initial setup never flips troop")
    eq(unit.buttons[3].label,"","fresh full troop is not defeated")
    eq(#unit.contextMenu,0,"progression adds no right-click menu")

    local function actionVisuals(acted,message)
        for index,side in ipairs({"FRONT","BACK"}) do
            local graphic=unitGraphic(unit,side,"ACTION")
            eq(select(2,managedDecal(unit,"SG_UNIT_ACTION_"..side)),index==1 and 1 or 0,message.." only front action uses decal "..side)
            local key=(index==1 and "front_" or "back_")..(acted and "acted" or "unacted")
            eq(graphic.url,UNIT_ACTION_IMAGES[key],message.." action state asset "..side)
            near(graphic.position[1],(index==1 and -1 or 1)*(1100/1200-.5)*2,message.." action marker in right corner "..side)
            near(graphic.position[3],(100/1200-.5)*2,message.." action marker remains in header "..side)
            local surface=index==1 and .1+UNIT_DEFEAT_FRONT_GAP+UNIT_SURFACE_CLEARANCE+.001 or -.1+.099
            near(graphic.position[2],surface,message.." action sits on correct face "..side)
            local button=unit.buttons[index+4]
            eq(button.click_function,"toggleUnitActed",message.." action callback "..side)
            buttonAboveDecal(button,graphic,index==2,message.." action "..side)
            eq(button.label,"",message.." successful image needs no overlaid action text "..side)
            eq(button.tooltip,"",message.." no action tooltip "..side)
        end
    end
    actionVisuals(false,"fresh troop")
    local rail=backGraphic(unit,"rail")
    eq(select(2,managedDecal(unit,"SG_UNIT_BACK_RAIL")),0,"independent rear background decal removed")
    eq(rail.url,UNIT_BACK_RAIL_IMAGE_URL,"single Canvas reuses uploaded dark artwork")
    near(rail.position[2],-.1+.099,"rear Canvas retains user-calibrated offset from bottom reference")
    eq(rail.root.tag,"Panel","back images share one Panel")
    eq(rail.root.attributes.rotation,"180 0 0","back Canvas faces physical underside")
    eq(rail.root.attributes.raycastTarget,"false","back Canvas does not intercept classic clicks")
    eq(#rail.root.children,6,"back Canvas has six ordered Image children including optional morale band")
    for index,kind in ipairs({"rail","count","morale","move","action","morale_band"}) do
        local node=rail.root.children[index]
        eq(node.attributes.id,"sgub_"..kind,"Canvas child draw order "..kind)
        eq(node.tag,"Image","Canvas uses native image layering "..kind)
        eq(node.attributes.raycastTarget,"false","Canvas child passes pointer through "..kind)
        near(backGraphic(unit,kind).position[2],rail.position[2],"Canvas child shares common plane "..kind)
    end
    for _,kind in ipairs({"COUNT","MORALE","MOVE"}) do
        eq(select(2,managedDecal(unit,"SG_UNIT_NUM_BACK_"..kind)),0,"rear number no longer separate transparent renderer "..kind)
    end
    near(UNIT_DEFEAT_FRONT_GAP,-.01,"working front face calibration is preserved")
    near(UNIT_DEFEAT_BACK_GAP,-.099,"existing back defeat and flag calibration is preserved")
    near(UNIT_SURFACE_CLEARANCE,.001,"user-calibrated decal clearance remains unchanged")
    local originalFrontNumber=.1+UNIT_DEFEAT_FRONT_GAP+.001
    local originalFrontAction=originalFrontNumber+.001
    for _,kind in ipairs({"COUNT","MORALE","MOVE"}) do
        near(managedDecal(unit,"SG_UNIT_NUM_FRONT_"..kind).position[2],originalFrontNumber,"Canvas migration leaves working front digit plane unchanged "..kind)
    end
    near(managedDecal(unit,"SG_UNIT_ACTION_FRONT").position[2],originalFrontAction,"Canvas migration leaves front action plane unchanged")
    near(classicButtonObjectPosition(unit.buttons[6])[2],rail.position[2]-.004,"back action hit remains outward from Canvas")
    near(classicButtonObjectPosition(unit.buttons[2])[2],rail.position[2]-.004,"back morale hit remains outward from Canvas")
    local savedClearance=UNIT_SURFACE_CLEARANCE
    UNIT_SURFACE_CLEARANCE=savedClearance+.02
    updateDefeatText(unit)
    near(managedDecal(unit,"SG_UNIT_NUM_FRONT_COUNT").position[2],originalFrontNumber+.02,"front decal still follows configured clearance")
    near(backGraphic(unit,"rail").position[2],rail.position[2],"Canvas independent of obsolete decal separation")
    unit.scale={x=2,y=3,z=.5}; unit.bounds={size={x=4,y=.6,z=1},offset={x=.4,y=.3,z=-.2}}
    updateDefeatText(unit)
    local scaledRail=backGraphic(unit,"rail")
    near(scaledRail.position[2],.099,"offset scaled Canvas retains user-calibrated offset from bottom reference")
    for _,kind in ipairs({"count","morale","move","action"}) do
        near(backGraphic(unit,kind).position[2],scaledRail.position[2],"nonuniform scale retains one shared Canvas "..kind)
    end
    near((classicButtonObjectPosition(unit.buttons[6])[2]-scaledRail.position[2])*unit.scale.y,-.012,"nonuniform scale preserves outward clickable back plane")
    local scaledFrontNumber=managedDecal(unit,"SG_UNIT_NUM_FRONT_COUNT")
    near((managedDecal(unit,"SG_UNIT_ACTION_FRONT").position[2]-scaledFrontNumber.position[2])*unit.scale.y,.003,"nonuniform scaling keeps original front action lift")
    for index,side in ipairs({"FRONT","BACK"}) do
        buttonAboveDecal(unit.buttons[index],unitGraphic(unit,side,"MORALE"),index==2,"scaled morale "..side)
        buttonAboveDecal(unit.buttons[index+4],unitGraphic(unit,side,"ACTION"),index==2,"scaled action "..side)
    end
    UNIT_SURFACE_CLEARANCE=savedClearance
    unit.scale={x=1,y=1,z=1}; unit.bounds={size={x=2,y=.2,z=2},offset={x=0,y=0,z=0}}
    updateDefeatText(unit); actionVisuals(false,"restored safety offsets")
    local writes,xmlWrites,assetWrites,attributeWrites=unit.decalWrites,unit.UI.xmlCalls,unit.UI.assetCalls,unit.UI.attributeCalls
    setupUnit(unit,getUnitConfig(unit)); updateDefeatText(unit); flush()
    eq(unit.decalWrites,writes,"identical front art refresh is idempotent")
    eq(unit.UI.xmlCalls,xmlWrites,"identical Canvas refresh never rebuilds XML")
    eq(unit.UI.assetCalls,assetWrites,"identical Canvas refresh never reloads resources")
    eq(unit.UI.attributeCalls,attributeWrites,"identical Canvas refresh avoids redundant attribute writes")
    _G[unit.buttons[5].click_function](unit,"Red",false)
    eq(unit_state.prog01.acted,true,"non-host can mark troop acted from front corner")
    eq(unit.is_face_down,false,"marking acted never flips troop")
    actionVisuals(true,"marked from front")
    _G[unit.buttons[6].click_function](unit,"Blue",true)
    eq(unit_state.prog01.acted,false,"another player can clear common action state from back corner")
    actionVisuals(false,"cleared from back")
    toggleUnitActed(unit,"Grey",false)
    eq(unit_state.prog01.acted,true,"spectator color has same action access")

    unit_state.prog01.back_value=2
    unit_state.prog01.manual_defeat_visible=true
    for expected=5,1,-1 do
        _G[unit.buttons[1].click_function](unit,"Red",true)
        eq(unit_state.prog01.front_value,expected,"front morale decreases toward transition "..expected)
        eq(unit.flipCalls,0,"positive front morale never auto flips "..expected)
        eq(unit_state.prog01.back_value,2,"no premature back replenishment "..expected)
        eq(unit_state.prog01.acted,true,"damage preserves action state "..expected)
    end
    _G[unit.buttons[1].click_function](unit,"Red",true)
    eq(unit_state.prog01.front_value,0,"front depleted at transition")
    eq(unit_state.prog01.back_value,5,"front depletion fills back to configured five")
    eq(unit_state.prog01.manual_defeat_visible,false,"front transition clears prior manual defeat")
    eq(unit.is_face_down,true,"front depletion flips to second stage")
    eq(unit.flipCalls,1,"transition flips exactly once")
    eq(unit_state.prog01.acted,true,"front transition preserves acted state")
    eq(unit.buttons[3].label,"","second stage starts without defeat")
    numberImage(unit,"BACK","MORALE",5,"second stage full morale image")
    numberImage(unit,"BACK","MOVE",3,"second stage fixed movement image")
    actionVisuals(true,"after first-stage exhaustion")
    changeBackValue(unit,"Blue",true)
    eq(unit_state.prog01.back_value,5,"flip animation guard also ignores a stray rear damage click")
    for n=1,3 do changeFrontValue(unit,"Red",true) end
    eq(unit_state.prog01.back_value,5,"repeated zero front does not alter second stage during flip")
    eq(unit.flipCalls,1,"repeated zero front does not flip again")
    changeFrontValue(unit,"Red",false)
    eq(unit_state.prog01.front_value,0,"flip animation guard ignores a stray front correction click")
    tick()
    changeBackValue(unit,"Blue",true)
    eq(unit_state.prog01.back_value,4,"second-stage damage subtracts normally after the flip guard")
    changeFrontValue(unit,"Red",true)
    eq(unit_state.prog01.back_value,4,"zero front still cannot refill after animation lock expires")
    for expected=3,0,-1 do
        changeBackValue(unit,"Blue",true)
        eq(unit_state.prog01.back_value,expected,"back morale decreases "..expected)
        eq(unit.flipCalls,1,"back damage never flips to first stage "..expected)
    end
    eq(unit.buttons[3].label,"敗走","second-stage zero shows back defeat")
    eq(unit.buttons[4].label,"敗走","second-stage zero shows front defeat too")
    changeBackValue(unit,"Red",true); changeFrontValue(unit,"Blue",true)
    eq(unit_state.prog01.back_value,0,"repeated zero preserves defeat")
    eq(unit_state.prog01.acted,true,"defeat preserves action flag")
    local saved=onSave()
    unit_state={}; onLoad(saved); flush(); tick()
    eq(unit_state.prog01.front_value,0,"depleted first stage persists through save load")
    eq(unit_state.prog01.back_value,0,"depleted second stage persists through save load")
    eq(unit_state.prog01.acted,true,"action persists through save load")
    eq(unit.flipCalls,1,"save load does not retrigger transition")
    eq(unit.buttons[3].label,"敗走","defeat persists through save load")
    actionVisuals(true,"save loaded action")

    unit_state.prog01.manual_defeat_visible=true
    changeBackValue(unit,"Red",false)
    eq(unit_state.prog01.back_value,1,"left click can recover morale from zero")
    eq(unit_state.prog01.manual_defeat_visible,false,"positive recovery clears obsolete manual defeat")
    eq(unit.buttons[3].label,"","positive recovery removes defeat")
    eq(unit.is_face_down,true,"recovery stays on second stage")
    changeFrontValue(unit,"Red",false)
    eq(unit_state.prog01.front_value,1,"front correction can recover first-stage value")
    eq(unit.flipCalls,1,"front correction does not auto flip back")
    changeFrontValue(unit,"Red",true)
    eq(unit_state.prog01.back_value,5,"positive-to-zero first-stage correction refills back")
    eq(unit.flipCalls,1,"transition already face down never toggles back up")

    -- Legacy saved zero means an existing exhausted state, not a new unit.
    unit_state.prog01={front_value=3,back_value=0,manual_defeat_visible=false,acted=true}
    setupUnit(unit,getUnitConfig(unit))
    eq(unit_state.prog01.back_value,0,"existing zero back is not silently refilled")
    eq(unit.buttons[3].label,"敗走","legacy positive front with zero back still means defeat")
    eq(unit.flipCalls,1,"legacy-state setup never flips token")
    unit_state.prog01={front_value=0,back_value=2,manual_defeat_visible=false}
    unit.is_face_down=false
    setupUnit(unit,getUnitConfig(unit))
    eq(unit_state.prog01.front_value,0,"existing zero front is preserved")
    eq(unit_state.prog01.back_value,2,"existing partial back is preserved")
    eq(unit_state.prog01.acted,false,"legacy record without acted defaults unacted")
    eq(unit.is_face_down,false,"loading old front zero never forces a flip")
    eq(unit.flipCalls,1,"loading old front zero never calls flip")
    unit_state.prog01.acted=true; unit_state.prog01.manual_defeat_visible=true
    resetUnit(unit)
    eq(unit_state.prog01.front_value,6,"explicit reset fills front")
    eq(unit_state.prog01.back_value,5,"explicit reset fills back")
    eq(unit_state.prog01.acted,false,"explicit reset clears acted")
    eq(unit_state.prog01.manual_defeat_visible,false,"explicit reset clears manual defeat")
    eq(unit.flipCalls,1,"explicit value reset preserves physical orientation")

    -- Verify all pale numeral assets and that a missing rear asset never reuses black front digits.
    local maximum=UNIT_CONFIGS[1].max_back
    UNIT_CONFIGS[1].max_back=8
    for value=0,8 do
        unit_state.prog01.back_value=value; setupUnit(unit,getUnitConfig(unit))
        numberImage(unit,"BACK","MORALE",value,"back nine-image set "..value)
    end
    -- The added eight must switch synchronously within the mounted Canvas.
    unit_state.prog01.back_value=7; setupUnit(unit,getUnitConfig(unit)); flush()
    local eightXML,eightAssets=unit.UI.xmlCalls,unit.UI.assetCalls
    local eightImageWrites=unit.UI.imageWrites.sgub_morale or 0
    changeBackValue(unit,"Red",false)
    eq(unit_state.prog01.back_value,8,"click increases rear morale from seven to eight")
    eq(findNode(unit.UI.xmlTable,"sgub_morale").attributes.image,UNIT_NUMBER_BACK_IMAGES[8],"new eight binds direct URL in the same callback without Wait")
    eq(unit.UI.imageWrites.sgub_morale,eightImageWrites+1,"switch to eight writes one image attribute")
    eq(unit.UI.xmlCalls,eightXML,"switch to eight preserves mounted Canvas")
    eq(unit.UI.assetCalls,eightAssets,"switch to eight does not reload resources")
    numberImage(unit,"BACK","MORALE",8,"eighth rear digit after direct click")
    local eightURL=UNIT_NUMBER_BACK_IMAGES[8]
    UNIT_NUMBER_BACK_IMAGES[8]="C:/Users/HP/Documents/ChatGPT/日本战国/TTS武将面板/部隊操作素材_v2.13/PNG/数字_背面_8.png"
    setupUnit(unit,getUnitConfig(unit))
    numberImage(unit,"BACK","MORALE",8,"eighth rear digit accepts absolute local PNG path")
    UNIT_NUMBER_BACK_IMAGES[8]=""
    setupUnit(unit,getUnitConfig(unit)); flush()
    eq(findNode(unit.UI.xmlTable,"sgub_morale").attributes.active,"false","missing eighth rear digit hides stale Canvas image")
    eq(unit.buttons[2].label,"","missing eighth rear digit leaves no numeral text")
    eq(unit_state.prog01.back_value,8,"missing eighth rear image preserves gameplay value")
    _G[unit.buttons[2].click_function](unit,"Red",true)
    eq(unit_state.prog01.back_value,7,"missing rear numeral retains usable decrement hit area")
    _G[unit.buttons[2].click_function](unit,"Red",false)
    eq(unit_state.prog01.back_value,8,"rear morale click can return to a value with no configured image")
    eq(unit.buttons[2].label,"","missing rear numeral keeps transparent hit area after a click")
    UNIT_NUMBER_BACK_IMAGES[8]=eightURL; setupUnit(unit,getUnitConfig(unit))
    numberImage(unit,"BACK","MORALE",8,"eighth rear digit restores after missing image")
    UNIT_CONFIGS[1].max_back=maximum
    unit_state.prog01.back_value=4
    local rearURL=UNIT_NUMBER_BACK_IMAGES[4]
    UNIT_NUMBER_BACK_IMAGES[4]=""
    setupUnit(unit,getUnitConfig(unit))
    eq(findNode(unit.UI.xmlTable,"sgub_morale").attributes.active,"false","missing pale number hides previous rear Canvas image")
    eq(unit.buttons[2].label,"","missing pale morale leaves no classic text")
    eq(unit_state.prog01.back_value,4,"missing rear digit never changes morale")
    UNIT_NUMBER_BACK_IMAGES[4]=rearURL; setupUnit(unit,getUnitConfig(unit))
    numberImage(unit,"BACK","MORALE",4,"restored pale number")

    local actionImages=UNIT_ACTION_IMAGES
    UNIT_ACTION_IMAGES={}
    setupUnit(unit,getUnitConfig(unit)); flush()
    eq(select(2,managedDecal(unit,"SG_UNIT_ACTION_FRONT")),0,"missing action images remove front action artwork")
    eq(findNode(unit.UI.xmlTable,"sgub_action").attributes.active,"false","missing action images hide stale rear action artwork")
    for index,expected in ipairs({true,false}) do
        local button=unit.buttons[index+4]
        eq(button.label,"","missing action images leave both hit areas free of text "..index)
        _G[button.click_function](unit,"Blue",false)
        eq(unit_state.prog01.acted,expected,"missing action images retain clickable action state "..index)
        eq(unit.buttons[index+4].label,"","action state changes do not introduce fallback text "..index)
    end
    UNIT_ACTION_IMAGES=actionImages
    setupUnit(unit,getUnitConfig(unit)); flush()
    actionVisuals(false,"restored action images")

    toggleUnitActed(unit,"Red",false)
    unit.tags.unit_nagaye_ashigaru=nil
    toggleUnitActed(unit,"Blue",false)
    eq(unit_state.prog01.acted,true,"removed unit tag disables action callback")
    clearUnitCounterVisuals(unit); flush()
    eq(#unit.buttons,0,"removing unit tag clears all six owned buttons")
    eq(findNode(unit.UI.xmlTable,"sgub_root"),nil,"removing unit tag clears entire back Canvas")
    eq(select(2,managedDecal(unit,"SG_UNIT_ACTION_FRONT")),0,"removing unit tag clears front action mark")
    eq(select(2,managedDecal(unit,"SG_UNIT_ACTION_BACK")),0,"removing unit tag clears back action mark")
    eq(unit_state.prog01.acted,true,"tag removal preserves action save data")
    unit.tags.unit_nagaye_ashigaru=true; setupUnit(unit,getUnitConfig(unit))
    actionVisuals(true,"readding unit tag restores acted state")
    objects.prog01=nil; unit_state.prog01=nil
    UNIT_DEFEAT_IMAGE_URL=originalDefeatURL
end
local function runUnitBackUIChecks()
    local unit=token("背面 Canvas 异步验证","","uican1")
    unit.tags.unit_nagaye_ashigaru=true; unit.tags.count_200=true
    unit.UI.xmlTable={{tag="Panel",attributes={id="foreign_container"},children={
        {tag="Text",attributes={id="foreign_nested"},value="保留"},
        {tag="Panel",attributes={id="sgub_legacy"}}}},
        {tag="Panel",attributes={id="sgmf_root"},children={{tag="Text",attributes={id="sgmf_external"},value="旗"}}}}
    unit.UI.assets={{name="foreign_asset",url="https://example.invalid/foreign.png"},
        {name="sgmf_flag",url="https://example.invalid/flag.png"},
        {name="sgub_obsolete",url="https://example.invalid/obsolete.png"}}
    for _,name in ipairs({"SG_UNIT_BACK_RAIL","SG_UNIT_NUM_BACK_COUNT","SG_UNIT_NUM_BACK_MORALE","SG_UNIT_NUM_BACK_MOVE","SG_UNIT_ACTION_BACK"}) do
        unit.decals[#unit.decals+1]={name=name,url="https://example.invalid/old.png",position={0,0,0},rotation={0,0,0},scale={1,1,1}}
    end
    unit.UI.holdAssets=true
    setupUnit(unit,getUnitConfig(unit)); flush()
    eq(unit.UI.loading,true,"first Canvas asset registration can load asynchronously")
    eq(findNode(unit.UI.xmlTable,"sgub_root"),nil,"loading resources do not create unresolved Canvas images")
    for kind,url in pairs({rail=UNIT_BACK_RAIL_IMAGE_URL,count=UNIT_NUMBER_BACK_IMAGES[2],
        morale=UNIT_NUMBER_BACK_IMAGES[5],move=UNIT_NUMBER_BACK_IMAGES[3],action=UNIT_ACTION_IMAGES.back_unacted}) do
        local node=findNode(unit.UI.xmlTable,"sgub_"..kind)
        eq(node,nil,"XML child waits for resource registration: "..kind)
        local registered=false
        for _,asset in ipairs(unit.UI.assets) do if asset.url==url then registered=true end end
        eq(registered,true,"complete image URL has reached explicit resource registry: "..kind)
        eq(unit.UI.imageWrites["sgub_"..kind] or 0,0,"initial XML does not pretend to perform post-load binding: "..kind)
    end
    eq(unit.UI.attributeCalls,0,"loading Canvas postpones attribute binding")
    eq(unit.buttons[2].label,"","loading rear image never introduces competing morale text")
    eq(unit.buttons[6].label,"","loading rear image never introduces competing action text")
    local xmlWrites,assetWrites=unit.UI.xmlCalls,unit.UI.assetCalls
    for n=1,3 do setupUnit(unit,getUnitConfig(unit)); flush() end
    eq(unit.UI.xmlCalls,xmlWrites,"pending setup does not start duplicate Canvas rebuilds")
    eq(unit.UI.assetCalls,assetWrites,"pending setup does not restart resource loads")
    unit_state.uican1.back_value=2; unit_state.uican1.acted=true
    unit.tags.count_200=nil; unit.tags.count_300=true
    updateDefeatText(unit); flush()
    eq(unit.UI.attributeCalls,0,"state changes during load never touch unready nodes")
    unit.UI.holdAssets=false; unit.UI.loading=false; flush()
    numberImage(unit,"BACK","COUNT",3,"loaded Canvas uses latest quantity")
    numberImage(unit,"BACK","MORALE",2,"loaded Canvas uses latest morale")
    eq(backGraphic(unit,"action").url,UNIT_ACTION_IMAGES.back_acted,"loaded Canvas uses latest action state")
    eq(findNode(unit.UI.xmlTable,"sgub_root").attributes.active,"true","complete Canvas displayed after binding")
    local readyAt,bindAt={},{ }
    for index,write in ipairs(unit.UI.attributeLog) do
        if write.id=="sgub_root" and write.key=="active" and write.value=="true" then readyAt=index end
        if write.key=="image" and write.id:sub(1,5)=="sgub_" then bindAt[write.id]=index end
    end
    eq(type(readyAt),"number","ready Canvas is explicitly revealed after resource loading")
    for _,kind in ipairs({"rail","count","morale","move","action"}) do
        local id="sgub_"..kind
        eq(unit.UI.imageWrites[id],1,"ready Canvas explicitly rebinds direct URL once: "..kind)
        eq(type(bindAt[id])=="number" and bindAt[id]<readyAt,true,"direct URL rebind precedes revealing complete root: "..kind)
    end
    eq(findNode(unit.UI.xmlTable,"foreign_nested").value,"保留","mount keeps nested external UI")
    eq(findNode(unit.UI.xmlTable,"sgmf_external").value,"旗","mount keeps map flag UI")
    eq(findNode(unit.UI.xmlTable,"sgub_legacy"),nil,"migration removes nested obsolete owned UI")
    eq(objectAssetURL(unit,"foreign_asset"),"https://example.invalid/foreign.png","mount preserves external resources")
    eq(objectAssetURL(unit,"sgmf_flag"),"https://example.invalid/flag.png","mount preserves flag resource")
    eq(objectAssetURL(unit,"sgub_obsolete"),nil,"mount removes obsolete owned resource")
    local names,count={},0
    for _,asset in ipairs(unit.UI.assets) do
        if asset.name:sub(1,5)=="sgub_" then
            eq(names[asset.name],nil,"back resource names are unique: "..asset.name)
            names[asset.name]=true; count=count+1
        end
    end
    eq(count,12,"all back visuals reuse fixed twelve-image registry")
    for _,name in ipairs({"SG_UNIT_BACK_RAIL","SG_UNIT_NUM_BACK_COUNT","SG_UNIT_NUM_BACK_MORALE","SG_UNIT_NUM_BACK_MOVE","SG_UNIT_ACTION_BACK"}) do
        eq(select(2,managedDecal(unit,name)),0,"migration removes independent transparent renderer "..name)
    end
    xmlWrites,assetWrites=unit.UI.xmlCalls,unit.UI.assetCalls
    local beforeImageWrites=unit.UI.imageWrites.sgub_morale or 0
    changeBackValue(unit,"Red",false)
    eq(findNode(unit.UI.xmlTable,"sgub_morale").attributes.image,UNIT_NUMBER_BACK_IMAGES[3],"ready morale click binds direct Image URL immediately without Wait")
    eq(unit.UI.imageWrites.sgub_morale,beforeImageWrites+1,"morale click writes selected image exactly once")
    eq(unit.UI.xmlCalls,xmlWrites,"morale click never rebuilds Canvas")
    eq(unit.UI.assetCalls,assetWrites,"morale click never reloads resources")
    toggleUnitActed(unit,"Blue",false)
    eq(findNode(unit.UI.xmlTable,"sgub_action").attributes.image,UNIT_ACTION_IMAGES.back_unacted,"ready action click binds direct Image URL immediately")
    eq(unit.UI.xmlCalls,xmlWrites,"action click never rebuilds Canvas")
    eq(unit.UI.assetCalls,assetWrites,"action click never reloads resources")
    -- A changed image URL reloads the resource set only once; state altered during it wins.
    local savedURL=UNIT_NUMBER_BACK_IMAGES[3]
    unit.UI.holdAssets=true; UNIT_NUMBER_BACK_IMAGES[3]="https://example.invalid/replaced-three.png"
    updateDefeatText(unit); flush()
    eq(unit.UI.loading,true,"configuration replacement waits for updated image resource")
    local pendingWrites=unit.UI.attributeCalls
    changeBackValue(unit,"Blue",false); toggleUnitActed(unit,"Red",false)
    eq(unit.UI.attributeCalls,pendingWrites,"pending resource replacement receives no premature binding")
    eq(unit.buttons[2].label,"","resource replacement keeps classic morale text hidden")
    eq(unit.buttons[6].label,"","resource replacement keeps classic action text hidden")
    unit.UI.holdAssets=false; unit.UI.loading=false; flush()
    numberImage(unit,"BACK","MORALE",4,"replacement completion uses later morale")
    eq(backGraphic(unit,"action").url,UNIT_ACTION_IMAGES.back_acted,"replacement completion uses later action")
    eq(objectAssetURL(unit,"sgub_digit_3"),"https://example.invalid/replaced-three.png","new URL survives resource reload")
    UNIT_NUMBER_BACK_IMAGES[3]=savedURL; updateDefeatText(unit); flush()
    unit.tags.unit_nagaye_ashigaru=nil
    clearUnitCounterVisuals(unit); flush()
    eq(findNode(unit.UI.xmlTable,"sgub_root"),nil,"tag removal cleans owned Canvas")
    eq(findNode(unit.UI.xmlTable,"foreign_nested").value,"保留","cleanup preserves nested external UI")
    eq(findNode(unit.UI.xmlTable,"sgmf_external").value,"旗","cleanup preserves flag UI")
    eq(objectAssetURL(unit,"sgub_digit_0"),nil,"cleanup releases owned back resource registry")
    eq(objectAssetURL(unit,"foreign_asset"),"https://example.invalid/foreign.png","cleanup preserves external resources")
    eq(objectAssetURL(unit,"sgmf_flag"),"https://example.invalid/flag.png","cleanup preserves flag resource")
    local gone=token("加载后已移除","","uican2"); gone.tags.unit_nagaye_ashigaru=true; gone.UI.holdAssets=true
    setupUnit(gone,getUnitConfig(gone)); flush()
    local oldWrites=gone.UI.attributeCalls
    objects.uican2=nil; onObjectDestroy(gone)
    local replacement=token("复用 GUID 的新棋子","","uican2")
    replacement.tags.unit_nagaye_ashigaru=true
    unit_state.uican2={front_value=5,back_value=1,acted=false,manual_defeat_visible=false}
    setupUnit(replacement,getUnitConfig(replacement)); flush()
    gone.UI.holdAssets=false; gone.UI.loading=false; flush()
    eq(gone.UI.attributeCalls,oldWrites,"destroyed pending Canvas receives no stale callback writes")
    numberImage(replacement,"BACK","MORALE",1,"reused GUID retains replacement object state")
    eq(backGraphic(replacement,"action").url,UNIT_ACTION_IMAGES.back_unacted,"reused GUID action is not overwritten")
    local removed=token("载入期间移除标签","","uican3")
    removed.tags.unit_nagaye_ashigaru=true; removed.UI.holdAssets=true
    removed.UI.xmlTable={{tag="Text",attributes={id="foreign_loading"},value="保留载入中内容"}}
    removed.UI.assets={{name="foreign_loading_asset",url="https://example.invalid/loading-external.png"}}
    setupUnit(removed,getUnitConfig(removed)); flush()
    removed.tags.unit_nagaye_ashigaru=nil; clearUnitCounterVisuals(removed); flush()
    local pendingRemovalXML=removed.UI.xmlCalls
    clearUnitCounterVisuals(removed); flush()
    eq(removed.UI.xmlCalls,pendingRemovalXML,"pending removal never rewrites unready UI")
    removed.UI.holdAssets=false; removed.UI.loading=false; flush()
    eq(findNode(removed.UI.xmlTable,"sgub_root"),nil,"pending tag removal clears Canvas after resource loading")
    eq(findNode(removed.UI.xmlTable,"foreign_loading").value,"保留载入中内容","deferred cleanup preserves external XML")
    eq(objectAssetURL(removed,"foreign_loading_asset"),"https://example.invalid/loading-external.png","deferred cleanup preserves external resources")
    eq(objectAssetURL(removed,"sgub_digit_0"),nil,"deferred cleanup releases owned resources")
    local stalled=token("资源等待超时","","uican4")
    stalled.tags.unit_nagaye_ashigaru=true; stalled.UI.holdAssets=true
    local waiting=#conditions
    setupUnit(stalled,getUnitConfig(stalled)); flush()
    eq(#conditions,waiting+1,"one blocked Canvas has one bounded waiter")
    local timedOut=table.remove(conditions)
    assert(type(timedOut.failure)=="function","back UI waiter must provide timeout recovery")
    timedOut.failure()
    eq(findNode(stalled.UI.xmlTable,"sgub_root"),nil,"timeout does not create unresolved Canvas images")
    stalled.UI.holdAssets=false; stalled.UI.loading=false
    changeBackValue(stalled,"Red",true); flush()
    numberImage(stalled,"BACK","MORALE",4,"next click recovers after resource timeout using current state")
    eq(findNode(stalled.UI.xmlTable,"sgub_root").attributes.active,"true","recovered timeout reveals complete Canvas")
    for _,guid in ipairs({"uican1","uican2","uican3","uican4"}) do objects[guid]=nil; unit_state[guid]=nil end
end
local function runUnitPreloadChecks()
    local originalFront,originalBack,originalActions=UNIT_NUMBER_IMAGES,UNIT_NUMBER_BACK_IMAGES,UNIT_ACTION_IMAGES
    local originalRail,originalDefeat,originalGlobal=UNIT_BACK_RAIL_IMAGE_URL,UNIT_DEFEAT_IMAGE_URL,copy(Global.decals)
    UNIT_NUMBER_IMAGES,UNIT_NUMBER_BACK_IMAGES,UNIT_ACTION_IMAGES={},{},{}
    for digit=0,8 do
        UNIT_NUMBER_IMAGES[digit]="https://example.invalid/cache-front-"..digit..".png"
        UNIT_NUMBER_BACK_IMAGES[digit]="https://example.invalid/cache-back-"..digit..".png"
    end
    for _,key in ipairs({"front_unacted","front_acted","back_unacted","back_acted"}) do
        UNIT_ACTION_IMAGES[key]="https://example.invalid/"..key..".png"
    end
    UNIT_BACK_RAIL_IMAGE_URL="https://example.invalid/cache-rail.png"
    UNIT_DEFEAT_IMAGE_URL="https://example.invalid/cache-defeat.png"
    local foreign={name="user_world_decal",url="https://example.invalid/keep-world.png",position={8,0,2},rotation={0,0,0},scale={1,1,1}}
    local similar=copy(foreign); similar.name="SG_UNIT_CACHE_FRONT_0_EXTRA"
    Global.decals={foreign,similar}
    preloadUnitImages(true)
    local function cacheURLs()
        local urls,count={},0
        for _,decal in ipairs(Global.decals) do
            if decal.name~="user_world_decal" and decal.name~=similar.name then
                eq(urls[decal.url],nil,"preloader never duplicates a URL")
                urls[decal.url]=true; count=count+1
                eq(decal.position[2]<-100,true,"cache is outside battlefield")
                eq(decal.scale[1]<=.001 and decal.scale[2]<=.001,true,"cache has no counter-sized world artwork")
            end
        end
        eq(managedDecal(Global,foreign.name).url,foreign.url,"world user artwork preserved")
        eq(managedDecal(Global,similar.name).url,similar.url,"similar name is not script owned")
        return urls,count
    end
    local urls,count=cacheURLs()
    eq(count,24,"one bounded set preloads both digit palettes plus action and rail/defeat")
    for digit=0,8 do
        eq(urls[UNIT_NUMBER_IMAGES[digit]],true,"unused front digit stays held "..digit)
        eq(urls[UNIT_NUMBER_BACK_IMAGES[digit]],true,"unused rear digit stays held "..digit)
    end
    local writes,reads=Global.decalWrites,Global.decalReads
    for n=1,8 do preloadUnitImages(false) end
    eq(Global.decalWrites,writes,"unchanged configuration never rebuilds world cache")
    eq(Global.decalReads,reads,"unchanged configuration never rereads world decals")
    local unit=token("即时数字检查","","cache1"); unit.tags.unit_nagaye_ashigaru=true
    setupUnit(unit,getUnitConfig(unit))
    for expected=5,2,-1 do
        changeFrontValue(unit,"Red",true)
        numberImage(unit,"FRONT","MORALE",expected,"same callback commits the new digit without a timer")
    end
    eq(Global.decalWrites,writes,"changing morale does not rebuild preload set")
    eq(Global.decalReads,reads,"changing morale keeps existing texture references without world scans")
    preloadUnitImages(true)
    eq(Global.decalWrites,writes,"reload validation does not duplicate preload artwork")
    local oldURL=UNIT_NUMBER_IMAGES[0]
    local newURL="https://example.invalid/new-"..string.rep("x",4096)..".png"
    UNIT_NUMBER_IMAGES[0]=" \t"..newURL.." "
    preloadUnitImages(false)
    urls,count=cacheURLs()
    eq(count,24,"changing a configured URL keeps cache bounded")
    eq(urls[oldURL],nil,"old zero texture reference is removed")
    eq(urls[newURL],true,"long replacement URL is normalized safely")
    UNIT_NUMBER_IMAGES[1]=UNIT_NUMBER_IMAGES[2]
    preloadUnitImages(false); urls,count=cacheURLs()
    eq(count,23,"shared texture URLs are retained once")
    UNIT_NUMBER_BACK_IMAGES=nil
    preloadUnitImages(false); urls,count=cacheURLs()
    eq(count,14,"missing back table removes its nine cached assets")
    UNIT_NUMBER_IMAGES,UNIT_ACTION_IMAGES={},{}
    UNIT_BACK_RAIL_IMAGE_URL,UNIT_DEFEAT_IMAGE_URL="",""
    preloadUnitImages(false); urls,count=cacheURLs()
    eq(count,0,"cleared configuration removes all owned preload records")
    eq(#Global.decals,2,"clearing cache preserves only preexisting foreign artwork")
    UNIT_NUMBER_IMAGES,UNIT_NUMBER_BACK_IMAGES,UNIT_ACTION_IMAGES=originalFront,originalBack,originalActions
    UNIT_BACK_RAIL_IMAGE_URL,UNIT_DEFEAT_IMAGE_URL=originalRail,originalDefeat
    Global.decals=originalGlobal; preloadUnitImages(true)
    objects.cache1=nil; unit_state.cache1=nil; forgetUnitCounter("cache1")
end

local function runUnitMoraleBandChecks()
    local originalBands=UNIT_MORALE_BAND_IMAGES
    local config=UNIT_CONFIGS[1]
    local originalFrontMax,originalBackMax=config.max_front,config.max_back
    local amberURL="https://example.invalid/morale-band-amber.png"
    local redURL="https://example.invalid/morale-band-red.png"
    UNIT_MORALE_BAND_IMAGES={}
    preloadUnitImages(true)
    local baselineCache=#Global.decals
    UNIT_MORALE_BAND_IMAGES={amber=amberURL,red=redURL}
    preloadUnitImages(false)
    eq(#Global.decals,baselineCache+2,"morale bands add exactly two global preload references")
    local cacheURLs={}
    for _,decal in ipairs(Global.decals) do cacheURLs[decal.url]=true end
    eq(cacheURLs[amberURL],true,"amber band stays globally preloaded before first damage")
    eq(cacheURLs[redURL],true,"red band stays globally preloaded before first critical damage")

    local unit=token("士気損耗帯回帰","","band01")
    unit.tags.unit_nagaye_ashigaru=true; unit.tags.count_200=true
    local foreign={name="SG_UNIT_MORALE_BAND_FRONT_extra",url="https://example.invalid/foreign-band.png",position={0,0,0},rotation={0,0,0},scale={1,1,1}}
    unit.decals={copy(foreign)}
    unit.UI.xmlTable={{tag="Text",attributes={id="foreign_band_ui"},value="keep"}}
    unit.UI.assets={{name="foreign_band_asset",url="https://example.invalid/foreign-ui.png"}}
    config.max_front,config.max_back=6,5
    setupUnit(unit,getUnitConfig(unit)); flush()
    local function band(side,expected,message)
        if side=="FRONT" then
            local graphic,count=managedDecal(unit,"SG_UNIT_MORALE_BAND_FRONT")
            eq(count,expected and 1 or 0,message.." exact front band ownership")
            if expected then eq(graphic.url,UNIT_MORALE_BAND_IMAGES[expected],message.." front warning color") end
            return graphic
        end
        local node=findNode(unit.UI.xmlTable,"sgub_morale_band")
        assert(node,"rear morale band node exists even when inactive")
        eq(node.attributes.active,expected and "true" or "false",message.." rear warning visibility")
        if expected then
            eq(node.attributes.image,"sgub_band_"..expected,message.." rear warning uses preloaded sprite name")
            eq(objectAssetURL(unit,node.attributes.image),UNIT_MORALE_BAND_IMAGES[expected],message.." rear sprite name maps to configured image")
        end
        return node
    end
    band("FRONT",nil,"front full six")
    band("BACK",nil,"rear full five uses its own maximum")
    eq(findNode(unit.UI.xmlTable,"sgub_morale_band").attributes.image,"sgub_band_amber","full rear keeps a loaded sprite bound while hidden")
    eq(objectAssetURL(unit,"sgub_band_amber"),amberURL,"rear registry includes amber band")
    eq(objectAssetURL(unit,"sgub_band_red"),redURL,"rear registry includes red band")
    local ownedAssets=0
    for _,asset in ipairs(unit.UI.assets) do if asset.name:sub(1,5)=="sgub_" then ownedAssets=ownedAssets+1 end end
    eq(ownedAssets,14,"rear registry contains twelve original assets plus two bands")
    eq(#unit.buttons,6,"warning bands add no overlapping classic click area")
    local xmlWrites,assetWrites=unit.UI.xmlCalls,unit.UI.assetCalls
    local globalWrites=Global.decalWrites
    changeFrontValue(unit,"Red",true)
    local front=band("FRONT","amber","front six to five is shown in the same click")
    band("BACK",nil,"front damage leaves full rear unmarked")
    eq(managedDecal(unit,"SG_UNIT_NUM_FRONT_MORALE").url,UNIT_NUMBER_IMAGES[5],"front warning keeps original dark digit")
    local firstBandLog=#unit.UI.attributeLog
    changeBackValue(unit,"Blue",true)
    band("BACK","amber","rear five to four is shown in the same click")
    local bindingWrite,showWrite
    for n=firstBandLog+1,#unit.UI.attributeLog do
        local entry=unit.UI.attributeLog[n]
        if entry.id=="sgub_morale_band" then
            if entry.key=="image" then bindingWrite=n; eq(entry.value,"sgub_band_amber","first warning rebinds preloaded sprite without a URL request") end
            if entry.key=="active" and entry.value=="true" then showWrite=n end
        end
    end
    eq(bindingWrite~=nil and showWrite~=nil and bindingWrite<showWrite,true,"first rear warning binds texture before becoming visible")
    eq(findNode(unit.UI.xmlTable,"sgub_morale").attributes.image,UNIT_NUMBER_BACK_IMAGES[4],"rear warning keeps original ivory digit")
    local rear=backGraphic(unit,"morale_band")
    near(front.position[1],-(1100/1200-.5)*2,"front warning aligns with right-column numeral")
    near(rear.position[1],(1100/1200-.5)*2,"rear warning aligns with right-column numeral")
    near(front.position[3],(843/1200-.5)*2,"front warning occupies lower morale slot")
    near(rear.position[3],front.position[3],"rear warning uses same artwork coordinates")
    near(front.position[2],managedDecal(unit,"SG_UNIT_NUM_FRONT_MORALE").position[2],"front warning retains calibrated numeral plane")
    near(rear.position[2],-.1+.099,"rear warning shares user-confirmed minus .099 Canvas calibration")
    near(front.scale[1],144/1200*2,"front warning is 144 pixels wide")
    near(front.scale[2],24/1200*2,"front warning is 24 pixels high")
    near(rear.scale[1],front.scale[1],"both warning sides have matching width")
    near(rear.scale[2],front.scale[2],"both warning sides have matching height")
    eq(rear.root.children[#rear.root.children].attributes.id,"sgub_morale_band","warning is last child in existing ordered Canvas")
    eq(rear.node.attributes.raycastTarget,"false","rear warning cannot block morale clicks")

    changeBackValue(unit,"Blue",true)
    band("BACK","amber","odd maximum five remains amber at three")
    changeBackValue(unit,"Blue",true)
    band("BACK","red","odd maximum five becomes red at two")
    changeBackValue(unit,"Blue",false)
    band("BACK","amber","recovering two to three immediately clears red")
    changeBackValue(unit,"Blue",false); changeBackValue(unit,"Blue",false)
    band("BACK",nil,"recovering rear to five immediately removes warning")
    eq(findNode(unit.UI.xmlTable,"sgub_morale_band").attributes.image,"sgub_band_amber","recovery hides warning without clearing its texture")
    changeFrontValue(unit,"Red",true)
    band("FRONT","amber","even maximum six remains amber at four")
    changeFrontValue(unit,"Red",true)
    band("FRONT","red","even maximum six becomes red at exact half three")
    for n=1,3 do changeFrontValue(unit,"Red",false) end
    band("FRONT",nil,"recovering front to six immediately removes warning")
    eq(unit.UI.xmlCalls,xmlWrites,"all warning threshold changes reuse existing rear XML")
    eq(unit.UI.assetCalls,assetWrites,"all warning threshold changes reuse fixed texture registry")
    eq(Global.decalWrites,globalWrites,"damage and recovery never rebuild global preload set")
    local frontWrites,uiWrites=unit.decalWrites,unit.UI.attributeCalls
    updateDefeatText(unit); updateDefeatText(unit)
    eq(unit.decalWrites,frontWrites,"unchanged full-morale refresh does not rewrite decals")
    eq(unit.UI.attributeCalls,uiWrites,"unchanged full-morale refresh does not rewrite Canvas attributes")

    -- Maxima are read from the selected troop configuration, not hardcoded to six/five.
    config.max_front,config.max_back=8,7
    unit_state.band01.front_value=5; unit_state.band01.back_value=4
    updateDefeatText(unit)
    band("FRONT","amber","custom front eight is amber at five")
    band("BACK","amber","custom rear seven is amber at four")
    unit_state.band01.front_value=4; unit_state.band01.back_value=3
    updateDefeatText(unit)
    band("FRONT","red","custom front eight is red at four")
    band("BACK","red","custom rear seven is red at three")
    config.max_front,config.max_back=6,5
    unit_state.band01.front_value=0; unit_state.band01.back_value=2
    updateDefeatText(unit)
    band("FRONT",nil,"depleted first stage has no residual warning")
    band("BACK","red","positive rear still shows warning when old front is zero")
    unit_state.band01.front_value=4; unit_state.band01.back_value=0
    updateDefeatText(unit)
    band("FRONT",nil,"automatic defeat suppresses positive front warning")
    band("BACK",nil,"automatic defeat suppresses zero rear warning")
    unit_state.band01.front_value=3; unit_state.band01.back_value=2
    unit_state.band01.manual_defeat_visible=true
    updateDefeatText(unit)
    band("FRONT",nil,"manual defeat suppresses front warning")
    band("BACK",nil,"manual defeat suppresses rear warning")
    unit_state.band01.manual_defeat_visible=false
    updateDefeatText(unit)
    band("FRONT","red","clearing manual defeat restores front warning")
    band("BACK","red","clearing manual defeat restores rear warning")
    unit_state.band01.front_value=1; unit.is_face_down=false
    changeFrontValue(unit,"Red",true)
    eq(unit.is_face_down,true,"depleting first stage still flips troop")
    eq(unit_state.band01.back_value,5,"first-stage transition replenishes back to its own maximum")
    band("FRONT",nil,"transition removes exhausted front warning immediately")
    band("BACK",nil,"transition removes previous red rear warning immediately")
    tick()

    unit_state.band01.front_value=3; unit_state.band01.back_value=2
    updateDefeatText(unit)
    UNIT_MORALE_BAND_IMAGES.red=""
    updateDefeatText(unit); flush()
    band("FRONT",nil,"missing red URL removes stale front warning")
    band("BACK",nil,"missing red URL hides stale rear warning")
    numberImage(unit,"FRONT","MORALE",3,"missing warning never hides normal front numeral")
    numberImage(unit,"BACK","MORALE",2,"missing warning never hides normal rear numeral")
    eq(unit_state.band01.front_value,3,"missing warning does not mutate front gameplay")
    eq(unit_state.band01.back_value,2,"missing warning does not mutate rear gameplay")
    UNIT_MORALE_BAND_IMAGES=nil
    updateDefeatText(unit); flush()
    band("FRONT",nil,"missing entire optional table safely disables front warning")
    band("BACK",nil,"missing entire optional table safely disables rear warning")
    UNIT_MORALE_BAND_IMAGES={amber=amberURL,red=redURL}
    updateDefeatText(unit); flush()
    band("FRONT","red","restored warning configuration redraws front")
    band("BACK","red","restored warning configuration redraws rear")

    local pending=token("損耗帯待機中更新","","band02")
    pending.tags.unit_nagaye_ashigaru=true; pending.UI.holdAssets=true
    setupUnit(pending,getUnitConfig(pending)); flush()
    eq(findNode(pending.UI.xmlTable,"sgub_morale_band"),nil,"XML waits for explicit resource registration to finish")
    eq(objectAssetURL(pending,"sgub_band_amber"),amberURL,"explicit registration reaches asset API before XML")
    unit_state.band02.back_value=4; updateDefeatText(pending)
    unit_state.band02.back_value=2; updateDefeatText(pending)
    eq(findNode(pending.UI.xmlTable,"sgub_root"),nil,"pending resources do not create unresolved Image nodes")
    pending.UI.holdAssets=false; pending.UI.loading=false; flush()
    eq(findNode(pending.UI.xmlTable,"sgub_morale_band").attributes.image,"sgub_band_red","load completion binds newest warning using preloaded red sprite")
    eq(objectAssetURL(pending,"sgub_band_red"),redURL,"completed preload contains exact red warning URL")
    eq(findNode(pending.UI.xmlTable,"sgub_morale_band").attributes.active,"true","load completion reveals newest warning")
    eq(findNode(pending.UI.xmlTable,"sgub_morale").attributes.image,UNIT_NUMBER_BACK_IMAGES[2],"loaded warning matches latest displayed morale")

    unit.tags.unit_nagaye_ashigaru=nil
    clearUnitCounterVisuals(unit); flush()
    eq(select(2,managedDecal(unit,"SG_UNIT_MORALE_BAND_FRONT")),0,"removing troop tag clears front warning")
    eq(findNode(unit.UI.xmlTable,"sgub_root"),nil,"removing troop tag clears rear warning Canvas")
    eq(objectAssetURL(unit,"sgub_band_amber"),nil,"removing troop tag releases amber rear asset")
    eq(objectAssetURL(unit,"sgub_band_red"),nil,"removing troop tag releases red rear asset")
    eq(managedDecal(unit,foreign.name).url,foreign.url,"cleanup preserves similarly named foreign decal")
    eq(findNode(unit.UI.xmlTable,"foreign_band_ui").value,"keep","cleanup preserves unrelated XML")
    eq(objectAssetURL(unit,"foreign_band_asset"),"https://example.invalid/foreign-ui.png","cleanup preserves unrelated resource")
    eq(unit_state.band01.front_value,3,"warning cleanup retains front morale")
    eq(unit_state.band01.back_value,2,"warning cleanup retains rear morale")
    for _,guid in ipairs({"band01","band02"}) do
        forgetUnitCounter(guid); objects[guid]=nil; unit_state[guid]=nil
    end
    UNIT_MORALE_BAND_IMAGES=originalBands
    config.max_front,config.max_back=originalFrontMax,originalBackMax
    preloadUnitImages(true)
    eq(#Global.decals,baselineCache,"disabling optional warnings removes their two preload references")
end

local function runUnitMoraleQuickChecks()
    local label="士気快捷調整"
    eq(type(hotkeys[label]),"table","onLoad registers the morale modifier hotkey")
    eq(hotkeys[label].triggerOnKeyUp,true,"morale modifier requests release events")
    local unit=token("士気快捷操作検証","","quick1")
    local other=token("騎馬快捷操作検証","","quick2")
    unit.tags.unit_nagaye_ashigaru=true
    other.tags.unit_kiba_samurai=true
    setupUnit(unit,getUnitConfig(unit)); setupUnit(other,getUnitConfig(other)); flush()
    local function key(color,isKeyUp,hovered)
        hotkeys[label].callback(color,hovered,{x=0,y=0,z=0},isKeyUp)
    end
    local function values(object,front,back,manual,acted)
        local state=unit_state[object.guid]
        state.front_value,state.back_value=front,back
        state.manual_defeat_visible,state.acted=manual==true,acted==true
        updateDefeatText(object); flush()
    end
    values(unit,4,3,false,true); values(other,2,2,false,false)
    key("Red",false,other)
    eq(unit_state.quick1.front_value,4,"pressing modifier alone never edits a troop")
    eq(unit_state.quick2.front_value,2,"hovered troop is not an implicit shortcut target")
    changeFrontValue(unit,"Blue",false)
    eq(unit_state.quick1.front_value,5,"another player's normal click remains plus one")
    changeFrontValue(unit,"Red",false)
    eq(unit_state.quick1.front_value,6,"held modifier plus left click fills current front")
    eq(unit_state.quick1.back_value,3,"front fill preserves a nonzero rear reserve")
    eq(unit_state.quick1.acted,true,"front fill preserves acted flag")
    eq(unit.is_face_down,false,"front fill preserves face")
    eq(unit_state.quick2.front_value,2,"shortcut targets the clicked troop rather than hovered troop")
    numberImage(unit,"FRONT","MORALE",6,"quick front fill immediately updates numeral")
    key("Red",true,nil)
    eq(unit_state.quick1.front_value,6,"releasing modifier never edits morale")
    changeFrontValue(unit,"Red",true)
    eq(unit_state.quick1.front_value,5,"keyup restores ordinary right-click minus one")

    key("Blue",false,nil)
    other.is_face_down=true
    changeBackValue(other,"Blue",false)
    eq(unit_state.quick2.back_value,7,"rear quick fill uses mounted troop's seven-point maximum")
    eq(unit_state.quick2.front_value,2,"rear fill preserves nonzero front reserve")
    eq(other.is_face_down,true,"rear fill keeps current physical face")
    eq(unit_state.quick2.acted,false,"rear fill preserves unacted flag")
    numberImage(other,"BACK","MORALE",7,"quick rear fill immediately updates numeral")
    key("Blue",true,unit)
    changeBackValue(other,"Blue",true)
    eq(unit_state.quick2.back_value,6,"releasing with a different hover target restores normal damage")
    key("Blue",false,nil)
    changeFrontValue(other,"Blue",false)
    eq(unit_state.quick2.front_value,8,"front quick fill uses mounted troop's eight-point maximum")
    eq(unit_state.quick2.back_value,6,"front quick fill leaves damaged positive rear reserve unchanged")
    eq(other.is_face_down,true,"shortcut callback never flips on refill")
    key("Blue",true,nil)

    key("Red",false,nil)
    changeFrontValue(unit,"Red",true)
    eq(unit_state.quick1.front_value,0,"held modifier plus right click exhausts first stage")
    eq(unit_state.quick1.back_value,5,"quick first-stage exhaustion starts full second stage")
    eq(unit.is_face_down,true,"quick first-stage exhaustion flips troop")
    eq(unit.flipCalls,1,"quick first-stage exhaustion flips exactly once")
    eq(unit_state.quick1.acted,true,"quick first-stage exhaustion preserves action flag")
    for n=1,3 do
        changeFrontValue(unit,"Red",true)
        changeBackValue(unit,"Red",true)
        changeBackValue(unit,"Blue",true)
    end
    changeFrontValue(unit,"Red",false); changeBackValue(unit,"Red",false)
    eq(unit_state.quick1.front_value,0,"flip lock rejects modified refill and repeated front damage")
    eq(unit_state.quick1.back_value,5,"flip lock rejects normal and modified rear damage")
    eq(unit.flipCalls,1,"cross-face click burst cannot flip twice")
    tick()
    changeFrontValue(unit,"Red",true)
    eq(unit_state.quick1.back_value,5,"repeating exhausted-front shortcut after lock cannot refill or flip")
    eq(unit.flipCalls,1,"exhausted-front shortcut remains idempotent after lock")
    changeBackValue(unit,"Red",true)
    eq(unit_state.quick1.back_value,0,"rear quick exhaustion reaches zero in one click")
    eq(unit.buttons[3].label,"敗走","rear quick exhaustion shows rear rout")
    eq(unit.buttons[4].label,"敗走","rear quick exhaustion shows front rout")
    eq(unit.is_face_down,true,"rear exhaustion does not flip troop")
    eq(unit_state.quick1.acted,true,"rear exhaustion preserves action flag")
    changeBackValue(unit,"Red",true)
    eq(unit.flipCalls,1,"repeated rear exhaustion never flips")
    unit_state.quick1.manual_defeat_visible=true
    changeBackValue(unit,"Red",false)
    eq(unit_state.quick1.back_value,5,"one quick refill rallies a routed rear to full morale")
    eq(unit_state.quick1.front_value,0,"rear rally leaves exhausted first stage exhausted")
    eq(unit_state.quick1.manual_defeat_visible,false,"quick rally removes manual defeat flag")
    eq(unit.buttons[3].label,"","quick rally removes rear defeat graphic immediately")
    eq(unit.buttons[4].label,"","quick rally removes front defeat graphic immediately")
    eq(unit.is_face_down,true,"quick rally remains on rear face")
    eq(unit_state.quick1.acted,true,"quick rally retains acted flag")
    numberImage(unit,"BACK","MORALE",5,"quick rally refreshes rear image synchronously")
    unit_state.quick1.manual_defeat_visible=true; updateDefeatText(unit)
    changeBackValue(unit,"Red",false)
    eq(unit_state.quick1.manual_defeat_visible,false,"full rear still clears manual defeat when numerical value is unchanged")
    eq(unit.buttons[3].label,"","unchanged-value rear rally still redraws defeat state")

    unit.is_face_down=false
    values(unit,6,0,true,true)
    changeFrontValue(unit,"Red",false)
    eq(unit_state.quick1.front_value,6,"manually front-facing routed troop keeps front maximum")
    eq(unit_state.quick1.back_value,5,"front rally also restores an exhausted rear reserve to clear automatic rout")
    eq(unit_state.quick1.manual_defeat_visible,false,"front rally clears manual defeat at existing front maximum")
    eq(unit.buttons[4].label,"","front rally fully clears defeat even when rear had been zero")
    eq(unit.is_face_down,false,"front rally after manual flip preserves current face")
    eq(unit.flipCalls,1,"rally never calls flip")
    eq(unit_state.quick1.acted,true,"front rally after manual flip preserves action flag")
    values(unit,3,2,true,false)
    changeFrontValue(unit,"Red",false)
    eq(unit_state.quick1.front_value,6,"front rally restores partial current stage")
    eq(unit_state.quick1.back_value,2,"front rally does not heal a positive rear reserve")
    eq(unit_state.quick1.manual_defeat_visible,false,"partial front rally clears manual rout")
    eq(unit_state.quick1.acted,false,"front rally retains unacted flag")
    key("Red",true,nil)

    -- A color callback only supplies the new color, so stale modifier state must
    -- not survive under any old color or be inherited by a later occupant.
    values(unit,3,3,false,true)
    key("Red",false,nil); key("Blue",false,nil)
    onPlayerChangeColor("Grey")
    changeFrontValue(unit,"Red",false); changeBackValue(unit,"Blue",false)
    eq(unit_state.quick1.front_value,4,"any color change clears stale old-color modifier")
    eq(unit_state.quick1.back_value,4,"color change also clears other held modifier entries safely")
    values(unit,3,3,false,true)
    key("Red",false,nil); key("Blue",false,nil)
    onPlayerDisconnect({color="Grey"})
    changeFrontValue(unit,"Red",false); changeBackValue(unit,"Blue",false)
    eq(unit_state.quick1.front_value,4,"disconnect clears stale modifier for later players")
    eq(unit_state.quick1.back_value,4,"disconnect clears all in-flight modifier states")

    values(unit,3,3,false,true)
    key("Red",false,nil); key("Blue",false,nil)
    local registrationsBefore=#hotkeyRegistrations
    local saved=onSave()
    onLoad(saved); flush(); tick()
    eq(#hotkeyRegistrations,registrationsBefore+1,"reload registers exactly one named morale shortcut")
    eq(hotkeyRegistrations[#hotkeyRegistrations].label,label,"reload keeps stable Game Keys binding name")
    eq(hotkeys[label].triggerOnKeyUp,true,"reload retains key-release delivery")
    changeFrontValue(unit,"Red",false); changeBackValue(unit,"Blue",false)
    eq(unit_state.quick1.front_value,4,"saved held modifier is not restored for front click")
    eq(unit_state.quick1.back_value,4,"saved held modifier is not restored for rear click")
    eq(unit_state.quick1.acted,true,"shortcut reload retains saved action flag")
    eq(#unit.buttons,6,"shortcut feature adds no crowded morale buttons")
    eq(#other.buttons,6,"shortcut feature keeps existing button count on other unit types")
    eq(#unit.contextMenu,0,"shortcut feature does not restore removed context menus")
    key("Red",false,nil); changeFrontValue(unit,"Red",false); key("Red",true,nil)
    eq(unit_state.quick1.front_value,6,"rebound shortcut works after reload")
    for _,guid in ipairs({"quick1","quick2"}) do
        forgetUnitCounter(guid); objects[guid]=nil; unit_state[guid]=nil
    end
end

-- Optional shared status markers: image availability gates visible, clickable UI.
local function runUnitStatusChecks()
    local originalImages=UNIT_STATUS_IMAGES
    UNIT_STATUS_IMAGES={}
    local callbacks={engaged="toggleUnitEngaged",out_of_command="toggleUnitOutOfCommand"}
    local function statusButtons(obj,kind,back)
        local found={}
        for _,button in ipairs(obj.buttons) do
            if button.click_function==callbacks[kind] and
                (back==nil or ((button.rotation or {})[3]==180)==back) then
                found[#found+1]=button
            end
        end
        return found
    end
    local function statusNode(obj,side,kind)
        return obj.UI and findNode(obj.UI.xmlTable,"sgub_status_"..side.."_"..kind)
    end
    local function checkMarker(obj,kind,enabled,message)
        for _,side in ipairs({"front","back"}) do
            local node=statusNode(obj,side,kind)
            assert(node,"Missing status Image "..side.." "..kind)
            eq(node.tag,"Image",message.." "..side.." image node")
            eq(node.attributes.active,"true",message.." "..side.." remains visible")
            eq(node.attributes.image,"sgub_status_image_"..kind,message.." "..side.." preloaded sprite binding")
            eq(node.attributes.color,enabled and "#FFFFFFFF" or "#FFFFFF20",message.." "..side.." visual state")
            eq(node.attributes.raycastTarget,"false",message.." "..side.." image does not intercept clicks")
            eq(#statusButtons(obj,kind,side=="back"),1,message.." "..side.." one click target")
        end
    end
    local unit=token("交戦指揮外試験","","status1")
    unit.tags.unit_nagaye_ashigaru=true
    setupUnit(unit,getUnitConfig(unit)); flush()
    eq(unit_state.status1.engaged,false,"new unit starts disengaged")
    eq(unit_state.status1.out_of_command,false,"new unit starts without manual OOC marker")
    eq(#unit.buttons,6,"absent status URLs leave original six buttons")
    for kind in pairs(callbacks) do
        eq(#statusButtons(unit,kind),0,"missing URL adds no invisible status hit area: "..kind)
        for _,side in ipairs({"front","back"}) do
            local node=statusNode(unit,side,kind)
            eq(node==nil or node.attributes.active=="false",true,"missing URL shows no status placeholder: "..side.." "..kind)
        end
    end
    UNIT_STATUS_IMAGES={engaged="https://example.invalid/engaged.png",out_of_command="https://example.invalid/out-of-command.png"}
    updateDefeatText(unit); flush()
    eq(#unit.buttons,10,"two shared statuses add one hit area per face")
    for kind,url in pairs(UNIT_STATUS_IMAGES) do
        eq(objectAssetURL(unit,"sgub_status_image_"..kind),url,"status image explicitly registered: "..kind)
        checkMarker(unit,kind,false,"initial inactive "..kind)
    end
    local unchangedMorale=unit_state.status1.front_value
    local other=token("別隊","","status2"); other.tags.unit_nagaye_ashigaru=true
    setupUnit(other,getUnitConfig(other)); flush()
    local button=statusButtons(unit,"engaged",false)[1]
    _G[button.click_function](unit,"Red",false)
    eq(unit_state.status1.engaged,true,"nonhost front left click enables shared engaged")
    checkMarker(unit,"engaged",true,"engaged immediate refresh")
    checkMarker(unit,"out_of_command",false,"engaged leaves OOC unchanged")
    eq(unit_state.status1.front_value,unchangedMorale,"status click preserves morale")
    eq(unit_state.status1.acted,false,"status click preserves action")
    eq(unit.is_face_down,false,"status click does not flip unit")
    eq(unit_state.status2.engaged,false,"status belongs only to clicked GUID")
    toggleUnitEngaged(unit,"Red",true)
    eq(unit_state.status1.engaged,true,"right click does not toggle engaged")
    _G[statusButtons(unit,"out_of_command",true)[1].click_function](unit,"Blue",false)
    eq(unit_state.status1.out_of_command,true,"nonhost back click enables shared OOC")
    checkMarker(unit,"out_of_command",true,"OOC immediate refresh on both faces")
    toggleUnitOutOfCommand(unit,"Blue",true)
    eq(unit_state.status1.out_of_command,true,"right click does not toggle OOC")
    _G[statusButtons(unit,"engaged",true)[1].click_function](unit,"Grey",false)
    eq(unit_state.status1.engaged,false,"back callback changes same engaged record")
    toggleUnitEngaged(unit,"Black",false)
    local assetWrites,xmlWrites=unit.UI.assetCalls,unit.UI.xmlCalls
    for n=1,6 do
        toggleUnitEngaged(unit,"Red",false)
        toggleUnitOutOfCommand(unit,"Blue",false)
    end
    eq(unit.UI.assetCalls,assetWrites,"status toggles reuse loaded images")
    eq(unit.UI.xmlCalls,xmlWrites,"status toggles do not rebuild Canvas")
    local attrs,decals=unit.UI.attributeCalls,unit.decalWrites
    for n=1,4 do updateDefeatText(unit) end
    eq(unit.UI.attributeCalls,attrs,"identical status refresh writes no attributes")
    eq(unit.decalWrites,decals,"status refresh leaves existing decals stable")
    eq(#unit.buttons,10,"repeated refresh never accumulates status buttons")

    local function geometryCheck(obj,message)
        local width=obj.bounds.size.x/obj.scale.x
        local depth=obj.bounds.size.z/obj.scale.z
        local cx=obj.bounds.offset.x/obj.scale.x
        local cz=obj.bounds.offset.z/obj.scale.z
        for _,back in ipairs({false,true}) do
            local side=back and "back" or "front"
            local root=findNode(obj.UI.xmlTable,"sgub_status_"..side)
            assert(root,"Missing status header "..side)
            eq(root.attributes.rotation,back and "180 0 0" or "0 0 180",message.." "..side.." faces outward")
            local rp,rs=vector(root.attributes.position),vector(root.attributes.scale)
            local expected={
                engaged={x=77,y=120,width=100,height=100,hit_width=200,hit_height=200},
                out_of_command={x=935,y=110,width=125,height=200,hit_width=208,hit_height=333}
            }
            for kind,layout in pairs(expected) do
                local node=statusNode(obj,side,kind)
                local child=vector(node.attributes.position)
                local localX=rp[1]/100+(back and 1 or -1)*child[1]*rs[1]/100
                local localY=-rp[3]/100
                local localZ=rp[2]/100-child[2]*rs[2]/100
                near(localX,cx+(back and 1 or -1)*(layout.x/1200-.5)*width,message.." "..side.." "..kind.." screen X")
                near(localZ,cz+(layout.y/1200-.5)*depth,message.." "..side.." "..kind.." top row")
                near(child[3],0,message.." "..side.." "..kind.." shares header plane")
                near(tonumber(node.attributes.width)*rs[1]/100,layout.width/1200*width,message.." "..side.." "..kind.." rendered width")
                near(tonumber(node.attributes.height)*rs[2]/100,layout.height/1200*depth,message.." "..side.." "..kind.." rendered height")
                eq(node.attributes.preserveAspect,"true",message.." "..side.." "..kind.." preserves source aspect")
                local hit=statusButtons(obj,kind,back)[1]
                local hp=classicButtonObjectPosition(hit)
                near(hp[1],localX,message.." "..side.." "..kind.." hit X")
                near(hp[3],localZ,message.." "..side.." "..kind.." hit Z")
                near(hp[2],localY+(back and -.004 or .004),message.." "..side.." "..kind.." hit above image")
                eq(hit.width,layout.hit_width,message.." "..side.." "..kind.." hit width")
                eq(hit.height,layout.hit_height,message.." "..side.." "..kind.." hit height")
                classicButtonOrientation(hit,back,message.." "..side.." "..kind)
            end
        end
    end
    geometryCheck(unit,"default geometry")
    unit.scale={x=2,y=3,z=.5}; unit.bounds={size={x=4,y=.6,z=1},offset={x=.4,y=.3,z=-.2}}
    updateDefeatText(unit); flush()
    geometryCheck(unit,"nonzero center and scaled geometry")
    unit.scale={x=1,y=1,z=1}; unit.bounds={size={x=2,y=.2,z=2},offset={x=0,y=0,z=0}}
    updateDefeatText(unit); flush()
    unit.flip(); onObjectDrop("Red",unit); onObjectRotate(unit,nil,true,"Blue"); flush(); tick()
    eq(unit_state.status1.engaged,true,"flip/drop keeps manual engaged marker")
    eq(unit_state.status1.out_of_command,true,"flip/drop keeps manual OOC marker")
    changeBackValue(unit,"Red",true)
    toggleUnitActed(unit,"Blue",false)
    toggleDefeatText(unit)
    eq(unit_state.status1.engaged,true,"morale/action/rout preserves engaged")
    eq(unit_state.status1.out_of_command,true,"morale/action/rout preserves OOC")
    local shortcut=hotkeys["士気快捷調整"]
    shortcut.callback("Red",unit,nil,false); changeBackValue(unit,"Red",false); shortcut.callback("Red",unit,nil,true)
    eq(unit_state.status1.engaged,true,"quick refill preserves engaged")
    eq(unit_state.status1.out_of_command,true,"quick refill preserves OOC")
    local saved=onSave(); onLoad(saved); flush(); tick()
    eq(unit_state.status1.engaged,true,"engaged survives save/load")
    eq(unit_state.status1.out_of_command,true,"OOC survives save/load")
    checkMarker(unit,"engaged",true,"restored engaged image")
    checkMarker(unit,"out_of_command",true,"restored OOC image")
    for _,fixture in ipairs({{},{engaged="true",out_of_command=1},{engaged={},out_of_command=false}}) do
        unit_state.status1={front_value=4,back_value=3,engaged=fixture.engaged,out_of_command=fixture.out_of_command,acted=true}
        local state=getStateAndConfig(unit)
        eq(state.engaged,false,"old or invalid engaged value defaults false")
        eq(state.out_of_command,false,"old or invalid OOC value defaults false")
        eq(state.front_value,4,"status normalization preserves old morale")
        eq(state.acted,true,"status normalization preserves old action flag")
    end
    toggleUnitEngaged(unit,"Red",false); toggleUnitOutOfCommand(unit,"Blue",false)
    resetUnit(unit)
    eq(unit_state.status1.engaged,false,"explicit full reset clears engaged")
    eq(unit_state.status1.out_of_command,false,"explicit full reset clears OOC")

    -- Register both sprites before revealing any header or click targets.
    local pending=token("状态图片下载中","","status3"); pending.tags.unit_nagaye_ashigaru=true
    pending.UI.holdAssets=true
    setupUnit(pending,getUnitConfig(pending)); flush()
    eq(#statusButtons(pending,"engaged"),0,"initial pending status has no clickable empty area")
    eq(#statusButtons(pending,"out_of_command"),0,"initial pending OOC has no clickable empty area")
    toggleUnitEngaged(pending,"Red",false); toggleUnitEngaged(pending,"Blue",false)
    toggleUnitOutOfCommand(pending,"Blue",false)
    pending.UI.holdAssets=false; pending.UI.loading=false; flush()
    checkMarker(pending,"engaged",false,"load completion uses latest engaged")
    checkMarker(pending,"out_of_command",true,"load completion uses latest OOC")
    pending.UI.holdAssets=true
    UNIT_STATUS_IMAGES.engaged="https://example.invalid/engaged-v2.png"
    updateDefeatText(pending); flush()
    eq(#statusButtons(pending,"engaged"),0,"replacement loading removes active hit targets")
    toggleUnitEngaged(pending,"Red",false)
    pending.UI.holdAssets=false; pending.UI.loading=false; flush()
    checkMarker(pending,"engaged",true,"replacement completion uses newest shared state")
    eq(objectAssetURL(pending,"sgub_status_image_engaged"),UNIT_STATUS_IMAGES.engaged,"replacement sprite URL registered")

    -- Clearing one optional URL hides only that status and retains its state.
    UNIT_STATUS_IMAGES.engaged=""
    updateDefeatText(pending); flush()
    eq(#statusButtons(pending,"engaged"),0,"cleared image removes engaged hit areas")
    eq(#statusButtons(pending,"out_of_command"),2,"other status remains clickable")
    eq(unit_state.status3.engaged,true,"missing image never deletes stored status")
    for _,side in ipairs({"front","back"}) do
        local node=statusNode(pending,side,"engaged")
        eq(node==nil or node.attributes.active=="false",true,"cleared image has no visible substitute: "..side)
    end
    UNIT_STATUS_IMAGES={engaged="[https://example.invalid/e.png](https://example.invalid/e.png)",out_of_command="C:/private/status.png"}
    updateDefeatText(pending); flush()
    eq(#pending.buttons,6,"invalid or local status URLs leave no invisible hit areas")
    eq(findNode(pending.UI.xmlTable,"sgub_status_front"),nil,"removing all usable images removes front header")
    eq(findNode(pending.UI.xmlTable,"sgub_status_back"),nil,"removing all usable images removes back header")
    eq(objectAssetURL(pending,"sgub_status_image_engaged"),nil,"cleared status asset is removed from registry")
    eq(unit_state.status3.out_of_command,true,"removing both images preserves manual state")
    UNIT_STATUS_IMAGES={out_of_command="https://example.invalid/out-of-command.png"}
    updateDefeatText(pending); flush()
    checkMarker(pending,"out_of_command",true,"restored image recovers saved state")
    local noUI=token("无物件UI","","status4"); noUI.tags.unit_nagaye_ashigaru=true; noUI.UI=nil
    setupUnit(noUI,getUnitConfig(noUI)); flush()
    eq(#statusButtons(noUI,"out_of_command"),0,"missing Object.UI never creates invisible status targets")

    pending.UI.xmlTable[#pending.UI.xmlTable+1]={tag="Text",attributes={id="foreign_status_text"},value="保留"}
    pending.UI.assets[#pending.UI.assets+1]={name="foreign_status_asset",url="https://example.invalid/foreign-status.png"}
    pending.decals[#pending.decals+1]={name="foreign_status_decal",url="https://example.invalid/foreign-decal.png"}
    pending.createButton({click_function="foreignStatusButton",label="外部",rotation={0,0,0}})
    pending.tags.unit_nagaye_ashigaru=nil
    clearUnitCounterVisuals(pending); flush()
    eq(#pending.buttons,1,"tag cleanup removes status and counter buttons only")
    eq(pending.buttons[1].label,"外部","tag cleanup preserves foreign button")
    eq(findNode(pending.UI.xmlTable,"sgub_status_front"),nil,"tag cleanup removes front status root")
    eq(findNode(pending.UI.xmlTable,"sgub_status_back"),nil,"tag cleanup removes back status root")
    eq(findNode(pending.UI.xmlTable,"foreign_status_text").value,"保留","tag cleanup preserves foreign XML")
    eq(objectAssetURL(pending,"foreign_status_asset"),"https://example.invalid/foreign-status.png","tag cleanup preserves foreign assets")
    eq(select(2,managedDecal(pending,"foreign_status_decal")),1,"tag cleanup preserves foreign decals")
    for _,guid in ipairs({"status1","status2","status3","status4"}) do
        local obj=objects[guid]
        objects[guid]=nil; onObjectDestroy(obj)
        eq(unit_state[guid],nil,"destroyed status unit releases persistent record: "..guid)
    end
    UNIT_STATUS_IMAGES=originalImages
    preloadUnitImages(true)
end

-- Bottom two-image controls: near-combat formation and ranged fire readiness.
local function runUnitModeChecks()
    local originalImages,originalStatus=UNIT_MODE_IMAGES,UNIT_STATUS_IMAGES
    UNIT_STATUS_IMAGES={}
    UNIT_MODE_IMAGES={}
    local created={}
    local function make(guid,tag)
        local obj=token("下部切換試験","",guid)
        obj.tags[tag]=true; created[#created+1]=obj
        setupUnit(obj,getUnitConfig(obj)); flush()
        return obj
    end
    local function buttons(obj,back)
        local found={}
        for _,button in ipairs(obj.buttons) do
            if button.click_function=="toggleUnitMode" and
                (back==nil or ((button.rotation or {})[3]==180)==back) then found[#found+1]=button end
        end
        return found
    end
    local function hidden(obj,message)
        eq(#buttons(obj),0,message.." no invisible mode click areas")
        for _,side in ipairs({"front","back"}) do
            local root=findNode(obj.UI.xmlTable,"sgub_mode_"..side)
            eq(root==nil or root.attributes.active=="false",true,message.." no mode placeholder: "..side)
        end
    end
    local function imageIs(obj,key,message)
        for _,side in ipairs({"front","back"}) do
            local root=findNode(obj.UI.xmlTable,"sgub_mode_"..side)
            local node=findNode(obj.UI.xmlTable,"sgub_mode_"..side.."_image")
            assert(root and node,message.." missing mode XML: "..side)
            eq(root.attributes.active,"true",message.." visible root: "..side)
            eq(node.tag,"Image",message.." uses Image: "..side)
            eq(node.attributes.active,"true",message.." visible image: "..side)
            eq(objectAssetURL(obj,node.attributes.image) or node.attributes.image,UNIT_MODE_IMAGES[key],message.." correct image: "..side)
            eq(node.attributes.raycastTarget,"false",message.." image passes mouse through: "..side)
            eq(node.attributes.color=="#FFFFFF" or node.attributes.color=="#FFFFFFFF",true,message.." both states fully opaque: "..side)
            eq(#buttons(obj,side=="back"),1,message.." one click area: "..side)
        end
    end
    local unit=make("mode01","unit_nagaye_ashigaru")
    hidden(unit,"empty image configuration")
    eq(unit_state.mode01.open_order,false,"old/new record defaults to closed formation")
    eq(unit_state.mode01.reloading,false,"old/new record defaults to fire ready")
    UNIT_MODE_IMAGES={closed="https://example.invalid/mode-closed.png",open="https://example.invalid/mode-open.png",
        ready="https://example.invalid/mode-ready.png",reloading="https://example.invalid/mode-reloading.png"}
    updateDefeatText(unit); flush()
    imageIs(unit,"closed","configured near-combat default")
    local expected={unit_nagaye_ashigaru="formation",unit_kiba_samurai="formation",unit_kachi_samurai="formation",
        unit_yari_ashigaru="formation",unit_akazonae_kiba="formation",unit_yumi_ashigaru="fire",unit_yumi_sohei="fire",
        unit_teppo_ashigaru="fire",unit_teppo_sohei="fire",unit_nanban_ozutsu="fire"}
    for index,config in ipairs(UNIT_CONFIGS) do
        eq(config.marker_mode,expected[config.tag],"explicit troop mode: "..config.tag)
        local troop=make("mode_type"..index,config.tag)
        local key=expected[config.tag]=="formation" and "closed" or "ready"
        imageIs(troop,key,"default mode for "..config.tag)
        local count=0
        for _,asset in ipairs(troop.UI.assets) do
            if asset.name:sub(1,16)=="sgub_mode_image_" then count=count+1 end
        end
        eq(count,2,"only applicable image pair loaded: "..config.tag)
        eq(objectAssetURL(troop,"sgub_mode_image_"..(key=="closed" and "ready" or "closed")),nil,
            "opposite troop class images not loaded: "..config.tag)
        eq(#troop.buttons,8,"each class adds exactly two face buttons: "..config.tag)
    end
    local function moraleTooltip(obj,back,printed,effective,open,message)
        eq(obj.buttons[back and 2 or 1].tooltip,
            "基礎士氣上限："..printed.."\n實際士氣上限："..effective..(open and "（散開 −1）" or ""),message)
    end
    unit_state.mode01.front_value=4 -- Six printed TQ, two accumulated hits.
    unit_state.mode01.back_value=3 -- Store the inactive face's two hits as well.
    updateDefeatText(unit)
    moraleTooltip(unit,false,6,6,false,"closed front tooltip uses printed limit, not remaining morale")
    moraleTooltip(unit,true,5,5,false,"closed rear tooltip uses its own printed limit")
    local unchanged=copy(unit_state.mode01)
    _G[buttons(unit,false)[1].click_function](unit,"Red",false)
    eq(unit_state.mode01.open_order,true,"nonhost front click opens formation")
    eq(unit_state.mode01.reloading,false,"formation click leaves fire state untouched")
    imageIs(unit,"open","formation click updates both faces immediately")
    eq(unit_state.mode01.front_value,3,"open formation preserves two accumulated front hits: six minus two becomes five minus two")
    eq(unit_state.mode01.back_value,2,"open formation preserves accumulated inactive rear hits")
    eq(unit_state.mode01.acted,true,"successful formation change consumes the action")
    moraleTooltip(unit,false,6,5,true,"open front tooltip distinguishes effective limit")
    moraleTooltip(unit,true,5,4,true,"open rear tooltip distinguishes effective limit")
    for _,key in ipairs({"manual_defeat_visible","engaged","out_of_command"}) do
        eq(unit_state.mode01[key],unchanged[key],"mode click preserves existing state: "..key)
    end
    eq(unit.is_face_down,false,"mode click does not turn unit over")
    toggleUnitMode(unit,"Blue",true)
    eq(unit_state.mode01.open_order,true,"right click ignores formation")
    toggleUnitMode(unit,"Grey",false)
    eq(unit_state.mode01.open_order,true,"acted troop cannot change formation again")
    eq(unit_state.mode01.front_value,3,"declined acted change preserves accumulated damage")
    toggleUnitActed(unit,"Grey",false)
    _G[buttons(unit,true)[1].click_function](unit,"Grey",false)
    imageIs(unit,"closed","either face callback uses actual front-facing troop state")
    eq(unit_state.mode01.front_value,4,"returning closed restores limit while retaining exactly two hits")
    eq(unit_state.mode01.back_value,3,"returning closed preserves inactive rear damage")
    eq(unit_state.mode01.acted,true,"returning closed consumes new order action")
    toggleUnitActed(unit,"Black",false)
    toggleUnitMode(unit,"Black",false)
    local loads,xml=unit.UI.assetCalls,unit.UI.xmlCalls
    for n=1,6 do toggleUnitActed(unit,"Red",false); toggleUnitMode(unit,"Red",false) end
    eq(unit.UI.assetCalls,loads,"mode toggles never redownload image pair")
    eq(unit.UI.xmlCalls,xml,"mode toggles do not rebuild Object.UI")
    local attrs,decals=unit.UI.attributeCalls,unit.decalWrites
    for n=1,4 do updateDefeatText(unit) end
    eq(unit.UI.attributeCalls,attrs,"unchanged mode refresh writes no UI attributes")
    eq(unit.decalWrites,decals,"mode refresh does not rewrite existing decals")

    -- Crossing the lowered threshold must reuse normal first-stage exhaustion.
    local crossing=make("mode_cross","unit_nagaye_ashigaru")
    unit_state.mode_cross.front_value=1
    unit_state.mode_cross.back_value=1
    toggleUnitMode(crossing,"Blue",false)
    eq(unit_state.mode_cross.open_order,true,"threshold crossing keeps new open formation")
    eq(unit_state.mode_cross.front_value,0,"five hits exhaust newly lowered front maximum five")
    eq(unit_state.mode_cross.back_value,4,"threshold crossing starts rear with no repeated front damage and effective full four")
    eq(unit_state.mode_cross.acted,true,"threshold crossing still consumes action")
    eq(crossing.is_face_down,true,"formation threshold crossing flips to disrupted face")
    eq(crossing.flipCalls,1,"formation threshold crossing flips once")
    changeBackValue(crossing,"Blue",true)
    eq(unit_state.mode_cross.back_value,4,"formation-induced flip retains normal click debounce")
    crossing.is_face_down=false -- Simulate a stale orientation event during the flip.
    toggleUnitActed(crossing,"Blue",false)
    toggleUnitMode(crossing,"Blue",false)
    eq(unit_state.mode_cross.open_order,true,"formation click respects in-progress flip guard")
    eq(unit_state.mode_cross.acted,false,"rejected flip-guard change does not spend another action")
    crossing.is_face_down=true; tick()
    toggleUnitMode(crossing,"Blue",false)
    eq(unit_state.mode_cross.open_order,true,"disrupted back face cannot change formation")
    eq(unit_state.mode_cross.acted,false,"disrupted rejection preserves unacted flag")
    changeBackValue(crossing,"Blue",false)
    eq(unit_state.mode_cross.back_value,4,"ordinary plus cannot exceed effective rear maximum")
    changeBackValue(crossing,"Blue",true)
    eq(unit_state.mode_cross.back_value,3,"rear loss applies below reduced maximum")
    local shortcut=hotkeys["士気快捷調整"]
    shortcut.callback("Blue",crossing,nil,false)
    changeBackValue(crossing,"Blue",false)
    eq(unit_state.mode_cross.back_value,4,"quick refill uses open rear maximum")
    changeBackValue(crossing,"Blue",true)
    eq(unit_state.mode_cross.back_value,0,"quick rear clear still exhausts open troop")
    eq(getDefeatText(unit_state.mode_cross),"敗走","zero open rear enters rout")
    changeBackValue(crossing,"Blue",false)
    eq(unit_state.mode_cross.back_value,4,"rout refill restores effective rear maximum")
    eq(getDefeatText(unit_state.mode_cross),"","rout refill clears defeat without closing formation")
    shortcut.callback("Blue",crossing,nil,true)
    eq(unit_state.mode_cross.open_order,true,"rout refill preserves formation")
    resetUnit(crossing)
    eq(unit_state.mode_cross.open_order,false,"full reset closes formation")
    eq(unit_state.mode_cross.front_value,6,"full reset restores printed front maximum")
    eq(unit_state.mode_cross.back_value,5,"full reset restores printed rear maximum")

    local blocked=make("mode_blocked","unit_nagaye_ashigaru")
    for _,cause in ipairs({"acted","engaged","manual_defeat_visible"}) do
        unit_state.mode_blocked[cause]=true
        local before=copy(unit_state.mode_blocked)
        toggleUnitMode(blocked,"Red",false)
        for _,key in ipairs({"open_order","front_value","back_value","acted",cause}) do
            eq(unit_state.mode_blocked[key],before[key],"declined "..cause.." formation change preserves "..key)
        end
        unit_state.mode_blocked[cause]=false
    end
    blocked.is_face_down=true
    toggleUnitMode(blocked,"Red",false)
    eq(unit_state.mode_blocked.open_order,false,"even unacted nonrouted back face cannot change formation")
    eq(unit_state.mode_blocked.acted,false,"back rejection does not mark acted")
    blocked.is_face_down=false
    toggleUnitMode(blocked,"Red",false)
    eq(unit_state.mode_blocked.open_order,true,"legal unacted recovered front can change formation")
    eq(unit_state.mode_blocked.front_value,5,"healthy open troop is full at effective front maximum")
    eq(select(2,managedDecal(blocked,"SG_UNIT_MORALE_BAND_FRONT")),0,"healthy open front does not show damage band")
    eq(findNode(blocked.UI.xmlTable,"sgub_morale_band").attributes.active,"false","healthy open rear does not show damage band")
    shortcut.callback("Red",blocked,nil,false); changeFrontValue(blocked,"Red",true); shortcut.callback("Red",blocked,nil,true)
    eq(unit_state.mode_blocked.back_value,4,"quick front exhaustion refills effective open rear limit")
    tick()

    -- Versioned migration applies the old visual-only formation penalty exactly once.
    local legacy=make("mode_legacy","unit_nagaye_ashigaru")
    unit_state.mode_legacy={front_value=4,back_value=3,open_order=true,acted=false}
    setupUnit(legacy,getUnitConfig(legacy)); flush()
    eq(unit_state.mode_legacy.formation_tq_version,1,"old record receives formation arithmetic version")
    eq(unit_state.mode_legacy.front_value,3,"legacy visual-only open front keeps its two hits")
    eq(unit_state.mode_legacy.back_value,2,"legacy visual-only open rear keeps its two hits")
    for n=1,3 do setupUnit(legacy,getUnitConfig(legacy)); updateDefeatText(legacy) end
    eq(unit_state.mode_legacy.front_value,3,"normalization does not repeatedly subtract migration penalty")
    local migrationSave=onSave(); unit_state={}; onLoad(migrationSave); flush(); tick()
    eq(unit_state.mode_legacy.front_value,3,"save/load does not apply formation penalty twice")
    eq(unit_state.mode_legacy.back_value,2,"save/load preserves migrated rear damage")
    eq(unit_state.mode_legacy.formation_tq_version,1,"formation migration version persists")
    unit_state.mode_legacy={front_value=1,back_value=2,open_order=true,acted=true}
    setupUnit(legacy,getUnitConfig(legacy)); flush()
    eq(legacy.is_face_down,true,"legacy open front threshold also uses disruption transition")
    eq(unit_state.mode_legacy.back_value,4,"legacy threshold starts full effective rear without duplicating hits")
    eq(unit_state.mode_legacy.acted,true,"legacy migration preserves existing acted state")
    tick()
    unit_state.mode_legacy={front_value=0,back_value=0,open_order=true,acted=false}
    local oldFlips=legacy.flipCalls
    setupUnit(legacy,getUnitConfig(legacy)); flush()
    eq(unit_state.mode_legacy.front_value,0,"legacy exhausted front remains zero")
    eq(unit_state.mode_legacy.back_value,0,"legacy routed rear remains zero")
    eq(legacy.flipCalls,oldFlips,"legacy exhausted record never triggers another disruption")

    local function geometryCheck(obj,message)
        local width,depth=obj.bounds.size.x/obj.scale.x,obj.bounds.size.z/obj.scale.z
        local cx,cz=obj.bounds.offset.x/obj.scale.x,obj.bounds.offset.z/obj.scale.z
        for _,back in ipairs({false,true}) do
            local side=back and "back" or "front"
            local root=findNode(obj.UI.xmlTable,"sgub_mode_"..side)
            local node=findNode(obj.UI.xmlTable,"sgub_mode_"..side.."_image")
            local p,s=vector(root.attributes.position),vector(root.attributes.scale)
            local offset=vector(node.attributes.position)
            local x=p[1]/100+(back and 1 or -1)*offset[1]*s[1]/100
            local z=p[2]/100-offset[2]*s[2]/100
            near(x,cx+(back and 1 or -1)*(780/1200-.5)*width,message.." "..side.." bottom-right X")
            near(z,cz+(1097/1200-.5)*depth,message.." "..side.." bottom-right Y")
            near(tonumber(node.attributes.width)*s[1]/100,420/1200*width,message.." "..side.." width")
            near(tonumber(node.attributes.height)*s[2]/100,210/1200*depth,message.." "..side.." height")
            eq(node.attributes.preserveAspect,"true",message.." "..side.." preserves source aspect")
            near(offset[3],0,message.." "..side.." shares mode panel plane")
            eq(root.attributes.rotation,back and "180 0 0" or "0 0 180",message.." "..side.." outward rotation")
            local hit=buttons(obj,back)[1]
            local hp=classicButtonObjectPosition(hit)
            near(hp[1],x,message.." "..side.." hit X")
            near(hp[3],z,message.." "..side.." hit Z")
            near(hp[2],-p[3]/100+(back and -.004 or .004),message.." "..side.." hit above image")
            eq(hit.width,733,message.." "..side.." 440-pixel hit width")
            eq(hit.height,333,message.." "..side.." 200-pixel hit height")
            classicButtonOrientation(hit,back,message.." "..side)
        end
    end
    geometryCheck(unit,"default mode geometry")
    unit.scale={x=2,y=3,z=.5}; unit.bounds={size={x=4,y=.6,z=1},offset={x=.4,y=.3,z=-.2}}
    updateDefeatText(unit); flush(); geometryCheck(unit,"scaled offset mode geometry")
    unit.scale={x=1,y=1,z=1}; unit.bounds={size={x=2,y=.2,z=2},offset={x=0,y=0,z=0}}
    updateDefeatText(unit); flush()

    -- Re-tagging switches the displayed group without destroying either stored manual choice.
    unit.tags.unit_nagaye_ashigaru=nil; unit.tags.unit_teppo_ashigaru=true
    setupUnit(unit,getUnitConfig(unit)); flush(); imageIs(unit,"ready","changing to ranged group")
    toggleUnitMode(unit,"Blue",false)
    imageIs(unit,"reloading","ranged click shows loading on both faces")
    eq(unit_state.mode01.open_order,true,"ranged change retains earlier formation choice")
    eq(unit_state.mode01.reloading,true,"ranged click records loading")
    unit.flip(); onObjectDrop("Red",unit); onObjectRotate(unit,nil,true,"Blue"); flush(); tick()
    toggleUnitActed(unit,"Red",false); changeBackValue(unit,"Blue",true); toggleDefeatText(unit)
    local shortcut=hotkeys["士気快捷調整"]
    shortcut.callback("Red",unit,nil,false); changeBackValue(unit,"Red",false); shortcut.callback("Red",unit,nil,true)
    eq(unit_state.mode01.open_order,true,"movement/rout/rally does not clear formation")
    eq(unit_state.mode01.reloading,true,"movement/rout/rally does not clear reload")
    local saved=onSave(); unit_state={}; onLoad(saved); flush(); tick()
    eq(unit_state.mode01.open_order,true,"formation survives save/load")
    eq(unit_state.mode01.reloading,true,"reload survives save/load")
    imageIs(unit,"reloading","saved shooting image restores")
    unit.tags.unit_teppo_ashigaru=nil; unit.tags.unit_nagaye_ashigaru=true
    setupUnit(unit,getUnitConfig(unit)); flush(); imageIs(unit,"open","restored earlier formation on retag")
    for _,fixture in ipairs({{}, {open_order="true",reloading=1}, {open_order={},reloading=false}}) do
        unit_state.mode01={front_value=4,back_value=3,acted=true,open_order=fixture.open_order,reloading=fixture.reloading}
        local state=getStateAndConfig(unit)
        eq(state.open_order,false,"missing/invalid formation is strict false")
        eq(state.reloading,false,"missing/invalid reload is strict false")
        eq(state.acted,true,"mode normalization keeps action")
        eq(state.front_value,4,"mode normalization keeps morale")
    end
    unit_state.mode01.open_order=true; unit_state.mode01.reloading=true
    resetUnit(unit)
    eq(unit_state.mode01.open_order,false,"full reset clears formation")
    eq(unit_state.mode01.reloading,false,"full reset clears reload")
    imageIs(unit,"closed","full reset returns default image")

    UNIT_STATUS_IMAGES={engaged="https://example.invalid/mode-top-engaged.png",out_of_command="https://example.invalid/mode-top-ooc.png"}
    unit.is_face_down=false -- Reset clears values/markers, not the physical face.
    updateDefeatText(unit); flush()
    eq(#unit.buttons,12,"top statuses and bottom mode coexist with original six buttons")
    toggleUnitEngaged(unit,"Blue",false); toggleUnitOutOfCommand(unit,"Red",false)
    toggleUnitMode(unit,"Grey",false)
    eq(unit_state.mode01.engaged,true,"bottom click preserves top engaged")
    eq(unit_state.mode01.out_of_command,true,"bottom click preserves top OOC")
    imageIs(unit,"closed","engaged status prevents formation change")
    toggleUnitEngaged(unit,"Blue",false); toggleUnitMode(unit,"Grey",false)
    imageIs(unit,"open","OOC alone remains a manual marker, without new automatic movement rules")
    eq(unit.buttons[1].click_function,"changeFrontValue","mode and status additions preserve front morale index")
    eq(unit.buttons[2].click_function,"changeBackValue","mode and status additions preserve rear morale index")
    UNIT_STATUS_IMAGES={}; resetUnit(unit); flush()

    -- A manually edited inactive reserve must not rout a still-active front early.
    local reserve=make("mode_reserve","unit_nagaye_ashigaru")
    unit_state.mode_reserve.back_value=1
    toggleUnitMode(reserve,"Red",false)
    eq(unit_state.mode_reserve.back_value,0,"lowered inactive reserve threshold preserves four stored hits")
    eq(unit_state.mode_reserve.back_threshold_pending,true,"inactive threshold waits for the back face")
    eq(getDefeatText(unit_state.mode_reserve),"","lowering hidden reserve cannot rout the full front")
    toggleUnitActed(reserve,"Red",false); toggleUnitMode(reserve,"Red",false)
    eq(unit_state.mode_reserve.back_value,1,"closing restores inactive limit without erasing its four hits")
    toggleUnitActed(reserve,"Red",false); toggleUnitMode(reserve,"Red",false)
    reserve.is_face_down=true; onObjectRotate(reserve,0,180,"Red",0,0); tick()
    eq(unit_state.mode_reserve.back_threshold_pending,false,"revealing the exhausted back resolves pending threshold")
    eq(getDefeatText(unit_state.mode_reserve),"敗走","actual exhausted back still routes")

    local fire=make("mode_fire_rules","unit_teppo_ashigaru")
    unit_state.mode_fire_rules.acted=true; unit_state.mode_fire_rules.engaged=true
    unit_state.mode_fire_rules.open_order=true; fire.is_face_down=true
    local fireBefore=copy(unit_state.mode_fire_rules)
    toggleUnitMode(fire,"Blue",false)
    eq(unit_state.mode_fire_rules.reloading,true,"ranged fire marker remains available on acted engaged rear")
    eq(unit_state.mode_fire_rules.front_value,fireBefore.front_value,"ranged marker never applies open-order TQ")
    eq(unit_state.mode_fire_rules.back_value,fireBefore.back_value,"ranged marker preserves rear morale")
    eq(unit_state.mode_fire_rules.acted,true,"ranged marker does not toggle acted")
    moraleTooltip(fire,true,2,2,false,"ranged tooltip has no formation penalty from retained dormant flag")

    local valid=copy(UNIT_MODE_IMAGES)
    for _,invalid in ipairs({"","C:/private/mode.png","[https://example.invalid/open.png](https://example.invalid/open.png)",valid.closed,UNIT_BACK_RAIL_IMAGE_URL}) do
        UNIT_MODE_IMAGES.open=invalid
        updateDefeatText(unit); flush()
        hidden(unit,"missing/invalid/conflicting partner "..invalid)
        eq(findNode(unit.UI.xmlTable,"sgub_root").attributes.active,"true","invalid mode pair leaves rear rail active")
        eq(objectAssetURL(unit,"sgub_mode_image_closed"),nil,"partial/unsafe pair is not registered")
    end
    UNIT_MODE_IMAGES=copy(valid); updateDefeatText(unit); flush()
    imageIs(unit,"closed","pair restoration returns mode control")

    local configuredMode=UNIT_CONFIGS[1].marker_mode
    UNIT_CONFIGS[1].marker_mode="unsupported-mode"
    updateDefeatText(unit); flush(); hidden(unit,"unknown marker mode")
    unit_state.mode01.open_order=true; unit_state.mode01.reloading=true
    toggleUnitMode(unit,"Red",false)
    eq(unit_state.mode01.open_order,true,"unknown mode callback preserves formation flag")
    eq(unit_state.mode01.reloading,true,"unknown mode callback preserves reload flag")
    UNIT_CONFIGS[1].marker_mode=configuredMode
    resetUnit(unit); flush()

    -- Distinct groups live on different units and may safely reuse their image pair.
    UNIT_MODE_IMAGES.ready=UNIT_MODE_IMAGES.closed
    UNIT_MODE_IMAGES.reloading=UNIT_MODE_IMAGES.open
    updateDefeatText(unit); flush(); imageIs(unit,"closed","shared cross-group URLs keep formation visible")
    local shared=make("mode_shared","unit_teppo_sohei")
    imageIs(shared,"ready","shared cross-group URLs keep fire control visible")
    eq(objectAssetURL(shared,"sgub_mode_image_closed"),nil,"shared cross-group URL does not register unused formation alias")
    toggleUnitMode(shared,"Blue",false)
    imageIs(shared,"reloading","shared cross-group URL still switches fire image")
    UNIT_MODE_IMAGES=copy(valid)
    updateDefeatText(shared); flush()

    local pending=token("下部画像載入中","","mode_pending")
    pending.tags.unit_yumi_sohei=true; created[#created+1]=pending
    pending.UI.holdAssets=true; setupUnit(pending,getUnitConfig(pending)); flush()
    hidden(pending,"pending pair")
    toggleUnitMode(pending,"Red",false)
    pending.UI.holdAssets=false; pending.UI.loading=false; flush()
    imageIs(pending,"reloading","pending callback uses latest reload state")
    local foreignURL="https://example.invalid/foreign-mode.png"
    unit.UI.assets[#unit.UI.assets+1]={name="foreign_mode_asset",url=foreignURL}
    unit.UI.xmlTable[#unit.UI.xmlTable+1]={tag="Text",attributes={id="foreign_mode_text"},value="保留"}
    UNIT_MODE_IMAGES.open=foreignURL; updateDefeatText(unit); flush()
    hidden(unit,"foreign URL collision")
    eq(objectAssetURL(unit,"foreign_mode_asset"),foreignURL,"collision does not alter external resource")
    UNIT_MODE_IMAGES=copy(valid); updateDefeatText(unit); flush()
    unit.createButton({click_function="foreignModeButton",label="外部",rotation={0,0,0}})
    unit.tags.unit_nagaye_ashigaru=nil; clearUnitCounterVisuals(unit); flush()
    eq(#unit.buttons,1,"cleanup removes own mode and counter buttons only")
    eq(unit.buttons[1].click_function,"foreignModeButton","cleanup preserves external button")
    eq(findNode(unit.UI.xmlTable,"sgub_mode_front"),nil,"cleanup removes front mode root")
    eq(findNode(unit.UI.xmlTable,"sgub_mode_back"),nil,"cleanup removes back mode root")
    eq(findNode(unit.UI.xmlTable,"foreign_mode_text").value,"保留","cleanup preserves external XML")
    eq(objectAssetURL(unit,"foreign_mode_asset"),foreignURL,"cleanup preserves external resource")
    for _,obj in ipairs(created) do objects[obj.guid]=nil; onObjectDestroy(obj) end
    flush()
    UNIT_MODE_IMAGES,UNIT_STATUS_IMAGES=originalImages,originalStatus
end

function runTeamChecks(merged)
    local configuredDefeatURL=UNIT_DEFEAT_IMAGE_URL
    local configuredNumberImages=UNIT_NUMBER_IMAGES
    local configuredBackImages,configuredRail,configuredActions=UNIT_NUMBER_BACK_IMAGES,UNIT_BACK_RAIL_IMAGE_URL,UNIT_ACTION_IMAGES
    local configuredMoraleBands=UNIT_MORALE_BAND_IMAGES
    local configuredStatusImages=UNIT_STATUS_IMAGES
    local configuredModeImages=UNIT_MODE_IMAGES
    if merged then
        -- Existing resource-count regressions intentionally run with the optional bands disabled.
        -- The dedicated morale-band suite below enables and verifies both new assets separately.
        UNIT_MORALE_BAND_IMAGES={}
        UNIT_STATUS_IMAGES={} -- Dedicated status suite supplies optional sprites separately.
        UNIT_MODE_IMAGES={} -- Dedicated formation/fire suite supplies its own pairs.
        UNIT_NUMBER_IMAGES={}; UNIT_NUMBER_BACK_IMAGES={}
        for value=0,8 do
            UNIT_NUMBER_IMAGES[value]="https://example.invalid/number-"..value..".png"
            UNIT_NUMBER_BACK_IMAGES[value]="https://example.invalid/back-number-"..value..".png"
        end
        UNIT_BACK_RAIL_IMAGE_URL="https://example.invalid/back-rail.png"
        UNIT_ACTION_IMAGES={front_unacted="https://example.invalid/front-unacted.png",front_acted="https://example.invalid/front-acted.png",back_unacted="https://example.invalid/back-unacted.png",back_acted="https://example.invalid/back-acted.png"}
    end
    UNIT_DEFEAT_IMAGE_URL="" -- Fixtures start in text mode; shipped URL is restored at the end.
    local rows={
        {"太田資正","ota_honjin","main",1522,5},{"三戸興義","ota_honjin","deputy1",1525,2},
        {"太田御前","ota_honjin","deputy2",1544,2},{"太田資房","iwatsuke_shu","main",1542,2},
        {"小宮山忠孝","iwatsuke_shu","deputy1",1533,2},{"高築道叶","iwatsuke_shu","deputy2",1523,2},
        {"太田康資","edo_shu","main",1531,3},{"宮城政業","edo_shu","deputy1",1495,2},
        {"舎人重長","edo_shu","deputy2",1532,2},{"梶原政景","matsuyama_shu","main",1548,4},
        {"広沢信秀","matsuyama_shu","deputy1",1543,2},{"比企政員","matsuyama_shu","deputy2",1538,2}
    }
    local roster={}
    for n,row in ipairs(rows) do roster[n]=token(row[1],"",string.format("%06d",n)) end
    local foreignDecal={name="既存家紋",url="https://example.invalid/crest.png",position={0,0.11,0},rotation={90,0,0},scale={0.4,0.4,1}}
    roster[1].decals={copy(foreignDecal)}
    roster[12].decals={
        {name=STAMP_NAME,url="https://example.invalid/obsolete-a.png"},
        {name=STAMP_NAME,url="https://example.invalid/obsolete-b.png"}
    }
    roster[12].is_face_down=true
    local unit=token("長柄足軽","team=ota_honjin\nrole=unit","unit01")
    unit.tags.unit_nagaye_ashigaru,unit.tags.count_200=true,true
    onLoad(""); flush(); tick()
    local initializedXMLCalls = UI.xmlCalls
    local initialStamp,initialCount=managedStamp(roster[12])
    eq(initialCount,1,"startup deduplicates back stamp on never-viewed commander")
    eq(initialStamp.url,STAMP_URL,"startup supplies unified back stamp URL")
    eq(roster[12].is_face_down,true,"startup preserves existing face-down state")
    eq(roster[1].is_face_down,false,"startup preserves existing face-up state")
    local preservedForeign
    for _,decal in ipairs(roster[1].decals) do if decal.name == foreignDecal.name then preservedForeign=decal end end
    eq(preservedForeign ~= nil,true,"startup retains foreign decal")
    eq(preservedForeign.url,foreignDecal.url,"startup retains foreign decal URL")
    eq(preservedForeign.scale[1],foreignDecal.scale[1],"startup retains foreign decal scale")
    eq(select(2,managedStamp(unit)),0,"unit has no automatic back stamp")
    onObjectHover("Red",roster[1]); eq(UI.values.sg_White_main_name,nil,"other player hover leaves White view unchanged")
    onObjectHover("White",nil)
    for n,row in ipairs(rows) do
        onObjectHover("White",roster[n])
        local prefix="sg_White_"..row[3]
        eq(UI.values[prefix.."_name"],row[1].."　年齢 "..tostring(1563-row[4]),"roster name/age")
        eq(UI.values[prefix.."_command"],tostring(row[5]),"roster command")
    end
    onObjectHover("White",unit)
    eq(UI.values.sg_White_main_name,"太田資正　年齢 41","unit selects formation")
    eq(commandSlots("sg_White_main"),"●●●●●○","command dots")
    slotLayout("sg_White_main","healthy main slots")
    slotLayout("sg_White_deputy1","healthy deputy slots")
    slotColors("sg_White_main","#7BC4B5","healthy main slot color")
    slotColors("sg_White_deputy1","#E2A56C","healthy deputy slot color")
    noStatusTooltip("sg_White_main","healthy main tooltip absent")
    noStatusTooltip("sg_White_deputy1","healthy deputy tooltip absent")
    local scanCount,uiCount=scans,changes
    local initialDecalWrites=roster[1].decalWrites
    local initialDecalReads,initialBoundsReads=roster[1].decalReads,roster[1].boundsReads
    for n=1,5 do tick() end
    eq(scans,scanCount,"steady refresh does not scan board")
    eq(changes,uiCount,"unchanged values cause no UI calls")
    eq(roster[1].decalWrites,initialDecalWrites,"steady polling does not rewrite unchanged back decal")
    eq(roster[1].decalReads,initialDecalReads,"steady team refresh does not reread decals")
    eq(roster[1].boundsReads,initialBoundsReads,"steady team refresh does not reread model bounds")
    onObjectHover("White",roster[1]); flush()
    eq(roster[1].decalReads > initialDecalReads,true,"hover explicitly validates decal list")
    roster[1].description="team=ota_honjin\nrole=main\nbirth=1520\ncommand=6\nstatus=轻伤\nformation=太田家 試験\norder=防御"
    tick()
    eq(UI.values.sg_White_main_name,"太田資正　年齢 43","birth override")
    eq(UI.values.sg_White_main_command,"6","command override")
    eq(UI.values.sg_White_formation,"太田家 試験","formation override")
    eq(UI.values.sg_White_main_mobility,"機動 4","injury movement")
    eq(UI.values.sg_White_main_status_text,"浅手","legacy status spelling")
    roster[1].description=roster[1].description:gsub("command=6","command=99"):gsub("birth=1520","birth=invalid")
    tick()
    eq(UI.values.sg_White_main_command,"5","invalid command fallback")
    eq(UI.values.sg_White_main_name,"太田資正　年齢 41","invalid birth fallback")
    eq(UI.attributes.sg_White_main_name.tooltip:find("統率",1,true) ~= nil,true,"invalid field diagnostic")
    roster[1].is_face_down=true
    local flipDecalWrites=roster[1].decalWrites
    onObjectRotate(roster[1],0,180,"White",0,0); tick()
    eq(UI.values.sg_White_main_action,"行動 済","flip refresh")
    eq(roster[1].decalWrites,flipDecalWrites,"flipping does not rewrite decal data")
    eq(roster[1].is_face_down,true,"flip handler preserves token face")
    roster[2].description="team=ota_honjin\nrole=deputy1\nstatus=重傷"; tick()
    eq(UI.values.sg_White_deputy1_mobility,"機動 4","heavy injury movement")
    eq(commandSlots("sg_White_deputy1"),"●X○○○○","heavy injury crosses last command dot")
    slotLayout("sg_White_deputy1","heavy deputy slots")
    slotColors("sg_White_deputy1","#E2A56C","heavy deputy uses base command color")
    eq(UI.values.sg_White_deputy1_command,"1","deputy heavy injury reduces command from two to one")
    eq(UI.attributes.sg_White_main_status_text.color ~= UI.attributes.sg_White_deputy1_status_text.color,true,"distinct injury text colors")
    local longURL="https://example.invalid/"..string.rep("x",8192).."?key=a=b&other=%20"
    table.insert(UI.assets,{name="late_foreign_asset",url="https://example.invalid/late-ui.png"})
    roster[1].description=roster[1].description.."\nimage=  "..longURL.." \t\n備考=保持"; tick()
    eq(assetURL("sgp_ota_honjin_main"),longURL,"long URL preserved")
    eq(UI.attributes.sg_White_main_portrait.image,longURL,"portrait uses direct URL")
    eq(assetURL("other"),"https://example.invalid/other.png","foreign assets retained")
    eq(assetURL("late_foreign_asset"),"https://example.invalid/late-ui.png","assets added by another script after initialization are retained")
    local count=UI.assetCalls; tick()
    eq(UI.assetCalls,count,"unchanged URL not reloaded")
    eq(UI.xmlCalls,initializedXMLCalls,"no XML rebuild on hover")
    local before=roster[1].description
    sgSetOrder(Player.Red,nil,"sg_White_attack")
    eq(roster[1].description,before,"other player cannot use White order button")
    sgSetOrder(Player.White,nil,"sg_White_regroup")
    eq(roster[1].description,(before:gsub("order=防御","order=再編")),"only order changed")
    eq(UI.values.sg_White_order,"現在命令：再編","order display")
    UI.holdAssets=true
    roster[1].description=roster[1].description:gsub("example.invalid/","example.invalid/new/"); tick()
    eq(UI.loading,true,"assets pending")
    onObjectHover("White",roster[7])
    UI.loading=false; UI.holdAssets=false; flush()
    eq(UI.values.sg_White_main_name,"太田康資　年齢 32","latest selection after loading")
    onObjectHover("White",roster[1]); flush()
    UI.holdAssets=true
    roster[1].description=roster[1].description:gsub("invalid/new/","invalid/changed/"); tick()
    sgClose(Player.White)
    UI.loading=false; UI.holdAssets=false; flush(); tick()
    eq(UI.attributes.sg_White_panel.active,"false","closing survives image loading")
    onObjectHover("White",roster[1]); flush(); sgPin(Player.White)
    onObjectHover("White",roster[7])
    eq(UI.values.sg_White_main_name,"太田資正　年齢 41","pin")
    sgPin(Player.White); onObjectHover("White",roster[7])
    eq(UI.values.sg_White_main_name,"太田康資　年齢 32","unpin")
    sgResize(Player.White,nil,"sg_White_smaller")
    eq(UI.attributes.sg_White_panel.scale,"0.9 0.9 1","resize")
    onObjectHover("White",roster[1])
    roster[1].description=roster[1].description:gsub("image=[^\n]*","image=-"); tick()
    eq(UI.attributes.sg_White_main_portrait.active,"false","explicit no image")
    eq(assetURL("sgp_ota_honjin_main"),nil,"removed obsolete asset")
    -- 行動印は全武将の共用URLで、旧Descriptionの個別指定や「-」を無視する。
    eq(UI.attributes.sg_White_main_acted_fallback.active,"false","shared stamp removes text fallback without Description URL")
    eq(UI.attributes.sg_White_main_acted_stamp.active,"true","shared stamp shown without Description URL")
    eq(UI.attributes.sg_White_main_acted_stamp.image,STAMP_URL,"all profiles use default shared stamp URL")
    local commonStampCount=0
    for _,asset in ipairs(UI.assets) do if asset.name == "sgp_common_acted" then commonStampCount=commonStampCount+1 end end
    eq(commonStampCount,1,"shared action image is registered once across profiles")
    local stampURL="https://example.invalid/stamp.png?x=a=b&v=1"
    roster[1].description=roster[1].description.."\nacted_image="..stampURL
    roster[1].description=roster[1].description:gsub("status=轻伤","status=重傷")
    tick()
    eq(assetURL("sgp_common_acted"),STAMP_URL,"deputy uses fixed shared stamp")
    eq(UI.attributes.sg_White_main_acted_stamp.active,"true","custom stamp overlays acted portrait")
    eq(UI.attributes.sg_White_main_acted_stamp.image,STAMP_URL,"old Description stamp URL does not override shared image")
    eq(UI.attributes.sg_White_main_acted_fallback.active,"false","custom stamp replaces text fallback")
    eq(UI.attributes.sg_White_main_injury_badge.active,"true","heavy injury badge visible")
    eq(UI.values.sg_White_main_injury_label,"深手","heavy injury label")
    eq(UI.values.sg_White_main_command,"4","heavy injury reduces current command")
    eq(commandSlots("sg_White_main"),"●●●●X○","heavy injury command overlay")
    eq(UI.attributes.sg_White_main_portrait.color,"#BDBDBD","heavy portrait dimmed")
    eq(UI.attributes.sg_White_main_portrait_frame.color,"#D15C68","heavy injury frame")
    local stampLoads=UI.assetCalls
    roster[2].is_face_down=true; tick()
    eq(UI.attributes.sg_White_deputy1_acted_stamp.active,"true","deputy flip shows shared stamp")
    eq(UI.assetCalls,stampLoads,"flip does not reload stamp asset")
    roster[1].is_face_down=false; tick()
    eq(UI.attributes.sg_White_main_acted_stamp.active,"false","face up hides custom stamp")
    eq(UI.attributes.sg_White_main_injury_badge.active,"true","face up keeps injury badge")
    eq(UI.attributes.sg_White_main_portrait.color,"#BDBDBD","face up keeps injury tint")
    roster[1].description=roster[1].description:gsub("status=重傷","status=軽傷"); tick()
    eq(UI.attributes.sg_White_main_portrait.color,"#FFFFFF","light injury restores brightness")
    eq(UI.attributes.sg_White_main_portrait_frame.color,"#F0AAAA","light injury frame")
    eq(UI.values.sg_White_main_injury_label,"浅手","light injury label")
    eq(commandSlots("sg_White_main"),"●●●●●○","light injury keeps all base command dots")
    roster[1].description=roster[1].description:gsub("status=軽傷","status=健康")
    roster[1].is_face_down=true; tick()
    eq(UI.attributes.sg_White_main_injury_badge.active,"false","healed hides injury badge")
    eq(UI.attributes.sg_White_main_portrait_frame.color,"#5E604F","healed restores neutral frame")
    eq(UI.attributes.sg_White_main_acted_stamp.active,"true","healing does not reset action")
    local statusDescription=roster[1].description
    clickUI(Player.Red,"sg_White_main_status")
    eq(roster[1].description,statusDescription,"other player cannot use White status button")
    clickUI(Player.White,"sg_White_main_status")
    eq(roster[1].description,statusDescription:gsub("status=健康","status=浅手"),"status click preserves other Description fields")
    eq(UI.values.sg_White_main_status_text,"浅手","status button health to light")
    eq(UI.attributes.sg_White_main_status_text.text,"浅手","explicit status text attribute follows first click")
    eq(UI.values.sg_White_main_command,"5","light injury leaves numeric command unchanged")
    eq(UI.attributes.sg_White_main_status.colors,"#86454B|#A96066|#623238|#30362D","light injury changes button background")
    eq(commandSlots("sg_White_main"),"●●●●●○","status button light command unchanged")
    clickUI(Player.White,"sg_White_main_status")
    eq(UI.values.sg_White_main_status_text,"深手","status button light to heavy")
    eq(UI.attributes.sg_White_main_status_text.text,"深手","explicit status text attribute follows heavy click")
    eq(UI.values.sg_White_main_command,"4","heavy click reduces numeric command")
    eq(UI.attributes.sg_White_main_status.colors,"#772C3A|#994050|#5C202E|#30362D","heavy injury changes button background")
    eq(commandSlots("sg_White_main"),"●●●●X○","status button heavy command overlay")
    slotLayout("sg_White_main","heavy main slots")
    slotColors("sg_White_main","#7BC4B5","heavy main uses base command color")
    noStatusTooltip("sg_White_main","heavy main tooltip absent")
    clickUI(Player.White,"sg_White_main_status")
    eq(UI.values.sg_White_main_status_text,"討死","status button heavy to dead")
    eq(UI.attributes.sg_White_main_status_text.text,"討死","explicit status text attribute follows terminal click")
    eq(UI.values.sg_White_main_command,"X","terminal status replaces command number with X")
    eq(UI.attributes.sg_White_main_card.color,"#1B1F1B","terminal status dims full card background")
    eq(UI.attributes.sg_White_main_name.color,"#797D75","terminal status dims name")
    eq(UI.attributes.sg_White_main_mobility.color,"#6F746B","terminal status dims details")
    eq(UI.attributes.sg_White_main_acted_stamp.color,"#FFFFFF55","terminal status dims action stamp")
    eq(UI.values.sg_White_main_mobility,"機動 —","dead mobility disabled")
    eq(commandSlots("sg_White_main"),"XXXXXX","dead command disabled")
    slotLayout("sg_White_main","terminal main slots")
    slotColors("sg_White_main","#666B65","terminal main slot color")
    noStatusTooltip("sg_White_main","terminal main tooltip absent")
    eq(UI.attributes.sg_White_main_portrait.color,"#3F3F3F","dead portrait deeply dimmed")
    clickUI(Player.White,"sg_White_main_status")
    eq(UI.values.sg_White_main_status_text,"無傷","status button dead to health")
    eq(UI.attributes.sg_White_main_status_text.text,"無傷","explicit status text attribute follows reset click")
    eq(UI.values.sg_White_main_command,"5","reset restores original numeric command")
    slotLayout("sg_White_main","reset restores circle font and optical offset")
    slotColors("sg_White_main","#7BC4B5","reset restores circle base command color")
    eq(UI.attributes.sg_White_main_card.color,"#292D28","reset restores card background")
    eq(UI.attributes.sg_White_main_name.color,"#F2EAD9","reset restores name brightness")
    noStatusTooltip("sg_White_main","status tooltip stays absent after reset")
    eq(UI.values.sg_White_main_status,nil,"button itself stays blank while sibling Text shows state")
    eq(UI.values.sg_White_main_mobility,"機動 9","health mobility restored")
    eq(UI.attributes.sg_White_main_portrait.color,"#FFFFFF","health portrait restored")
    local mainDescription, otherDeputyDescription = roster[1].description, roster[3].description
    clickUI(Player.White,"sg_White_deputy1_status")
    eq(UI.values.sg_White_deputy1_status_text,"討死","first deputy XML button works")
    eq(roster[1].description,mainDescription,"deputy click leaves main unchanged")
    eq(roster[3].description,otherDeputyDescription,"deputy click leaves other deputy unchanged")
    clickUI(Player.White,"sg_White_deputy1_status")
    clickUI(Player.White,"sg_White_deputy1_status")
    clickUI(Player.White,"sg_White_deputy1_status")
    eq(UI.values.sg_White_deputy1_status_text,"深手","deputy cycle returns to prior injury")
    clickUI(Player.White,"sg_White_deputy2_status")
    eq(UI.values.sg_White_deputy2_status_text,"浅手","second deputy XML button works")
    roster[2].description=roster[2].description.."\nacted_image=https://example.invalid/other-stamp.png"; tick()
    eq(assetURL("sgp_common_acted"),STAMP_URL,"individual legacy stamp URL ignored")
    eq(assetURL("sgp_common_acted"),STAMP_URL,"other deputy retains fixed shared stamp")
    roster[2].description=roster[2].description:gsub("acted_image=[^\n]*","acted_image=-"); tick()
    eq(UI.attributes.sg_White_deputy1_acted_stamp.active,"true","legacy dash cannot disable shared stamp")
    eq(UI.attributes.sg_White_deputy1_acted_fallback.active,"false","legacy dash does not reenable fallback text")
    roster[2].description="team=new_team\nrole=main\nname=試験武将\nbirth=1500\ncommand=4\nformation=試験備\nstatus=健康"; tick()
    eq(UI.values.sg_White_deputy1_status_text,"未配置","changed team removes old slot")
    eq(UI.attributes.sg_White_deputy1_status.interactable,"false","missing member button disabled")
    local missingDescription = roster[2].description
    sgSetStatus(Player.White,nil,"sg_White_deputy1_status")
    eq(roster[2].description,missingDescription,"missing member cannot be changed by callback")
    eq(UI.attributes.sg_White_deputy1_acted_stamp.active,"false","missing member has no stamp")
    eq(UI.attributes.sg_White_deputy1_acted_fallback.active,"false","missing member has no acted text")
    eq(UI.attributes.sg_White_deputy1_injury_badge.active,"false","missing member has no injury badge")
    onObjectHover("White",roster[2]); flush()
    eq(UI.values.sg_White_main_name,"試験武将　年齢 63","new team without global edit")
    eq(UI.values.sg_White_main_command,"4","new team stats")
    local currentScans=scans
    for n=1,5 do tick() end
    eq(scans,currentScans,"missing deputies do not rescan")
    local duplicate=token("重複","team=new_team\nrole=main","dupe01")
    onObjectSpawn(duplicate); flush(); tick()
    eq(UI.values.sg_White_main_status_text,"配置重複","duplicate role detection")
    eq(UI.attributes.sg_White_main_status.interactable,"false","duplicate role button disabled")
    local duplicateDescription, originalDescription = duplicate.description, roster[2].description
    sgSetStatus(Player.White,nil,"sg_White_main_status")
    eq(duplicate.description,duplicateDescription,"duplicate role cannot change duplicate")
    eq(roster[2].description,originalDescription,"duplicate role cannot change original")
    onObjectDestroy(duplicate); objects.dupe01=nil; flush(); tick()
    eq(UI.values.sg_White_main_status_text,"無傷","deletion recovery")
    eq(UI.attributes.sg_White_main_status.interactable,"true","resolved duplicate button enabled")
    clickUI(Player.White,"sg_White_main_status")
    eq(UI.values.sg_White_main_status_text,"浅手","resolved duplicate button works")
    sgClose(Player.White)
    local closedDescription=roster[2].description
    sgSetStatus(Player.White,nil,"sg_White_main_status")
    eq(roster[2].description,closedDescription,"hidden panel ignores stale status callbacks")
    onObjectHover("White",roster[2]); flush()
    token("増援","team=new_team\nrole=deputy1\nname=増援\n生年=1510\n統率=3\n状態=軽傷","late01")
    sgRefresh(Player.White)
    eq(UI.values.sg_White_deputy1_name,"増援　年齢 53","refresh discovers new token")
    eq(UI.values.sg_White_deputy1_command,"3","Japanese field aliases")
    eq(UI.values.sg_White_deputy1_mobility,"機動 4","Japanese status alias")
    local transient=token("削除","","tmp001")
    onObjectSpawn(transient); onObjectDestroy(transient); objects.tmp001=nil; flush(); tick()
    eq(true,true,"spawn-delete race")
    -- 多人检查使用独立队伍，不改动前面的武将或合并版兵种状态。
    local mpAlpha=token("多人甲将","team=mp_alpha\nrole=main\nname=多人甲将\nbirth=1522\ncommand=5\nstatus=健康\nimage=-\nformation=多人甲備\norder=防御","mpa001")
    local mpAlphaDeputy=token("多人甲副将","team=mp_alpha\nrole=deputy1\nname=多人甲副将\nbirth=1525\ncommand=2\nstatus=健康\nimage=-","mpa002")
    local mpBeta=token("多人乙将","team=mp_beta\nrole=main\nname=多人乙将\nbirth=1531\ncommand=3\nstatus=健康\nimage=-\nformation=多人乙備\norder=防御","mpb001")
    local mpGamma=token("多人丙将","team=mp_gamma\nrole=main\nname=多人丙将\nbirth=1530\ncommand=4\nstatus=健康\nimage=https://example.invalid/mp-gamma.png\nformation=多人丙備","mpc001")
    local mpDelta=token("多人丁将","team=mp_delta\nrole=main\nname=多人丁将\nbirth=1540\ncommand=2\nstatus=健康\nimage=https://example.invalid/mp-delta.png\nformation=多人丁備","mpd001")
    for _,object in ipairs({mpAlpha,mpAlphaDeputy,mpBeta,mpGamma,mpDelta}) do onObjectSpawn(object) end
    flush(); tick()
    eq(Player.Red.host,false,"multiplayer Red is not host")
    eq(Player.Blue.host,false,"multiplayer Blue is not host")
    for _,color in ipairs({"Red","Blue","Grey","Black"}) do
        local root=UI.xml:match('<Panel id="sg_'..color..'_panel"[^>]*>')
        eq(root ~= nil,true,"player panel exists: "..color)
        eq(root and root:match('visibility="([^"]+)"'),color,"player panel visibility: "..color)
    end
    onObjectHover("Red",mpAlpha)
    onObjectHover("Blue",mpBeta)
    eq(UI.values.sg_Red_main_name,"多人甲将　年齢 41","nonhost Red selects own team")
    eq(UI.values.sg_Blue_main_name,"多人乙将　年齢 32","nonhost Blue selects different team")
    eq(UI.values.sg_Red_formation,"多人甲備","Blue hover preserves Red formation")
    local betaDescription=mpBeta.description
    clickUI(Player.Red,"sg_Red_main_status")
    eq(mpAlpha.description:find("status=浅手",1,true) ~= nil,true,"nonhost Red writes own team status")
    eq(mpBeta.description,betaDescription,"Red status leaves Blue team unchanged")
    eq(UI.values.sg_Red_main_status_text,"浅手","nonhost Red status display")
    eq(UI.values.sg_Blue_main_status_text,"無傷","different-team Blue display unchanged")
    local alphaDescription=mpAlpha.description
    clickUI(Player.Blue,"sg_Blue_main_status")
    eq(mpBeta.description:find("status=浅手",1,true) ~= nil,true,"nonhost Blue writes own team status")
    eq(mpAlpha.description,alphaDescription,"Blue status leaves Red team unchanged")
    clickUI(Player.Red,"sg_Red_deputy1_status")
    eq(mpAlphaDeputy.description:find("status=浅手",1,true) ~= nil,true,"nonhost deputy XML status button works")
    eq(mpAlpha.description,alphaDescription,"nonhost deputy click leaves main unchanged")
    onObjectHover("Blue",mpAlpha)
    eq(UI.values.sg_Blue_main_status_text,"浅手","new viewer reads shared status")
    eq(UI.values.sg_Blue_deputy1_status_text,"浅手","new viewer reads shared deputy status")
    clickUI(Player.Red,"sg_Red_main_status")
    eq(UI.values.sg_Red_main_status_text,"深手","Red advances shared main status")
    eq(UI.values.sg_Blue_main_status_text,"深手","same-team Blue updates immediately")
    eq(UI.values.sg_Red_main_command,"4","shared heavy status updates Red command number")
    eq(UI.values.sg_Blue_main_command,"4","shared heavy status updates Blue command number")
    eq(commandSlots("sg_Blue_main"),"●●●●X○","same-team injury command overlay updates")
    sameSlots("sg_Red_main","sg_Blue_main","shared heavy command bar")
    slotLayout("sg_Red_main","shared Red heavy slots")
    slotLayout("sg_Blue_main","shared Blue heavy slots")
    noStatusTooltip("sg_Red_main","shared Red tooltip absent")
    noStatusTooltip("sg_Blue_main","shared Blue tooltip absent")
    local forgedMain,forgedDeputy=mpAlpha.description,mpAlphaDeputy.description
    clickUI(Player.Blue,"sg_Red_main_status")
    clickUI(Player.Red,"sg_Blue_deputy1_status")
    eq(mpAlpha.description,forgedMain,"forged other-color main ID rejected")
    eq(mpAlphaDeputy.description,forgedDeputy,"forged other-color deputy ID rejected")
    local forgedOrder=mpAlpha.description
    clickUI(Player.Blue,"sg_Red_attack")
    eq(mpAlpha.description,forgedOrder,"forged other-color order ID rejected")
    clickUI(Player.Red,"sg_Red_attack")
    eq(UI.values.sg_Red_order,"現在命令：攻撃","nonhost order button writes own selected team")
    eq(UI.values.sg_Blue_order,"現在命令：攻撃","shared order updates other same-team view")
    clickUI(Player.Red,"sg_Red_smaller")
    eq(UI.attributes.sg_Red_panel.scale,"0.9 0.9 1","Red XML resize changes own scale")
    eq(UI.attributes.sg_Blue_panel.scale,"1.0 1.0 1","Red resize preserves Blue scale")
    clickUI(Player.Blue,"sg_Blue_larger")
    eq(UI.attributes.sg_Blue_panel.scale,"1.1 1.1 1","Blue XML resize changes own scale")
    eq(UI.attributes.sg_Red_panel.scale,"0.9 0.9 1","Blue resize preserves Red scale")
    clickUI(Player.Blue,"sg_Red_close")
    eq(UI.attributes.sg_Red_panel.active,"true","forged other-color close ID rejected")
    clickUI(Player.Red,"sg_Red_pin")
    eq(UI.values.sg_Red_pin,"固定：有","Red XML pin changes own setting")
    eq(UI.values.sg_Blue_pin,"固定：無","Red pin preserves Blue setting")
    onObjectHover("Blue",mpBeta)
    onObjectHover("Red",mpBeta)
    eq(UI.values.sg_Red_main_name,"多人甲将　年齢 41","Red pin preserves selected team")
    eq(UI.values.sg_Blue_main_name,"多人乙将　年齢 32","unpinned Blue independently switches team")
    clickUI(Player.Blue,"sg_Blue_pin")
    clickUI(Player.Red,"sg_Red_pin")
    eq(UI.values.sg_Red_pin,"固定：無","Red unpins own view")
    eq(UI.values.sg_Blue_pin,"固定：有","Red unpin preserves Blue pin")
    clickUI(Player.Red,"sg_Red_close")
    eq(UI.attributes.sg_Red_panel.active,"false","Red XML close hides own view")
    eq(UI.attributes.sg_Blue_panel.active,"true","Red close preserves Blue visible view")
    eq(UI.values.sg_Blue_pin,"固定：有","Red close preserves Blue pinned setting")
    local hiddenAlpha=mpAlpha.description
    clickUI(Player.Red,"sg_Red_main_status")
    eq(mpAlpha.description,hiddenAlpha,"closed Red view rejects stale XML status click")
    onObjectHover("Red",mpAlpha)
    eq(UI.attributes.sg_Red_panel.active,"true","Red hover reopens own view")
    eq(UI.attributes.sg_Blue_panel.scale,"1.1 1.1 1","Red reopening preserves Blue scale")
    clickUI(Player.Blue,"sg_Blue_pin")
    onObjectHover("Grey",mpAlpha)
    clickUI(Player.Grey,"sg_Grey_main_status")
    eq(mpAlpha.description:find("status=討死",1,true) ~= nil,true,"Grey spectator can change status")
    eq(UI.values.sg_Red_main_status_text,"討死","Grey status change updates seated same-team view")
    sameSlots("sg_Red_main","sg_Grey_main","shared terminal command bar")
    slotLayout("sg_Grey_main","shared Grey terminal slots")
    clickUI(Player.Grey,"sg_Grey_main_status")
    eq(UI.values.sg_Grey_main_status_text,"無傷","Grey reset changes shared terminal status to healthy")
    sameSlots("sg_Red_main","sg_Grey_main","shared reset command bar")
    slotLayout("sg_Red_main","shared Red restored circle slots")
    slotLayout("sg_Grey_main","shared Grey restored circle slots")
    slotColors("sg_Red_main","#7BC4B5","shared Red restored base command color")
    slotColors("sg_Grey_main","#7BC4B5","shared Grey restored base command color")
    onObjectHover("Black",mpBeta)
    clickUI(Player.Black,"sg_Black_main_status")
    eq(mpBeta.description:find("status=深手",1,true) ~= nil,true,"Black GM can change status without host flag")
    eq(UI.values.sg_Blue_main_status_text,"深手","Black status change updates Blue same-team view")
    -- 全局画像加载期间记录两人的最终选择；关闭一侧不能被旧完成回调重新打开。
    UI.holdAssets=true
    mpAlpha.description=mpAlpha.description:gsub("image=%-","image=https://example.invalid/mp-alpha.png")
    tick()
    eq(UI.loading,true,"multiplayer assets pending")
    onObjectHover("Red",mpGamma)
    onObjectHover("Red",mpDelta)
    onObjectHover("Blue",mpDelta)
    onObjectHover("Blue",mpGamma)
    local pendingBeta,pendingGamma=mpBeta.description,mpGamma.description
    clickUI(Player.Blue,"sg_Blue_main_status")
    eq(mpBeta.description,pendingBeta,"pending stale view does not change formerly shown team")
    eq(mpGamma.description,pendingGamma,"pending stale view does not change newly selected team")
    clickUI(Player.Red,"sg_Red_close")
    UI.loading=false; UI.holdAssets=false; flush(); tick()
    eq(UI.attributes.sg_Red_panel.active,"false","Red closing survives shared image completion")
    eq(UI.values.sg_Blue_main_name,"多人丙将　年齢 33","Blue final selection survives shared image completion")
    eq(UI.values.sg_Blue_formation,"多人丙備","Blue final formation survives shared image completion")
    eq(UI.attributes.sg_Blue_panel.scale,"1.1 1.1 1","asset completion preserves Blue scale")
    eq(UI.values.sg_Grey_main_name,"多人甲将　年齢 41","double-player loading preserves Grey selection")
    eq(UI.values.sg_Black_main_name,"多人乙将　年齢 32","double-player loading preserves Black selection")
    onObjectHover("Red",mpDelta); flush()
    eq(UI.values.sg_Red_main_name,"多人丁将　年齢 23","closed Red can reopen on final chosen team")
    eq(UI.values.sg_Blue_main_name,"多人丙将　年齢 33","Red reopening preserves Blue final team")
    eq(assetURL("sgp_mp_alpha_main"),"https://example.invalid/mp-alpha.png","union assets retain Grey image")
    eq(assetURL("sgp_mp_gamma_main"),"https://example.invalid/mp-gamma.png","union assets retain Blue image")
    eq(assetURL("sgp_mp_delta_main"),"https://example.invalid/mp-delta.png","union assets retain Red image")
    local settledAssetCalls=UI.assetCalls
    tick()
    eq(UI.assetCalls,settledAssetCalls,"unchanged multiplayer views do not replace assets")
    eq(UI.xmlCalls,initializedXMLCalls,"multiplayer interactions do not rebuild XML")
    clickUI(Player.Blue,"sg_Blue_main_status")
    clickUI(Player.Red,"sg_Red_main_status")
    eq(mpGamma.description:find("status=浅手",1,true) ~= nil,true,"Blue post-load status targets final team")
    eq(mpDelta.description:find("status=浅手",1,true) ~= nil,true,"Red post-load status targets final team")
    eq(mpBeta.description,pendingBeta,"post-load status leaves old Blue team unchanged")
    -- 基礎統率の端点、未知値、旧名と新名の読取を独立した隊で検証。
    local edge=token("端点武将","team=edge_case\nrole=main\nname=端点武将\nbirth=1500\ncommand=1\nstatus=深手\nimage=-","edge01")
    onObjectSpawn(edge); flush(); onObjectHover("White",edge); tick()
    eq(UI.values.sg_White_main_command,"0","base one heavy injury has zero current command")
    eq(commandSlots("sg_White_main"),"X○○○○○","base one heavy injury crosses its only dot")
    clickUI(Player.White,"sg_White_main_status")
    eq(UI.values.sg_White_main_command,"X","base one terminal command is X")
    eq(edge.description:find("status=討死",1,true) ~= nil,true,"terminal click writes selected vocabulary")
    edge.description="team=edge_case\nrole=main\nname=端点武将\nstatus=討死\nimage=-"; tick()
    eq(UI.values.sg_White_main_command,"X","terminal unknown base command is still X")
    eq(commandSlots("sg_White_main"),"XXXXXX","terminal unknown base command crosses all dots")
    edge.description="team=edge_case\nrole=main\nname=端点武将\ncommand=6\nstatus=無傷\nimage=-"; tick()
    eq(UI.values.sg_White_main_command,"6","base six healthy command")
    eq(commandSlots("sg_White_main"),"●●●●●●","base six healthy full bar")
    edge.description=edge.description:gsub("status=無傷","status=浅手"); tick()
    eq(UI.values.sg_White_main_command,"6","new shallow injury alias preserves command")
    eq(UI.values.sg_White_main_status_text,"浅手","new shallow injury alias reads correctly")
    edge.description=edge.description:gsub("status=浅手","status=深手"); tick()
    eq(UI.values.sg_White_main_command,"5","base six deep injury command")
    eq(commandSlots("sg_White_main"),"●●●●●X","base six deep injury bar")
    edge.description=edge.description:gsub("status=深手","status=討死"); tick()
    eq(UI.values.sg_White_main_status_text,"討死","new terminal alias reads correctly")
    local edgeDuplicate=token("端点重複","team=edge_case\nrole=main","edge02")
    onObjectSpawn(edgeDuplicate); flush(); tick()
    eq(UI.values.sg_White_order,"現在命令：備大将配置重複","duplicate order diagnostic has no kana")
    onObjectDestroy(edgeDuplicate); objects.edge02=nil; flush(); tick()
    -- 背面印章直接附于令牌，保留既存贴花，不依赖面板曾否查看该队。
    local backCommander=token("背面将","team=back_case\nrole=main\nname=背面将\ncommand=3\nimage=-","back01")
    backCommander.description=backCommander.description:gsub("image=%-","image=https://example.invalid/nbsp.png ")
    backCommander.decals={copy(foreignDecal)}
    onObjectSpawn(backCommander); flush(); tick()
    local backStamp,backCount=managedStamp(backCommander)
    eq(backCount,1,"spawn attaches stamp without any hover")
    eq(backStamp.url,STAMP_URL,"spawn uses shared stamp URL")
    eq(backCommander.is_face_down,false,"spawn never flips token")
    near(backStamp.position[1] or backStamp.position.x,0,"default back stamp local X")
    near(backStamp.position[2] or backStamp.position.y,-0.001,"user calibrated back stamp GAP -0.099")
    near(backStamp.position[3] or backStamp.position.z,0,"default back stamp local Z")
    near(backStamp.rotation[1] or backStamp.rotation.x,270,"back stamp rotation faces underside")
    near(backStamp.scale[1] or backStamp.scale.x,2,"calibrated back stamp image width")
    near(backStamp.scale[2] or backStamp.scale.y,2,"calibrated back stamp image height")
    local backWrites,backScans=backCommander.decalWrites,scans
    for n=1,3 do tick() end
    eq(backCommander.decalWrites,backWrites,"unviewed settled commander has no repeated decal write")
    eq(scans,backScans,"decal polling has no whole-board scan")
    for n,role in ipairs({"deputy1","deputy2"}) do
        local deputy=token("背面副将"..n,"team=back_case\nrole="..role.."\nimage=-","backd"..n)
        onObjectSpawn(deputy); flush(); tick()
        eq(select(2,managedStamp(deputy)),1,"spawn attaches back stamp to "..role)
    end
    backCommander.bounds={size={x=8,y=0.6,z=6},offset={x=2,y=0.6,z=-1}}
    backCommander.scale={x=2,y=3,z=0.5}
    onObjectDrop("White",backCommander); flush(); tick()
    backStamp=managedStamp(backCommander)
    near(backStamp.position[1] or backStamp.position.x,1,"nonuniform offset local X")
    near(backStamp.position[2] or backStamp.position.y,0.199,"nonuniform offset local underside Y")
    near(backStamp.position[3] or backStamp.position.z,-2,"nonuniform offset local Z")
    near(backStamp.scale[1] or backStamp.scale.x,3,"nonuniform scale compensates token X")
    near(backStamp.scale[2] or backStamp.scale.y,12,"nonuniform scale compensates token Z")
    near(backStamp.scale[3] or backStamp.scale.z,0.1,"back stamp projection depth")
    backWrites=backCommander.decalWrites
    backCommander.is_face_down=true
    onObjectRotate(backCommander,0,180,"White",0,0); flush(); tick()
    eq(backCommander.decalWrites,backWrites,"nonuniform token flip preserves decal data")
    eq(backCommander.is_face_down,true,"nonuniform token stays face down")
    local fallbackCommander=token("范围将","team=bounds_fallback\nrole=main\nimage=-","backfb")
    fallbackCommander.getVisualBoundsNormalized=nil
    onObjectSpawn(fallbackCommander); flush(); tick()
    eq(select(2,managedStamp(fallbackCommander)),1,"missing visual bounds uses normalized bounds fallback")
    local loadingCommander=token("读图将","team=load_case\nrole=main\nimage=-","backld")
    loadingCommander.loading_custom=true
    onObjectSpawn(loadingCommander); flush(); tick()
    eq(loadingCommander.decalWrites,0,"custom loading defers back decal application")
    backScans=scans
    loadingCommander.loading_custom=false
    tick()
    eq(select(2,managedStamp(loadingCommander)),1,"pending custom loading applies decal when ready")
    eq(scans,backScans,"pending custom loading completion does not scan board")
    local spawningCommander=token("生成将","team=spawn_case\nrole=main\nimage=-","backsp")
    spawningCommander.spawning=true
    onObjectSpawn(spawningCommander); flush(); tick()
    eq(spawningCommander.decalWrites,0,"spawning defers back decal application")
    spawningCommander.spawning=false
    tick()
    eq(select(2,managedStamp(spawningCommander)),1,"pending spawning applies decal when ready")
    local deletedLoading=token("读图删除将","team=destroy_case\nrole=main\nimage=-","backrm")
    deletedLoading.loading_custom=true
    onObjectSpawn(deletedLoading); flush()
    onObjectDestroy(deletedLoading); objects.backrm=nil; flush(); tick()
    deletedLoading.loading_custom=false; tick()
    eq(deletedLoading.decalWrites,0,"destroyed pending commander is never stamped")
    backCommander.description=backCommander.description:gsub("role=main","role=unit")
    onObjectDrop("White",backCommander); flush(); tick()
    eq(select(2,managedStamp(backCommander)),0,"changing role to unit removes managed stamp")
    eq(#backCommander.decals,1,"changing role to unit retains foreign decal")
    eq(backCommander.decals[1].url,foreignDecal.url,"role change retains foreign decal content")
    backCommander.description=backCommander.description:gsub("role=unit","role=main")
    onObjectHover("White",backCommander); flush(); tick()
    eq(select(2,managedStamp(backCommander)),1,"hover repairs restored commander role")
    eq(UI.attributes.sg_White_main_portrait.image,"https://example.invalid/nbsp.png","trailing nonbreaking space is trimmed from pasted image URL")
    backCommander.decals={copy(foreignDecal)}
    local beforeRefreshReads=backCommander.decalReads
    sgRefresh(Player.White); flush(); tick()
    eq(select(2,managedStamp(backCommander)),1,"manual refresh repairs missing managed back stamp")
    eq(backCommander.decalReads > beforeRefreshReads,true,"manual refresh validates decal list")
    -- 陣旗只读備大将；任意队员选中仍显示同一旗，保持画像组合与旗整体居中。
    local flagURLA="https://example.invalid/flag-alpha.png?version=1&part=a=b"
    local flagURLB="https://example.invalid/flag-alpha-new.png"
    local flagBetaURL="https://example.invalid/flag-beta.png"
    local flagGammaURL="https://example.invalid/flag-gamma.png"
    local function alphaFlagDescription(value)
        local description="team=flag_alpha\nrole=main\nname=陣旗甲将\nbirth=1522\ncommand=5\nstatus=無傷\nimage=-\nformation=陣旗甲備"
        if value ~= nil then description=description.."\nflag_image="..value end
        return description
    end
    local flagAlpha=token("陣旗甲将",alphaFlagDescription(flagURLA),"flga01")
    local flagDeputy=token("陣旗甲副将","team=flag_alpha\nrole=deputy1\nname=陣旗甲副将\ncommand=2\nimage=-\nflag_image=https://example.invalid/deputy-ignored.png","flga02")
    local flagBeta=token("陣旗乙将","team=flag_beta\nrole=main\nname=陣旗乙将\ncommand=3\nimage=-\nflag_image="..flagBetaURL,"flgb01")
    local flagGamma=token("陣旗丙将","team=flag_gamma\nrole=main\nname=陣旗丙将\ncommand=4\nimage=-\nflag_image="..flagGammaURL,"flgc01")
    for _,object in ipairs({flagAlpha,flagDeputy,flagBeta,flagGamma}) do onObjectSpawn(object) end
    flush(); tick()
    onObjectHover("White",flagDeputy); flush(); tick()
    eq(UI.attributes.sg_White_flag.active,"true","deputy hover shows main commander flag")
    eq(UI.attributes.sg_White_flag.image,flagURLA,"main flag URL preserved including equals and ampersand")
    eq(assetURL("sgp_flag_alpha_flag"),flagURLA,"team flag registered once under team asset name")
    flagLayout("White",-55,"visible flag centers portrait plus flag")
    eq(UI.attributes.sg_White_flag.tooltip,"","flag has no tooltip")
    eq(UI.attributes.sg_White_flag.color,"#FFFFFF","flag uses original colors")
    local flagInteractWrites=UI.attributeWrites["sg_White_mapflags:interactable"]
    tick(); tick()
    eq(UI.attributeWrites["sg_White_mapflags:interactable"],flagInteractWrites,"visible flag does not toggle interactable false/true each poll")
    local queuedFrames=#frames
    for n=1,20 do onObjectDrop("White",flagAlpha) end
    eq(#frames,queuedFrames+1,"batch drop events schedule only one panel render")
    flush()
    eq(UI.attributes.sg_White_flag.active,"true","coalesced drop render preserves latest flag state")
    local sharedFlagAssets=0
    for _,asset in ipairs(UI.assets) do if asset.name == "sgp_flag_alpha_flag" then sharedFlagAssets=sharedFlagAssets+1 end end
    eq(sharedFlagAssets,1,"main and deputy views do not duplicate team flag asset")
    local flagLoads=UI.assetCalls
    flagAlpha.description=flagAlpha.description:gsub("flag_image=","陣旗=")
    tick()
    eq(UI.attributes.sg_White_flag.image,flagURLA,"Japanese flag field alias is supported")
    eq(UI.assetCalls,flagLoads,"alias with unchanged flag URL does not reload assets")
    clickUI(Player.White,"sg_White_main_status")
    clickUI(Player.White,"sg_White_main_status")
    clickUI(Player.White,"sg_White_main_status")
    eq(UI.values.sg_White_main_status_text,"討死","flag test reaches terminal commander state")
    eq(UI.attributes.sg_White_flag.color,"#FFFFFF","terminal commander does not darken team flag")
    eq(UI.attributes.sg_White_flag.image,flagURLA,"terminal commander retains original flag image")
    flagAlpha.is_face_down=true
    onObjectRotate(flagAlpha,0,180,"White",0,0); flush(); tick()
    eq(UI.attributes.sg_White_flag.color,"#FFFFFF","commander flip does not tint team flag")
    eq(UI.attributes.sg_White_flag.active,"true","commander flip does not hide team flag")
    flagAlpha.description=alphaFlagDescription(nil); tick()
    eq(UI.attributes.sg_White_flag.active,"false","missing main flag field hides flag despite deputy field")
    flagLayout("White",0,"missing flag recenters portrait")
    eq(assetURL("sgp_flag_alpha_flag"),nil,"missing flag removes unused team asset")
    eq(UI.values.sg_White_deputy1_name,"陣旗甲副将　年齢 —","flag change preserves deputy information")
    flagAlpha.description=alphaFlagDescription("-"); tick()
    eq(UI.attributes.sg_White_flag.active,"false","explicit dash hides flag")
    flagLayout("White",0,"dash flag recenters portrait")
    flagAlpha.description=alphaFlagDescription("not-a-url"); tick()
    eq(UI.attributes.sg_White_flag.active,"false","invalid URL hides flag")
    flagLayout("White",0,"invalid flag recenters portrait")
    eq(UI.attributes.sg_White_main_name.tooltip:find("陣旗URL確認",1,true) ~= nil,true,"invalid flag diagnostic belongs to commander name")
    noStatusTooltip("sg_White_main","invalid flag never adds status tooltip")
    flagAlpha.description=alphaFlagDescription(flagURLA); tick(); flush()
    local flagDuplicate=token("陣旗重複","team=flag_alpha\nrole=main\nflag_image="..flagURLB,"flgdup")
    onObjectSpawn(flagDuplicate); flush(); tick()
    eq(UI.attributes.sg_White_flag.active,"false","duplicate main commander hides ambiguous flag")
    flagLayout("White",0,"duplicate main commander recenters portrait")
    onObjectDestroy(flagDuplicate); objects.flgdup=nil; flush(); tick()
    eq(UI.attributes.sg_White_flag.active,"true","duplicate removal restores original flag")
    eq(UI.attributes.sg_White_flag.image,flagURLA,"duplicate removal chooses existing main commander flag")
    onObjectDestroy(flagAlpha); objects.flga01=nil; flush(); tick()
    eq(UI.attributes.sg_White_flag.active,"false","missing commander hides flag while deputy remains")
    flagLayout("White",0,"missing commander recenters portrait")
    objects.flga01=flagAlpha; onObjectSpawn(flagAlpha); flush(); tick()
    onObjectHover("Red",flagAlpha); onObjectHover("Blue",flagBeta); flush(); tick()
    eq(UI.attributes.sg_Red_flag.image,flagURLA,"Red has independently selected alpha flag")
    eq(UI.attributes.sg_Blue_flag.image,flagBetaURL,"Blue independently selects beta flag")
    flagAlpha.description=alphaFlagDescription(flagURLB); tick(); flush()
    eq(UI.attributes.sg_White_flag.image,flagURLB,"same-team White updates changed flag URL")
    eq(UI.attributes.sg_Red_flag.image,flagURLB,"same-team Red updates changed flag URL")
    eq(UI.attributes.sg_Blue_flag.image,flagBetaURL,"alpha flag change preserves different-team Blue flag")
    UI.holdAssets=true
    flagAlpha.description=alphaFlagDescription(flagURLA); tick()
    eq(UI.loading,true,"flag replacement waits for custom asset load")
    flagAlpha.description=alphaFlagDescription(flagURLB); tick()
    flagAlpha.description=alphaFlagDescription("-"); tick()
    UI.loading=false; UI.holdAssets=false; flush(); tick()
    eq(UI.attributes.sg_White_flag.active,"false","flag load completion respects latest dash selection")
    eq(UI.attributes.sg_Red_flag.active,"false","latest dash updates all same-team viewers")
    flagLayout("White",0,"pending dash recenters White portrait")
    flagLayout("Red",0,"pending dash recenters Red portrait")
    eq(UI.attributes.sg_Blue_flag.image,flagBetaURL,"pending alpha changes preserve Blue beta flag")
    UI.holdAssets=true
    flagAlpha.description=alphaFlagDescription(flagURLA); tick()
    eq(UI.loading,true,"second flag replacement is pending")
    onObjectHover("White",flagGamma)
    flagAlpha.description=alphaFlagDescription(flagURLB); tick()
    clickUI(Player.Red,"sg_Red_close")
    UI.loading=false; UI.holdAssets=false; flush(); tick()
    eq(UI.attributes.sg_White_flag.image,flagGammaURL,"pending completion uses final White team flag")
    eq(UI.values.sg_White_main_name,"陣旗丙将　年齢 —","pending completion keeps final White team")
    eq(UI.attributes.sg_Red_panel.active,"false","flag load completion never reopens closed Red panel")
    eq(UI.attributes.sg_Blue_flag.image,flagBetaURL,"selection change leaves Blue flag untouched")
    onObjectHover("Red",flagAlpha); flush(); tick()
    eq(UI.attributes.sg_Red_flag.image,flagURLB,"reopening uses latest alpha flag URL")
    eq(UI.attributes.sg_White_flag.image,flagGammaURL,"Red reopening preserves White gamma flag")
    eq(assetURL("sgp_flag_gamma_flag"),flagGammaURL,"union assets include independently viewed gamma flag")
    eq(assetURL("sgp_flag_beta_flag"),flagBetaURL,"union assets retain independently viewed beta flag")
    eq(assetURL("sgp_flag_alpha_flag"),flagURLB,"union assets include final alpha flag URL")
    flagLoads=UI.assetCalls
    for n=1,3 do tick() end
    eq(UI.assetCalls,flagLoads,"steady flags do not reload shared custom assets")
    -- 逐队查看制造资源压力；可见座席与共用/外来资源必须保留，旧不可见队可淘汰。
    local stressTokens={}
    for n=1,40 do
        local team="lru_"..n
        local portraitURL="https://example.invalid/lru-portrait-"..n..".png"
        local flagURL="https://example.invalid/lru-flag-"..n..".png"
        stressTokens[n]=token("資源将"..n,"team="..team.."\nrole=main\nname=資源将"..n.."\ncommand=3\nimage="..portraitURL.."\nflag_image="..flagURL,"lru"..string.format("%03d",n))
        onObjectSpawn(stressTokens[n]); flush()
        onObjectHover("Purple",stressTokens[n]); flush(); tick()
        eq(UI.attributes.sg_Purple_main_portrait.image,portraitURL,"LRU portrait loads for team "..n)
        eq(UI.attributes.sg_Purple_flag.image,flagURL,"LRU flag loads for team "..n)
    end
    local ownedResources=0
    for _,asset in ipairs(UI.assets) do if asset.name:sub(1,4) == "sgp_" then ownedResources=ownedResources+1 end end
    eq(ownedResources <= 64,true,"registered panel assets stay within LRU capacity")
    eq(assetURL("sgp_lru_1_main"),nil,"LRU evicts oldest invisible portrait")
    eq(assetURL("sgp_lru_1_flag"),nil,"LRU evicts oldest invisible flag")
    eq(assetURL("sgp_lru_40_main"),"https://example.invalid/lru-portrait-40.png","LRU retains current Purple portrait")
    eq(assetURL("sgp_lru_40_flag"),"https://example.invalid/lru-flag-40.png","LRU retains current Purple flag")
    eq(assetURL("sgp_flag_gamma_flag"),flagGammaURL,"LRU retains visible White flag")
    eq(assetURL("sgp_flag_alpha_flag"),flagURLB,"LRU retains visible Red flag")
    eq(assetURL("sgp_flag_beta_flag"),flagBetaURL,"LRU retains visible Blue flag")
    eq(assetURL("sgp_common_acted"),STAMP_URL,"LRU retains shared action stamp")
    eq(assetURL("other"),"https://example.invalid/other.png","LRU retains foreign UI asset")
    onObjectHover("Purple",stressTokens[1]); flush(); tick()
    eq(UI.attributes.sg_Purple_main_portrait.image,"https://example.invalid/lru-portrait-1.png","revisiting evicted team restores portrait")
    eq(UI.attributes.sg_Purple_flag.image,"https://example.invalid/lru-flag-1.png","revisiting evicted team restores flag")
    eq(assetURL("sgp_lru_1_main"),"https://example.invalid/lru-portrait-1.png","revisited portrait reenters registered assets")
    eq(assetURL("sgp_lru_1_flag"),"https://example.invalid/lru-flag-1.png","revisited flag reenters registered assets")
    local stressReads,stressBounds=stressTokens[1].decalReads,stressTokens[1].boundsReads
    flagLoads=UI.assetCalls
    for n=1,3 do tick() end
    eq(stressTokens[1].decalReads,stressReads,"settled stress view skips decal reads")
    eq(stressTokens[1].boundsReads,stressBounds,"settled stress view skips bounds reads")
    eq(UI.assetCalls,flagLoads,"settled LRU does not reload assets")
    runMapFlagChecks(roster)
    local beforeReloadWrites=backCommander.decalWrites
    onLoad(""); flush(); tick()
    eq(select(2,managedStamp(backCommander)),1,"reload never adds a duplicate managed back stamp")
    eq(backCommander.decalWrites,beforeReloadWrites,"reload avoids rewriting identical back stamp parameters")
    eq(backCommander.is_face_down,true,"reload preserves token face-down state")
    if merged then
        eq(#unit.buttons,6,"right rail buttons")
        for n=1,10 do changeFrontValue(unit,"White",false); changeBackValue(unit,"White",false) end
        eq(unit_state.unit01.front_value,6,"front morale limit")
        eq(unit_state.unit01.back_value,5,"back morale limit")
        toggleDefeatText(unit); eq(unit.buttons[3].label,"敗走","defeat label")
        local saved=onSave(); unit_state={}; onLoad(saved); flush(); tick()
        eq(unit_state.unit01.front_value,6,"morale reload")
        eq(unit_state.unit01.manual_defeat_visible,true,"defeat flag reload")
        numberImage(unit,"FRONT","MORALE",6,"counter display reload")
        numberImage(unit,"FRONT","COUNT",2,"count label in hundreds")
        -- 旧或异常存档只能影响计数默认值，不应阻断Global和面板初始化。
        local normalDecode=JSON.decode
        local function loadFixture(decoded,throws)
            JSON.decode=function()
                if throws then error("Malformed saved JSON") end
                return copy(decoded)
            end
            unit_state={unit01={front_value=6,back_value=5,manual_defeat_visible=true}}
            onLoad("fixture"); flush(); tick()
        end
        local function defaultUnit(message,existingTable)
            eq(type(unit_state.unit01),"table",message.." state is table")
            eq(unit_state.unit01.front_value,existingTable and 0 or 6,message.." front default distinguishes missing record from invalid field")
            eq(unit_state.unit01.back_value,existingTable and 0 or 5,message.." back default distinguishes missing record from invalid field")
            eq(unit_state.unit01.acted,false,message.." action defaults to false")
            eq(unit_state.unit01.manual_defeat_visible,false,message.." defeat defaults to false")
            eq(#unit.buttons,6,message.." right rail buttons remain available")
        end
        loadFixture(nil,true); defaultUnit("malformed JSON")
        loadFixture(17,false); defaultUnit("numeric decoded JSON")
        loadFixture({unit_state=17},false); defaultUnit("numeric unit_state field")
        loadFixture({unit_state={unit01="corrupt entry"}},false); defaultUnit("non-table unit entry")
        loadFixture({unit_state={unit01={front_value="5.9",back_value="4.2",manual_defeat_visible=true}}},false)
        eq(unit_state.unit01.front_value,5,"numeric-string front is accepted and floored")
        eq(unit_state.unit01.back_value,4,"numeric-string back is accepted and floored")
        eq(unit_state.unit01.manual_defeat_visible,true,"boolean true defeat flag is retained")
        numberImage(unit,"FRONT","MORALE",5,"normalized numeric-string front reaches counter")
        numberImage(unit,"BACK","MORALE",4,"normalized numeric-string back reaches counter")
        loadFixture({unit_state={unit01={front_value="bad",back_value={},manual_defeat_visible="true"}}},false)
        defaultUnit("invalid fields and string boolean",true)
        loadFixture({unit_state={unit01={front_value=99,back_value=-7,manual_defeat_visible=1}}},false)
        eq(unit_state.unit01.front_value,6,"overflow front is clamped to its side maximum")
        eq(unit_state.unit01.back_value,0,"negative back is clamped to minimum")
        eq(unit_state.unit01.manual_defeat_visible,false,"numeric defeat flag is false")
        loadFixture({unit_state={unit01={front_value=math.huge,back_value=-math.huge,manual_defeat_visible=false}}},false)
        defaultUnit("infinite counters",true)
        loadFixture({unit_state={unit01={front_value=0/0,back_value=true,manual_defeat_visible=false}}},false)
        defaultUnit("NaN and boolean counters",true)
        unit_state.unit01="corrupt live entry"
        changeFrontValue(unit,"White",false)
        eq(unit_state.unit01.front_value,6,"counter callback restores missing live record at full morale")
        eq(unit_state.unit01.back_value,5,"counter callback restores missing opposite side at full morale")
        unit_state.unit01={front_value="3.8",back_value="9.1",manual_defeat_visible=true}
        changeBackValue(unit,"White",true)
        eq(unit_state.unit01.front_value,3,"callback floors numeric-string opposite side")
        eq(unit_state.unit01.back_value,4,"callback clamps then decrements edited side")
        eq(unit_state.unit01.manual_defeat_visible,true,"callback retains valid defeat flag")
        JSON.decode=normalDecode
        local normalizedSave=onSave()
        unit_state={}; onLoad(normalizedSave); flush(); tick()
        eq(unit_state.unit01.front_value,3,"normalized state survives save and reload")
        eq(unit_state.unit01.back_value,4,"normalized back state survives save and reload")
        eq(unit_state.unit01.manual_defeat_visible,true,"normalized defeat flag survives save and reload")
        onLoad(22); flush(); tick()
        defaultUnit("non-string onLoad input")
        runUnitLayoutChecks()
        runUnitDefeatImageChecks()
        runUnitProgressionChecks()
        runUnitBackUIChecks()
        runUnitPreloadChecks()
        runUnitMoraleBandChecks()
        runUnitMoraleQuickChecks()
        runUnitStatusChecks()
        runUnitModeChecks()
    end
    UNIT_DEFEAT_IMAGE_URL=configuredDefeatURL
    UNIT_NUMBER_IMAGES=configuredNumberImages
    UNIT_NUMBER_BACK_IMAGES,UNIT_BACK_RAIL_IMAGE_URL,UNIT_ACTION_IMAGES=configuredBackImages,configuredRail,configuredActions
    UNIT_MORALE_BAND_IMAGES=configuredMoraleBands
    UNIT_STATUS_IMAGES=configuredStatusImages
    UNIT_MODE_IMAGES=configuredModeImages
    return tostring(checks).." behavior checks passed (network and live TTS rendering not tested)"
end
