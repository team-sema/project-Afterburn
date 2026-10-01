extends Node2D
## Lens beam: a straight laser along local +y (rotate the node to aim). Warns with a dashed guide, then cuts.

enum State { OFF, WARN, ON }
const HIT_WIDTH := 6.0

var state := State.OFF
var length := 420.0
var age := 0.0
var hitbox: HitboxComponent
var shape: CollisionShape2D


func _ready() -> void:
	hitbox = HitboxComponent.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	hitbox.damage = 1
	shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.disabled = true
	hitbox.add_child(shape)
	add_child(hitbox)
	set_length(length)


func set_length(value: float) -> void:
	length = maxf(value, 1.0)
	if shape != null:
		(shape.shape as RectangleShape2D).size = Vector2(HIT_WIDTH, length)
		shape.position.y = length * 0.5
	queue_redraw()


func set_state(value: State) -> void:
	state = value
	if shape != null:
		shape.set_deferred("disabled", state != State.ON)
	visible = state != State.OFF
	queue_redraw()


func is_blocking() -> bool:
	return state == State.ON


func _physics_process(delta: float) -> void:
	age += delta
	if state != State.OFF: queue_redraw()


func _draw() -> void:
	match state:
		State.WARN:
			var alpha := 0.45 + 0.4 * float(int(age * 14.0) % 2)
			var y := fmod(age * 90.0, 12.0) - 12.0
			while y < length:
				draw_line(Vector2(0, maxf(y, 0.0)), Vector2(0, minf(y + 7.0, length)), Color(1.4, 0.2, 0.22, alpha), 1.0)
				y += 12.0
			draw_circle(Vector2.ZERO, 2.0 + 1.5 * alpha, Color(1.6, 0.3, 0.3, alpha))
		State.ON:
			var flicker := 0.85 + 0.15 * sin(age * 40.0)
			draw_rect(Rect2(-7, 0, 14, length), Color(1.0, 0.1, 0.14, 0.16 * flicker))
			draw_rect(Rect2(-3.5, 0, 7, length), Color(1.8, 0.25, 0.28, 0.6 * flicker))
			draw_rect(Rect2(-1.2, 0, 2.4, length), Color(3.0, 2.0, 1.8))
			draw_circle(Vector2.ZERO, 4.5, Color(2.6, 1.2, 1.0, 0.9))
