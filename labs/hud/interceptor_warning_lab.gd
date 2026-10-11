extends Control
## Visual-only comparison. No combat actors, damage or gameplay timing changes.
const WORLD := preload("res://world.tscn")
const FIGHTER := preload("res://assets/enemies/enemy_interceptor.svg")
const TITLES := ["A / EDGE RAIL", "B / BEARING LOCK", "C / VECTOR SCAN"]
const NOTES := ["분절 레일 · 측면 위험 강조", "방위각 눈금 · 접촉 방향 포착", "진입 벡터 · 두 기체 스캔"]
const BLUE := Color("48baff")
const ICE := Color("bcefff")
const WARNING_TIME := 0.9
const ENTRY_ANGLE := 22.0
const TEAL := Color("35ffe1")
var variant := 1
var from_right := false
var elapsed := 0.0
var stopped := false
var slow := false
var danger: DangerIndicator
var ink: Control
var caption: Label
var buttons: Array[Button] = []

func _ready() -> void:
	var world := WORLD.instantiate()
	world.get_node("Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay/LaunchSequence").autostart = false
	add_child(world)
	_disable_tree(world)
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ink = Control.new()
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.draw.connect(_paint)
	add_child(ink)
	danger = DangerIndicator.new()
	danger.auto_advance = false
	danger.warning_duration = WARNING_TIME
	add_child(danger)
	var bar := HBoxContainer.new()
	bar.position = Vector2(155, 5)
	bar.add_theme_constant_override("separation", 3)
	add_child(bar)
	for i in 3:
		_add_button(bar, ["1 레일", "2 방위각", "3 벡터"][i], choose.bind(i))
	_add_button(bar, "L 좌", set_side.bind(false))
	_add_button(bar, "R 우", set_side.bind(true))
	var controls := HBoxContainer.new()
	controls.position = Vector2(166, 329)
	controls.add_theme_constant_override("separation", 3)
	add_child(controls)
	_add_button(controls, "Space 재생", replay)
	_add_button(controls, "P 정지", toggle_pause)
	_add_button(controls, "S 느리게", toggle_slow)
	_add_button(controls, "F1 목록", return_to_hub)
	caption = Label.new()
	caption.position = Vector2(183, 291)
	caption.visible = false
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", ICE)
	add_child(caption)
	for i in buttons.size():
		buttons[i].focus_next = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
		buttons[i].focus_previous = buttons[i].get_path_to(buttons[posmod(i - 1, buttons.size())])
	buttons[variant].grab_focus()
	_refresh()

func _disable_tree(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_disable_tree(child)

func _add_button(row: HBoxContainer, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(action)
	button.mouse_entered.connect(button.grab_focus)
	row.add_child(button)
	buttons.append(button)

func choose(index: int) -> void:
	variant = clampi(index, 0, 2)
	if not stopped: elapsed = 0.0
	_refresh()

func set_side(right: bool) -> void:
	from_right = right
	if not stopped: elapsed = 0.0
	_refresh()

func replay() -> void:
	elapsed = 0.0
	stopped = false
	_refresh()

func toggle_pause() -> void:
	stopped = not stopped
	_refresh()

func toggle_slow() -> void:
	slow = not slow
	_refresh()

func return_to_hub() -> void:
	var navigation := get_tree().root.get_node_or_null("LabReturn")
	if navigation != null:
		navigation.return_to_hub.call_deferred()
	else:
		get_tree().change_scene_to_file.call_deferred("res://lab_hub.tscn")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1: choose(0)
		KEY_2: choose(1)
		KEY_3: choose(2)
		KEY_L: set_side(false)
		KEY_R: set_side(true)
		KEY_SPACE: replay()
		KEY_P: toggle_pause()
		KEY_S: toggle_slow()
		KEY_F1: return_to_hub()
		_: return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not stopped:
		elapsed = fmod(elapsed + delta * (0.35 if slow else 1.0), 4.0)
	_refresh()

func warning_active() -> bool:
	return elapsed < WARNING_TIME

func _refresh() -> void:
	if caption == null: return
	for i in 3:
		buttons[i].modulate = ICE if i == variant else Color(0.65, 0.7, 0.8)
	caption.text = "%s   /   %s   %s\n%s  ·  VISUAL SIM / NO COMBAT" % [TITLES[variant], "PAUSED" if stopped else "0.35x" if slow else "1.00x", "RIGHT" if from_right else "LEFT", NOTES[variant]]
	danger.position = _point(153, 117)
	danger.inward_direction = Vector2.LEFT if from_right else Vector2.RIGHT
	var direction := Vector2.from_angle(deg_to_rad(ENTRY_ANGLE))
	danger.trajectory_direction = Vector2(-direction.x, direction.y) if from_right else direction
	danger.set_preview_time(elapsed)
	danger.visible = variant == 1 and warning_active()
	ink.queue_redraw()

func _point(x: float, y: float) -> Vector2:
	return Vector2(640.0 - x if from_right else x, y)

func _line(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	ink.draw_line(_point(a.x, a.y), _point(b.x, b.y), color, width, true)

func _paint() -> void:
	if elapsed >= WARNING_TIME:
		_paint_fighters()
		return
	var progress := elapsed / WARNING_TIME
	var pulse := 0.55 + 0.45 * pow(sin(progress * PI * 3.0), 2.0)
	var light := Color(BLUE, pulse)
	var dim := Color(BLUE, 0.24)
	var y := 105.0
	match variant:
		0:
			for i in 9:
				var yy := y - 40 + i * 10
				var c := light if abs(i - 4) <= int(progress * 5) else dim
				_line(Vector2(154, yy), Vector2(154, yy + 6), c, 2.0)
				_line(Vector2(158, yy), Vector2(161, yy), c)
			for i in 2:
				var x := 169.0 + i * 8 + (1.0 - progress) * 5
				_line(Vector2(x + 5, y - 7), Vector2(x, y), light, 1.5)
				_line(Vector2(x, y), Vector2(x + 5, y + 7), light, 1.5)
			_line(Vector2(187, y + 12), Vector2(263, y + 12), dim)
			_line(Vector2(187, y + 12), Vector2(187 + 76 * progress, y + 12), BLUE, 2)
		1:
			pass # The shared DangerIndicator child renders this variant.
		2:
			for offset in [-13, 13]:
				var start := Vector2(154, y + offset)
				var end := start + Vector2(97, 39)
				_line(start, end, dim)
				var scan := start.lerp(end, progress)
				_line(scan - Vector2(0, 5), scan + Vector2(0, 5), light, 2)
				_line(start + Vector2(5, -4), start, ICE)
				_line(start, start + Vector2(5, 4), ICE)
			_line(Vector2(154, y - 23), Vector2(154, y + 23), light, 2)

func _paint_fighters() -> void:
	var direction := Vector2.from_angle(deg_to_rad(ENTRY_ANGLE))
	var flight_time := elapsed - WARNING_TIME
	for i in 2:
		var pos := Vector2(133, 94 + i * 26) + direction * flight_time * 210.0
		if pos.x < 150 or pos.x > 487: continue
		var heading := Vector2(-direction.x if from_right else direction.x, direction.y)
		ink.draw_set_transform(_point(pos.x, pos.y), heading.angle() - PI * 0.5)
		ink.draw_texture_rect(FIGHTER, Rect2(-10, -12, 20, 24), false, Color(1.0, 0.6, 0.25))
	ink.draw_set_transform(Vector2.ZERO)

