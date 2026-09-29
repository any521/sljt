# 《阿卡姆号》项目交接文档 —— 给下一个 AI

> 写于当前会话末尾。上下文窗口快满了，所以把**所有踩过的坑、测量数据、当前状态、下一步**都写在这里。
> 请**先通读第 1、2、7 章**再动手——第 7 章能帮你避开 10 个已经付过代价的坑。

---

## 1. 项目概况与本机固定路径

| 项 | 值 |
|---|---|
| 项目名 | **阿卡姆号**（`project.godot` 里 `config/name`，窗口标题同） |
| 项目路径 | `D:\Huailxgame` |
| 引擎 | **Godot 4.7.2 stable**（GDScript，无 C#） |
| Godot 可执行文件 | `C:\Users\hp\devtools\godot\Godot_v4.7.2-stable_win64.exe` |
| Aseprite | `D:\BaiduNetdiskDownload\Aseprite\Aseprite\Aseprite\aseprite.exe`（v1.3.18.2） |
| 3D 归档区 | `D:\Huailxgame_3d_archived`（1.3 GB，已全部移出项目） |
| 项目总体积 | 约 **26 MB**（含 `.godot` 缓存 11.4 MB） |

**类型**：科幻克苏鲁卡牌构筑 Roguelite，**纯 2D**，PC/Steam，目标是 Early Access。

**设定（已锁定，勿改）**
- 舞台：空间站 **阿卡姆号**；最终目的地 **拉莱耶**
- 怪物统一叫 **眷族**
- 主角 **沈明砚**（右手/前臂异化，**不戴头盔**，要能演表情）
- 同伴 **宋梅**（生物学家，**没有任何感染痕迹**——她是全场唯一完全正常的人，这是叙事支点）
- 眷族视觉母题：**「金属还在，但被从内部撑开了」**（宇航服还在、头盔裂开、里面没有人）
- 美术基调见 `docs/阿卡姆号-美术基调-v1.0.md`：**UI 永远是工程系冷青（route A），即使卡是异化系**——「UI 是人的最后一道防线」

---

## 2. 如何运行 / 验证（每次改完必做）

### 2.1 铁律：不要用 pwsh/bash 启动 Godot

Godot 启动时要往**用户主目录**写 `user://` 日志和配置。文件沙箱会拦截这些写入，导致 `godot --headless` 直接 **signal 11 段错误**。
**必须**走 `godot_*` 工具（它们通过不受沙箱约束的 subprocess 服务启动）：

| 目的 | 工具 |
|---|---|
| 交互式跑游戏 | `godot_run_project` |
| 跑无头脚本/测试 | `godot_run_headless` |
| 静态校验单个脚本 | `godot_validate_script` |
| 停止（仅限自己启动的实例） | `godot_stop_project` |
| 游戏内交互（截图/查属性/eval） | `godot_command` |

**唯一的例外**：`--import` 没有对应的 godot_* 工具，只能用 pwsh 跑（当前沙箱是 danger-full-access，可以）：

```powershell
& 'C:\Users\hp\devtools\godot\Godot_v4.7.2-stable_win64.exe' --headless --path 'D:\Huailxgame' --import
```

**新增/移动素材后一定要跑一次 `--import`**，否则 `ResourceLoader.exists()` 返回 false，代码会静默走 fallback（背景不显示、精灵不加载）。

### 2.2 两个测试脚本

```powershell
# 核心逻辑（当前 112 项，必须全绿）
godot_run_headless  script=tests/test_combat.gd

# 回合循环 / 发牌回归（6 回合，必须全 OK）
godot_run_headless  script=tests/test_turn_loop.gd
```

当前状态：**112/112 通过**；回合循环 1~5 全部正常补牌，第 6 回合因战斗结束而停止（探针已正确识别，不算失败）。另有表现集成测试 31 项。

### 2.3 `godot_command eval` 的致命注意事项 ⚠️

**绝对不要在 eval 里写 `for` / `while` 循环。** 已经因此把交互服务搞挂过**两次**，每次都中断了正在玩的人。

安全写法：单表达式，或 `var x = ...; return {...}` 这种两三句无控制流的。
需要遍历时用 `Array.map()` + `min()/max()` 这类调用：

```gdscript
var cv = get_tree().root.find_child("CombatView", true, false)
var alphas = cv.card_views.map(func(v): return snappedf(v.modulate.a, 0.01))
return {"min": alphas.min(), "alphas": str(alphas)}
```

**另外**：`key_press` 注入的按键**匹配不上** `physical_keycode` 绑定的输入动作（`end_turn` 绑的是 physical_keycode 32）。要程序化结束回合，直接调方法：

```gdscript
cv._on_end_turn_pressed()      # 异步函数，不用 await 也会继续跑
```

