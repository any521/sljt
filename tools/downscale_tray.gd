extends SceneTree
## 1/8 最近邻降采样：保留像素网格（像素风必须最近邻）。
const JOBS := {
	"res://assets/art/ui/tray": ["frame_full", "edge_h", "edge_v", "corners", "edge2_h", "edge2_v"],
	"res://assets/art/ui/card": ["card_corner"],
}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for dir in JOBS:
		for name in JOBS[dir]:
			var path := "%s/%s.png" % [dir, name]
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image == null:
				print("SKIP ", name)
				continue
			var w := maxi(1, image.get_width() / 8)
			var h := maxi(1, image.get_height() / 8)
			image.resize(w, h, Image.INTERPOLATE_NEAREST)
			var err := image.save_png(ProjectSettings.globalize_path("%s/%s_s8.png" % [dir, name]))
			print("DOWNSCALE %s -> %dx%d  %s" % [name, w, h, "OK" if err == OK else error_string(err)])
	quit(0)
