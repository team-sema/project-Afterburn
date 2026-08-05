class_name AuxiliaryCannonWeaponSystem
extends WeaponSystem

@export_range(0.02, 10.0, 0.01) var base_fire_interval := 0.8
@export_range(1, 200, 1) var base_damage := 9
@export_range(1.0, 600.0, 1.0) var projectile_speed := 190.0
@export_range(8.0, 80.0, 1.0) var orbit_radius := 28.0
@export_range(0.2, 8.0, 0.05) var orbit_speed := 2.2
@export_range(1, 4, 1) var pod_count := 1

## Permanent bay weapon — fires from orbiting pods toward the nearest enemy.

@onready var muzzle: Marker2D = $Muzzle
@onready var spawner_component: SpawnerComponent = $SpawnerComponent
@onready var fire_rate_timer: Timer = $FireRateTimer

var _pods: Array[Marker2D] = []
var _orbit_angle := 0.0


func _ready() -> void:
	_ensure_pods()
	fire_rate_timer.timeout.connect(fire)
	_apply_stat_multipliers()
	fire_rate_timer.start()


func _on_weapon_setup() -> void:
	connect_weapon_trait_changed(_on_weapon_trait_changed)
	_ensure_pods()
	_apply_stat_multipliers()


func _on_weapon_trait_changed(changed_weapon_id: StringName, _trait_id: StringName, _new_rank: int) -> void:
	if changed_weapon_id != get_weapon_id():
		return
	_apply_stat_multipliers()


func _process(delta: float) -> void:
	if is_shutdown:
		return
	_orbit_angle += orbit_speed * delta
	_layout_pods()


func fire() -> void:
	if is_shutdown:
		return
	_ensure_pods()
	var target := _nearest_enemy()
	for pod in _pods:
		var direction := Vector2.UP
		if target != null:
			direction = pod.global_position.direction_to(target.global_position)
			if direction.length_squared() < 0.0001:
				direction = Vector2.UP
		else:
			direction = Vector2.UP.rotated(_orbit_angle)
		spawner_component.spawn(
			pod.global_position,
			null,
			func(projectile: Node) -> void: _configure_projectile(projectile, direction.normalized()),
		)
	fired.emit()


func _apply_stat_multipliers() -> void:
	if not is_node_ready():
		return
	var interval := base_fire_interval / get_effective_fire_rate_multiplier()
	interval *= float(get_trait_param(&"aux_heavy_barrel", &"fire_interval_mult", 1.0))
	interval *= float(get_trait_param(&"aux_auto_loader", &"fire_interval_mult", 1.0))
	fire_rate_timer.wait_time = maxf(0.02, interval)


func _on_weapon_shutdown() -> void:
	disconnect_weapon_trait_changed(_on_weapon_trait_changed)
	if fire_rate_timer != null:
		fire_rate_timer.stop()
		if fire_rate_timer.timeout.is_connected(fire):
			fire_rate_timer.timeout.disconnect(fire)


func _ensure_pods() -> void:
	var desired := maxi(1, pod_count)
	while _pods.size() < desired:
		var pod := Marker2D.new()
		pod.name = "CannonPod%d" % (_pods.size() + 1)
		add_child(pod)
		_pods.append(pod)
	while _pods.size() > desired:
		var extra := _pods.pop_back() as Marker2D
		if is_instance_valid(extra):
			extra.queue_free()
	# Prefer scene-authored Muzzle as first pod anchor when only one pod exists.
	if desired == 1 and muzzle != null and _pods.size() == 1:
		pass
	_layout_pods()


func _layout_pods() -> void:
	var count := _pods.size()
	if count == 0:
		return
	for index in count:
		var angle := _orbit_angle + TAU * float(index) / float(count)
		_pods[index].position = Vector2(cos(angle), sin(angle)) * orbit_radius


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	var origin := global_position
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist := origin.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _configure_projectile(projectile: Node, direction: Vector2) -> void:
	var hitbox := projectile.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox == null:
		push_error("AuxiliaryCannonWeaponSystem: projectile missing HitboxComponent.")
		return
	var move := projectile.get_node_or_null("MoveComponent") as MoveComponent
	if move == null:
		push_error("AuxiliaryCannonWeaponSystem: projectile missing MoveComponent.")
		return

	var speed := projectile_speed * float(get_trait_param(&"aux_hv_ap", &"speed_mult", 1.0))
	move.velocity = direction * speed
	projectile.rotation = direction.angle() + PI * 0.5

	var damage_mult := 1.0
	damage_mult *= float(get_trait_param(&"aux_heavy_barrel", &"damage_mult", 1.0))
	damage_mult *= float(get_trait_param(&"aux_auto_loader", &"damage_mult", 1.0))
	damage_mult *= float(get_trait_param(&"aux_hv_ap", &"damage_mult", 1.0))
	if has_trait(&"aux_he_shell"):
		damage_mult *= float(get_trait_param(&"aux_he_shell", &"direct_damage_mult", 0.95))

	var base := maxi(1, roundi(base_damage * damage_mult))
	var size_mult := float(get_trait_param(&"aux_heavy_barrel", &"size_mult", 1.0))
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
			size_mult,
			aoe_radius,
			aoe_mult,
		)
	else:
		hitbox.damage = resolve_hit_damage(base)
		hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
			return resolve_hit_damage(base, hurtbox)
