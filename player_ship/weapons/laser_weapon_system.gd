class_name LaserWeaponSystem
extends WeaponSystem

## Piercing beam that always reaches the top of the playfield and damages every
## enemy hurtbox along its path each tick.

const BEAM_LOCAL_START := Vector2(0, -6)
const PLAYFIELD_TOP_MARGIN := 8.0

@onready var glow_line: Sprite2D = $GlowLine
@onready var core_line: Line2D = $CoreLine
@onready var damage_tick_timer: Timer = $DamageTickTimer
@onready var damage_hitbox: HitboxComponent = $DamageHitbox

var base_tick_interval: float
var base_tick_damage: int


func _ready() -> void:
	base_tick_interval = damage_tick_timer.wait_time
	base_tick_damage = damage_hitbox.damage
	damage_tick_timer.timeout.connect(apply_damage_tick)
	_apply_stat_multipliers()
	_update_beam_visual(_full_beam_endpoint())


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


func _on_weapon_shutdown() -> void:
	set_physics_process(false)
	visible = false
	if damage_tick_timer != null:
		damage_tick_timer.stop()
		if damage_tick_timer.timeout.is_connected(apply_damage_tick):
			damage_tick_timer.timeout.disconnect(apply_damage_tick)


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
