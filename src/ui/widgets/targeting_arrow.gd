extends Node2D
## 指向箭头：炮弹光线（深蓝为主、金色为辅）。
##
## 形态：沿二次贝塞尔生成一条**锥形光束** —— 链尾细、接近箭头变粗，
## 分四层叠加（深蓝大光晕 → 中蓝 → 亮蓝 → 近白蓝核心），读起来像炮弹的拖曳光。
## 金色只做点缀：沿光束流动的能量刻线、箭头头的本体与亮金上缘。
##
## 几何仍对齐《杀戮尖塔2》的 NTargetingArrow：19 段采样、二次贝塞尔、
## 控制点让弧线朝"甩出去"的方向鼓、头/尾相对目标后退 88 / 40；悬停弹性脉冲保留。
##
## 贴图替换：把 targeting_arrow_head.png / targeting_arrow_segment.png 放进
## assets/art/ui/ 即自动切到贴图模式（系数照原版：段 ×0.28~0.42、头 ×0.95~1.05）。

const SAMPLE_COUNT := 26
const HEAD_BACK := 88.0
const TAIL_BACK := 40.0
const HALF_Y := 527.0

## 光束基准半宽（再乘 0.62~1.12 的伸缩系数）
const BEAM_WIDTH := 30.0
const HEAD_UNIT := 56.0

## 金色能量刻线沿光束流动的速度（越小越慢）
const MARCH_SPEED := 0.42
const TICK_COUNT := 7

## 伸缩：距离达到这个像素就算拉满
const STRETCH_FULL_DISTANCE := 430.0
const STRETCH_MIN := 0.62
const STRETCH_MAX := 1.12

## 深蓝主体
const COLOR_BEAM_DEEP := Color("0f2f6b")
const COLOR_BEAM_MID := Color("1f5fc4")
const COLOR_BEAM_CORE := Color("3f9bf0")
const COLOR_BEAM_HOT := Color("c8e6ff")
const COLOR_GLOW_DEEP := Color("0f2f6b")
const COLOR_GLOW := Color("3f8fe0")
## 金色点缀
const COLOR_GOLD := Color("c9a227")
const COLOR_GOLD_HOT := Color("ffe9a8")
const COLOR_HEAD_MAIN := Color("c9a227")
const COLOR_HEAD_EDGE := Color("fff3c4")
const COLOR_ENEMY := Color("ffcc44")
const COLOR_ALLY := Color("7fd9a0")
const COLOR_IDLE := Color("1f5fc4")

const TEXTURE_HEAD := "res://assets/art/ui/targeting_arrow_head.png"
const TEXTURE_SEGMENT := "res://assets/art/ui/targeting_arrow_segment.png"

var from_position := Vector2.ZERO
var to_position := Vector2.ZERO
var follow_mouse := true
var accent := COLOR_IDLE

var _control := Vector2.ZERO
var _head_position := Vector2.ZERO
var _tail_position := Vector2.ZERO
var _head_rotation := 0.0
var _head_scale := 0.95
var _pulse: Tween
var _head_texture: Texture2D
var _segment_texture: Texture2D
var _clock := 0.0
var _stretch := 1.0
var _highlighted := false


func _ready() -> void:
    visible = false
    z_index = 120
    set_process(true)
    if ResourceLoader.exists(TEXTURE_HEAD):
        _head_texture = load(TEXTURE_HEAD)
    if ResourceLoader.exists(TEXTURE_SEGMENT):
        _segment_texture = load(TEXTURE_SEGMENT)


func start_drawing(from: Vector2, use_mouse: bool) -> void:
    from_position = from
    follow_mouse = use_mouse
    if use_mouse:
        to_position = get_local_mouse_position()
    accent = COLOR_IDLE
    _highlighted = false
    _head_scale = 0.95
    _stretch = 0.0
    _clock = 0.0
    visible = true


func stop_drawing() -> void:
    visible = false
    follow_mouse = true
    _clear_pulse()
    _head_scale = 0.95
    _highlighted = false


func update_drawing_to(position: Vector2) -> void:
    to_position = position


