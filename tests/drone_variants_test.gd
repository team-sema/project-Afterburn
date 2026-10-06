extends SceneTree
## Drone variants (산탄·느린탄·정지탄) each teach one dodge skill with their own
## bullet shape and glow colour. See docs/design/enemies/drone.md 「변종」.

const BASE := "res://enemies/normal_enemy.tscn"
const VARIANTS := {
	"spread": "res://enemies/variants/drone_spread.tscn",
	"slow": "res://enemies/variants/drone_slow.tscn",
	"halt": "res://enemies/variants/drone_halt.tscn",
}
const PRESETS := {
	"drone_spread_formation": "res://resources/encounters/presets/drone_spread_formation.tres",
	"drone_slow_zigzag": "res://resources/encounters/presets/drone_slow_zigzag.tres",
	"drone_halt_formation": "res://resources/encounters/presets/drone_halt_formation.tres",
}

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _build(scene_path: String) -> Dictionary:
	var enemy := (load(scene_path) as PackedScene).instantiate()
	var component := enemy.get_node("EnemyShootComponent") as EnemyShootComponent
	var sequence := component.pattern_script.new() as BarrageSequence
	sequence.build(component.pattern_params)
	var glow := (enemy.get_node("Anchor/TightGlow") as CanvasItem).self_modulate
	var health: int = enemy.get_node("StatsComponent").health
	var boost: bool = component.pattern_fire_volume_boost
	enemy.free()
	_expect(sequence.validation_error().is_empty(), "%s pattern valid: %s" % [scene_path, sequence.validation_error()])
	var volley: BarrageVolley = null
	for step in sequence.steps:
		if step.action == BarrageStep.Action.FIRE:
			volley = step.get_volleys()[0]
			break
	return {"volley": volley, "glow": glow, "health": health, "boost": boost}


func _run() -> void:
	var base := _build(BASE)
	var spread := _build(VARIANTS["spread"])
	var slow := _build(VARIANTS["slow"])
	var halt := _build(VARIANTS["halt"])

	for name in ["spread", "slow", "halt"]:
		var built: Dictionary = {"spread": spread, "slow": slow, "halt": halt}[name]
		_expect(built["health"] == base["health"], "%s keeps drone HP %d" % [name, base["health"]])
		_expect(not (built["glow"] as Color).is_equal_approx(base["glow"]), "%s glow colour differs from the pink drone" % name)
		_expect((built["volley"] as BarrageVolley).aim == BarrageVolley.Aim.EACH_SHOT, "%s aims at the target" % name)

	# 산탄: three pink-gold rounds in a 24° fan, no trail.
	var sv := spread["volley"] as BarrageVolley
	_expect(sv.layout == BarrageVolley.Layout.FAN and sv.count == 3 and is_equal_approx(sv.spread_degrees, 24.0), "spread drone fires a 3-way 24° fan")
	_expect(sv.shot.appearance.form == BulletAppearance.Form.ROUND and sv.shot.trail_effect == null, "spread drone fires plain rounds")
	_expect(is_equal_approx(sv.speed, 80.0), "spread drone rounds fly at 80px/s")

	# 느린탄: one slow violet orb that lingers.
	var lv := slow["volley"] as BarrageVolley
	_expect(lv.count == 1 and is_equal_approx(lv.speed, 55.0), "slow drone fires one 55px/s shot")
	_expect(lv.shot.appearance.core_size == Vector2(20, 20) and is_equal_approx(lv.shot.appearance.collision_radius, 8.0), "slow drone fires the orb preset")
	_expect(lv.shot.trail_effect == null, "slow drone orb has no trail")
	_expect(lv.shot.lifetime * lv.speed >= 360.0, "orb lives long enough to cross the playfield")

	# 정지탄: needle that brakes, warns red, re-aims and dashes.
	var hv := halt["volley"] as BarrageVolley
	_expect(hv.shot.appearance.form == BulletAppearance.Form.TEXTURED, "halt drone fires the needle")
	var types: Array = []
	for action in hv.shot.behavior.actions:
		types.append(action.type)
	_expect(types.has(BulletAction.Type.SPEED) and types.has(BulletAction.Type.TINT) and types.has(BulletAction.Type.HOMING), "halt needle brakes, tints and homes")
	_expect(types.find(BulletAction.Type.TINT) < types.find(BulletAction.Type.HOMING), "red warning comes before the dash")
	_expect(not halt["boost"], "halt drone opts out of fire-volume boost")

	# Presets validate and point at the variant scenes; pool gates them by Threat.
	for id in PRESETS:
		var preset := load(PRESETS[id]) as EncounterPreset
		_expect(preset != null and preset.encounter_id == StringName(id), "%s preset loads with its id" % id)
		if preset == null:
			continue
		var errors := preset.get_validation_errors()
		_expect(errors.is_empty(), "%s validates: %s" % [id, "; ".join(errors)])
		_expect(preset.members[0].enemy_scene.resource_path.contains("enemies/variants/"), "%s spawns a variant scene" % id)
	var pool := load("res://resources/encounters/pools/main_encounter_pool.tres") as EncounterPool
	var ids_at := func(threat: int) -> Array:
		var out := []
		for entry in pool.get_eligible_entries(threat):
			out.append(String(entry.preset.encounter_id))
		return out
	var threat1: Array = ids_at.call(1)
	var threat2: Array = ids_at.call(2)
	_expect(threat1.has("drone_spread_formation"), "spread drones join the pool at Threat 1")
	_expect(not threat1.has("drone_slow_zigzag") and not threat1.has("drone_halt_formation"), "slow and halt drones wait until Threat 2")
	_expect(threat2.has("drone_slow_zigzag") and threat2.has("drone_halt_formation"), "slow and halt drones join the pool at Threat 2")

	if failures.is_empty():
		print("PASS drone_variants_test")
		quit(0)
		return
	for failure in failures:
		printerr("FAIL: ", failure)
	quit(1)
