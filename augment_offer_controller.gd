class_name AugmentOfferController
extends Node

const AUGMENT_RESUME_BURST_SCENE := preload("res://effects/augment_resume_burst.tscn")

signal offer_started(offer_type: OfferType)
signal offer_completed(offer_type: OfferType)

enum OfferType {
	PLAYER,
	ENEMY,
}

@export var player_registry: PlayerAugmentRegistry
@export var enemy_registry: EnemyAugmentRegistry
@export var selection_ui: AugmentSelectionOverlay
@export var slot_selection_ui: WeaponSlotSelectionOverlay
@export var module_swap_ui: AugmentModuleSwapOverlay
@export var ship: Node2D
@export var player_augment_pool: Array[PlayerAugment] = []
@export var enemy_augment_pool: Array[EnemyAugment] = []
@export_range(1, 3, 1) var choices_per_offer := 3
@export_range(8.0, 120.0, 1.0) var player_resume_clear_radius := 36.0

var is_offer_active := false
var active_offer_type := OfferType.PLAYER


func _ready() -> void:
	assert(player_registry != null, "AugmentOfferController requires a PlayerAugmentRegistry.")
	assert(enemy_registry != null, "AugmentOfferController requires an EnemyAugmentRegistry.")
	assert(selection_ui != null, "AugmentOfferController requires an AugmentSelectionOverlay.")
	assert(slot_selection_ui != null, "AugmentOfferController requires a WeaponSlotSelectionOverlay.")
	assert(module_swap_ui != null, "AugmentOfferController requires an AugmentModuleSwapOverlay.")
	assert(ship != null, "AugmentOfferController requires a Ship reference.")
	assert(enemy_augment_pool.size() >= choices_per_offer, "Enemy augment pool is too small for an offer.")
	selection_ui.configure_player_registry(player_registry)
	selection_ui.choice_selected.connect(_on_choice_selected)
	selection_ui.facility_expansion_selected.connect(_on_facility_expansion_selected)


func request_offer(offer_type: OfferType) -> bool:
	if is_offer_active:
		return false
	is_offer_active = true
	active_offer_type = offer_type
	offer_started.emit(active_offer_type)
	_start_offer.call_deferred()
	return true


func _start_offer() -> void:
	await get_tree().process_frame
	if not is_offer_active or not is_inside_tree():
		return
	get_tree().paused = true
	var choices: Array
	var title: String
	var prompt: String
	var accent_color: Color
	var show_ship_modules := false
	if active_offer_type == OfferType.PLAYER:
		choices = _pick_player_choices()
		title = "함선 모듈"
		prompt = "모듈을 장착하거나 함선 부위의 슬롯을 확장하세요"
		accent_color = selection_ui.player_accent_color
		show_ship_modules = true
	else:
		choices = _pick_enemy_choices()
		title = "적 강화"
		prompt = "다음 위협을 고르세요"
		accent_color = selection_ui.enemy_accent_color

	if choices.is_empty():
		push_error("AugmentOfferController: no valid augment choices.")
		is_offer_active = false
		get_tree().paused = false
		return
	await selection_ui.open_choices(title, prompt, choices, accent_color, show_ship_modules)


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
	if augment == null or not player_registry.has_facility(augment.facility_id):
		return false
	match augment.augment_type:
		PlayerAugmentKind.Kind.UPGRADE_MAIN_WEAPON:
			return loadout != null and loadout.can_upgrade_equipped_main_weapon()
		PlayerAugmentKind.Kind.UPGRADE_AUXILIARY_WEAPON:
			return loadout != null and loadout.has_upgradable_auxiliary_weapon()
		PlayerAugmentKind.Kind.STAT_MULTIPLIER, PlayerAugmentKind.Kind.FACILITY_EFFECT:
			return true
		_:
			return false


