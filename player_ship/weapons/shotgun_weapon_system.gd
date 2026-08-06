class_name ShotgunWeaponSystem
extends WeaponSystem

@export_range(0.02, 10.0, 0.01) var base_fire_interval := 0.42
@export_range(1, 200, 1) var base_damage := 4
@export_range(1, 32, 1) var pellet_count := 5
@export_range(5.0, 90.0, 1.0) var spread_degrees := 36.0
@export_range(1.0, 600.0, 1.0) var pellet_speed := 220.0
@export_range(0.05, 10.0, 0.01) var base_pellet_lifetime := 1.27
@export_range(20.0, 200.0, 1.0) var close_range_px := 80.0

@onready var muzzle: Marker2D = $Muzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer
@onready var sound_player: VariablePitchAudioStreamPlayer = $ShotgunSoundPlayer

var _real_shot_count := 0
var _burst_damage_mult := 1.0


func _ready() -> void:
	fire_rate_timer.timeout.connect(fire)
	_apply_stat_multipliers()
	fire_rate_timer.start()


func _on_weapon_setup() -> void:
	connect_weapon_trait_changed(_on_weapon_trait_changed)
	_real_shot_count = 0
	_burst_damage_mult = 1.0
	_apply_stat_multipliers()


func _on_weapon_trait_changed(changed_weapon_id: StringName, _trait_id: StringName, _new_rank: int) -> void:
	if changed_weapon_id != get_weapon_id():
		return
	_apply_stat_multipliers()


func fire() -> void:
	_fire_internal(true)


func _fire_burst_extra() -> void:
	if is_shutdown:
		return
	_burst_damage_mult = float(get_trait_param(&"shotgun_burst_device", &"extra_damage_mult", 0.9))
	_fire_internal(false)
	_burst_damage_mult = 1.0


func _fire_internal(count_as_real: bool) -> void:
	if is_shutdown:
		return
	sound_player.play_with_variance()
	var count := maxi(1, pellet_count + int(get_trait_param(&"shotgun_expanded_shell", &"pellet_bonus", 0)))
	for index in count:
		var direction := _pellet_direction(index, count)
		spawner_component.spawn(
			muzzle.global_position,
			null,
			func(projectile: Node) -> void: _configure_projectile(projectile, direction),
		)
	fired.emit()
	if count_as_real and has_trait(&"shotgun_burst_device"):
		_real_shot_count += 1
		var every_nth := maxi(1, int(get_trait_param(&"shotgun_burst_device", &"every_nth", 3)))
		if _real_shot_count % every_nth == 0:
			var delay := float(get_trait_param(&"shotgun_burst_device", &"delay", 0.12))
			get_tree().create_timer(delay).timeout.connect(_fire_burst_extra, CONNECT_ONE_SHOT)


func _pellet_direction(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.UP
	var spread := spread_degrees
	spread *= float(get_trait_param(&"shotgun_choke", &"spread_mult", 1.0))
	spread *= float(get_trait_param(&"shotgun_cut_barrel", &"spread_mult", 1.0))
	var t := (float(index) / float(count - 1)) * 2.0 - 1.0
	var angle := deg_to_rad(spread * 0.5 * t)
	return Vector2(sin(angle), -cos(angle)).normalized()


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


func _configure_projectile(projectile: Node, direction: Vector2) -> void:
	var hitbox := projectile.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox == null:
		push_error("ShotgunWeaponSystem: projectile missing HitboxComponent.")
		return
	var move := projectile.get_node_or_null("MoveComponent") as MoveComponent
	if move == null:
		push_error("ShotgunWeaponSystem: projectile missing MoveComponent.")
		return

	var speed := pellet_speed
	speed *= float(get_trait_param(&"shotgun_choke", &"speed_mult", 1.0))
	var lifetime_mult := 1.0
	lifetime_mult *= float(get_trait_param(&"shotgun_choke", &"lifetime_mult", 1.0))
	lifetime_mult *= float(get_trait_param(&"shotgun_cut_barrel", &"lifetime_mult", 1.0))
	var max_lifetime := base_pellet_lifetime * lifetime_mult
	move.velocity = direction * speed
	projectile.rotation = direction.angle() + PI * 0.5

	var damage_mult := float(get_trait_param(&"shotgun_expanded_shell", &"damage_mult", 1.0))
	damage_mult *= _burst_damage_mult
	var base := maxi(1, roundi(base_damage * damage_mult))
	var close_mult := float(get_trait_param(&"shotgun_cut_barrel", &"close_damage_mult", 1.0))
	var close_px := float(get_trait_param(&"shotgun_cut_barrel", &"close_range_px", close_range_px))
	if not has_trait(&"shotgun_cut_barrel"):
		close_mult = 1.0
	var origin := muzzle.global_position

	if projectile.has_method("configure_shotgun_combat"):
		projectile.call(
			"configure_shotgun_combat",
			self,
			base,
			origin,
			max_lifetime,
			close_mult,
			close_px,
		)
	else:
		hitbox.damage = resolve_hit_damage(base)
		hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
			return resolve_hit_damage(base, hurtbox)
