class_name LaserWeaponSystem
extends WeaponSystem

## Piercing beam that always reaches the top of the playfield and damages every
## enemy hurtbox inside its hit width each tick.

const BEAM_LOCAL_START := Vector2(0, -6)
const PLAYFIELD_TOP_MARGIN := 8.0
const ENEMY_HURTBOX_MASK := 1 << 1
const HIT_QUERY_BATCH := 64

@export_range(0.1, 8.0, 0.1) var beam_width_multiplier := 1.0
## Damage band width before width multipliers; matches the bright core + tight
## glow of the beam shader. The faint wide glow outside it is visual only.
@export_range(0.5, 32.0, 0.5) var beam_hit_width := 3.0
@export_range(0.0, 1.0, 0.01) var beam_expand_duration := 0.18
@export_range(0.02, 10.0, 0.01) var base_tick_interval := 0.1
@export_range(1, 200, 1) var base_tick_damage := 3
@export var impact_profile: ImpactProfile = preload("res://effects/impact_profiles/laser.tres")
## Impact flare/spark scale at refract fork targets relative to primary hits.
@export_range(0.0, 2.0, 0.05) var refract_impact_strength := 0.6

@onready var glow_line: Sprite2D = $GlowLine
@onready var core_line: Line2D = $CoreLine
@onready var refract_vfx = $RefractVfx
@onready var damage_tick_timer: Timer = $DamageTickTimer
@onready var damage_hitbox: HitboxComponent = $DamageHitbox

var base_core_width: float
var base_glow_width_scale: float
var _base_core_alpha: float
var _base_glow_alpha: float
var _beam_material: ShaderMaterial
var _beam_width_tween: Tween
## enemy instance id -> {start: float, last_hit: float} of the current contact run.
var _heat_stacks: Dictionary = {}
## Gameplay seconds accumulated from _physics_process delta. Heat stack
## intervals use this so tree pause does not advance or expire them.
var _clock := 0.0
var _pulse_on := true
var _pulse_elapsed := 0.0
## 0..1 visual intensity for pulse fade (damage still uses `_pulse_on`).
var _pulse_beam_alpha := 1.0
## laser_whip springs, in global x scaled by sway_gain. Tip and mid-beam chase
## the ship; their offsets from it bend the beam (laser.md 채찍 광선).
var _whip_active := false
var _whip_tip_x := 0.0
var _whip_tip_v := 0.0
var _whip_mid_x := 0.0
var _whip_mid_v := 0.0
## Glow sprite width scale for the straight beam body. The startup tween drives
## this; the whip curve widens the sprite on top of it.
var glow_body_scale_x := 0.0:
	set(value):
		glow_body_scale_x = value
		if glow_line != null:
			glow_line.scale.x = value + _glow_extra_scale_x
var _glow_extra_scale_x := 0.0
## laser_spectrum_prism side beams: {angle, core: Line2D, glow: Sprite2D, material}.
var _side_beams: Array[Dictionary] = []


func _ready() -> void:
	base_core_width = core_line.width
	base_glow_width_scale = glow_line.scale.x
	glow_body_scale_x = glow_line.scale.x
	_base_core_alpha = core_line.default_color.a
	_base_glow_alpha = glow_line.self_modulate.a
	_beam_material = glow_line.material as ShaderMaterial
	damage_hitbox.damage = base_tick_damage
	damage_tick_timer.timeout.connect(apply_damage_tick)
	_sync_side_beams()
	_apply_stat_multipliers()
	damage_tick_timer.start()
	_update_beam_visual(_full_beam_endpoint())
	_apply_pulse_beam_alpha()
	restart_beam_width_animation()


func _on_weapon_setup() -> void:
	connect_weapon_trait_changed(_on_weapon_trait_changed)
	_heat_stacks.clear()
	_pulse_on = true
	_pulse_elapsed = 0.0
	_pulse_beam_alpha = 1.0
	_whip_active = false
	refract_vfx.clear_segments()
	_sync_side_beams()
	_apply_stat_multipliers()
	_apply_pulse_beam_alpha()
	restart_beam_width_animation()


