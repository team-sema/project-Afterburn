class_name PlasmaBombProjectile
extends Node2D

signal detonated(hit_count: int)

const ENEMY_HURTBOX_MASK := 1 << 1
const CONTACT_RADIUS := 4.0
const SINGULARITY_HANDLE := &"plasma_singularity"
## Bullet pull re-aims this often so a held bullet adds few trajectory events.
const SINGULARITY_PULL_STEP := 0.1
const SINGULARITY_COLOR := Color(0.72, 0.38, 1.0, 1.0)
## Lens event horizon: base size plus growth per swallowed bullet, capped.
const HORIZON_BASE_PX := 5.0
const HORIZON_PER_BULLET_PX := 0.5
const HORIZON_MAX_PX := 12.0

@export var explosion_effect_scene: PackedScene
@export var explosion_color := Color(0.35, 0.9, 1.0, 1.0)
## Radial sparks layered on the explosion effect (the profile skips the flare).
@export var impact_profile: ImpactProfile = preload("res://effects/impact_profiles/plasma_bomb.tres")
@export var cluster_bomb_scene: PackedScene

@onready var visual: Node2D = $Visual
@onready var fuse_timer: Timer = $FuseTimer

var _elapsed := 0.0
var _detonated := false
var flight_speed := 0.0
var flight_direction := Vector2.UP
var fuse_time := 0.0
var blast_radius := 0.0
var damage_radius_margin := 0.0
var blast_damage := 0

var _damage_multiplier := 1.0
var _boss_damage_multiplier := 1.0
var _cluster_count := 0
var _cluster_damage_mult := 0.4
var _field_duration := 0.0
var _field_max_bonus_mult := 1.0
var _pull_strength := 0.0
var _pull_radius_multiplier := 1.0
var _is_cluster_child := false
## plasma_singularity_prism config; empty when the bomb explodes normally.
var _singularity: Dictionary = {}
## Seconds left as a singularity; negative until the bomb first "detonates".
var _singularity_left := -1.0
var _singularity_pull_left := 0.0
var _swallowed := 0
var _lens: SingularityLens
## Players inside the pull range are invincible (the lens warps what they
## dodge). instance id -> HurtComponent currently held by this singularity.
var _sheltered: Dictionary = {}


func configure_bomb(
	configured_speed: float,
	configured_fuse_time: float,
	configured_blast_radius: float,
	configured_damage_radius_margin: float,
	configured_damage: int,
) -> void:
	flight_speed = maxf(1.0, configured_speed)
	# Zero disables the fuse; only cluster children use a timed detonation.
	fuse_time = maxf(0.0, configured_fuse_time)
	blast_radius = maxf(4.0, configured_blast_radius)
	damage_radius_margin = maxf(0.0, configured_damage_radius_margin)
	blast_damage = maxi(1, configured_damage)


func configure_plasma_traits(
	weapon: WeaponSystem,
	cluster_count: int,
	cluster_damage_mult: float,
	field_duration: float,
	field_max_bonus_mult: float,
	pull_strength: float,
	pull_radius_multiplier: float = 1.0,
) -> void:
	if weapon != null and is_instance_valid(weapon):
		configure_damage_snapshot(
			weapon.get_effective_damage_multiplier(),
			weapon.get_boss_damage_multiplier(),
		)
	_cluster_count = maxi(0, cluster_count)
	_cluster_damage_mult = maxf(0.0, cluster_damage_mult)
	_field_duration = maxf(0.0, field_duration)
	_field_max_bonus_mult = maxf(0.0, field_max_bonus_mult)
	_pull_strength = maxf(0.0, pull_strength)
	_pull_radius_multiplier = maxf(1.0, pull_radius_multiplier)


func configure_damage_snapshot(damage_multiplier: float, boss_damage_multiplier: float) -> void:
	_damage_multiplier = maxf(0.01, damage_multiplier)
	_boss_damage_multiplier = maxf(0.01, boss_damage_multiplier)


func set_flight_direction(direction: Vector2) -> void:
	flight_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.UP


func mark_as_cluster_child() -> void:
	_is_cluster_child = true
	_cluster_count = 0
	_field_duration = 0.0
	_pull_strength = 0.0
	_singularity = {}


## plasma_singularity_prism: the first detonation turns the bomb into a
## singularity that pulls enemies and bullets, then collapses.
func configure_singularity(config: Dictionary) -> void:
	_singularity = config.duplicate()


func is_singularity_active() -> bool:
	return _singularity_left >= 0.0 and not _detonated


func get_swallowed_count() -> int:
	return _swallowed


func get_lens() -> SingularityLens:
	return _lens if is_instance_valid(_lens) else null