**还有**：`wait` 命令的 `ms` 参数不生效（只等了 1 帧）。要等动画，用 pwsh `Start-Sleep` 再发下一个 eval。

---

## 3. 目录结构与文件职责

```
D:\Huailxgame\
├── project.godot              主场景 res://scenes/main.tscn；stretch=disabled；blender 导入已禁用
├── scenes\main.tscn           游戏入口场景
├── scenes\battle_world_2d.tscn 战斗世界组合场景
├── scenes\actors\             主角、队友和敌人的独立角色场景
├── scenes\environment\        灯光、体积光和雾效场景
├── scenes\ui\                 HUD、手牌层和弹窗层场景
├── scenes\widgets\            可复用卡牌场景
├── src\
│   ├── core\                  ★ 纯逻辑层，禁止依赖任何 UI/场景
│   │   ├── card_instance.gd       卡牌运行时实例（费用/异化/uid）
│   │   ├── combat_manager.gd      战斗总控（回合、能量、手牌、抽弃堆、敌人意图）17 KB
│   │   ├── damage_pipeline.gd     伤害计算（力量/虚弱/易伤/回响倍率/格挡）
│   │   ├── echo_system.gd         回声连击（streak / multiplier / predict / required_faction）
│   │   └── isolation_system.gd    隔离值 0~10 与阈值 3/6/8/10
│   ├── data\
│   │   ├── card_data.gd           卡牌静态定义
│   │   └── enemy_data.gd          敌人定义 + 意图序列
│   ├── autoload\
│   │   ├── card_db.gd             卡池/敌池（19 张卡、2 个敌人）
│   │   └── card_art.gd            卡面精灵表读取（cards_art.png + .json）
│   └── ui\                    ★ 表现层
│       ├── main.gd
│       ├── combat_view.gd         ★ 全部战斗 UI（~1180 行）。绝对定位 + 快照驱动
│       ├── world\
│       │   ├── battle_world_2d.gd ★ 2D 战斗场景（背景 + 角色摆位）
│       │   └── battle_actor_2d.gd ★ 2D 角色（AnimatedSprite2D，序列帧/单图统一）
│       ├── widgets\
│       │   ├── battle_card.gd     ★ 卡牌控件（用图片卡框 card_frame_225.png）
│       │   └── battle_actor.gd    （Codex 遗留，当前未被使用）
│       └── effects\
│           ├── juice.gd           打击感（trauma 抖动/顿帧/粒子/音效/无障碍开关）
│           └── shaders\           hit_flash / outline 等着色器
├── assets\
│   ├── art\
│   │   ├── battle\
│   │   │   ├── biolab_backdrop.png    ★ 当前战斗背景 1670x941
│   │   │   └── particles\             8 个粒子贴图
│   │   ├── cards\
│   │   │   ├── cards_art.png          卡面精灵表 256x96（8x3 格，每格 32x32）
│   │   │   ├── cards_art.json         每张卡在表里的坐标
│   │   │   ├── card_frame_ai.png      原始卡框 300x396
│   │   │   └── card_frame_225.png     ★ 在用（0.75 倍高保真缩放，比例严格一致）
│   │   ├── characters\
│   │   │   ├── shen_mingyan\          主角（battle_infected_512x384.png 为 4x3 序列帧）
│   │   │   └── song_mei\              宋梅（battle_512x384.png 为 4x3 序列帧）
│   │   ├── enemies\kin_attached_512.png   眷族（184x364 静态单图）
│   │   ├── ui\arkham_25d\             旧版生成 SVG（已停用，仅保留历史参考）
│   │   ├── reference\                 版式标注、blockout 参考图
│   │   └── incoming_0927\             ★★ 本次新移入的 23 个原画（见第 8 章）
│   └── audio\                     34 个 WAV 音效
├── docs\
│   ├── 阿卡姆号-策划案-v2.1.md
│   ├── 阿卡姆号-美术基调-v1.0.md      ★ 美术硬约束，改美术前必读
│   ├── RikaAI-使用规范.md             ★ 生成角色序列帧的提示词规范
│   ├── 交接文档-战斗表现升级.md        （此前给 Codex 的 37 KB 文档）
│   ├── 战斗UI-2.5D版式与素材规范.md
│   └── verification\                  最终截图 + 3 个基线文件
├── tests\  test_combat.gd(107项) / test_turn_loop.gd / test_presentation.gd
└── tools\  Aseprite Lua 脚本（去底/裁切/生成卡面与序列帧）
```

---

## 4. 架构契约（改动前必读）

### 4.1 分层

- **`src/core/` 是纯逻辑**，不 import 任何 UI。任何规则改动都要能通过 `tests/test_combat.gd` 验证。
- **`src/ui/` 只做表现**，不写规则。
- **`src/autoload/`** 是全局单例（`CardDB` / `CardArt`）。

### 4.2 UI 的数据流：快照驱动

