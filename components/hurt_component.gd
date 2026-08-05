# Give the component a class name so it can be instanced as a custom node
class_name HurtComponent
extends Node

# Grab the stats so we can alter the health
@export var stats_component: StatsComponent

# Grab a hurtbox so we know when we have taken a hiet
@export var hurtbox_component: HurtboxComponent

# Optional shield buffer HP in front of hull health.
@export var shield_component: ShieldComponent

## Optional facility combat buffs (emergency on hull damage).
@export var combat_buff_controller: ShipCombatBuffController
## Facility registry for HULL_HIT_IFRAMES duration.
@export var facility_registry: PlayerAugmentRegistry
## Optional flash feedback while iframes are active.
@export var flash_component: FlashComponent

var _iframe_timer: Timer


func _ready() -> void:
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
		if actor != null and actor.is_in_group("player"):
			incoming = 1
		var remaining := incoming
		# Any hit resets shield charge; shield absorbs first like buffer HP.
		if shield_component != null:
			shield_component.notify_hit()
			remaining = shield_component.absorb_damage(remaining)
		if remaining <= 0:
			return
		stats_component.health -= remaining
		_on_hull_damaged()
	)


func _on_hull_damaged() -> void:
	if combat_buff_controller != null:
		combat_buff_controller.notify_hull_damage()
	_try_apply_iframes()


func _try_apply_iframes() -> void:
	if hurtbox_component == null:
		return
	# Do not refresh if already invincible.
	if hurtbox_component.is_invincible:
		return
	var duration := _get_iframe_duration()
	if duration <= 0.0:
		return
	hurtbox_component.is_invincible = true
	if flash_component != null:
		flash_component.flash()
	_iframe_timer.start(duration)


func _get_iframe_duration() -> float:
	var registry := facility_registry
	if registry == null:
		var ship := get_parent()
		if ship != null:
			registry = ship.get("augment_registry") as PlayerAugmentRegistry
	if registry == null:
		return 0.0
	if not registry.has_module_effect_kind(FacilityModuleEffect.Kind.HULL_HIT_IFRAMES):
		return 0.0
	var first := registry.get_first_module_effect(FacilityModuleEffect.Kind.HULL_HIT_IFRAMES)
	return maxf(0.0, first.primary) if first != null else 0.0


func _on_iframe_timeout() -> void:
	if hurtbox_component != null:
		hurtbox_component.is_invincible = false