func get_singularity_pull_radius() -> float:
	return get_damage_radius() * float(_singularity.get(&"pull_radius_mult", 1.75))


## Collapse blast radius. The screen lens uses the same size, so the collapse
## wave ends where the blast does and the warp stays off the wider pull range.
func get_collapse_radius() -> float:
	return get_damage_radius() * float(_singularity.get(&"collapse_radius_mult", 1.25))


func get_damage_radius() -> float:
	return blast_radius + damage_radius_margin


func _ready() -> void:
	assert(explosion_effect_scene != null, "PlasmaBombProjectile requires an explosion effect scene.")
	if fuse_time > 0.0:
		fuse_timer.wait_time = fuse_time
		fuse_timer.timeout.connect(_detonate)
		fuse_timer.start()


func _process(delta: float) -> void:
	if _detonated:
		return
	_elapsed += delta
	var active := is_singularity_active()
	visual.rotation += delta * (6.0 if active else 1.4)
	var pulse := 1.0 + sin(_elapsed * TAU * 3.0) * 0.08
	visual.scale = Vector2.ONE * pulse * (0.7 if active else 1.0)
	if active:
		queue_redraw()


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	if is_singularity_active():
		_singularity_tick(delta)
		return
	var bounds := get_canvas_transform().affine_inverse() * get_viewport_rect()
	var start := global_position
	if not bounds.has_point(start):
		global_position = start.clamp(bounds.position, bounds.end)
		_detonate()
		return
	var motion := flight_direction * flight_speed * delta
	var boundary_fraction := 1.0
	for axis in 2:
		if motion[axis] > 0.0:
			boundary_fraction = minf(boundary_fraction, (bounds.end[axis] - start[axis]) / motion[axis])
		elif motion[axis] < 0.0:
			boundary_fraction = minf(boundary_fraction, (bounds.position[axis] - start[axis]) / motion[axis])
	var reaches_boundary := not bounds.has_point(start + motion) or boundary_fraction < 1.0
	# has_point includes the top/left boundary, so check exact arrival as well.
	var destination := start + motion * boundary_fraction
	reaches_boundary = reaches_boundary or destination.x <= bounds.position.x or destination.y <= bounds.position.y

	var shape := CircleShape2D.new()
	shape.radius = CONTACT_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, start)
	query.collision_mask = ENEMY_HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space := get_world_2d().direct_space_state
	# cast_motion ignores initial overlaps.
	if not space.intersect_shape(query, 1).is_empty():
		_detonate()
		return
	query.motion = destination - start
	var fractions := space.cast_motion(query)
	if fractions[0] < 1.0:
		global_position = start + query.motion * fractions[0]
		_detonate()
		return
	global_position = destination
	if reaches_boundary:
		_detonate()


func detonate_now() -> void:
	_detonate()


func _detonate() -> void:
	if _detonated or is_singularity_active():
		return
	if not _singularity.is_empty():
		_begin_singularity()
		return
	_explode(blast_damage, get_damage_radius(), blast_radius)


func _begin_singularity() -> void:
	fuse_timer.stop()
	_singularity_left = maxf(0.01, float(_singularity.get(&"duration", 2.0)))
	_singularity_pull_left = 0.0
	visual.visible = false
	# Draw the pull ring above the lens so the lens does not warp it.
	z_index = SingularityLens.Z_INDEX + 1
	z_as_relative = false
	var parent := get_parent()
	if parent != null:
		_lens = SingularityLens.new()
		_lens.setup(get_collapse_radius(), self)
		_lens.set_horizon(HORIZON_BASE_PX)
		parent.add_child(_lens)
		_lens.global_position = global_position
	queue_redraw()


func _singularity_tick(delta: float) -> void:
	_singularity_left = maxf(0.0, _singularity_left - delta)
	_pull_enemies(delta)
	_singularity_pull_left -= delta
	if _singularity_pull_left <= 0.0:
		_singularity_pull_left += SINGULARITY_PULL_STEP
		_pull_bullets(SINGULARITY_PULL_STEP)
	_swallow_bullets()
	_update_shelter()
	if _singularity_left <= 0.0:
		_collapse()


func _pull_enemies(delta: float) -> void:
	var radius := get_singularity_pull_radius()
	var accel := float(_singularity.get(&"enemy_pull", 1500.0))
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset := global_position - enemy.global_position
		var dist := offset.length()
		if dist > radius or dist < 0.5:
			continue
		var modifier := enemy.get_node_or_null("MoveModifierComponent") as MoveModifierComponent
		if modifier != null:
			modifier.apply_impulse(offset / dist * accel * sqrt(1.0 - dist / radius) * delta)


