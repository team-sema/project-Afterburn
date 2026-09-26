class_name AugmentOfferController
extends Node

const AUGMENT_RESUME_BURST_SCENE := preload("res://effects/augment_resume_burst.tscn")
const FOURTH_WEAPON_BAY_RULE := &"fourth_weapon_bay"
const FOURTH_WEAPON_BAY_DAMAGE_MULTIPLIER := 0.85
const FOURTH_WEAPON_BAY_COUNT := 4

signal offer_started(offer_type: OfferType)
signal offer_completed(offer_type: OfferType)
signal reroll_count_changed(remaining: int)
signal augment_candidates_changed

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
## Empty + auto_load → folder scan. Tests may assign a pool before _ready / without auto_load.
@export var player_augment_pool: Array[PlayerAugment] = []
@export var enemy_augment_pool: Array[EnemyAugment] = []
@export var auto_load_offer_pools := true
@export_dir var player_augment_directory := AugmentPoolLoader.DEFAULT_PLAYER_DIR
@export_dir var enemy_augment_directory := AugmentPoolLoader.DEFAULT_ENEMY_DIR
@export_range(1, 3, 1) var choices_per_offer := 3
@export_range(8.0, 120.0, 1.0) var player_resume_clear_radius := 36.0
## Run-wide reroll budget (temporary balance; tune via export only).
@export_range(0, 20, 1) var max_reroll_count := 2
## Offer-level tier odds: one roll per player offer (temporary balance).
@export_range(0.0, 100.0, 0.1) var silver_offer_weight := 55.0
@export_range(0.0, 100.0, 0.1) var gold_offer_weight := 40.0
@export_range(0.0, 100.0, 0.1) var prismatic_offer_weight := 5.0
@export_range(0, 10, 1) var max_prismatic_picks_per_run := 2
## Category multipliers on top of each card's offer_weight, inside the offer tier.
@export_range(0.01, 10.0, 0.01) var acquire_weight_has_empty_bay := 1.8
@export_range(0.01, 10.0, 0.01) var acquire_weight_bays_full := 0.55
@export_range(0.01, 10.0, 0.01) var trait_weight_has_empty_bay := 1.0
@export_range(0.01, 10.0, 0.01) var trait_weight_bays_full := 1.0
@export_range(0.01, 10.0, 0.01) var facility_weight_multiplier := 1.0

var is_offer_active := false
var active_offer_type := OfferType.PLAYER
var remaining_reroll_count := 0
## Highest tier among the current player offer's cards (shown in the title).
var current_offer_tier := PlayerAugment.Tier.SILVER
var prismatic_pick_count := 0
## Elite rewards: each one lifts one later player offer to Gold or above.
var pending_gold_guarantees := 0
var _applied_rules: Dictionary = {}
var _current_player_choices: Array[PlayerAugment] = []
var _awaiting_final_choice := false


func _ready() -> void:
	assert(player_registry != null, "AugmentOfferController requires a PlayerAugmentRegistry.")
	assert(enemy_registry != null, "AugmentOfferController requires an EnemyAugmentRegistry.")
	assert(selection_ui != null, "AugmentOfferController requires an AugmentSelectionOverlay.")
	assert(module_swap_ui != null, "AugmentOfferController requires an AugmentModuleSwapOverlay.")
	assert(ship != null, "AugmentOfferController requires a Ship reference.")
	_ensure_offer_pools_loaded()
	assert(enemy_augment_pool.size() >= choices_per_offer, "Enemy augment pool is too small for an offer.")
	remaining_reroll_count = max_reroll_count
	selection_ui.configure_player_registry(player_registry)
	selection_ui.configure_weapon_loadout(_get_loadout())
	selection_ui.choice_selected.connect(_on_choice_selected)
	selection_ui.universal_slot_expansion_selected.connect(_on_universal_slot_expansion_selected)
	selection_ui.reroll_requested.connect(_on_reroll_requested)


