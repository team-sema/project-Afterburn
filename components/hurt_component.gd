# Give the component a class name so it can be instanced as a custom node
class_name HurtComponent
extends Node

signal invincibility_started(duration: float)
signal invincibility_ended
signal armor_absorbed(remaining_hits: int)
## Graded by the shield left *after* the hit (see docs/design/player.md).
enum HitSeverity {
	ABSORBED, ## Shield took it and at least one point remains.
	SHIELD_BROKEN, ## Shield took it and is now empty: the next hit kills.
	LETHAL, ## No shield left; the hull took the damage.
}

## Player-only hit grade, emitted after the shield has absorbed what it can.
## `impact_direction` points from the attacker's hitbox through the hit point
## (the way the blow pushes); it is UP when the hitbox has no usable position.
signal player_hit(severity: HitSeverity, hit_position: Vector2, impact_direction: Vector2)

# Grab the stats so we can alter the health
@export var stats_component: StatsComponent

# Grab a hurtbox so we know when we have taken a hiet
@export var hurtbox_component: HurtboxComponent

## Short protection after any hit. Player config sets this; enemies leave it at zero.
@export_range(0.0, 5.0, 0.05) var base_iframe_duration := 0.0
@export_range(0.05, 1.0, 0.05) var invincible_alpha := 0.45
@export var invincibility_visual: CanvasItem

# Optional shield buffer HP in front of hull health.
@export var shield_component: ShieldComponent

## Optional facility combat buffs (emergency on hull damage).
@export var combat_buff_controller: ShipCombatBuffController
## Facility registry for HULL_HIT_IFRAMES duration.
@export var facility_registry: PlayerAugmentRegistry
## Optional flash feedback while iframes are active.
@export var flash_component: FlashComponent

var _iframe_timer: Timer
## Handles keeping the hurtbox invincible regardless of the iframe timer
## (e.g. standing inside a plasma singularity). Iframes ending never clear a hold.
var _invincibility_holds: Dictionary = {}
var _base_visual_modulate := Color.WHITE
## Whole hits ignored before hull damage (enemy armor plate augment).
var armor_hits := 0


func _ready() -> void:
	if invincibility_visual == null:
		var actor := get_parent()
		if actor != null:
			invincibility_visual = actor.get_node_or_null("Anchor") as CanvasItem
			if invincibility_visual == null:
				invincibility_visual = actor as CanvasItem
	if invincibility_visual != null:
		_base_visual_modulate = invincibility_visual.modulate
	hurtbox_component.invincibility_changed.connect(_on_invincibility_changed)
	_set_invincibility_visual(hurtbox_component.is_invincible)
	_iframe_timer = Timer.new()
	_iframe_timer.one_shot = true
	add_child(_iframe_timer)
	_iframe_timer.timeout.connect(_on_iframe_timeout)

	# Connect the hurt signal on the hurtbox component to an anonymous function
	# that removes health equal to the damage from the hitbox
	hurtbox_component.hurt.connect(func(hitbox_component: HitboxComponent):
		# 플레이어가 받는 피해 이벤트는 항상 1. (적 HurtComponent는 hitbox.damage 그대로)
		var incoming := hitbox_component.damage
		var actor := get_parent()
		var is_player := actor != null and actor.is_in_group("player")
		if is_player:
			incoming = 1
		var remaining := incoming
		# Any hit resets shield charge; shield absorbs first like buffer HP.
		if shield_component != null:
			shield_component.notify_hit()
			remaining = shield_component.absorb_damage(remaining)
		if remaining <= 0:
			_try_apply_iframes(false)
			if is_player:
				var severity := HitSeverity.SHIELD_BROKEN if shield_component.get_current_shield() <= 0 else HitSeverity.ABSORBED
				player_hit.emit(severity, _hit_position(), _impact_direction(hitbox_component))
			return
		if is_player:
			player_hit.emit(HitSeverity.LETHAL, _hit_position(), _impact_direction(hitbox_component))
		if armor_hits > 0:
			armor_hits -= 1
			armor_absorbed.emit(armor_hits)
			return
		var scale := float(hurtbox_component.get_meta("incoming_damage_scale", 1.0))
		if not is_equal_approx(scale, 1.0):
			# Chip-damage parts (e.g. boss wall body) keep at least 1 so hits still read.
			remaining = maxi(1, roundi(float(remaining) * maxf(0.0, scale)))
		stats_component.health -= remaining
		_on_hull_damaged()
	)


