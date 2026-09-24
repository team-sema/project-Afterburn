extends Control

const LABS := [
	["탄막 · 패턴 스크립트", "res://projectiles/bullet_lab.tscn"],
	["거대 항모 · Boss Lab", "res://labs/carrier_boss_lab.tscn"],
	["엘리트 · 스나이퍼 공격 패턴", "res://labs/enemy_attack_lab.tscn"],
	["무기 · 증강 · 적 소환", "res://weapon_test/weapon_test_lab.tscn"],
	["실제 전투 · 위협도 분석", "res://threat_monitor/threat_monitor_lab.tscn"],
	["증강 카드 · UI", "res://menus/augment_frame_test.tscn"],
]
var _opening := false

func _ready() -> void:
	get_tree().paused = false
	var background := ColorRect.new()
	background.color = Color("0a101c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := VBoxContainer.new()
	panel.position = Vector2(100, 28)
	panel.size = Vector2(440, 304)
	panel.add_theme_constant_override("separation", 6)
	add_child(panel)
	var title := Label.new()
	title.text = "AFTERBURN  /  LAB"
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "시험 환경 선택 · Lab에서 F1을 누르면 이 목록으로"
	subtitle.add_theme_font_size_override("font_size", 14)
	panel.add_child(subtitle)
	var buttons: Array[Button] = []
	for entry in LABS:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 32
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(open_lab.bind(entry[1]))
		button.mouse_entered.connect(button.grab_focus)
		panel.add_child(button)
		buttons.append(button)
	for i in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[posmod(i - 1, buttons.size())])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
	buttons[0].grab_focus()

func open_lab(path: String) -> void:
	if _opening: return
	_opening = true
	var navigation := Node.new()
	navigation.name = "LabReturn"
	navigation.set_script(preload("res://labs/lab_return.gd"))
	get_tree().root.add_child(navigation)
	get_tree().change_scene_to_file.call_deferred(path)