`CombatView` **不是**逐帧读 `CombatManager` 的字段，而是：

```
CombatManager 发出信号 (hand_changed / energy_changed / enemy_acted ...)
      ↓
CombatView._record(...) 把信号录进 _events
      ↓
_on_end_turn_pressed() 里：_recording = true → combat.end_turn() → _recording = false
      ↓
await _replay_events(epoch)   把录制的事件按顺序「重放」成动画
      ↓
_apply_snapshot(_take_snapshot())   最后统一刷新 UI
```

**理解这一点很重要**：结束回合时 `_sync_hand()` 会被调用**两次**（`_replay_events` 内一次 + 末尾一次），这曾经导致过一个很难查的 bug（见 7.4）。

### 4.3 `BattleWorld2D` 与 `CombatView` 的接口契约

`battle_world_2d.gd` 必须提供（`combat_view.gd` 依赖）：

```gdscript
var camera                       # ★ 必须为 null（见 7.3）
var player_actor: Node
var companion_actor: Node
var enemy_actors: Array
func build() -> void
func player_screen_point() -> Vector2
func enemy_screen_point(i: int) -> Vector2
func get_enemy_actor(i: int) -> Node
```

`battle_actor_2d.gd` 必须提供：
```gdscript
var animated: bool
func highlight(active: bool)
func hit(large: bool, reduced_flash: bool, allow_motion := true)
func die(allow_motion := true)
func attack_motion(allow_motion := true)
func reset_actor()
func mark_base_position()
# 节点自身：size（角色实际占用矩形）、position（左上角）
```

---

## 5. 战斗规则（已锁定）

### 5.1 回声连击
- 交替打出 **工程/规程** 与 **异化/变异** 归属的卡 → 连击 +1
- 倍率：`1.0 / 1.15 / 1.30 / 1.50 / 1.75 / 2.0`（连击 5 封顶）
- 打出同归属 → 连击清零；**中立牌不打断**
- 回合结束连击归零
- 3 连击后攻击额外抽牌

### 5.2 隔离值 0~10
- 阈值 **3 / 6 / 8 / 10**：皮下蔓延 / 组织共生 / 意识让渡 / **同化**
- 达到 10 即同化 —— **同化算「胜利」**（不是失败）
- 阈值 6：每回合结束失去 2 生命，但回合开始 +1 力量
- 阈值 8：变异牌费用 −1

### 5.3 死亡规则：**重塑无代价**
爬塔类 Roguelite 的驱动力不来自「死亡有代价」，而来自「永久成长」。**不要加死亡惩罚。**
Organ 的用途只有两个：**战斗奖励** 和 **经济**。「血肉争夺」那套张力已删除。

### 5.4 当前范围：**只做 Stage 1**

---

## 6. 2D 战斗场景实现细节

### 6.1 坐标系统：站位用「背景图像素坐标」书写

`battle_world_2d.gd` 里站位**不是**屏幕坐标，而是背景图上的像素坐标：

```gdscript
const BACKDROP_SRC := Vector2(1670.0, 941.0)
const ALLY_FEET_SRC  := Vector2(474.0, 566.0)   # 宋梅（后排）
const HERO_FEET_SRC  := Vector2(600.0, 606.0)   # 主角（前排）
const ENEMY_FEET_SRC := [Vector2(1200.0, 572.0), Vector2(1320.0, 576.0)]
```

运行时按背景 `STRETCH_KEEP_ASPECT_COVERED` 的同一套变换换算：

```gdscript
func _src_to_screen(p: Vector2) -> Vector2:
    var vp := get_viewport_rect().size
    var k := maxf(vp.x / BACKDROP_SRC.x, vp.y / BACKDROP_SRC.y)
    return p * k + (vp - BACKDROP_SRC * k) * 0.5
```

**好处**：换背景图、改分辨率都不用重算站位。**y 就是进深**——y 越小＝越远＝越靠后。

当前换算结果（视口 1920×1055）：
| 角色 | 脚底屏幕坐标 |
|---|---|
| 宋梅（后排） | (545.0, 637.3) |
| 眷族 0 / 1 | (1379.6, 644.2) / (1517.6, 648.8) |
| 沈明砚（前排） | (689.8, 683.3) |

### 6.2 角色：统一用 `AnimatedSprite2D`

`battle_actor_2d.gd` 有两个入口，走同一条代码路径：

```gdscript
# 序列帧：cols x rows 网格，content 是「全帧并集包围盒」
setup_sheet(tex_path, cols, rows, cell, content, px_scale, fps, facing_left)

# 静态单图：等于只有 1 帧
setup_sprite(tex_path, target_height, facing_left)
```

**为什么不用 TextureRect**：见 7.2。

