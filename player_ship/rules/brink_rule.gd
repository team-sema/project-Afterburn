class_name BrinkRule
extends Node2D

## Prismatic rule: when the shield drops from 1+ to 0, every enemy bullet on
## screen, and any that appears during the next `duration` seconds, moves at
## `bullet_speed_mult` for the rest of that window. Shield charge speed is
## multiplied by `charge_speed_mult` for the whole run.

signal triggered

const HANDLE := &"rule_brink"
const WAVE_COLOR := Color(0.45, 0.75, 1.0, 1.0)
const WAVE_MAX_RADIUS := 420.0

@export var duration := 2.0
@export var bullet_speed_mult := 0.2
@export var charge_speed_mult := 0.5

var _shield: ShieldComponent
var _last_shield := 0
## Gameplay seconds left in the slow window.
var _left := 0.0


func install(ship: Node2D, _loadout: PlayerWeaponLoadout) -> void:
	_shield = ship.get_node_or_null("ShieldComponent") as ShieldComponent
	_shield.set_rule_charge_speed_multiplier(_shield.rule_charge_speed_multiplier * charge_speed_mult)
	name = "BrinkRule"
	ship.add_child(self)


func _ready() -> void:
	_last_shield = _shield.get_current_shield()
	_shield.shield_changed.connect(_on_shield_changed)


func is_active() -> bool:
	return _left > 0.0


func get_time_left() -> float:
	return _left


## Starts (or restarts) the slow window and slows every bullet now on screen.
func trigger() -> void:
	_left = duration
	var world := _world()
	if world != null:
		for bullet in EnemyBullets.get_all(world):
			EnemyBullets.apply_effect(bullet, HANDLE, bullet_speed_mult, 0.0, _left)
	triggered.emit()
	queue_redraw()


func _on_shield_changed(current: int, _max_shield: int) -> void:
	if current <= 0 and _last_shield > 0:
		trigger()
	_last_shield = current


func _physics_process(delta: float) -> void:
	if _left <= 0.0:
		return
	var world := _world()
	if world != null:
		# Bullets fired during the window get the slow for what is left of it.
		for bullet in EnemyBullets.get_all(world):
			if EnemyBullets.get_effect(bullet, HANDLE).is_empty():
				EnemyBullets.apply_effect(bullet, HANDLE, bullet_speed_mult, 0.0, _left)
	_left = maxf(0.0, _left - delta)
	queue_redraw()


func _world() -> Node:
	return get_tree().get_first_node_in_group("gameplay_world")


func _draw() -> void:
	if _left <= 0.0:
		return
	var progress := 1.0 - _left / duration
	var fade := _left / duration
	draw_arc(Vector2.ZERO, WAVE_MAX_RADIUS * progress, 0.0, TAU, 96, Color(WAVE_COLOR, 0.6 * fade), 2.0)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, Color(WAVE_COLOR, 0.5 * fade), 1.0)
