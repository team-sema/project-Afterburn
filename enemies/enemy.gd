class_name Enemy
extends Node2D

enum MovementMode {
	INDIVIDUAL,
	FORMATION_MEMBER,
}

var augment_registry: EnemyAugmentRegistry
var spawn_id: StringName
var movement_mode := MovementMode.INDIVIDUAL
var _formation_controller: Node
var _formation_slot: FormationSlot
var _formation_intent := MovementIntent.new()

## When true, boss-damage facility modules apply extra multiplier via WeaponSystem.resolve_hit_damage.
@export var is_boss := false:
	set(value):
		is_boss = value
		if not is_inside_tree():
			return
		if value:
			add_to_group("bosses")
		elif is_in_group("bosses"):
			remove_from_group("bosses")

@onready var stats_component: StatsComponent = $StatsComponent
@onready var move_component: MoveComponent = $MoveComponent
@onready var movement_controller: MovementController = $MovementController
@onready var scale_component: ScaleComponent = $ScaleComponent
@onready var flash_component: FlashComponent = $FlashComponent
@onready var shake_component: ShakeComponent = $ShakeComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var hurt_component: HurtComponent = $HurtComponent
@onready var score_component: ScoreComponent = $ScoreComponent
@onready var hit_sound_player: VariablePitchAudioStreamPlayer = $HitSoundPlayer

func _ready() -> void:
	add_to_group("enemies")
	if is_boss:
		add_to_group("bosses")
	stats_component.no_health.connect(func():
		score_component.adjust_score()
	)
	
	hurtbox_component.hurt.connect(func(hitbox: HitboxComponent):
		scale_component.tween_scale()
		flash_component.flash()
		shake_component.tween_shake()
		hit_sound_player.play_with_variance()
	)
	stats_component.no_health.connect(func():
		movement_controller.stop()
		queue_free()
	)


func set_movement_sequence(
	new_sequence: MovementSequence,
	context: Dictionary = {},
	start_immediately := true,
) -> void:
	# EnemyGenerator configures instances before add_child(), so avoid relying on
	# the @onready reference here.
	var controller := get_node_or_null("MovementController") as MovementController
	assert(controller != null, "Enemy requires MovementController for a MovementSequence.")
	controller.set_sequence(new_sequence, context)
	if start_immediately:
		controller.start()


func enter_formation_mode(controller: Node, slot: FormationSlot) -> void:
	assert(controller != null, "Enemy formation mode requires a controller.")
	assert(slot != null, "Enemy formation mode requires a FormationSlot.")
	var controller_node := get_node("MovementController") as MovementController
	controller_node.stop()
	movement_mode = MovementMode.FORMATION_MEMBER
	_formation_controller = controller
	_formation_slot = slot


func apply_formation_target(
	target_global_position: Vector2,
	delta: float,
	target_rotation: float = 0.0,
) -> void:
	if movement_mode != MovementMode.FORMATION_MEMBER:
		return
	if _formation_controller == null or not is_instance_valid(_formation_controller):
		return
	_formation_intent.reset()
	_formation_intent.set_global_position(target_global_position)
	(get_node("MoveComponent") as MoveComponent).apply_movement_intent(
		_formation_intent,
		delta,
	)
	rotation = target_rotation


func exit_formation_mode(
	individual_sequence: MovementSequence,
	context: Dictionary = {},
) -> void:
	if movement_mode != MovementMode.FORMATION_MEMBER:
		return
	movement_mode = MovementMode.INDIVIDUAL
	_formation_controller = null
	_formation_slot = null
	var controller_node := get_node("MovementController") as MovementController
	if individual_sequence == null:
		controller_node.clear_sequence()
		return
	controller_node.set_sequence(individual_sequence, context)
	# FormationController can release during its own process callback. Starting
	# deferred guarantees the formation and individual paths never move in the
	# same frame and captures the preserved post-reparent global position.
	controller_node.request_deferred_start()


func is_formation_member() -> bool:
	return movement_mode == MovementMode.FORMATION_MEMBER


func get_formation_slot() -> FormationSlot:
	return _formation_slot


## Enemy-owned behaviors use this generic request when their independent state
## should take over. FormationController decides only whether this member is
## still bound; it does not inspect the enemy type or behavior.
func detach_from_formation() -> bool:
	if movement_mode != MovementMode.FORMATION_MEMBER:
		return false
	if _formation_controller == null or not is_instance_valid(_formation_controller):
		return false
	if not _formation_controller.has_method("detach_member"):
		return false
	return bool(_formation_controller.call("detach_member", self))
