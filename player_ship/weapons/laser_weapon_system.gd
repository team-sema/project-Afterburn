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


func get_status_stat_line() -> String:
	return "틱피해 %d · 틱 %s초" % [
		_status_damage(base_tick_damage),
		_status_num(_status_interval(base_tick_interval)),
	]


func _ready() -> void:
	base_core_width = core_line.width
	base_glow_width_scale = glow_line.scale.x
	damage_hitbox.damage = base_tick_damage
	damage_tick_timer.timeout.connect(apply_damage_tick)
	_apply_stat_multipliers()
	damage_tick_timer.start()
	_update_beam_visual(_full_beam_endpoint())
	restart_beam_width_animation()


func _physics_process(_delta: float) -> void:
	if is_shutdown:
		return
	_update_beam_visual(_full_beam_endpoint())


func apply_damage_tick() -> void:
	if is_shutdown:
		return
	var endpoint := _full_beam_endpoint()
	_update_beam_visual(endpoint)
	_damage_all_along_beam(endpoint)


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	damage_tick_timer.wait_time = base_tick_interval / get_effective_fire_rate_multiplier()


func set_beam_width_multiplier(multiplier: float) -> void:
	beam_width_multiplier = maxf(0.1, multiplier)
	if not is_node_ready():
		return
	_stop_beam_width_tween()
	_apply_target_beam_width()


func restart_beam_width_animation() -> void:
	if not is_node_ready():
		return
	_stop_beam_width_tween()
	core_line.width = 0.0
	glow_line.scale.x = 0.0
	if beam_expand_duration <= 0.0:
		_apply_target_beam_width()
		return

	_beam_width_tween = create_tween().set_parallel(true)
	_beam_width_tween.tween_property(
		core_line,
		"width",
		base_core_width * beam_width_multiplier,
		beam_expand_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_beam_width_tween.tween_property(
		glow_line,
		"scale:x",
		base_glow_width_scale * beam_width_multiplier,
		beam_expand_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_weapon_shutdown() -> void:
	_stop_beam_width_tween()
	set_physics_process(false)
	visible = false
	if damage_tick_timer != null:
		damage_tick_timer.stop()
		if damage_tick_timer.timeout.is_connected(apply_damage_tick):
			damage_tick_timer.timeout.disconnect(apply_damage_tick)


func _apply_target_beam_width() -> void:
	core_line.width = base_core_width * beam_width_multiplier
	glow_line.scale.x = base_glow_width_scale * beam_width_multiplier


func _stop_beam_width_tween() -> void:
	if _beam_width_tween != null:
		_beam_width_tween.kill()
		_beam_width_tween = null


func _full_beam_endpoint() -> Vector2:
	# Extend upward in local space until we reach the playfield top edge.
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


func _damage_all_along_beam(endpoint: Vector2) -> void:
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var from_global := to_global(BEAM_LOCAL_START)
	var to_global := to_global(endpoint)
	var exclude: Array[RID] = []
	damage_hitbox.damage = maxi(1, roundi(base_tick_damage * get_effective_damage_multiplier()))

	# Walk the ray, damaging every hurtbox without stopping the beam visually.
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
		hurtbox.hurt.emit(damage_hitbox)