**镜像补偿**（`flip_h` 是绕节点原点镜像的）：
```gdscript
if p_facing_left:
    sprite.position = Vector2(content.end.x, -content.position.y) * px_scale
else:
    sprite.position = Vector2(-content.position.x, -content.position.y) * px_scale
```

### 6.3 像素密度（「像素质感是否统一」的根本）

屏幕每格点像素 = `px_scale × 素材原生格点`

| 角色 | 素材 | 内容/并集包围盒 | 原生格点 | px_scale | 屏幕高度 | 每格点屏幕像素 |
|---|---|---|---|---|---|---|
| 沈明砚 | `battle_infected_512x384.png` 4×3 | `Rect2(30,34,91,92)` | 2 px | 3.5 | 322 | **7.0** |
| 宋梅 | `song_mei/battle_512x384.png` 4×3 | `Rect2(45,44,29,47)` | 2 px | 4.5 | 212 | **9.0** |
| 眷族 | `kin_attached_512.png` 静态 | `184×364` | 4 px | — | 320 | **3.5** |

**这三个数字不一致，是素材本身造成的**（三张图生成时就不是同一套规格），不是代码 bug。详见第 8/9 章。

### 6.4 视口与 1:1 像素

`project.godot`：
```
window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="disabled"      ← 已改为 disabled
```

- 物理窗口是 **1920×1055**（1080 屏减去任务栏/边框），逻辑尺寸也是 1920×1055 → **1:1，像素不缩放**
- 之前是 `canvas_items + expand`，逻辑画布被撑成 1965×1080 再按 **0.977** 非整数缩回物理分辨率 → 像素画采样抖动
- ⚠️ 因为窗口只有 1055 高（比设计稿 1080 少 25px），**底部元素要特别当心被切**（见 7.6）

---

## 7. 踩过的坑（血泪清单）★ 改代码前必读

### 7.1 `.blend` 文件会打断**整个**导入队列

**现象**：新增的 PNG/SVG 全都不生成 `.import`，`ResourceLoader.exists()` 返回 false，背景不显示。日志里 `_update_scan_actions` 列完待导入文件后，**导入阶段整个消失**，直接跳到 `loading_editor_layout`。

**根因**：项目里有个 `biolab_precision_modules.blend`，Godot 的 Blender 导入器抛错并**中断了整个重导入队列**——不只是那个 .blend，所有文件都没导入。

**修法**：`project.godot` 里
```
[filesystem]
import/blender/enabled=false
```
并且**3D 资产已全部移出项目**（`D:\Huailxgame_3d_archived`）。这个设置保留做双保险。

> 症状极隐蔽：不是「某个文件导入失败」，而是「全部文件静默不导入」，日志里只有一行 Blender 报错。

### 7.2 `TextureRect` 的最小尺寸钳制 —— 像素精灵必须用 `Sprite2D`

**现象**：明明设了 `size = (163, 300)`，精灵却按贴图原始尺寸 298×550 渲染，脚底位置整个沉下去。

**根因**：`Control.size` 的 setter 会**向上钳制到 `get_combined_minimum_size()`**。`TextureRect` 的最小尺寸默认是贴图原始尺寸。
**改了顺序（先设 `expand_mode = EXPAND_IGNORE_SIZE` 再设 `size`）也没用**——运行时查 `expand_mode` 确实是 1，但 `size` 依然被顶成 298×550，说明钳制发生在**入树之前**。

**修法**：**角色一律用 `AnimatedSprite2D`**（用 `scale` 缩放，没有最小尺寸概念）。单张静态图也包装成「只有 1 帧的动画」，保持一条代码路径。

### 7.3 背景整个不显示 —— `world.size` 在 `_ready()` 里是 (0,0)

**现象**：背景图不渲染，但角色精灵正常显示（所以很容易误判为「资源没导入」）。

**根因**：`combat_view.gd` 在 `_ready()` 里执行 `world.size = size`，那一刻父容器**还没跑布局**，`size` 还是 `(0,0)`。于是 `world` → `battle_world` → 背景 `TextureRect`（用 FULL_RECT 锚点）全被算成 **0×0**。
角色用的是绝对 `position`，不受父节点尺寸影响，所以照常显示。

**修法**：背景**不用锚点**，按视口尺寸显式铺满，并在视口变化时重算：

```gdscript
backdrop.set_anchors_preset(Control.PRESET_TOP_LEFT)
add_child(backdrop)
_fit_backdrop()
get_viewport().size_changed.connect(_fit_backdrop)

func _fit_backdrop() -> void:
    backdrop.position = Vector2.ZERO
    backdrop.size = get_viewport_rect().size
```

### 7.4 手牌「消失」/「不再补充」—— 双重根因

**现象**：结束回合后手牌空了或只剩几张，看起来像「第二回合不再发牌」。但核心逻辑完全正常（`tests/test_turn_loop.gd` 实测 1~5 回合都补满 5 张）。