## Turns each bullet in range toward the core by at most bullet_turn_deg/s,
## keeping the offset it has built up (combat.md 외부 궤도 개입).
func _pull_bullets(step: float) -> void:
	var world := _bullet_world()
	if world == null:
		return
	var max_turn := deg_to_rad(float(_singularity.get(&"bullet_turn_deg", 450.0))) * step
	var speed_mult := float(_singularity.get(&"bullet_speed_mult", 0.85))
	for bullet in EnemyBullets.query_circle(world, global_position, get_singularity_pull_radius()):
		if not bullet.has_method("get_travel_velocity"):
			continue
		var velocity: Vector2 = bullet.call("get_travel_velocity")
		var toward := global_position - bullet.global_position
		if velocity.is_zero_approx() or toward.is_zero_approx():
			continue
		var turn := clampf(velocity.angle_to(toward), -max_turn, max_turn)
		var offset := float(EnemyBullets.get_effect(bullet, SINGULARITY_HANDLE).get("heading_offset", 0.0))
		EnemyBullets.apply_effect(bullet, SINGULARITY_HANDLE, speed_mult, offset + rad_to_deg(turn))


func _swallow_bullets() -> void:
	var world := _bullet_world()
	if world == null:
		return
	var swallowed := EnemyBullets.cancel_all(
		world,
		EnemyBullets.query_circle(world, global_position, float(_singularity.get(&"swallow_radius", 14.0))),
		EnemyBullets.REASON_SINGULARITY,
	)
	if swallowed <= 0:
		return
	_swallowed += swallowed
	if is_instance_valid(_lens):
		_lens.kick()
		_lens.set_horizon(minf(HORIZON_MAX_PX, HORIZON_BASE_PX + HORIZON_PER_BULLET_PX * float(_swallowed)))


func _bullet_world() -> Node:
	return get_tree().get_first_node_in_group("gameplay_world")


func get_collapse_damage() -> int:
	var bonus := minf(
		float(_singularity.get(&"max_bonus", 2.0)),
		float(_swallowed) * float(_singularity.get(&"bonus_per_bullet", 0.08)),
	)
	return maxi(1, roundi(float(blast_damage) * (1.0 + bonus)))


func _collapse() -> void:
	var radius_mult := float(_singularity.get(&"collapse_radius_mult", 1.25))
	if is_instance_valid(_lens):
		_lens.collapse()
	_explode(get_collapse_damage(), get_damage_radius() * radius_mult, blast_radius * radius_mult)


func get_sheltered_count() -> int:
	return _sheltered.size()


## Per-bomb handle so overlapping singularities hold and release independently.
func _shelter_handle() -> StringName:
	return StringName("%s_%d" % [SINGULARITY_HANDLE, get_instance_id()])


func _update_shelter() -> void:
	var radius := get_singularity_pull_radius()
	var current: Dictionary = {}
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Node2D
		if player == null or player.global_position.distance_to(global_position) > radius:
			continue
		var hurt := player.get_node_or_null("HurtComponent") as HurtComponent
		if hurt == null:
			continue
		current[hurt.get_instance_id()] = hurt
		if not _sheltered.has(hurt.get_instance_id()):
			hurt.set_invincibility_hold(_shelter_handle(), true)
	for id in _sheltered:
		if not current.has(id) and is_instance_valid(_sheltered[id]):
			(_sheltered[id] as HurtComponent).set_invincibility_hold(_shelter_handle(), false)
	_sheltered = current


func _release_shelter() -> void:
	for id in _sheltered:
		if is_instance_valid(_sheltered[id]):
			(_sheltered[id] as HurtComponent).set_invincibility_hold(_shelter_handle(), false)
	_sheltered.clear()


func _exit_tree() -> void:
	_release_shelter()


func _explode(damage: int, damage_radius: float, effect_radius: float) -> void:
	_detonated = true
	_release_shelter()
	fuse_timer.stop()
	if _pull_strength > 0.0:
		_apply_gravity_pull()
	var hit_count := _deal_blast_damage(damage, damage_radius)
	_spawn_explosion_effect(effect_radius)
	ImpactVfx.emit_from(self, global_position, impact_profile, Vector2.DOWN, 0.5 if _is_cluster_child else 1.0)
	if not _is_cluster_child:
		_spawn_clusters()
		_spawn_residual_field()
	detonated.emit(hit_count)
	queue_free()


