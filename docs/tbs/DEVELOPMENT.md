# 开发与验证

## 源码关系

这是对既有Lua工程的整理，不是重写。全量入口 `tts/Global.lua` 的部队前缀本身就是源代码。不要删除它再期待工具从零生成。

```text
map_flags.lua ──注入──> commanders.lua（保留独立事件包装）
                               │ 去掉独立事件包装
Global.lua的部队前缀 ───────────┴──> Global.lua完整脚本 ──字节复制──> releases/Global_v*.txt
```

各自源文件的标记只有一个：`BEGIN/END MAP FLAGS MODULE`、`BEGIN STANDALONE EVENTS`、`===== 備隊面板 v2 =====`。同步器验证边界，重复／丢失时拒绝执行，防止静默截断。

- 部队逻辑、图片常量、UNIT_CONFIGS：修改Global分隔符之前。
- 武将XML／资料：修改commanders，但地图旗标记区由map_flags覆盖。
- 地图旗：只修改map_flags。
- 更新版本时先改commanders的第一行版本和更新日，同步器更新Global头部与相应版本的TXT。

```powershell
python tools/tts/sync_global.py
python tools/tts/sync_global.py --check
python tools/tts/validate.py
pwsh -NoProfile -File tools/tts/test.ps1
git diff --check
```

`--check`不写文件；不带参数会同步源文件并生成当前版本完整TXT。仓库保留导入Lua的原有换行，避免仅因迁移造成全文件差异。

## 依赖

Python3.10+只有标准库。PowerShell测试从TTS安装目录读取MoonSharp，支持 `-TtsManagedPath` 或 `TTS_MANAGED_DIR`；默认Windows Steam安装路径。不需要游戏进程运行，不加载游戏存档，不发送网络命令，不安装／提交游戏DLL。

测试入口保留既有断言：解析实际生成的十二座位XML，检查按钮／ID／回调／事件唯一性，执行模拟物件上的状态、计数、翻面、按键隔离、加载重试、资源与清理行为。独立面板只测一份，原来的简体文件名别名是字节相同的重复件，未再保留第二份。

`validate.py --verify-import` 是本次导入专用验收：验证原样导入文件的来源哈希、既有素材目录和Photoshop工具相对导入基线未变。未来正常开发改变Lua后，此模式可能失败；不要为绕过检查改写原始来源哈希。普通开发运行不带该参数的静态检查。

## 必须在TTS中另行验证的内容

1. 用完整Global Save & Play，确认无红色报错；新棋子与原存档均可识别。
2. 正背面右栏、阵旗、行动和损耗带在俯视／倾斜／缩放时正常；前黑字、后象牙白字。
3. 普通左右键与Ctrl快捷操作，正面归零翻面、背面归零敗走、补满解除敗走，行动不被重置。
4. 两名玩家分别点击，面板查看互不干扰，物件状态同步；换座／离线不残留按住快捷键状态。
5. 武将状态循环、深手统率−1、姓名校正与指向提示；Description写回后存档重载仍正确。
6. 本隊旗、空图片、失效URL、新物件加载、进出袋和复制物件均无错误清理其他脚本UI。
7. 若改新状态图标／悬浮高度，再测有无武将叠放、棋子密集排列、邻棋遮挡和鼠标穿透。

模拟测试不证明图片云端可访问、GPU排序正确或联机无冲突。真实灰度图、完整场景、自动回合均未实现，不应被列为验收已通过。
