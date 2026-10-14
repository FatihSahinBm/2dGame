@tool
extends SceneTree

const CELL_WIDTH = 1280
const CELL_HEIGHT = 720

const ANIM_CONFIGS = {
	"intro_taunt": {
		"file": "intro_taunt.png",
		"hframes": 5,
		"vframes": 4,
		"total_frames": 20,
		"fps": 10.0,
		"loop": false
	},
	"idle": {
		"file": "idle.png",
		"hframes": 4,
		"vframes": 4,
		"total_frames": 16,
		"fps": 8.0,
		"loop": true
	},
	"walk": {
		"file": "walk.png",
		"hframes": 4,
		"vframes": 4,
		"total_frames": 16,
		"fps": 8.0,
		"loop": true
	},
	"run": {
		"file": "run.png",
		"hframes": 5,
		"vframes": 4,
		"total_frames": 20,
		"fps": 14.0,
		"loop": true
	},
	"attack_bite": {
		"file": "attack_bite.png",
		"hframes": 5,
		"vframes": 4,
		"total_frames": 20,
		"fps": 10.0,
		"loop": false
	},
	"attack_laser": {
		"file": "attack_laser.png",
		"hframes": 5,
		"vframes": 4,
		"total_frames": 20,
		"fps": 10.0,
		"loop": false
	},
	"attack_platform_slam": {
		"file": "attack_platform_slam.png",
		"hframes": 5,
		"vframes": 4,
		"total_frames": 20,
		"fps": 10.0,
		"loop": false
	},
	"grab_counter": {
		"file": "grab_counter.png",
		"hframes": 5,
		"vframes": 4,
		"total_frames": 20,
		"fps": 10.0,
		"loop": false
	},
	"stunned_groggy": {
		"file": "stunned_groggy.png",
		"hframes": 5,
		"vframes": 4,
		"total_frames": 20,
		"fps": 10.0,
		"loop": false
	},
	"hurt": {
		"file": "hurt.png",
		"hframes": 4,
		"vframes": 4,
		"total_frames": 16,
		"fps": 10.0,
		"loop": false
	},
	"death": {
		"file": "death.png",
		"hframes": 5,
		"vframes": 4,
		"total_frames": 20,
		"fps": 10.0,
		"loop": false
	}
}

func _init() -> void:
	print("Building T-Rex Boss SpriteFrames...")
	var sf = SpriteFrames.new()
	# Remove default animation if exists
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")

	for anim_name in ANIM_CONFIGS:
		var cfg = ANIM_CONFIGS[anim_name]
		var tex_path = "res://assets/characters/trex_boss/" + cfg["file"]
		var tex = load(tex_path)
		if not tex:
			push_error("Failed to load texture: " + tex_path)
			quit(1)
			return

		sf.add_animation(StringName(anim_name))
		sf.set_animation_speed(StringName(anim_name), cfg["fps"])
		sf.set_animation_loop(StringName(anim_name), cfg["loop"])

		var hframes = cfg["hframes"]
		var total_frames = cfg["total_frames"]

		for i in range(total_frames):
			var col = i % hframes
			var row = i / hframes
			var atlas_tex = AtlasTexture.new()
			atlas_tex.atlas = tex
			atlas_tex.region = Rect2(col * CELL_WIDTH, row * CELL_HEIGHT, CELL_WIDTH, CELL_HEIGHT)
			sf.add_frame(StringName(anim_name), atlas_tex)

		print("  - Added animation: ", anim_name, " with ", total_frames, " frames (", cfg["fps"], " fps)")

	var save_path = "res://assets/characters/trex_boss/trex_frames.tres"
	var err = ResourceSaver.save(sf, save_path)
	if err != OK:
		push_error("Failed to save SpriteFrames to " + save_path + ", error: " + str(err))
		quit(1)
		return

	print("SUCCESS: Saved SpriteFrames to ", save_path)
	quit(0)