func _ensure_offer_pools_loaded() -> void:
	if not auto_load_offer_pools:
		return
	if player_augment_pool.is_empty():
		player_augment_pool = AugmentPoolLoader.load_player_offer_pool(player_augment_directory)
	if enemy_augment_pool.is_empty():
		enemy_augment_pool = AugmentPoolLoader.load_enemy_offer_pool(enemy_augment_directory)


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
	var accent_color: Color
	var show_ship_modules := false
	if active_offer_type == OfferType.PLAYER:
		selection_ui.configure_weapon_loadout(_get_loadout())
		_current_player_choices = _pick_player_choices()
		choices = _current_player_choices
		title = "강화 선택 · %s" % PlayerAugment.tier_label(current_offer_tier)
		accent_color = selection_ui.player_accent_color
		show_ship_modules = true
		_awaiting_final_choice = true
		selection_ui.set_reroll_state(remaining_reroll_count, remaining_reroll_count > 0)
	else:
		choices = _pick_enemy_choices()
		title = "적 강화"
		accent_color = selection_ui.enemy_accent_color
		_awaiting_final_choice = false
		selection_ui.set_reroll_state(-1, false)

	if choices.is_empty():
		push_error("AugmentOfferController: no valid augment choices.")
		is_offer_active = false
		get_tree().paused = false
		return
	await selection_ui.open_choices(title, choices, accent_color, show_ship_modules)


func _get_loadout() -> PlayerWeaponLoadout:
	if ship != null and ship.has_method("get_weapon_loadout"):
		return ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	return null


## Elite reward hook: the next player offer rolls at least Gold. Stacks per call.
func grant_gold_offer_guarantee() -> void:
	pending_gold_guarantees += 1


func _pick_player_choices() -> Array[PlayerAugment]:
	_ensure_offer_pools_loaded()
	var loadout := _get_loadout()
	var valid: Array[PlayerAugment] = []
	for augment in player_augment_pool:
		if _is_player_augment_available(augment, loadout):
			valid.append(augment)
	var picks := _pick_tiered(valid, choices_per_offer, _roll_offer_tier(), loadout)
	current_offer_tier = PlayerAugment.Tier.SILVER
	for pick in picks:
		current_offer_tier = maxi(current_offer_tier, pick.tier) as PlayerAugment.Tier
	return picks


## One roll per offer; a pending elite guarantee lifts Silver to Gold.
func _roll_offer_tier() -> PlayerAugment.Tier:
	var weights: Array[float] = [
		maxf(0.0, silver_offer_weight),
		maxf(0.0, gold_offer_weight),
		maxf(0.0, prismatic_offer_weight),
	]
	var total := weights[0] + weights[1] + weights[2]
	var tier := PlayerAugment.Tier.SILVER
	if total > 0.0:
		var roll := randf() * total
		var cursor := 0.0
		for index in weights.size():
			cursor += weights[index]
			if roll < cursor:
				tier = index as PlayerAugment.Tier
				break
	if pending_gold_guarantees > 0:
		pending_gold_guarantees -= 1
		tier = maxi(tier, PlayerAugment.Tier.GOLD) as PlayerAugment.Tier
	return tier


## Fills the offer from `tier`, topping up from each lower tier when it runs short.
func _pick_tiered(
	pool: Array[PlayerAugment],
	count: int,
	tier: PlayerAugment.Tier,
	loadout: PlayerWeaponLoadout,
) -> Array[PlayerAugment]:
	var picked: Array[PlayerAugment] = []
	for current_tier in range(int(tier), -1, -1):
		if picked.size() >= count:
			break
		var tier_pool: Array[PlayerAugment] = []
		for augment in pool:
			if int(augment.tier) == current_tier and not picked.has(augment):
				tier_pool.append(augment)
		picked.append_array(_pick_weighted(tier_pool, count - picked.size(), loadout))
	return picked


func _pick_enemy_choices() -> Array[EnemyAugment]:
	_ensure_offer_pools_loaded()
	var choices: Array[EnemyAugment] = []
	for augment in enemy_augment_pool:
		if _is_enemy_augment_available(augment):
			choices.append(augment)
	choices.shuffle()
	choices.resize(mini(choices.size(), choices_per_offer))
	return choices


func _is_enemy_augment_available(augment: EnemyAugment) -> bool:
	return augment != null and enemy_registry.can_add_augment(augment)


