class_name TargetMarkComponent
extends Node2D

## Homing missile "표적 지정" prism mark. Lives as a child of the marked Enemy;
## every player weapon multiplies its hit damage by `damage_multiplier` while
## the mark lasts (WeaponSystem.get_target_damage_multiplier). Time counts in
## _process, so the mark freezes while the tree is paused.

const NODE_NAME := &"TargetMark"
const COLOR := Color(1.0, 0.3, 0.85, 0.9)
const BRACKET_RADIUS := 11.0
const BRACKET_LENGTH := 5.0
const SPIN_SPEED := 1.6
const BLINK_TIME := 1.0

var damage_multiplier := 1.0
var remaining := 0.0


## Marks `enemy` (or refreshes an existing mark) for `duration` seconds.
static func apply_to(enemy: Node2D, duration: float, multiplier: float) -> TargetMarkComponent:
	if enemy == null or not is_instance_valid(enemy) or duration <= 0.0:
		return null
	var mark := enemy.get_node_or_null(NodePath(NODE_NAME)) as TargetMarkComponent
	if mark == null:
		mark = TargetMarkComponent.new()
		mark.name = NODE_NAME
		enemy.add_child(mark)
	mark.remaining = maxf(mark.remaining, duration)
	mark.damage_multiplier = maxf(mark.damage_multiplier, multiplier)
	mark.queue_redraw()
	return mark


static func get_mark(enemy: Node) -> TargetMarkComponent:
	if enemy == null or not is_instance_valid(enemy):
		return null
	var mark := enemy.get_node_or_null(NodePath(NODE_NAME)) as TargetMarkComponent
	if mark == null or mark.is_queued_for_deletion() or mark.remaining <= 0.0:
		return null
	return mark


static func is_marked(enemy: Node) -> bool:
	return get_mark(enemy) != null


static func get_multiplier(enemy: Node) -> float:
	var mark := get_mark(enemy)
	return mark.damage_multiplier if mark != null else 1.0


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	rotation += SPIN_SPEED * delta
	queue_redraw()


func _draw() -> void:
	var color := COLOR
	if remaining < BLINK_TIME and fmod(remaining, 0.2) < 0.1:
		color.a *= 0.35
	for corner in 4:
		var angle := TAU * (float(corner) / 4.0) + PI * 0.25
		var tip := Vector2.from_angle(angle) * BRACKET_RADIUS
		var side_a := Vector2.from_angle(angle + PI * 0.75) * BRACKET_LENGTH
		var side_b := Vector2.from_angle(angle - PI * 0.75) * BRACKET_LENGTH
		draw_line(tip, tip + side_a, color, 1.0, true)
		draw_line(tip, tip + side_b, color, 1.0, true)
