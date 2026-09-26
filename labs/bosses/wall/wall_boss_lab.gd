extends Control
## Standalone Boss Wall fight: the in-game enemies/boss_wall.tscn against the real ship.
const WALL_SCENE := preload("res://enemies/boss_wall.tscn")
const ENTRY := preload("res://resources/enemy_movement/sequences/boss_wall_entry_hold.tres")
const PHASE_TITLES := {&"entry": "진입", &"rest": "회피", &"appear": "포탑 등장", &"fire": "사격 · 코어 노출", &"core_linger": "코어 추가 노출", &"disappear": "포탑 퇴장"}
var viewport: SubViewport
var world: Node2D
var ship: Node2D
var boss: Enemy
var cycle: BossWallTurretCycleComponent
var bar: ProgressBar
var phase_label: Label
var metrics: Label
var pause_button: Button
var hits := 0
var elapsed := 0.0
var max_health := 0
var defeated := false
var restarting := false

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
	add_label(left,"벽 공략\n\nWASD / 방향키 이동 · 자동 사격\n\n훈련 모드 · 생존 보장\n피격 횟수로 회피 확인",12)
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
	add_label(right,"WALL / 00",18)
	add_label(right,"회피 → 포탑·코어 등장 → 코어 공격\n\n벽 본체는 피해 8%만 받습니다.\n열린 슬롯의 마젠타 코어를 노리세요.\n포탑을 모두 부수면 코어가 더 오래 노출됩니다.",12)
	# The wall covers the top band, so the phase reads from the side panel instead.
	phase_label = add_label(right,"",14)
	metrics = add_label(right,"",14)
	var hud := VBoxContainer.new()
	hud.position = Vector2(208,6)
	hud.size.x = 224
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(224,8)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ff426d")
	bar.add_theme_stylebox_override("fill",fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("283448")
	track.border_color = Color("8f9dad")
	track.set_border_width_all(1)
	bar.add_theme_stylebox_override("background",track)
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
	world.add_child(preload("res://effects/space_background.tscn").instantiate())
	var player_registry := PlayerAugmentRegistry.new()
	world.add_child(player_registry)
	ship = preload("res://player_ship/ship.tscn").instantiate()
	ship.augment_registry = player_registry
	ship.position = Vector2(120,300)
	world.add_child(ship)
	ship.get_node("StatsComponent").health = 1000000
	ship.get_node("PlayerHitPoint/HurtboxComponent").hurt.connect(func(_hit): hits += 1)
	var enemy_registry := EnemyAugmentRegistry.new()
	world.add_child(enemy_registry)
	boss = WALL_SCENE.instantiate() as Enemy
	boss.augment_registry = enemy_registry
	boss.is_boss = true
	boss.position = Vector2(120,-32)
	world.add_child(boss)
	boss.set_movement_sequence(ENTRY)
	cycle = boss.get_node("BossWallTurretCycle") as BossWallTurretCycleComponent
	boss.stats_component.no_health.connect(func(): defeated = true)
	max_health = boss.stats_component.health
	bar.max_value = max_health
	bar.value = max_health
	hits = 0
	elapsed = 0
	defeated = false
	restarting = false

func _process(delta: float) -> void:
	if restarting or not is_instance_valid(ship): return
	if not get_tree().paused:
		if not defeated: elapsed += delta
		if ship.get_node("StatsComponent").health < 1000000:
			ship.get_node("StatsComponent").health = 1000000
	var health := boss.stats_component.health if is_instance_valid(boss) and not defeated else 0
	bar.value = health
	phase_label.text = "\n격파" if defeated else "\n단계  " + PHASE_TITLES.get(cycle.get("_phase"), "")
	metrics.text = "피격  %d\n시간  %.1fs\nHP  %d / %d" % [hits,elapsed,health,max_health]

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
		KEY_F1: return_to_hub.call_deferred()
		_: return
	get_viewport().set_input_as_handled()
