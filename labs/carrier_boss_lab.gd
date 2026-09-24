extends Control
const Boss = preload("res://labs/carrier_lab_boss.gd")
var viewport: SubViewport
var world: Node2D
var ship: Node2D
var boss: Node2D
var bar: ProgressBar
var phase_label: Label
var metrics: Label
var hits := 0
var elapsed := 0.0
var restarting := false
var pause_button: Button
var camera: Camera2D
var camera_tween: Tween
var shake_strength := 0.0
var shake_age := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop := ColorRect.new()
	backdrop.color = Color("090e18")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var container := SubViewportContainer.new()
	container.position = Vector2(200,0)
	container.size = Vector2(240,360)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(240,360)
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var left := VBoxContainer.new()
	left.position = Vector2(12,16)
	left.size = Vector2(176,310)
	left.add_theme_constant_override("separation",8)
	add_child(left)
	add_label(left,"AFTERBURN\nBOSS LAB",18)
	add_label(left,"거대 항모 공략\n\nWASD / 방향키 이동 · 자동 사격\n\n훈련 모드 · 생존 보장\n피격 횟수로 회피 확인",12)
	var restart_button := Button.new()
	restart_button.text = "다시 시작  [R]"
	left.add_child(restart_button)
	restart_button.pressed.connect(restart)
	pause_button = Button.new()
	pause_button.text = "일시정지  [P]"
	left.add_child(pause_button)
	pause_button.pressed.connect(toggle_pause)
	var back := Button.new()
	back.text = "Lab 목록  [F1]"
	left.add_child(back)
	back.pressed.connect(return_to_hub)
	var buttons := [restart_button, pause_button, back]
	for i in buttons.size():
		buttons[i].add_theme_font_size_override("font_size",13)
		buttons[i].custom_minimum_size.y = 28
		buttons[i].mouse_entered.connect(buttons[i].grab_focus)
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[posmod(i-1,3)])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i+1)%3])
	restart_button.grab_focus()
	var right := VBoxContainer.new()
	right.position = Vector2(454,24)
	right.size = Vector2(174,310)
	add_child(right)
	add_label(right,"CARRIER / 01",18)
	add_label(right,"함미 → 격납고 → 함교\n\n밝은 부위를 공격하세요.\n갑판 위로 비행할 수 있습니다.\n\n부위 파괴 시 공격 중단\n격납고 파괴 시 출격 중단\n\n상단 바 = 필수 부위 HP 합계\n함재기는 전체 HP에서 제외",12)
	metrics = add_label(right,"",14)
	var hud := VBoxContainer.new()
	hud.position = Vector2(208,3)
	hud.size.x = 224
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	phase_label = add_label(hud,"",10)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(224,8)
	bar.show_percentage = false
	bar.max_value = 800
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ff426d")
	bar.add_theme_stylebox_override("fill",fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("283448")
	track.border_color = Color("8f9dad")
	track.set_border_width_all(1)
	bar.add_theme_stylebox_override("background",track)
	hud.add_child(bar)
	for ratio in [0.3, 0.7]:
		var divider := ColorRect.new()
		divider.color = Color("090e18")
		divider.position = Vector2(224 * ratio,0)
		divider.size = Vector2(1,8)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(divider)
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
	shake_strength = 0
	shake_age = 0
	camera = Camera2D.new()
	camera.position = Vector2(120,180)
	world.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
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
	var background := preload("res://labs/carrier_lab_background.gd").new()
	world.add_child(background)
	var registry := PlayerAugmentRegistry.new()
	world.add_child(registry)
	ship = preload("res://player_ship/ship.tscn").instantiate()
	ship.augment_registry = registry
	ship.position = Vector2(120,300)
	world.add_child(ship)
	ship.get_node("StatsComponent").health = 1000000
	ship.get_node("PlayerHitPoint/HurtboxComponent").hurt.connect(func(_hit): hits += 1)
	boss = Boss.new()
	boss.world = world
	boss.target = ship
	boss.health_changed.connect(func(current: int, _maximum: int): bar.value = current)
	boss.section_changed.connect(func(title: String): phase_label.text = title)
	boss.destruction_started.connect(_begin_destruction_shot)
	boss.destruction_pulse.connect(func(strength: float): shake_strength = maxf(shake_strength,strength))
	world.add_child(boss)
	world.move_child(boss,0)
	hits = 0
	elapsed = 0
	bar.value = 800
	restarting = false

func _begin_destruction_shot() -> void:
	# Keep the player's silhouette in the foreground as the carrier falls away.
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	var foreground := CanvasLayer.new()
	foreground.layer = 2
	world.add_child(foreground)
	ship.reparent(foreground)
	for child in world.get_children():
		if child.get_script() == preload("res://projectiles/player_blaster.gd"):
			child.queue_free()
	# Bind the camera timeline to the disposable, pausable Lab world.
	camera_tween = world.create_tween()
	camera_tween.tween_interval(0.35)
	camera_tween.tween_property(camera,"zoom",Vector2.ONE*0.28,3.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	camera_tween.parallel().tween_property(camera,"position",boss.to_global(Vector2(0,-350)),3.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	if restarting or not is_instance_valid(ship): return
	if not get_tree().paused:
		if not boss.defeated: elapsed += delta
		if not boss.defeated: ship.position = ship.position.clamp(Vector2(10,55),Vector2(230,346))
		shake_age += delta
		shake_strength = move_toward(shake_strength,0,delta*4)
		camera.offset = Vector2(sin(shake_age*71),cos(shake_age*57)) * shake_strength / camera.zoom.x
		if ship.get_node("StatsComponent").health < 1000000:
			ship.get_node("StatsComponent").health = 1000000
	metrics.text = "\n피격  %d\n시간  %.1fs\nHP  %d / 800" % [hits,elapsed,boss.health]

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "계속  [P]" if get_tree().paused else "일시정지  [P]"

func return_to_hub() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://labs/lab_hub.tscn")
	var navigation := get_tree().root.get_node_or_null("LabReturn")
	if navigation != null: navigation.queue_free()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_R: restart()
		KEY_P: toggle_pause()
		KEY_F1: return_to_hub.call_deferred()
		_: return
	get_viewport().set_input_as_handled()
