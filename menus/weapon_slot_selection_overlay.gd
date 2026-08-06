class_name WeaponSlotSelectionOverlay
extends CanvasLayer

## In-offer replace UI when acquiring a weapon with full bays.

signal slot_selected(slot_index: int)
signal selection_cancelled
signal selection_finished(slot_index: int)

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
var _incoming: WeaponDefinition = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for index in slot_buttons.size():
		slot_buttons[index].pressed.connect(_on_slot_pressed.bind(index))
	cancel_button.pressed.connect(_on_cancel_pressed)


func open_for_replace(
	loadout: PlayerWeaponLoadout,
	title: String,
	prompt: String,
	incoming_weapon: WeaponDefinition = null,
) -> void:
	_incoming = incoming_weapon
	_valid_indices.clear()
	for index in loadout.get_max_equipped_weapon_count():
		var bay := loadout.get_bay(index)
		if bay != null and not bay.is_empty():
			_valid_indices.append(index)
	_open(loadout, title, prompt, true)


func _open(loadout: PlayerWeaponLoadout, title: String, prompt: String, allow_cancel: bool) -> void:
	var incoming_name := _incoming.display_name if _incoming != null else "새 무기"
	title_label.text = title
	prompt_label.text = (
		prompt
		if prompt != ""
		else "%s(으)로 교체할 병기를 선택하세요.\n교체하면 장착된 모듈 레벨이 모두 사라집니다." % incoming_name
	)
	visible = true
	_accepting = true
	for index in slot_buttons.size():
		var button := slot_buttons[index]
		var bay: WeaponSlotState = loadout.get_bay(index)
		button.visible = index < loadout.get_max_equipped_weapon_count()
		if bay == null or bay.is_empty():
			button.text = "베이 %d\n비어 있음" % [index + 1]
			button.disabled = true
			button.icon = null
			continue
		var weapon_id := bay.equipped_weapon_id
		var weapon_name := bay.equipped_weapon_display_name
		if weapon_name.is_empty():
			weapon_name = String(weapon_id)
		var traits := loadout.get_weapon_traits(weapon_id)
		var trait_text := "모듈 없음"
		if not traits.is_empty():
			var parts: PackedStringArray = []
			for trait_id in traits.keys():
				parts.append("%s %d" % [String(trait_id), int(traits[trait_id])])
			parts.sort()
			trait_text = " / ".join(parts)
		button.text = "베이 %d\n%s\n%s\n(교체 시 모듈 삭제)" % [
			index + 1,
			weapon_name,
			trait_text,
		]
		button.icon = loadout.get_weapon_icon(weapon_id)
		button.disabled = not _valid_indices.has(index)
	cancel_button.visible = allow_cancel
	if not _valid_indices.is_empty():
		slot_buttons[_valid_indices[0]].grab_focus()
	elif allow_cancel:
		cancel_button.grab_focus()


func close() -> void:
	_accepting = false
	visible = false
	_incoming = null


func _on_slot_pressed(index: int) -> void:
	if not _accepting:
		return
	if not _valid_indices.has(index):
		return
	_accepting = false
	slot_selected.emit(index)
	selection_finished.emit(index)
	close()


func _on_cancel_pressed() -> void:
	if not _accepting:
		return
	_accepting = false
	selection_cancelled.emit()
	selection_finished.emit(-1)
	close()