func _deal_blast_damage(damage: int, radius := -1.0) -> int:
	var world := get_world_2d()
	if world == null:
		return 0
	var shape := CircleShape2D.new()
	shape.radius = radius if radius > 0.0 else get_damage_radius()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hitbox := HitboxComponent.new()
	var hit_hurtboxes: Dictionary = {}
	# Gather every overlap before emitting damage: no occlusion or target cap.
	var results: Array[Dictionary] = []
	var excluded: Array[RID] = []
	while true:
		query.exclude = excluded
		var batch := world.direct_space_state.intersect_shape(query, 64)
		results.append_array(batch)
		for result in batch:
			excluded.append(result["rid"])
		if batch.size() < 64:
			break
	for result in results:
		var collider: Variant = result.get("collider")
		if not is_instance_valid(collider) or not collider is HurtboxComponent:
			continue
		var hurtbox := collider as HurtboxComponent
		if hurtbox.is_invincible or hit_hurtboxes.has(hurtbox.get_instance_id()):
			continue
		hit_hurtboxes[hurtbox.get_instance_id()] = true
		hitbox.damage = _resolve_hit_damage(damage, hurtbox)
		hitbox.hit_hurtbox.emit(hurtbox)
		hurtbox.hurt.emit(hitbox)
	var hit_count := hit_hurtboxes.size()
	hitbox.free()
	return hit_count


func _resolve_hit_damage(damage: int, hurtbox: HurtboxComponent = null) -> int:
	var multiplier := _damage_multiplier
	multiplier *= WeaponSystem.get_target_damage_multiplier(hurtbox, _boss_damage_multiplier)
	return maxi(1, roundi(float(damage) * multiplier))


func _apply_gravity_pull() -> void:
	var radius := get_damage_radius() * _pull_radius_multiplier
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset := global_position - enemy.global_position
		var dist := offset.length()
		if dist > radius or dist < 0.01:
			continue
		var falloff := sqrt(1.0 - dist / radius)
		var strength := _pull_strength * falloff
		var modifier := enemy.get_node_or_null("MoveModifierComponent") as MoveModifierComponent
		if modifier != null:
			modifier.apply_impulse(offset.normalized() * strength)


func _spawn_clusters() -> void:
	if _cluster_count <= 0:
		return
	var scene := cluster_bomb_scene
	if scene == null:
		scene = load("res://projectiles/plasma_bomb_projectile.tscn") as PackedScene
	if scene == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	for index in _cluster_count:
		var angle := TAU * float(index) / float(_cluster_count) - PI * 0.5
		var direction := Vector2(cos(angle), sin(angle))
		var child := scene.instantiate() as PlasmaBombProjectile
		if child == null:
			continue
		child.configure_bomb(
			flight_speed * 0.7,
			0.35,
			maxf(8.0, blast_radius * 0.45),
			damage_radius_margin * 0.5,
			maxi(1, roundi(float(blast_damage) * _cluster_damage_mult)),
		)
		child.mark_as_cluster_child()
		child.set_flight_direction(direction)
		child.configure_damage_snapshot(_damage_multiplier, _boss_damage_multiplier)
		parent.add_child(child)
		child.global_position = global_position + direction * 10.0


func _spawn_residual_field() -> void:
	if _field_duration <= 0.0:
		return
	var parent := get_parent()
	if parent == null:
		return
	var field_script := load("res://projectiles/plasma_residual_field.gd") as Script
	var field := Node2D.new()
	field.set_script(field_script)
	field.call(
		"configure",
		_field_duration,
		get_damage_radius() * 0.85,
		blast_damage,
		_field_max_bonus_mult,
		_damage_multiplier,
		_boss_damage_multiplier,
	)
	parent.add_child(field)
	field.global_position = global_position


func _spawn_explosion_effect(radius := -1.0) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var effect := explosion_effect_scene.instantiate() as Node2D
	if effect == null:
		return
	parent.add_child(effect)
	effect.global_position = global_position
	if effect.has_method("set_effect_radius"):
		effect.call("set_effect_radius", radius if radius > 0.0 else blast_radius)
	else:
		push_error("PlasmaBombProjectile: explosion effect missing set_effect_radius().")
	if effect.has_method("set_effect_color"):
		effect.call("set_effect_color", explosion_color)


func _draw() -> void:
	if not is_singularity_active():
		return
	var total := maxf(0.01, float(_singularity.get(&"duration", 2.0)))
	var left := clampf(_singularity_left / total, 0.0, 1.0)
	var pull_radius := get_singularity_pull_radius()
	# The lens draws the core. A fixed faint ring marks the whole pull range; a
	# brighter arc on it runs clockwise from the top and shrinks with time left.
	draw_arc(Vector2.ZERO, pull_radius, 0.0, TAU, 64, Color(SINGULARITY_COLOR, 0.22), 1.0)
	if left > 0.0:
		var start := -PI * 0.5
		draw_arc(
			Vector2.ZERO,
			pull_radius,
			start,
			start + TAU * left,
			maxi(4, ceili(64.0 * left)),
			Color(SINGULARITY_COLOR, 0.75),
			2.0,
		)
