extends SceneTree

const PROJECTILE_SCENE := preload("res://projectiles/plasma_bomb_projectile.tscn")
const WEAPON_DEFINITION := preload("res://resources/weapons/definitions/plasma_bomb.tres")

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)

	_expect(WEAPON_DEFINITION.id == &"plasma_bomb", "plasma bomb definition has the expected id")
	_expect(WEAPON_DEFINITION.weapon_scene != null, "plasma bomb definition declares a weapon scene")
	_expect(WEAPON_DEFINITION.icon != null, "plasma bomb definition declares an icon")

	var damage_taken := {
		"near_a": 0,
		"near_b": 0,
		"margin": 0,
		"far": 0,
	}
	_make_target(world, Vector2(100, 100), damage_taken, "near_a")
	_make_target(world, Vector2(122, 100), damage_taken, "near_b")
	_make_target(world, Vector2(138, 100), damage_taken, "margin")
	_make_target(world, Vector2(150, 100), damage_taken, "far")

	var weapon_system := WEAPON_DEFINITION.weapon_scene.instantiate() as PlasmaBombWeaponSystem
	_expect(weapon_system.damage_radius_margin == 0.0, "damage radius margin defaults to zero")
	weapon_system.base_fire_interval = 2.2
	weapon_system.base_damage = 24
	weapon_system.projectile_speed = 38.0
	weapon_system.blast_radius = 34.0
	weapon_system.damage_radius_margin = 6.0
	var projectile := PROJECTILE_SCENE.instantiate() as PlasmaBombProjectile
	projectile.global_position = Vector2(100, 150)
	weapon_system.call("_configure_projectile", projectile)
	_expect(is_equal_approx(projectile.get_damage_radius(), 40.0), "damage radius includes the configured margin")
	var detonation_result := {"count": -1, "events": 0}
	projectile.detonated.connect(func(hit_count: int) -> void:
		detonation_result["count"] = hit_count
		detonation_result["events"] += 1
	)
	world.add_child(projectile)
	projectile.set_physics_process(false)

	await physics_frame
	var initial_y := projectile.global_position.y
	projectile.call("_physics_process", 0.1)
	_expect(is_instance_valid(projectile), "plasma bomb remains active before contact")
	_expect(projectile.global_position.y < initial_y, "plasma bomb travels slowly forward")
	_expect(damage_taken["near_a"] == 0, "plasma bomb deals no damage before detonation")

	await create_timer(1.35).timeout
	_expect(not projectile._detonated, "main bomb does not explode after the old 1.25 second fuse")
	projectile.call("_physics_process", 2.0)
	projectile.detonate_now()
	await physics_frame
	_expect(detonation_result["events"] == 1, "contact and repeated requests produce exactly one explosion")
	_expect(detonation_result["count"] == 3, "plasma blast includes the target inside its damage margin")
	_expect(damage_taken["near_a"] == 24, "plasma blast damages the first nearby target")
	_expect(damage_taken["near_b"] == 24, "plasma blast damages the second nearby target")
	_expect(damage_taken["margin"] == 24, "plasma blast damages a target inside the configured margin")
	_expect(damage_taken["far"] == 0, "plasma blast leaves targets outside its radius untouched")
	var explosion_effect := world.get_node_or_null("ExplosionEffect") as Node2D
	_expect(explosion_effect != null, "plasma bomb creates its explosion effect")
	if explosion_effect != null:
		_expect(
			is_equal_approx(float(explosion_effect.call("get_effect_radius")), weapon_system.blast_radius),
			"visual explosion radius remains the configured blast radius",
		)

	var detached_weapon := WEAPON_DEFINITION.weapon_scene.instantiate() as PlasmaBombWeaponSystem
	detached_weapon.set_global_damage_multiplier(1.5)
	detached_weapon.set_boss_damage_multiplier(1.25)
	var cluster_source := PROJECTILE_SCENE.instantiate() as PlasmaBombProjectile
	cluster_source.configure_bomb(38.0, 1.0, 34.0, 0.0, 24)
	cluster_source.configure_plasma_traits(detached_weapon, 3, 0.4, 3.0, 1.0, 0.0)
	detached_weapon.free()
	cluster_source.position = Vector2(200, 200)
	world.add_child(cluster_source)
	cluster_source.detonate_now()
	await process_frame
	var cluster_children: Array[PlasmaBombProjectile] = []
	for child in world.get_children():
		if child is PlasmaBombProjectile:
			cluster_children.append(child as PlasmaBombProjectile)
	_expect(cluster_children.size() == 3, "cluster trait creates three child bombs")
	var direction_sum := Vector2.ZERO
	for child in cluster_children:
		_expect(is_equal_approx(child.fuse_time, 0.35), "cluster child stores its short fuse")
		_expect(
			is_equal_approx((child.get_node("FuseTimer") as Timer).wait_time, 0.35),
			"cluster child configures its timer before entering the tree",
		)
		_expect(
			is_equal_approx(child.flight_direction.length(), 1.0),
			"cluster child receives a normalized flight direction",
		)
		direction_sum += child.flight_direction
		var position_before_move := child.global_position
		child.call("_physics_process", 0.1)
		var movement := child.global_position - position_before_move
		_expect(
			movement.normalized().dot(child.flight_direction) > 0.999,
			"cluster child moves along its radial direction",
		)
		_expect(
			int(child.call("_resolve_hit_damage", 10)) == 15,
			"cluster child keeps the launch-time damage multiplier after weapon removal",
		)
	_expect(direction_sum.length() < 0.001, "cluster child directions are evenly distributed radially")
	for child in cluster_children:
		child.queue_free()
	await process_frame

	var residual_field: PlasmaResidualField = null
	for child in world.get_children():
		if child is PlasmaResidualField:
			residual_field = child as PlasmaResidualField
			break
	_expect(residual_field != null, "residual field trait creates a field")
	if residual_field != null:
		_expect(
			is_equal_approx(residual_field.damage_multiplier, 1.5),
			"residual field keeps the launch-time damage multiplier after weapon removal",
		)
		_expect(
			is_equal_approx(residual_field.boss_damage_multiplier, 1.25),
			"residual field keeps the launch-time boss multiplier after weapon removal",
		)
		var field_fill := residual_field.get_node("Visual/FieldFill") as Polygon2D
		_expect(field_fill != null, "residual field creates a visible translucent fill")
		if field_fill != null:
			_expect(
				field_fill.color.a > 0.0 and field_fill.color.a < 1.0,
				"residual field fill is translucent",
			)
			_expect(
				is_equal_approx(field_fill.polygon[0].length(), residual_field.radius),
				"residual field visual matches its damage radius",
			)
		_expect(residual_field.has_node("Visual/OuterRing"), "residual field has a visible boundary ring")

	var configured_projectile := PROJECTILE_SCENE.instantiate() as PlasmaBombProjectile
	weapon_system.set_global_damage_multiplier(1.5)
	weapon_system.call("_configure_projectile", configured_projectile)
	_expect(configured_projectile.blast_damage == 24, "configure stores trait-adjusted base damage")
	_expect(
		weapon_system.resolve_hit_damage(configured_projectile.blast_damage) == 36,
		"weapon damage multiplier scales blast damage",
	)
	configured_projectile.free()
	weapon_system.free()

	world.queue_free()
	await process_frame
	await _test_boundaries_and_dense_blast()
	if failures.is_empty():
		print("plasma bomb weapon smoke test: PASS")
		quit()
		return
	for failure in failures:
		push_error("plasma bomb weapon smoke test: %s" % failure)
	quit(1)


