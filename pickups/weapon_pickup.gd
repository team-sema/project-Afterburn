class_name WeaponPickup
extends Area2D

signal collected(weapon_definition: WeaponDefinition)

const PLAYER_HURTBOX_LAYER := 1
const EXPERIENCE_COLLECTOR_LAYER := 1 << 4

@export var drift_speed := 12.0
@export var lifetime := 12.0

var weapon_definition: WeaponDefinition
var _collecting := false
var _age := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 0
	collision_mask = PLAYER_HURTBOX_LAYER | EXPERIENCE_COLLECTOR_LAYER
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)


func setup(definition: WeaponDefinition, spawn_position: Vector2) -> void:
	weapon_definition = definition
	global_position = spawn_position
	_refresh_label()


func _process(delta: float) -> void:
	if _collecting:
		return
	_age += delta
	global_position.y += drift_speed * delta
	if _age >= lifetime:
		queue_free()


func _refresh_label() -> void:
	var label := get_node_or_null("Label") as Label
	if label == null or weapon_definition == null:
		return
	label.text = weapon_definition.display_name


func _on_area_entered(area: Area2D) -> void:
	if _collecting or weapon_definition == null:
		return
	if not _is_valid_collector(area):
		return
	_collecting = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	var controller := get_tree().get_first_node_in_group("weapon_acquisition") as WeaponAcquisitionController
	if controller == null:
		push_error("WeaponPickup: no WeaponAcquisitionController in group.")
		_collecting = false
		process_mode = Node.PROCESS_MODE_PAUSABLE
		return
	# Leave the Area2D signal's physics-query flush before adding a weapon scene.
	await get_tree().process_frame
	var consumed := await controller.try_collect(weapon_definition)
	if consumed:
		collected.emit(weapon_definition)
		queue_free()
	else:
		_collecting = false
		process_mode = Node.PROCESS_MODE_PAUSABLE


func _is_valid_collector(area: Area2D) -> bool:
	if area.is_in_group("experience_collector"):
		return true
	# Only the ship's hit-core hurtbox — not orbital-barrier segments on layer 1.
	var parent := area.get_parent()
	return parent != null and parent is PlayerHitPoint
