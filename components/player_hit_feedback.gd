class_name PlayerHitFeedback
extends Node

## Turns HurtComponent.player_hit into the in-field feedback for the two hit
## grades: ship flash, shield-coloured impact VFX, the playfield edge warning
## and the hit point pulse while the shield is empty. Cockpit panel shake and
## the shield arc react on their own from the same signal / shield events.
## Rules and numbers: docs/design/player.md「피격 연출」.

const FLASH_ABSORBED := 0.12
const FLASH_BROKEN := 0.22
const STRENGTH_ABSORBED := 1.0
const STRENGTH_BROKEN := 1.6
const RING_ABSORBED := 14.0
const RING_BROKEN := 24.0
const PULSE_PERIOD := 0.8
const PULSE_MIN := 1.0
const PULSE_MAX := 1.6

@export var hurt_component: HurtComponent
@export var shield_component: ShieldComponent
@export var flash_component: FlashComponent
@export var hit_point: PlayerHitPoint
@export var impact_profile: ImpactProfile = preload("res://effects/impact_profiles/player_shield.tres")

var _core: PlayerHitPointCore
var _core_fill := Color.WHITE
var _pulsing := false
var _pulse_elapsed := 0.0
var _last_shield := -1
var _last_severity := -1


func _ready() -> void:
	set_process(false)
	if hit_point != null:
		_core = hit_point.get_node_or_null("Visual/Core") as PlayerHitPointCore
		if _core != null:
			_core_fill = _core.fill_color
	if hurt_component != null:
		hurt_component.player_hit.connect(_on_player_hit)
	if shield_component != null:
		shield_component.shield_changed.connect(_on_shield_changed)
		_last_shield = shield_component.get_current_shield()
		if _last_shield <= 0:
			_set_pulsing(true)
			var warning := _warning()
			if warning != null:
				warning.start(false)


func get_last_severity() -> int:
	return _last_severity


func is_pulsing() -> bool:
	return _pulsing


func _on_player_hit(severity: int, hit_position: Vector2, impact_direction: Vector2) -> void:
	_last_severity = severity
	if severity == HurtComponent.HitSeverity.LETHAL:
		return
	var broken := severity == HurtComponent.HitSeverity.SHIELD_BROKEN
	if flash_component != null:
		flash_component.flash_duration = FLASH_BROKEN if broken else FLASH_ABSORBED
		flash_component.flash()
	var owner_node := get_parent()
	if owner_node != null and impact_profile != null:
		ImpactVfx.emit_from(
			owner_node,
			hit_position,
			impact_profile,
			impact_direction,
			STRENGTH_BROKEN if broken else STRENGTH_ABSORBED,
			RING_BROKEN if broken else RING_ABSORBED,
		)
	if broken:
		var warning := _warning()
		if warning != null:
			warning.start(true)


func _on_shield_changed(current: int, _maximum: int) -> void:
	if current <= 0 and _last_shield > 0:
		_set_pulsing(true)
	elif current > 0 and _last_shield <= 0:
		_set_pulsing(false)
		var warning := _warning()
		if warning != null:
			warning.stop()
	_last_shield = current


func _set_pulsing(enabled: bool) -> void:
	if _pulsing == enabled:
		return
	_pulsing = enabled
	_pulse_elapsed = 0.0
	set_process(enabled)
	if not enabled:
		_apply_pulse(PULSE_MIN)


func _process(delta: float) -> void:
	_pulse_elapsed = fmod(_pulse_elapsed + delta, PULSE_PERIOD)
	_apply_pulse(lerpf(PULSE_MIN, PULSE_MAX, 0.5 - 0.5 * cos(TAU * _pulse_elapsed / PULSE_PERIOD)))


func _apply_pulse(brightness: float) -> void:
	if _core == null or not is_instance_valid(_core):
		return
	var next := Color(_core_fill.r * brightness, _core_fill.g * brightness, _core_fill.b * brightness, _core_fill.a)
	if next != _core.fill_color:
		_core.fill_color = next


func _warning() -> PlayfieldDamageWarning:
	if not is_inside_tree():
		return null
	return PlayfieldDamageWarning.get_or_create(self)


func _exit_tree() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var host := tree.get_first_node_in_group(PlayfieldDamageWarning.GAMEPLAY_WORLD_GROUP)
	if host == null:
		return
	var warning := host.get_node_or_null(NodePath(PlayfieldDamageWarning.NODE_NAME)) as PlayfieldDamageWarning
	if warning != null:
		warning.stop()