**根因（两层，都已修）**：

1. `_on_end_turn_pressed` 的**弃牌动画**把所有牌的 `modulate:a → 0.0`。
2. `_sync_hand` 结束时**无条件** `_draw_generation += 1`。新牌先被设成 `modulate.a = 0.0` 再靠 tween 飞到 1.0；`_draw_card_step` 里 `generation != _draw_generation` 就直接 `return`，**不恢复 alpha**。

结束回合时 `_sync_hand` 被调用两次 → 第二轮把第一轮的飞牌动画顶掉 → 那批牌的 alpha 永久停在 0（牌在手里，只是完全透明）。牌洗回牌堆再抽回来时会**按 uid 复用同一个 view**，所以这个 alpha 会一直带着。

**修法**（`combat_view.gd`）：

```gdscript
# _sync_hand 里：保留下来的牌强制恢复可见
for view in card_views:
    if not fresh.has(view):
        view.modulate.a = 1.0

# 只有真有新牌要飞进来时才自增
if animate_new and juice.enabled("card_animations") and not fresh.is_empty():
    _draw_generation += 1

# _draw_card_step 里：动画被顶掉时也要恢复可见
if generation != _draw_generation:
    view.modulate.a = 1.0
    view.position = view.home
    view.scale = Vector2.ONE * CARD_BASE_SCALE
    return
```

> 这个修复**同时实现了用户要的手感**：留场的牌待在原位不动，只有真正的新牌才飞进来。
> **验证方法**：连续结束两个回合，第二个回合才会走「洗牌复用」路径。
> `eval` 检查 `cv.combat.hand.size() == cv.card_views.size()` 且所有 `modulate.a == 1.0`。

### 7.5 非整数缩放的像素抖动 —— `stretch/mode` 改 `disabled`

原配置 `canvas_items + expand`：基准 1920×1080，但窗口只有 1920×1055，于是逻辑画布被撑成 **1965×1080**，再按 **0.977** 缩回物理分辨率。0.977 不是整数 → 像素画采样抖动。
**已改为 `window/stretch/mode="disabled"`**：逻辑 = 物理 = 1920×1055，1:1。

### 7.6 窗口只有 1055 高 → 底部元素被切 26px

设计稿按 1080 写，实际窗口 1055。已处理：
- 手牌区整块上移 28px：`card_tray` y=766、`hand_box` y=758（因为扇形最外侧的牌还会下沉 18px）
- `_hint_label` 从 y=1044 挪到 y=734

**新增底部元素时务必检查 y + 高度 ≤ 1055。**

### 7.7 敌人热区与贴图错位 37px

**根因**：热区用**写死的偏移量** `target.position = center - Vector2(70, 155)`、`size = Vector2(140, 300)`，而 `center` 只比脚底高 182、精灵高 320 —— 两者差了 37px。表现是「点不到怪物 / 拖牌判定的位置和贴图对不上」。

**修法**：直接取角色节点自身的矩形，别再手写偏移：
```gdscript
target.position = actor.position
target.size = actor.size
```

### 7.8 意图面板宽度 > 敌人间距 → 两个面板叠在一起

敌人间距只有 ~138px，而 Codex 原代码用 290px 宽的意图面板 → 直接糊成一片。
**当前修法**：意图图标由 `pixel_frame.gd` 在固定 4×4 屏幕像素网格上绘制，配合紧凑文字在角色头顶竖排；旧 SVG 已不参与运行时显示。

### 7.9 `assets/art/characters/song_mei/sprite_512.png` 是 512×512 画布，真人只有 96×188

周围全是透明边距，按画布摆放必然又小又错位。已裁出 `battle_idle.png`（96×188，原图保留）。

**通用教训**：用之前一定要测 **alpha 并集包围盒**，不要相信画布尺寸。

### 7.10 其他零碎但重要的

- **`key_press` 注入的按键匹配不上 `physical_keycode` 绑定的输入动作**（`end_turn` 绑的是 physical_keycode 32）。程序化结束回合请直接调 `cv._on_end_turn_pressed()`。
- **`godot_command wait` 的 `ms` 参数无效**（只等 1 帧）。等动画用 pwsh `Start-Sleep`。
- **素材路径被移动后，检查有没有孤立 `.import`**：`a.png.import` 存在但 `a.png` 不在 → Godot 会报错。
- **改完脚本必须 `godot_validate_script`**，这个项目对缩进（tab）敏感。
- **Aseprite 命令行传参**：`app.params` 从 CLI **不生效**（参数会被当文件名），要在 Lua 脚本里硬编码路径列表。

---

## 8. 本次新移入的素材：`assets/art/incoming_0927/`（23 个）

> 来源：`C:\Users\hp\Downloads` 中**创建时间 2026-09-27** 的全部 PNG，**移动**（非复制）过来，共 7.36 MB。
> Downloads 里已清空。

