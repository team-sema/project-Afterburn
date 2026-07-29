class_name ExperienceOrb
extends Area2D

signal collected(amount: int)

enum CollectionState {
	DRIFTING,
	KNOCKBACK,
	ATTRACTING,
	COLLECTED,
}

const EXPERIENCE_COLLECTOR_LAYER := 1 << 4

@export var drift_speed := 6.0
@export var lifetime := 20.0
@export_range(0.0, 20.0, 0.5) var knockback_distance := 5.0
@export_range(0.01, 1.0, 0.01) var knockback_duration := 0.09
@export_range(1.0, 500.0, 1.0) var initial_attraction_speed := 55.0
@export_range(1.0, 1000.0, 1.0) var attraction_acceleration := 480.0
@export_range(1.0, 1000.0, 1.0) var maximum_attraction_speed := 190.0
@export_range(0.5, 20.0, 0.5) var collection_distance := 3.0

var experience_amount := 1
var _age := 0.0
var _state := CollectionState.DRIFTING
var _collector: Area2D
var _attraction_speed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 0
	collision_mask = EXPERIENCE_COLLECTOR_LAYER
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)


func setup(amount: int, spawn_position: Vector2) -> void:
	experience_amount = amount
	global_position = spawn_position


func _process(delta: float) -> void:
	if _state == CollectionState.COLLECTED:
		return
	match _state:
		CollectionState.DRIFTING:
			_process_drift(delta)
		CollectionState.ATTRACTING:
			_process_attraction(delta)


func _process_drift(delta: float) -> void:
	_age += delta
	global_position.y += drift_speed * delta
	if _age >= lifetime:
		queue_free()


func _process_attraction(delta: float) -> void:
	if not is_instance_valid(_collector):
		_collector = null
		_state = CollectionState.DRIFTING
		return
	_attraction_speed = move_toward(
		_attraction_speed,
		maximum_attraction_speed,
		attraction_acceleration * delta,
	)
	global_position = global_position.move_toward(
		_collector.global_position,
		_attraction_speed * delta,
	)
	if global_position.distance_to(_collector.global_position) <= collection_distance:
		_collect()


func _on_area_entered(area: Area2D) -> void:
	if _state != CollectionState.DRIFTING or not area.is_in_group("experience_collector"):
		return
	_collector = area
	_state = CollectionState.KNOCKBACK
	var away_direction := area.global_position.direction_to(global_position)
	if away_direction.is_zero_approx():
		away_direction = Vector2.RIGHT.rotated(randf() * TAU)
	var knockback_target := global_position + away_direction * knockback_distance
	var tween := create_tween()
	tween.tween_property(self, "global_position", knockback_target, knockback_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if not is_instance_valid(_collector):
		_collector = null
		_state = CollectionState.DRIFTING
		return
	_attraction_speed = initial_attraction_speed
	_state = CollectionState.ATTRACTING


func _collect() -> void:
	var progression := get_tree().get_first_node_in_group("augment_progression")
	if progression == null:
		push_error("ExperienceOrb: no AugmentProgressionController in group.")
		return
	_state = CollectionState.COLLECTED
	progression.add_experience(experience_amount)
	collected.emit(experience_amount)
	queue_free()
