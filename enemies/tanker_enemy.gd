class_name TankerEnemy
extends Enemy

signal shield_destroyed

@export_range(1, 1000, 1) var body_max_hp := 35
@export_range(1, 5000, 1) var shield_max_hp := 1000
## Evolved Tanker: an intact shield refills after shield_regen_delay seconds
## without a shield hit. A broken shield never comes back.
@export_range(0.0, 2000.0, 1.0, "suffix:hp/s") var shield_regen_per_second := 0.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var shield_regen_delay := 2.0

@onready var shield: Node2D = $Shield
@onready var shield_visual: Node2D = $Shield/Visual
@onready var shield_core: Sprite2D = $Shield/Visual/Core
@onready var shield_stats: StatsComponent = $Shield/StatsComponent
@onready var shield_hurtbox: HurtboxComponent = $Shield/HurtboxComponent
@onready var shield_flash: FlashComponent = $Shield/FlashComponent
@onready var shield_scale: ScaleComponent = $Shield/ScaleComponent
@onready var shield_break_spawner: SpawnerComponent = $Shield/BreakEffectSpawner

var _shield_destroyed := false
var _shield_regen_cap := 0
var _since_shield_hit := 0.0
var _shield_regen_carry := 0.0
var _last_shield_health := 0


func _enter_tree() -> void:
	# Parent _enter_tree runs before child component _ready callbacks, so Inspector
	# values become the modifier factory's base values instead of overwriting its
	# results afterward.
	(get_node("StatsComponent") as StatsComponent).health = body_max_hp
	(get_node("Shield/StatsComponent") as StatsComponent).health = shield_max_hp
	# Tanker is a mobile shield wall only — no projectiles.
	var shoot := get_node_or_null("EnemyShootComponent")
	if shoot != null:
		shoot.free()


func _ready() -> void:
	super._ready()
	shield_hurtbox.hurt.connect(_on_shield_hurt)
	shield_stats.health_changed.connect(_update_shield_damage_visual)
	shield_stats.no_health.connect(_destroy_shield)
	stats_component.no_health.connect(_cleanup_shield_for_body_death)
	# Children are ready first, so this cap already includes HEALTH augments.
	_shield_regen_cap = shield_stats.health
	_last_shield_health = shield_stats.health
	shield_stats.health_changed.connect(_on_shield_health_changed)
	set_process(shield_regen_per_second > 0.0)
	_update_shield_damage_visual()


func _process(delta: float) -> void:
	if _shield_destroyed or shield_stats.health >= _shield_regen_cap:
		_shield_regen_carry = 0.0
		return
	_since_shield_hit += delta
	if _since_shield_hit < shield_regen_delay:
		return
	_shield_regen_carry += shield_regen_per_second * delta
	var amount := int(_shield_regen_carry)
	if amount <= 0:
		return
	_shield_regen_carry -= amount
	shield_stats.health = mini(_shield_regen_cap, shield_stats.health + amount)


func is_shield_active() -> bool:
	return not _shield_destroyed


func get_body_health() -> int:
	return stats_component.health


func get_shield_health() -> int:
	return shield_stats.health


func _on_shield_health_changed() -> void:
	# Any shield damage, from any weapon path, restarts the regen delay.
	if shield_stats.health < _last_shield_health:
		_since_shield_hit = 0.0
		_shield_regen_carry = 0.0
	_last_shield_health = shield_stats.health


func _on_shield_hurt(_hitbox: HitboxComponent) -> void:
	if _shield_destroyed:
		return
	# Soft read: flash + tiny scale. No shake — large shield Visual made even small
	# ShakeComponent offsets read as heavy thrash, and scale was the real punch.
	shield_scale.tween_scale()
	shield_flash.flash()
	hit_sound_player.play_with_variance()


func _update_shield_damage_visual() -> void:
	if _shield_destroyed or shield_core == null:
		return
	var ratio := clampf(float(shield_stats.health) / float(maxi(1, shield_max_hp)), 0.0, 1.0)
	# A simple stepped fade reads at game scale and avoids a dedicated shader/HP bar.
	var alpha := 1.0
	if ratio <= 0.25:
		alpha = 0.42
	elif ratio <= 0.5:
		alpha = 0.62
	elif ratio <= 0.75:
		alpha = 0.82
	for child in shield_visual.get_children():
		var item := child as CanvasItem
		if item != null:
			var color := item.self_modulate
			color.a = alpha
			item.self_modulate = color


func _destroy_shield() -> void:
	if _shield_destroyed:
		return
	_shield_destroyed = true
	shield_hurtbox.is_invincible = true
	shield_hurtbox.set_deferred("monitorable", false)
	shield_visual.hide()
	if shield_break_spawner != null and shield_break_spawner.scene != null:
		var effect := shield_break_spawner.spawn(shield_hurtbox.global_position)
		if effect.has_method("set_effect_color"):
			effect.call("set_effect_color", Color(0.72, 0.92, 1.0, 1.0))
	shield_destroyed.emit()


func _cleanup_shield_for_body_death() -> void:
	# The Shield remains owned by this Enemy, but disable it immediately while the
	# common death path queues the Tanker root for deletion.
	if shield_hurtbox != null:
		shield_hurtbox.is_invincible = true
		shield_hurtbox.set_deferred("monitorable", false)
	if shield_visual != null:
		shield_visual.hide()
	_shield_destroyed = true
