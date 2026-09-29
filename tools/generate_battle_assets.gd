extends SceneTree
## Reproducible, original battle particles and synthesized sound effects.
const TAU_F := TAU
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 0xA4C4A9
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/art/battle/particles"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio"))
	_generate_particles()
	_generate_audio()
	print("Generated battle particle atlas set and 17 original WAV cues.")
	quit()

func _image() -> Image:
	return Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)

func _pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < 64 and y >= 0 and y < 64: image.set_pixel(x, y, color)

func _disc(image: Image, center: Vector2, radius: float, color: Color, soft: bool = false) -> void:
	for y in range(maxi(0, int(center.y-radius-1)), mini(64, int(center.y+radius+2))):
		for x in range(maxi(0, int(center.x-radius-1)), mini(64, int(center.x+radius+2))):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if distance <= radius:
				var c := color
				if soft: c.a *= pow(1.0 - distance / radius, 1.65)
				_pixel(image, x, y, c)

func _save(image: Image, name: String) -> void:
	image.save_png(ProjectSettings.globalize_path("res://assets/art/battle/particles/particle_%s.png" % name))

func _generate_particles() -> void:
	var image := _image()
	for y in 64:
		for x in 64:
			var dx := absf(x - 31.5); var dy := absf(y - 31.5)
			if (dx < 3 and dy < 27) or (dy < 3 and dx < 27) or (absf(dx-dy) < 2 and dx < 16):
				_pixel(image, x, y, Color("b2e8ff") if dx + dy < 16 else Color("6bc7ff"))
	_disc(image, Vector2(32,32), 7, Color.WHITE, true); _save(image, "spark")
	image = _image()
	var shard := PackedVector2Array([Vector2(29,4),Vector2(47,26),Vector2(35,59),Vector2(17,35)])
	for y in 64:
		for x in 64:
			if Geometry2D.is_point_in_polygon(Vector2(x,y), shard): _pixel(image,x,y,Color("3a82b2") if x+y>63 else Color("b2e8ff"))
	_save(image, "shard")
	image = _image()
	for y in range(6,59):
		var width := sin(float(y-5)/54.0*PI) * 18.0 + (5.0 if y>40 else 0.0)
		for x in range(8,56):
			if absf(x - 29.0 - sin(y*0.31)*3.0) < width:
				_pixel(image,x,y,Color("c7479e") if x < 32 else Color("8c2a70"))
	_disc(image,Vector2(24,23),4,Color("f0f6fa"),true); _save(image,"slime")
	image = _image()
	var tissue := PackedVector2Array([Vector2(7,26),Vector2(18,8),Vector2(34,15),Vector2(50,6),Vector2(58,27),Vector2(46,38),Vector2(51,57),Vector2(30,49),Vector2(15,59),Vector2(17,41)])
	for y in 64:
		for x in 64:
			if Geometry2D.is_point_in_polygon(Vector2(x,y), tissue): _pixel(image,x,y,Color("8c2a70") if (x+y)%7<3 else Color("48123a"))
	for point in [Vector2(19,22),Vector2(39,31),Vector2(28,43)]: _disc(image,point,3,Color("ff9edc"),true)
	_save(image,"tissue")
	image = _image(); _disc(image,Vector2(32,32),28,Color("6bc7ff"),true); _disc(image,Vector2(32,32),8,Color("b2e8ff"),true); _save(image,"glow")
	image = _image()
	for y in range(5,59):
		for x in range(15,49):
			var center_x := 32.0 + sin(y*0.17)*2.0
			if absf(x-center_x)<3 or (y>25 and y<33 and absf(x-center_x)<11): _pixel(image,x,y,Color("7fd9a0") if y<35 else Color("46b46e"))
	_disc(image,Vector2(29,17),3,Color("f0f6fa"),true); _save(image,"heal")
	image = _image()
	for item in [[Vector2(23,35),16.0],[Vector2(39,33),17.0],[Vector2(31,22),14.0]]: _disc(image,item[0],item[1],Color(0.52,0.57,0.64,0.42),true)
	_save(image,"smoke")
	image = _image()
	for y in 64:
		for x in 64:
			var distance := Vector2(x+0.5,y+0.5).distance_to(Vector2(32,32))
			if distance > 24 and distance < 28: _pixel(image,x,y,Color("b2e8ff") if y<32 else Color("6bc7ff"))
	_save(image,"ring")

