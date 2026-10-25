# 验证记录

## 当前版本：v2.18.2（2026-10-25）

本次将底部图框进一步放大为420×210，并将交戦／指揮外各下移10。保留图片直链及现有状态逻辑。运行 `tools/tts/test.ps1`：完整Global 4750项、独立面板1168项，共5918项MoonSharp行为检查通过，生成XML、按钮、回调和事件检查通过。`tools/tts/validate.py`通过，包含源码同步、发布TXT字节一致和静态配置检查。

更新既有几何检查，覆盖正反面图片与点击范围、指揮外独立宽高及Y坐标、非等比缩放与图片原比例。未在TTS实机运行斜视角、武将叠放和多人联机验收。详见 [UNIT_MODES.md](UNIT_MODES.md)、[STATUS_MARKERS.md](STATUS_MARKERS.md)；此前敗走功能见 [ROUT_OVERLAY.md](ROUT_OVERLAY.md)。

## 历史记录：v2.14.11初始导入

日期：2026-10-21。代码：v2.14.11。基线main：`8c7aaa731f124eb693a23800402a65033806975f`。

## 已执行并通过

| 检查 | 结果 |
| --- | --- |
| `python tools/tts/sync_global.py --check` | 地图旗、武将面板、完整Global同步；发布TXT与Global字节一致 |
| `python tools/tts/validate.py --verify-import` | Python语法、26份JSON、10类唯一兵种标签、0～8两套数字图键、事件入口检查通过 |
| 导入来源校验 | 84个导入文件的SHA256通过；游戏Lua和测试原样导入，两个工具仅适配仓库路径／入口 |
| `pwsh -NoProfile -File tools/tts/test.ps1` | 独立武将面板1168项、完整Global3208项行为检查通过，共4376项 |
| 同一PowerShell测试中的XML检查 | 实际生成的面板XML、按钮、ID、回调及事件检查通过 |
| 美术／原工具保护检查 | 三个素材目录与`tools/photoshop`相对基线没有变更；96张成品，12类各8色 |
| 当前文档链接与差异格式 | 当前说明中的本地文档链接可解析；差异检查按下述原样导入换行约定执行 |
| 凭据模式检查 | 导入代码、文档、测试与工具中未检出常见GitHub令牌、AWS访问密钥、私钥或OpenAI密钥模式；这不是完整安全审计 |

行为测试使用本机已安装TTS中的MoonSharp和模拟物件API；没有提交游戏DLL。Python检查使用标准库。未增加或运行与此次文本／路径迁移无关的游戏功能测试。

导入原稿含CRLF及13处文件末尾空行。为保留来源字节和SHA256，`.gitattributes`仅对原样导入路径接受CRLF和末尾空行，仍检查其他行末空白；没有为格式检查重写游戏代码或历史资料。

基线文件路径、Git blob和目录tree哈希见 [asset-inventory.json](asset-inventory.json)，导入原文件和目标文件SHA256见 [import-sources.json](import-sources.json)。稀疏检出没有把全部美术下载到工作盘，但Git索引及本次提交保留原有blob；完整性检查不依赖重新生成PNG。

## 不能据此宣称通过的内容

- 此次没有在实际TTS窗口重新操作整场游戏，没有运行GPU渲染、多人联机、倾斜视角或叠放遮挡验收。
- 没有逐个重新下载云端图片；URL配置原样保留，云端可用性须在实际客户端检查。
- 没有最新完整TTS场景可用于一键复现所有物件、Description、Tags、GUID和局部脚本。
- 尚未实现的新状态／完整RAN回合不属于通过范围。下一位开发者应按 [DEVELOPMENT.md](DEVELOPMENT.md) 的实机清单验收。

`--verify-import`记录的是本次导入基线。后续开发更改源码后仍运行普通静态／行为检查；不能为通过历史来源核验而重写原始哈希。
