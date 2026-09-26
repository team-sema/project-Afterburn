extends SceneTree

## Shared player hit effects: one renderer per world, per-weapon profiles,
## strength/ring options, overcharge tint, lifetime and caps.

const PROFILE_DIR := "res://effects/impact_profiles/"
const WEAPON_PROFILES := {
	"res://projectiles/player_blaster.tscn": "blaster",
	"res://projectiles/player_shotgun_pellet.tscn": "shotgun",
	"res://projectiles/aux_cannon_bolt.tscn": "aux_cannon",
	"res://projectiles/player_homing_missile.tscn": "homing_missile",
	"res://projectiles/plasma_bomb_projectile.tscn": "plasma_bomb",
	"res://player_ship/weapons/laser_weapon_system.tscn": "laser",
	"res://player_ship/weapons/orbital_barrier_weapon_system.tscn": "orbital_barrier",
}

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_weapon_profiles()

	var source := Node2D.new()
	root.add_child(source)
	var vfx := ImpactVfx.get_or_create(source)
	_expect(vfx != null and vfx.get_parent() == root, "renderer is created on the world host")
	_expect(ImpactVfx.get_or_create(source) == vfx, "renderer is shared per world")
	_expect(vfx.material != null and vfx.z_index == ImpactVfx.DRAW_Z_INDEX, "renderer is additive and above enemies")

	var profile := load(PROFILE_DIR + "blaster.tres") as ImpactProfile
	ImpactVfx.emit_from(source, Vector2(50, 50), profile, Vector2.DOWN)
	_expect(vfx.get_active_flare_count() == 1, "a hit creates one flare")
	_expect(vfx.get_active_spark_count() == profile.spark_count, "a hit creates the profile's spark count")
	_expect(vfx.get_active_ring_count() == 0, "a hit without a radius has no ring")
	vfx.clear_impacts()

	ImpactVfx.emit_from(source, Vector2(50, 50), profile, Vector2.DOWN, 0.6, 24.0)
	_expect(vfx.get_active_spark_count() == roundi(profile.spark_count * 0.6), "strength scales spark count")
	_expect(vfx.get_active_ring_count() == 1, "an area hit adds a ring")
	var flare := (vfx.get("_flares") as Array)[0] as Dictionary
	_expect(is_equal_approx(float(flare["radius"]), profile.flare_radius * 0.6), "strength scales flare size")
	vfx.call("_process", 1.0)
	_expect(
		vfx.get_active_spark_count() == 0 and vfx.get_active_flare_count() == 0 and vfx.get_active_ring_count() == 0,
		"impacts expire after their lifetime",
	)

	var plasma := load(PROFILE_DIR + "plasma_bomb.tres") as ImpactProfile
	ImpactVfx.emit_from(source, Vector2(50, 50), plasma)
	_expect(vfx.get_active_flare_count() == 0, "a zero flare radius skips the flare")
	vfx.clear_impacts()

	var overcharge := OverchargeVisualComponent.new()
	overcharge.name = "OverchargeVisualComponent"
	overcharge.visual_root = source
	source.add_child(overcharge)
	overcharge.call("_set_overcharge_active", true)
	ImpactVfx.emit_from(source, Vector2(50, 50), profile)
	var tinted := (vfx.get("_sparks") as Array)[0] as Dictionary
	_expect(
		(tinted["core"] as Color).is_equal_approx(OverchargeVisualComponent.tint_color(profile.core_color)),
		"overcharged sources tint their impacts",
	)
	vfx.clear_impacts()

	for i in vfx.max_sparks:
		ImpactVfx.emit_from(source, Vector2(50, 50), profile)
	_expect(vfx.get_active_spark_count() == vfx.max_sparks, "spark count is capped")
	_expect(vfx.get_active_flare_count() == vfx.max_flares, "flare count is capped")
	vfx.clear_impacts()

	source.queue_free()
	vfx.queue_free()
	await process_frame
	if failures.is_empty():
		print("impact_vfx_smoke_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("impact_vfx_smoke_test: %s" % failure)
	quit(1)


func _check_weapon_profiles() -> void:
	var glow_colors: Dictionary = {}
	for scene_path in WEAPON_PROFILES:
		var instance := (load(scene_path) as PackedScene).instantiate()
		var profile := instance.get("impact_profile") as ImpactProfile
		var expected := PROFILE_DIR + String(WEAPON_PROFILES[scene_path]) + ".tres"
		_expect(profile != null and profile.resource_path == expected, "%s uses %s" % [scene_path, expected])
		if profile != null:
			glow_colors[profile.glow_color.to_html()] = true
		instance.free()
	_expect(glow_colors.size() == WEAPON_PROFILES.size(), "every weapon has its own impact color")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
