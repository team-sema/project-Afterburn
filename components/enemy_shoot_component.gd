class_name EnemyShootComponent
extends Node

## Periodic aimed fire used as the default enemy offense.

@export_group("Pattern (takes precedence over legacy fire)")
## Must extend BarrageSequence with a parameterless, data-only constructor.
@export var pattern_script: Script
## Passed to the pattern's build(params) after _init(); patterns read keys with defaults.
@export var pattern_params: Dictionary = {}
## Opt in only for ordinary aimed patterns. Applied by spawn-time augments.
@export var pattern_fire_volume_boost := false
@export_group("Legacy fire (ignored when Pattern is set)")
@export var projectile_scene: PackedScene
## Optional new projectile recipe for directional fire; timers and gates stay here.
@export var barrage_shot: BarrageShot
## Delay from the end of one burst to the start of the next burst.
@export_range(0.2, 20.0, 0.05) var fire_interval := 2.0
## Number of aimed volleys fired in one burst. One preserves the original behavior.
@export_range(1, 12, 1) var burst_count := 1
## Delay between volleys within a burst.
@export_range(0.05, 2.0, 0.05) var burst_interval := 0.15
@export_range(20.0, 400.0, 1.0) var projectile_speed := 100.0
@export_range(1, 12, 1) var shot_count := 1
@export_range(0.0, 90.0, 1.0) var spread_degrees := 0.0
@export_group("Activation")
@export_range(0.0, 5.0, 0.05) var initial_delay := 0.75
## Starts the fire window only after the actor center enters VisibleRect. Useful
## for one-pass encounters that must never attack from offscreen.
@export var activate_on_visible_entry := false
## Zero keeps firing indefinitely after activation.
@export_range(0.0, 20.0, 0.05, "suffix:s") var active_duration := 0.0
## Prevents ordinary enemies from firing after descending into the player's
## starting band. Special attacks leave this disabled.
@export var apply_shot_threshold := false

var enemy: Enemy
@export_group("Legacy aiming (ignored when Pattern is set)")
## When enabled, projectiles receive launch(direction, speed). When disabled,
## projectile scenes are spawned without directional configuration.
@export var inject_target_direction := true
## Overrides target aiming and launches along this actor-local forward axis.
@export var use_actor_forward_direction := false
@export var local_forward_direction := Vector2.DOWN
@export_group("Target")
@export var targeting_component: TargetingComponent
var fire_timer: Timer
var _base_fire_interval := 2.0
var _base_burst_interval := 0.15
var _burst_volleys_remaining := 0
var _visible_pass_started := false
var _fire_window_active := false
var _active_elapsed := 0.0
var _volleys_fired := 0
var barrage_player: BarragePlayer
var pattern_error := ""
var _pattern: BarrageSequence
var _pattern_summary := {"rate": 0.0, "speed": 0.0}
var _pattern_action_rate := 1.0


func apply_fire_volume_boost(extra_shots: int, min_spread: float) -> void:
	if pattern_script == null:
		shot_count = maxi(shot_count + extra_shots, 1)
		spread_degrees = maxf(spread_degrees, min_spread)
		return
	if not pattern_fire_volume_boost or _pattern == null:
		return
	if barrage_player != null and barrage_player.running:
		push_error("Pattern fire volume must be configured before playback starts.")
		return
	# Each step has its own snapshot, even when the builder reused a Volley.
	_boost_pattern_volume(_pattern, extra_shots, min_spread)
	_pattern_summary = _pattern.emission_summary()


func _boost_pattern_volume(sequence: BarrageSequence, extra_shots: int, min_spread: float) -> void:
	for step in sequence.steps:
		if step.action != BarrageStep.Action.FIRE: continue
		for volley in step.get_volleys():
			if volley.layout == BarrageVolley.Layout.RING: continue
			var count := 1 if volley.layout == BarrageVolley.Layout.SINGLE else volley.count
			volley.layout = BarrageVolley.Layout.FAN
			volley.count = maxi(1, count + extra_shots)
			volley.spread_degrees = maxf(volley.spread_degrees, min_spread)


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "EnemyShootComponent must be attached directly to an Enemy.")
	if pattern_script != null:
		_prepare_pattern()
		return
	assert(projectile_scene != null or (barrage_shot != null and (inject_target_direction or use_actor_forward_direction)), "EnemyShootComponent requires a projectile source.")
	assert(barrage_shot == null or barrage_shot.is_valid(), "Invalid BarrageShot.")
	if inject_target_direction and not use_actor_forward_direction:
		assert(targeting_component != null, "Targeted EnemyShootComponent requires TargetingComponent.")
	if use_actor_forward_direction:
		assert(
			not local_forward_direction.is_zero_approx(),
			"Forward EnemyShootComponent requires a non-zero local forward direction.",
		)

	_base_fire_interval = fire_interval
	_base_burst_interval = burst_interval
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)

	if activate_on_visible_entry:
		process_priority = 20
		set_process(true)
		return
	_fire_window_active = true
	_schedule_initial_burst()


