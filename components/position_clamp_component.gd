# Give the component a class name so it can be instanced as a custom node
class_name PositionClampComponent
extends Node2D

# Export the actor who's position will be clamped
@export var actor: Node2D

## Clearance kept between the actor origin and the boundary. The ship's hit
## point (radius 3) sits on its origin, so 4 keeps the hit point inside while
## the hull artwork may overlap the frame (danmaku-style clamping).
@export var margin: = 4
## false lets the actor sit outside the viewport (launch sequence).
@export var enabled := true
## Enabled only by the main cockpit; labs retain viewport bounds.
@export var cockpit_boundary := false
const CockpitBounds := preload("res://menus/cockpit_geometry.gd")

func _process(_delta: float) -> void:
	if not enabled:
		return
	if cockpit_boundary:
		actor.position = CockpitBounds.clamp_position(actor.position, float(margin))
		return
	var viewport_size := actor.get_viewport_rect().size
	actor.global_position = actor.global_position.clamp(
		Vector2.ONE * margin,
		viewport_size - Vector2.ONE * margin
	)
