extends SceneTree

## Telegraphed BEAM (combat.md 예고형 빔): no hitbox while warning/growing, a
## persistent hitbox while holding, none while fading, then removal. Fixed in
## place, reaches the view edge, predicts its segment, clears and pauses.

var failures: PackedStringArray = []
var _world: Node2D
var _hits := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_world = Node2D.new()
	_world.add_to_group("gameplay_world")
	root.add_child(_world)
	_test_validation()
	await _test_phases()
	await _test_fixed_and_contract()
	_world.queue_free()
	await process_frame
	if failures.is_empty():
		print("telegraph_beam_test: PASS")
		quit()
		return
	for failure in failures:
		push_error("telegraph_beam_test: %s" % failure)
	quit(1)


func _beam_shot() -> BarrageShot:
	var shot := BarrageShot.new()
	shot.kind = BarrageShot.Kind.BEAM
	shot.behavior = null
	shot.beam_warn_duration = 0.3
	shot.beam_grow_duration = 0.1
	shot.beam_hold_duration = 0.3
	shot.beam_fade_duration = 0.1
	shot.core_width = 8.0
	shot.hit_width = 4.0
	return shot


func _test_validation() -> void:
	_expect(_beam_shot().is_valid(), "a default beam shot is valid")
	var with_behavior := _beam_shot()
	with_behavior.behavior = BulletBehavior.new()
	_expect(not with_behavior.is_valid(), "a beam cannot carry a Behavior")
	var no_hold := _beam_shot()
	no_hold.beam_hold_duration = 0.0
	_expect(not no_hold.is_valid(), "a beam needs a positive hold time")
	var wide_hit := _beam_shot()
	wide_hit.hit_width = 12.0
	_expect(not wide_hit.is_valid(), "the hit width cannot exceed the visual width")
	var negative := _beam_shot()
	negative.beam_warn_duration = -0.1
	_expect(not negative.is_valid(), "negative phase times are rejected")
	var zero_speed := BarrageVolley.new()
	zero_speed.shot = _beam_shot()
	zero_speed.speed = 0.0
	_expect(zero_speed.is_valid(), "beam volleys accept speed 0")


func _test_phases() -> void:
	var target := _make_target(Vector2(100, 200))
	var beam := _beam_shot().spawn(_world, Vector2(100, 40), Vector2.DOWN, 0.0) as TelegraphBeam
	_expect(beam != null and beam.is_in_group(EnemyBullets.GROUP), "the beam spawns as an enemy bullet")
	if beam == null:
		return
	var bottom := beam.get_viewport_rect().end.y
	_expect(absf(beam.get_end_point().y - (bottom + TelegraphBeam.EDGE_MARGIN)) < 0.5, "the beam reaches past the view edge")
	_expect(beam.get_predicted_path(1.0).size() == 2, "a warning beam already predicts its segment")

	await _until(beam, 0.25)
	_expect(beam.get_phase() == TelegraphBeam.Phase.WARN, "the beam is still warning")
	_expect(not beam.is_hitbox_active() and _hits == 0, "no hitbox while warning")
	await _until(beam, 0.35)
	_expect(beam.get_phase() == TelegraphBeam.Phase.GROW, "the beam is growing")
	_expect(not beam.is_hitbox_active() and _hits == 0, "no hitbox while growing")
	_expect(beam.current_width() > 1.0 and beam.current_width() < 8.0, "the beam thickens while growing")

	await _until(beam, 0.6)
	_expect(beam.get_phase() == TelegraphBeam.Phase.HOLD and beam.is_hitbox_active(), "the hitbox is live while holding")
	_expect(_hits > 1, "a target inside the beam keeps getting hit (%d)" % _hits)
	target.is_invincible = true
	var before := _hits
	await physics_frame
	await physics_frame
	_expect(_hits == before, "an invincible target is not hit")
	target.is_invincible = false

	await _until(beam, 0.75)
	_expect(beam.get_phase() == TelegraphBeam.Phase.FADE and not beam.is_hitbox_active(), "the hitbox is off while fading")
	_expect(beam.get_predicted_path(1.0).is_empty(), "a fading beam predicts nothing")
	before = _hits
	await physics_frame
	await physics_frame
	_expect(_hits == before, "a fading beam does not hit")
	await _until(beam, 0.95)
	_expect(not is_instance_valid(beam) or beam.is_queued_for_deletion(), "the beam is removed after fading")
	target.queue_free()
	await process_frame


func _test_fixed_and_contract() -> void:
	var emitter := Node2D.new()
	_world.add_child(emitter)
	emitter.position = Vector2(60, 60)
	var volley := BarrageVolley.new()
	volley.shot = _beam_shot()
	volley.shot.beam_length = 120.0
	volley.speed = 0.0
	var sequence := BarrageSequence.new()
	sequence.fire(volley)
	var player := BarragePlayer.new()
	_world.add_child(player)
	var spawned: Array = []
	player.volley_fired.connect(func(projectiles: Array) -> void: spawned.append_array(projectiles))
	_expect(player.play(sequence, emitter, _world), "a beam volley plays (%s)" % player.last_error)
	await physics_frame
	var beam := spawned[0] as TelegraphBeam if not spawned.is_empty() else null
	_expect(beam != null, "the player fired a beam")
	if beam == null:
		return
	_expect(is_equal_approx(beam.length, 120.0), "a set beam length is used")
	_expect(beam.show_impact, "the impact flare is on by default")
	var quiet := _beam_shot()
	quiet.beam_impact = false
	var quiet_beam := quiet.spawn(_world, Vector2(20, 20), Vector2.DOWN, 0.0) as TelegraphBeam
	_expect(quiet_beam != null and not quiet_beam.show_impact, "beam_impact = false turns the impact flare off")
	if quiet_beam != null:
		quiet_beam.queue_free()
	emitter.position = Vector2(200, 200)
	emitter.queue_free()
	await physics_frame
	_expect(is_instance_valid(beam) and beam.global_position.is_equal_approx(Vector2(60, 60)), "the beam stays where it was fired")
	_expect(not EnemyBullets.apply_effect(beam, &"slow", 0.5), "beams ignore trajectory effects")

	paused = true
	var age := beam.age
	for _i in 4:
		await process_frame
	_expect(is_equal_approx(beam.age, age), "the beam freezes while the tree is paused")
	paused = false
	_expect(EnemyBullets.cancel(_world, beam, EnemyBullets.REASON_LAB), "the beam can be cleared")
	player.queue_free()
	await process_frame


func _make_target(position: Vector2) -> HurtboxComponent:
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	hurtbox.add_child(shape)
	_world.add_child(hurtbox)
	hurtbox.global_position = position
	hurtbox.hurt.connect(func(_hitbox: Variant) -> void: _hits += 1)
	return hurtbox


## Waits physics frames until the beam is at least `seconds` old.
func _until(beam: TelegraphBeam, seconds: float) -> void:
	for _i in 600:
		if not is_instance_valid(beam) or beam.is_queued_for_deletion() or beam.age >= seconds:
			return
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
