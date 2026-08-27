# Give the component a class name so it can be instanced as a custom node
class_name FlashComponent
extends Node

# The flash component uses a flash material. I chose to preload this into a constant
# But you could also export a material instead to allow the component to use a variety
# of different materials
const FLASH_MATERIAL = preload("uid://c88q6pkhh3vl")

# Export the sprite this component will be flashing
@export var sprite: CanvasItem

## When set, every direct CanvasItem child (and the root itself if it is a CanvasItem)
## flashes together. Use for multi-layer neon visuals like the Tanker shield.
@export var flash_root: Node

# Export a duration for the flash
@export var flash_duration: = 0.2

# We need to store the original sprite's material so we can reset it after the flash
var original_sprite_material: Material
var _original_materials: Dictionary = {}

# Create a timer for the flash component to use
var timer: Timer = Timer.new()

func _ready() -> void:
	# We have to add the timer as a child of this component in order to use it
	add_child(timer)
	assert(
		sprite != null or flash_root != null,
		"FlashComponent requires sprite and/or flash_root.",
	)
	# Store the original sprite material
	if sprite != null:
		original_sprite_material = sprite.material
	timer.timeout.connect(_restore_materials)

func _collect_targets() -> Array[CanvasItem]:
	var targets: Array[CanvasItem] = []
	if sprite != null:
		targets.append(sprite)
	if flash_root != null:
		if flash_root is CanvasItem:
			var root_item := flash_root as CanvasItem
			if not targets.has(root_item):
				targets.append(root_item)
		for child in flash_root.get_children():
			if child is CanvasItem:
				var item := child as CanvasItem
				if not targets.has(item):
					targets.append(item)
	return targets

# This is the function we can use to activate this component
func flash():
	var targets := _collect_targets()
	if targets.is_empty():
		return

	# A new hit during an active flash only extends the existing flash. Capturing a
	# target's material again here would capture FLASH_MATERIAL as its "original"
	# material and permanently leave the target flashed after rapid hits.
	if _original_materials.is_empty():
		for target in targets:
			_original_materials[target] = target.material
			target.material = FLASH_MATERIAL

	# Restarting this one timer extends the feedback without spawning overlapping
	# await continuations that can restore materials out of order.
	timer.start(flash_duration)


func _restore_materials() -> void:
	for target_key in _original_materials:
		var target := target_key as CanvasItem
		if target != null and is_instance_valid(target):
			target.material = _original_materials[target_key]
	_original_materials.clear()
	# Keep the legacy single-sprite field in sync for older callers.
	if sprite != null and is_instance_valid(sprite):
		original_sprite_material = sprite.material
