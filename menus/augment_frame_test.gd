extends Control
## Standalone F6 visual lab. Only duplicated resources receive test tiers.

const SAMPLES := [
	preload("res://resources/player_augments/weapon/trait_shotgun_expanded_shell.tres"),
	preload("res://resources/player_augments/weapon/trait_plasma_gravity.tres"),
	preload("res://resources/player_augments/weapon/trait_missile_multi_rack.tres"),
	preload("res://resources/player_augments/weapon/trait_shotgun_cut_barrel.tres"),
]

@onready var overlay: AugmentSelectionOverlay = $AugmentSelectionOverlay
@onready var status: Label = %Status
@onready var mode_buttons: VBoxContainer = %Modes
var test_tier := -1
var rerolls := 2
var sample_offset := 0
var busy := false


func _ready() -> void:
	for index in mode_buttons.get_child_count():
		(mode_buttons.get_child(index) as Button).pressed.connect(show_mode.bind(index - 1))
	%Reset.pressed.connect(show_mode.bind(-2))
	overlay.reroll_requested.connect(_reroll)
	overlay.choice_selected.connect(_select)
	show_mode(-1)


func _make_choice(index: int) -> PlayerAugment:
	var choice := SAMPLES[(sample_offset + index) % SAMPLES.size()].duplicate() as PlayerAugment
	choice.tier = index as PlayerAugment.Tier if test_tier < 0 else test_tier as PlayerAugment.Tier
	return choice


func show_mode(tier: int) -> void:
	if busy:
		return
	busy = true
	if tier != -2:
		test_tier = tier
	rerolls = 2
	overlay.set_reroll_state(rerolls, true)
	var choices: Array = []
	for index in 3:
		choices.append(_make_choice(index))
	status.text = "선택하면 결과 연출 후\n다시 열립니다."
	await overlay.open_choices("증강 선택", choices, overlay.player_accent_color)
	busy = false


func _reroll(index: int) -> void:
	if busy or rerolls <= 0:
		return
	sample_offset += 1
	rerolls -= 1
	overlay.refresh_choice_at(index, _make_choice(index))
	overlay.set_reroll_state(rerolls, true)
	status.text = "리롤 적용 · 남은 횟수 %d\n등급은 유지됩니다." % rerolls


func _select(choice: Resource) -> void:
	if busy:
		return
	busy = true
	var augment := choice as PlayerAugment
	status.text = "%s 선택\n%s" % [augment.get_tier_label(), augment.display_name]
	await overlay.close_with_result("선택 완료", augment, overlay.player_accent_color)
	busy = false
	show_mode(-2)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode >= KEY_1 and key.keycode <= KEY_4:
		show_mode(int(key.keycode - KEY_1) - 1)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F5:
		show_mode(-2)
		get_viewport().set_input_as_handled()
