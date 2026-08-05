extends Node2D

@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var flash_component: FlashComponent = $FlashComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var move_component: MoveComponent = $MoveComponent

var _weapon: WeaponSystem
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


func configure_blaster_combat(
	weapon: WeaponSystem,
	base_damage: int,
	pierce_bonus: int,
	pierce_falloff: float,
	max_bounces: int,
	bounce_damage_mults: Array,
	ricochet_radius: float,
) -> void:
	_weapon = weapon
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


func _ready() -> void:
	scale_component.tween_scale()
	flash_component.flash()
	hitbox_component.hit_hurtbox.connect(_on_hit_hurtbox)
	if _pending_configure or _weapon != null:
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
		var scale := _bounce_damage_scale
		if _pierce_hits > 0:
			scale *= pow(_pierce_falloff, float(_pierce_hits))
		var raw := maxi(1, roundi(float(_base_damage) * scale))
		if _weapon != null:
			return _weapon.resolve_hit_damage(raw, hurtbox)
		return raw
	hitbox.damage = maxi(1, roundi(float(_base_damage) * _bounce_damage_scale))
	_pending_configure = false


func _on_hit_hurtbox(hurtbox: HurtboxComponent) -> void:
	var target := _enemy_from_hurtbox(hurtbox)
	if target != null:
		_hit_ids[target.get_instance_id()] = true

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
		get_tree().create_timer(0.03).timeout.connect(_reenable_hitbox, CONNECT_ONE_SHOT)


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
