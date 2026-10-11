class_name TelegraphBeam
extends Node2D
## Straight telegraphed laser (BarrageShot.Kind.BEAM). A thin warning line shows
## the path without a hitbox, the beam thickens, then holds with a hitbox and
## an impact flare at its far end, and finally thins out. Fixed at the launch
## position and direction. Rules: combat.md 예고형 빔.

## Extra length past the viewport edge so the beam end is off screen.
const EDGE_MARGIN := 8.0
const SPARK_COUNT := 5
## Warning line: steady alpha after a short fade-in (no blinking).
const WARN_ALPHA := 0.75
const WARN_FADE_IN := 0.1

enum Phase { WARN, GROW, HOLD, FADE, DONE }

var warn_duration := 0.7
var grow_duration := 0.1
var hold_duration := 0.5
var fade_duration := 0.15
var warn_width := 1.5
var core_width := 6.0
var hit_width := 4.0
## 0 measures to the viewport edge at launch.
var beam_length := 0.0
var color := Color(1.0, 0.3, 0.5)
## Draws the impact glow and sparks at the far end while held (visual only).
var show_impact := true
var show_hitbox := false:
	set(value):
		show_hitbox = value
		queue_redraw()

var age := 0.0
var length := 0.0
var _direction := Vector2.DOWN
var _active := false
## Shape-less HitboxComponent handed to hurtboxes as the damage source; the
## beam segment is tested on the CPU against EnemyBullets.TARGET_GROUP.
var _hitbox: HitboxComponent
var _hitting := false
var _targets: Array[EnemyBulletPool.Target] = []


func launch(direction: Vector2, _speed: float) -> void:
	if not direction.is_finite() or direction.is_zero_approx():
		push_error("TelegraphBeam launch requires a finite nonzero direction.")
		queue_free()
		return
	_direction = direction.normalized()
	rotation = _direction.angle()
	length = beam_length if beam_length > 0.0 else _length_to_view_edge() + EDGE_MARGIN
	_build_hitbox()
	age = 0.0
	_active = true
	queue_redraw()


func get_phase() -> Phase:
	if age < warn_duration: return Phase.WARN
	if age < warn_duration + grow_duration: return Phase.GROW
	if age < warn_duration + grow_duration + hold_duration: return Phase.HOLD
	if age < total_duration(): return Phase.FADE
	return Phase.DONE


func total_duration() -> float:
	return warn_duration + grow_duration + hold_duration + fade_duration


func is_hitbox_active() -> bool:
	return _hitting


func get_end_point() -> Vector2:
	return global_position + _direction * length


func _physics_process(delta: float) -> void:
	if not _active:
		return
	age += delta
	var phase := get_phase()
	if phase == Phase.DONE:
		_active = false
		queue_free()
		return
	_hitting = phase == Phase.HOLD
	if _hitting:
		apply_contacts()
	queue_redraw()


## CPU collision of the held beam segment against player-side hurtboxes.
func apply_contacts() -> void:
	if not is_inside_tree():
		return
	EnemyBulletPool.collect_targets(get_tree(), _targets)
	var start := global_position
	var end := get_end_point()
	for target in _targets:
		if target.hurtbox.is_invincible:
			continue
		var hit: Variant = EnemyBulletPool.segment_hits(start, end, hit_width * 0.5, target)
		if hit != null:
			_hitbox.global_position = hit
			_hitbox._on_hurtbox_entered(target.hurtbox)


## True when `shape` at `shape_transform` overlaps the held beam
## (EnemyBullets.query_shape).
func overlaps_shape(shape: Shape2D, shape_transform: Transform2D) -> bool:
	if not _active or not _hitting:
		return false
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(length, hit_width)
	return shape.collide(shape_transform, rectangle, global_transform.translated_local(Vector2(length * 0.5, 0.0)))


## Visual width now: warn width, eased up to core width, held, then thinned out.
func current_width() -> float:
	match get_phase():
		Phase.WARN:
			return warn_width
		Phase.GROW:
			var t := (age - warn_duration) / maxf(grow_duration, 0.0001)
			return lerpf(warn_width, core_width, 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.0))
		Phase.HOLD:
			# Slight shimmer so a held beam reads as energy, not a static bar.
			return core_width * (1.0 + 0.06 * sin(age * TAU * 14.0))
		Phase.FADE:
			var t := (age - warn_duration - grow_duration - hold_duration) / maxf(fade_duration, 0.0001)
			return core_width * (1.0 - clampf(t, 0.0, 1.0))
	return 0.0


