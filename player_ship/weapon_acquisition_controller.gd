class_name WeaponAcquisitionController
extends Node

@export var ship: Node2D
@export var slot_selection_ui: WeaponSlotSelectionOverlay
@export var confirm_ui: WeaponAcquireConfirmOverlay

var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("weapon_acquisition")
	assert(ship != null, "WeaponAcquisitionController requires ship.")
	assert(slot_selection_ui != null, "WeaponAcquisitionController requires slot_selection_ui.")
	assert(confirm_ui != null, "WeaponAcquisitionController requires confirm_ui.")


func try_collect(weapon_definition: WeaponDefinition) -> bool:
	if _busy or weapon_definition == null:
		return false
	var loadout := _get_loadout()
	if loadout == null:
		return false

	_busy = true
	var consumed := false
	match weapon_definition.category:
		WeaponDefinition.Category.MAIN:
			consumed = await _collect_main(loadout, weapon_definition)
		WeaponDefinition.Category.AUXILIARY:
			consumed = await _collect_auxiliary(loadout, weapon_definition)
		_:
			consumed = false
	_busy = false
	return consumed


func _collect_main(loadout: PlayerWeaponLoadout, weapon_definition: WeaponDefinition) -> bool:
	if loadout.get_main_weapon_id() == weapon_definition.id:
		return loadout.upgrade_main_slot()

	get_tree().paused = true
	confirm_ui.ask(
		"주무기 교체",
		"%s(으)로 교체할까요?" % weapon_definition.display_name,
	)
	var replace := await _wait_bool(confirm_ui.confirmed, confirm_ui.cancelled)
	get_tree().paused = false
	if not replace:
		return true
	loadout.equip_main_weapon(weapon_definition)
	return true


func _collect_auxiliary(loadout: PlayerWeaponLoadout, weapon_definition: WeaponDefinition) -> bool:
	if loadout.has_auxiliary_weapon(weapon_definition.id):
		return loadout.upgrade_auxiliary_weapon(weapon_definition.id)

	var empty := loadout.get_first_empty_auxiliary_slot()
	if empty >= 0:
		loadout.equip_auxiliary_weapon(weapon_definition, empty)
		return true

	get_tree().paused = true
	slot_selection_ui.open_for_replace(
		loadout,
		"보조무기 교체",
		"%s(으)로 교체할 슬롯을 고르세요" % weapon_definition.display_name,
	)
	var slot_index := await _wait_slot_or_cancel()
	get_tree().paused = false
	if slot_index < 0:
		return false
	loadout.replace_auxiliary_weapon(slot_index, weapon_definition)
	return true


func _wait_bool(yes_signal: Signal, no_signal: Signal) -> bool:
	var state := {"done": false, "value": false}
	var on_yes := func() -> void:
		if state.done:
			return
		state.done = true
		state.value = true
	var on_no := func() -> void:
		if state.done:
			return
		state.done = true
		state.value = false
	yes_signal.connect(on_yes, CONNECT_ONE_SHOT)
	no_signal.connect(on_no, CONNECT_ONE_SHOT)
	while not state.done:
		await get_tree().process_frame
	return state.value


func _wait_slot_or_cancel() -> int:
	var state := {"done": false, "value": -1}
	var on_slot := func(index: int) -> void:
		if state.done:
			return
		state.done = true
		state.value = index
	var on_cancel := func() -> void:
		if state.done:
			return
		state.done = true
		state.value = -1
	slot_selection_ui.slot_selected.connect(on_slot, CONNECT_ONE_SHOT)
	slot_selection_ui.selection_cancelled.connect(on_cancel, CONNECT_ONE_SHOT)
	while not state.done:
		await get_tree().process_frame
	return state.value


func _get_loadout() -> PlayerWeaponLoadout:
	if ship != null and ship.has_method("get_weapon_loadout"):
		return ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	return null
