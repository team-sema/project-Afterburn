class_name ShotgunWeaponSystem
extends WeaponSystem

@export var pellet_count := 5
@export_range(5.0, 90.0, 1.0) var spread_degrees := 36.0
@export var pellet_speed := 220.0

@onready var muzzle: Marker2D = $Muzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer
@onready var sound_player: VariablePitchAudioStreamPlayer = $ShotgunSoundPlayer

var base_fire_wait_time: float


func _ready() -> void:
	base_fire_wait_time = fire_rate_timer.wait_time
	fire_rate_timer.timeout.connect(fire)
	_apply_stat_multipliers()


func fire() -> void:
	if is_shutdown:
		return
	sound_player.play_with_variance()
	var count := maxi(1, pellet_count)
	for index in count:
		var direction := _pellet_direction(index, count)
		spawner_component.spawn(
			muzzle.global_position,
			null,
			func(projectile: Node) -> void: _configure_projectile(projectile, direction),
		)
	fired.emit()


func _pellet_direction(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.UP
	var t := (float(index) / float(count - 1)) * 2.0 - 1.0
	var angle := deg_to_rad(spread_degrees * 0.5 * t)
	return Vector2(sin(angle), -cos(angle)).normalized()


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	fire_rate_timer.wait_time = base_fire_wait_time / get_effective_fire_rate_multiplier()


func _on_weapon_shutdown() -> void:
	if fire_rate_timer != null:
		fire_rate_timer.stop()
		if fire_rate_timer.timeout.is_connected(fire):
			fire_rate_timer.timeout.disconnect(fire)


func _configure_projectile(projectile: Node, direction: Vector2) -> void:
	var hitbox := projectile.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox == null:
		push_error("ShotgunWeaponSystem: projectile missing HitboxComponent.")
		return
	hitbox.damage = maxi(1, roundi(hitbox.damage * get_effective_damage_multiplier()))
	var move := projectile.get_node_or_null("MoveComponent") as MoveComponent
	if move == null:
		push_error("ShotgunWeaponSystem: projectile missing MoveComponent.")
		return
	move.velocity = direction * pellet_speed
	projectile.rotation = direction.angle() + PI * 0.5
