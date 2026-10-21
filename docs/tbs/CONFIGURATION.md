# 当前配置与操作（v2.15.0）

本页以已保存的 Lua 为准。`history/` 的旧指南可能描述已经替换的显示方式。

交戦／指揮外：在 Global 顶部 `UNIT_STATUS_IMAGES` 配置两张正式图片直链后，左键顶栏两端图标切换；未配置时完全隐藏，右键不切换。正反面共享、所有玩家可操作、存档保存；不自动改士气或移动。布局与美术接口见 [STATUS_MARKERS.md](STATUS_MARKERS.md)。

## 部队：Tags

每枚部队只添加一个兵种标签。Tags 中不写 `tag=`。数量和所属标签可以并存。

| 兵种 | Tag | 正面士气／移动 | 背面士气／移动 |
| --- | --- | --- | --- |
| 長柄足軽（三间枪） | `unit_nagaye_ashigaru` | 6／4 | 5／3 |
| 騎馬武士 | `unit_kiba_samurai` | 8／6 | 7／5 |
| 徒歩武士 | `unit_kachi_samurai` | 8／4 | 7／3 |
| 槍足軽（用户称持枪足轻） | `unit_yari_ashigaru` | 5／4 | 4／3 |
| 弓足軽 | `unit_yumi_ashigaru` | 4／5 | 3／4 |
| 弓僧兵 | `unit_yumi_sohei` | 4／5 | 4／4 |
| 鉄砲足軽 | `unit_teppo_ashigaru` | 3／4 | 2／3 |
| 鉄砲僧兵 | `unit_teppo_sohei` | 3／4 | 3／3 |
| 赤備騎馬 | `unit_akazonae_kiba` | 8／6 | 8／6 |
| 南蛮大筒 | `unit_nanban_ozutsu` | 2／2 | 1／1 |

数量标签：`count_100`、`count_200`、`count_300`、`count_400`，对应显示 1、2、3、4。单位「百人」已经在底图中；未指定时显示1。数量没有点击加减，移动力按当前面配置固定，不可点击增减。

所属備隊标签：`ota_honjin`、`iwatsuke_shu`、`edo_shu`、`matsuyama_shu`。新備隊使用 `sg_team_<team ID>`。所属标签优先于 Description 的 `team`；每枚只用一个所属标签。

例如一枚本陣200人的长枪足轻，三个 Tags 分别为：

```text
unit_nagaye_ashigaru
count_200
ota_honjin
```

也兼容 Description 中的 `team=ota_honjin`、`role=unit`；这两行不代替 `unit_*` 兵种 Tag。

## 武将：Description

逐行 `key=value`，不用引号。以下可直接作为主将资料模板；图片留空表示尚未提供，不是示例网址：

```text
team=ota_honjin
role=main
name=太田資正
birth=1522
command=5
image=
flag_image=
status=無傷
title=備大将
formation=太田家 本陣
order=防御
```

| 字段 | 格式与含义 |
| --- | --- |
| `team` | 同隊一致的英文 ID。自编隊推荐英文字母、数字、下划线、连字符。 |
| `role` | `main`、`deputy1`、`deputy2`；每隊每个角色只能一个。 |
| `name`、`title` | 姓名／职务显示。 |
| `birth` | 生年，年龄按 `1563-birth` 计算。 |
| `command` | 原始统率1～6；伤势不会改写此值。 |
| `image` | 画像直链；空值可回退内置默认，当前内置画像均为空；`-` 明确禁用。 |
| `flag_image` 或 `陣旗` | 主将填写本隊旗 URL。空值／`-` 隐藏；不从副将读取。 |
| `status` | `無傷`、`浅手`、`深手`、`討死`。兼容旧值健康、軽傷、重傷、陣没。 |
| `formation` | 主将的備隊显示名称。 |
| `order` | 主将的攻撃、防御、機動、再編，仅记录与显示命令。 |
| `acted_image` | 遗留字段，忽略；全武将使用统一済印。 |

URL 推荐直接从 TTS Cloud Manager 复制，使用完整 `https://...` 纯直链。不要填写 Markdown 的 `[地址](地址)` 包装、网页分享页或依赖本机盘符；这些不能作为联机可用的图片地址。

| 状态 | 有效统率 | 机动 | 表现 |
| --- | --- | --- | --- |
| 無傷 | 原始值 | 9 | 绿色状态 |
| 浅手 | 原始值 | 4 | 较浅红色、伤势角标 |
| 深手 | 原始值−1，最低0 | 4 | 深红、画像压暗、失效格X |
| 討死 | X | — | 全部失效格X、卡片和画像压暗；非真正灰度转换 |

状态按钮所有玩家都能点击，直接写回 Description；主将及两副将的行动由各自令牌翻面决定。正面未，背面済，与部队的独立行动布尔值不同。

## 内置初始人物

这些是项目已有设定，非本次重新考证的史实资料。Description 有效值优先。

| team | main（生年／统率） | deputy1 | deputy2 |
| --- | --- | --- | --- |
| ota_honjin | 太田資正 1522／5 | 三戸興義 1525／2 | 太田御前 1544／2 |
| iwatsuke_shu | 太田資房 1542／2 | 小宮山忠孝 1533／2 | **高築道叶** 1523／2 |
| edo_shu | 太田康資 1531／3 | 宮城政業 1495／2 | 舎人重長 1532／2 |
| matsuyama_shu | 梶原政景 1548／4 | 広沢信秀 1543／2 | **比企政員** 1538／2 |

## 点击、回合与保存

- 士气数字：左键+1、右键−1。每位玩家先在 Options → Game Keys 绑定「士気快捷調整」为Ctrl，再用Ctrl+左键补满并解除敗走，Ctrl+右键清空。
- 正面耗尽转背面满值；背面耗尽敗走。若敗走后手动翻回正面再快捷补满，会同时修复为0的背面储备，避免仍被判敗走；其他尚有士气的一面保留。
- 右上角行动图可点击切换，翻面和恢复士气不改变其值。
- 没有自动下一回合、射击次数、交战或指挥范围裁决。不要把「済」当成所有 RAN 行动都被禁止。
- 背面数字和旗需要加载图片；缺数字／行动图片时透明按钮仍工作但不显示文字回退。
- 修改姓名／状态可等待面板刷新；换 team、role、Tags 后点「更新」重建索引，必要时 Save & Play。
- 保存完整 TTS 游戏才能一起保留 Global 状态、Description、Tags、底图和物件朝向。单独复制 Lua 不包含每枚令牌的数据。