### 8.1 ★★★ 最有价值的两个（项目里完全没有）

| 文件 | 尺寸 | 切分 | 说明 |
|---|---|---|---|
| **`眷族1号小人战斗待机.png`** | 512×384 | **4×3 = 12 帧** | **眷族的待机动画！** 项目里眷族一直是**静态单图**，这是唯一能让怪物动起来的素材 |
| **`沈明拔枪射击序列帧.png`** | 512×384 | **4×3 = 12 帧** | **主角的拔枪射击（攻击）动画**。当前 `attack_motion()` 只有程序化位移，没有帧动画 |

> ⚠️ **这两个是实心底色，不能直接用**（见 8.4）。先用 Aseprite 去底再接入。

### 8.2 与项目中已有文件**字节级完全相同**（重复，可安全删除）

| incoming 文件 | 等同于项目里的 |
|---|---|
| `战斗场景1号.png` | `assets/art/battle/biolab_backdrop.png` |
| `场景分布图.png` | `assets/art/reference/scene_layout_annotated.png` |
| `沈明砚战斗序列帧.png` | `assets/art/characters/shen_mingyan/battle_infected_512x384.png` |
| `2d感染后沈明砚.png` | `assets/art/characters/shen_mingyan/_source/sprite_infected_raw.png` |
| `2d宋梅大图.png` | `assets/art/characters/song_mei/sprite_512.png` |

### 8.3 其余素材

| 文件 | 尺寸 | 内容 | 用途建议 |
|---|---|---|---|
| `战斗场景一号精细版.png` | 1671×941 | 全幅 | ★ **比当前背景更精细**，可考虑替换 `biolab_backdrop.png`（比例同为 1.775） |
| `场景2号大图.png` | 2048×1152 | 全幅 | ★ 第二张场景（16:9），可做第二关背景 |
| `工程卡卡面.png` | 512×512 | 298×394 透明 | ★ 工程卡完整卡面，**透明底可直接用** |
| `工程卡卡面小.png` | 128×128 | 不透明 | 缩小版 |
| `沈明立绘.png` | 1024×1536 | 全幅 | 主角立绘大图（标题界面 / 剧情演出） |
| `宋梅立绘.png` / `宋梅立绘大图.png` | 128×128 / 512×512 | 49×109 / 199×445 透明 | 宋梅立绘 |
| `眷族1号小人.png` | 1254×1254 | 不透明 | 眷族原画（**注意**：与 `enemies/_source/kin_attached_raw.png`（512×512）**不是同一张**） |
| `怪物废案.png` | 512×512 | 256×367 透明 | 弃用怪物，勿用 |
| `沈明拔枪射击序列帧废案.png` | 512×384 | 4×3 | 弃用，勿用 |
| `沈明砚感染前战斗序列帧.png` | 512×256 | 4×2 = 8 帧 | 主角「感染前」的帧表（与在用那张 4×2 不同） |
| `宋梅战斗序列帧.png` | 512×384 | 4×3 = 12 帧 | ★ 宋梅帧表（与在用那张**不同**，且在用的那张已去底、这张没有） |
| `2d感染前沈明砚.png` / `2d感染前沈明砚大图.png` | 128 / 512 | | 「感染前」主角小图 |
| `2d宋梅.png` | 128×128 | 22×46 透明 | 宋梅小图（与我在用的紧裁版 `battle_idle.png` 不同，这是原图） |
| `沈明感染前装束小人.png` | 512×512 | 94×199 透明 | 「感染前」装束小图 |

### 8.4 ⚠️ 背景透明度实测（决定能否直接使用）

| 文件 | 角像素 | 全透明占比 | 能否直接用 |
|---|---|---|---|
| `沈明砚战斗序列帧.png` | #000000 a=0 | 92.3% | ✅ 透明底 |
| `工程卡卡面.png` | #000000 a=0 | 57.1% | ✅ 透明底 |
| `沈明砚感染前战斗序列帧.png` | #013B3B a=255 | 37.5% | ⚠️ 部分透明，需检查 |
| **`眷族1号小人战斗待机.png`** | #010000 a=255 | **0.0%** | ❌ **实心黑底，必须先抠** |
| **`沈明拔枪射击序列帧.png`** | #013B3B a=255 | **0.0%** | ❌ **实心深青底，必须先抠** |
| **`宋梅战斗序列帧.png`** | #004041 a=255 | **0.0%** | ❌ **实心深青底，必须先抠** |
| `沈明拔枪射击序列帧废案.png` | #013C3C a=255 | 0.0% | （废案，忽略） |