func _on_weapon_trait_changed(changed_weapon_id: StringName, _trait_id: StringName, _new_rank: int) -> void:
	if changed_weapon_id != get_weapon_id():
		return
	_sync_side_beams()
	_apply_stat_multipliers()
	restart_beam_width_animation()


func _physics_process(delta: float) -> void:
	_clock += delta
	if is_shutdown:
		return
	_update_pulse(delta)
	_update_whip(delta)
	_update_beam_visual(_full_beam_endpoint())
	_apply_pulse_beam_alpha()


func apply_damage_tick() -> void:
	if is_shutdown:
		return
	if has_trait(&"laser_pulse") and not _pulse_on:
		return
	var endpoint := _full_beam_endpoint()
	_update_beam_visual(endpoint)
	_damage_all_along_beam(endpoint)
	_prune_heat_stacks()


## Resonance bonus: one extra damage tick (nothing while the pulse is off).
func fire_bonus_shot() -> bool:
	if is_shutdown or (has_trait(&"laser_pulse") and not _pulse_on):
		return false
	apply_damage_tick()
	return true


## Shared by the visual beam and the damage band.
func get_beam_width_multiplier() -> float:
	return beam_width_multiplier * float(get_trait_param(&"laser_wide_lens", &"width_mult", 1.0))


func get_beam_hit_width() -> float:
	return beam_hit_width * get_beam_width_multiplier()


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	damage_tick_timer.wait_time = base_tick_interval / get_effective_fire_rate_multiplier()
	var width_mult := get_beam_width_multiplier()
	_stop_beam_width_tween()
	core_line.width = base_core_width * width_mult
	glow_body_scale_x = base_glow_width_scale * width_mult


func set_beam_width_multiplier(multiplier: float) -> void:
	beam_width_multiplier = maxf(0.1, multiplier)
	if not is_node_ready():
		return
	_apply_stat_multipliers()


