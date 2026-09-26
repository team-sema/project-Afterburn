extends Node2D

## Impact scale for hits the shot continues through (pierce/ricochet).
const PASS_THROUGH_IMPACT_STRENGTH := 0.6

@export var impact_profile: ImpactProfile = preload("res://effects/impact_profiles/blaster.tres")

@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var flash_component: FlashComponent = $FlashComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var move_component: MoveComponent = $MoveComponent

var _damage_snapshot: Dictionary = {}
var _base_damage := 1
var _pierce_remaining := 0
var _pierce_falloff := 1.0
var _pierce_hits := 0
var _bounces_remaining := 0
var _bounce_damage_mults: Array[float] = []
var _bounce_index := 0
var _ricochet_radius := 96.0
var _hit_ids: Dictionary = {}
var _bounce_damage_scale := 1.0
var _pending_configure := false
## Prismatic split: fragments per split and how many more split steps remain.
var _split_count := 0
var _split_generations_left := 0
var _split_spread_deg := 90.0
var _has_split := false
## Enemy instance ids this shot and its split ancestors already hit.
var _ignored_ids: Dictionary = {}


func configure_blaster_combat(
	weapon: WeaponSystem,
	base_damage: int,
	pierce_bonus: int,
	pierce_falloff: float,
	max_bounces: int,
	bounce_damage_mults: Array,
	ricochet_radius: float,
) -> void:
	_damage_snapshot = weapon.get_projectile_damage_snapshot() if weapon != null else {}
	_base_damage = maxi(1, base_damage)
	_pierce_remaining = maxi(0, pierce_bonus)
	_pierce_falloff = clampf(pierce_falloff, 0.05, 1.0)
	_bounces_remaining = maxi(0, max_bounces)
	_bounce_damage_mults.clear()
	for value in bounce_damage_mults:
		_bounce_damage_mults.append(float(value))
	_ricochet_radius = maxf(8.0, ricochet_radius)
	_pending_configure = true
	if is_node_ready():
		_apply_damage_resolver()


## Enables the prismatic split on the first enemy hit; `ignored_ids` are never hit.
func configure_split(
	count: int,
	generations_left: int,
	spread_deg: float,
	ignored_ids: Dictionary = {},
) -> void:
	_split_count = maxi(0, count)
	_split_generations_left = maxi(0, generations_left)
	_split_spread_deg = spread_deg
	_ignored_ids = ignored_ids.duplicate()
	var hitbox := _hitbox()
	if hitbox != null and not _ignored_ids.is_empty():
		hitbox.hit_filter = func(hurtbox: HurtboxComponent) -> bool:
			var target := _enemy_from_hurtbox(hurtbox)
			return target == null or not _ignored_ids.has(target.get_instance_id())


## Split fragment: inherits the parent's launch snapshot and damage, no pierce or ricochet.
func configure_split_fragment(
	damage_snapshot: Dictionary,
	base_damage: int,
	count: int,
	generations_left: int,
	spread_deg: float,
	ignored_ids: Dictionary,
) -> void:
	_damage_snapshot = damage_snapshot.duplicate()
	_base_damage = maxi(1, base_damage)
	_pending_configure = true
	configure_split(count, generations_left, spread_deg, ignored_ids)


func _ready() -> void:
	scale_component.tween_scale()
	flash_component.flash()
	hitbox_component.hit_hurtbox.connect(_on_hit_hurtbox)
	if _pending_configure:
		_apply_damage_resolver()
	elif hitbox_component.damage <= 0:
		hitbox_component.damage = 1


func _hitbox() -> HitboxComponent:
	if hitbox_component != null:
		return hitbox_component
	return get_node_or_null("HitboxComponent") as HitboxComponent


func _move() -> MoveComponent:
	if move_component != null:
		return move_component
	return get_node_or_null("MoveComponent") as MoveComponent


func _apply_damage_resolver() -> void:
	var hitbox := _hitbox()
	if hitbox == null:
		return
	hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
		var damage_scale := _bounce_damage_scale
		if _pierce_hits > 0:
			damage_scale *= pow(_pierce_falloff, float(_pierce_hits))
		var raw := maxi(1, roundi(float(_base_damage) * damage_scale))
		return WeaponSystem.resolve_projectile_snapshot_damage(raw, hurtbox, _damage_snapshot)
	hitbox.damage = maxi(1, roundi(float(_base_damage) * _bounce_damage_scale))
	_pending_configure = false