**去底工具**已经现成：`tools/bg_remove_list.lua`、`tools/clean_infected.lua`（Aseprite Lua 脚本，硬编码路径列表）。
调用方式：`aseprite.exe -b --script tools\bg_remove_list.lua`
> 注意：**从 CLI 传参无效**（`app.params` 拿不到，参数会被当成文件名），路径必须写在脚本里。

**对照**：项目里在用的 `characters/song_mei/battle_512x384.png` 全透明占比 **94.9%** ——说明它当时**已经去过底了**，而用户新给的 `宋梅战斗序列帧.png` 没有。所以「两张不同」很可能只是「去过底 vs 没去底」。

---

## 9. 下一步待办（按优先级）

### P0 —— 让角色真正「动」起来

1. **接入眷族待机动画**（当前怪物是完全静止的静态图）
   - 去底 `incoming_0927/眷族1号小人战斗待机.png`
   - 在 `battle_world_2d.gd` 里把 `ENEMY_SPRITE` 换成帧表，仿照主角的写法：
     ```gdscript
     const ENEMY_SHEET := "res://assets/art/.../眷族待机.png"
     const ENEMY_SHEET_COLS := 4
     const ENEMY_SHEET_ROWS := 3
     const ENEMY_CONTENT := Rect2(?, ?, ?, ?)   # 必须实测全帧并集包围盒
     const ENEMY_PX := ?.?
     ```
   - `_build_actors()` 里 `_spawn_sprite(...)` 换成 `_spawn_sheet(...)`
   - **务必实测并集包围盒**，否则脚底对不齐（测量脚本见 `tools/` 或自己写 pwsh + System.Drawing）

2. **接入主角拔枪射击动画**（攻击时播放）
   - 去底 `沈明拔枪射击序列帧.png`
   - `battle_actor_2d.gd` 目前只播一个 `"idle"` 动画（`SpriteFrames` 只建了这一个）
   - 需要扩展：支持多个动画名（`idle` / `attack` / `hit`），并在 `attack_motion()` 里 `play("attack")` + `await` 播完回 `idle`
   - 当前 `attack_motion()` 是纯程序化位移（预备→前冲→归位），可以保留位移 + 叠加帧动画

### P1 —— 统一像素密度（**素材问题，需要用户决定**）

三张图生成时不是同一套规格（见 6.3）：
- 主角帧表：46 个美术像素高，**2px 原生格点**
- 宋梅帧表：24 个美术像素高，2px 原生格点（**被画成只有主角一半高**）
- 眷族静态图：91 个美术像素高，**4px 原生格点**

于是「像素完全一致」和「怪物不比主角大」**无法同时满足**。
**真正的解法**：让用户按 `docs/RikaAI-使用规范.md` 的格式，**重新生成一套 4×3、128×128 一帧、画 40~46 个美术像素高、与两个人物同一管线的眷族序列帧**。
（好消息：用户刚给的 `眷族1号小人战斗待机.png` 可能已经接近这个规格——先测它的原生格点和并集包围盒再判断。）

### P2 —— 视觉升级

3. 背景换成 `战斗场景一号精细版.png`（更精细，比例一致，改一个常量即可）
4. `工程卡卡面.png` 用于卡的卡面（当前 `cards_art.png` 每格只有 **32×32**，放大到 109×109 显示，很糊）
5. `场景2号大图.png` 作为第二关背景

### P3 —— 已完成但值得复核

- ✅ `.png` 默认程序已从 WPS 照片改为系统「照片」
- ⚠️ 但 `.jpeg/.gif/.bmp/.webp/.tif/.tiff/.ico/.jfif` **仍是 WPS 照片**，如需一并改，见第 11 章

---

## 10. 不要做的事 / 已归档的东西

### 不要做

- ❌ **不要加 3D**。用户明确要求「纯 2D，不要再加入 3D 建模」。所有 GLB/blend/Blender 安装包已移出项目。
- ❌ **不要加死亡惩罚**。「重塑无代价」是锁定设计。
- ❌ **不要恢复「血肉争夺」张力**。已删除。
- ❌ **不要动 `docs/阿卡姆号-美术基调-v1.0.md` 里的硬约束**：UI 永远工程系冷青；异化系用洋红；限定 32 色。
- ❌ **不要用 pwsh/bash 启动 Godot**（见 2.1）。
- ❌ **不要在 `godot_command eval` 里写循环**（见 2.3）。

### 已归档（不在项目内，但别删）

