extends SceneTree
## 白底软抠图：AI 出的素材多为白底不透明。
## 高亮 + 低饱和像素：硬白→全透明，边缘灰白→半透明过渡，避免留下白色光晕。
const JOBS := {
	"res://assets/art/ui/tray": ["frame_full", "edge_h", "edge_v", "corners", "edge2_h", "edge2_v"],
	"res://assets/art/ui/card": ["card_corner"],
}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for dir in JOBS:
		for name in JOBS[dir]:
			var path := "%s/%s_s8.png" % [dir, name]
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image == null:
				print("SKIP ", name)
				continue
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			var w := image.get_width()
			var h := image.get_height()
			var keyed := 0
			var softened := 0
			for y in h:
				for x in w:
					var c := image.get_pixel(x, y)
					var mx := maxf(c.r, maxf(c.g, c.b))
					var mn := minf(c.r, minf(c.g, c.b))
					var lum := (c.r + c.g + c.b) / 3.0
					var sat := mx - mn
					if sat < 0.09 and lum > 0.72:
						if lum > 0.90:
							image.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
							keyed += 1
						else:
							image.set_pixel(x, y, Color(c.r, c.g, c.b, clampf((0.90 - lum) / 0.18, 0.0, 1.0)))
							softened += 1
			var err := image.save_png(ProjectSettings.globalize_path("%s/%s_cut.png" % [dir, name]))
			print("KEY %s %dx%d keyed=%d softened=%d %s" % [name, w, h, keyed, softened, "OK" if err == OK else error_string(err)])
	quit(0)
