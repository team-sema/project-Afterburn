class_name ExperienceCollectorComponent
extends Area2D

const EXPERIENCE_COLLECTOR_LAYER := 1 << 4

@export_range(1.0, 160.0, 1.0) var collection_radius := 36.0:
	set(value):
		collection_radius = maxf(1.0, value)
		if is_node_ready():
			_update_collision_radius()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("experience_collector")
	collision_layer = EXPERIENCE_COLLECTOR_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	_update_collision_radius()


func _update_collision_radius() -> void:
	var circle := collision_shape.shape as CircleShape2D
	assert(circle != null, "ExperienceCollectorComponent requires a CircleShape2D.")
	circle.radius = collection_radius
