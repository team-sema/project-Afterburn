extends Control
const Playfield = preload("res://menus/playfield_layout.gd")
const Boss = preload("res://enemies/octagon/octagon_boss.gd")
var viewport: SubViewport
var world: Node2D
var ship: Node2D
var boss: Node2D
var bar: ProgressBar
var phase_label: Label
var metrics: Label
var pause_button: Button
var hits := 0
var elapsed := 0.0
var restarting := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop := ColorRect.new()
	backdrop.color = Color("090e18")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var container := SubViewportContainer.new()
	container.position.x = Playfield.SIDE_PANEL_WIDTH
	container.size = Vector2(Playfield.SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Playfield.SIZE
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var left := VBoxContainer.new()
	left.position = Vector2(12,16)
	left.size = Vector2(146,320)
	left.add_theme_constant_override("separation",8)
	add_child(left)
	add_label(left,"AFTERBURN\nBOSS LAB",18)
	add_label(left,"옥타곤 · 회전 방어환\n\nWASD / 방향키 이동\n자동 사격 · 생존 보장",12)
	var buttons: Array[Button] = []
	for entry in [["다시 시작  [R]",restart],["일시정지  [P]",toggle_pause],["다음 모듈 쌍  [N]",next_pair],["Lab 목록  [F1]",return_to_hub]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 28
		button.add_theme_font_size_override("font_size",12)
		left.add_child(button)
		button.pressed.connect(entry[1])
		button.mouse_entered.connect(button.grab_focus)
		buttons.append(button)
	pause_button = buttons[1]
	for i in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[posmod(i-1,buttons.size())])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i+1)%buttons.size()])
	buttons[0].grab_focus()
	var right := VBoxContainer.new()
	right.position = Vector2(484,18)
	right.size = Vector2(144,320)
	add_child(right)
	add_label(right,"OCTAGON / LAB",16)
	add_label(right,"BROKEN ORBIT\n\n8개 공통 포탑\n인접한 두 개씩 교전\n\n개방 → 사격\n폐쇄 → 회전\n\n열린 포탑을 공격하세요.\n파괴한 잔해는\n고리와 함께 돌아옵니다.",11)
	metrics = add_label(right,"",11)
	var hud := VBoxContainer.new()
	hud.position = Vector2(178,3)
	hud.size.x = 284
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	phase_label = add_label(hud,"",10)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(284,6)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ff426d")
	bar.add_theme_stylebox_override("fill",fill)
	hud.add_child(bar)
	restart()

func add_label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func restart() -> void:
	if restarting: return
	restarting = true
	get_tree().paused = false
	pause_button.text = "일시정지  [P]"
	if is_instance_valid(world):
		world.queue_free()
		await get_tree().process_frame
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_to_group("gameplay_world")
	viewport.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.45
	environment.glow_strength = 0.65
	environment.glow_bloom = 0.06
	environment.glow_hdr_threshold = 1.05
	environment_node.environment = environment
	world.add_child(environment_node)
	var background := preload("res://effects/space_background.tscn").instantiate()
	background.backdrop = background.backdrop.duplicate()
	background.backdrop.orbital_ring_enabled = false
	world.add_child(background)
	for layer in background.get_children():
		if layer is CanvasItem: layer.modulate = Color(0.25,0.25,0.25,1)
	var registry := PlayerAugmentRegistry.new()
	world.add_child(registry)
	ship = preload("res://player_ship/ship.tscn").instantiate()
	ship.augment_registry = registry
	ship.position = Vector2(150,300)
	world.add_child(ship)
	ship.get_node("StatsComponent").health = 1000000
	ship.get_node("PlayerHitPoint/HurtboxComponent").hurt.connect(func(_hit): hits += 1)
	boss = Boss.new()
	boss.world = world
	world.add_child(boss)
	bar.max_value = boss.maximum
	bar.value = boss.health
	boss.health_changed.connect(func(current: int, _max: int): bar.value = current)
	hits = 0
	elapsed = 0
	restarting = false

func _process(delta: float) -> void:
	if restarting or not is_instance_valid(ship): return
	if not get_tree().paused:
		if not boss.defeated: elapsed += delta
		ship.position = ship.position.clamp(Vector2(10,160),Vector2(290,346))
		ship.get_node("StatsComponent").health = 1000000
	phase_label.text = boss.status_text()
	var alive := 0
	for part in boss.parts:
		if part.health > 0: alive += 1
	metrics.text = "\n남은 모듈  %d / 8\n피격  %d\n시간  %.1fs\nHP  %d / %d" % [alive,hits,elapsed,boss.health,boss.maximum]

func next_pair() -> void:
	if restarting or not is_instance_valid(boss) or get_tree().paused: return
	boss.next_pair()

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "계속  [P]" if get_tree().paused else "일시정지  [P]"

func return_to_hub() -> void:
	var tree := get_tree()
	var navigation := tree.root.get_node_or_null("LabReturn")
	if navigation != null: navigation.queue_free()
	tree.paused = false
	tree.change_scene_to_file("res://lab_hub.tscn")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_R: restart()
		KEY_P: toggle_pause()
		KEY_N: next_pair()
		KEY_F1: return_to_hub.call_deferred()
		_: return
	get_viewport().set_input_as_handled()
