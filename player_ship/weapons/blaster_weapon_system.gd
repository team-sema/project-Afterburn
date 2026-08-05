class_name BlasterWeaponSystem
extends WeaponSystem

@export_range(0.02, 10.0, 0.01) var base_fire_interval := 0.15
@export_range(1, 200, 1) var base_damage := 10
@export_range(1.0, 600.0, 1.0) var projectile_speed := 200.0
@export_range(40.0, 200.0, 1.0) var ricochet_search_radius := 96.0

@onready var left_muzzle: Marker2D = $LeftMuzzle
@onready var right_muzzle: Marker2D = $RightMuzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer
@onready var blaster_sound_player: VariablePitchAudioStreamPlayer = $BlasterSoundPlayer

var is_left_firing := false


func _ready() -> void:
	fire_rate_timer.timeout.connect(fire)
	_apply_stat_multipliers()
	fire_rate_timer.start()


func _on_weapon_setup() -> void:
	connect_weapon_trait_changed(_on_weapon_trait_changed)
	_apply_stat_multipliers()


func _on_weapon_trait_changed(changed_weapon_id: StringName, _trait_id: StringName, _new_rank: int) -> void:
	if changed_weapon_id != get_weapon_id():
		return
	_apply_stat_multipliers()


func fire() -> void:
	if is_shutdown:
		return
	blaster_sound_player.play_with_variance()

	if has_trait(&"blaster_sync_trigger"):
		_spawn_from_muzzle(left_muzzle)
		_spawn_from_muzzle(right_muzzle)
	else:
		var muzzle := right_muzzle
		if is_left_firing:
			muzzle = left_muzzle
		is_left_firing = not is_left_firing
		_spawn_from_muzzle(muzzle)
	fired.emit()


func _spawn_from_muzzle(muzzle: Marker2D) -> void:
	spawner_component.spawn(
		muzzle.global_position,
		null,
		_configure_projectile,
	)


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	var interval := base_fire_interval / get_effective_fire_rate_multiplier()
	interval *= float(get_trait_param(&"blaster_rapid_loader", &"fire_interval_mult", 1.0))
	interval *= float(get_trait_param(&"blaster_sync_trigger", &"fire_interval_mult", 1.0))
	fire_rate_timer.wait_time = maxf(0.02, interval)


func _on_weapon_shutdown() -> void:
	disconnect_weapon_trait_changed(_on_weapon_trait_changed)
	if fire_rate_timer != null:
		fire_rate_timer.stop()
		if fire_rate_timer.timeout.is_connected(fire):
			fire_rate_timer.timeout.disconnect(fire)


func _trait_damage_mult() -> float:
	var mult := 1.0
	mult *= float(get_trait_param(&"blaster_rapid_loader", &"damage_mult", 1.0))
	mult *= float(get_trait_param(&"blaster_sync_trigger", &"damage_mult", 1.0))
	return mult


func _configure_projectile(projectile: Node) -> void:
	var hitbox := projectile.get_node_or_null("HitboxComponent") as HitboxComponent
	assert(hitbox != null, "Blaster projectile requires a HitboxComponent.")
	var move := projectile.get_node_or_null("MoveComponent") as MoveComponent
	assert(move != null, "Blaster projectile requires a MoveComponent.")

	var speed := projectile_speed * float(get_trait_param(&"blaster_accel_ap", &"speed_mult", 1.0))
	move.velocity = Vector2.UP * speed

	var base := maxi(1, roundi(base_damage * _trait_damage_mult()))
	var pierce_bonus := int(get_trait_param(&"blaster_accel_ap", &"pierce_bonus", 0))
	var pierce_falloff := float(get_trait_param(&"blaster_accel_ap", &"pierce_damage_falloff", 1.0))
	var max_bounces := int(get_trait_param(&"blaster_ricochet", &"max_bounces", 0))
	var bounce_mults: Array[float] = []
	if max_bounces > 0:
		bounce_mults.append(float(get_trait_param(&"blaster_ricochet", &"bounce1_damage_mult", 0.7)))
		if max_bounces > 1:
			bounce_mults.append(float(get_trait_param(&"blaster_ricochet", &"bounce2_damage_mult", 0.4)))

	if projectile.has_method("configure_blaster_combat"):
		projectile.call(
			"configure_blaster_combat",
			self,
			base,
			pierce_bonus,
			pierce_falloff,
			max_bounces,
			bounce_mults,
			ricochet_search_radius,
		)
	else:
		hitbox.damage = resolve_hit_damage(base)
		hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
			return resolve_hit_damage(base, hurtbox)
