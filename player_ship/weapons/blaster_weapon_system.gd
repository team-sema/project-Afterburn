class_name BlasterWeaponSystem
extends WeaponSystem

@export_range(0.02, 10.0, 0.01) var base_fire_interval := 0.15
@export_range(1, 200, 1) var base_damage := 10
@export_range(1.0, 600.0, 1.0) var projectile_speed := 200.0

@onready var left_muzzle: Marker2D = $LeftMuzzle
@onready var right_muzzle: Marker2D = $RightMuzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer
@onready var blaster_sound_player: VariablePitchAudioStreamPlayer = $BlasterSoundPlayer

var is_left_firing := false


func get_status_stat_line() -> String:
	return "피해 %d · 간격 %s초 · 탄속 %s" % [
		_status_damage(base_damage),
		_status_num(_status_interval(base_fire_interval)),
		_status_num(projectile_speed, 0),
	]


func _ready() -> void:
	fire_rate_timer.timeout.connect(fire)
	_apply_stat_multipliers()
	fire_rate_timer.start()


func fire() -> void:
	if is_shutdown:
		return
	blaster_sound_player.play_with_variance()

	var muzzle := right_muzzle
	if is_left_firing:
		muzzle = left_muzzle
	is_left_firing = not is_left_firing

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
	assert(hitbox != null, "Blaster projectile requires a HitboxComponent.")
	hitbox.damage = maxi(1, roundi(base_damage * get_effective_damage_multiplier()))
	var move := projectile.get_node_or_null("MoveComponent") as MoveComponent
	assert(move != null, "Blaster projectile requires a MoveComponent.")
	move.velocity = Vector2.UP * projectile_speed
