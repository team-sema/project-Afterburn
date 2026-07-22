class_name BlasterWeaponSystem
extends WeaponSystem

@onready var left_muzzle: Marker2D = $LeftMuzzle
@onready var right_muzzle: Marker2D = $RightMuzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer
@onready var blaster_sound_player: VariablePitchAudioStreamPlayer = $BlasterSoundPlayer

var is_left_firing := false
var base_fire_wait_time: float


func _ready() -> void:
	base_fire_wait_time = fire_rate_timer.wait_time
	fire_rate_timer.timeout.connect(fire)
	_apply_stat_multipliers()


func fire() -> void:
	blaster_sound_player.play_with_variance()

	var muzzle := right_muzzle
	if is_left_firing:
		muzzle = left_muzzle
	is_left_firing = not is_left_firing

	spawner_component.spawn(
		muzzle.global_position,
		get_tree().current_scene,
		_configure_projectile,
	)
	fired.emit()


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	fire_rate_timer.wait_time = base_fire_wait_time / get_effective_fire_rate_multiplier()


func _configure_projectile(projectile: Node) -> void:
	var hitbox := projectile.get_node_or_null("HitboxComponent") as HitboxComponent
	assert(hitbox != null, "Blaster projectile requires a HitboxComponent.")
	hitbox.damage = maxi(1, roundi(hitbox.damage * get_effective_damage_multiplier()))
