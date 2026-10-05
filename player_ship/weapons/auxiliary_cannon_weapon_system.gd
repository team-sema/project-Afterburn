class_name AuxiliaryCannonWeaponSystem
extends WeaponSystem

@export_range(0.02, 10.0, 0.01) var base_fire_interval := 0.8
@export_range(1, 200, 1) var base_damage := 9
@export_range(1.0, 600.0, 1.0) var projectile_speed := 190.0
@export_range(2, 8, 2) var base_drone_count := 2
@export_range(8.0, 48.0, 1.0) var drone_side_offset := 18.0
@export_range(4.0, 24.0, 1.0) var drone_pair_spacing := 11.0
@export_range(-16.0, 16.0, 1.0) var drone_pair_vertical_spacing := 5.0
@export_range(20.0, 400.0, 1.0) var drone_follow_speed := 100.0
@export_range(0.0, 100.0, 1.0) var drone_distance_speed_gain_percent := 15.0
@export_range(0.0, 200.0, 1.0) var drone_max_distance_speed_bonus := 50.0

## Permanent bay weapon — fixed support drones fire straight ahead.

@onready var support_drone_template: Node2D = $SupportDroneTemplate
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer

var _support_drones: Array[Node2D] = []
## Autonomous prism: per-drone chased enemy (parallel to _support_drones).
var _drone_targets: Array[Node2D] = []
var _orbit_phase := 0.0


func _ready() -> void:
	support_drone_template.visible = false
	_ensure_support_drones()
	fire_rate_timer.timeout.connect(fire)
	_apply_stat_multipliers()
	fire_rate_timer.start()


func _on_weapon_setup() -> void:
	connect_weapon_trait_changed(_on_weapon_trait_changed)
	_ensure_support_drones()
	_apply_stat_multipliers()


func _on_weapon_trait_changed(changed_weapon_id: StringName, _trait_id: StringName, _new_rank: int) -> void:
	if changed_weapon_id != get_weapon_id():
		return
	_ensure_support_drones()
	_apply_stat_multipliers()


func _process(delta: float) -> void:
	if is_shutdown:
		return
	var autonomous := is_autonomous()
	if autonomous:
		_orbit_phase = wrapf(
			_orbit_phase + float(get_trait_param(&"aux_autonomous_prism", &"orbit_speed", 1.4)) * delta,
			0.0,
			TAU,
		)
		_assign_drone_targets()
	for index in _support_drones.size():
		var drone := _support_drones[index]
		var enemy := _get_chased_enemy(index) if autonomous else null
		var target := _get_drone_target(index)
		var follow_speed := 0.0
		if enemy != null:
			target = _get_orbit_position(index, enemy)
			follow_speed = float(get_trait_param(&"aux_autonomous_prism", &"drone_speed", 160.0))
		else:
			var player_distance := drone.global_position.distance_to(global_position)
			var distance_speed_bonus := minf(
				player_distance * drone_distance_speed_gain_percent / 100.0,
				drone_max_distance_speed_bonus,
			)
			follow_speed = drone_follow_speed + distance_speed_bonus
		drone.global_position = drone.global_position.move_toward(
			target,
			follow_speed * delta,
		)
		drone.rotation = _get_aim_direction(index).angle() + PI * 0.5


func fire() -> void:
	if is_shutdown:
		return
	_ensure_support_drones()
	for index in _support_drones.size():
		var drone := _support_drones[index]
		var muzzle := drone.get_node_or_null("Muzzle") as Marker2D
		if muzzle == null:
			push_error("AuxiliaryCannonWeaponSystem: support drone missing Muzzle.")
			continue
		var direction := _get_aim_direction(index)
		spawner_component.spawn(
			muzzle.global_position,
			null,
			func(projectile: Node) -> void: _configure_projectile(projectile, direction),
		)
	fired.emit()


func is_autonomous() -> bool:
	return has_trait(&"aux_autonomous_prism")


func get_drone_chased_enemy(index: int) -> Node2D:
	return _get_chased_enemy(index)


func _get_chased_enemy(index: int) -> Node2D:
	if index < 0 or index >= _drone_targets.size():
		return null
	var enemy := _drone_targets[index]
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return null
	return enemy


func _get_aim_direction(index: int) -> Vector2:
	var enemy := _get_chased_enemy(index) if is_autonomous() else null
	if enemy == null or index >= _support_drones.size():
		return Vector2.UP
	var direction := _support_drones[index].global_position.direction_to(enemy.global_position)
	return direction if direction.length_squared() > 0.0001 else Vector2.UP


## Drones keep their enemy while it lives on screen; a free drone takes the
## on-screen enemy chased by the fewest drones, nearest to the drone first.
func _assign_drone_targets() -> void:
	_drone_targets.resize(_support_drones.size())
	var bounds := get_viewport_rect()
	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if bounds.has_point(enemy.global_position):
			candidates.append(enemy)
	var chase_counts: Dictionary = {}
	for index in _drone_targets.size():
		var kept := _get_chased_enemy(index)
		if kept != null and not candidates.has(kept):
			kept = null
		_drone_targets[index] = kept
		if kept != null:
			chase_counts[kept] = int(chase_counts.get(kept, 0)) + 1
	for index in _drone_targets.size():
		if _drone_targets[index] != null:
			continue
		var drone_position := _support_drones[index].global_position
		var best: Node2D = null
		var best_count := 0
		var best_distance := INF
		for enemy in candidates:
			var count := int(chase_counts.get(enemy, 0))
			var distance := drone_position.distance_squared_to(enemy.global_position)
			if best == null or count < best_count or (count == best_count and distance < best_distance):
				best = enemy
				best_count = count
				best_distance = distance
		_drone_targets[index] = best
		if best != null:
			chase_counts[best] = best_count + 1


