class_name HomingMissileWeaponSystem
extends WeaponSystem

@export_range(0.02, 10.0, 0.01) var base_fire_interval := 1.1
@export_range(1, 200, 1) var base_damage := 14
@export_range(1.0, 600.0, 1.0) var projectile_speed := 150.0
@export_range(0.1, 20.0, 0.1) var turn_rate := 5.5
@export_range(0.02, 2.0, 0.01) var retarget_interval := 0.15
@export_range(4.0, 40.0, 1.0) var multi_rack_spread_px := 10.0

## Permanent bay weapon — fires on its own timer with no ammo limit.

@onready var muzzle: Marker2D = $Muzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer


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
	var count := 1 + int(get_trait_param(&"missile_multi_rack", &"count_bonus", 0))
	for index in count:
		var offset_x := 0.0
		if count > 1:
			offset_x = (float(index) - float(count - 1) * 0.5) * multi_rack_spread_px
		var spawn_pos := muzzle.global_position + Vector2(offset_x, 0.0)
		spawner_component.spawn(
			spawn_pos,
			null,
			_configure_projectile,
		)
	fired.emit()


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	var interval := base_fire_interval / get_effective_fire_rate_multiplier()
	interval *= float(get_trait_param(&"missile_high_mobility", &"fire_interval_mult", 1.0))
	fire_rate_timer.wait_time = maxf(0.02, interval)


func _on_weapon_shutdown() -> void:
	disconnect_weapon_trait_changed(_on_weapon_trait_changed)
	if fire_rate_timer != null:
		fire_rate_timer.stop()
		if fire_rate_timer.timeout.is_connected(fire):
			fire_rate_timer.timeout.disconnect(fire)


func _configure_projectile(projectile: Node) -> void:
	if not projectile.has_method("configure_motion"):
		push_error("HomingMissileWeaponSystem: projectile missing configure_motion().")
		return
	var speed := projectile_speed * float(get_trait_param(&"missile_high_mobility", &"speed_mult", 1.0))
	projectile.call("configure_motion", speed, turn_rate, retarget_interval)

	var damage_mult := float(get_trait_param(&"missile_multi_rack", &"damage_mult", 1.0))
	if has_trait(&"missile_proximity"):
		damage_mult *= float(get_trait_param(&"missile_proximity", &"direct_mult", 0.95))
	var base := maxi(1, roundi(base_damage * damage_mult))

	var aoe_radius := 0.0
	var aoe_mult := 1.0
	if has_trait(&"missile_proximity"):
		aoe_radius = float(get_trait_param(&"missile_proximity", &"aoe_radius", 24))
		aoe_mult = float(get_trait_param(&"missile_proximity", &"aoe_mult", 0.8))

	var min_bonus := 0.0
	var max_bonus := 0.0
	var full_time := 2.5
	if has_trait(&"missile_terminal"):
		min_bonus = float(get_trait_param(&"missile_terminal", &"min_bonus", 0.2))
		max_bonus = float(get_trait_param(&"missile_terminal", &"max_bonus", 1.0))
		full_time = float(get_trait_param(&"missile_terminal", &"full_bonus_flight_time", 2.5))

	if projectile.has_method("configure_missile_combat"):
		projectile.call(
			"configure_missile_combat",
			self,
			base,
			aoe_radius,
			aoe_mult,
			min_bonus,
			max_bonus,
			full_time,
		)
	else:
		var hitbox := projectile.get_node_or_null("HitboxComponent") as HitboxComponent
		if hitbox != null:
			hitbox.damage = resolve_hit_damage(base)
			hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
				return resolve_hit_damage(base, hurtbox)