func _process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not activate_on_visible_entry and pattern_script == null:
		return
	if activate_on_visible_entry and not _visible_pass_started:
		if enemy.get_viewport_rect().has_point(enemy.global_position):
			_visible_pass_started = true
			_fire_window_active = true
			_active_elapsed = 0.0
			_schedule_initial_burst()
		return
	if not _fire_window_active:
		return
	_active_elapsed += delta
	if active_duration > 0.0 and _active_elapsed >= active_duration:
		_fire_window_active = false
		_burst_volleys_remaining = 0
		if fire_timer != null: fire_timer.stop()
		if barrage_player != null: barrage_player.stop()
		set_process(false)


func configure_baseline(interval: float, speed: float = -1.0) -> void:
	if pattern_script != null: return
	_base_fire_interval = interval
	fire_interval = interval
	if speed > 0.0:
		projectile_speed = speed
	if fire_timer != null:
		fire_timer.wait_time = _get_next_fire_delay()


func apply_action_rate_multiplier(multiplier: float) -> void:
	if not is_finite(multiplier): return
	var rate := maxf(0.01, multiplier)
	_pattern_action_rate = rate
	if pattern_script != null:
		if barrage_player != null: barrage_player.time_scale = rate
		return
	fire_interval = _base_fire_interval / rate
	burst_interval = _base_burst_interval / rate
	if fire_timer != null:
		fire_timer.wait_time = _get_next_fire_delay()


func _on_fire_timer_timeout() -> void:
	if pattern_script != null:
		_start_pattern.call_deferred()
		return
	if activate_on_visible_entry and not _fire_window_active:
		return
	if _burst_volleys_remaining > 0:
		_fire_next_burst_volley()
	else:
		_start_burst()


func _start_burst() -> void:
	if activate_on_visible_entry and not _fire_window_active:
		return
	_burst_volleys_remaining = maxi(1, burst_count)
	_fire_next_burst_volley()


func _fire_next_burst_volley() -> void:
	if activate_on_visible_entry and not _fire_window_active:
		return
	fire()
	_burst_volleys_remaining -= 1
	fire_timer.start(_get_next_fire_delay())


func _get_next_fire_delay() -> float:
	if _burst_volleys_remaining > 0:
		return burst_interval
	return fire_interval


func fire() -> void:
	# Pattern mode owns all fire scheduling; legacy manual fire must not overlap.
	if pattern_script != null: return
	if enemy == null or not is_instance_valid(enemy):
		return
	if activate_on_visible_entry and not _fire_window_active:
		return
	if _is_below_shot_threshold():
		return
	if use_actor_forward_direction:
		var forward := local_forward_direction.normalized().rotated(enemy.global_rotation)
		_fire_projectiles(forward)
	elif inject_target_direction:
		if targeting_component == null:
			push_error("Targeted EnemyShootComponent requires TargetingComponent.")
			return
		var target := targeting_component.get_target()
		if target == null:
			return
		var target_direction := targeting_component.get_direction_from(enemy.global_position)
		if target_direction == Vector2.ZERO:
			return
		_fire_projectiles(target_direction)
	else:
		_fire_projectiles()


func _fire_projectiles(target_direction: Variant = null) -> void:
	var projectile_parent := get_tree().get_first_node_in_group("gameplay_world")
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	if projectile_parent == null:
		return
	if barrage_shot != null and target_direction != null:
		if projectile_parent is Node2D:
			_volleys_fired += 1
			_spawn_barrage_volley.call_deferred(projectile_parent, enemy.global_position, target_direction, projectile_speed, maxi(1, shot_count), spread_degrees)
		return
	_volleys_fired += 1

	var count := maxi(1, shot_count)
	for index in count:
		var projectile := projectile_scene.instantiate() as Node2D
		projectile.global_position = enemy.global_position

		if target_direction != null and not projectile.has_method("launch"):
			push_error("EnemyShootComponent projectile must implement launch(direction, speed).")
			projectile.queue_free()
			continue

		projectile_parent.add_child.call_deferred(projectile)
		if target_direction != null:
			var direction: Vector2 = target_direction
			if count > 1:
				var weight := float(index) / float(count - 1)
				var angle_offset := lerpf(
					-spread_degrees * 0.5,
					spread_degrees * 0.5,
					weight,
				)
				direction = direction.rotated(deg_to_rad(angle_offset))
			projectile.call_deferred("launch", direction, projectile_speed)


