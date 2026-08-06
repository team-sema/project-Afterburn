class_name AugmentModuleSwapOverlay
extends CanvasLayer

signal slot_selected(slot_index: int)
signal selection_cancelled
signal selection_finished(slot_index: int)

@onready var title_label: Label = %TitleLabel
@onready var prompt_label: Label = %PromptLabel
@onready var cancel_button: Button = %CancelButton
@onready var slot_list: VBoxContainer = %SlotList
@onready var slot_button_template: Button = %SlotButtonTemplate

var _accepting := false
var _slot_count := 0
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	cancel_button.pressed.connect(_on_cancel_pressed)


func open(
	registry: PlayerAugmentRegistry,
	incoming_augment: PlayerAugment,
) -> void:
	title_label.text = "범용 모듈 교체"
	prompt_label.text = "%s 모듈을 장착할 슬롯을 고르세요" % incoming_augment.display_name
	var slots := registry.get_module_slots()
	_slot_count = slots.size()
	_rebuild_slot_buttons(_slot_count)
	for index in _slot_count:
		var button := _slot_buttons[index]
		var state := slots[index] as PlayerAugmentModuleState
		var definition := registry.get_facility_definition(state.augment.get_primary_module_tag())
		var tag_name := (
			definition.display_name
			if definition != null
			else String(state.augment.get_primary_module_tag())
		)
		button.text = "범용 슬롯 %d · %s\n%s" % [
			index + 1,
			tag_name,
			state.augment.display_name,
		]
		button.icon = state.augment.icon
		button.disabled = false
	visible = true
	_accepting = true
	if _slot_count > 0:
		_slot_buttons[0].grab_focus()


func _rebuild_slot_buttons(count: int) -> void:
	for button in _slot_buttons:
		button.free()
	_slot_buttons.clear()
	for index in count:
		var button := slot_button_template.duplicate() as Button
		button.name = "SlotButton%d" % (index + 1)
		button.visible = true
		button.pressed.connect(_on_slot_pressed.bind(index))
		slot_list.add_child(button)
		_slot_buttons.append(button)


func close() -> void:
	_accepting = false
	visible = false


func _on_slot_pressed(index: int) -> void:
	if not _accepting or index < 0 or index >= _slot_count:
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
