class_name FreeOffscreenComponent
extends VisibleOnScreenNotifier2D

const DEFAULT_MOVEMENT_SPACE: MovementSpaceConfig = preload(
	"res://resources/enemy_movement/default_movement_space.tres"
)

@export var actor: Node2D
## Projectiles retain their legacy screen-exit lifetime. Enemy scenes opt into
## the wider DespawnArea so leaving the camera is not equivalent to despawning.
@export var use_despawn_area := false
@export var movement_space_config: MovementSpaceConfig = DEFAULT_MOVEMENT_SPACE
@export_range(0.0, 256.0, 1.0) var actor_extent_padding := 16.0

var _despawn_suspended := false


func _ready() -> void:
	assert(actor != null, "FreeOffscreenComponent requires an actor.")
	assert(
		movement_space_config != null and movement_space_config.validate(),
		"FreeOffscreenComponent requires a valid MovementSpaceConfig.",
	)
	if use_despawn_area:
		set_process(true)
	else:
		set_process(false)
		screen_exited.connect(actor.queue_free)


func _process(_delta: float) -> void:
	if _despawn_suspended or actor == null or not is_instance_valid(actor):
		return
	var visible_rect := actor.get_viewport_rect()
	var despawn_area := movement_space_config.get_despawn_area(visible_rect).grow(
		actor_extent_padding
	)
	if not despawn_area.has_point(actor.global_position):
		actor.queue_free()
		set_process(false)


func suspend_despawn() -> void:
	_despawn_suspended = true
