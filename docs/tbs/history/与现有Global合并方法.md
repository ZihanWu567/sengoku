# 与现有兵种 Global 脚本合并

当前 v2.9 已经提供[兵種与備隊面板合并版_日本漢字.lua](C:/Users/HP/Documents/ChatGPT/日本战国/TTS武将面板/兵種与備隊面板合并版_日本漢字.lua)。它包含之前提供的兵种功能、新版备队面板、统一「済」印和地图陣旗模块，通常直接使用这个文件即可；不需要另粘地图旗模块或逐枚修改棋子 Lua。

本版更新日期为 2026-10-10。安装后，只需在主将 Description 新增 `flag_image=真实陣旗图片直链`（也可使用 `陣旗=`）即可显示本隊陣旗，不用再次修改 Global；空值或 `-` 隐藏旗。陣旗显示为 `90 × 240`，放在 `260 × 260` 主将画像右侧，相隔 `20`，纵向中心对齐，组合水平居中；「備大将」标题随画像向左移 `55`，无旗时标题和画像一同回中。姓名及能力行保持整卡居中，面板仍为 `600 × 1000`，副将显示和背面印章参数保持原值。

已提供白底无字、三枚家纹纵列的本地新素材。它尚未上传到云端，不能把本地文件路径填入 `flag_image`；上传步骤及素材下载见[新陣旗使用说明](C:/Users/HP/Documents/ChatGPT/日本战国/TTS武将面板/新陣旗使用说明.md)。

v2.9 新增地图上的主将常驻旗、悬停旗和本隊高亮，以及面板底部「本隊陣旗」开关。普通部队使用英文所属标签，如本陣 `ota_honjin`；同一隊地图旗统一读取主将 `flag_image`。不需要在 Tags 中输入汉字。完整配置与多人的显示说明见[地图陣旗与英文标签](C:/Users/HP/Documents/ChatGPT/日本战国/TTS武将面板/地图陣旗与英文标签.md)。

本合并版也增加了对格式异常的旧存档资料的容错处理。本脚本 Global UI 的资源登记最多保留 `64` 份当前及近期使用的资源，其他脚本资源仍保留；不要将登记管理视为直链图片已缓存或实测帧率提升。

十二名武将的 Description 模板、画像填写和面板操作见[令牌資料填写指南](C:/Users/HP/Documents/ChatGPT/日本战国/TTS武将面板/令牌資料填写指南.md)。

面板行動印和武将令牌背面贴花统一使用 Global 中设置的图片，无需给每枚令牌填 `acted_image`；旧字段会被忽略。背面安装与检查见[令牌背面済印](C:/Users/HP/Documents/ChatGPT/日本战国/TTS武将面板/令牌背面済印.md)。

## 推荐操作：使用已经合并的文件

1. 先将当前 TTS 游戏另存为副本。
2. 如果你在游戏内又修改过 Global，先保留这些额外改动。如果旧脚本填过画像地址，复制到对应令牌 Description 的 `image=`。
3. 打开 `兵種与備隊面板合并版_日本漢字.lua`，复制全部代码。
4. 在 TTS 的 **Scripting → Lua → Global** 中全选原代码，以新代码完整替换，点击 **Save & Play**。
5. 按新指南填写令牌 Description，检查原有兵种按钮和武将面板都正常。

不要把整个合并版追加到旧 Global 末尾，否则会重复定义事件函数。若你后来又改过兵种功能，需要将那些额外改动保留到合并版中。

## 仅在需要保留其他 Global 功能时手动合并

以下适用于把[独立面板脚本](C:/Users/HP/Documents/ChatGPT/日本战国/TTS武将面板/備隊武将面板_日本漢字.lua)整合到你自己继续修改过的 Global。

**新版脚本已经定义了 `initTeamPanel()`。不要再把 `onLoad()` 改名为 `initTeamPanel()`，那会重复定义函数，并可能导致递归调用。**

1. 保留现有 Global 中唯一的 `onLoad`、`onSave`、`onObjectSpawn` 和 `onObjectDestroy`，以及原有逻辑。
2. 从独立面板脚本中删除末尾从 `-- BEGIN STANDALONE EVENTS` 到 `-- END STANDALONE EVENTS` 的整段内容，包含两个标记行。这段是供独立使用的三个事件入口。
3. 将删除该段后的面板代码加入现有 Global。面板自身的 `initTeamPanel`、`sgPanelObjectSpawn`、`sgPanelObjectDestroy` 等函数保持原名。
4. 在原有 `onLoad(saved_data)` 中添加一次 `initTeamPanel()`，保留原有读档和兵种初始化。
5. 在原有 `onObjectSpawn(obj)` 中添加一次 `sgPanelObjectSpawn(obj)`；在原有 `onObjectDestroy(obj)` 中添加一次 `sgPanelObjectDestroy(obj)`。如果你的参数名称不是 `obj`，调用时使用你实际的参数名。
6. 如果现有 Global 也定义了以下任一事件，必须把原有逻辑与面板对应逻辑合并到各自唯一的事件函数内，不能让两个同名事件互相覆盖：`onObjectHover`、`onObjectRotate`、`onObjectDrop`、`onObjectEnterContainer`、`onObjectLeaveContainer`、`onObjectStateChange`、`onPlayerDisconnect`、`onPlayerChangeColor`。保留各自逻辑需要的参数；处理提前 `return` 时，确认不会阻断另一部分逻辑。后五项负责收纳、取出、更换物件状态和玩家离线／换座后的清理，不要省略。

现有兵种脚本的加载部分应保留读档内容，并包含：

```lua
    Wait.time(setupAllUnits, 1)
    initTeamPanel()
```

`onSave()` 继续保存兵种状态。武将资料和命令保存在令牌 Description 中，随 TTS 游戏保存，不需要为它们再增加一个 `onSave()`。

面板初始化会设置 Global UI。若你的原有脚本还有其他 Global UI，需要同时整合 XML 及初始化流程；合并 Lua 事件本身不会自动保留另一套界面。

地图旗使用各枚棋子的 Object UI。脚本会读取并保留其他节点及图片资源，再合并自身的 `sgmf_` 节点；首次挂载或清理时会重新提交 XML。第三方 `allowDragging` 界面拖动后的屏幕位置无法通过 TTS API 可靠读回，重建时可能重置，因此不能保证此类界面的位置完全不变。已有自定义 Object UI 的棋子应在存档副本中检查，具体范围见[地图陣旗与英文标签](C:/Users/HP/Documents/ChatGPT/日本战国/TTS武将面板/地图陣旗与英文标签.md)。

## 检查结果

- 全部 Global 中只保留一个 `onLoad` 和一个 `initTeamPanel`，原有 `onSave` 仍在。
- `onObjectSpawn`、`onObjectDestroy` 各只有一个，并分别调用对应的面板函数。
- 悬停、旋转、放下、收纳、取出、更换物件状态、玩家离线和换座的同名事件没有重复定义。
- 原有兵种的士气、数量和移动力按钮正常；悬停同队任意武将时，三人的资料一起显示。
- 新建令牌或修改编队后，点击面板的 `更新`，再检查队伍归属。

不要把 Markdown 代码块的三个反引号复制进 Lua 编辑器。修改完成后保存游戏，确保令牌资料与桌面物件进入存档。
