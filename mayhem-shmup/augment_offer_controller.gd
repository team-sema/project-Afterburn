class_name AugmentOfferController
extends Node

signal offer_started
signal offer_completed(player_augment: PlayerAugment, enemy_augment: EnemyAugment)

enum Phase {
	PLAYER,
	ENEMY,
}

@export var player_registry: PlayerAugmentRegistry
@export var enemy_registry: EnemyAugmentRegistry
@export var selection_ui: AugmentSelectionOverlay
@export var player_augment_pool: Array[PlayerAugment] = []
@export var enemy_augment_pool: Array[EnemyAugment] = []
@export_range(1, 3, 1) var choices_per_offer := 3

var is_offer_active := false
var phase := Phase.PLAYER
var selected_player_augment: PlayerAugment
var enemy_choices: Array[EnemyAugment] = []


func _ready() -> void:
	assert(player_registry != null, "AugmentOfferController requires a PlayerAugmentRegistry.")
	assert(enemy_registry != null, "AugmentOfferController requires an EnemyAugmentRegistry.")
	assert(selection_ui != null, "AugmentOfferController requires an AugmentSelectionOverlay.")
	assert(player_augment_pool.size() >= choices_per_offer, "Player augment pool is too small for an offer.")
	assert(enemy_augment_pool.size() >= choices_per_offer, "Enemy augment pool is too small for an offer.")
	selection_ui.choice_selected.connect(_on_choice_selected)


func request_offer() -> bool:
	if is_offer_active:
		return false

	is_offer_active = true
	phase = Phase.PLAYER
	selected_player_augment = null
	enemy_choices = _pick_enemy_choices()
	offer_started.emit()
	_start_offer.call_deferred()
	return true


func _start_offer() -> void:
	await get_tree().process_frame
	if not is_offer_active or not is_inside_tree():
		return
	get_tree().paused = true
	await selection_ui.open_choices(
		"PLAYER AUGMENT",
		"Choose one upgrade",
		_pick_player_choices(),
		selection_ui.player_accent_color,
	)


func _pick_player_choices() -> Array[PlayerAugment]:
	var choices := player_augment_pool.duplicate()
	choices.shuffle()
	choices.resize(choices_per_offer)
	return choices


func _pick_enemy_choices() -> Array[EnemyAugment]:
	var choices := enemy_augment_pool.duplicate()
	choices.shuffle()
	choices.resize(choices_per_offer)
	return choices


func _on_choice_selected(choice: Resource) -> void:
	match phase:
		Phase.PLAYER:
			var player_augment := choice as PlayerAugment
			assert(player_augment != null, "Player phase requires a PlayerAugment choice.")
			selected_player_augment = player_augment
			player_registry.add_augment(player_augment)
			phase = Phase.ENEMY
			await selection_ui.transition_choices(
				"ENEMY AUGMENT",
				"Choose the next threat",
				enemy_choices,
				selection_ui.enemy_accent_color,
			)
		Phase.ENEMY:
			var enemy_augment := choice as EnemyAugment
			assert(enemy_augment != null, "Enemy phase requires an EnemyAugment choice.")
			enemy_registry.add_augment(enemy_augment)
			await _finish_offer(enemy_augment)


func _finish_offer(enemy_augment: EnemyAugment) -> void:
	await selection_ui.close_with_result(selected_player_augment, enemy_augment)
	is_offer_active = false
	get_tree().paused = false
	offer_completed.emit(selected_player_augment, enemy_augment)


func _exit_tree() -> void:
	if is_offer_active:
		get_tree().paused = false