func _generate_audio() -> void:
	var specs := {
		"draw": [0.15, "paper"], "hover": [0.055, "tick"], "grab": [0.08, "grab"],
		"whoosh": [0.28, "whoosh"], "enemy_whoosh": [0.18, "whoosh"],
		"impact": [0.20, "impact"], "impact_large": [0.36, "large"],
		"death": [0.82, "death"], "shield": [0.28, "shield"], "heal": [0.42, "heal"],
		"combo": [0.36, "combo"], "corruption": [1.0, "corruption"], "turn": [0.42, "turn"],
		"player_hit": [0.32, "player_hit"], "victory": [0.85, "victory"], "defeat": [0.85, "defeat"], "deny": [0.09, "deny"]}
	for key in specs:
		_write_wav(key, float(specs[key][0]), String(specs[key][1]))

func _write_wav(name: String, duration: float, kind: String) -> void:
	var rate := 44100
	var count := int(duration * rate)
	var samples := PackedInt32Array(); samples.resize(count)
	var phase_noise := 0.0
	for i in count:
		var t := float(i) / rate
		var q := t / duration
		var attack := minf(1.0, t / 0.012)
		var decay := pow(maxf(0.0, 1.0-q), 1.4)
		var noise := rng.randf_range(-1.0,1.0)
		phase_noise = lerpf(phase_noise, noise, 0.24)
		var s := 0.0
		match kind:
			"paper": s = phase_noise*0.42*sin(q*PI) + sin(TAU_F*820*t)*0.08*decay
			"tick": s = sin(TAU_F*1650*t)*exp(-t*55.0)*0.48
			"grab": s = sin(TAU_F*185*t)*decay*0.42 + phase_noise*decay*0.13
			"whoosh": s = phase_noise*sin(q*PI)*0.52 + sin(TAU_F*(95.0*t+620.0*t*t))*0.12*sin(q*PI)
			"impact": s = (sin(TAU_F*74*t)*0.55 + sin(TAU_F*720*t)*0.22 + phase_noise*0.36)*attack*exp(-t*14.0)
			"large": s = (sin(TAU_F*45*t)*0.72 + sin(TAU_F*510*t)*0.25 + phase_noise*0.35)*attack*exp(-t*8.0)
			"death": s = (sin(TAU_F*(78.0*t-25.0*t*t))*0.45 + phase_noise*(0.42+0.2*sin(TAU_F*19*t)))*attack*decay
			"shield": s = (sin(TAU_F*225*t)+sin(TAU_F*451*t)*0.45)*sin(q*PI)*0.38
			"heal": s = (sin(TAU_F*(330*t+260*t*t))+sin(TAU_F*(495*t+390*t*t))*0.4)*sin(q*PI)*0.36
			"combo": s = (sin(TAU_F*523.25*t)+sin(TAU_F*784.88*t)*0.45+sin(TAU_F*1046.5*t)*0.2)*attack*decay*0.36
			"corruption": s = (sin(TAU_F*43*t)+sin(TAU_F*47*t)*0.7+phase_noise*0.17)*sin(q*PI)*0.48
			"turn": s = phase_noise*sin(q*PI)*0.34 + sin(TAU_F*(120*t+580*t*t))*sin(q*PI)*0.21
			"player_hit": s = (sin(TAU_F*54*t)*0.65+sin(TAU_F*108*t)*0.25+phase_noise*0.27)*attack*exp(-t*9.0)
			"victory": s = (sin(TAU_F*392*t)+sin(TAU_F*523.25*t)+sin(TAU_F*659.25*t))*sin(q*PI)*0.19
			"defeat": s = (sin(TAU_F*(196*t-45*t*t))+sin(TAU_F*(147*t-32*t*t))*0.6)*sin(q*PI)*0.29
			"deny": s = (sin(TAU_F*155*t)+sin(TAU_F*149*t))*decay*0.23
		s = clampf(s, -0.92, 0.92)
		samples[i] = int(s * 32767.0)
	var file := FileAccess.open(ProjectSettings.globalize_path("res://assets/audio/%s.wav" % name), FileAccess.WRITE)
	file.store_buffer("RIFF".to_ascii_buffer()); file.store_32(36 + count*2); file.store_buffer("WAVE".to_ascii_buffer())
	file.store_buffer("fmt ".to_ascii_buffer()); file.store_32(16); file.store_16(1); file.store_16(1); file.store_32(rate); file.store_32(rate*2); file.store_16(2); file.store_16(16)
	file.store_buffer("data".to_ascii_buffer()); file.store_32(count*2)
	for value in samples: file.store_16(value if value >= 0 else value + 65536)
	file.close()