func _on_choice_selected(choice: Resource) -> void:
	match active_offer_type:
		OfferType.PLAYER:
			var player_augment := choice as PlayerAugment
			assert(player_augment != null, "Player offer requires a PlayerAugment choice.")
			if not await _resolve_player_augment(player_augment):
				selection_ui.resume_choices()
				return
			await _finish_offer(player_augment)
		OfferType.ENEMY:
			var enemy_augment := choice as EnemyAugment
			assert(enemy_augment != null, "Enemy offer requires an EnemyAugment choice.")
			enemy_registry.add_augment(enemy_augment)
			await _finish_offer(enemy_augment)


func _resolve_player_augment(player_augment: PlayerAugment) -> bool:
	var target_weapon_id := &""
	var loadout := _get_loadout()
	if player_augment.augment_type == PlayerAugmentKind.Kind.UPGRADE_MAIN_WEAPON:
		var main_slot := loadout.get_main_slot()
		target_weapon_id = main_slot.equipped_weapon_id
	elif player_augment.augment_type == PlayerAugmentKind.Kind.UPGRADE_AUXILIARY_WEAPON:
		selection_ui.suspend_choices()
		slot_selection_ui.open_for_weapon_upgrade(
			loadout,
			"보조무기 모듈",
			"효과를 연결할 보조무기를 고르세요",
		)
		var weapon_slot_index: int = await slot_selection_ui.slot_selected
		target_weapon_id = loadout.get_auxiliary_slot(weapon_slot_index).equipped_weapon_id

	var replace_index := -1
	if not player_registry.has_empty_slot(player_augment.facility_id):
		selection_ui.suspend_choices()
		module_swap_ui.open(player_registry, player_augment.facility_id, player_augment)
		replace_index = await module_swap_ui.selection_finished
		if replace_index < 0:
			return false

	var installed_index := player_registry.install_augment(
		player_augment,
		target_weapon_id,
		replace_index,
	)
	if installed_index < 0:
		return false
	selection_ui.restore_for_result()
	return true


func _on_facility_expansion_selected(facility_id: StringName) -> void:
	if active_offer_type != OfferType.PLAYER:
		return
	if not player_registry.expand_slots(facility_id):
		selection_ui.resume_choices()
		return
	var definition := player_registry.get_facility_definition(facility_id)
	var facility_name := definition.display_name if definition != null else String(facility_id)
	await selection_ui.close_with_text(
		"슬롯 확장",
		"%s 슬롯 %d/%d" % [
			facility_name,
			player_registry.get_slot_capacity(facility_id),
			PlayerAugmentRegistry.MAX_SLOT_CAPACITY,
		],
		selection_ui.player_accent_color,
	)
	_complete_offer(OfferType.PLAYER)


func _finish_offer(augment: Resource) -> void:
	var result_title := "모듈 장착 완료" if active_offer_type == OfferType.PLAYER else "적 위협 강화"
	var accent_color := (
		selection_ui.player_accent_color
		if active_offer_type == OfferType.PLAYER
		else selection_ui.enemy_accent_color
	)
	await selection_ui.close_with_result(result_title, augment, accent_color)
	_complete_offer(active_offer_type)


func _complete_offer(completed_offer_type: OfferType) -> void:
	is_offer_active = false
	if completed_offer_type == OfferType.PLAYER:
		_trigger_player_resume_burst()
	get_tree().paused = false
	offer_completed.emit(completed_offer_type)


func _trigger_player_resume_burst() -> int:
	if not is_instance_valid(ship):
		return 0
	var gameplay_world := get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if gameplay_world == null:
		return 0
	var burst := AUGMENT_RESUME_BURST_SCENE.instantiate() as Node2D
	burst.call("setup", player_resume_clear_radius, selection_ui.player_accent_color)
	gameplay_world.add_child(burst)
	burst.global_position = ship.global_position

	var clear_radius_squared := player_resume_clear_radius * player_resume_clear_radius
	var cleared_count := 0
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if not projectile is Node2D or not is_instance_valid(projectile):
			continue
		var projectile_node := projectile as Node2D
		if ship.global_position.distance_squared_to(projectile_node.global_position) > clear_radius_squared:
			continue
		projectile_node.queue_free()
		cleared_count += 1
	return cleared_count


func _exit_tree() -> void:
	if is_offer_active:
		get_tree().paused = false