func restart_beam_width_animation() -> void:
	if not is_node_ready():
		return
	_stop_beam_width_tween()
	var width_mult := get_beam_width_multiplier()
	core_line.width = 0.0
	glow_body_scale_x = 0.0
	if beam_expand_duration <= 0.0:
		core_line.width = base_core_width * width_mult
		glow_body_scale_x = base_glow_width_scale * width_mult
		return

	_beam_width_tween = create_tween().set_parallel(true)
	_beam_width_tween.tween_property(
		core_line,
		"width",
		base_core_width * width_mult,
		beam_expand_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_beam_width_tween.tween_property(
		self,
		"glow_body_scale_x",
		base_glow_width_scale * width_mult,
		beam_expand_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_weapon_shutdown() -> void:
	disconnect_weapon_trait_changed(_on_weapon_trait_changed)
	_stop_beam_width_tween()
	refract_vfx.clear_segments()
	set_physics_process(false)
	visible = false
	if damage_tick_timer != null:
		damage_tick_timer.stop()
		if damage_tick_timer.timeout.is_connected(apply_damage_tick):
			damage_tick_timer.timeout.disconnect(apply_damage_tick)


func _stop_beam_width_tween() -> void:
	if _beam_width_tween != null:
		_beam_width_tween.kill()
		_beam_width_tween = null


func _full_beam_endpoint() -> Vector2:
	var top_local := to_local(Vector2(global_position.x, PLAYFIELD_TOP_MARGIN))
	return Vector2(0.0, minf(BEAM_LOCAL_START.y, top_local.y))


func _update_whip(delta: float) -> void:
	var gain := float(get_trait_param(&"laser_whip", &"sway_gain", 3.0))
	var ship_x := global_position.x * gain
	var active := has_trait(&"laser_whip")
	if not active or not _whip_active:
		# Start (or stay) straight: springs rest on the ship.
		_whip_active = active
		_whip_tip_x = ship_x
		_whip_mid_x = ship_x
		_whip_tip_v = 0.0
		_whip_mid_v = 0.0
		return
	var stiffness := float(get_trait_param(&"laser_whip", &"tip_stiffness", 90.0))
	var damping := float(get_trait_param(&"laser_whip", &"tip_damping", 12.0))
	var mid_stiffness := stiffness * float(get_trait_param(&"laser_whip", &"mid_stiffness_mult", 2.2))
	var mid_damping := damping * float(get_trait_param(&"laser_whip", &"mid_damping_mult", 1.4))
	# Substeps keep the stiffer mid spring stable at low frame rates.
	var step := delta / 4.0
	for _i in 4:
		_whip_tip_v += ((ship_x - _whip_tip_x) * stiffness - _whip_tip_v * damping) * step
		_whip_tip_x += _whip_tip_v * step
		_whip_mid_v += ((ship_x - _whip_mid_x) * mid_stiffness - _whip_mid_v * mid_damping) * step
		_whip_mid_x += _whip_mid_v * step


## x = beam tip lateral offset, y = mid-beam curve height (local px, both 0 when straight).
func get_whip_shape(endpoint: Vector2 = _full_beam_endpoint()) -> Vector2:
	if not _whip_active:
		return Vector2.ZERO
	var ship_x := global_position.x * float(get_trait_param(&"laser_whip", &"sway_gain", 3.0))
	var limit := BEAM_LOCAL_START.distance_to(endpoint) * float(
		get_trait_param(&"laser_whip", &"max_sway_ratio", 0.18)
	)
	var tip := clampf(_whip_tip_x - ship_x, -limit, limit)
	var mid := clampf(_whip_mid_x - ship_x, -limit, limit)
	return Vector2(tip, (mid - tip * 0.5) * float(get_trait_param(&"laser_whip", &"bend", 0.25)))


## Beam centre line in local space: straight chord to the swayed tip plus the
## mid-beam curve. Two points when the beam is straight.
func get_beam_points(endpoint: Vector2 = _full_beam_endpoint()) -> PackedVector2Array:
	var shape := get_whip_shape(endpoint)
	if shape.is_zero_approx():
		return PackedVector2Array([BEAM_LOCAL_START, endpoint])
	var segments := maxi(1, int(get_trait_param(&"laser_whip", &"segments", 12)))
	var points := PackedVector2Array()
	for index in segments + 1:
		var u := float(index) / float(segments)
		var point := BEAM_LOCAL_START.lerp(endpoint, u)
		point.x += shape.x * u + shape.y * 4.0 * u * (1.0 - u)
		points.append(point)
	return points


## Every beam centre line in local space: the main beam first, then the
## laser_spectrum_prism side beams (the main beam turned about the muzzle and
## stretched by 1/cos so their tips reach the same height).
func get_beam_paths(endpoint: Vector2 = _full_beam_endpoint()) -> Array[PackedVector2Array]:
	var main := get_beam_points(endpoint)
	var paths: Array[PackedVector2Array] = [main]
	for side in _side_beams:
		paths.append(_side_beam_points(main, float(side["angle"])))
	return paths


func _side_beam_points(main: PackedVector2Array, angle: float) -> PackedVector2Array:
	var stretch := 1.0 / cos(angle)
	var points := PackedVector2Array()
	for point in main:
		points.append(BEAM_LOCAL_START + (point - BEAM_LOCAL_START).rotated(angle) * stretch)
	return points


func _sync_side_beams() -> void:
	var wanted := has_trait(&"laser_spectrum_prism") and is_node_ready()
	if wanted != _side_beams.is_empty():
		return
	for side in _side_beams:
		(side["core"] as Node).queue_free()
		(side["glow"] as Node).queue_free()
	_side_beams.clear()
	if not wanted:
		return
	var angle := deg_to_rad(float(get_trait_param(&"laser_spectrum_prism", &"side_angle_deg", 12.0)))
	for sign_value in [-1.0, 1.0]:
		var glow := glow_line.duplicate() as Sprite2D
		var material := (glow_line.material as ShaderMaterial).duplicate() as ShaderMaterial
		glow.material = material
		var core := core_line.duplicate() as Line2D
		add_child(glow)
		add_child(core)
		_side_beams.append({"angle": angle * sign_value, "core": core, "glow": glow, "material": material})


func _update_beam_visual(endpoint: Vector2) -> void:
	var points := get_beam_points(endpoint)
	core_line.points = points
	var curve := get_whip_shape(endpoint).y
	_update_glow_beam(points[0], points[points.size() - 1], curve)
	for side in _side_beams:
		var angle := float(side["angle"])
		var side_points := _side_beam_points(points, angle)
		var core := side["core"] as Line2D
		core.points = side_points
		core.width = core_line.width
		_layout_glow(
			side["glow"],
			side["material"],
			side_points[0],
			side_points[side_points.size() - 1],
			Vector2(curve, 0.0).rotated(angle) / cos(angle),
		)


func _update_glow_beam(start: Vector2, end: Vector2, curve: float = 0.0) -> void:
	_glow_extra_scale_x = _layout_glow(glow_line, _beam_material, start, end, Vector2(curve, 0.0))


## Places one glow sprite along start->end and returns the extra width scale
## that leaves room for the curve inside its quad.
func _layout_glow(
	sprite: Sprite2D,
	material: ShaderMaterial,
	start: Vector2,
	end: Vector2,
	curve: Vector2,
) -> float:
	var direction := end - start
	var texture_size := sprite.texture.get_size()
	if texture_size.y <= 0.0 or texture_size.x <= 0.0:
		return 0.0
	sprite.position = (start + end) * 0.5
	sprite.rotation = direction.angle() - PI * 0.5
	sprite.scale.y = direction.length() / texture_size.y
	# Widen the sprite so the shader can draw the curve inside its quad.
	var curve_px := curve.dot(Vector2.RIGHT.rotated(sprite.rotation))
	var body_px := glow_body_scale_x * texture_size.x
	var sprite_px := body_px + 2.0 * absf(curve_px)
	var extra := (sprite_px - body_px) / texture_size.x
	sprite.scale.x = glow_body_scale_x + extra
	if material != null:
		material.set_shader_parameter(&"beam_length", direction.length())
		material.set_shader_parameter(&"beam_time", _clock)
		material.set_shader_parameter(
			&"body_fraction",
			body_px / sprite_px if sprite_px > 0.0 else 1.0,
		)
		material.set_shader_parameter(
			&"curve_offset",
			curve_px / (sprite_px * 0.5) if sprite_px > 0.0 else 0.0,
		)
	return extra


func _update_pulse(delta: float) -> void:
	if not has_trait(&"laser_pulse"):
		_pulse_on = true
		_pulse_beam_alpha = 1.0
		return
	var on_duration := float(get_trait_param(&"laser_pulse", &"on_duration", 0.7))
	var off_duration := float(get_trait_param(&"laser_pulse", &"off_duration", 0.35))
	var fade_out := float(get_trait_param(&"laser_pulse", &"fade_out_duration", 0.12))
	var fade_in := float(get_trait_param(&"laser_pulse", &"fade_in_duration", 0.05))
	_pulse_elapsed += delta
	var period := on_duration if _pulse_on else off_duration
	if _pulse_elapsed >= period:
		_pulse_elapsed = 0.0
		_pulse_on = not _pulse_on
	var target := 1.0 if _pulse_on else 0.0
	if target > _pulse_beam_alpha:
		_pulse_beam_alpha = (
			1.0 if fade_in <= 0.0
			else move_toward(_pulse_beam_alpha, 1.0, delta / fade_in)
		)
	elif target < _pulse_beam_alpha:
		_pulse_beam_alpha = (
			0.0 if fade_out <= 0.0
			else move_toward(_pulse_beam_alpha, 0.0, delta / fade_out)
		)


func _apply_pulse_beam_alpha() -> void:
	var intensity := clampf(_pulse_beam_alpha, 0.0, 1.0)
	var core_color := core_line.default_color
	core_color.a = _base_core_alpha * intensity
	core_line.default_color = core_color
	var glow_mod := glow_line.self_modulate
	glow_mod.a = _base_glow_alpha * intensity
	glow_line.self_modulate = glow_mod
	var show_beam := intensity > 0.001
	core_line.visible = show_beam
	glow_line.visible = show_beam
	for side in _side_beams:
		var core := side["core"] as Line2D
		var glow := side["glow"] as Sprite2D
		core.default_color = core_color
		glow.self_modulate = glow_mod
		core.visible = show_beam
		glow.visible = show_beam


func _trait_damage_mult() -> float:
	var mult := float(get_trait_param(&"laser_wide_lens", &"damage_mult", 1.0))
	mult *= float(get_trait_param(&"laser_whip", &"damage_mult", 1.0))
	mult *= float(get_trait_param(&"laser_spectrum_prism", &"damage_mult", 1.0))
	if has_trait(&"laser_pulse") and _pulse_on:
		mult *= float(get_trait_param(&"laser_pulse", &"active_damage_mult", 2.0))
	return mult


func _heat_bonus_for(enemy: Node) -> float:
	if not has_trait(&"laser_heat_stack") or enemy == null:
		return 0.0
	var id := enemy.get_instance_id()
	var now := _clock
	var grace := float(get_trait_param(&"laser_heat_stack", &"contact_grace", 0.5))
	var stack_interval := maxf(0.01, float(get_trait_param(&"laser_heat_stack", &"stack_interval", 0.5)))
	var stack_bonus := float(get_trait_param(&"laser_heat_stack", &"stack_bonus", 0.15))
	var max_bonus := float(get_trait_param(&"laser_heat_stack", &"max_bonus", 0.9))
	var entry: Dictionary = _heat_stacks.get(id, {})
	# A gap longer than the grace window ends the contact run; restart from zero.
	if entry.is_empty() or now - float(entry["last_hit"]) > grace:
		entry = {"start": now}
	entry["last_hit"] = now
	_heat_stacks[id] = entry
	# Small epsilon keeps accumulated float deltas from landing just under a step.
	var stacks := floori((now - float(entry["start"])) / stack_interval + 0.0001)
	return minf(max_bonus, float(stacks) * stack_bonus)


func _prune_heat_stacks() -> void:
	if _heat_stacks.is_empty():
		return
	var grace := float(get_trait_param(&"laser_heat_stack", &"contact_grace", 0.5))
	for id in _heat_stacks.keys():
		if _clock - float(_heat_stacks[id]["last_hit"]) > grace:
			_heat_stacks.erase(id)


func _damage_all_along_beam(endpoint: Vector2) -> void:
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	# Each beam hits on its own: a hurtbox under two spectrum beams takes two hits.
	var primary_hits: Array[Dictionary] = []
	for path in get_beam_paths(endpoint):
		var points := PackedVector2Array()
		for point in path:
			points.append(to_global(point))
		_damage_along_path(space, points, primary_hits)

	if has_trait(&"laser_refract") and not primary_hits.is_empty():
		_apply_refract(primary_hits)


func _damage_along_path(
	space: PhysicsDirectSpaceState2D,
	points: PackedVector2Array,
	primary_hits: Array[Dictionary],
) -> void:
	# One hit-width rectangle per beam segment (a single one when straight).
	# Gather every overlap first; one hurtbox may report several shapes or
	# segments but is hit once per tick.
	var hurtboxes: Array[HurtboxComponent] = []
	var seen: Dictionary = {}
	for index in points.size() - 1:
		var segment := points[index + 1] - points[index]
		if segment.length_squared() < 0.0001:
			continue
		var shape := RectangleShape2D.new()
		shape.size = Vector2(get_beam_hit_width(), segment.length())
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		# Rectangle local +Y runs along the segment.
		query.transform = Transform2D(segment.angle() - PI * 0.5, points[index] + segment * 0.5)
		query.collision_mask = ENEMY_HURTBOX_MASK
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var exclude: Array[RID] = []
		while true:
			query.exclude = exclude
			var batch := space.intersect_shape(query, HIT_QUERY_BATCH)
			for result in batch:
				exclude.append(result["rid"])
				var hurtbox := result.get("collider") as HurtboxComponent
				if hurtbox == null or seen.has(hurtbox.get_instance_id()):
					continue
				seen[hurtbox.get_instance_id()] = true
				hurtboxes.append(hurtbox)
			if batch.size() < HIT_QUERY_BATCH:
				break

	# Sparks fly back toward the muzzle along this beam.
	var back := (points[0] - points[points.size() - 1]).normalized()
	for hurtbox in hurtboxes:
		if not is_instance_valid(hurtbox) or hurtbox.is_invincible:
			continue
		var contact := _closest_point_on_beam(hurtbox.global_position, points)
		primary_hits.append({"collider": hurtbox, "position": contact})
		_apply_beam_hit(hurtbox, 1.0)
		ImpactVfx.emit_from(self, contact, impact_profile, back)


func _closest_point_on_beam(target: Vector2, points: PackedVector2Array) -> Vector2:
	var best := points[0]
	var best_distance := INF
	for index in points.size() - 1:
		var candidate := Geometry2D.get_closest_point_to_segment(target, points[index], points[index + 1])
		var distance := candidate.distance_squared_to(target)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _apply_beam_hit(hurtbox: HurtboxComponent, extra_mult: float) -> void:
	var enemy := _enemy_from_hurtbox(hurtbox)
	var heat := _heat_bonus_for(enemy)
	var raw := maxi(1, roundi(float(base_tick_damage) * _trait_damage_mult() * (1.0 + heat) * extra_mult))
	damage_hitbox.damage = resolve_hit_damage(raw, hurtbox)
	hurtbox.hurt.emit(damage_hitbox)


func _apply_refract(primary_hits: Array[Dictionary]) -> void:
	var fork_mult := float(get_trait_param(&"laser_refract", &"fork_damage_mult", 0.55))
	var primary_enemies: Array[Node] = []
	for hit in primary_hits:
		var hurtbox := hit.get("collider") as HurtboxComponent
		var enemy := _enemy_from_hurtbox(hurtbox)
		if enemy != null:
			primary_enemies.append(enemy)
	for hit in primary_hits:
		var origin: Vector2 = hit.get("position", global_position)
		var source := _enemy_from_hurtbox(hit.get("collider") as HurtboxComponent)
		var nearest := _nearest_other_enemy(origin, source, primary_enemies)
		if nearest == null:
			continue
		var hurtbox := nearest.get_node_or_null("HurtboxComponent") as HurtboxComponent
		if hurtbox == null or hurtbox.is_invincible:
			continue
		_apply_beam_hit(hurtbox, fork_mult)
		_show_refract_visual(origin, hurtbox.global_position)
		ImpactVfx.emit_from(
			self,
			hurtbox.global_position,
			impact_profile,
			origin - hurtbox.global_position,
			refract_impact_strength,
		)


func _show_refract_visual(from_global: Vector2, target_global: Vector2) -> void:
	if refract_vfx != null:
		refract_vfx.flash_segment(from_global, target_global)


func _nearest_other_enemy(origin: Vector2, exclude: Node, also_exclude: Array[Node]) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy == exclude or also_exclude.has(enemy):
			continue
		var dist := origin.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _enemy_from_hurtbox(hurtbox: HurtboxComponent) -> Node:
	if hurtbox == null:
		return null
	var node: Node = hurtbox
	while node != null:
		if node.is_in_group("enemies"):
			return node
		node = node.get_parent()
	return hurtbox.get_parent()
