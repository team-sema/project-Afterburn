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
@export var module_swap_ui: AugmentModuleSwapOverlay
@export var weapon_slot_ui: WeaponSlotSelectionOverlay
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
	assert(module_swap_ui != null, "AugmentOfferController requires an AugmentModuleSwapOverlay.")
	assert(ship != null, "AugmentOfferController requires a Ship reference.")
	assert(enemy_augment_pool.size() >= choices_per_offer, "Enemy augment pool is too small for an offer.")
	selection_ui.configure_player_registry(player_registry)
	selection_ui.configure_weapon_loadout(_get_loadout())
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
		selection_ui.configure_weapon_loadout(_get_loadout())
		choices = _pick_player_choices()
		title = "함선 모듈"
		prompt = "무기·특성·시설 모듈을 선택하거나 함선 부위의 슬롯을 확장하세요"
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
	return _pick_weighted(valid, choices_per_offer)


func _pick_enemy_choices() -> Array[EnemyAugment]:
	var choices := enemy_augment_pool.duplicate()
	choices.shuffle()
	choices.resize(choices_per_offer)
	return choices


func _pick_weighted(pool: Array[PlayerAugment], count: int) -> Array[PlayerAugment]:
	var remaining: Array[PlayerAugment] = pool.duplicate()
	var picked: Array[PlayerAugment] = []
	while not remaining.is_empty() and picked.size() < count:
		var total := 0.0
		for augment in remaining:
			total += maxf(0.0, augment.offer_weight)
		if total <= 0.0:
			remaining.shuffle()
			while not remaining.is_empty() and picked.size() < count:
				picked.append(remaining.pop_back())
			break
		var roll := randf() * total
		var cursor := 0.0
		var chosen_index := remaining.size() - 1
		for index in remaining.size():
			cursor += maxf(0.0, remaining[index].offer_weight)
			if roll <= cursor:
				chosen_index = index
				break
		picked.append(remaining[chosen_index])
		remaining.remove_at(chosen_index)
	return picked


func _is_player_augment_available(augment: PlayerAugment, loadout: PlayerWeaponLoadout) -> bool:
	if augment == null:
		return false
	match augment.augment_type:
		PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
			if loadout == null or augment.weapon_definition == null:
				return false
			var weapon_id := augment.get_weapon_id()
			# Already equipped → use WEAPON_LEVEL cards instead.
			return not loadout.is_weapon_equipped(weapon_id)
		PlayerAugmentKind.Kind.WEAPON_LEVEL:
			if loadout == null:
				return false
			var weapon_id := augment.get_weapon_id()
			if weapon_id == &"" or not loadout.has_weapon_progress(weapon_id):
				return false
			return loadout.can_upgrade_weapon(weapon_id)
		PlayerAugmentKind.Kind.WEAPON_TRAIT:
			if loadout == null or augment.trait_id == &"":
				return false
			if augment.target_weapon_id != &"":
				return loadout.is_weapon_equipped(augment.target_weapon_id)
			return not loadout.get_equipped_weapon_ids().is_empty()
		PlayerAugmentKind.Kind.STAT_MULTIPLIER, PlayerAugmentKind.Kind.FACILITY_EFFECT:
			return augment.facility_id != &"" and player_registry.has_facility(augment.facility_id)
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
	var loadout := _get_loadout()
	match player_augment.augment_type:
		PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
			return await _resolve_weapon_acquire(player_augment, loadout)
		PlayerAugmentKind.Kind.WEAPON_LEVEL:
			return _resolve_weapon_level(player_augment, loadout)
		PlayerAugmentKind.Kind.WEAPON_TRAIT:
			return _resolve_weapon_trait(player_augment, loadout)
		PlayerAugmentKind.Kind.STAT_MULTIPLIER, PlayerAugmentKind.Kind.FACILITY_EFFECT:
			return await _resolve_facility_module(player_augment)
		_:
			return false


func _resolve_weapon_acquire(player_augment: PlayerAugment, loadout: PlayerWeaponLoadout) -> bool:
	if loadout == null or player_augment.weapon_definition == null:
		return false
	var definition := player_augment.weapon_definition
	var starting_level := player_augment.starting_weapon_level
	if loadout.offer_equip_weapon(definition, starting_level):
		selection_ui.restore_for_result()
		return true
	if weapon_slot_ui == null:
		push_error("AugmentOfferController: weapon_slot_ui required when bays are full.")
		return false
	selection_ui.suspend_choices()
	weapon_slot_ui.open_for_replace(
		loadout,
		"무기 교체",
		"%s 을(를) 장착할 베이를 선택하세요" % definition.display_name,
		definition,
	)
	var slot_index: int = await weapon_slot_ui.selection_finished
	if slot_index < 0:
		return false
	if not loadout.request_replace_equipped(slot_index, definition, starting_level):
		return false
	selection_ui.restore_for_result()
	return true


func _resolve_weapon_level(player_augment: PlayerAugment, loadout: PlayerWeaponLoadout) -> bool:
	if loadout == null:
		return false
	var weapon_id := player_augment.get_weapon_id()
	if not loadout.upgrade_weapon_level(weapon_id):
		return false
	selection_ui.restore_for_result()
	return true


func _resolve_weapon_trait(player_augment: PlayerAugment, loadout: PlayerWeaponLoadout) -> bool:
	if loadout == null:
		return false
	var target_weapon_id := player_augment.target_weapon_id
	if target_weapon_id == &"":
		var equipped := loadout.get_equipped_weapon_ids()
		if equipped.is_empty():
			return false
		target_weapon_id = equipped[0]
	elif not loadout.is_weapon_equipped(target_weapon_id):
		return false
	var trait_id := player_augment.trait_id
	if trait_id == &"" and player_augment.trait_definition != null:
		trait_id = player_augment.trait_definition.trait_id
	if trait_id == &"":
		return false
	if loadout.add_or_upgrade_weapon_trait(
		target_weapon_id,
		trait_id,
		player_augment.trait_rank_increase,
	) < 0:
		return false
	selection_ui.restore_for_result()
	return true


func _resolve_facility_module(player_augment: PlayerAugment) -> bool:
	var replace_index := -1
	if not player_registry.has_empty_slot(player_augment.facility_id):
		selection_ui.suspend_choices()
		module_swap_ui.open(player_registry, player_augment.facility_id, player_augment)
		replace_index = await module_swap_ui.selection_finished
		if replace_index < 0:
			return false

	var installed_index := player_registry.install_augment(
		player_augment,
		player_augment.target_weapon_id,
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
	var summary := str(augment.get("display_name"))
	var player_augment := augment as PlayerAugment
	if player_augment != null:
		summary = player_augment.get_offer_title(_get_loadout()).replace("\n", " · ")
	await selection_ui.close_with_text(result_title, summary, accent_color)
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
	gameplay_world.add_child(burst)
	burst.global_position = ship.global_position
	if burst.has_method("play"):
		return int(burst.call("play", player_resume_clear_radius))
	return 0