func _test_boundaries_and_dense_blast() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 360)
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var received := {"edge": 0, "outside": 0, "immune": 0}
	_make_target(world, Vector2(125, 20), received, "edge")
	_make_target(world, Vector2(180, 20), received, "outside")
	var immune := _make_target(world, Vector2(115, 20), received, "immune")
	immune.is_invincible = true
	await physics_frame
	await physics_frame
	var bomb := PROJECTILE_SCENE.instantiate() as PlasmaBombProjectile
	bomb.configure_bomb(120.0, 0.0, 34.0, 0.0, 24)
	bomb.position = Vector2(120, 1)
	var result := {"events": 0, "position": Vector2.ZERO}
	bomb.detonated.connect(func(_hits: int) -> void:
		result["events"] += 1
		result["position"] = bomb.global_position
	)
	world.add_child(bomb)
	for frame in 4:
		await physics_frame
	_expect(result["events"] == 1, "physics processing detonates at the playfield edge")
	_expect(result["position"] == Vector2(120, 0), "explosion is at the SubViewport boundary without overshoot")
	_expect(received["edge"] == 24, "edge explosion damages nearby enemies immediately")
	_expect(received["outside"] == 0, "edge explosion excludes distant enemies")
	_expect(received["immune"] == 0, "piercing explosion respects invincibility")
	# More than one physics-query batch; front targets do not block rear targets.
	for index in 80:
		var key := "dense_%d" % index
		received[key] = 0
		_make_target(world, Vector2(110 + index % 10, 175 + index / 10), received, key)
	await physics_frame
	await physics_frame
	var dense_bomb := PROJECTILE_SCENE.instantiate() as PlasmaBombProjectile
	dense_bomb.configure_bomb(1000.0, 0.0, 34.0, 0.0, 24)
	dense_bomb.position = Vector2(115, 240)
	world.add_child(dense_bomb)
	dense_bomb.set_physics_process(false)
	dense_bomb.call("_physics_process", 0.2)
	_expect(dense_bomb._detonated, "swept contact detects targets crossed within one physics step")
	for index in 80:
		_expect(received["dense_%d" % index] == 24, "blast pierces all dense targets once: %d" % index)
	viewport.queue_free()
	await process_frame


func _make_target(
	parent: Node,
	position: Vector2,
	damage_taken: Dictionary,
	key: String,
) -> HurtboxComponent:
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "Target_%s" % key
	hurtbox.collision_layer = 1 << 1
	hurtbox.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 3.0
	collision.shape = shape
	hurtbox.add_child(collision)
	hurtbox.hurt.connect(func(hitbox: HitboxComponent) -> void:
		damage_taken[key] = int(damage_taken[key]) + hitbox.damage
	)
	parent.add_child(hurtbox)
	hurtbox.global_position = position
	return hurtbox


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
