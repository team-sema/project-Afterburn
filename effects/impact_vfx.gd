class_name ImpactVfx
extends Node2D

## Shared hit-effect renderer for player weapons. One instance lives under the
## gameplay world and draws every flare, spark and area ring in a single custom
## draw, so projectiles that free themselves on hit can still leave an impact.

const NODE_NAME := &"ImpactVfx"
const GAMEPLAY_WORLD_GROUP := &"gameplay_world"
const ADDITIVE_MATERIAL := preload("res://effects/additive_unshaded_material.tres")
## Above enemies (0) and below enemy health bars (20).
const DRAW_Z_INDEX := 10

@export_range(1, 2048, 1) var max_sparks := 256
@export_range(1, 512, 1) var max_flares := 64
@export_range(1, 128, 1) var max_rings := 16

var _sparks: Array[Dictionary] = []
var _flares: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## Soft radial falloff shared by every flare; flat draw_circle discs read as
## solid blobs instead of light.
var _flare_texture: GradientTexture2D


## Emits `profile` at `position_global` using the renderer of `source`'s world.
## `direction` is the spray centre (usually opposite the shot's travel).
## `strength` scales flare size and spark count; `ring_radius` > 0 adds a ring.
## The overcharge tint follows `source`'s OverchargeVisualComponent, so a
## projectile keeps the state it was fired with.
static func emit_from(
	source: Node,
	position_global: Vector2,
	profile: ImpactProfile,
	direction := Vector2.DOWN,
	strength := 1.0,
	ring_radius := 0.0,
) -> void:
	if source == null or profile == null or not source.is_inside_tree():
		return
	var vfx := get_or_create(source)
	if vfx == null:
		return
	vfx.emit_impact(position_global, profile, direction, strength, _is_source_overcharged(source), ring_radius)


## Spray direction for a projectile hit: back against its travel.
static func against_travel(projectile: Node2D) -> Vector2:
	var move := projectile.get_node_or_null(^"MoveComponent") as MoveComponent
	if move != null and move.velocity.length_squared() > 0.0001:
		return -move.velocity
	return Vector2.DOWN.rotated(projectile.global_rotation)


static func get_or_create(source: Node) -> ImpactVfx:
	var tree := source.get_tree()
	if tree == null:
		return null
	var host := tree.get_first_node_in_group(GAMEPLAY_WORLD_GROUP)
	if host == null:
		host = tree.current_scene
	if host == null:
		host = tree.root
	var existing := host.get_node_or_null(NodePath(NODE_NAME)) as ImpactVfx
	if existing != null:
		return existing
	var vfx := ImpactVfx.new()
	vfx.name = NODE_NAME
	vfx.z_index = DRAW_Z_INDEX
	vfx.material = ADDITIVE_MATERIAL
	host.add_child(vfx)
	return vfx


static func _is_source_overcharged(source: Node) -> bool:
	var overcharge := source.get_node_or_null(^"OverchargeVisualComponent") as OverchargeVisualComponent
	return overcharge != null and overcharge.is_overcharge_active()


func _ready() -> void:
	_rng.randomize()
	_flare_texture = _build_flare_texture()
	set_process(false)


