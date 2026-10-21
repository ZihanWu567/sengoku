-- 備隊武将面板 v2.15.0：交戦・指揮外手動標記対応
-- 更新日：2026-10-21
-- 画像・生年・統率は各武将令牌の Description に入力可能。
-- team=ota_honjin / role=main,deputy1,deputy2 / name=太田資正
-- birth=1522 / command=5 / image=https://... / status=無傷
-- 主将に formation=太田家 本陣 / order=防御 / flag_image=陣旗URL を設定。
-- 普通部队添加所属标签 ota_honjin / iwatsuke_shu / edo_shu / matsuyama_shu 即可。
-- 自编队标签 sg_team_<team ID>；仍兼容 Description 的 team / role=unit。
-- 全武将统一使用下方行動印URL，不必逐枚填写 acted_image。
-- 詳細・12名のテンプレート：令牌資料填写指南.md
-- このファイルは Global UI を置換する。既存の兵種スクリプトには合并版を使用。
local CURRENT_YEAR = 1563
local ACTED_IMAGE_URL = "https://steamusercontent-a.akamaihd.net/ugc/16127482967476073358/AB4E3857AE6ECD0830ECE8C32682AE244709D8B5/"
-- 背面貼花：一般平面令牌取局部 -Y 面；旋转是依据官方地面例子反向推算，须在 TTS 内确认。
local BACK_STAMP_NAME = "SG_済_背面"
local BACK_STAMP_RATIO = 1 -- 印章直径占令牌较短一边的比例；当前令牌实测值
local BACK_STAMP_GAP = -0.099 -- 背面貼花局部偏移；2026-10-13 用户实测值
local BACK_STAMP_ROTATION = {270, 0, 0}

-- 初期資料。Description の有効な入力値を優先する。
local FORMATIONS = {
    ["ota_honjin"] = {
        title = "太田家 本陣",
        main = {
            tokenName = "太田資正",
            roleLabel = "備大将",
            name = "太田資正",
            birthYear = 1522,
            command = 5,
            image = "", -- 完全な Cloud URL を貼付
            defaultStatus = "健康"
        },
        deputies = {
            {
                tokenName = "三戸興義",
                roleLabel = "副将",
                name = "三戸興義",
                birthYear = 1525,
                command = 2,
                image = "",
                defaultStatus = "健康"
            },
            {
                tokenName = "太田御前",
                roleLabel = "副将",
                name = "太田御前",
                birthYear = 1544,
                command = 2,
                image = "",
                defaultStatus = "健康"
            }
        }
    },
    ["iwatsuke_shu"] = {
        title = "太田家 岩付衆",
        main = {
            tokenName = "太田資房",
            roleLabel = "備大将",
            name = "太田資房",
            birthYear = 1542,
            command = 2,
            image = "",
            defaultStatus = "健康"
        },
        deputies = {
            {
                tokenName = "小宮山忠孝",
                roleLabel = "副将",
                name = "小宮山忠孝",
                birthYear = 1533,
                command = 2,
                image = "",
                defaultStatus = "健康"
            },
            {
                tokenName = "高築道叶",
                roleLabel = "副将",
                name = "高築道叶",
                birthYear = 1523,
                command = 2,
                image = "",
                defaultStatus = "健康"
            }
        }
    },
    ["edo_shu"] = {
        title = "太田家 江戸衆",
        main = {
            tokenName = "太田康資",
            roleLabel = "備大将",
            name = "太田康資",
            birthYear = 1531,
            command = 3,
            image = "",
            defaultStatus = "健康"
        },
        deputies = {
            {
                tokenName = "宮城政業",
                roleLabel = "副将",
                name = "宮城政業",
                birthYear = 1495,
                command = 2,
                image = "",
                defaultStatus = "健康"
            },
            {
                tokenName = "舎人重長",
                roleLabel = "副将",
                name = "舎人重長",
                birthYear = 1532,
                command = 2,
                image = "",
                defaultStatus = "健康"
            }
        }
    },
    ["matsuyama_shu"] = {
        title = "太田家 松山衆",
        main = {
            tokenName = "梶原政景",
            roleLabel = "備大将",
            name = "梶原政景",
            birthYear = 1548,
            command = 4,
            image = "",
            defaultStatus = "健康"
        },
        deputies = {
            {
                tokenName = "広沢信秀",
                roleLabel = "副将",
                name = "広沢信秀",
                birthYear = 1543,
                command = 2,
                image = "",
                defaultStatus = "健康"
            },
            {
                tokenName = "比企政員",
                roleLabel = "副将",
                name = "比企政員",
                birthYear = 1538,
                command = 2,
                image = "",
                defaultStatus = "健康"
            }
        }
    }
}