`D:\Huailxgame_3d_archived\`（1.3 GB）
- `blender_installer_913MB\` —— 913 MB 的 Blender 安装包（7142 个文件），曾让项目体积涨到 1.28 GB
- `models_biolab_361MB\` —— 全部 GLB 建模 + `biolab_precision_modules.blend`
- `world3d_scripts\` —— `battle_world_3d.gd` / `battle_actor_3d.gd` + `.uid`
- `tools_lux3d\` / `docs_lux3d\` —— 3D 资产生成脚本与清单
- `backup_codex_0927_1342\` —— 6 MB 的 src/docs/tools 备份
- `build_temp_reviews\` —— 早期的美术评审用图
- `verification_3d_era\` / `verification_wip\` —— 3D 时代的验证截图、中间过程截图

**项目体积变化**：**1,282 MB → 26 MB**

---

## 11. 环境相关（与本项目无关，但同一台机器上踩过）

### Windows 默认应用改不动（UCPD）

想把 `.png` 默认程序从 WPS 照片改成系统「照片」，**程序化修改是不可能的**：
- `HKCU\...\Explorer\FileExts\.png\UserChoice` 里的 `ProgId` 配一个 `Hash`，Windows 读取时校验
- **`UCPD` 服务（User Choice Protection Driver）正在运行**，`reg add` / `reg delete` / `Set-ItemProperty` 一律 **Access is denied**
- `IApplicationAssociationRegistration::SetAppAsDefault` 在 Win8+ 也被封
- **只能走系统 UI**：右键 PNG → **打开方式 → 选择其他应用 → 选「照片」→ 点「始终」**
  （⚠️ 直接点子菜单里的「照片」只是**打开一次**，默认程序不会变，这是最容易踩的误区）

系统「照片」的 ProgId：`AppX4mntx4h978m1v9gtzv0ewksfd6pmwsre`

**当前关联状态**：

| 格式 | 默认程序 |
|---|---|
| `.png` | ✅ 系统「照片」 |
| `.jpg` | ✅ 系统「照片」 |
| `.jpeg` `.gif` `.bmp` `.webp` `.tif` `.tiff` `.ico` `.jfif` | ❌ 仍是 WPS 照片 |

**本机其他事实**：屏幕分辨率 1536×864（125% 缩放）；`ms-settings:` 深链能打开但窗口常被其他窗口挡在后面；`rundll32 shell32.dll,OpenAs_RunDLL` 和 `Shell.Application.ShellExecute(..., 'openas')` 在这台机器上**弹不出**「打开方式」对话框。

---

## 12. 2026-09-27 接手审查后的修复

- 回合开始的腐蚀致死会立刻进入 `DEFEAT`，生命钳制为 0，不再补能量或抽牌。
- `ASSIMILATED` 保留特殊结局阶段，但按锁定规则通过 `combat_ended(true)` 上报胜利。
- 卡牌交互会识别目标类型：攻击/施加状态必须选敌人；护盾、治疗等自身策略牌可拖到战场结算。
- 战斗 UI 使用 1920×1055 安全画布并整体等比适配窗口；背景、角色、热区和屏幕特效共用该坐标空间。
- `check_presentation_compile.gd` 会等待 autoload 初始化并检查战斗视图是否完整，不再带着运行时错误输出成功。
- `McpInteractionServer` 仅在 debug 构建且桥接插件注入令牌时启动；手动调试需设置 `ARKHAM_ENABLE_MCP=1`。
- 当前自动检查：核心逻辑 112 项、表现集成 47 项；表现测试覆盖角色节点、站位、字体、UI 对齐、攻击时序、卡牌复用与死亡清理，另有回合循环与表现编译检查。
- `scenes/battle_world_2d.tscn` 中的背景和角色 PNG 在编辑器中直接可见；移动 `Gameplay/Actors` 下的四个角色场景实例会同步改变运行时站位。
- 沈明、宋梅、两个眷族变体和卡牌均为独立可编辑场景；沈明场景为 `scenes/actors/shen_ming.tscn`，其中 `AnimatedSprite2D` 包含 `idle` 与 12 帧 `draw_gun`。
- 沈明与宋梅的左上状态栏共用 `scenes/widgets/crew_status_panel.tscn`；沈明正式立绘为 `assets/art/characters/shen_mingyan/portrait_shen_ming.png`。
- 战斗界面统一继承 `assets/themes/pixel_font_theme.tres`，使用项目内工坊像素黑体；主要 HUD、意图、卡框和按钮采用 `pixel_frame.gd` 的 4×4 屏幕像素网格。
- 灯光独立为 `scenes/environment/battle_lighting.tscn`，包含三个 `PointLight2D`、屏幕空间体积光与雾效节点。
- HUD、Cards、Overlays 也已拆成独立场景，运行时控件会进入其命名分组，而不是全部平铺在主节点下。
- `scenes/main.tscn` 直接组合 BattleWorld、HUD、Cards、Overlays 和 CardTemplate，可在编辑器中展开修改。
- 详细编辑入口见 `docs/场景节点结构与编辑指南.md`。

---

## 13. 一句话总结当前状态

> 项目已是**纯 2D Godot 工程**，核心逻辑、角色序列帧、卡牌实例、战场环境、灯光和 UI 分层均有独立场景。主角二技能与眷族待机动画已经接入并完成透明背景处理。
