# 贡献指南

感谢有兴趣参与《阿卡姆号》。本项目当前以**单人开发 + AI 辅助**为主，外部贡献请先开 Issue 讨论方向，
避免大改动被拒。

## 开发环境

| 项 | 版本 |
|---|---|
| Godot | **4.6 stable** |
| 引擎类型 | 标准版（GDScript，**不使用 C#**） |
| 推荐编辑器 | Godot 内置编辑器 + Aseprite（美术） |

\`\`\`bash
git clone <repo-url>
cd <repo>
godot --headless --path . --import   # 首次导入资源
godot --path .                        # 运行
\`\`\`

## 提交前必须做的事

1. **跑测试**（见 [README](README.md#测试)），全绿再提交。
2. **改了脚本先 \`--import\` 再 \`--script\`**，否则类别名缓存失效会报假错误。
3. **新增素材后跑一次 \`--import\`**，否则 \`ResourceLoader.exists()\` 返回 false，
   代码会静默走 fallback（背景不显示、精灵不加载）。

## 代码规范（硬约束）

### 1. 预制体优先

**禁止**运行时造节点：

\`\`\`gdscript
# ❌ 禁止
var label := Label.new()
add_child(label)
var arrow := TargetingArrowScript.new()

# ✅ 正确
@export var arrow_prefab: PackedScene
var arrow := arrow_prefab.instantiate()
card_layer.add_child(arrow)
\`\`\`

- 所有**重复生成**的物体必须有独立 \`.tscn\` 预制体；
- 预制体用 \`@export var xxx_prefab: PackedScene\` 暴露，**在编辑器里拖拽赋值**，
  代码里禁止硬编码 \`load("res://...tscn")`；
- 预制体必须能在编辑器里直接改（节点、动画、尺寸、颜色），脚本不要覆盖这些值；
- 详细规范与预制体内部节点清单见 [docs/项目规则-预制体规范.md](docs/项目规则-预制体规范.md)。

### 2. 分层

- \`src/core/\` 是**纯逻辑层**，禁止依赖任何 UI / 场景；表现层只读逻辑层状态。
- 表现层与逻辑层分离：动画排队播放，逻辑立即结算，**动画不阻塞输入**。

### 3. 美术

- 任何新资产必须先对照 [美术基调](docs/阿卡姆号-美术基调-v1.0.md) 取色（32 色锁定色板）。
- **生成后先给制作人过目**，通过后才写进游戏（这是硬性流程）。
- 像素素材必须使用最近邻过滤、整数倍缩放。

## 提交信息

采用 Conventional Commits 风格：

\`\`\`
feat(combat): 出牌队列支持条件不足自动回手
fix(ui): 手牌按可见卡槽中心对齐（原先右移半张牌）
docs(art): 补充空间站地砖集生成提示词
chore(repo): 忽略 .godot 缓存与参考字体集合
\`\`\`

## 测试要求

新增功能必须带**可无头运行**的回归测试，优先写成对客观数值的断言
（例如"整排居中偏差 < 1.5px"、"相邻卡牌不重叠"），而不是依赖固定帧数的时序断言 ——
逐帧插值类动画是时间相关的，固定帧数在负载高时会假失败。
