extends Control
## Standalone RECYCLER fight. Two ways in: straight to the boss, or the whole phase — the real gameplay
## assembly runs the main encounter pattern (minus its BOSS token) down the approach route, then the bay closes.
const Playfield = preload("res://menus/playfield_layout.gd")
const Boss = preload("res://labs/bosses/wall/wall_boss.gd")
const Background = preload("res://labs/bosses/wall/wall_background.gd")
const Approach = preload("res://labs/bosses/wall/wall_approach.gd")
const GAMEPLAY := preload("res://gameplay.tscn")
const MAIN_SEQUENCE := preload("res://resources/encounter_sequences/main_encounter_sequence.tres")
const SHIP_HEALTH := 1000000

enum Mode { BOSS_ONLY, FULL_PHASE }

var mode := Mode.BOSS_ONLY
var viewport: SubViewport
var world: Node2D
var ship: Node2D
var boss: Node2D
var background: Node
var approach: Node
var director: EncounterDirector
var camera: Camera2D
var bar: ProgressBar
var phase_label: Label
var metrics: Label
var pause_button: Button
var mode_buttons: Array[Button] = []
var hits := 0
var elapsed := 0.0
var restarting := false
var shake_strength := 0.0
var shake_age := 0.0
var route_progress := 0.0
var route_step := 0
var route_step_count := 0
var _phase_run := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop := ColorRect.new()
	backdrop.color = Color("090e18")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var container := SubViewportContainer.new()
	container.position = Vector2(Playfield.SIDE_PANEL_WIDTH, 0)
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
	left.size = Vector2(Playfield.SIDE_PANEL_WIDTH - 24, 310)
	left.add_theme_constant_override("separation",6)
	add_child(left)
	add_label(left,"AFTERBURN\nBOSS LAB",18)
	add_label(left,"자동 해체시설 공략\n\nWASD / 방향키 이동 · 자동 사격\n훈련 모드 · 생존 보장",12)
	var boss_button := Button.new()
	boss_button.pressed.connect(set_mode.bind(Mode.BOSS_ONLY))
	var phase_button := Button.new()
	phase_button.pressed.connect(set_mode.bind(Mode.FULL_PHASE))
	mode_buttons = [boss_button, phase_button]
	var restart_button := Button.new()
	restart_button.text = "다시 시작  [R]"
	restart_button.pressed.connect(restart)
	pause_button = Button.new()
	pause_button.text = "일시정지  [P]"
	pause_button.pressed.connect(toggle_pause)
	var back := Button.new()
	back.text = "Lab 목록  [F1]"
	back.pressed.connect(return_to_hub)
	var buttons := [boss_button, phase_button, restart_button, pause_button, back]
	for i in buttons.size():
		left.add_child(buttons[i])
		buttons[i].add_theme_font_size_override("font_size",13)
		buttons[i].custom_minimum_size.y = 26
		buttons[i].mouse_entered.connect(buttons[i].grab_focus)
	for i in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[posmod(i-1,buttons.size())])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i+1)%buttons.size()])
	_refresh_mode_buttons()
	boss_button.grab_focus()
	var right := VBoxContainer.new()
	right.position = Vector2(Playfield.SIDE_PANEL_WIDTH + Playfield.SIZE.x + 14, 24)
	right.size = Vector2(Playfield.SIDE_PANEL_WIDTH - 26, 310)
	add_child(right)
	add_label(right,"RECYCLER",18)
	add_label(right,"압착 격벽 → 절단 광학기 → 압착 프레스\n\n밝은 부위를 공격하세요.\n부위를 부수면 공간이 돌아옵니다.\n\n돌진한 벽의 외장 커버가 6초간 열림\n벽 광학기는 레이저와 함께 내려옴\n제어 링크를 모두 끊으면 시설 정지\n\n예고된 돌진·압착에 밀리면 피격",12)
	metrics = add_label(right,"",14)
	var hud := VBoxContainer.new()
	hud.position = Vector2(Playfield.SIDE_PANEL_WIDTH + 8, 3)
	hud.size.x = Playfield.SIZE.x - 16
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	phase_label = add_label(hud,"",10)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(Playfield.SIZE.x - 16, 8)
	bar.show_percentage = false
	bar.max_value = Boss.MAX_HEALTH
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ff426d")
	bar.add_theme_stylebox_override("fill",fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("283448")
	track.border_color = Color("8f9dad")
	track.set_border_width_all(1)
	bar.add_theme_stylebox_override("background",track)
	hud.add_child(bar)
	# Section borders: covers 300 / optics 280 / links 270.
	for ratio in [300.0 / Boss.MAX_HEALTH, 580.0 / Boss.MAX_HEALTH]:
		var divider := ColorRect.new()
		divider.color = Color("090e18")
		divider.position = Vector2((Playfield.SIZE.x - 16) * (1.0 - ratio),0)
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

func set_mode(next_mode: Mode) -> void:
	mode = next_mode
	_refresh_mode_buttons()
	restart()

func _refresh_mode_buttons() -> void:
	mode_buttons[0].text = ("▶ " if mode == Mode.BOSS_ONLY else "") + "보스 즉시  [1]"
	mode_buttons[1].text = ("▶ " if mode == Mode.FULL_PHASE else "") + "페이즈 처음부터  [2]"

## The main pattern without its BOSS token, stopping at the end: the Lab hands over to the bay itself.
static func phase_sequence() -> EncounterSequence:
	var sequence := EncounterSequence.new()
	sequence.sequence_id = &"wall_lab_phase"
	sequence.on_complete = EncounterSequence.OnComplete.STOP
	sequence.shared_steps = MAIN_SEQUENCE.shared_steps
	for source in MAIN_SEQUENCE.phases:
		var phase := EncounterSequencePhase.new()
		phase.phase_id = source.phase_id
		phase.repeat_count = source.repeat_count
		phase.steps = source.steps
		var kept := PackedStringArray()
		for token in source.get_tokens():
			var step := MAIN_SEQUENCE.resolve_step(source, StringName(token))
			if step != null and step.kind == EncounterSequenceStep.Kind.BOSS: continue
			kept.append(token)
		phase.pattern = " ".join(kept)
		sequence.phases.append(phase)
	return sequence

func restart() -> void:
	if restarting: return
	restarting = true
	_phase_run += 1
	get_tree().paused = false
	pause_button.text = "일시정지  [P]"
	if is_instance_valid(world):
		world.queue_free()
		await get_tree().process_frame
	boss = null
	director = null
	hits = 0
	elapsed = 0
	shake_strength = 0
	shake_age = 0
	route_progress = 0.0
	route_step = 0
	route_step_count = 0
	if mode == Mode.FULL_PHASE:
		# The real run assembly: registries, offers, elite gates and the director all come along.
		var gameplay := GAMEPLAY.instantiate()
		director = gameplay.get_node("EncounterDirector") as EncounterDirector
		director.autostart = false
		var stock_background := gameplay.get_node("SpaceBackground")
		gameplay.remove_child(stock_background)
		stock_background.free()
		world = gameplay
	else:
		world = Node2D.new()
		world.add_to_group("gameplay_world")
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	viewport.add_child(world)
	camera = Camera2D.new()
	camera.position = Playfield.CENTER
	world.add_child(camera)
	camera.make_current()
	if mode == Mode.BOSS_ONLY:
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
	background = Background.new()
	world.add_child(background)
	approach = null
	if mode == Mode.FULL_PHASE:
		approach = Approach.new()
		world.add_child(approach)
		ship = world.get_node("Ship")
	else:
		var registry := PlayerAugmentRegistry.new()
		world.add_child(registry)
		ship = preload("res://player_ship/ship.tscn").instantiate()
		ship.augment_registry = registry
		world.add_child(ship)
	ship.position = Vector2(Playfield.CENTER.x, 300)
	ship.get_node("StatsComponent").health = SHIP_HEALTH
	ship.get_node("PlayerHitPoint/HurtboxComponent").hurt.connect(func(_hit): hits += 1)
	bar.value = Boss.MAX_HEALTH
	bar.visible = mode == Mode.BOSS_ONLY
	restarting = false
	if mode == Mode.FULL_PHASE:
		start_phase()
	else:
		_spawn_boss()

## Runs the approach: the pattern plays, the route advances, and once the field is clear the bay takes over.
func start_phase(sequence_override: EncounterSequence = null) -> bool:
	if director == null or not is_instance_valid(world): return false
	var run := _phase_run
	var sequence := sequence_override if sequence_override != null else phase_sequence()
	director.sequence_progress_changed.connect(_on_route_progress)
	director.sequence_completed.connect(func(_id: StringName): _on_phase_cleared(run), CONNECT_ONE_SHOT)
	phase_label.text = Approach.beat_title(0.0)
	return director.start_sequence(sequence)

func _on_route_progress(_stage: int, step_index: int, step_count: int, _token: StringName, kind: EncounterSequenceStep.Kind) -> void:
	route_step = step_index
	route_step_count = step_count
	route_progress = float(step_index) / float(step_count + 1)
	if approach != null: approach.progress = route_progress
	var title := "HULL GATE / ELITE" if kind == EncounterSequenceStep.Kind.ELITE else Approach.beat_title(route_progress)
	phase_label.text = "%s   %02d / %02d" % [title, step_index, step_count]

func _on_phase_cleared(run: int) -> void:
	if run != _phase_run or not is_instance_valid(world): return
	route_progress = 1.0
	if approach != null: approach.progress = 1.0
	phase_label.text = Approach.beat_title(1.0)
	# Same rule as the BOSS token: the bay only closes once the corridor is clear.
	while run == _phase_run and is_instance_valid(world) and director.get_active_encounter_count() > 0:
		await get_tree().process_frame
	if run != _phase_run or not is_instance_valid(world): return
	var warning := EncounterStepWarning.present(world, EncounterSequenceStep.Kind.BOSS, 0.8)
	await warning.finished
	if run != _phase_run or not is_instance_valid(world): return
	_spawn_boss()

func _spawn_boss() -> void:
	boss = Boss.new()
	boss.world = world
	boss.target = ship
	boss.background = background
	boss.health_changed.connect(func(current: int, _maximum: int): bar.value = current)
	boss.section_changed.connect(func(title: String): phase_label.text = title)
	boss.pulse.connect(func(strength: float): shake_strength = maxf(shake_strength,strength))
	world.add_child(boss)
	world.move_child(boss,0)
	bar.value = Boss.MAX_HEALTH
	bar.visible = true

func _process(delta: float) -> void:
	if restarting or not is_instance_valid(ship): return
	var boss_live := is_instance_valid(boss)
	if not get_tree().paused:
		if not (boss_live and boss.defeated): elapsed += delta
		shake_age += delta
		shake_strength = move_toward(shake_strength,0,delta*4)
		camera.offset = Vector2(sin(shake_age*71),cos(shake_age*57)) * shake_strength
		if ship.get_node("StatsComponent").health < SHIP_HEALTH:
			ship.get_node("StatsComponent").health = SHIP_HEALTH
	if approach != null and background != null:
		approach.speed_scale = background.speed_scale
	if boss_live:
		metrics.text = "\n피격  %d\n시간  %.1fs\nHP  %d / %d" % [hits,elapsed,boss.health,Boss.MAX_HEALTH]
	else:
		metrics.text = "\n피격  %d\n시간  %.1fs\n구간  %02d / %02d" % [hits,elapsed,route_step,route_step_count]

func toggle_pause() -> void:
	# An augment offer owns the pause while it is open; the Lab key must not release it.
	if world != null and is_instance_valid(world):
		var offer := world.get_node_or_null("AugmentOfferController")
		if offer != null and bool(offer.get("is_offer_active")): return
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
		KEY_1: set_mode(Mode.BOSS_ONLY)
		KEY_2: set_mode(Mode.FULL_PHASE)
		KEY_R: restart()
		KEY_P: toggle_pause()
		KEY_F1: return_to_hub.call_deferred()
		_: return
	get_viewport().set_input_as_handled()
