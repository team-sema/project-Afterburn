extends PanelContainer

signal apply_requested(path: String, origin_index: int)
signal close_requested

var path_input: LineEdit
var choices: OptionButton
var origin_choice: OptionButton
var error_label: Label
var apply_button: Button

func _ready() -> void:
	position = Vector2(36, 25)
	size = Vector2(568, 310)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var title := Label.new()
	title.text = "패턴 스크립트  /  저장 후 F5로 다시 실행"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	choices = OptionButton.new()
	box.add_child(choices)
	choices.item_selected.connect(func(index): path_input.text = choices.get_item_metadata(index))
	path_input = LineEdit.new()
	path_input.placeholder_text = "res://patterns/새_패턴.gd"
	box.add_child(path_input)
	path_input.text_submitted.connect(func(_text): apply_requested.emit(path_input.text, origin_choice.selected))
	origin_choice = OptionButton.new()
	for text in ["발사 위치 · 상단 중앙", "발사 위치 · 화면 중앙", "발사 위치 · 하단 중앙"]:
		origin_choice.add_item(text)
	box.add_child(origin_choice)
	var help := Label.new()
	help.text = "BarrageSequence 상속 · _init()에서 발사 일정 작성\n에디터에서 저장 → 적용/F5 · WASD 표적 · Esc 취소"
	help.add_theme_font_size_override("font_size", 12)
	box.add_child(help)
	error_label = Label.new()
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.custom_minimum_size = Vector2(530, 46)
	error_label.add_theme_color_override("font_color", Color("ffb58f"))
	error_label.add_theme_font_size_override("font_size", 12)
	box.add_child(error_label)
	apply_button = Button.new()
	apply_button.text = "저장본 불러오기 / 실행"
	apply_button.pressed.connect(func(): apply_requested.emit(path_input.text, origin_choice.selected))
	box.add_child(apply_button)
	var close := Button.new()
	close.text = "취소 · 기존 실행으로"
	close.pressed.connect(func(): close_requested.emit())
	box.add_child(close)
	var controls: Array[Control] = [choices, path_input, origin_choice, apply_button, close]
	for i in controls.size():
		controls[i].mouse_entered.connect(controls[i].grab_focus)
		controls[i].focus_neighbor_top = controls[i].get_path_to(controls[posmod(i - 1, controls.size())])
		controls[i].focus_neighbor_bottom = controls[i].get_path_to(controls[(i + 1) % controls.size()])

func refresh(path: String, origin_index: int) -> void:
	choices.clear()
	var paths := preload("res://labs/pattern_loader.gd").list_patterns()
	for item in paths:
		choices.add_item(item.trim_prefix("res://patterns/"))
		choices.set_item_metadata(choices.item_count - 1, item)
		if item == path: choices.select(choices.item_count - 1)
	choices.disabled = paths.is_empty()
	choices.focus_mode = Control.FOCUS_NONE if choices.disabled else Control.FOCUS_ALL
	path_input.text = path
	origin_choice.select(origin_index)
	error_label.text = ""
	apply_button.grab_focus()
