extends Node2D
## Replay enemy attack phases against a shared automatic target path.

const SCENES := ["res://enemies/elite_awl.tscn", "res://enemies/elite_fighter.tscn", "res://enemies/sniper_enemy.tscn"]
const TITLES := ["Elite Awl", "Elite Fighter", "Sniper"]

var world: Node2D
var target: Node2D
var elapsed := 0.0
var mode := 0
var status: Label
var _restarting := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("090c16"))
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := VBoxContainer.new()
	panel.add_theme_font_size_override("font_size", 10)
	panel.position = Vector2(12, 8)
	ui.add_child(panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 12)
	panel.add_child(status)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var buttons: Array[Button] = []
	for entry in ["Elite Awl", "Elite Fighter", "Sniper", "다시 재생"]:
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 10)
		button.text = entry
		row.add_child(button)
		buttons.append(button)
		button.mouse_entered.connect(button.grab_focus)
	for i in 3: buttons[i].pressed.connect(restart.bind(i))
	buttons[3].pressed.connect(func(): restart(mode))
	for i in buttons.size():
		buttons[i].focus_neighbor_left = buttons[i].get_path_to(buttons[posmod(i - 1, buttons.size())])
		buttons[i].focus_neighbor_right = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
	buttons[0].grab_focus()
	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 10)
	hint.text = "자동 표적 경로 / 방향키 + Enter 선택 / F1 허브"
	panel.add_child(hint)
	restart(0)

func restart(selection: int) -> void:
	if _restarting: return
	_restarting = true
	mode = clampi(selection, 0, SCENES.size() - 1)
	if is_instance_valid(world):
		world.queue_free()
		await get_tree().process_frame
	elapsed = 0
	world = Node2D.new()
	world.add_to_group("gameplay_world")
	add_child(world)
	var registry := EnemyAugmentRegistry.new()
	world.add_child(registry)
	target = Node2D.new()
	target.add_to_group("player")
	target.position = Vector2(320, 285)
	world.add_child(target)
	var marker := Line2D.new()
	marker.points = PackedVector2Array([Vector2(-5, 0), Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)])
	marker.default_color = Color(0.3, 1, 0.9)
	marker.width = 1.5
	target.add_child(marker)
	var path: String = SCENES[mode]
	var enemy := load(path).instantiate() as Enemy
	enemy.augment_registry = registry
	enemy.position = Vector2(320, -40)
	if mode == 0: enemy.get_node("EnemyShootComponent").shot_random_seed = 1701
	world.add_child(enemy)
	status.text = "공격 패턴  /  " + TITLES[mode]
	_restarting = false

func _process(delta: float) -> void:
	if _restarting or not is_instance_valid(target): return
	elapsed += delta
	target.position = Vector2(320 + sin(elapsed * 0.65) * 130, 285)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		get_tree().change_scene_to_file("res://labs/lab_hub.tscn")
		get_viewport().set_input_as_handled()