## Drones on the same enemy spread evenly around it, clamped inside the playfield.
func _get_orbit_position(index: int, enemy: Node2D) -> Vector2:
	var sharing: Array[int] = []
	for other in _drone_targets.size():
		if _get_chased_enemy(other) == enemy:
			sharing.append(other)
	var slot := maxi(0, sharing.find(index))
	var angle := _orbit_phase + TAU * float(slot) / float(maxi(1, sharing.size()))
	var radius := float(get_trait_param(&"aux_autonomous_prism", &"orbit_radius", 44.0))
	var point := enemy.global_position + Vector2.from_angle(angle) * radius
	var bounds := get_viewport_rect().grow(-6.0)
	return point.clamp(bounds.position, bounds.end)


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	var interval := base_fire_interval / get_effective_fire_rate_multiplier()
	interval *= float(get_trait_param(&"aux_auto_loader", &"fire_interval_mult", 1.0))
	fire_rate_timer.wait_time = maxf(0.02, interval)


func _on_weapon_shutdown() -> void:
	disconnect_weapon_trait_changed(_on_weapon_trait_changed)
	if fire_rate_timer != null:
		fire_rate_timer.stop()
		if fire_rate_timer.timeout.is_connected(fire):
			fire_rate_timer.timeout.disconnect(fire)


func get_support_drone_count() -> int:
	return _support_drones.size()


func get_support_drone_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for drone in _support_drones:
		positions.append(drone.global_position)
	return positions


func _ensure_support_drones() -> void:
	if support_drone_template == null:
		return
	var desired := _get_desired_drone_count()
	while _support_drones.size() < desired:
		var drone := support_drone_template.duplicate() as Node2D
		drone.name = "SupportDrone%d" % (_support_drones.size() + 1)
		drone.visible = true
		add_child(drone)
		drone.top_level = true
		_support_drones.append(drone)
		drone.global_position = _get_drone_target(_support_drones.size() - 1)
	while _support_drones.size() > desired:
		var extra := _support_drones.pop_back() as Node2D
		if is_instance_valid(extra):
			extra.queue_free()


func _get_desired_drone_count() -> int:
	var desired := maxi(2, base_drone_count)
	desired += int(get_trait_param(&"aux_heavy_barrel", &"drone_count_bonus", 0))
	if desired % 2 != 0:
		desired += 1
	return desired


func _get_drone_target(index: int) -> Vector2:
	return to_global(_get_drone_offset(index))


func _get_drone_offset(index: int) -> Vector2:
	var pair_index := floori(float(index) / 2.0)
	var side := -1.0 if index % 2 == 0 else 1.0
	return Vector2(
		side * (drone_side_offset + drone_pair_spacing * pair_index),
		drone_pair_vertical_spacing * pair_index,
	)


func _configure_projectile(projectile: Node, direction: Vector2 = Vector2.UP) -> void:
	var hitbox := projectile.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox == null:
		push_error("AuxiliaryCannonWeaponSystem: projectile missing HitboxComponent.")
		return
	var move := projectile.get_node_or_null("MoveComponent") as MoveComponent
	if move == null:
		push_error("AuxiliaryCannonWeaponSystem: projectile missing MoveComponent.")
		return

	var shot_direction := direction.normalized()
	if shot_direction.length_squared() < 0.0001:
		shot_direction = Vector2.UP
	var speed := projectile_speed * float(get_trait_param(&"aux_hv_ap", &"speed_mult", 1.0))
	move.velocity = shot_direction * speed
	projectile.rotation = shot_direction.angle() + PI * 0.5

	var damage_mult := 1.0
	damage_mult *= float(get_trait_param(&"aux_heavy_barrel", &"damage_mult", 1.0))
	damage_mult *= float(get_trait_param(&"aux_auto_loader", &"damage_mult", 1.0))
	damage_mult *= float(get_trait_param(&"aux_hv_ap", &"damage_mult", 1.0))
	damage_mult *= float(get_trait_param(&"aux_autonomous_prism", &"damage_mult", 1.0))
	if has_trait(&"aux_he_shell"):
		damage_mult *= float(get_trait_param(&"aux_he_shell", &"direct_damage_mult", 0.95))

	var base := maxi(1, roundi(base_damage * damage_mult))
	var pierce_bonus := int(get_trait_param(&"aux_hv_ap", &"pierce_bonus", 0))
	var pierce_falloff := float(get_trait_param(&"aux_hv_ap", &"pierce_falloff", 1.0))
	var aoe_radius := 0.0
	var aoe_mult := 1.0
	if has_trait(&"aux_he_shell"):
		aoe_radius = float(get_trait_param(&"aux_he_shell", &"aoe_radius", 28))
		aoe_mult = float(get_trait_param(&"aux_he_shell", &"aoe_damage_mult", 0.8))

	if projectile.has_method("configure_aux_combat"):
		projectile.call(
			"configure_aux_combat",
			self,
			base,
			pierce_bonus,
			pierce_falloff,
			1.0,
			aoe_radius,
			aoe_mult,
		)
	else:
		hitbox.damage = resolve_hit_damage(base)
		hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
			return resolve_hit_damage(base, hurtbox)
