class_name WeaponSlotSelectionOverlay
extends CanvasLayer

signal slot_selected(slot_index: int)
signal selection_cancelled

@onready var backdrop: ColorRect = $Backdrop
@onready var title_label: Label = %TitleLabel
@onready var prompt_label: Label = %PromptLabel
@onready var cancel_button: Button = %CancelButton
@onready var slot_buttons: Array[Button] = [
	%SlotButton1,
	%SlotButton2,
	%SlotButton3,
]

var _accepting := false
var _valid_indices: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for index in slot_buttons.size():
		slot_buttons[index].pressed.connect(_on_slot_pressed.bind(index))
	cancel_button.pressed.connect(_on_cancel_pressed)


func open_for_replace(loadout: PlayerWeaponLoadout, title: String, prompt: String) -> void:
	_valid_indices = loadout.get_occupied_auxiliary_indices()
	_open(loadout, title, prompt, true)


func open_for_weapon_upgrade(loadout: PlayerWeaponLoadout, title: String, prompt: String) -> void:
	_valid_indices = loadout.get_upgradable_auxiliary_indices()
	_open(loadout, title, prompt, false)


func _open(loadout: PlayerWeaponLoadout, title: String, prompt: String, allow_cancel: bool) -> void:
	title_label.text = title
	prompt_label.text = prompt
	visible = true
	_accepting = true
	for index in slot_buttons.size():
		var button := slot_buttons[index]
		var slot := loadout.get_auxiliary_slot(index)
		var weapon_name := "비어 있음"
		if slot != null and not slot.is_empty() and slot.equipped_weapon_instance != null:
			weapon_name = slot.equipped_weapon_display_name
			if weapon_name.is_empty():
				weapon_name = String(slot.equipped_weapon_id)
		var status_text := "잠김"
		if slot != null and slot.unlocked:
			status_text = "비어 있음" if slot.is_empty() else "Lv.%d" % loadout.get_weapon_level(
				slot.equipped_weapon_id
			)
		button.text = "보조 %d [%s]\n%s" % [index + 1, status_text, weapon_name]
		button.disabled = not _valid_indices.has(index)
		button.visible = true
	cancel_button.visible = allow_cancel
	if not _valid_indices.is_empty():
		slot_buttons[_valid_indices[0]].grab_focus()
	elif allow_cancel:
		cancel_button.grab_focus()


func close() -> void:
	_accepting = false
	visible = false


func _on_slot_pressed(index: int) -> void:
	if not _accepting:
		return
	if not _valid_indices.has(index):
		return
	_accepting = false
	slot_selected.emit(index)
	close()


func _on_cancel_pressed() -> void:
	if not _accepting:
		return
	_accepting = false
	selection_cancelled.emit()
	close()
