class_name HomingMissileWeaponSystem
extends WeaponSystem

@export_range(0.02, 10.0, 0.01) var base_fire_interval := 1.1
@export_range(1, 200, 1) var base_damage := 14
@export_range(1.0, 600.0, 1.0) var projectile_speed := 150.0
@export_range(0.1, 20.0, 0.1) var turn_rate := 5.5
@export_range(0.02, 2.0, 0.01) var retarget_interval := 0.15

## Permanent bay weapon — fires on its own timer with no ammo limit.

@onready var muzzle: Marker2D = $Muzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer

func get_status_stat_line() -> String:
	return "피해 %d · 간격 %s초 · 탄속 %s · 선회 %s" % [
		_status_damage(base_damage),
		_status_num(_status_interval(base_fire_interval)),
		_status_num(projectile_speed, 0),
		_status_num(turn_rate),
	]


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
	if not projectile.has_method("configure_motion"):
		push_error("HomingMissileWeaponSystem: projectile missing configure_motion().")
		return
	projectile.call("configure_motion", projectile_speed, turn_rate, retarget_interval)
	var hitbox := projectile.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox == null:
		push_error("HomingMissileWeaponSystem: projectile missing HitboxComponent.")
		return
	hitbox.damage = maxi(1, roundi(base_damage * get_effective_damage_multiplier()))
