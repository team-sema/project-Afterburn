class_name WeaponLoadoutHud
extends Label

@export var ship: Node2D


func _ready() -> void:
	if ship == null:
		return
	var loadout := _get_loadout()
	if loadout == null:
		return
	loadout.loadout_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var loadout := _get_loadout()
	if loadout == null:
		text = ""
		return

	var main_slot := loadout.get_main_slot()
	var main_name := "없음"
	if main_slot != null and not main_slot.is_empty():
		main_name = main_slot.equipped_weapon_display_name
		if main_name.is_empty():
			main_name = String(main_slot.equipped_weapon_id)
	var lines: PackedStringArray = []
	lines.append("주무기 Lv.%d %s" % [main_slot.level if main_slot else 1, main_name])

	for index in PlayerWeaponLoadout.AUX_SLOT_COUNT:
		var slot := loadout.get_auxiliary_slot(index)
		if slot == null or not slot.unlocked:
			lines.append("보조%d 잠김" % (index + 1))
			continue
		if slot.is_empty():
			lines.append("보조%d Lv.%d —" % [index + 1, slot.level])
		else:
			var weapon_name := slot.equipped_weapon_display_name
			if weapon_name.is_empty():
				weapon_name = String(slot.equipped_weapon_id)
			lines.append("보조%d Lv.%d %s" % [index + 1, slot.level, weapon_name])
	text = "\n".join(lines)


func _get_loadout() -> PlayerWeaponLoadout:
	if ship != null and ship.has_method("get_weapon_loadout"):
		return ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	return null
