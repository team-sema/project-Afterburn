class_name PlasmaBombWeaponSystem
extends WeaponSystem

@export_range(0.02, 10.0, 0.01) var base_fire_interval := 2.2
@export_range(1, 200, 1) var base_damage := 24
@export_range(1.0, 200.0, 1.0) var projectile_speed := 38.0
@export_range(0.05, 10.0, 0.05) var fuse_time := 1.25
@export_range(4.0, 120.0, 1.0) var blast_radius := 34.0
@export_range(0.0, 64.0, 1.0) var damage_radius_margin := 0.0
@export_range(10.0, 300.0, 1.0) var pull_strength := 90.0

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
	disconnect_weapon_trait_changed(_on_weapon_trait_changed)
	if fire_rate_timer != null:
		fire_rate_timer.stop()
		if fire_rate_timer.timeout.is_connected(fire):
			fire_rate_timer.timeout.disconnect(fire)


func _configure_projectile(projectile: Node) -> void:
	if not projectile.has_method("configure_bomb"):
		push_error("PlasmaBombWeaponSystem: projectile missing configure_bomb().")
		return

	var radius_mult := 1.0
	radius_mult *= float(get_trait_param(&"plasma_expand", &"radius_mult", 1.0))
	radius_mult *= float(get_trait_param(&"plasma_gravity", &"radius_mult", 1.0))
	var damage_mult := 1.0
	damage_mult *= float(get_trait_param(&"plasma_expand", &"damage_mult", 1.0))
	damage_mult *= float(get_trait_param(&"plasma_cluster", &"damage_mult", 1.0))
	damage_mult *= float(get_trait_param(&"plasma_field", &"damage_mult", 1.0))
	damage_mult *= float(get_trait_param(&"plasma_gravity", &"damage_mult", 1.0))

	var radius := blast_radius * radius_mult
	var damage := maxi(1, roundi(base_damage * damage_mult))
	projectile.call(
		"configure_bomb",
		projectile_speed,
		fuse_time,
		radius,
		damage_radius_margin,
		damage,
	)

	if projectile.has_method("configure_plasma_traits"):
		var cluster_count := int(get_trait_param(&"plasma_cluster", &"cluster_count", 0))
		var cluster_damage_mult := float(get_trait_param(&"plasma_cluster", &"cluster_damage_mult", 0.4))
		var field_duration := 0.0
		var field_max_bonus := 0.0
		if has_trait(&"plasma_field"):
			field_duration = float(get_trait_param(&"plasma_field", &"field_duration", 3.0))
			field_max_bonus = float(get_trait_param(&"plasma_field", &"field_max_bonus_mult", 1.0))
		var gravity_pull := 0.0
		if has_trait(&"plasma_gravity"):
			gravity_pull = float(get_trait_param(&"plasma_gravity", &"pull_strength", pull_strength))
		projectile.call(
			"configure_plasma_traits",
			self,
			cluster_count,
			cluster_damage_mult,
			field_duration,
			field_max_bonus,
			gravity_pull,
		)
