extends SceneTree
## Ordinary enemies must not all fire the pink needle: each role has its own
## bullet shape (see docs/design/combat.md "탄 어휘"). Builds every general-enemy
## pattern with the params its scene passes and inspects the resulting shots.

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _first_shots(sequence: BarrageSequence) -> Array[BarrageShot]:
	var shots: Array[BarrageShot] = []
	for step in sequence.steps:
		if step.action != BarrageStep.Action.FIRE:
			continue
		for volley in step.get_volleys():
			shots.append(volley.shot)
		break
	return shots


func _scene_params(scene_path: String) -> Dictionary:
	var enemy := (load(scene_path) as PackedScene).instantiate()
	var component := enemy.get_node("EnemyShootComponent") as EnemyShootComponent
	var params: Dictionary = component.pattern_params.duplicate()
	var script := component.pattern_script
	enemy.free()
	params["__script"] = script
	return params


func _build(scene_path: String) -> BarrageSequence:
	var params := _scene_params(scene_path)
	var script := params["__script"] as Script
	params.erase("__script")
	var sequence := script.new() as BarrageSequence
	sequence.build(params)
	_expect(sequence.validation_error().is_empty(), "%s pattern is valid: %s" % [scene_path, sequence.validation_error()])
	return sequence


func _run() -> void:
	var pink := Color(1.0, 0.22, 0.52)

	# Drone keeps the aimed needle with its diamond trail.
	var drone := _first_shots(_build("res://enemies/normal_enemy.tscn"))
	_expect(drone.size() == 1 and drone[0].appearance.form == BulletAppearance.Form.TEXTURED, "drone fires textured needle")
	_expect(drone[0].trail_effect != null, "drone needle keeps diamond trail")

	# Drone evolved shares aimed_burst_pattern and must keep the needle default.
	var drone_evolved := _first_shots(_build("res://enemies/evolved/drone_evolved.tscn"))
	_expect(drone_evolved[0].appearance.form == BulletAppearance.Form.TEXTURED and drone_evolved[0].trail_effect != null, "evolved drone keeps needle + trail by default")

	# Striker fan: pink rounds, no trail.
	var striker := _first_shots(_build("res://enemies/moving_enemy.tscn"))
	_expect(striker[0].appearance.form == BulletAppearance.Form.ROUND, "striker fires round bullets")
	_expect(striker[0].appearance.tint.is_equal_approx(pink), "striker rounds stay pink")
	_expect(striker[0].trail_effect == null, "striker rounds have no trail")

	# Interceptor burst: orange rice, no trail.
	var interceptor := _first_shots(_build("res://enemies/interceptor_enemy.tscn"))
	_expect(interceptor[0].appearance.form == BulletAppearance.Form.RICE, "interceptor fires rice bullets")
	_expect(interceptor[0].appearance.tint.is_equal_approx(Color(1, 0.55, 0.25)), "interceptor rice is orange")
	_expect(interceptor[0].trail_effect == null, "interceptor rice has no trail")
	_expect(preload("res://resources/projectiles/rice.tres").tint.is_equal_approx(pink), "tinting duplicates the preset instead of editing it")

	# Interceptor evolved inherits the scene and must get the same rice.
	var interceptor_evolved := _first_shots(_build("res://enemies/evolved/interceptor_evolved.tscn"))
	_expect(interceptor_evolved[0].appearance.form == BulletAppearance.Form.RICE, "evolved interceptor inherits rice")

	# Caster ring: pink rounds, no trail, 16 per ring.
	var caster_sequence := _build("res://enemies/shooting_enemy.tscn")
	var caster := _first_shots(caster_sequence)
	_expect(caster[0].appearance.form == BulletAppearance.Form.ROUND and caster[0].trail_effect == null, "caster rings are plain rounds")
	_expect(caster_sequence.steps[0].get_volleys()[0].count == 16, "caster ring count unchanged")

	# Caster evolved: forward ring pink, backward ring violet, both rounds.
	var evolved := _first_shots(_build("res://enemies/evolved/caster_evolved.tscn"))
	_expect(evolved.size() == 2, "evolved caster fires two rings per beat")
	if evolved.size() == 2:
		_expect(evolved[0].appearance.form == BulletAppearance.Form.ROUND and evolved[1].appearance.form == BulletAppearance.Form.ROUND, "evolved caster rings are rounds")
		_expect(evolved[0].appearance.tint.is_equal_approx(pink), "forward ring is pink")
		_expect(evolved[1].appearance.tint.is_equal_approx(Color(0.7, 0.42, 1.0)), "backward ring is violet")
		_expect(evolved[0].trail_effect == null and evolved[1].trail_effect == null, "evolved caster rings have no trail")

	# Unknown shape falls back to the needle rather than failing validation.
	var fallback := (load("res://patterns/aimed_burst_pattern.gd") as Script).new() as BarrageSequence
	fallback.build({"shape": "banana"})
	_expect(fallback.validation_error().is_empty() and _first_shots(fallback)[0].appearance.form == BulletAppearance.Form.TEXTURED, "unknown shape falls back to needle")

	if failures.is_empty():
		print("PASS enemy_bullet_vocabulary_test")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)