-- 主将画像 260、副将画像 200。副将は左右並列。
local PANEL_XML = [=[
<Panel id="sg_panel" visibility="PLAYER_COLOR" active="true" rectAlignment="MiddleRight" offsetXY="-20 0" width="600" height="1000" scale="1 1 1" color="#1B211DF8" raycastTarget="true">
    <Text id="sg_formation" rectAlignment="UpperCenter" offsetXY="0 -10" width="558" height="36" fontSize="26" color="#E4D3A3" raycastTarget="false" >請指向武將令牌</Text>
<Panel id="sg_main_card" rectAlignment="UpperCenter" offsetXY="0 -62" width="568" height="438" color="#292D28" raycastTarget="true">
    <Text id="sg_main_role" rectAlignment="UpperCenter" offsetXY="0 -8" width="266" height="24" fontSize="16" color="#C5AD75" raycastTarget="false" resizeTextForBestFit="true" resizeTextMinSize="12" resizeTextMaxSize="16">備大将</Text>
    <Panel id="sg_main_visual_group" rectAlignment="UpperCenter" offsetXY="0 -37" width="266" height="266" color="#FFFFFF00" raycastTarget="false">
        <Panel id="sg_main_portrait_frame" rectAlignment="UpperCenter" offsetXY="0 0" width="266" height="266" color="#5E604F" raycastTarget="false" />
        <Panel rectAlignment="UpperCenter" offsetXY="0 -3" width="260" height="260" color="#1C211D" raycastTarget="false" />
        <Text id="sg_main_no_image" rectAlignment="UpperCenter" offsetXY="0 -3" width="260" height="260" fontSize="16" color="#8D9688" raycastTarget="false" >画像未登録</Text>
        <Image id="sg_main_portrait" active="false" rectAlignment="UpperCenter" offsetXY="0 -3" width="260" height="260" preserveAspect="true" raycastTarget="false" />
        <!-- 独立层：画像の暗色化は行動印・負傷表示に影響しない。 -->
        <Image id="sg_main_acted_stamp" active="false" rectAlignment="UpperCenter" offsetXY="70 -147" width="112" height="112" preserveAspect="true" color="#FFFFFFE6" raycastTarget="false" />
        <Text id="sg_main_acted_fallback" active="false" rectAlignment="UpperCenter" offsetXY="70 -147" width="112" height="112" fontSize="64" fontStyle="Bold" color="#E43B36DF" raycastTarget="false">済</Text>
        <Panel id="sg_main_injury_badge" active="false" rectAlignment="UpperCenter" offsetXY="-86 -9" width="72" height="28" color="#6F2432" raycastTarget="false">
            <Text id="sg_main_injury_label" fontSize="17" color="#FFFFFF" raycastTarget="false">深手</Text>
        </Panel>
    </Panel>
    <Image id="sg_flag" active="false" rectAlignment="UpperCenter" offsetXY="140 -50" width="90" height="240" preserveAspect="true" color="#FFFFFF" raycastTarget="false" />
    <Text id="sg_main_name" rectAlignment="UpperCenter" offsetXY="0 -308" width="548" height="38" fontSize="26" color="#F2EAD9" raycastTarget="true" resizeTextForBestFit="true" resizeTextMinSize="20" resizeTextMaxSize="26">姓名　年齢 —</Text>
    <Panel id="sg_main_command_row" rectAlignment="UpperCenter" offsetXY="0 -353" width="276" height="40" color="#FFFFFF00" raycastTarget="false">
        <Text id="sg_main_command_label" rectAlignment="MiddleCenter" offsetXY="-118 0" width="40" height="36" fontSize="16" alignment="MiddleCenter" color="#BDBAA9" raycastTarget="false">統率</Text>
        <Panel id="sg_main_command_box" rectAlignment="MiddleCenter" offsetXY="-67 0" width="38" height="36" color="#20271F" raycastTarget="false" />
        <Text id="sg_main_command" rectAlignment="MiddleCenter" offsetXY="-67 0" width="38" height="36" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false" fontStyle="Bold">—</Text>
        <Panel id="sg_main_command_bar" rectAlignment="MiddleCenter" offsetXY="54 0" width="168" height="40" color="#FFFFFF00" raycastTarget="false">
            <Text id="sg_main_command_slot1" rectAlignment="MiddleCenter" offsetXY="-70 2" width="28" height="36" fontSize="30" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_main_command_slot2" rectAlignment="MiddleCenter" offsetXY="-42 2" width="28" height="36" fontSize="30" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_main_command_slot3" rectAlignment="MiddleCenter" offsetXY="-14 2" width="28" height="36" fontSize="30" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_main_command_slot4" rectAlignment="MiddleCenter" offsetXY="14 2" width="28" height="36" fontSize="30" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_main_command_slot5" rectAlignment="MiddleCenter" offsetXY="42 2" width="28" height="36" fontSize="30" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_main_command_slot6" rectAlignment="MiddleCenter" offsetXY="70 2" width="28" height="36" fontSize="30" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
        </Panel>
    </Panel>
    <Text id="sg_main_mobility" rectAlignment="UpperCenter" offsetXY="-171 -394" width="148" height="26" fontSize="18" color="#ECE6D8" raycastTarget="false" >機動 —</Text>
    <Text id="sg_main_status_label" rectAlignment="UpperCenter" offsetXY="-45 -394" width="52" height="30" fontSize="18" color="#BDBAA9" raycastTarget="false">状態</Text>
    <Button id="sg_main_status" rectAlignment="UpperCenter" offsetXY="28 -394" width="86" height="30" onClick="sgSetStatus" raycastTarget="true" text="" colors="#3C684D|#548363|#2A4937|#30362D" />
    <Text id="sg_main_status_text" rectAlignment="UpperCenter" offsetXY="28 -394" width="86" height="30" fontSize="18" color="#86C48B" raycastTarget="false">無傷</Text>
    <Text id="sg_main_action" rectAlignment="UpperCenter" offsetXY="171 -394" width="148" height="26" fontSize="18" color="#C9C6BA" raycastTarget="false" >行動 未</Text>
</Panel>
<Panel id="sg_deputy1_card" rectAlignment="UpperCenter" offsetXY="-146 -514" width="280" height="352" color="#292D28" raycastTarget="true">
    <Text id="sg_deputy1_role" rectAlignment="UpperCenter" offsetXY="0 -8" width="260" height="24" fontSize="15" color="#C5AD75" raycastTarget="false" >副将</Text>
    <Panel id="sg_deputy1_portrait_frame" rectAlignment="UpperCenter" offsetXY="0 -35" width="206" height="206" color="#5E604F" raycastTarget="false" />
    <Panel rectAlignment="UpperCenter" offsetXY="0 -38" width="200" height="200" color="#1C211D" raycastTarget="false" />
    <Text id="sg_deputy1_no_image" rectAlignment="UpperCenter" offsetXY="0 -38" width="200" height="200" fontSize="16" color="#8D9688" raycastTarget="false" >画像未登録</Text>
    <Image id="sg_deputy1_portrait" active="false" rectAlignment="UpperCenter" offsetXY="0 -38" width="200" height="200" preserveAspect="true" raycastTarget="false" />
    <!-- 独立层：画像の暗色化は行動印・負傷表示に影響しない。 -->
    <Image id="sg_deputy1_acted_stamp" active="false" rectAlignment="UpperCenter" offsetXY="54 -148" width="86" height="86" preserveAspect="true" color="#FFFFFFE6" raycastTarget="false" />
    <Text id="sg_deputy1_acted_fallback" active="false" rectAlignment="UpperCenter" offsetXY="54 -148" width="86" height="86" fontSize="50" fontStyle="Bold" color="#E43B36DF" raycastTarget="false">済</Text>
    <Panel id="sg_deputy1_injury_badge" active="false" rectAlignment="UpperCenter" offsetXY="-61 -44" width="66" height="24" color="#6F2432" raycastTarget="false">
        <Text id="sg_deputy1_injury_label" fontSize="15" color="#FFFFFF" raycastTarget="false">深手</Text>
    </Panel>
    <Text id="sg_deputy1_name" rectAlignment="UpperCenter" offsetXY="0 -246" width="260" height="30" fontSize="20" color="#F2EAD9" raycastTarget="true" resizeTextForBestFit="true" resizeTextMinSize="16" resizeTextMaxSize="20">姓名　年齢 —</Text>
    <Panel id="sg_deputy1_command_row" rectAlignment="UpperCenter" offsetXY="0 -281" width="235" height="38" color="#FFFFFF00" raycastTarget="false">
        <Text id="sg_deputy1_command_label" rectAlignment="MiddleCenter" offsetXY="-96.5 0" width="42" height="34" fontSize="16" alignment="MiddleCenter" color="#BDBAA9" raycastTarget="false">統率</Text>
        <Panel id="sg_deputy1_command_box" rectAlignment="MiddleCenter" offsetXY="-53.5 0" width="30" height="34" color="#20271F" raycastTarget="false" />
        <Text id="sg_deputy1_command" rectAlignment="MiddleCenter" offsetXY="-53.5 0" width="30" height="34" fontSize="22" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false" fontStyle="Bold">—</Text>
        <Panel id="sg_deputy1_command_bar" rectAlignment="MiddleCenter" offsetXY="45.5 0" width="144" height="38" color="#FFFFFF00" raycastTarget="false">
            <Text id="sg_deputy1_command_slot1" rectAlignment="MiddleCenter" offsetXY="-60 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_deputy1_command_slot2" rectAlignment="MiddleCenter" offsetXY="-36 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_deputy1_command_slot3" rectAlignment="MiddleCenter" offsetXY="-12 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_deputy1_command_slot4" rectAlignment="MiddleCenter" offsetXY="12 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_deputy1_command_slot5" rectAlignment="MiddleCenter" offsetXY="36 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_deputy1_command_slot6" rectAlignment="MiddleCenter" offsetXY="60 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
        </Panel>
    </Panel>
    <Text id="sg_deputy1_mobility" rectAlignment="UpperCenter" offsetXY="-88 -322" width="80" height="26" fontSize="14" color="#ECE6D8" raycastTarget="false" >機動 —</Text>
    <Text id="sg_deputy1_status_label" rectAlignment="UpperCenter" offsetXY="-25 -322" width="34" height="28" fontSize="14" color="#BDBAA9" raycastTarget="false">状態</Text>
    <Button id="sg_deputy1_status" rectAlignment="UpperCenter" offsetXY="20 -322" width="50" height="28" onClick="sgSetStatus" raycastTarget="true" text="" colors="#3C684D|#548363|#2A4937|#30362D" />
    <Text id="sg_deputy1_status_text" rectAlignment="UpperCenter" offsetXY="20 -322" width="50" height="28" fontSize="14" resizeTextForBestFit="true" resizeTextMinSize="10" resizeTextMaxSize="14" color="#86C48B" raycastTarget="false">無傷</Text>
    <Text id="sg_deputy1_action" rectAlignment="UpperCenter" offsetXY="88 -322" width="80" height="26" fontSize="14" color="#C9C6BA" raycastTarget="false" >行動 未</Text>
</Panel>
<Panel id="sg_deputy2_card" rectAlignment="UpperCenter" offsetXY="146 -514" width="280" height="352" color="#292D28" raycastTarget="true">
    <Text id="sg_deputy2_role" rectAlignment="UpperCenter" offsetXY="0 -8" width="260" height="24" fontSize="15" color="#C5AD75" raycastTarget="false" >副将</Text>
    <Panel id="sg_deputy2_portrait_frame" rectAlignment="UpperCenter" offsetXY="0 -35" width="206" height="206" color="#5E604F" raycastTarget="false" />
    <Panel rectAlignment="UpperCenter" offsetXY="0 -38" width="200" height="200" color="#1C211D" raycastTarget="false" />
    <Text id="sg_deputy2_no_image" rectAlignment="UpperCenter" offsetXY="0 -38" width="200" height="200" fontSize="16" color="#8D9688" raycastTarget="false" >画像未登録</Text>
    <Image id="sg_deputy2_portrait" active="false" rectAlignment="UpperCenter" offsetXY="0 -38" width="200" height="200" preserveAspect="true" raycastTarget="false" />
    <!-- 独立层：画像の暗色化は行動印・負傷表示に影響しない。 -->
    <Image id="sg_deputy2_acted_stamp" active="false" rectAlignment="UpperCenter" offsetXY="54 -148" width="86" height="86" preserveAspect="true" color="#FFFFFFE6" raycastTarget="false" />
    <Text id="sg_deputy2_acted_fallback" active="false" rectAlignment="UpperCenter" offsetXY="54 -148" width="86" height="86" fontSize="50" fontStyle="Bold" color="#E43B36DF" raycastTarget="false">済</Text>
    <Panel id="sg_deputy2_injury_badge" active="false" rectAlignment="UpperCenter" offsetXY="-61 -44" width="66" height="24" color="#6F2432" raycastTarget="false">
        <Text id="sg_deputy2_injury_label" fontSize="15" color="#FFFFFF" raycastTarget="false">深手</Text>
    </Panel>
    <Text id="sg_deputy2_name" rectAlignment="UpperCenter" offsetXY="0 -246" width="260" height="30" fontSize="20" color="#F2EAD9" raycastTarget="true" resizeTextForBestFit="true" resizeTextMinSize="16" resizeTextMaxSize="20">姓名　年齢 —</Text>
    <Panel id="sg_deputy2_command_row" rectAlignment="UpperCenter" offsetXY="0 -281" width="235" height="38" color="#FFFFFF00" raycastTarget="false">
        <Text id="sg_deputy2_command_label" rectAlignment="MiddleCenter" offsetXY="-96.5 0" width="42" height="34" fontSize="16" alignment="MiddleCenter" color="#BDBAA9" raycastTarget="false">統率</Text>
        <Panel id="sg_deputy2_command_box" rectAlignment="MiddleCenter" offsetXY="-53.5 0" width="30" height="34" color="#20271F" raycastTarget="false" />
        <Text id="sg_deputy2_command" rectAlignment="MiddleCenter" offsetXY="-53.5 0" width="30" height="34" fontSize="22" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false" fontStyle="Bold">—</Text>
        <Panel id="sg_deputy2_command_bar" rectAlignment="MiddleCenter" offsetXY="45.5 0" width="144" height="38" color="#FFFFFF00" raycastTarget="false">
            <Text id="sg_deputy2_command_slot1" rectAlignment="MiddleCenter" offsetXY="-60 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_deputy2_command_slot2" rectAlignment="MiddleCenter" offsetXY="-36 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_deputy2_command_slot3" rectAlignment="MiddleCenter" offsetXY="-12 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_deputy2_command_slot4" rectAlignment="MiddleCenter" offsetXY="12 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_deputy2_command_slot5" rectAlignment="MiddleCenter" offsetXY="36 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
            <Text id="sg_deputy2_command_slot6" rectAlignment="MiddleCenter" offsetXY="60 1" width="24" height="34" fontSize="24" alignment="MiddleCenter" color="#82C6B0" raycastTarget="false">○</Text>
        </Panel>
    </Panel>
    <Text id="sg_deputy2_mobility" rectAlignment="UpperCenter" offsetXY="-88 -322" width="80" height="26" fontSize="14" color="#ECE6D8" raycastTarget="false" >機動 —</Text>
    <Text id="sg_deputy2_status_label" rectAlignment="UpperCenter" offsetXY="-25 -322" width="34" height="28" fontSize="14" color="#BDBAA9" raycastTarget="false">状態</Text>
    <Button id="sg_deputy2_status" rectAlignment="UpperCenter" offsetXY="20 -322" width="50" height="28" onClick="sgSetStatus" raycastTarget="true" text="" colors="#3C684D|#548363|#2A4937|#30362D" />
    <Text id="sg_deputy2_status_text" rectAlignment="UpperCenter" offsetXY="20 -322" width="50" height="28" fontSize="14" resizeTextForBestFit="true" resizeTextMinSize="10" resizeTextMaxSize="14" color="#86C48B" raycastTarget="false">無傷</Text>
    <Text id="sg_deputy2_action" rectAlignment="UpperCenter" offsetXY="88 -322" width="80" height="26" fontSize="14" color="#C9C6BA" raycastTarget="false" >行動 未</Text>
</Panel>
    <Text id="sg_order" rectAlignment="UpperCenter" offsetXY="0 -875" width="560" height="28" fontSize="19" color="#DEC78E" raycastTarget="false" >現在命令：—</Text>
<Button id="sg_attack" rectAlignment="UpperCenter" offsetXY="-180 -909" width="108" height="30" fontSize="15" onClick="sgSetOrder" colors="#424D3E|#657059|#2C352A|#30362D" textColor="#EAE2CC">攻撃</Button>
<Button id="sg_defend" rectAlignment="UpperCenter" offsetXY="-60 -909" width="108" height="30" fontSize="15" onClick="sgSetOrder" colors="#424D3E|#657059|#2C352A|#30362D" textColor="#EAE2CC">防御</Button>
<Button id="sg_move" rectAlignment="UpperCenter" offsetXY="60 -909" width="108" height="30" fontSize="15" onClick="sgSetOrder" colors="#424D3E|#657059|#2C352A|#30362D" textColor="#EAE2CC">機動</Button>
<Button id="sg_regroup" rectAlignment="UpperCenter" offsetXY="180 -909" width="108" height="30" fontSize="15" onClick="sgSetOrder" colors="#424D3E|#657059|#2C352A|#30362D" textColor="#EAE2CC">再編</Button>
<Button id="sg_mapflags" rectAlignment="UpperCenter" offsetXY="-220 -952" width="132" height="30" fontSize="14" onClick="sgToggleMapFlags" interactable="false" colors="#424D3E|#657059|#2C352A|#30362D" textColor="#EAE2CC">本隊陣旗：無</Button>
<Button id="sg_pin" rectAlignment="UpperCenter" offsetXY="-107 -952" width="82" height="30" fontSize="15" onClick="sgPin" colors="#424D3E|#657059|#2C352A|#30362D" textColor="#EAE2CC">固定：無</Button>
<Button id="sg_refresh" rectAlignment="UpperCenter" offsetXY="-19 -952" width="82" height="30" fontSize="15" onClick="sgRefresh" colors="#424D3E|#657059|#2C352A|#30362D" textColor="#EAE2CC">更新</Button>
<Button id="sg_smaller" rectAlignment="UpperCenter" offsetXY="69 -952" width="82" height="30" fontSize="15" onClick="sgResize" colors="#424D3E|#657059|#2C352A|#30362D" textColor="#EAE2CC">縮小</Button>
<Button id="sg_larger" rectAlignment="UpperCenter" offsetXY="157 -952" width="82" height="30" fontSize="15" onClick="sgResize" colors="#424D3E|#657059|#2C352A|#30362D" textColor="#EAE2CC">拡大</Button>
<Button id="sg_close" rectAlignment="UpperCenter" offsetXY="245 -952" width="82" height="30" fontSize="15" onClick="sgClose" colors="#424D3E|#657059|#2C352A|#30362D" textColor="#EAE2CC">關閉</Button>
</Panel>
]=]

