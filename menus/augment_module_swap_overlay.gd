class_name AugmentModuleSwapOverlay
extends CanvasLayer

signal slot_selected(slot_index: int)
signal selection_cancelled
signal selection_finished(slot_index: int)

@onready var title_label: Label = %TitleLabel
@onready var prompt_label: Label = %PromptLabel
@onready var cancel_button: Button = %CancelButton
@onready var slot_buttons: Array[Button] = [
	%SlotButton1,
	%SlotButton2,
	%SlotButton3,
]

var _accepting := false
var _slot_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for index in slot_buttons.size():
		slot_buttons[index].pressed.connect(_on_slot_pressed.bind(index))
	cancel_button.pressed.connect(_on_cancel_pressed)


func open(
	registry: PlayerAugmentRegistry,
	facility_id: StringName,
	incoming_augment: PlayerAugment,
) -> void:
	var definition := registry.get_facility_definition(facility_id)
	var facility_name := definition.display_name if definition != null else String(facility_id)
	title_label.text = "%s 모듈 교체" % facility_name
	prompt_label.text = "%s 모듈을 장착할 슬롯을 고르세요" % incoming_augment.display_name
	var slots := registry.get_facility_slots(facility_id)
	_slot_count = slots.size()
	for index in slot_buttons.size():
		var button := slot_buttons[index]
		button.visible = index < _slot_count
		if index >= _slot_count:
			continue
		var state := slots[index] as PlayerAugmentModuleState
		button.text = "슬롯 %d\n%s" % [index + 1, state.augment.display_name]
		button.disabled = false
	visible = true
	_accepting = true
	if _slot_count > 0:
		slot_buttons[0].grab_focus()


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
