class_name PlasmaBombProjectile
extends Node2D

signal detonated(hit_count: int)

const ENEMY_HURTBOX_MASK := 1 << 1

@export var explosion_effect_scene: PackedScene
@export var explosion_color := Color(0.35, 0.9, 1.0, 1.0)
@export var cluster_bomb_scene: PackedScene

@onready var visual: Node2D = $Visual
@onready var fuse_timer: Timer = $FuseTimer

var _elapsed := 0.0
var _detonated := false
var flight_speed := 0.0
var fuse_time := 0.0
var blast_radius := 0.0
var damage_radius_margin := 0.0
var blast_damage := 0

var _weapon: WeaponSystem
var _cluster_count := 0
var _cluster_damage_mult := 0.4
var _field_duration := 0.0
var _field_max_bonus_mult := 1.0
var _pull_strength := 0.0
var _is_cluster_child := false


func configure_bomb(
	configured_speed: float,
	configured_fuse_time: float,
	configured_blast_radius: float,
	configured_damage_radius_margin: float,
	configured_damage: int,
) -> void:
	flight_speed = maxf(1.0, configured_speed)
	fuse_time = maxf(0.05, configured_fuse_time)
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
) -> void:
	_weapon = weapon
	_cluster_count = maxi(0, cluster_count)
	_cluster_damage_mult = maxf(0.0, cluster_damage_mult)
	_field_duration = maxf(0.0, field_duration)
	_field_max_bonus_mult = maxf(0.0, field_max_bonus_mult)
	_pull_strength = maxf(0.0, pull_strength)


func mark_as_cluster_child() -> void:
	_is_cluster_child = true
	_cluster_count = 0
	_field_duration = 0.0
	_pull_strength = 0.0


func get_damage_radius() -> float:
	return blast_radius + damage_radius_margin


func _ready() -> void:
	assert(explosion_effect_scene != null, "PlasmaBombProjectile requires an explosion effect scene.")
	fuse_timer.wait_time = fuse_time
	fuse_timer.timeout.connect(_detonate)
	fuse_timer.start()


func _process(delta: float) -> void:
	if _detonated:
		return
	_elapsed += delta
	global_position.y -= flight_speed * delta
	visual.rotation += delta * 1.4
	var pulse := 1.0 + sin(_elapsed * TAU * 3.0) * 0.08
	visual.scale = Vector2.ONE * pulse


func detonate_now() -> void:
	_detonate()


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	if _pull_strength > 0.0:
		_apply_gravity_pull()
	var hit_count := _deal_blast_damage(blast_damage)
	_spawn_explosion_effect()
	if not _is_cluster_child:
		_spawn_clusters()
		_spawn_residual_field()
	detonated.emit(hit_count)
	queue_free()


func _deal_blast_damage(damage: int) -> int:
	var world := get_world_2d()
	if world == null:
		return 0
	var shape := CircleShape2D.new()
	shape.radius = get_damage_radius()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hitbox := HitboxComponent.new()
	var hit_hurtboxes: Dictionary = {}
	for result in world.direct_space_state.intersect_shape(query, 64):
		var collider: Variant = result.get("collider")
		if not collider is HurtboxComponent:
			continue
		var hurtbox := collider as HurtboxComponent
		if hurtbox.is_invincible or hit_hurtboxes.has(hurtbox.get_instance_id()):
			continue
		hit_hurtboxes[hurtbox.get_instance_id()] = true
		if _weapon != null:
			hitbox.damage = _weapon.resolve_hit_damage(damage, hurtbox)
		else:
			hitbox.damage = damage
		hitbox.hit_hurtbox.emit(hurtbox)
		hurtbox.hurt.emit(hitbox)
	var hit_count := hit_hurtboxes.size()
	hitbox.free()
	return hit_count


func _apply_gravity_pull() -> void:
	var radius := get_damage_radius()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset := global_position - enemy.global_position
		var dist := offset.length()
		if dist > radius or dist < 0.01:
			continue
		var strength := _pull_strength * (1.0 - dist / radius)
		enemy.global_position += offset.normalized() * strength * 0.05
		var move := enemy.get_node_or_null("MoveComponent") as MoveComponent
		if move != null:
			move.velocity += offset.normalized() * strength


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
		var child := scene.instantiate() as PlasmaBombProjectile
		if child == null:
			continue
		parent.add_child(child)
		child.global_position = global_position + Vector2(cos(angle), sin(angle)) * 10.0
		child.configure_bomb(
			flight_speed * 0.7,
			0.35,
			maxf(8.0, blast_radius * 0.45),
			damage_radius_margin * 0.5,
			maxi(1, roundi(float(blast_damage) * _cluster_damage_mult)),
		)
		child.mark_as_cluster_child()
		if _weapon != null:
			child.configure_plasma_traits(_weapon, 0, 0.0, 0.0, 0.0, 0.0)


func _spawn_residual_field() -> void:
	if _field_duration <= 0.0:
		return
	var parent := get_parent()
	if parent == null:
		return
	var field_script := load("res://projectiles/plasma_residual_field.gd") as Script
	var field := Node2D.new()
	field.set_script(field_script)
	parent.add_child(field)
	field.global_position = global_position
	field.call(
		"configure",
		_field_duration,
		get_damage_radius() * 0.85,
		blast_damage,
		_field_max_bonus_mult,
		_weapon,
	)


func _spawn_explosion_effect() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var effect := explosion_effect_scene.instantiate() as Node2D
	if effect == null:
		return
	parent.add_child(effect)
	effect.global_position = global_position
	if effect.has_method("set_effect_radius"):
		effect.call("set_effect_radius", blast_radius)
	else:
		push_error("PlasmaBombProjectile: explosion effect missing set_effect_radius().")
	if effect.has_method("set_effect_color"):
		effect.call("set_effect_color", explosion_color)
