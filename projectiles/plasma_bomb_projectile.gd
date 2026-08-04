class_name PlasmaBombProjectile
extends Node2D

signal detonated(hit_count: int)

const ENEMY_HURTBOX_MASK := 1 << 1

@export var explosion_effect_scene: PackedScene
@export var explosion_color := Color(0.35, 0.9, 1.0, 1.0)

@onready var visual: Node2D = $Visual
@onready var fuse_timer: Timer = $FuseTimer

var _elapsed := 0.0
var _detonated := false
var flight_speed := 0.0
var fuse_time := 0.0
var blast_radius := 0.0
var damage_radius_margin := 0.0
var blast_damage := 0


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
	var hit_count := _deal_blast_damage()
	_spawn_explosion_effect()
	detonated.emit(hit_count)
	queue_free()


func _deal_blast_damage() -> int:
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
	hitbox.damage = blast_damage
	var hit_hurtboxes: Dictionary = {}
	for result in world.direct_space_state.intersect_shape(query, 64):
		var collider: Variant = result.get("collider")
		if not collider is HurtboxComponent:
			continue
		var hurtbox := collider as HurtboxComponent
		if hurtbox.is_invincible or hit_hurtboxes.has(hurtbox.get_instance_id()):
			continue
		hit_hurtboxes[hurtbox.get_instance_id()] = true
		hitbox.hit_hurtbox.emit(hurtbox)
		hurtbox.hurt.emit(hitbox)
	var hit_count := hit_hurtboxes.size()
	hitbox.free()
	return hit_count


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
