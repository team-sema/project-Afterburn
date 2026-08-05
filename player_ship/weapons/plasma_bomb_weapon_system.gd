class_name PlasmaBombWeaponSystem
extends WeaponSystem

@export_range(0.02, 10.0, 0.01) var base_fire_interval := 2.2
@export_range(1, 200, 1) var base_damage := 24
@export_range(1.0, 200.0, 1.0) var projectile_speed := 38.0
@export_range(0.05, 10.0, 0.05) var fuse_time := 1.25
@export_range(4.0, 120.0, 1.0) var blast_radius := 34.0
@export_range(0.0, 64.0, 1.0) var damage_radius_margin := 0.0

@onready var muzzle: Marker2D = $Muzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer

func get_status_stat_line() -> String:
	return "피해 %d · 간격 %s초 · 신관 %s초 · 반경 %s" % [
		_status_damage(base_damage),
		_status_num(_status_interval(base_fire_interval)),
		_status_num(fuse_time),
		_status_num(blast_radius, 0),
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
	if not projectile.has_method("configure_bomb"):
		push_error("PlasmaBombWeaponSystem: projectile missing configure_bomb().")
		return
	projectile.call(
		"configure_bomb",
		projectile_speed,
		fuse_time,
		blast_radius,
		damage_radius_margin,
		maxi(1, roundi(base_damage * get_effective_damage_multiplier())),
	)