func _category_weight_multiplier(
	augment: PlayerAugment,
	loadout: PlayerWeaponLoadout,
) -> float:
	var bays_full := loadout != null and loadout.is_bays_full()
	match augment.augment_type:
		PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
			return acquire_weight_bays_full if bays_full else acquire_weight_has_empty_bay
		PlayerAugmentKind.Kind.WEAPON_TRAIT:
			return trait_weight_bays_full if bays_full else trait_weight_has_empty_bay
		PlayerAugmentKind.Kind.FACILITY_EFFECT:
			return facility_weight_multiplier
		_:
			return 1.0


func _effective_offer_weight(
	augment: PlayerAugment,
	loadout: PlayerWeaponLoadout,
) -> float:
	return maxf(0.0, augment.offer_weight) * _category_weight_multiplier(augment, loadout)


func _pick_weighted(
	pool: Array[PlayerAugment],
	count: int,
	loadout: PlayerWeaponLoadout = null,
) -> Array[PlayerAugment]:
	var remaining: Array[PlayerAugment] = pool.duplicate()
	var picked: Array[PlayerAugment] = []
	while not remaining.is_empty() and picked.size() < count:
		var total := 0.0
		for augment in remaining:
			total += _effective_offer_weight(augment, loadout)
		if total <= 0.0:
			remaining.shuffle()
			while not remaining.is_empty() and picked.size() < count:
				picked.append(remaining.pop_back())
			break
		var roll := randf() * total
		var cursor := 0.0
		var chosen_index := remaining.size() - 1
		for index in remaining.size():
			cursor += _effective_offer_weight(remaining[index], loadout)
			if roll <= cursor:
				chosen_index = index
				break
		picked.append(remaining[chosen_index])
		remaining.remove_at(chosen_index)
	return picked


func _is_player_augment_available(augment: PlayerAugment, loadout: PlayerWeaponLoadout) -> bool:
	if augment == null:
		return false
	if (
		augment.tier == PlayerAugment.Tier.PRISMATIC
		and prismatic_pick_count >= max_prismatic_picks_per_run
	):
		return false
	match augment.augment_type:
		PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
			if loadout == null or augment.weapon_definition == null:
				return false
			var weapon_id := augment.get_weapon_id()
			# Already equipped weapons grow through their modules.
			return not loadout.is_weapon_equipped(weapon_id)
		PlayerAugmentKind.Kind.WEAPON_TRAIT:
			if loadout == null or augment.trait_id == &"":
				return false
			var target_weapon_id := augment.target_weapon_id
			if target_weapon_id == &"":
				var equipped := loadout.get_equipped_weapon_ids()
				if equipped.is_empty():
					return false
				target_weapon_id = equipped[0]
			return loadout.can_upgrade_weapon_trait(target_weapon_id, augment.trait_id)
		PlayerAugmentKind.Kind.FACILITY_EFFECT:
			var primary_tag := augment.get_primary_module_tag()
			return primary_tag != &"" and player_registry.has_facility(primary_tag)
		PlayerAugmentKind.Kind.SHIP_RULE:
			return _is_ship_rule_available(augment, loadout)
		_:
			return false


func _is_ship_rule_available(augment: PlayerAugment, loadout: PlayerWeaponLoadout) -> bool:
	if augment.rule_id == &"" or _applied_rules.has(augment.rule_id):
		return false
	match augment.rule_id:
		FOURTH_WEAPON_BAY_RULE:
			return (
				loadout != null
				and loadout.get_max_equipped_weapon_count() < FOURTH_WEAPON_BAY_COUNT
			)
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
			if player_augment.tier == PlayerAugment.Tier.PRISMATIC:
				prismatic_pick_count += 1
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
		PlayerAugmentKind.Kind.WEAPON_TRAIT:
			return _resolve_weapon_trait(player_augment, loadout)
		PlayerAugmentKind.Kind.STAT_MULTIPLIER, PlayerAugmentKind.Kind.FACILITY_EFFECT:
			return await _resolve_facility_module(player_augment)
		PlayerAugmentKind.Kind.SHIP_RULE:
			return _resolve_ship_rule(player_augment, loadout)
		_:
			return false


