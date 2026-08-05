class_name LaserWeaponSystem
extends WeaponSystem

## Piercing beam that always reaches the top of the playfield and damages every
## enemy hurtbox along its path each tick.

const BEAM_LOCAL_START := Vector2(0, -6)
const PLAYFIELD_TOP_MARGIN := 8.0

@export_range(0.1, 8.0, 0.1) var beam_width_multiplier := 1.0
@export_range(0.0, 1.0, 0.01) var beam_expand_duration := 0.18
@export_range(0.02, 10.0, 0.01) var base_tick_interval := 0.1
@export_range(1, 200, 1) var base_tick_damage := 3

@onready var glow_line: Sprite2D = $GlowLine
@onready var core_line: Line2D = $CoreLine
@onready var damage_tick_timer: Timer = $DamageTickTimer
@onready var damage_hitbox: HitboxComponent = $DamageHitbox

var base_core_width: float
var base_glow_width_scale: float
var _beam_width_tween: Tween
## enemy instance id -> {stacks: int, last_time: float}
var _heat_stacks: Dictionary = {}
var _pulse_on := true
var _pulse_elapsed := 0.0


func _ready() -> void:
	base_core_width = core_line.width
	base_glow_width_scale = glow_line.scale.x
	damage_hitbox.damage = base_tick_damage
	damage_tick_timer.timeout.connect(apply_damage_tick)
	_apply_stat_multipliers()
	damage_tick_timer.start()
	_update_beam_visual(_full_beam_endpoint())
	restart_beam_width_animation()


func _on_weapon_setup() -> void:
	connect_weapon_trait_changed(_on_weapon_trait_changed)
	_heat_stacks.clear()
	_pulse_on = true
	_pulse_elapsed = 0.0
	_apply_stat_multipliers()
	restart_beam_width_animation()


func _on_weapon_trait_changed(changed_weapon_id: StringName, _trait_id: StringName, _new_rank: int) -> void:
	if changed_weapon_id != get_weapon_id():
		return
	_apply_stat_multipliers()
	restart_beam_width_animation()


func _physics_process(delta: float) -> void:
	if is_shutdown:
		return
	_update_pulse(delta)
	_update_beam_visual(_full_beam_endpoint())
	_update_beam_visibility()


func apply_damage_tick() -> void:
	if is_shutdown:
		return
	if has_trait(&"laser_pulse") and not _pulse_on:
		return
	var endpoint := _full_beam_endpoint()
	_update_beam_visual(endpoint)
	_damage_all_along_beam(endpoint)


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	damage_tick_timer.wait_time = base_tick_interval / get_effective_fire_rate_multiplier()
	var width_mult := beam_width_multiplier
	width_mult *= float(get_trait_param(&"laser_wide_lens", &"width_mult", 1.0))
	_stop_beam_width_tween()
	core_line.width = base_core_width * width_mult
	glow_line.scale.x = base_glow_width_scale * width_mult


func set_beam_width_multiplier(multiplier: float) -> void:
	beam_width_multiplier = maxf(0.1, multiplier)
	if not is_node_ready():
		return
	_apply_stat_multipliers()


func restart_beam_width_animation() -> void:
	if not is_node_ready():
		return
	_stop_beam_width_tween()
	var width_mult := beam_width_multiplier * float(get_trait_param(&"laser_wide_lens", &"width_mult", 1.0))
	core_line.width = 0.0
	glow_line.scale.x = 0.0
	if beam_expand_duration <= 0.0:
		core_line.width = base_core_width * width_mult
		glow_line.scale.x = base_glow_width_scale * width_mult
		return

	_beam_width_tween = create_tween().set_parallel(true)
	_beam_width_tween.tween_property(
		core_line,
		"width",
		base_core_width * width_mult,
		beam_expand_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_beam_width_tween.tween_property(
		glow_line,
		"scale:x",
		base_glow_width_scale * width_mult,
		beam_expand_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_weapon_shutdown() -> void:
	disconnect_weapon_trait_changed(_on_weapon_trait_changed)
	_stop_beam_width_tween()
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


func _update_beam_visual(endpoint: Vector2) -> void:
	core_line.set_point_position(0, BEAM_LOCAL_START)
	core_line.set_point_position(1, endpoint)
	_update_glow_beam(endpoint)


func _update_glow_beam(endpoint: Vector2) -> void:
	var direction := endpoint - BEAM_LOCAL_START
	var texture_size := glow_line.texture.get_size()
	if texture_size.y <= 0.0:
		return
	glow_line.position = (BEAM_LOCAL_START + endpoint) * 0.5
	glow_line.rotation = direction.angle() - PI * 0.5
	glow_line.scale.y = direction.length() / texture_size.y


func _update_pulse(delta: float) -> void:
	if not has_trait(&"laser_pulse"):
		_pulse_on = true
		return
	var on_duration := float(get_trait_param(&"laser_pulse", &"on_duration", 0.7))
	var off_duration := float(get_trait_param(&"laser_pulse", &"off_duration", 0.35))
	_pulse_elapsed += delta
	var period := on_duration if _pulse_on else off_duration
	if _pulse_elapsed >= period:
		_pulse_elapsed = 0.0
		_pulse_on = not _pulse_on


func _update_beam_visibility() -> void:
	var show_beam := true
	if has_trait(&"laser_pulse"):
		show_beam = _pulse_on
	core_line.visible = show_beam
	glow_line.visible = show_beam


func _trait_damage_mult() -> float:
	var mult := float(get_trait_param(&"laser_wide_lens", &"damage_mult", 1.0))
	if has_trait(&"laser_pulse") and _pulse_on:
		mult *= float(get_trait_param(&"laser_pulse", &"active_damage_mult", 2.0))
	return mult


func _heat_bonus_for(enemy: Node) -> float:
	if not has_trait(&"laser_heat_stack") or enemy == null:
		return 0.0
	var id := enemy.get_instance_id()
	var now := Time.get_ticks_msec() * 0.001
	var stack_interval := float(get_trait_param(&"laser_heat_stack", &"stack_interval", 0.5))
	var stack_bonus := float(get_trait_param(&"laser_heat_stack", &"stack_bonus", 0.15))
	var max_bonus := float(get_trait_param(&"laser_heat_stack", &"max_bonus", 0.9))
	var entry: Dictionary = _heat_stacks.get(id, {"stacks": 0, "last_time": -999.0})
	var last_time := float(entry.get("last_time", -999.0))
	var stacks := int(entry.get("stacks", 0))
	if now - last_time >= stack_interval:
		stacks += 1
		entry["stacks"] = stacks
		entry["last_time"] = now
		_heat_stacks[id] = entry
	else:
		entry["last_time"] = now
		_heat_stacks[id] = entry
	return minf(max_bonus, float(maxi(0, stacks - 1)) * stack_bonus)


func _damage_all_along_beam(endpoint: Vector2) -> void:
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var from_global := to_global(BEAM_LOCAL_START)
	var to_global := to_global(endpoint)
	var exclude: Array[RID] = []
	var primary_hits: Array[Dictionary] = []

	for _i in 32:
		var query := PhysicsRayQueryParameters2D.create(from_global, to_global)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.collision_mask = 2
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var collider: Object = hit.get("collider")
		if collider is CollisionObject2D:
			exclude.append((collider as CollisionObject2D).get_rid())
		var hurtbox := collider as HurtboxComponent
		if hurtbox == null or hurtbox.is_invincible:
			continue
		primary_hits.append(hit)
		_apply_beam_hit(hurtbox, 1.0)

	if has_trait(&"laser_refract") and not primary_hits.is_empty():
		_apply_refract(primary_hits)


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
