class_name ArmorPlateComponent
extends Node2D

## Ignores the enemy's first hits and outlines the hurtbox while armor remains.

@export_range(1, 10, 1) var armor_hits := 1
@export var outline_color := Color(0.72, 0.84, 1.0, 0.75)
@export_range(0.5, 4.0, 0.5) var outline_width := 1.0
@export_range(0.0, 8.0, 0.5) var outline_padding := 3.0
@export_range(2.0, 64.0, 0.5) var fallback_radius := 10.0

var enemy: Enemy
var hurt_component: HurtComponent
var _radius := 10.0


func _ready() -> void:
	enemy = get_parent() as Enemy
	assert(enemy != null, "ArmorPlateComponent must be attached directly to an Enemy.")
	# One absorbed hit is noise on an elite or boss health pool; ordinary enemies only.
	if enemy.is_elite or enemy.is_boss:
		queue_free()
		return
	hurt_component = enemy.get_node("HurtComponent") as HurtComponent
	assert(hurt_component != null, "ArmorPlateComponent requires HurtComponent.")
	hurt_component.armor_hits += armor_hits
	hurt_component.armor_absorbed.connect(_on_armor_absorbed)
	_radius = _resolve_radius() + outline_padding
	queue_redraw()


func _on_armor_absorbed(remaining_hits: int) -> void:
	if remaining_hits <= 0:
		visible = false


func _draw() -> void:
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 24, outline_color, outline_width, true)


func _resolve_radius() -> float:
	var hurtbox := enemy.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox == null:
		return fallback_radius
	for child in hurtbox.get_children():
		var collision := child as CollisionShape2D
		if collision == null or collision.shape == null:
			continue
		var offset := collision.position.length()
		if collision.shape is CircleShape2D:
			return (collision.shape as CircleShape2D).radius + offset
		if collision.shape is RectangleShape2D:
			return (collision.shape as RectangleShape2D).size.length() * 0.5 + offset
	return fallback_radius