func _resolve_ship_rule(player_augment: PlayerAugment, loadout: PlayerWeaponLoadout) -> bool:
	if not _is_ship_rule_available(player_augment, loadout):
		return false
	match player_augment.rule_id:
		FOURTH_WEAPON_BAY_RULE:
			loadout.add_weapon_bays(FOURTH_WEAPON_BAY_COUNT - loadout.get_max_equipped_weapon_count())
			loadout.set_rule_damage_multiplier(
				loadout.get_rule_damage_multiplier() * FOURTH_WEAPON_BAY_DAMAGE_MULTIPLIER
			)
		_:
			return false
	_applied_rules[player_augment.rule_id] = true
	selection_ui.restore_for_result()
	return true


func _resolve_weapon_acquire(player_augment: PlayerAugment, loadout: PlayerWeaponLoadout) -> bool:
	if loadout == null or player_augment.weapon_definition == null:
		return false
	var definition := player_augment.weapon_definition
	if loadout.offer_equip_weapon(definition):
		selection_ui.restore_for_result()
		return true
	if weapon_slot_ui == null:
		push_error("AugmentOfferController: weapon_slot_ui required when bays are full.")
		return false
	selection_ui.suspend_choices()
	weapon_slot_ui.open_for_replace(
		loadout,
		"무기 교체",
		"교체할 병기 모듈을 선택하세요.\n교체하면 장착된 모듈 레벨이 모두 사라집니다.",
		definition,
	)
	var slot_index: int = await weapon_slot_ui.selection_finished
	if slot_index < 0:
		return false
	if not loadout.request_replace_equipped(slot_index, definition):
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
	if not player_registry.has_empty_slot():
		selection_ui.suspend_choices()
		module_swap_ui.open(player_registry, player_augment)
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


func _on_universal_slot_expansion_selected() -> void:
	if active_offer_type != OfferType.PLAYER:
		return
	if not player_registry.expand_slots():
		selection_ui.resume_choices()
		return
	await selection_ui.close_with_text(
		"슬롯 확장",
		"범용 슬롯 %d/%d" % [
			player_registry.get_slot_capacity(),
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
	_awaiting_final_choice = false
	_current_player_choices.clear()
	if completed_offer_type == OfferType.PLAYER:
		_trigger_player_resume_burst()
	get_tree().paused = false
	offer_completed.emit(completed_offer_type)


func _on_reroll_requested(choice_index: int) -> void:
	if not is_offer_active or not _awaiting_final_choice:
		return
	if active_offer_type != OfferType.PLAYER:
		return
	if choice_index < 0 or choice_index >= _current_player_choices.size():
		return
	if remaining_reroll_count <= 0:
		selection_ui.set_reroll_state(0, false)
		return
	var excluded_ids := {}
	for choice in _current_player_choices:
		if choice != null:
			excluded_ids[choice.augment_id] = true
	var focused := _current_player_choices[choice_index]
	var replacement := _pick_player_replacement(excluded_ids, focused.augment_type, focused.tier)
	if replacement == null:
		return
	remaining_reroll_count -= 1
	reroll_count_changed.emit(remaining_reroll_count)
	_current_player_choices[choice_index] = replacement
	augment_candidates_changed.emit()
	selection_ui.refresh_choice_at(choice_index, replacement)
	selection_ui.set_reroll_state(remaining_reroll_count, remaining_reroll_count > 0)


## Same tier as the rerolled card (lower tiers only when it runs dry), same Kind first.
func _pick_player_replacement(
	excluded_ids: Dictionary,
	preferred_kind: PlayerAugmentKind.Kind = PlayerAugmentKind.Kind.STAT_MULTIPLIER,
	max_tier: PlayerAugment.Tier = PlayerAugment.Tier.PRISMATIC,
) -> PlayerAugment:
	var loadout := _get_loadout()
	var valid: Array[PlayerAugment] = []
	for augment in player_augment_pool:
		if (
			_is_player_augment_available(augment, loadout)
			and not excluded_ids.has(augment.augment_id)
		):
			valid.append(augment)
	for current_tier in range(int(max_tier), -1, -1):
		var tier_pool: Array[PlayerAugment] = []
		var preferred: Array[PlayerAugment] = []
		for augment in valid:
			if int(augment.tier) != current_tier:
				continue
			tier_pool.append(augment)
			if augment.augment_type == preferred_kind:
				preferred.append(augment)
		var picked := _pick_weighted(preferred if not preferred.is_empty() else tier_pool, 1, loadout)
		if not picked.is_empty():
			return picked[0]
	return null


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