local ROLES = {"main", "deputy1", "deputy2"}
local ORDER_BY_BUTTON = {
    sg_attack = "攻撃", sg_defend = "防御", sg_move = "機動", sg_regroup = "再編"
}
local ORDER_LABELS = {
    ["进攻"] = "攻撃", ["進攻"] = "攻撃", ["攻撃"] = "攻撃",
    ["防御"] = "防御", ["机动"] = "機動", ["機動"] = "機動",
    ["重整"] = "再編", ["再編"] = "再編"
}
local STATUS_LABELS = {
    ["健康"] = "健康", ["健在"] = "健康", ["無傷"] = "健康", ["无伤"] = "健康",
    ["轻伤"] = "軽傷", ["軽傷"] = "軽傷", ["浅手"] = "軽傷", ["淺手"] = "軽傷",
    ["重伤"] = "重傷", ["重傷"] = "重傷", ["深手"] = "重傷",
    ["阵亡"] = "陣没", ["陣亡"] = "陣没", ["阵没"] = "陣没", ["陣没"] = "陣没", ["战死"] = "陣没", ["戦死"] = "陣没",
    ["逃亡"] = "陣没", ["討死"] = "陣没", ["讨死"] = "陣没"
}
-- 既有 Description 的 status 值仍可读取；此表控制面板的显示称呼。
local STATUS_TEXT = { ["健康"] = "無傷", ["軽傷"] = "浅手", ["重傷"] = "深手", ["陣没"] = "討死" }
local STATUS_COLORS = {
    ["健康"] = "#86C48B", ["軽傷"] = "#F0AAAA",
    ["重傷"] = "#D15C68", ["陣没"] = "#A3A7A4",
    ["未配置"] = "#A7AB9F"
}
local STATUS_BUTTON_COLORS = {
    ["健康"] = "#3C684D|#548363|#2A4937|#30362D",
    ["軽傷"] = "#86454B|#A96066|#623238|#30362D",
    ["重傷"] = "#772C3A|#994050|#5C202E|#30362D",
    ["陣没"] = "#4F5352|#6B706E|#373A39|#30362D",
    ["未配置"] = "#424D3E|#657059|#2C352A|#30362D"
}
local COMMAND_COLORS = {
    "#D9817A", "#E2A56C", "#DAC677", "#B2CA80", "#7BC4B5", "#8EACE2"
}
local FIELD_ALIASES = {
    ["部隊"] = "team", ["役割"] = "role", ["姓名"] = "name",
    ["生年"] = "birth", ["birthYear"] = "birth",
    ["統率"] = "command", ["画像"] = "image", ["状態"] = "status",
    ["行動印"] = "acted_image", ["陣旗"] = "flag_image",
    ["命令"] = "order", ["部隊名"] = "formation", ["役職"] = "title"
}
local ROLE_ALIASES = {
    ["備大将"] = "main", ["主将"] = "main",
    ["副将一"] = "deputy1", ["副将二"] = "deputy2", ["部隊"] = "unit"
}
local STATUS_CYCLE = {"健康", "軽傷", "重傷", "陣没"}
local STATUS_ROLE_BY_BUTTON = {
    sg_main_status = "main", sg_deputy1_status = "deputy1", sg_deputy2_status = "deputy2"
}
local PLAYER_COLORS = {"White", "Brown", "Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "Grey", "Black"}
local playerViews = {}
local ready, assetBusy, refreshTimer = false, false, nil
local tokenNames, parsedTokens, memberships, teamIndex = {}, {}, {}, {}
local teamMembers, tagWarnings, highlighted = {}, {}, {}
local uiValues, uiAttributes, portraitAssets = {}, {}, {}
local foreignAssets = {}
local pendingBackStamps, backStampRoles = {}, {}
-- 12 个座席最多同时需要 48 张画像/陣旗，加 1 张共通行動印。
-- 额外保留最近使用的资源；其他脚本的资源不计入此上限。
local ASSET_CACHE_LIMIT = 64
local assetLastUsed, assetUseGeneration = {}, 0
local renderAllViews
local pendingPanelRender

-- 同一批物件事件只排一次刷新；执行时读取最新状态，不保留旧视图。
local function requestPanelRender()
    if pendingPanelRender then return end
    local request = {}
    pendingPanelRender = request
    Wait.frames(function()
        if pendingPanelRender ~= request then return end
        pendingPanelRender = nil
        renderAllViews()
    end, 1)
end

local function playerID(color, id)
    return "sg_" .. color .. "_" .. id:sub(4)
end

local function buildPlayerXML()
    local panels = {}
    for _, color in ipairs(PLAYER_COLORS) do
        local xml = PANEL_XML:gsub('visibility="PLAYER_COLOR"', 'visibility="' .. color .. '"')
        xml = xml:gsub('id="(sg_[A-Za-z0-9_]+)"', function(id)
            return 'id="' .. playerID(color, id) .. '"'
        end)
        table.insert(panels, xml)
    end
    return table.concat(panels, "\n")
end

-- 用回调实际传入的玩家颜色选取座席，避免另一人悬停导致操作错队。
local function viewFor(player, id)
    local color = player and player.color
    local view = color and playerViews[color]
    if not view then return nil, nil end
    if id ~= nil then
        local prefix = "sg_" .. color .. "_"
        if id:sub(1, #prefix) ~= prefix then return nil, nil end
        return view, "sg_" .. id:sub(#prefix + 1)
    end
    return view, nil
end

-- 不用 (.-) 匹配长地址。按行找到第一个等号，其后的 URL 原样保留。
local function trim(value)
    local text = tostring(value or "")
    local first, last = 1, #text
    local function blank(char)
        return char == " " or char == "\t" or char == "\r" or char == "\n"
            or char == "\v" or char == "\f" or char == "　" or char == " "
    end
    -- MoonSharp 的 %s 会把部分汉字（如“三”）误作空白，逐字符精确判断。
    while first <= last and blank(text:sub(first, first)) do first = first + 1 end
    while last >= first and blank(text:sub(last, last)) do last = last - 1 end
    return text:sub(first, last)
end

local function splitField(line)
    local at = line:find("=", 1, true)
    if not at then return nil, nil end
    local key = trim(line:sub(1, at - 1))
    return FIELD_ALIASES[key] or key, trim(line:sub(at + 1))
end

local function fieldsFor(object)
    if not object then return {} end
    local guid = object.getGUID()
    local raw, name = object.getDescription() or "", trim(object.getName())
    local cached = parsedTokens[guid]
    if cached and cached.raw == raw and cached.name == name then return cached.fields end
    local fields = {}
    for line in raw:gmatch("[^\r\n]+") do
        local key, value = splitField(line)
        if key and fields[key] == nil then fields[key] = value end
    end
    parsedTokens[guid] = {raw = raw, name = name, fields = fields}
    return fields
end

local function nonempty(value)
    if value ~= nil and value ~= "" then return value end
    return nil
end

local function baseProfile(teamId, role)
    local team = FORMATIONS[teamId]
    if not team then return {} end
    if role == "main" then return team.main end
    if role == "deputy1" then return team.deputies[1] end
    if role == "deputy2" then return team.deputies[2] end
    return {}
end

local function identifyToken(object)
    if not object then return nil, nil end
    local fields = fieldsFor(object)
    local fallback = tokenNames[trim(object.getName())]
    local tagTeam
    for _, tag in ipairs(object.getTags and object.getTags() or {}) do
        local candidate = FORMATIONS[tag] and tag or nil
        if type(tag) == "string" and tag:sub(1, 8) == "sg_team_" then
            local suffix = tag:sub(9)
            if suffix:match("^[A-Za-z0-9_%-]+$") then candidate = suffix end
        end
        if candidate then
            if tagTeam and tagTeam ~= candidate then return nil, nil, "所属标签重复" end
            tagTeam = candidate
        end
    end
    local teamId = tagTeam or nonempty(fields.team)
    if teamId then
        -- 所属标签优先；未打标签时，继续兼容 Description 和旧姓名绑定。
        if not teamId:match("^[A-Za-z0-9_%-]+$") then return nil, nil end
        local role = nonempty(fields.role)
        role = ROLE_ALIASES[role] or role
        if not role and fallback and fallback.team == teamId then role = fallback.role end
        return teamId, role or "unit"
    end
    if fallback then return fallback.team, fallback.role end
    return nil, nil
end

local function component(vector, key, index, default)
    if type(vector) == "number" then return vector end
    if not vector then return default end
    return tonumber(vector[key] or vector[index]) or default
end

local function sameVector(left, right, rotation)
    for index, key in ipairs({"x", "y", "z"}) do
        local a = component(left, key, index, nil)
        local b = component(right, key, index, nil)
        if a == nil or b == nil then return false end
        local delta = a - b
        if rotation then delta = (delta + 180) % 360 - 180 end
        if math.abs(delta) > 0.0005 then return false end
    end
    return true
end

local function syncBackStamp(object, role)
    if not object or not object.getDecals or not object.setDecals then return end
    local guid = object.getGUID()
    local isLeader = role == "main" or role == "deputy1" or role == "deputy2"
    if object.spawning or object.loading_custom then
        pendingBackStamps[guid] = true
        return
    end
    local wanted
    if isLeader then
        local bounds = object.getVisualBoundsNormalized and object.getVisualBoundsNormalized()
            or (object.getBoundsNormalized and object.getBoundsNormalized())
        local scale = object.getScale and object.getScale()
        local sx, sy, sz = math.abs(component(scale, "x", 1, 1)), math.abs(component(scale, "y", 2, 1)), math.abs(component(scale, "z", 3, 1))
        local width, depth = component(bounds and bounds.size, "x", 1, 0), component(bounds and bounds.size, "z", 3, 0)
        if width <= 0 or depth <= 0 or sx <= 0 or sy <= 0 or sz <= 0 then
            pendingBackStamps[guid] = true
            return
        end
        local offset, height = bounds.offset, component(bounds.size, "y", 2, 0)
        local diameter = math.min(width, depth) * BACK_STAMP_RATIO
        wanted = {
            name = BACK_STAMP_NAME, url = ACTED_IMAGE_URL,
            position = {
                component(offset, "x", 1, 0) / sx,
                (component(offset, "y", 2, 0) - height / 2) / sy - BACK_STAMP_GAP,
                component(offset, "z", 3, 0) / sz
            },
            rotation = BACK_STAMP_ROTATION,
            scale = {diameter / sx, diameter / sz, 0.1}
        }
    end
    local retained, managed, matches = {}, 0, false
    for _, decal in ipairs(object.getDecals() or {}) do
        if decal.name == BACK_STAMP_NAME then
            managed = managed + 1
            if wanted and decal.url == wanted.url and sameVector(decal.position, wanted.position)
                and sameVector(decal.rotation, wanted.rotation, true) and sameVector(decal.scale, wanted.scale) then
                matches = true
            end
        else
            table.insert(retained, decal)
        end
    end
    pendingBackStamps[guid] = nil
    if (wanted and managed == 1 and matches) or (not wanted and managed == 0) then return end
    if wanted then table.insert(retained, wanted) end
    -- setDecals 会替换整个列表；必须把其它贴花原样保留。
    object.setDecals(retained)
end

local function retryBackStamps()
    local guids = {}
    for guid in pairs(pendingBackStamps) do table.insert(guids, guid) end
    for _, guid in ipairs(guids) do
        local object = getObjectFromGUID(guid)
        if object then
            local _, role = identifyToken(object)
            syncBackStamp(object, role)
        else
            pendingBackStamps[guid] = nil
            backStampRoles[guid] = nil
        end
    end
end

local function removeMembership(guid)
    local old = memberships[guid]
    if old and teamIndex[old.team] and teamIndex[old.team][old.role] then
        teamIndex[old.team][old.role][guid] = nil
    end
    if old and teamMembers[old.team] then
        teamMembers[old.team][guid] = nil
        if next(teamMembers[old.team]) == nil then teamMembers[old.team] = nil end
    end
    memberships[guid] = nil
end

local function registerObject(object, forceStamp)
    if not object then return end
    local guid = object.getGUID()
    local teamId, role, issue = identifyToken(object)
    if issue and tagWarnings[guid] ~= issue then
        print("[備隊] " .. object.getName() .. "：" .. issue .. "。请只保留一个所属标签。")
    end
    tagWarnings[guid] = issue
    local stampRole = (role == "main" or role == "deputy1" or role == "deputy2") and role or false
    if backStampRoles[guid] ~= stampRole or (forceStamp and stampRole) then
        backStampRoles[guid] = stampRole
        syncBackStamp(object, role)
    end
    local old = memberships[guid]
    if old and old.team == teamId and old.role == role then return end
    removeMembership(guid)
    if teamId then
        if role == "main" or role == "deputy1" or role == "deputy2" then
            teamIndex[teamId] = teamIndex[teamId] or {}
            teamIndex[teamId][role] = teamIndex[teamId][role] or {}
            teamIndex[teamId][role][guid] = true
        end
        teamMembers[teamId] = teamMembers[teamId] or {}
        teamMembers[teamId][guid] = true
        memberships[guid] = {team = teamId, role = role}
    end
end

local function rebuildIndex()
    teamIndex, memberships, parsedTokens = {}, {}, {}
    teamMembers = {}
    backStampRoles, pendingBackStamps = {}, {}
    for _, object in ipairs(getAllObjects()) do registerObject(object) end
end

-- 普通刷新只查本队三个位置；缺员也不反复扫描全桌。
local function locateTeam(teamId)
    local objects, conflicts = {}, {}
    for _, role in ipairs(ROLES) do
        local candidates = teamIndex[teamId] and teamIndex[teamId][role] or {}
        local guids = {}
        for guid in pairs(candidates) do table.insert(guids, guid) end
        table.sort(guids)
        local count = 0
        for _, guid in ipairs(guids) do
            local object = getObjectFromGUID(guid)
            if object then
                registerObject(object)
                local current = memberships[guid]
                if current and current.team == teamId and current.role == role then
                    count = count + 1
                    objects[role] = object
                end
            else
                removeMembership(guid)
                parsedTokens[guid] = nil
                backStampRoles[guid], pendingBackStamps[guid] = nil, nil
            end
        end
        if count > 1 then objects[role], conflicts[role] = nil, true end
    end
    return objects, conflicts
end

local function validInteger(value, low, high)
    local number = tonumber(value)
    if number and number == math.floor(number) and number >= low and number <= high then return number end
    return nil
end

local function resolveProfile(teamId, role, object)
    local defaults, fields = baseProfile(teamId, role), fieldsFor(object)
    local command = validInteger(fields.command, 1, 6)
    local birth = validInteger(fields.birth, 1, CURRENT_YEAR)
    local issues = {}
    if nonempty(fields.command) and not command then table.insert(issues, "統率：1～6") end
    if nonempty(fields.birth) and not birth then table.insert(issues, "生年確認") end
    local image = nonempty(fields.image) or defaults.image or ""
    if image == "-" then image = "" end
    image = trim(image)
    local validURL = image:lower():match("^https?://") ~= nil
    if image ~= "" and not validURL then
        table.insert(issues, "画像URL確認")
        image = ""
    end
    local flagImage = role == "main" and trim(fields.flag_image) or ""
    if flagImage == "-" then flagImage = "" end
    if flagImage ~= "" and not flagImage:lower():match("^https?://") then
        table.insert(issues, "陣旗URL確認")
        flagImage = ""
    end
    -- 用户指定所有武将使用同一张印章；旧 Description 的 acted_image 不再覆盖。
    local actedImage = ACTED_IMAGE_URL
    local name = nonempty(fields.name) or defaults.name
        or (object and nonempty(trim(object.getName()))) or "未登録"
    local status = STATUS_LABELS[fields.status]
    if not status and nonempty(fields.status) then table.insert(issues, "状態確認") end
    status = status or defaults.defaultStatus or "健康"
    return {
        name = name, birthYear = birth or defaults.birthYear,
        command = command or defaults.command,
        roleLabel = nonempty(fields.title) or defaults.roleLabel or (role == "main" and "備大将" or "副将"),
        image = image, asset = "sgp_" .. teamId .. "_" .. role,
        flagImage = flagImage, flagAsset = "sgp_" .. teamId .. "_flag",
        actedImage = actedImage, actedAsset = "sgp_common_acted",
        status = object and status or "未配置",
        issues = table.concat(issues, "・")
    }
end

local function setValue(id, value)
    value = tostring(value)
    if uiValues[id] ~= value then
        uiValues[id] = value
        UI.setValue(id, value)
    end
end

local function setAttribute(id, key, value)
    value = tostring(value)
    uiAttributes[id] = uiAttributes[id] or {}
    if uiAttributes[id][key] ~= value then
        uiAttributes[id][key] = value
        UI.setAttribute(id, key, value)
    end
end

-- 状态文字使用独立 Text，显式更新 text 属性，避免按钮保留初始标签。
local function setText(id, value)
    setValue(id, value)
    setAttribute(id, "text", value)
end

local function statText(value)
    return value ~= nil and tostring(value) or "—"
end

local function waitForUI(callback)
    Wait.frames(function()
        Wait.condition(callback, function() return not UI.loading end, 30, function()
            -- 超时之后轮询仍可在 UI.loading 恢复时正常继续。
            assetBusy = false
            ready = true
            print("[備隊面板] 画像讀取中。請檢查 URL。")
        end)
    end, 1)
end

local function refreshForeignAssets()
    foreignAssets = {}
    for _, asset in ipairs(UI.getCustomAssets() or {}) do
        if type(asset.name) ~= "string" or asset.name:sub(1, 4) ~= "sgp_" then
            table.insert(foreignAssets, asset)
        end
    end
end

local function allAssets()
    local assets, names = {}, {}
    for _, asset in ipairs(foreignAssets) do table.insert(assets, asset) end
    for name in pairs(portraitAssets) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
        table.insert(assets, {name = name, url = portraitAssets[name]})
    end
    return assets
end

local function ensurePortraits(profileLists)
    local changed = false
    assetUseGeneration = assetUseGeneration + 1
    local active = {sgp_common_acted = true}
    local function remember(name, url)
        local wanted = nonempty(url)
        if portraitAssets[name] ~= wanted then
            portraitAssets[name] = wanted
            changed = true
        end
        if wanted then
            active[name] = true
            assetLastUsed[name] = assetUseGeneration
        else
            assetLastUsed[name] = nil
        end
    end
    for _, profiles in ipairs(profileLists) do
        for _, role in ipairs(ROLES) do
            local profile = profiles[role]
            -- 共通行動印只登记一份资源；翻面时只切换可见性。
            remember(profile.asset, profile.image)
            remember(profile.actedAsset, profile.actedImage)
            if role == "main" then
                remember(profile.flagAsset, profile.flagImage)
            end
        end
    end
    local count, inactive = 0, {}
    for name in pairs(portraitAssets) do
        count = count + 1
        if not active[name] then table.insert(inactive, name) end
    end
    if count > ASSET_CACHE_LIMIT then
        table.sort(inactive, function(a, b)
            local aTime, bTime = assetLastUsed[a] or 0, assetLastUsed[b] or 0
            return aTime < bTime or (aTime == bTime and a < b)
        end)
        for _, name in ipairs(inactive) do
            if count <= ASSET_CACHE_LIMIT then break end
            portraitAssets[name], assetLastUsed[name] = nil, nil
            count, changed = count - 1, true
        end
    end
    if not changed then return true end
    -- 其他脚本可能在初始化后新增资源；只在确需提交资源时重读实时列表。
    refreshForeignAssets()
    assetBusy = true
    -- setCustomAssets 替换整个列表，保留当前及近期画像、其他脚本的资源。
    UI.setCustomAssets(allAssets())
    uiValues, uiAttributes = {}, {}
    waitForUI(function()
        assetBusy = false
        -- 此处不捕获旧队伍，加载期间换队或关窗后也不会跳回去。
        renderAllViews()
    end)
    return false
end

-- 統率六格分别绘制，避免连写符号因字体宽度而偏移；深手失效格直接显示 X。
local function commandBar(value, status)
    local level = type(value) == "number" and math.max(1, math.min(6, math.floor(value))) or 0
    local chars = {}
    for i = 1, 6 do
        if status == "陣没" then
            chars[i] = "X"
        elseif i <= level then
            chars[i] = (status == "重傷" and i == level) and "X" or "●"
        else
            chars[i] = "○"
        end
    end
    return chars
end

local function setPersonUI(prefix, profile, object, conflict)
    local status = conflict and "配置重複" or profile.status
    local age = profile.birthYear and tostring(CURRENT_YEAR - profile.birthYear) or "—"
    local command = profile.command
    local dots = commandBar(command, status)
    local injured = status == "軽傷" or status == "重傷"
    local inactive = status == "陣没"
    local currentCommand = command
    if status == "重傷" and command then currentCommand = math.max(0, command - 1) end
    local color = inactive and "#666B65" or COMMAND_COLORS[currentCommand]
        or (currentCommand == 0 and "#D9817A") or "#A7AB9F"
    local dotColor = inactive and "#666B65" or COMMAND_COLORS[command] or "#A7AB9F"
    local displayStatus = STATUS_TEXT[status] or status
    local movement = object and (inactive and "—" or injured and "4" or "9") or "—"
    local acted = object and (object.is_face_down and "済" or "未") or "—"
    setValue(prefix .. "_role", profile.roleLabel)
    setValue(prefix .. "_name", profile.name .. "　年齢 " .. age)
    setValue(prefix .. "_command", inactive and "X" or statText(currentCommand))
    local main = prefix:sub(-5) == "_main"
    local slotWidth, circleSize, crossSize, circleRise = main and 28 or 24, main and 30 or 24, main and 24 or 20, main and 2 or 1
    for index, symbol in ipairs(dots) do
        local slotID = prefix .. "_command_slot" .. index
        local cross = symbol == "X"
        setValue(slotID, symbol)
        setAttribute(slotID, "color", dotColor)
        setAttribute(slotID, "fontSize", cross and crossSize or circleSize)
        setAttribute(slotID, "offsetXY", string.format("%g %g", -5 * slotWidth / 2 + (index - 1) * slotWidth, cross and 0 or circleRise))
    end
    setValue(prefix .. "_mobility", "機動 " .. movement)
    setText(prefix .. "_status_text", displayStatus)
    setValue(prefix .. "_action", "行動 " .. acted)
    setAttribute(prefix .. "_command", "color", color)
    setAttribute(prefix .. "_status_text", "color", inactive and "#848A84" or STATUS_COLORS[status] or "#D7A978")
    setAttribute(prefix .. "_card", "color", inactive and "#1B1F1B" or "#292D28")
    setAttribute(prefix .. "_role", "color", inactive and "#73776B" or "#C5AD75")
    setAttribute(prefix .. "_name", "color", inactive and "#797D75" or "#F2EAD9")
    setAttribute(prefix .. "_command_label", "color", inactive and "#6F746B" or "#BDBAA9")
    setAttribute(prefix .. "_status_label", "color", inactive and "#6F746B" or "#BDBAA9")
    setAttribute(prefix .. "_mobility", "color", inactive and "#6F746B" or "#ECE6D8")
    setAttribute(prefix .. "_action", "color", inactive and "#6F746B" or acted == "済" and "#8E968B" or "#DED9CB")
    setAttribute(prefix .. "_name", "tooltip", profile.issues)
    local available = profile.image ~= "" and not conflict
    setAttribute(prefix .. "_portrait", "active", available and "true" or "false")
    setAttribute(prefix .. "_no_image", "active", available and "false" or "true")
    setValue(prefix .. "_no_image", conflict and "配置重複" or "画像未登録")
    -- 直接写入完整 URL。Steam Cloud URL 没有文件扩展名时，部分 TTS 版本
    -- 通过自定义资源名称会显示白块；Image.image 直接 URL 可正常读取。
    if available then setAttribute(prefix .. "_portrait", "image", profile.image) end

    -- 负伤与行动分别控制，重傷画像仍可同时盖「済」。
    local showInjury = object ~= nil and not conflict and (injured or inactive)
    local heavy = showInjury and status == "重傷"
    setAttribute(prefix .. "_portrait_frame", "color", showInjury and STATUS_COLORS[status] or "#5E604F")
    -- TTS の Image.color は中性灰の着色までなので、陣没は輪郭を残す灰暗色で示す。
    setAttribute(prefix .. "_portrait", "color", inactive and "#3F3F3F" or heavy and "#BDBDBD" or "#FFFFFF")
    setAttribute(prefix .. "_injury_badge", "active", showInjury and "true" or "false")
    setAttribute(prefix .. "_injury_badge", "color", inactive and "#555A58" or heavy and "#772C3A" or "#AF5960")
    setValue(prefix .. "_injury_label", displayStatus)
    setAttribute(prefix .. "_status", "colors", STATUS_BUTTON_COLORS[status] or STATUS_BUTTON_COLORS["未配置"])
    setAttribute(prefix .. "_status", "interactable", object ~= nil and not conflict and "true" or "false")
    setAttribute(prefix .. "_status", "tooltip", "")
    setAttribute(prefix .. "_status_text", "tooltip", "")
    setAttribute(prefix .. "_status_label", "tooltip", "")

    local showActed = object ~= nil and not conflict and object.is_face_down == true
    local hasStamp = profile.actedImage ~= ""
    setAttribute(prefix .. "_acted_stamp", "active", showActed and hasStamp and "true" or "false")
    setAttribute(prefix .. "_acted_fallback", "active", showActed and not hasStamp and "true" or "false")
    setAttribute(prefix .. "_acted_stamp", "color", inactive and "#FFFFFF55" or "#FFFFFFE6")
    setAttribute(prefix .. "_acted_fallback", "color", inactive and "#81474388" or "#E43B36DF")
    if hasStamp then setAttribute(prefix .. "_acted_stamp", "image", profile.actedImage) end
end

-- 地图只使用已登记对象；添加/更改标签后由悬停、放下或「更新」重新登记。
local function renderMapEffects()
    local urls, snapshot, teamIds = {}, {}, {}
    for teamId in pairs(teamMembers) do table.insert(teamIds, teamId) end
    for _, teamId in ipairs(teamIds) do
        local objects, conflicts = locateTeam(teamId)
        urls[teamId] = objects.main and not conflicts.main
            and resolveProfile(teamId, "main", objects.main).flagImage or ""
    end
    local stale = {}
    for guid, member in pairs(memberships) do
        local object = getObjectFromGUID(guid)
        if object then
            snapshot[guid] = {object = object, team = member.team, role = member.role, url = urls[member.team] or ""}
        else
            table.insert(stale, guid)
        end
    end
    for _, guid in ipairs(stale) do
        removeMembership(guid)
        parsedTokens[guid], backStampRoles[guid], pendingBackStamps[guid], tagWarnings[guid] = nil, nil, nil, nil
    end
    local hoverTeams = {}
    for _, view in pairs(playerViews) do
        local current = view.hoverGUID and snapshot[view.hoverGUID]
        view.hoverTeam = current and current.team or nil
        if not current then view.hoverGUID = nil end
        if view.hoverTeam then hoverTeams[view.hoverTeam] = true end
        if view.flagTeam and (urls[view.flagTeam] or "") == "" then view.flagTeam = nil end
    end
    -- TTS 物件轮廓是桌面共享的；取所有座席悬停队伍的并集，避免互相清除。
    local wanted = {}
    for guid, entry in pairs(snapshot) do
        if hoverTeams[entry.team] and entry.object.highlightOn then
            wanted[guid] = true
            entry.object.highlightOn({0.84, 0.72, 0.38}, 1.5)
        end
    end
    for guid in pairs(highlighted) do
        if not wanted[guid] then
            local object = getObjectFromGUID(guid)
            if object and object.highlightOff then object.highlightOff() end
        end
    end
    highlighted = wanted
    sgMapUpdate(snapshot, playerViews)
end

renderAllViews = function()
    pendingPanelRender = nil
    -- 地图清理不受屏幕画像资源加载阻塞。
    renderMapEffects()
    if not ready or UI.loading or assetBusy then return end
    local teams, profileLists = {}, {}
    for _, color in ipairs(PLAYER_COLORS) do
        local view = playerViews[color]
        local teamId = view.selectedTeamId
        if view.visible and teamId and not teams[teamId] then
            local objects, conflicts = locateTeam(teamId)
            local fields, profiles = fieldsFor(objects.main), {}
            for _, role in ipairs(ROLES) do
                profiles[role] = resolveProfile(teamId, role, objects[role])
            end
            teams[teamId] = {objects = objects, conflicts = conflicts, fields = fields, profiles = profiles}
            table.insert(profileLists, profiles)
        end
    end
    if not ensurePortraits(profileLists) then return end
    for _, color in ipairs(PLAYER_COLORS) do
        local view = playerViews[color]
        setAttribute(playerID(color, "sg_panel"), "active", view.visible and "true" or "false")
        setText(playerID(color, "sg_mapflags"), view.flagTeam and view.flagTeam == view.selectedTeamId and "本隊陣旗：有" or "本隊陣旗：無")
        local data = view.visible and view.selectedTeamId and teams[view.selectedTeamId]
        local showFlag = false
        if data then
            local objects, conflicts, fields, profiles = data.objects, data.conflicts, data.fields, data.profiles
            local defaults = FORMATIONS[view.selectedTeamId]
            local title = nonempty(fields.formation) or (defaults and defaults.title) or view.selectedTeamId
            local size = string.format("%.1f", view.scale)
            setAttribute(playerID(color, "sg_panel"), "scale", size .. " " .. size .. " 1")
            setText(playerID(color, "sg_pin"), view.pinned and "固定：有" or "固定：無")
            setValue(playerID(color, "sg_formation"), title)
            for _, role in ipairs(ROLES) do
                setPersonUI(playerID(color, "sg_" .. role), profiles[role], objects[role], conflicts[role])
            end
            showFlag = objects.main ~= nil and not conflicts.main and profiles.main.flagImage ~= ""
            local flagID = playerID(color, "sg_flag")
            setAttribute(flagID, "image", showFlag and profiles.main.flagImage or "")
            setAttribute(flagID, "active", showFlag and "true" or "false")
            setAttribute(flagID, "color", "#FFFFFF")
            setAttribute(flagID, "tooltip", "")
            -- 260 画像 + 20 留白 + 90 陣旗，组合宽 370；无旗时画像与役職回中。
            setAttribute(playerID(color, "sg_main_visual_group"), "offsetXY", showFlag and "-55 -37" or "0 -37")
            setAttribute(playerID(color, "sg_main_role"), "offsetXY", showFlag and "-55 -8" or "0 -8")
            local order = nonempty(fields.order) or "未設定"
            order = ORDER_LABELS[order] or order
            if not objects.main then order = conflicts.main and "備大将配置重複" or "備大将未配置" end
            setValue(playerID(color, "sg_order"), "現在命令：" .. order)
            for id, value in pairs(ORDER_BY_BUTTON) do
                setAttribute(playerID(color, id), "colors", order == value
                    and "#79663D|#968151|#5D4E2C|#30362D"
                    or "#424D3E|#657059|#2C352A|#30362D")
            end
        end
        setAttribute(playerID(color, "sg_mapflags"), "interactable", showFlag and "true" or "false")
    end
end

local function writeField(object, wanted, value)
    local description = (object.getDescription() or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local result, replaced = {}, false
    if description ~= "" then
        for line in (description .. "\n"):gmatch("([^\n]*)\n") do
            local key = splitField(line)
            if key == wanted then
                if not replaced then table.insert(result, wanted .. "=" .. value) end
                replaced = true
            else
                table.insert(result, line)
            end
        end
    end
    if not replaced then table.insert(result, wanted .. "=" .. value) end
    object.setDescription(table.concat(result, "\n"))
end

-- 面板状态按钮：不必进入 Description，点击一次推进到下一个状态。
function sgSetStatus(player, value, id)
    local view, button = viewFor(player, id)
    if not view or not ready or UI.loading or assetBusy or not view.selectedTeamId or not view.visible then return end
    local role = STATUS_ROLE_BY_BUTTON[button]
    if not role then return end
    local objects, conflicts = locateTeam(view.selectedTeamId)
    local object = objects[role]
    if not object or conflicts[role] then return end
    local current = resolveProfile(view.selectedTeamId, role, object).status
    local nextStatus = STATUS_CYCLE[1]
    for index, status in ipairs(STATUS_CYCLE) do
        if status == current then
            nextStatus = STATUS_CYCLE[index % #STATUS_CYCLE + 1]
            break
        end
    end
    writeField(object, "status", STATUS_TEXT[nextStatus] or nextStatus)
    renderAllViews()
end

-- 合并版只从既有 onLoad 调用本函数；不会覆盖兵种存档逻辑。
function initTeamPanel()
    pendingPanelRender = nil
    for guid in pairs(highlighted) do
        local object = getObjectFromGUID(guid)
        if object and object.highlightOff then object.highlightOff() end
    end
    highlighted, tagWarnings, teamMembers = {}, {}, {}
    sgMapInit()
    ready, assetBusy = false, false
    playerViews = {}
    for _, color in ipairs(PLAYER_COLORS) do
        playerViews[color] = {selectedTeamId = nil, visible = true, pinned = false, scale = 1,
            hoverGUID = nil, hoverTeam = nil, flagTeam = nil}
    end
    tokenNames, parsedTokens, memberships, teamIndex = {}, {}, {}, {}
    pendingBackStamps, backStampRoles = {}, {}
    assetLastUsed, assetUseGeneration = {}, 0
    uiValues, uiAttributes, portraitAssets, foreignAssets = {}, {}, {}, {}
    portraitAssets.sgp_common_acted = ACTED_IMAGE_URL
    for teamId in pairs(FORMATIONS) do
        for _, role in ipairs(ROLES) do
            local profile = baseProfile(teamId, role)
            tokenNames[profile.tokenName] = {team = teamId, role = role}
        end
    end
    refreshForeignAssets()
    rebuildIndex()
    renderMapEffects()
    UI.setXml(buildPlayerXML(), allAssets())
    waitForUI(function()
        ready = true
        renderAllViews()
    end)
    if refreshTimer then Wait.stop(refreshTimer) end
    refreshTimer = Wait.time(function()
        retryBackStamps()
        renderAllViews()
    end, 0.75, -1)
end

function sgPanelObjectSpawn(object)
    if not object then return end
    local guid = object.getGUID()
    Wait.frames(function()
        local live = getObjectFromGUID(guid)
        if live then registerObject(live, true) end
        requestPanelRender()
    end, 2)
end

function sgPanelObjectDestroy(object)
    if not object then return end
    local guid = object.getGUID()
    removeMembership(guid)
    pendingBackStamps[guid] = nil
    backStampRoles[guid] = nil
    parsedTokens[guid] = nil
    tagWarnings[guid] = nil
    if highlighted[guid] and object.highlightOff then object.highlightOff() end
    highlighted[guid] = nil
    sgMapForget(guid)
    requestPanelRender()
end

function onObjectHover(player_color, object)
    local view = playerViews[player_color]
    if not view then return end
    if object then registerObject(object, true) end
    local teamId = object and identifyToken(object)
    view.hoverGUID, view.hoverTeam = teamId and object.getGUID() or nil, teamId
    if not teamId or (view.pinned and view.selectedTeamId and teamId ~= view.selectedTeamId) then
        renderMapEffects()
        return
    end
    if view.selectedTeamId ~= teamId then view.flagTeam = nil end
    view.selectedTeamId, view.visible = teamId, true
    renderAllViews()
end

function onObjectRotate(object, spin, flip, player_color, old_spin, old_flip)
    if not object then return end
    local teamId = identifyToken(object)
    if teamId then
        -- 等翻面动画推进后读取正反面；定时检查也会捕捉物理翻转。
        Wait.time(requestPanelRender, 0.35)
    end
end

function onObjectDrop(player_color, object)
    if object then registerObject(object, true) end
    requestPanelRender()
end

function onObjectEnterContainer(container, object)
    sgPanelObjectDestroy(object)
end

function onObjectLeaveContainer(container, object)
    sgPanelObjectSpawn(object)
end

function onObjectStateChange(object, old_state_guid)
    removeMembership(old_state_guid)
    parsedTokens[old_state_guid], pendingBackStamps[old_state_guid], backStampRoles[old_state_guid] = nil, nil, nil
    tagWarnings[old_state_guid] = nil
    sgMapForget(old_state_guid)
    for _, view in pairs(playerViews) do
        if view.hoverGUID == old_state_guid then view.hoverGUID, view.hoverTeam = nil, nil end
    end
    sgPanelObjectSpawn(object)
end

function onPlayerChangeColor(player_color)
    if type(clearUnitMoraleQuickKeys) == "function" then clearUnitMoraleQuickKeys() end
    -- 换座不继承上位玩家的临时地图状态；清除已空座位，避免残留全桌高亮。
    local changed = playerViews[player_color]
    if changed then changed.hoverGUID, changed.hoverTeam, changed.flagTeam = nil, nil, nil end
    if Player and Player.getPlayers then
        local occupied = {}
        for _, player in ipairs(Player.getPlayers()) do occupied[player.color] = true end
        for color, view in pairs(playerViews) do
            if not occupied[color] then view.hoverGUID, view.hoverTeam, view.flagTeam = nil, nil, nil end
        end
    end
    renderAllViews()
end

function onPlayerDisconnect(player)
    onPlayerChangeColor(player and player.color)
end

function sgToggleMapFlags(player, value, id)
    local view, button = viewFor(player, id)
    if not view or button ~= "sg_mapflags" or not view.visible or not view.selectedTeamId then return end
    local objects, conflicts = locateTeam(view.selectedTeamId)
    if not objects.main or conflicts.main or resolveProfile(view.selectedTeamId, "main", objects.main).flagImage == "" then
        view.flagTeam = nil
    else
        if view.flagTeam == view.selectedTeamId then
            view.flagTeam = nil
        else
            view.flagTeam = view.selectedTeamId
        end
    end
    renderAllViews()
end

function sgSetOrder(player, value, id)
    local view, button = viewFor(player, id)
    if not view or not ready or UI.loading or assetBusy or not view.selectedTeamId or not view.visible then return end
    local order = ORDER_BY_BUTTON[button]
    if not order then return end
    local objects = locateTeam(view.selectedTeamId)
    if not objects.main then renderAllViews() return end
    writeField(objects.main, "order", order)
    renderAllViews()
end

function sgRefresh(player, value, id)
    local view = viewFor(player, id)
    if not view then return end
    rebuildIndex()
    renderAllViews()
end

function sgPin(player, value, id)
    local view = viewFor(player, id)
    if not view or not view.selectedTeamId or UI.loading then return end
    view.pinned = not view.pinned
    setText(playerID(player.color, "sg_pin"), view.pinned and "固定：有" or "固定：無")
end

function sgResize(player, value, id)
    local view, button = viewFor(player, id)
    if not view or not ready or UI.loading then return end
    if button ~= "sg_smaller" and button ~= "sg_larger" then return end
    view.scale = math.max(0.6, math.min(1.2, view.scale + (button == "sg_smaller" and -0.1 or 0.1)))
    local size = string.format("%.1f", view.scale)
    setAttribute(playerID(player.color, "sg_panel"), "scale", size .. " " .. size .. " 1")
end

function sgClose(player, value, id)
    local view = viewFor(player, id)
    if not view then return end
    view.visible, view.pinned = false, false
    view.hoverGUID, view.hoverTeam, view.flagTeam = nil, nil, nil
    -- 窗口关闭状态独立于画像异步加载。
    setAttribute(playerID(player.color, "sg_panel"), "active", "false")
    setText(playerID(player.color, "sg_pin"), "固定：無")
    setText(playerID(player.color, "sg_mapflags"), "本隊陣旗：無")
    renderMapEffects()
end

-- 独立版入口；合并版构建时移除此段，调用上面的面板 hooks。
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

-- BEGIN STANDALONE EVENTS
function onLoad()
    initTeamPanel()
end
function onObjectSpawn(object)
    sgPanelObjectSpawn(object)
end
function onObjectDestroy(object)
    sgPanelObjectDestroy(object)
end
-- END STANDALONE EVENTS
