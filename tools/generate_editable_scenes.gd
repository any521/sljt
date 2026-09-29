extends SceneTree
## 生成可在 Godot 编辑器中直接修改的角色场景、SpriteFrames 和卡牌场景。

const CELL := Vector2(128, 128)
const REBUILD_ENV := "ARKHAM_REBUILD_EDITABLE_SCENES"
const ACTORS_ONLY_ENV := "ARKHAM_REBUILD_ACTORS_ONLY"


func _init() -> void:
	if OS.get_environment(REBUILD_ENV) != "1":
		push_warning("已跳过场景重建：这些 .tscn 现在由 Godot 编辑器维护。确需覆盖时先设置 %s=1。" % REBUILD_ENV)
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/actors"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/widgets"))
	_generate_actor_resources()
	if OS.get_environment(ACTORS_ONLY_ENV) != "1":
		_generate_card_scene()
	print("EDITABLE_SCENES_GENERATED")
	quit()


func _atlas_frames(path: String, animation_name: StringName, loop: bool, fps: float, frame_count: int = 12) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	var texture: Texture2D = load(path)
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((i % 4) * CELL.x, (i / 4) * CELL.y, CELL.x, CELL.y)
		frames.add_frame(animation_name, atlas)
	return frames


func _append_animation(target: SpriteFrames, source_path: String, animation_name: StringName, loop: bool, fps: float, frame_count: int = 12) -> void:
	target.add_animation(animation_name)
	target.set_animation_loop(animation_name, loop)
	target.set_animation_speed(animation_name, fps)
	var texture: Texture2D = load(source_path)
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((i % 4) * CELL.x, (i / 4) * CELL.y, CELL.x, CELL.y)
		target.add_frame(animation_name, atlas)


func _save_actor(path: String, node_name: String, frames: SpriteFrames, content: Rect2, pixel_scale: float, facing_left: bool, action: StringName = &"attack", visual_flip: bool = false) -> void:
	var root := Control.new()
	root.name = node_name
	root.size = content.size * pixel_scale
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_script(load("res://src/ui/world/battle_actor_2d.gd"))
	root.set("facing_left", facing_left)
	root.set("attack_animation", action)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = frames
	sprite.animation = &"idle"
	sprite.autoplay = &"idle"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = visual_flip
	sprite.scale = Vector2.ONE * pixel_scale
	# 以 128×128 帧中心为基准，再把实际人物包围盒放回角色根节点矩形。
	# flip_h 后包围盒横坐标变为 [128-content.end.x, 128-content.position.x]。
	if visual_flip:
		sprite.position = Vector2(content.end.x - CELL.x * 0.5, CELL.y * 0.5 - content.position.y) * pixel_scale
	else:
		sprite.position = (CELL * 0.5 - content.position) * pixel_scale
	root.add_child(sprite)
	sprite.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, path)
	root.free()


func _generate_actor_resources() -> void:
	var hero := _atlas_frames("res://assets/art/characters/shen_mingyan/battle_clean_512x256.png", &"idle", true, 5.0, 5)
	_append_animation(hero, "res://assets/art/characters/shen_mingyan/battle_skill_2_512x384.png", &"draw_gun", false, 12.0)
	ResourceSaver.save(hero, "res://assets/art/characters/shen_mingyan/battle_animations.tres")
	_save_actor("res://scenes/actors/shen_ming.tscn", "ShenMing", hero, Rect2(48, 41, 32, 51), 4.3, false, &"draw_gun")

	var ally := _atlas_frames("res://assets/art/characters/song_mei/battle_512x384.png", &"idle", true, 8.0)
	ResourceSaver.save(ally, "res://assets/art/characters/song_mei/battle_animations.tres")
	_save_actor("res://scenes/actors/song_mei.tscn", "SongMei", ally, Rect2(45, 44, 29, 47), 4.65, false)

	var kin := _atlas_frames("res://assets/art/enemies/kin_idle_512x384.png", &"idle", true, 8.0)
	ResourceSaver.save(kin, "res://assets/art/enemies/kin_animations.tres")
	_save_actor("res://scenes/actors/kin_variant.tscn", "KinVariant", kin, Rect2(34, 43, 39, 43), 5.1, true, &"attack", true)


func _label(name_value: String, text_value: String, position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.name = name_value
	item.text = text_value
	item.position = position_value
	item.size = size_value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item


func _owned(parent: Node, child: Node, owner: Node) -> void:
	parent.add_child(child)
	child.owner = owner


func _generate_card_scene() -> void:
	var root := Control.new()
	root.name = "BattleCard"
	root.size = Vector2(225, 297)
	root.pivot_offset = root.size * 0.5
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_script(load("res://src/ui/widgets/battle_card.gd"))

	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.size = root.size
	frame.texture = load("res://assets/art/cards/card_frame_225.png")
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owned(root, frame, root)

	var art := TextureRect.new()
	art.name = "Art"
	art.position = Vector2(21, 45)
	art.size = Vector2(186, 132)
	var preview_art := AtlasTexture.new()
	preview_art.atlas = load("res://assets/art/cards/cards_art.png")
	preview_art.region = Rect2(0, 0, 32, 32)
	art.texture = preview_art
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owned(root, art, root)

	var cost := _label("Cost", "1", Vector2(6, 6), Vector2(38, 38), 22, Color("ffdc82"))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_owned(root, cost, root)
	var title := _label("Name", "卡牌名称", Vector2(46, 10), Vector2(152, 28), 17, Color("e0e8f0"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_owned(root, title, root)
	var index := _label("Index", "1", Vector2(174, 12), Vector2(24, 20), 11, Color("a8c8e0"))
	index.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_owned(root, index, root)
	_owned(root, _label("Type", "规程 / 攻击", Vector2(22, 187), Vector2(182, 17), 11, Color("8592a0")), root)
	var description := _label("Description", "造成 6 点伤害", Vector2(22, 205), Vector2(182, 62), 15, Color("e0e8f0"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_owned(root, description, root)
	_owned(root, _label("Badge", "建立回声基准", Vector2(22, 276), Vector2(182, 17), 11, Color("6bc7ff")), root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.size = root.size
	dim.color = Color(0.025, 0.035, 0.05, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.visible = false
	_owned(root, dim, root)

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/widgets/battle_card.tscn")
	root.free()
