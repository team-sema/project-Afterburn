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
@export var ship: Node2D
## 시설 오그먼트의 상한 판정과 실제 레벨 변경에 쓰는 유일한 상태 출처.
@export var facility_registry: ShipFacilityRegistry
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
	assert(ship != null, "AugmentOfferController requires a Ship reference.")
	assert(enemy_augment_pool.size() >= choices_per_offer, "Enemy augment pool is too small for an offer.")
	selection_ui.choice_selected.connect(_on_choice_selected)


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
	if active_offer_type == OfferType.PLAYER:
		choices = _pick_player_choices()
		title = "플레이어 강화"
		prompt = "업그레이드를 하나 고르세요"
		accent_color = selection_ui.player_accent_color
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
	await selection_ui.open_choices(title, prompt, choices, accent_color)


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
		PlayerAugmentKind.Kind.UPGRADE_FACILITY:
			# 상한에 닿은 시설은 선택지에서 사라진다.
			return facility_registry != null and facility_registry.can_upgrade_facility(augment.facility_id)
		_:
			# Weapon grant and unlock cards are not offered; weapons come from drops.
			return false
	return false


func _on_choice_selected(choice: Resource) -> void:
	match active_offer_type:
		OfferType.PLAYER:
			var player_augment := choice as PlayerAugment
			assert(player_augment != null, "Player offer requires a PlayerAugment choice.")
			await _resolve_player_augment(player_augment)
			await _finish_offer(player_augment)
		OfferType.ENEMY:
			var enemy_augment := choice as EnemyAugment
			assert(enemy_augment != null, "Enemy offer requires an EnemyAugment choice.")
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

	# 시설 레벨은 레지스트리만 바꾼다. 스탯 재계산과 STATUS UI 갱신은
	# facility_level_changed를 듣는 ShipFacilityApplier·ShipPanel이 알아서 한다.
	if player_augment.augment_type == PlayerAugmentKind.Kind.UPGRADE_FACILITY:
		_upgrade_facility(player_augment)

	player_registry.add_augment(player_augment)


func _upgrade_facility(player_augment: PlayerAugment) -> void:
	if facility_registry == null:
		push_error("AugmentOfferController: facility augment offered without a ShipFacilityRegistry.")
		return
	for _step in maxi(1, player_augment.facility_level_gain):
		if not facility_registry.upgrade_facility(player_augment.facility_id):
			break


func _finish_offer(augment: Resource) -> void:
	var result_title := "플레이어 강화 획득" if active_offer_type == OfferType.PLAYER else "적 위협 강화"
	var accent_color := selection_ui.player_accent_color if active_offer_type == OfferType.PLAYER else selection_ui.enemy_accent_color
	await selection_ui.close_with_result(result_title, augment, accent_color)
	var completed_offer_type := active_offer_type
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
