class_name BombProximityFuseComponent
extends Node

## Slow bomb: when the player enters range, flash red 3× over ~2s, then detonate.
## Blast VFX/damage radius = base_explosion_radius * blast_size_multiplier (default 1.5).

@export var actor: Node2D
@export var move_component: MoveComponent
@export var targeting_component: TargetingComponent
@export var stats_component: StatsComponent
@export var visual_anchor: Node2D
@export var destroy_effect_spawner: SpawnerComponent

@export_range(8.0, 200.0, 1.0) var trigger_radius := 72.0
@export_range(0.5, 5.0, 0.05) var arm_duration := 2.0
@export_range(1, 8, 1) var flash_count := 3
@export var flash_color := Color(1.0, 0.12, 0.12, 1.0)
## Approx. normal enemy explosion reach (ring/glow feel).
@export_range(8.0, 120.0, 1.0) var base_explosion_radius := 40.0
@export_range(1.0, 3.0, 0.05) var blast_size_multiplier := 1.5
@export_range(1, 20, 1) var blast_damage := 2
@export var blast_effect_color := Color(1.0, 0.2, 0.15, 1.0)

var _armed := false
var _detonating := false
var _original_modulates: Array[Color] = []
var _flash_sprites: Array[CanvasItem] = []


func _ready() -> void:
	assert(actor != null, "BombProximityFuseComponent requires actor.")
	assert(move_component != null, "BombProximityFuseComponent requires MoveComponent.")
	assert(stats_component != null, "BombProximityFuseComponent requires StatsComponent.")
	_cache_flash_targets()


func _process(_delta: float) -> void:
	if _armed or _detonating or not is_instance_valid(actor):
		return
	var player := _get_player()
	if player == null:
		return
	if actor.global_position.distance_to(player.global_position) <= trigger_radius:
		_start_arming()


func _start_arming() -> void:
	_armed = true
	if move_component != null:
		move_component.velocity = Vector2.ZERO
	_arm_and_detonate()


func _arm_and_detonate() -> void:
	var period := arm_duration / float(maxi(1, flash_count))
	var on_time := period * 0.55
	var off_time := period - on_time
	for _i in flash_count:
		if not is_instance_valid(self) or not is_instance_valid(actor):
			return
		_set_flash(true)
		await get_tree().create_timer(on_time, false).timeout
		if not is_instance_valid(self) or not is_instance_valid(actor):
			return
		_set_flash(false)
		await get_tree().create_timer(off_time, false).timeout
	if not is_instance_valid(self) or not is_instance_valid(actor):
		return
	_detonate()


func _detonate() -> void:
	if _detonating:
		return
	_detonating = true
	_set_flash(false)

	# Avoid default DestroyedComponent VFX; we spawn a larger blast ourselves.
	var destroyed := actor.get_node_or_null("DestroyedComponent") as DestroyedComponent
	if destroyed != null and stats_component.no_health.is_connected(destroyed.destroy):
		stats_component.no_health.disconnect(destroyed.destroy)

	_spawn_blast_vfx()
	_deal_blast_damage()

	# Score / XP / queue_free via normal no_health hooks on Enemy.
	stats_component.health = 0


func _spawn_blast_vfx() -> void:
	if destroy_effect_spawner == null:
		return
	var effect := destroy_effect_spawner.spawn(actor.global_position)
	if effect == null:
		return
	effect.scale = Vector2.ONE * blast_size_multiplier
	if effect.has_method("set_effect_color"):
		effect.call("set_effect_color", blast_effect_color)


func _deal_blast_damage() -> void:
	var radius := base_explosion_radius * blast_size_multiplier
	var world := actor.get_world_2d()
	if world == null:
		return
	var circle := CircleShape2D.new()
	circle.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, actor.global_position)
	params.collision_mask = 1 # player_hurtbox
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var hitbox := HitboxComponent.new()
	hitbox.damage = blast_damage

	for result in world.direct_space_state.intersect_shape(params, 32):
		var collider: Variant = result.get("collider")
		if collider is HurtboxComponent:
			var hurtbox := collider as HurtboxComponent
			if hurtbox.is_invincible:
				continue
			hurtbox.hurt.emit(hitbox)
	hitbox.free()


func _get_player() -> Node2D:
	if targeting_component != null:
		var target := targeting_component.get_target()
		if target != null and is_instance_valid(target):
			return target
	return get_tree().get_first_node_in_group("player") as Node2D


func _cache_flash_targets() -> void:
	_flash_sprites.clear()
	_original_modulates.clear()
	if visual_anchor == null:
		return
	for child in visual_anchor.get_children():
		if child is CanvasItem:
			var item := child as CanvasItem
			_flash_sprites.append(item)
			_original_modulates.append(item.self_modulate)


func _set_flash(enabled: bool) -> void:
	for index in _flash_sprites.size():
		var item := _flash_sprites[index]
		if not is_instance_valid(item):
			continue
		if enabled:
			item.self_modulate = flash_color
		else:
			item.self_modulate = _original_modulates[index]
