# 戦国 · Sengoku

日本战国题材的 **Tabletop Simulator（TTS）** 棋子脚本、武将／備隊面板和美术素材项目。对话中也曾简称 TBS；实际运行平台是 TTS。

当前版本为 **v2.15.0（2026-10-21）**，在已导入的 v2.14.11 上增加交戦／指揮外手动标记。它提供棋子操作和状态显示，**不是完整的 RAN 规则或自动回合引擎**。

另一位 Codex 开始工作前，请先阅读 [AGENTS.md](AGENTS.md) 和 [docs/HANDOFF.md](docs/HANDOFF.md)。

## 目录

| 路径 | 用途 |
| --- | --- |
| [tts/Global.lua](tts/Global.lua) | 完整可运行的 Global Lua；部队逻辑在前半段，武将面板与地图旗在后半段 |
| [tts/modules](tts/modules/) | 武将面板源文件、地图旗模块；已有源码的同步关系保留 |
| [tts/releases/Global_v2.15.0.txt](tts/releases/Global_v2.15.0.txt) | 可直接全选复制的完整替换版，与 Global.lua 字节一致；旧版 TXT 仅供回溯 |
| [tools/tts](tools/tts/) / [tests/tts](tests/tts/) | 源码同步工具、MoonSharp 行为与 XML 检查 |
| [docs/tbs](docs/tbs/) | 当前使用说明、配置、规则差异、设计待办、导入来源与历史资料 |
| [素材/底图](素材/底图/) | 现有八色 1200×1200 底图 |
| [素材/部队](素材/部队/) | 现有十二种部队素材 |
| [素材/合成成品](素材/合成成品/) | 十二兵种 × 八色，共 96 张成品 |
| [tools/photoshop](tools/photoshop/) | 仓库已有的 Photoshop 图层导出脚本 |

## 技术栈与依赖

- **游戏运行**：Tabletop Simulator 自带 Lua／MoonSharp、Global UI XML、Object.UI、贴花与经典按钮 API。没有 npm 服务、浏览器应用或数据库，也不需要额外安装 Lua 包。
- **源码同步和静态检查**：Python **3.10+**，只用标准库，不需要 `pip install`。
- **行为测试**：Windows PowerShell 7 和本机 TTS 安装内的 `MoonSharp.Interpreter.dll`。DLL 由合法安装的游戏提供，不包含在仓库中。
- **美术工具**：Photoshop 仅在运行现有 JSX 导出工具时需要；游玩和 Lua 检查不依赖 Photoshop。
- **图片加载**：现有数字、行动、士气色带等使用 Steam Cloud 直链；各武将画像和阵旗由令牌 Description 提供，需要客户端能访问图片。

## 在 TTS 中运行

1. 安装并启动 Tabletop Simulator，先将要修改的游戏另存为副本。
2. 打开 **Scripting → Lua → Global**，用 `tts/Global.lua` 的**全部内容**替换 Global，执行 **Save & Play**。不要将多个完整版本追加在一起。
3. 使用仓库成品制作／配置 Custom Tile。脚本不会自动创建整个战场，也不会自动替换物件底图。
4. 部队的 Tags 至少添加一个 `unit_*` 兵种标签；可加 `count_100`～`count_400` 和所属備隊标签。见 [配置与操作](docs/tbs/CONFIGURATION.md)。
5. 武将令牌填写 `team`、`role` 等 Description 字段。画像／阵旗使用图片直链；点面板「更新」重新索引。
6. 每位玩家在 **Options → Game Keys** 将 **士気快捷調整** 绑定 Ctrl。普通左右键加减士气，按住绑定键再左右键补满／清空。
7. 保存 TTS 游戏，保存部队状态、令牌 Description 与物件朝向。仓库目前没有可一键载入的完整 `.json` 场景。

只有武将面板的独立使用场景可选择 `tts/modules/commanders.lua` 作为整个 Global；完整项目应使用 `tts/Global.lua`，不要再额外粘贴独立面板。

## 修改与验证

在仓库根目录执行：

```powershell
python tools/tts/sync_global.py --check
python tools/tts/validate.py
pwsh -NoProfile -File tools/tts/test.ps1
git diff --check
```

TTS 安装在非默认位置时：

```powershell
pwsh -NoProfile -File tools/tts/test.ps1 -TtsManagedPath 'D:/SteamLibrary/steamapps/common/Tabletop Simulator/Tabletop Simulator_Data/Managed'
```

也可设置 `TTS_MANAGED_DIR` 环境变量。缺少游戏 DLL 时，静态检查仍可运行，但不能声称行为测试已通过。

改部队逻辑／图片配置：编辑 `tts/Global.lua` 中 `-- ===== 備隊面板 v2 =====` **之前**的内容。改武将面板：编辑 `tts/modules/commanders.lua`；改地图旗：编辑 `tts/modules/map_flags.lua`。然后运行 `python tools/tts/sync_global.py`，再运行上述检查。详见 [开发与验证](docs/tbs/DEVELOPMENT.md)。

## 已实现与待实现

已实现：十类部队配置、数字图片、士气点击／快捷补满清空、正面耗尽自动翻面、背面耗尽敗走、独立「未／済」、损耗色带、双面部队旗、十二座位武将面板、受伤与有效统率、Description 数据读取与写回。

新增：[交戦／指揮外手动标记](docs/tbs/STATUS_MARKERS.md)的共享状态、存档、点击与双面图片接口已实现。正式图片直链尚空，按用户要求此时不显示、不产生点击区域，也没有文字占位；配置图片后开启。

未实现：完整 RAN 回合／战斗裁决、交戦／指揮外自动判定及规则限制、散開／密集切换、射击准备／装填图标、检测叠放武将后抬升的敗走图标。后续范围见 [设计记录](docs/tbs/DESIGN_BACKLOG.md)。

美术有 **12 类**，运行配置有 **10 类**。`槍武士隊` 与现有 `徒歩武士` 尚需确认对应关系，`近習騎馬隊`、`騎馬鉄砲隊` 尚无已批准的运行数值。详见 [美术关联表](docs/tbs/ASSETS.md)。

本次验证和实机限制记录在 [VALIDATION.md](docs/tbs/VALIDATION.md)。旧文件保存在 `tts/archive/`、`docs/tbs/history/`，仅供追溯，不作为当前安装入口。

## 协作与素材

两个 Codex 使用各自工作分支，通过 PR 合并到 `main`。本次导入分支为 `import/tbs-code-and-docs`，不会直接推送 main。`troop-cards-download` 是专用图片下载分支，不用于代码开发，不修改其内容或历史。

保留现有素材、文件名和下载入口。素材字体、制作与来源说明继续以各素材目录 README 为准；本次未重新生成、替换或重新授权第三方素材。未发布第三方 RAN 规则全文与 TTS 游戏程序集。
