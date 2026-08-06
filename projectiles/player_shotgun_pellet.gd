extends Node2D

@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var flash_component: FlashComponent = $FlashComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent

var _weapon: WeaponSystem
var _base_damage := 1
var _origin := Vector2.ZERO
var _max_lifetime := 1.27
var _close_damage_mult := 1.0
var _close_range_px := 80.0
var _age := 0.0
var _pending_configure := false


func configure_shotgun_combat(
	weapon: WeaponSystem,
	base_damage: int,
	origin: Vector2,
	max_lifetime: float,
	close_damage_mult: float,
	close_range_px: float,
) -> void:
	_weapon = weapon
	_base_damage = maxi(1, base_damage)
	_origin = origin
	_max_lifetime = maxf(0.05, max_lifetime)
	_close_damage_mult = maxf(1.0, close_damage_mult)
	_close_range_px = maxf(1.0, close_range_px)
	_pending_configure = true
	if is_node_ready():
		_apply_damage_resolver()


func _ready() -> void:
	scale_component.tween_scale()
	flash_component.flash()
	hitbox_component.hit_hurtbox.connect(queue_free.unbind(1))
	if _pending_configure or _weapon != null:
		_apply_damage_resolver()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _max_lifetime:
		queue_free()


func _hitbox() -> HitboxComponent:
	if hitbox_component != null:
		return hitbox_component
	return get_node_or_null("HitboxComponent") as HitboxComponent


func _apply_damage_resolver() -> void:
	var hitbox := _hitbox()
	if hitbox == null:
		return
	hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
		var mult := 1.0
		if _close_damage_mult > 1.0 and global_position.distance_to(_origin) <= _close_range_px:
			mult = _close_damage_mult
		var raw := maxi(1, roundi(float(_base_damage) * mult))
		if _weapon != null:
			return _weapon.resolve_hit_damage(raw, hurtbox)
		return raw
	hitbox.damage = _base_damage
	_pending_configure = false
