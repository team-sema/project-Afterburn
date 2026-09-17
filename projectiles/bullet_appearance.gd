class_name BulletAppearance
extends Resource

enum Form { ROUND, RICE, TEXTURED }

@export var form: Form = Form.ROUND
@export var core_size := Vector2(8, 8)
@export var collision_radius := 3.0
@export var collision_height := 6.0
@export var tint := Color(1.0, 0.22, 0.52)
@export var texture: Texture2D
@export var wide_size := Vector2(5.28, 14.08)
@export var tight_size := Vector2(3.36, 8.96)
@export var wide_color := Color(1, 0.18, 0.58, 0.12)
@export var tight_color := Color(1, 0.22, 0.62, 0.38)
@export var core_color := Color(1, 0.94, 0.98)
@export var collision_size := Vector2(4, 8)
@export var collision_offset := Vector2.ZERO


func is_valid() -> bool:
	return (
		form in [Form.ROUND, Form.RICE, Form.TEXTURED]
		and collision_offset.is_finite()
		and (form != Form.TEXTURED or (texture != null and collision_size.is_finite() and collision_size.x > 0 and collision_size.y > 0 and wide_size.is_finite() and tight_size.is_finite() and wide_size.x > 0 and wide_size.y > 0 and tight_size.x > 0 and tight_size.y > 0))
		and core_size.is_finite() and core_size.x > 0 and core_size.y > 0
		and is_finite(collision_radius) and collision_radius > 0
		and is_finite(collision_height) and collision_height >= collision_radius * 2
	)


func make_shape() -> Shape2D:
	if form == Form.TEXTURED:
		var rectangle := RectangleShape2D.new()
		rectangle.size = collision_size
		return rectangle
	if form == Form.RICE:
		var capsule := CapsuleShape2D.new()
		capsule.radius = collision_radius
		capsule.height = collision_height
		return capsule
	var circle := CircleShape2D.new()
	circle.radius = collision_radius
	return circle


func bounding_radius() -> float:
	if form == Form.TEXTURED: return collision_size.length() * 0.5 + collision_offset.length()
	return (collision_height * 0.5 if form == Form.RICE else collision_radius) + collision_offset.length()

func render_key() -> String:
	if form == Form.TEXTURED:
		return str(form, ":", texture.get_rid(), core_size, wide_size, tight_size, wide_color, tight_color, core_color)
	return str(form, ":", core_size)

func visual_extent() -> float:
	var size := core_size
	if form == Form.TEXTURED: size = size.max(wide_size).max(tight_size)
	return maxf(size.x, size.y)