static func _build_flare_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.45),
		Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func emit_impact(
	position_global: Vector2,
	profile: ImpactProfile,
	direction := Vector2.DOWN,
	strength := 1.0,
	overcharged := false,
	ring_radius := 0.0,
) -> void:
	var glow := profile.glow_color
	var core := profile.core_color
	if overcharged:
		glow = OverchargeVisualComponent.tint_color(glow)
		core = OverchargeVisualComponent.tint_color(core)
	if profile.flare_radius > 0.0 and _flares.size() < max_flares:
		_flares.append({
			"position": position_global,
			"remaining": profile.flare_lifetime,
			"lifetime": profile.flare_lifetime,
			"radius": profile.flare_radius * strength,
			"glow": glow,
			"core": core,
		})
	if ring_radius > 0.0 and _rings.size() < max_rings:
		_rings.append({
			"position": position_global,
			"remaining": profile.ring_lifetime,
			"lifetime": profile.ring_lifetime,
			"radius": ring_radius,
			"width": profile.ring_width,
			"glow": glow,
		})
	var count := 0
	if profile.spark_count > 0:
		count = maxi(1, roundi(float(profile.spark_count) * strength))
	var base_angle := direction.angle() if direction.length_squared() > 0.0001 else PI * 0.5
	var spread := deg_to_rad(profile.spark_spread_degrees)
	for i in count:
		if _sparks.size() >= max_sparks:
			break
		var lifetime := profile.spark_lifetime * _rng.randf_range(0.7, 1.0)
		var angle := base_angle + _rng.randf_range(-spread, spread)
		_sparks.append({
			"position": position_global,
			"velocity": Vector2.from_angle(angle) * _rng.randf_range(profile.spark_speed_min, profile.spark_speed_max),
			"drag": profile.spark_drag,
			"length": profile.spark_length,
			"remaining": lifetime,
			"lifetime": profile.spark_lifetime,
			"glow": glow,
			"core": core,
		})
	set_process(true)
	queue_redraw()


func clear_impacts() -> void:
	_sparks.clear()
	_flares.clear()
	_rings.clear()
	set_process(false)
	queue_redraw()


func get_active_spark_count() -> int:
	return _sparks.size()


func get_active_flare_count() -> int:
	return _flares.size()


func get_active_ring_count() -> int:
	return _rings.size()


func _process(delta: float) -> void:
	for index in range(_sparks.size() - 1, -1, -1):
		var spark := _sparks[index]
		var remaining := float(spark["remaining"]) - delta
		if remaining <= 0.0:
			_sparks.remove_at(index)
			continue
		spark["remaining"] = remaining
		var velocity := (spark["velocity"] as Vector2) * exp(-float(spark["drag"]) * delta)
		spark["velocity"] = velocity
		spark["position"] = (spark["position"] as Vector2) + velocity * delta
	_age_entries(_flares, delta)
	_age_entries(_rings, delta)
	if _sparks.is_empty() and _flares.is_empty() and _rings.is_empty():
		set_process(false)
	queue_redraw()


func _age_entries(entries: Array[Dictionary], delta: float) -> void:
	for index in range(entries.size() - 1, -1, -1):
		var remaining := float(entries[index]["remaining"]) - delta
		if remaining <= 0.0:
			entries.remove_at(index)
			continue
		entries[index]["remaining"] = remaining


func _draw() -> void:
	for ring in _rings:
		var t := _life_fraction(ring)
		var glow := ring["glow"] as Color
		glow.a *= t
		var radius := float(ring["radius"]) * (0.4 + 0.6 * (1.0 - t))
		draw_arc(to_local(ring["position"]), radius, 0.0, TAU, 40, glow, float(ring["width"]), true)

	for flare in _flares:
		var t := _life_fraction(flare)
		var center := to_local(flare["position"])
		var radius := float(flare["radius"]) * (0.6 + 0.4 * t)
		var glow := flare["glow"] as Color
		glow.a *= t
		var glow_radius := radius * 2.2
		draw_texture_rect(_flare_texture, Rect2(center - Vector2.ONE * glow_radius, Vector2.ONE * glow_radius * 2.0), false, glow)
		var core := flare["core"] as Color
		core.a *= t
		var core_radius := radius * 0.8
		draw_texture_rect(_flare_texture, Rect2(center - Vector2.ONE * core_radius, Vector2.ONE * core_radius * 2.0), false, core)

	for spark in _sparks:
		var t := _life_fraction(spark)
		var velocity := spark["velocity"] as Vector2
		if velocity.length_squared() < 0.0001:
			continue
		var head := to_local(spark["position"])
		var tail := head - velocity.normalized() * float(spark["length"]) * (0.4 + 0.6 * t)
		var glow := spark["glow"] as Color
		glow.a *= t
		draw_line(tail, head, glow, 3.0, true)
		var core := spark["core"] as Color
		core.a *= t
		draw_line(tail, head, core, 1.2, true)


func _life_fraction(entry: Dictionary) -> float:
	return clampf(float(entry["remaining"]) / maxf(float(entry["lifetime"]), 0.001), 0.0, 1.0)
