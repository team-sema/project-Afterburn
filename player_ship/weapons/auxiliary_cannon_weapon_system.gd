class_name AuxiliaryCannonWeaponSystem
extends WeaponSystem

@export_range(0.02, 10.0, 0.01) var base_fire_interval := 0.8
@export_range(1, 200, 1) var base_damage := 9
@export_range(1.0, 600.0, 1.0) var projectile_speed := 190.0

## Permanent bay weapon — fires on its own timer with no ammo limit.

@onready var muzzle: Marker2D = $Muzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer


func _ready() -> void:
	fire_rate_timer.timeout.connect(fire)
	_apply_stat_multipliers()
	fire_rate_timer.start()


func fire() -> void:
	if is_shutdown:
		return
	spawner_component.spawn(
		muzzle.global_position,
		null,
		_configure_projectile,
	)
	fired.emit()


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	fire_rate_timer.wait_time = base_fire_interval / get_effective_fire_rate_multiplier()


func _on_weapon_shutdown() -> void:
	if fire_rate_timer != null:
		fire_rate_timer.stop()
		if fire_rate_timer.timeout.is_connected(fire):
			fire_rate_timer.timeout.disconnect(fire)


func _configure_projectile(projectile: Node) -> void:
	var hitbox := projectile.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox == null:
		push_error("AuxiliaryCannonWeaponSystem: projectile missing HitboxComponent.")
		return
	hitbox.damage = maxi(1, roundi(base_damage * get_effective_damage_multiplier()))
	var move := projectile.get_node_or_null("MoveComponent") as MoveComponent
	if move == null:
		push_error("AuxiliaryCannonWeaponSystem: projectile missing MoveComponent.")
		return
	move.velocity = Vector2.UP * projectile_speed
