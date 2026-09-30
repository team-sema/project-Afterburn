class_name TimeWarpRule
extends Node2D

## Prismatic rule: enemy bullets inside `radius` of the ship move at
## `bullet_speed_mult` until they leave; the ship moves at `move_speed_mult`.

const HANDLE := &"rule_time_warp"
const FIELD_COLOR := Color(0.55, 0.7, 1.0, 1.0)

@export var radius := 50.0
@export var bullet_speed_mult := 0.5
@export var move_speed_mult := 0.8

var _field: BulletSlowField


func install(ship: Node2D, _loadout: PlayerWeaponLoadout) -> void:
	var applier := ship.get_node_or_null("PlayerAugmentApplier") as PlayerAugmentApplier
	applier.set_rule_move_speed_multiplier(applier.rule_move_speed_multiplier * move_speed_mult)
	name = "TimeWarpRule"
	ship.add_child(self)


func _ready() -> void:
	_field = BulletSlowField.new(HANDLE, bullet_speed_mult)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var world := get_tree().get_first_node_in_group("gameplay_world")
	if world != null:
		_field.update(world, global_position, radius)


func get_slowed_count() -> int:
	return _field.get_count() if _field != null else 0


func _exit_tree() -> void:
	if _field != null:
		_field.release()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(FIELD_COLOR, 0.04))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(FIELD_COLOR, 0.3), 1.0)
