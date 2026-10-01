extends Node2D
## RECYCLER wreckage: casing plates, gears, ram rods and sparks. Every piece falls, spins and fades out.

const Neon = preload("res://labs/bosses/wall/wall_visual.gd")
const STRUCTURE := Neon.STRUCTURE

enum Kind { PLATE, GEAR, ROD, SPARK }
var kind := Kind.PLATE
var velocity := Vector2.ZERO
var spin := 0.0
var age := 0.0
var size := 6.0
var lifetime := 2.2
var polygon := PackedVector2Array()


static func spawn(parent: Node2D, origin: Vector2, piece_kind: int, piece_size: float) -> Node2D:
	var piece: Node2D = load("res://labs/bosses/wall/wall_debris.gd").new()
	piece.kind = piece_kind
	piece.size = piece_size
	piece.global_position = origin
	piece.add_to_group("wall_debris")
	parent.add_child(piece)
	return piece


func _ready() -> void:
	if kind == Kind.PLATE:
		for i in 5:
			var angle := TAU * i / 5.0 + randf_range(-0.25, 0.25)
			polygon.append(Vector2.RIGHT.rotated(angle) * size * randf_range(0.7, 1.0))
	if kind == Kind.SPARK:
		lifetime = randf_range(0.3, 0.55)
		velocity = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 150.0)
		return
	velocity = Vector2(randf_range(-70.0, 70.0), randf_range(-40.0, 20.0))
	spin = randf_range(-3.0, 3.0)


func _physics_process(delta: float) -> void:
	age += delta
	if kind == Kind.SPARK:
		velocity += Vector2(0, 260.0) * delta
		position += velocity * delta
		if age >= lifetime: queue_free()
		queue_redraw()
		return
	rotation += spin * delta
	velocity += Vector2(0, 170.0) * delta
	position += velocity * delta
	modulate.a = 1.0 - smoothstep(0.8, lifetime, age)
	if age >= lifetime: queue_free()
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.PLATE:
			Neon.stroke(self, polygon + PackedVector2Array([polygon[0]]), STRUCTURE, 1.0, 0.65)
		Kind.GEAR:
			var teeth := 8
			var outline := PackedVector2Array()
			for i in teeth:
				var step := TAU / teeth
				var start := step * i
				outline.append(Vector2.RIGHT.rotated(start) * size * 0.72)
				outline.append(Vector2.RIGHT.rotated(start + step * 0.15) * size)
				outline.append(Vector2.RIGHT.rotated(start + step * 0.45) * size)
				outline.append(Vector2.RIGHT.rotated(start + step * 0.6) * size * 0.72)
			Neon.stroke(self, outline + PackedVector2Array([outline[0]]), STRUCTURE, 0.8, 0.6)
		Kind.ROD:
			Neon.line(self, Vector2(-size, 0), Vector2(size, 0), STRUCTURE, 1.5, 0.7)
			Neon.line(self, Vector2(-size, -size * 0.3), Vector2(-size, size * 0.3), STRUCTURE, 1.2, 0.55)
		Kind.SPARK:
			var fade := 1.0 - age / lifetime
			draw_line(Vector2.ZERO, -velocity.normalized() * size, Color(2.0, 1.1, 2.6, fade), 1.2, true)
