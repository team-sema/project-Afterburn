class_name AuxiliaryCannonWeaponSystem
extends WeaponSystem

@onready var muzzle: Marker2D = $Muzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer

var base_fire_wait_time: float


func _ready() -> void:
	base_fire_wait_time = fire_rate_timer.wait_time
	fire_rate_timer.timeout.connect(fire)
	_apply_stat_multipliers()


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
	fire_rate_timer.wait_time = base_fire_wait_time / get_effective_fire_rate_multiplier()


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
	hitbox.damage = maxi(1, roundi(hitbox.damage * get_effective_damage_multiplier()))