func _spawn_barrage_volley(parent: Node2D, origin: Vector2, direction: Vector2, speed: float, count: int, spread: float) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
		return
	if not is_instance_valid(parent) or parent.is_queued_for_deletion() or not parent.is_inside_tree() or parent.get_viewport() != enemy.get_viewport():
		return
	if barrage_shot == null:
		return
	for index in count:
		var offset := lerpf(-spread * 0.5, spread * 0.5, float(index) / (count - 1)) if count > 1 else 0.0
		barrage_shot.spawn(parent, origin, direction.rotated(deg_to_rad(offset)), speed)


func has_visible_pass_started() -> bool:
	return _visible_pass_started


func is_fire_window_active() -> bool:
	return _fire_window_active


func get_volleys_fired() -> int:
	return _volleys_fired


func get_threat_projectile_rate() -> float:
	if pattern_script != null:
		return float(_pattern_summary.rate) * _pattern_action_rate if _pattern_can_fire() and _pattern_scheduled() else 0.0
	if activate_on_visible_entry and not _fire_window_active:
		return 0.0
	if enemy != null and _is_below_shot_threshold():
		return 0.0
	var cycle_duration := fire_interval + maxf(0.0, float(burst_count - 1) * burst_interval)
	return float(maxi(1, burst_count) * maxi(1, shot_count)) / maxf(0.05, cycle_duration)


func get_threat_reaction_time() -> float:
	if pattern_script != null:
		if not _pattern_can_fire() or not _pattern_scheduled(): return -1.0
		var size := enemy.get_viewport_rect().size
		return minf(size.x, size.y) / maxf(1.0, _pattern_summary.speed)
	if enemy == null or (activate_on_visible_entry and not _fire_window_active):
		return -1.0
	if _is_below_shot_threshold():
		return -1.0
	var playfield_size := enemy.get_viewport_rect().size
	var response_distance := minf(playfield_size.x, playfield_size.y)
	return response_distance / maxf(1.0, projectile_speed)


func _is_below_shot_threshold() -> bool:
	if not apply_shot_threshold:
		return false
	var visible_rect := enemy.get_viewport_rect()
	var threshold_y := (
		visible_rect.position.y
		+ visible_rect.size.y * enemy.augment_registry.shot_threshold_y_ratio
	)
	return enemy.global_position.y > threshold_y


func _schedule_initial_burst() -> void:
	if initial_delay > 0.0:
		fire_timer.start(initial_delay)
	else:
		if pattern_script != null: _start_pattern.call_deferred()
		else: _start_burst()


func _prepare_pattern() -> void:
	var base := pattern_script
	while base != null and base != preload("res://projectiles/barrage_sequence.gd"):
		base = base.get_base_script()
	if base == null or not pattern_script.can_instantiate():
		pattern_error = "pattern_script must extend BarrageSequence."
		push_error(pattern_error)
		set_process(false)
		return
	for method in pattern_script.get_script_method_list():
		if method.name == "_init" and method.args.size() > method.default_args.size():
			pattern_error = "Pattern _init must not require arguments."
			push_error(pattern_error)
			set_process(false)
			return
	_pattern = pattern_script.new() as BarrageSequence
	if _pattern != null:
		_pattern.build(pattern_params)
	pattern_error = "Pattern construction failed." if _pattern == null else _pattern.validation_error()
	if not pattern_error.is_empty():
		push_error(pattern_error)
		set_process(false)
		return
	_pattern = _pattern.snapshot()
	_pattern_summary = _pattern.emission_summary()
	barrage_player = BarragePlayer.new()
	barrage_player.name = "BarragePlayer"
	barrage_player.may_fire = _pattern_can_fire
	barrage_player.resolve_target = _pattern_target
	barrage_player.time_scale = _pattern_action_rate
	barrage_player.volley_fired.connect(_pattern_fired)
	add_child(barrage_player)
	# This timer is only the one-time activation delay, never the pattern clock.
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)
	process_priority = 20
	set_process(true)
	if not activate_on_visible_entry:
		_fire_window_active = true
		_schedule_initial_burst()


func _start_pattern() -> void:
	if _pattern == null or not _fire_window_active or not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_inside_tree(): return
	var world := get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if world == null: world = get_tree().current_scene as Node2D
	if not barrage_player.play(_pattern, enemy, world):
		pattern_error = barrage_player.last_error
		push_error(pattern_error)


func _pattern_can_fire() -> bool:
	return is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.is_queued_for_deletion() and _fire_window_active and not _is_below_shot_threshold() and (active_duration <= 0 or _active_elapsed < active_duration)


func _pattern_target() -> Node2D:
	if targeting_component == null: return null
	var target := targeting_component.get_target()
	return target if is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() else null


func _pattern_fired(projectiles: Array[Node2D]) -> void:
	if not projectiles.is_empty(): _volleys_fired += 1

func _pattern_scheduled() -> bool:
	return barrage_player != null and (barrage_player.running or (fire_timer != null and not fire_timer.is_stopped()))