func _on_hit_hurtbox(hurtbox: HurtboxComponent) -> void:
	var target := _enemy_from_hurtbox(hurtbox)
	if target != null:
		_hit_ids[target.get_instance_id()] = true
	var passes_through := not hurtbox.blocks_pierce and (_pierce_remaining > 0 or _bounces_remaining > 0)
	ImpactVfx.emit_from(
		self,
		global_position,
		impact_profile,
		ImpactVfx.against_travel(self),
		PASS_THROUGH_IMPACT_STRENGTH if passes_through else 1.0,
	)
	_try_split()

	if hurtbox.blocks_pierce:
		queue_free()
		return

	if _pierce_remaining > 0:
		_pierce_remaining -= 1
		_pierce_hits += 1
		_apply_damage_resolver()
		return

	if _bounces_remaining > 0:
		_bounces_remaining -= 1
		var mult := 1.0
		if _bounce_index < _bounce_damage_mults.size():
			mult = _bounce_damage_mults[_bounce_index]
		_bounce_index += 1
		_bounce_damage_scale *= mult
		_pierce_hits = 0
		_apply_damage_resolver()
		_start_ricochet(target)
		return

	queue_free()


## First enemy hit only: fan `_split_count` fragments around the travel direction.
## Fragments are added deferred because this runs inside a physics callback.
func _try_split() -> void:
	if _has_split or _split_generations_left <= 0 or _split_count <= 0:
		return
	_has_split = true
	var parent := get_parent() as Node2D
	var scene := load(scene_file_path) as PackedScene
	if parent == null or scene == null:
		return
	var move := _move()
	var velocity := move.velocity if move != null else Vector2.ZERO
	if velocity.length_squared() < 0.0001:
		velocity = Vector2.UP * 200.0
	var ignored := _ignored_ids.duplicate()
	ignored.merge(_hit_ids)
	for index in _split_count:
		var t := 0.0 if _split_count == 1 else float(index) / float(_split_count - 1) - 0.5
		var direction := velocity.rotated(deg_to_rad(_split_spread_deg * t))
		var fragment := scene.instantiate()
		fragment.call(
			"configure_split_fragment",
			_damage_snapshot,
			_base_damage,
			_split_count,
			_split_generations_left - 1,
			_split_spread_deg,
			ignored,
		)
		var fragment_move := fragment.get_node_or_null("MoveComponent") as MoveComponent
		if fragment_move != null:
			fragment_move.velocity = direction
		fragment.rotation = direction.angle() + PI * 0.5
		fragment.position = parent.to_local(global_position)
		parent.add_child.call_deferred(fragment)


func _start_ricochet(exclude: Node) -> void:
	var move := _move()
	var hitbox := _hitbox()
	var best: Node2D = null
	var best_dist := _ricochet_radius * _ricochet_radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy == exclude:
			continue
		if _hit_ids.has(enemy.get_instance_id()):
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	if best == null:
		queue_free()
		return
	var direction := global_position.direction_to(best.global_position)
	if direction.length_squared() < 0.0001:
		direction = Vector2.UP
	var speed := 200.0
	if move != null:
		speed = maxf(1.0, move.velocity.length())
		move.velocity = direction.normalized() * speed
	rotation = direction.angle() + PI * 0.5
	if hitbox != null:
		hitbox.set_deferred("monitoring", false)
		get_tree().create_timer(0.03, false).timeout.connect(_reenable_hitbox, CONNECT_ONE_SHOT)


func _reenable_hitbox() -> void:
	var hitbox := _hitbox()
	if is_instance_valid(self) and hitbox != null:
		hitbox.monitoring = true


func _enemy_from_hurtbox(hurtbox: HurtboxComponent) -> Node:
	var node: Node = hurtbox
	while node != null:
		if node.is_in_group("enemies"):
			return node
		node = node.get_parent()
	return hurtbox.get_parent()