func _hit_position() -> Vector2:
	if hurtbox_component != null and hurtbox_component.is_inside_tree():
		return hurtbox_component.global_position
	var actor := get_parent() as Node2D
	return actor.global_position if actor != null and actor.is_inside_tree() else Vector2.ZERO


func _impact_direction(hitbox: Node) -> Vector2:
	var hitbox_2d := hitbox as Node2D
	if hitbox_2d == null or not hitbox_2d.is_inside_tree() or hurtbox_component == null or not hurtbox_component.is_inside_tree():
		return Vector2.UP
	var direction := hurtbox_component.global_position - hitbox_2d.global_position
	if direction.length_squared() < 0.0001:
		return Vector2.UP
	return direction.normalized()


func _on_hull_damaged() -> void:
	if combat_buff_controller != null:
		combat_buff_controller.notify_hull_damage()
	_try_apply_iframes(true)


func _try_apply_iframes(include_facility: bool) -> void:
	if hurtbox_component == null:
		return
	# Do not refresh if already invincible.
	if hurtbox_component.is_invincible:
		return
	var duration := _get_iframe_duration(include_facility)
	if duration <= 0.0:
		return
	start_invincibility(duration)


func start_invincibility(duration: float) -> void:
	if hurtbox_component == null or duration <= 0.0:
		return
	var was_invincible: bool = hurtbox_component.is_invincible
	hurtbox_component.is_invincible = true
	if flash_component != null:
		flash_component.flash()
	_iframe_timer.start(duration)
	if not was_invincible:
		invincibility_started.emit(duration)


func end_invincibility() -> void:
	if hurtbox_component == null or not _invincibility_holds.is_empty():
		return
	hurtbox_component.is_invincible = false


## Keeps the hurtbox invincible while any handle holds it. Releasing the last
## hold ends invincibility unless iframes are still running.
func set_invincibility_hold(handle: StringName, held: bool) -> void:
	if hurtbox_component == null or handle == &"":
		return
	if held:
		_invincibility_holds[handle] = true
		hurtbox_component.is_invincible = true
		return
	if not _invincibility_holds.has(handle):
		return
	_invincibility_holds.erase(handle)
	if _invincibility_holds.is_empty() and (_iframe_timer == null or _iframe_timer.is_stopped()):
		hurtbox_component.is_invincible = false


func is_invincibility_held() -> bool:
	return not _invincibility_holds.is_empty()


func _get_iframe_duration(include_facility: bool) -> float:
	var duration := maxf(0.0, base_iframe_duration)
	if not include_facility:
		return duration
	var registry := facility_registry
	if registry == null:
		var ship := get_parent()
		if ship != null:
			registry = ship.get("augment_registry") as PlayerAugmentRegistry
	if registry == null:
		return duration
	return duration + registry.get_module_effect_sum(FacilityModuleEffect.Kind.HULL_HIT_IFRAMES)


func _on_iframe_timeout() -> void:
	end_invincibility()


func _on_invincibility_changed(enabled: bool) -> void:
	_set_invincibility_visual(enabled)
	if not enabled:
		invincibility_ended.emit()


func _set_invincibility_visual(enabled: bool) -> void:
	if invincibility_visual == null:
		return
	if enabled:
		var translucent := _base_visual_modulate
		translucent.a = _base_visual_modulate.a * invincible_alpha
		invincibility_visual.modulate = translucent
	else:
		invincibility_visual.modulate = _base_visual_modulate