# --- Enemy bullet contract (SafeSpaceMeter, EnemyBullets) -----------------

func get_predicted_path(_seconds: float) -> PackedVector2Array:
	if not _active or is_queued_for_deletion() or get_phase() >= Phase.FADE:
		return PackedVector2Array()
	return PackedVector2Array([global_position, get_end_point()])


func get_hazard_radius() -> float:
	return hit_width * 0.5


func get_travel_velocity() -> Vector2:
	return Vector2.ZERO


func _build_hitbox() -> void:
	_hitbox = HitboxComponent.new()
	_hitbox.name = "HitboxComponent"
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	_hitbox.monitorable = false
	add_child(_hitbox)


func _length_to_view_edge() -> float:
	var rect := get_viewport_rect()
	var origin := global_position
	var best := 0.0
	# Distance along the ray to the farthest side it can still reach.
	for axis in 2:
		var d := _direction[axis]
		if absf(d) < 0.0001:
			continue
		var edge := rect.end[axis] if d > 0.0 else rect.position[axis]
		var t := (edge - origin[axis]) / d
		if t > 0.0:
			best = t if best == 0.0 else minf(best, t)
	return maxf(best, 0.0)


func _draw() -> void:
	if not _active:
		return
	var end := Vector2(length, 0.0)
	var phase := get_phase()
	if phase == Phase.WARN:
		# A steady thin line only; it fades in briefly instead of popping.
		var fade_in := clampf(age / WARN_FADE_IN, 0.0, 1.0)
		draw_line(Vector2.ZERO, end, Color(color.lightened(0.3), WARN_ALPHA * fade_in), warn_width, true)
		return
	var width := current_width()
	var alpha := 1.0
	if phase == Phase.FADE:
		alpha = clampf(width / maxf(core_width, 0.0001), 0.0, 1.0)
	draw_line(Vector2.ZERO, end, Color(color, 0.28 * alpha), width * 2.6, true)
	draw_line(Vector2.ZERO, end, Color(color.lightened(0.35), 0.7 * alpha), width * 1.5, true)
	draw_line(Vector2.ZERO, end, Color(1.0, 1.0, 1.0, alpha), maxf(1.0, width * 0.55), true)
	if phase == Phase.HOLD or phase == Phase.GROW:
		_draw_flare(Vector2.ZERO, width * 1.1, alpha)
		if show_impact:
			_draw_impact(end, width, alpha)
	if show_hitbox and is_hitbox_active():
		draw_rect(Rect2(0.0, -hit_width * 0.5, length, hit_width), Color(0.2, 1.0, 0.75, 0.7), false, 1.0)


func _draw_flare(center: Vector2, radius: float, alpha: float) -> void:
	draw_circle(center, radius * 1.6, Color(color, 0.3 * alpha), true, -1.0, true)
	draw_circle(center, radius * 0.8, Color(1.0, 1.0, 1.0, 0.85 * alpha), true, -1.0, true)


## Pulsing glow plus sparks that splash back from where the beam ends.
func _draw_impact(center: Vector2, width: float, alpha: float) -> void:
	var pulse := 0.5 + 0.5 * sin(age * TAU * 9.0)
	draw_circle(center, width * (2.0 + 0.6 * pulse), Color(color, 0.25 * alpha), true, -1.0, true)
	draw_circle(center, width * (1.0 + 0.3 * pulse), Color(1.0, 1.0, 1.0, 0.8 * alpha), true, -1.0, true)
	for index in SPARK_COUNT:
		# Deterministic per-spark angle and length that wobble over time.
		var spark_phase := float(index) * 1.618
		var spread := (float(index) - (SPARK_COUNT - 1) * 0.5) * 0.5
		var angle := PI + spread + 0.35 * sin(age * 11.0 + spark_phase * 3.0)
		var reach := width * (2.2 + 1.4 * (0.5 + 0.5 * sin(age * 17.0 + spark_phase * 5.0)))
		var tip := center + Vector2.from_angle(angle) * reach
		draw_line(center, tip, Color(color.lightened(0.5), 0.8 * alpha), 1.0, true)
