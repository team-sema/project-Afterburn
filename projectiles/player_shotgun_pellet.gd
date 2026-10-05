extends Node2D

@export var impact_profile: ImpactProfile = preload("res://effects/impact_profiles/shotgun.tres")

@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var flash_component: FlashComponent = $FlashComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent

var _damage_snapshot: Dictionary = {}
var _base_damage := 1
var _origin := Vector2.ZERO
var _max_lifetime := 1.27
var _close_damage_mult := 1.0
var _close_range_px := 80.0
var _age := 0.0
var _pending_configure := false
## Slug prism: one shot carrying the volley's damage, piercing on overkill.
var _is_slug := false
## Share of the slug's damage left after the enemies it killed.
var _slug_damage_scale := 1.0
var _slug_hit_ids: Dictionary = {}
var _slug_bulk := 1.0
## Slug sprite -> authored scale before bulk/wear.
var _slug_sprites: Dictionary = {}

const SLUG_TEXTURE := preload("res://assets/player/player_slug.svg")
const SLUG_CORE_SCALE := Vector2(0.2, 0.2)
const SLUG_TIGHT_SCALE := Vector2(0.26, 0.26)
const SLUG_WIDE_SCALE := Vector2(0.4, 0.4)
const SLUG_MAX_BULK := 1.6
## Slugs ignore the pellet lifetime and free on leaving the screen; this only
## catches a slug that never leaves (e.g. no viewport).
const SLUG_SAFETY_LIFETIME := 10.0
## Glow flicker of the hot shell (Hz) and its alpha swing.
const SLUG_FLICKER_HZ := 6.0
const SLUG_FLICKER_ALPHA := 0.18


func configure_shotgun_combat(
	weapon: WeaponSystem,
	base_damage: int,
	origin: Vector2,
	max_lifetime: float,
	close_damage_mult: float,
	close_range_px: float,
) -> void:
	_damage_snapshot = weapon.get_projectile_damage_snapshot() if weapon != null else {}
	_base_damage = maxi(1, base_damage)
	_origin = origin
	_max_lifetime = maxf(0.05, max_lifetime)
	_close_damage_mult = maxf(1.0, close_damage_mult)
	_close_range_px = maxf(1.0, close_range_px)
	_pending_configure = true
	if is_node_ready():
		_apply_damage_resolver()


## `pellets` is how many pellets the slug compresses; more pellets draw a bulkier shell.
func configure_slug(size_mult: float, pellets: int = 5) -> void:
	_is_slug = true
	scale = Vector2.ONE * maxf(0.1, size_mult)
	_slug_bulk = clampf(sqrt(float(maxi(1, pellets)) / 5.0), 1.0, SLUG_MAX_BULK)


func is_slug() -> bool:
	return _is_slug


func get_slug_visual_scale() -> float:
	return _slug_bulk * _slug_wear()


func _ready() -> void:
	if _is_slug:
		_build_slug_visual()
	scale_component.tween_scale()
	flash_component.flash()
	hitbox_component.hit_hurtbox.connect(_on_hit_hurtbox)
	if _is_slug:
		hitbox_component.hit_filter = func(hurtbox: HurtboxComponent) -> bool:
			return not _slug_hit_ids.has(hurtbox.get_instance_id())
	if _pending_configure:
		_apply_damage_resolver()