func set_highlight(on: bool, is_enemy: bool) -> void:
    _clear_pulse()
    _highlighted = on
    if not on:
        accent = COLOR_IDLE
        _head_scale = 0.95
        queue_redraw()
        return
    accent = COLOR_ENEMY if is_enemy else COLOR_ALLY
    _pulse = create_tween()
    _pulse.tween_property(self, "_head_scale", 1.05, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
    queue_redraw()


func _clear_pulse() -> void:
    if _pulse != null and _pulse.is_valid():
        _pulse.kill()
    _pulse = null


func _process(delta: float) -> void:
    if not visible:
        return
    _clock += delta
    if follow_mouse:
        to_position = get_local_mouse_position()
    _update_geometry()
    var distance := from_position.distance_to(to_position)
    var target_stretch := clampf(distance / STRETCH_FULL_DISTANCE, 0.0, 1.0)
    _stretch = lerpf(_stretch, target_stretch, clampf(delta * 8.0, 0.0, 1.0))
    queue_redraw()


func _update_geometry() -> void:
    # 箭头头位置依赖上一帧的朝向（与原版相同的单帧反馈回路），朝向随后更新。
    _head_position = to_position + Vector2(0.0, HEAD_BACK).rotated(_head_rotation)
    _tail_position = to_position + Vector2(0.0, TAIL_BACK).rotated(_head_rotation)
    _control.x = from_position.x - (_head_position.x - from_position.x) * 0.25
    if from_position.y > HALF_Y:
        _control.y = _head_position.y + (_head_position.y - from_position.y) * 0.5
    else:
        _control.y = _head_position.y * 0.75 + from_position.y * 0.25
    _head_rotation = (to_position - _control).angle() + PI * 0.5


func _quadratic(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
    return a.lerp(b, t).lerp(b.lerp(c, t), t)


func _size_factor() -> float:
    return lerpf(STRETCH_MIN, STRETCH_MAX, _stretch)


## 光束半宽剖面：链尾细 → 中段最粗 → 末端收窄。
## 末端收窄是关键：让光束"钻进"箭头头里，接缝处不会出现平切口和突兀的宽度跳变。
func _beam_profile(t: float) -> float:
    var clamped := clampf(t, 0.0, 1.0)
    var rise := pow(clampf(clamped / 0.70, 0.0, 1.0), 0.85)
    var taper := 1.0 - 0.70 * clampf((clamped - 0.62) / 0.38, 0.0, 1.0)
    return BEAM_WIDTH * _size_factor() * (0.28 + 0.72 * rise) * taper


func _tangent_of(samples: PackedVector2Array, index: int) -> Vector2:
    var n := samples.size()
    var a := samples[maxi(index - 1, 0)]
    var b := samples[mini(index + 1, n - 1)]
    var delta := b - a
    return delta.normalized() if delta.length_squared() > 0.0001 else Vector2.UP


func _draw() -> void:
    var samples := PackedVector2Array()
    for i in SAMPLE_COUNT:
        samples.append(_quadratic(from_position, _control, _tail_position, float(i) / float(SAMPLE_COUNT - 1)))
    if _segment_texture != null:
        _draw_texture_chain(samples)
    else:
        _draw_beam(samples)
        _draw_ticks(samples)
    _draw_head(_size_factor())


## 四层锥形光束：深蓝大光晕 → 中蓝 → 亮蓝 → 近白蓝核心
func _draw_beam(samples: PackedVector2Array) -> void:
    var layers := [
        {"width": 1.85, "color": Color(COLOR_BEAM_DEEP, 0.26)},
        {"width": 1.24, "color": Color(COLOR_BEAM_MID, 0.46)},
        {"width": 0.66, "color": Color(COLOR_BEAM_CORE, 0.70)},
        {"width": 0.26, "color": Color(COLOR_BEAM_HOT, 0.92)},
    ]
    var n := samples.size()
    for layer in layers:
        var half: PackedVector2Array = PackedVector2Array()
        var back: PackedVector2Array = PackedVector2Array()
        for i in n:
            var t := float(i) / float(n - 1)
            var normal := Vector2(-_tangent_of(samples, i).y, _tangent_of(samples, i).x)
            var w: float = _beam_profile(t) * float(layer["width"])
            half.append(samples[i] + normal * w)
            back.append(samples[i] - normal * w)
        back.reverse()
        half.append_array(back)
        draw_colored_polygon(half, layer["color"])
    # 金色辅色：沿光束上缘一条细金边，让"金为辅"贯穿整条光线，而不是只有刻线
    var gold_edge := PackedVector2Array()
    for i in n:
        var t := float(i) / float(n - 1)
        var tangent := _tangent_of(samples, i)
        var normal := Vector2(-tangent.y, tangent.x)
        gold_edge.append(samples[i] - normal * _beam_profile(t) * 0.94)
    draw_polyline(gold_edge, Color(COLOR_GOLD, 0.5), maxf(1.0, 1.8 * _size_factor()), true)


## 金色能量刻线：沿光束流动，尾部淡入、接近箭头淡出
func _draw_ticks(samples: PackedVector2Array) -> void:
    var n := samples.size()
    for k in TICK_COUNT:
        var t := fmod(float(k) / float(TICK_COUNT) + _clock * MARCH_SPEED, 1.0)
        var index := clampi(int(t * float(n - 1)), 0, n - 1)
        var point := samples[index]
        var tangent := _tangent_of(samples, index)
        var normal := Vector2(-tangent.y, tangent.x)
        var w := _beam_profile(t)
        var alpha := minf(t / 0.14, 1.0) * minf((1.0 - t) / 0.20, 1.0)
        if alpha <= 0.01:
            continue
        var gold := COLOR_GOLD if not _highlighted else accent
        draw_line(point - normal * w * 0.92, point + normal * w * 0.92, Color(gold, alpha * 0.92), maxf(1.0, 2.6 * _size_factor()), true)
        draw_line(point - normal * w * 0.46, point + normal * w * 0.46, Color(COLOR_GOLD_HOT, alpha * 0.6), maxf(1.0, 1.3 * _size_factor()), true)


## 贴图模式：段贴图沿曲线排布（系数照原版 0.28~0.42）
func _draw_texture_chain(samples: PackedVector2Array) -> void:
    var n := samples.size()
    for i in n:
        var t := float(i) / float(n - 1)
        var alpha := minf(t / 0.10, 1.0) * minf((1.0 - t) / 0.16, 1.0)
        if alpha <= 0.01:
            continue
        var tangent := _tangent_of(samples, i)
        draw_set_transform(samples[i], tangent.angle() + PI * 0.5, Vector2.ONE * (0.35 * _size_factor()))
        var tex_size := _segment_texture.get_size()
        draw_texture(_segment_texture, -tex_size * 0.5, Color(1, 1, 1, alpha))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 箭头头：金色本体 + 亮金上缘，外圈深蓝光晕（蓝为主、金为辅）
func _draw_head(size_factor: float) -> void:
    var unit := HEAD_UNIT * size_factor
    if _head_texture != null:
        draw_set_transform(_head_position, _head_rotation, Vector2.ONE * _head_scale)
        var tex_size := _head_texture.get_size()
        draw_texture(_head_texture, -tex_size * 0.5)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        return
    draw_set_transform(_head_position, _head_rotation, Vector2.ONE * _head_scale)
    var main := COLOR_HEAD_MAIN if not _highlighted else accent
    # 与光束的接缝过渡：在箭头尾部叠两层柔光圆，把"光线"和"箭头"焊在一起
    draw_circle(Vector2(0.0, unit * 0.38), unit * 0.66, Color(COLOR_BEAM_MID, 0.34))
    draw_circle(Vector2(0.0, unit * 0.30), unit * 0.44, Color(COLOR_BEAM_CORE, 0.34))
    draw_circle(Vector2(0.0, unit * 0.24), unit * 0.26, Color(COLOR_BEAM_HOT, 0.28))
    # 外光晕改成三层递减，边界柔和，不再是硬三角套硬三角
    var glow_base := PackedVector2Array([
        Vector2(0.0, -unit * 1.35),
        Vector2(-unit, unit * 0.8),
        Vector2(0.0, unit * 0.34),
        Vector2(unit, unit * 0.8),
    ])
    var glow_layers := [
        {"scale": 1.42, "color": Color(COLOR_GLOW_DEEP, 0.16)},
        {"scale": 1.24, "color": Color(COLOR_GLOW, 0.20)},
        {"scale": 1.10, "color": Color(COLOR_BEAM_CORE, 0.22)},
    ]
    for layer in glow_layers:
        var soft := PackedVector2Array()
        for point in glow_base:
            soft.append(point * float(layer["scale"]))
        draw_colored_polygon(soft, layer["color"])
    var head := PackedVector2Array([
        Vector2(0.0, -unit * 1.15),
        Vector2(-unit * 0.72, unit * 0.5),
        Vector2(0.0, unit * 0.2),
        Vector2(unit * 0.72, unit * 0.5),
    ])
    draw_colored_polygon(head, main)
    var edge := PackedVector2Array([
        Vector2(0.0, -unit * 1.15),
        Vector2(-unit * 0.40, -unit * 0.02),
        Vector2(0.0, -unit * 0.28),
        Vector2(unit * 0.40, -unit * 0.02),
    ])
    draw_colored_polygon(edge, Color(COLOR_HEAD_EDGE, 0.9))
    draw_polyline(head, Color(COLOR_GLOW, 0.75), maxf(1.0, 1.6 * size_factor), true)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
