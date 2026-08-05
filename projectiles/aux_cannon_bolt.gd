extends Node2D

const ENEMY_HURTBOX_MASK := 1 << 1

@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var flash_component: FlashComponent = $FlashComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent

var _weapon: WeaponSystem
var _base_damage := 1
var _pierce_remaining := 0
var _pierce_falloff := 1.0
var _pierce_hits := 0
var _aoe_radius := 0.0
var _aoe_mult := 1.0
var _size_mult := 1.0
var _pending_configure := false


func configure_aux_combat(
	weapon: WeaponSystem,
	base_damage: int,
	pierce_bonus: int,
	pierce_falloff: float,
	size_mult: float,
	aoe_radius: float,
	aoe_mult: float,
) -> void:
	_weapon = weapon
	_base_damage = maxi(1, base_damage)
	_pierce_remaining = maxi(0, pierce_bonus)
	_pierce_falloff = clampf(pierce_falloff, 0.05, 1.0)
	_size_mult = maxf(0.1, size_mult)
	_aoe_radius = maxf(0.0, aoe_radius)
	_aoe_mult = maxf(0.0, aoe_mult)
	_pending_configure = true
	if is_node_ready():
		_finish_configure()


func _ready() -> void:
	scale_component.tween_scale()
	flash_component.flash()
	hitbox_component.hit_hurtbox.connect(_on_hit_hurtbox)
	if _pending_configure or _weapon != null:
		_finish_configure()


func _finish_configure() -> void:
	scale = Vector2.ONE * _size_mult
	_apply_damage_resolver()
	_pending_configure = false


func _hitbox() -> HitboxComponent:
	if hitbox_component != null:
		return hitbox_component
	return get_node_or_null("HitboxComponent") as HitboxComponent


func _apply_damage_resolver() -> void:
	var hitbox := _hitbox()
	if hitbox == null:
		return
	hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
		var scale := 1.0
		if _pierce_hits > 0:
			scale *= pow(_pierce_falloff, float(_pierce_hits))
		var raw := maxi(1, roundi(float(_base_damage) * scale))
		if _weapon != null:
			return _weapon.resolve_hit_damage(raw, hurtbox)
		return raw
	hitbox.damage = _base_damage


func _on_hit_hurtbox(hurtbox: HurtboxComponent) -> void:
	if _aoe_radius > 0.0:
		_deal_aoe(hurtbox)

	if _pierce_remaining > 0:
		_pierce_remaining -= 1
		_pierce_hits += 1
		_apply_damage_resolver()
		return

	queue_free()


func _deal_aoe(exclude_hurtbox: HurtboxComponent) -> void:
	var world := get_world_2d()
	if world == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = _aoe_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var aoe_damage := maxi(1, roundi(float(_base_damage) * _aoe_mult))
	var hitbox := HitboxComponent.new()
	for result in world.direct_space_state.intersect_shape(query, 64):
		var collider: Variant = result.get("collider")
		if not collider is HurtboxComponent:
			continue
		var other := collider as HurtboxComponent
		if other == exclude_hurtbox or other.is_invincible:
			continue
		if _weapon != null:
			hitbox.damage = _weapon.resolve_hit_damage(aoe_damage, other)
		else:
			hitbox.damage = aoe_damage
		other.hurt.emit(hitbox)
	hitbox.free()
