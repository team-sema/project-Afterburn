class_name LaserWeaponSystem
extends WeaponSystem

@onready var ray_cast: RayCast2D = $RayCast2D
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
	_update_beam_endpoint()


func _physics_process(_delta: float) -> void:
	if is_shutdown:
		return
	_update_beam_endpoint()


func apply_damage_tick() -> void:
	if is_shutdown:
		return
	_update_beam_endpoint()
	if not ray_cast.is_colliding():
		return

	var hurtbox := ray_cast.get_collider() as HurtboxComponent
	if hurtbox == null or hurtbox.is_invincible:
		return

	damage_hitbox.damage = maxi(1, roundi(base_tick_damage * get_effective_damage_multiplier()))
	hurtbox.hurt.emit(damage_hitbox)


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


func _update_beam_endpoint() -> void:
	ray_cast.force_raycast_update()
	var endpoint := ray_cast.target_position
	if ray_cast.is_colliding():
		endpoint = to_local(ray_cast.get_collision_point())
	_update_glow_beam(endpoint)
	core_line.set_point_position(1, endpoint)


func _update_glow_beam(endpoint: Vector2) -> void:
	var start := core_line.get_point_position(0)
	var direction := endpoint - start
	var texture_size := glow_line.texture.get_size()
	glow_line.position = (start + endpoint) * 0.5
	glow_line.rotation = direction.angle() - PI * 0.5
	glow_line.scale.y = direction.length() / texture_size.y
