extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	var music_player := root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	_run.call_deferred()


func _run() -> void:
	var laser_scene := load("res://player_ship/weapons/laser_weapon_system.tscn") as PackedScene
	var laser := laser_scene.instantiate() as LaserWeaponSystem
	laser.position = Vector2(80.0, 216.0)
	root.add_child(laser)
	await process_frame

	var refract_vfx := laser.get_node("RefractVfx")
	_expect(refract_vfx != null, "laser scene contains refract VFX")
	_expect(refract_vfx.material != null, "refract VFX uses an additive material")
	_expect(
		float(refract_vfx.get("glow_width")) > float(refract_vfx.get("core_width")),
		"refract glow is wider than its core",
	)

	var from_global := Vector2(84.0, 140.0)
	var target_global := Vector2(132.0, 104.0)
	laser.call("_show_refract_visual", from_global, target_global)
	_expect(
		int(refract_vfx.call("get_active_segment_count")) == 1,
		"a refract hit creates one visible segment",
	)

	refract_vfx.call("_process", float(refract_vfx.get("segment_lifetime")) * 0.5)
	_expect(
		int(refract_vfx.call("get_active_segment_count")) == 1,
		"refract segment remains during its fade",
	)
	refract_vfx.call("_process", float(refract_vfx.get("segment_lifetime")))
	_expect(
		int(refract_vfx.call("get_active_segment_count")) == 0,
		"refract segment is removed after its lifetime",
	)

	laser.call("_show_refract_visual", target_global, target_global)
	_expect(
		int(refract_vfx.call("get_active_segment_count")) == 0,
		"zero-length refract paths stay hidden",
	)

	laser.queue_free()
	refract_vfx = null
	laser = null
	laser_scene = null
	await process_frame
	if failures.is_empty():
		print("laser_refraction_vfx_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("laser_refraction_vfx_smoke_test: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
