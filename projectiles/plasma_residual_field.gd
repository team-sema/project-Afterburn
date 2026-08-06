class_name PlasmaResidualField
extends Node2D

const ENEMY_HURTBOX_MASK := 1 << 1
const CIRCLE_POINT_COUNT := 48

var duration := 3.0
var radius := 16.0
var base_damage := 1
var max_bonus_mult := 1.0
var damage_multiplier := 1.0
var boss_damage_multiplier := 1.0

var _elapsed := 0.0
var _tick := 0.0
var _visual: Node2D


func _ready() -> void:
	z_index = -1
	_build_visual()


func configure(
	configured_duration: float,
	configured_radius: float,
	configured_damage: int,
	configured_max_bonus: float,
	configured_damage_multiplier: float,
	configured_boss_damage_multiplier: float,
) -> void:
	duration = maxf(0.05, configured_duration)
	radius = maxf(4.0, configured_radius)
	base_damage = maxi(1, configured_damage)
	max_bonus_mult = maxf(0.0, configured_max_bonus)
	damage_multiplier = maxf(0.01, configured_damage_multiplier)
	boss_damage_multiplier = maxf(0.01, configured_boss_damage_multiplier)


func _process(delta: float) -> void:
	_elapsed += delta
	_tick += delta
	if _elapsed >= duration:
		queue_free()
		return
	_update_visual(delta)
	if _tick < 0.25:
		return
	_tick = 0.0
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	var bonus := max_bonus_mult * t
	var damage := maxi(1, roundi(float(base_damage) * (0.25 + bonus * 0.35)))
	var world := get_world_2d()
	if world == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hitbox := HitboxComponent.new()
	for result in world.direct_space_state.intersect_shape(query, 64):
		var collider: Variant = result.get("collider")
		if not collider is HurtboxComponent:
			continue
		var hurtbox := collider as HurtboxComponent
		if hurtbox.is_invincible:
			continue
		hitbox.damage = _resolve_hit_damage(damage, hurtbox)
		hurtbox.hurt.emit(hitbox)
	hitbox.free()


func _resolve_hit_damage(damage: int, hurtbox: HurtboxComponent = null) -> int:
	var multiplier := damage_multiplier
	if hurtbox != null and not is_equal_approx(boss_damage_multiplier, 1.0):
		var node: Node = hurtbox.get_parent()
		while node != null and not (node is Enemy):
			node = node.get_parent()
		if node is Enemy and (node as Enemy).is_boss:
			multiplier *= boss_damage_multiplier
	return maxi(1, roundi(float(damage) * multiplier))


func _build_visual() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var field_fill := Polygon2D.new()
	field_fill.name = "FieldFill"
	field_fill.polygon = _circle_points(radius)
	field_fill.color = Color(0.12, 0.58, 1.0, 0.18)
	_visual.add_child(field_fill)

	var inner_glow := Polygon2D.new()
	inner_glow.name = "InnerGlow"
	inner_glow.polygon = _circle_points(radius * 0.68)
	inner_glow.color = Color(0.58, 0.18, 1.0, 0.11)
	_visual.add_child(inner_glow)

	var outer_ring := Line2D.new()
	outer_ring.name = "OuterRing"
	outer_ring.points = _circle_points(radius)
	outer_ring.closed = true
	outer_ring.width = 1.5
	outer_ring.default_color = Color(0.45, 0.92, 1.0, 0.72)
	_visual.add_child(outer_ring)

	var pulse_ring := Line2D.new()
	pulse_ring.name = "PulseRing"
	pulse_ring.points = _circle_points(radius * 0.72)
	pulse_ring.closed = true
	pulse_ring.width = 1.0
	pulse_ring.default_color = Color(0.78, 0.32, 1.0, 0.5)
	_visual.add_child(pulse_ring)


func _update_visual(delta: float) -> void:
	if _visual == null:
		return
	var fade_in := clampf(_elapsed / 0.12, 0.0, 1.0)
	var fade_out := clampf((duration - _elapsed) / 0.35, 0.0, 1.0)
	_visual.modulate.a = fade_in * fade_out
	var pulse := 1.0 + sin(_elapsed * TAU * 0.8) * 0.025
	_visual.scale = Vector2.ONE * pulse
	_visual.rotation += delta * 0.08


func _circle_points(circle_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in CIRCLE_POINT_COUNT:
		var angle := TAU * float(index) / float(CIRCLE_POINT_COUNT)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
