extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var controller := ShipCombatBuffController.new()
	root.add_child(controller)
	controller.set("_has_overcharge", true)

	var projectile_scenes := [
		"res://projectiles/player_blaster.tscn",
		"res://projectiles/player_shotgun_pellet.tscn",
		"res://projectiles/player_homing_missile.tscn",
		"res://projectiles/aux_cannon_bolt.tscn",
		"res://projectiles/plasma_bomb_projectile.tscn",
	]
	var persistent_scenes := [
		"res://player_ship/weapons/laser_weapon_system.tscn",
		"res://player_ship/weapons/orbital_barrier_weapon_system.tscn",
	]
	var instances: Array[Node] = []
	var old_projectile_visuals: Array[CanvasItem] = []
	var old_projectile_colors: Array[Color] = []
	for path in projectile_scenes:
		var instance := (load(path) as PackedScene).instantiate()
		if instance is PlasmaBombProjectile:
			(instance as PlasmaBombProjectile).configure_bomb(1.0, 1.0, 24.0, 0.0, 1)
			(instance as PlasmaBombProjectile).position = Vector2(120, 180)
		instances.append(instance)
		var visual := _find_visual(instance)
		_expect(visual != null, "%s has a render visual" % path)
		if visual != null:
			old_projectile_visuals.append(visual)
			old_projectile_colors.append(visual.self_modulate)
		root.add_child(instance)

	var persistent_visuals: Array[CanvasItem] = []
	var persistent_colors: Array[Color] = []
	for path in persistent_scenes:
		var instance := (load(path) as PackedScene).instantiate()
		instances.append(instance)
		var visual := _find_visual(instance)
		persistent_visuals.append(visual)
		persistent_colors.append(visual.self_modulate)
		root.add_child(instance)

	controller.call("_start_buff", ShipCombatBuffController.BUFF_OVERCHARGE)
	await process_frame
	for index in old_projectile_visuals.size():
		_expect(
			old_projectile_visuals[index].self_modulate.is_equal_approx(
				old_projectile_colors[index]
			),
			"a projectile already in flight keeps its original color",
		)
	for index in persistent_visuals.size():
		var tinted := persistent_visuals[index].self_modulate
		var base := persistent_colors[index]
		_expect(tinted.r > tinted.g and tinted.r > tinted.b, "overcharge tint is red")
		_expect(is_equal_approx(tinted.a, base.a), "overcharge preserves visual alpha")

	# A projectile created midway through the buff must start red immediately.
	var active_projectile := (
		load("res://projectiles/player_blaster.tscn") as PackedScene
	).instantiate()
	var active_visual := _find_visual(active_projectile)
	var active_base := active_visual.self_modulate
	instances.append(active_projectile)
	root.add_child(active_projectile)
	await process_frame
	_expect(
		active_visual.self_modulate.r > active_visual.self_modulate.g,
		"projectiles spawned during overcharge start red",
	)

	controller.call("_end_buff", ShipCombatBuffController.BUFF_OVERCHARGE)
	await process_frame
	for index in persistent_visuals.size():
		_expect(
			persistent_visuals[index].self_modulate.is_equal_approx(persistent_colors[index]),
			"persistent weapons restore their original color when overcharge ends",
		)
	_expect(
		not active_visual.self_modulate.is_equal_approx(active_base),
		"an empowered projectile keeps its spawn-time red state after the buff ends",
	)

	await _test_damage_snapshot()

	for instance in instances:
		instance.queue_free()
	controller.queue_free()
	await process_frame

	if failures.is_empty():
		print("overcharge weapon visual smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("overcharge weapon visual smoke test: %s" % failure)
	quit(1)


func _test_damage_snapshot() -> void:
	var weapon := WeaponSystem.new()
	root.add_child(weapon)
	weapon.set_temp_damage_multiplier(1.0)
	var old_projectile := (
		load("res://projectiles/player_blaster.tscn") as PackedScene
	).instantiate()
	old_projectile.call(
		"configure_blaster_combat",
		weapon,
		10,
		0,
		1.0,
		0,
		[],
		96.0,
	)
	root.add_child(old_projectile)
	weapon.set_temp_damage_multiplier(1.4)
	var old_hitbox := old_projectile.get_node("HitboxComponent") as HitboxComponent
	_expect(
		int(old_hitbox.damage_resolver.call(null)) == 10,
		"an in-flight projectile keeps its pre-overcharge damage",
	)

	var empowered_projectile := (
		load("res://projectiles/player_blaster.tscn") as PackedScene
	).instantiate()
	empowered_projectile.call(
		"configure_blaster_combat",
		weapon,
		10,
		0,
		1.0,
		0,
		[],
		96.0,
	)
	root.add_child(empowered_projectile)
	weapon.set_temp_damage_multiplier(1.0)
	var empowered_hitbox := empowered_projectile.get_node("HitboxComponent") as HitboxComponent
	_expect(
		int(empowered_hitbox.damage_resolver.call(null)) == 14,
		"a projectile spawned during overcharge keeps its empowered damage",
	)
	old_projectile.queue_free()
	empowered_projectile.queue_free()
	weapon.queue_free()
	await process_frame


func _find_visual(node: Node) -> CanvasItem:
	if node is Sprite2D or node is Line2D or node is Polygon2D:
		return node as CanvasItem
	for child in node.get_children():
		var result := _find_visual(child)
		if result != null:
			return result
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
