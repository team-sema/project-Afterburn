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
@export var slot_selection_ui: WeaponSlotSelectionOverlay
@export var ship: Node2D
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
	assert(slot_selection_ui != null, "AugmentOfferController requires a WeaponSlotSelectionOverlay.")
	assert(ship != null, "AugmentOfferController requires a Ship reference.")
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
	var player_choices := _pick_player_choices()
	if player_choices.is_empty():
		push_error("AugmentOfferController: no valid player augment choices.")
		is_offer_active = false
		get_tree().paused = false
		return
	await selection_ui.open_choices(
		"아군 강화",
		"업그레이드를 하나 고르세요",
		player_choices,
		selection_ui.player_accent_color,
	)


func _get_loadout() -> PlayerWeaponLoadout:
	if ship != null and ship.has_method("get_weapon_loadout"):
		return ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	return null


func _pick_player_choices() -> Array[PlayerAugment]:
	var loadout := _get_loadout()
	var valid: Array[PlayerAugment] = []
	for augment in player_augment_pool:
		if _is_player_augment_available(augment, loadout):
			valid.append(augment)
	valid.shuffle()
	if valid.size() > choices_per_offer:
		valid.resize(choices_per_offer)
	return valid


func _pick_enemy_choices() -> Array[EnemyAugment]:
	var choices := enemy_augment_pool.duplicate()
	choices.shuffle()
	choices.resize(choices_per_offer)
	return choices


func _is_player_augment_available(augment: PlayerAugment, loadout: PlayerWeaponLoadout) -> bool:
	if augment == null:
		return false
	match augment.augment_type:
		PlayerAugmentKind.Kind.STAT_MULTIPLIER:
			return true
		PlayerAugmentKind.Kind.UPGRADE_MAIN_SLOT:
			return loadout != null and loadout.get_main_slot().can_upgrade()
		PlayerAugmentKind.Kind.UPGRADE_AUXILIARY_SLOT:
			return loadout != null and loadout.has_upgradable_auxiliary_slot()
		_:
			# Weapon grant / unlock cards are not offered — weapons come from drops.
			return false
	return false


func _on_choice_selected(choice: Resource) -> void:
	match phase:
		Phase.PLAYER:
			var player_augment := choice as PlayerAugment
			assert(player_augment != null, "Player phase requires a PlayerAugment choice.")
			selected_player_augment = player_augment
			await _resolve_player_augment(player_augment)
			phase = Phase.ENEMY
			await selection_ui.transition_choices(
				"적 강화",
				"다음 위협을 고르세요",
				enemy_choices,
				selection_ui.enemy_accent_color,
			)
		Phase.ENEMY:
			var enemy_augment := choice as EnemyAugment
			assert(enemy_augment != null, "Enemy phase requires an EnemyAugment choice.")
			enemy_registry.add_augment(enemy_augment)
			await _finish_offer(enemy_augment)


func _resolve_player_augment(player_augment: PlayerAugment) -> void:
	var loadout := _get_loadout()
	var applier := ship.get_node_or_null("PlayerAugmentApplier") as PlayerAugmentApplier
	assert(applier != null, "Ship missing PlayerAugmentApplier.")

	if player_augment.augment_type == PlayerAugmentKind.Kind.UPGRADE_AUXILIARY_SLOT:
		selection_ui.hide_choices()
		slot_selection_ui.open_for_upgrade(
			loadout,
			"보조 오버클럭",
			"강화할 보조 슬롯을 고르세요",
		)
		var upgrade_index: int = await slot_selection_ui.slot_selected
		applier.set_pending_auxiliary_slot(upgrade_index)
		selection_ui.visible = true

	player_registry.add_augment(player_augment)


func _finish_offer(enemy_augment: EnemyAugment) -> void:
	await selection_ui.close_with_result(selected_player_augment, enemy_augment)
	is_offer_active = false
	get_tree().paused = false
	offer_completed.emit(selected_player_augment, enemy_augment)


func _exit_tree() -> void:
	if is_offer_active:
		get_tree().paused = false
