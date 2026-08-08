class_name MoveComponent
extends Node

@export var actor: Node2D
@export var velocity := Vector2.ZERO
@export var modifier_component: MoveModifierComponent
@export var velocity_multiplier := 1.0


func _ready() -> void:
	assert(actor != null, "MoveComponent requires an actor.")
	if modifier_component == null:
		modifier_component = actor.get_node_or_null("MoveModifierComponent") as MoveModifierComponent


func _process(delta: float) -> void:
	_apply_velocity(velocity, delta)


func apply_movement_intent(intent: MovementIntent, delta: float) -> void:
	assert(intent != null and intent.is_valid, "MoveComponent requires a valid MovementIntent.")
	velocity = intent.velocity
	if intent.has_global_position:
		if modifier_component != null:
			modifier_component.advance(delta)
		actor.global_position = intent.global_position + get_modifier_offset()
		return
	_apply_velocity(intent.velocity, delta)


func stop_motion() -> void:
	velocity = Vector2.ZERO
	set_process(false)


func resume_legacy_motion() -> void:
	set_process(true)


func get_modifier_component() -> MoveModifierComponent:
	return modifier_component


func get_modifier_offset() -> Vector2:
	return modifier_component.get_offset() if modifier_component != null else Vector2.ZERO


func _apply_velocity(target_velocity: Vector2, delta: float) -> void:
	if actor == null or not is_instance_valid(actor):
		push_error("MoveComponent cannot move because its actor is missing.")
		set_process(false)
		return
	var motion := target_velocity * delta * velocity_multiplier
	if modifier_component != null:
		motion += modifier_component.advance(delta)
	actor.translate(motion)