## Restyles the pellet into a white-hot shell with a heavy flame trail.
func _build_slug_visual() -> void:
	var visual := $Sprite2D as Node2D
	var core := visual.get_node("Core") as Sprite2D
	var tight := visual.get_node("TightGlow") as Sprite2D
	var wide := visual.get_node("WideGlow") as Sprite2D
	for sprite in [core, tight, wide]:
		(sprite as Sprite2D).texture = SLUG_TEXTURE
	core.self_modulate = Color(1.0, 0.97, 0.86, 1.0)
	tight.self_modulate = Color(1.0, 0.62, 0.18, 0.8)
	wide.self_modulate = Color(1.0, 0.42, 0.08, 0.34)
	_slug_sprites = {core: SLUG_CORE_SCALE, tight: SLUG_TIGHT_SCALE, wide: SLUG_WIDE_SCALE}
	_apply_slug_sprite_scale()

	var trail := visual.get_node("Trail") as GPUParticles2D
	var process := (trail.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.95, 0.75, 0.95),
		Color(1.0, 0.55, 0.1, 0.6),
		Color(0.9, 0.2, 0.02, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	process.spread = 12.0
	process.initial_velocity_min = 14.0
	process.initial_velocity_max = 30.0
	process.scale_min = 0.3 * _slug_bulk
	process.scale_max = 0.5 * _slug_bulk
	trail.process_material = process
	trail.amount = 48
	trail.lifetime = 0.36
	trail.position = Vector2(0.0, 4.0)
	trail.visibility_rect = Rect2(-12.0, -12.0, 24.0, 40.0)


## Kills that eat into the slug's damage shrink it toward 55% of full size.
func _slug_wear() -> float:
	return lerpf(0.55, 1.0, sqrt(clampf(_slug_damage_scale, 0.0, 1.0)))


func _apply_slug_sprite_scale() -> void:
	var size := get_slug_visual_scale()
	for sprite in _slug_sprites:
		(sprite as Sprite2D).scale = (_slug_sprites[sprite] as Vector2) * size


func _on_hit_hurtbox(hurtbox: HurtboxComponent) -> void:
	if _is_slug and _continue_slug_after(hurtbox):
		ImpactVfx.emit_from(self, global_position, impact_profile, ImpactVfx.against_travel(self), 0.6)
		_apply_slug_sprite_scale()
		return
	ImpactVfx.emit_from(self, global_position, impact_profile, ImpactVfx.against_travel(self))
	queue_free()


## Runs before the hit lands, so the enemy's health is still the pre-hit value.
## The slug keeps flying only when this hit kills, carrying the overkill share.
func _continue_slug_after(hurtbox: HurtboxComponent) -> bool:
	_slug_hit_ids[hurtbox.get_instance_id()] = true
	if hurtbox.blocks_pierce:
		return false
	var enemy := WeaponSystem.find_enemy(hurtbox)
	if enemy == null or enemy.stats_component == null:
		return false
	var health_before := enemy.stats_component.health
	var dealt := float(_hitbox().damage) * float(hurtbox.get_meta("incoming_damage_scale", 1.0))
	if dealt <= 0.0 or dealt < float(health_before):
		return false
	_slug_damage_scale *= (dealt - float(health_before)) / dealt
	return float(_base_damage) * _slug_damage_scale >= 1.0


func _process(delta: float) -> void:
	_age += delta
	# Slugs fly until they leave the screen; the cap only guards a stuck shot.
	if _age >= (SLUG_SAFETY_LIFETIME if _is_slug else _max_lifetime):
		queue_free()
		return
	if _is_slug:
		var tight := $Sprite2D/TightGlow as Sprite2D
		tight.self_modulate.a = 0.8 - SLUG_FLICKER_ALPHA * (0.5 + 0.5 * sin(_age * TAU * SLUG_FLICKER_HZ))


func _hitbox() -> HitboxComponent:
	if hitbox_component != null:
		return hitbox_component
	return get_node_or_null("HitboxComponent") as HitboxComponent


func _apply_damage_resolver() -> void:
	var hitbox := _hitbox()
	if hitbox == null:
		return
	hitbox.damage_resolver = func(hurtbox: HurtboxComponent) -> int:
		var mult := _slug_damage_scale
		if _close_damage_mult > 1.0 and global_position.distance_to(_origin) <= _close_range_px:
			mult *= _close_damage_mult
		var raw := maxi(1, roundi(float(_base_damage) * mult))
		return WeaponSystem.resolve_projectile_snapshot_damage(raw, hurtbox, _damage_snapshot)
	hitbox.damage = _base_damage
	_pending_configure = false
