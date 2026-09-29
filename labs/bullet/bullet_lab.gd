extends Control

@export var start_with_laser := false
@export var start_with_api_demo := false
@export var start_with_behavior_demo := false
@export var start_with_needle := false
@export var start_with_homing := false
@export_file("*.gd") var test_pattern_path := ""
const PATTERN_LOADER = preload("res://labs/bullet/pattern_loader.gd")
const API_PROBE = preload("res://labs/bullet/enemy_bullet_api_probe.gd")
var _custom_sequence: BarrageSequence
var _custom_path := ""
var _custom_origin := 0
## Pattern catalog: one dropdown grouped into combos (shape + motion + layout),
## fixed demos, and scripts from patterns/. Each item's metadata indexes here.
var _entries: Array[Dictionary] = []
var _entry: Dictionary = {}
var _last_item := 0
var _script_panel: PanelContainer
var _script_shade: ColorRect
var _script_button: Button
var _saved_pause := false
var _saved_focus: Control
const MIXED_SIXTEEN := preload("res://patterns/mixed_sixteen_pattern.gd")
const ROTATING_RING := preload("res://resources/projectiles/rotating_ring_sequence.tres")
const APPEARANCES: Array[BulletAppearance] = [
	preload("res://resources/projectiles/round.tres"),
	preload("res://resources/projectiles/rice.tres"),
	preload("res://resources/projectiles/orb.tres"),
]
const BEHAVIORS: Array[BulletBehavior] = [
	preload("res://resources/projectiles/straight_behavior.tres"),
	preload("res://resources/projectiles/wave_behavior.tres"),
]
const FIELD_SIZE := Vector2i(416, 288)
const SHAPES := ["원탄 · 8px", "쌀탄 · 6×12px", "대형 구탄 · 20px", "기존 기본탄", "궤적 레이저", "바늘탄 · 텍스처"]
const SHAPE_LEGACY := 3
const SHAPE_LASER := 4
const SHAPE_NEEDLE := 5
const COMBOS := [
	{"id": &"fan5", "label": "부채꼴 · 5발"},
	{"id": &"ring16", "label": "원형 · 16발"},
	{"id": &"single_down", "label": "단발 · 아래"},
	{"id": &"single_diagonal", "label": "단발 · 대각선"},
]
const DEMOS := [
	{"id": &"laser_flower", "label": "꽃잎 · 레이저 12줄", "details": "레이저 12줄 · 90px/s\n70°/s 선회 · 4초마다 15° 회전"},
	{"id": &"rotating_ring", "label": "회전 링 연속 발사", "details": "쌀탄 16발 × 6회 / 0.2초\n매회 10° 회전 → 1.2초 대기"},
	{"id": &"mixed_sixteen", "label": "16방향 · 원탄 + S 레이저", "details": "원탄 8 + 레이저 8 / 22.5°\nS자 ±35° · 주기 2.4초"},
	{"id": &"behavior_morph", "label": "Behavior · 색/크기 변화", "details": "선회 + 색 + 시각 확대\n판정은 그대로 / 3초 주기"},
	{"id": &"homing_round", "label": "호밍 · 원탄", "details": "호밍 90°/s · 추적 4초\n70px/s · WASD로 회피"},
	{"id": &"homing_laser", "label": "호밍 · 레이저", "details": "호밍 90°/s · 추적 4초\n70px/s · WASD로 회피"},
]

var world: Node2D
var target: Node2D
var hurtbox: HurtboxComponent
var safety_meter: SafeSpaceMeter
## Q/E EnemyBullets tools (see enemy_bullet_api_probe.gd).
var api_probe: Node2D
var shape_choice: OptionButton
var motion_choice: OptionButton
var pattern_choice: OptionButton
var pause_button: Button
var hitbox_button: CheckButton
var safety_button: CheckButton
var fps_label: Label
var _fps_started_usec := 0
var _fps_frames := 0
var pattern_player: BarragePlayer
var emitter: Node2D
var status_label: Label
var details_label: Label
var hits := 0
var cleared := 0
var _invincible_left := 0.0
var _controls: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Theme.new()
	theme.default_font_size = 13
	_build_field()
	_build_panel()
	_build_script_panel()
	var start_id := &"fan5"
	if start_with_laser:
		start_id = &"laser_flower"
	elif start_with_api_demo:
		start_id = &"rotating_ring"
	elif start_with_behavior_demo:
		start_id = &"mixed_sixteen"
	elif start_with_homing:
		start_id = &"homing_round"
	elif start_with_needle:
		shape_choice.select(SHAPE_NEEDLE)
		_refresh_motion_items()
		motion_choice.select(1)
	select_pattern(start_id)
	pattern_choice.grab_focus()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pattern="): test_pattern_path = argument.trim_prefix("--pattern=")
	if not test_pattern_path.is_empty(): apply_script(test_pattern_path, 0)


func _build_field() -> void:
	var background := ColorRect.new()
	background.color = Color("0a101c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var title := Label.new()
	title.text = "BULLET LAB  /  탄환 비교"
	title.position = Vector2(208, 8)
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)
	fps_label = Label.new()
	fps_label.position = Vector2(460, 12)
	fps_label.size.x = 164
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.add_theme_font_size_override("font_size", 12)
	add_child(fps_label)
	_reset_fps()
	var container := SubViewportContainer.new()
	container.name = "Field"
	container.position = Vector2(208, 38)
	container.size = FIELD_SIZE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.name = "Viewport"
	viewport.size = FIELD_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_2d = World2D.new()
	container.add_child(viewport)
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	viewport.add_child(world)
	var field_bg := Polygon2D.new()
	field_bg.polygon = PackedVector2Array([Vector2.ZERO, Vector2(416, 0), Vector2(416, 288), Vector2(0, 288)])
	field_bg.color = Color("101b2b")
	world.add_child(field_bg)
	for x in range(0, FIELD_SIZE.x, 32):
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x, 0), Vector2(x, 288)])
		line.width = 0.5
		line.default_color = Color(0.2, 0.3, 0.4, 0.3)
		world.add_child(line)
	target = Node2D.new()
	target.name = "Target"
	world.add_child(target)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(0, -9), Vector2(8, 7), Vector2(0, 3), Vector2(-8, 7)])
	body.color = Color("61cfec")
	target.add_child(body)
	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 2.0
	collision.shape = circle
	hurtbox.add_child(collision)
	target.add_child(hurtbox)
	hurtbox.hurt.connect(_on_hurt)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(0, -2), Vector2(2, 0), Vector2(0, 2), Vector2(-2, 0)])
	core.color = Color.WHITE
	target.add_child(core)
	safety_meter = SafeSpaceMeter.new()
	safety_meter.monitored_root = world
	safety_meter.player = target
	world.add_child(safety_meter)
	emitter = Node2D.new()
	emitter.name = "Emitter"
	world.add_child(emitter)
	api_probe = API_PROBE.new()
	api_probe.name = "EnemyBulletApiProbe"
	world.add_child(api_probe)
	api_probe.setup(world, target)
	pattern_player = BarragePlayer.new()
	world.add_child(pattern_player)
	status_label = Label.new()
	status_label.position = Vector2(208, 329)
	status_label.add_theme_font_size_override("font_size", 12)
	add_child(status_label)


func _build_panel() -> void:
	var panel := VBoxContainer.new()
	panel.name = "Controls"
	panel.position = Vector2(12, 10)
	panel.size = Vector2(184, 340)
	panel.add_theme_constant_override("separation", 1)
	panel.add_theme_font_size_override("font_size", 13)
	add_child(panel)
	pattern_choice = _choice(panel, [])
	_build_pattern_items()
	shape_choice = _choice(panel, SHAPES)
	motion_choice = _choice(panel, [])
	_refresh_motion_items()
	_script_button = _button(panel, "스크립트 경로 · F5 재실행", _open_script_panel)
	_script_button.add_theme_font_size_override("font_size", 12)
	pattern_choice.item_selected.connect(_selection_changed)
	shape_choice.item_selected.connect(_shape_changed)
	motion_choice.item_selected.connect(_motion_changed)
	_button(panel, "다시 발사 / 초기화", restart)
	pause_button = _button(panel, "일시정지", toggle_pause)
	hitbox_button = CheckButton.new()
	hitbox_button.text = "판정 표시"
	panel.add_child(hitbox_button)
	_controls.append(hitbox_button)
	hitbox_button.toggled.connect(_toggle_hitboxes)
	safety_button = CheckButton.new()
	safety_button.text = "안전 비율 ON"
	safety_button.button_pressed = true
	panel.add_child(safety_button)
	_controls.append(safety_button)
	safety_button.toggled.connect(_toggle_safety)
	_button(panel, "화면의 탄 소거", clear_bullets)
	details_label = Label.new()
	details_label.add_theme_font_size_override("font_size", 12)
	details_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.add_child(details_label)
	var help := Label.new()
	help.text = "WASD 이동 · Q 원형/E 빔 소거\nR 감속장 · F 흡인점 · 방향키 메뉴\n피격 코어 2px / 무적 0.6초"
	help.add_theme_font_size_override("font_size", 11)
	panel.add_child(help)
	for index in _controls.size():
		var control := _controls[index]
		control.mouse_entered.connect(control.grab_focus)
	_refresh_focus_chain()


func _refresh_focus_chain() -> void:
	var active: Array[Control] = []
	for control in _controls:
		var disabled := control is BaseButton and (control as BaseButton).disabled
		control.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
		if not disabled: active.append(control)
	for index in active.size():
		active[index].focus_neighbor_top = active[index].get_path_to(active[posmod(index - 1, active.size())])
		active[index].focus_neighbor_bottom = active[index].get_path_to(active[(index + 1) % active.size()])


func _choice(panel: VBoxContainer, items: Array) -> OptionButton:
	var choice := OptionButton.new()
	# Long script names must not widen the side panel over the field.
	choice.fit_to_longest_item = false
	choice.clip_text = true
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.custom_minimum_size.x = 184
	for item in items:
		choice.add_item(item)
	panel.add_child(choice)
	_controls.append(choice)
	return choice


func _button(panel: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	panel.add_child(button)
	_controls.append(button)
	return button


func _build_pattern_items() -> void:
	_entries.clear()
	pattern_choice.clear()
	pattern_choice.add_separator("조합 · 모양과 이동을 고름")
	for combo in COMBOS:
		_add_entry({"kind": &"combo", "id": combo.id, "label": combo.label})
	pattern_choice.add_separator("데모")
	for demo in DEMOS:
		_add_entry({"kind": &"demo", "id": demo.id, "label": demo.label, "details": demo.details})
	pattern_choice.add_separator("스크립트 · patterns/")
	for path in PATTERN_LOADER.list_patterns():
		_add_entry({"kind": &"script", "id": StringName(path), "label": path.trim_prefix("res://patterns/").trim_suffix(".gd").trim_suffix("_pattern"), "path": path})
	_add_entry({"kind": &"open_panel", "id": &"open_panel", "label": "경로 직접 열기…"})


func _add_entry(entry: Dictionary) -> void:
	_entries.append(entry)
	pattern_choice.add_item(entry.label)
	pattern_choice.set_item_metadata(pattern_choice.item_count - 1, _entries.size() - 1)


func _entry_at(item: int) -> Dictionary:
	var index = pattern_choice.get_item_metadata(item) if item >= 0 and item < pattern_choice.item_count else null
	return _entries[index] if index is int else {}


func _item_for(id: StringName) -> int:
	for item in pattern_choice.item_count:
		var entry := _entry_at(item)
		if not entry.is_empty() and entry.id == id:
			return item
	return -1


## Selected catalog id: a combo/demo id, or the res:// path of a script.
func get_pattern_id() -> StringName:
	return _entry.get("id", &"")


func is_combo() -> bool:
	return _entry.get("kind", &"") == &"combo"


## Selects and plays a catalog entry by id (combo/demo id or script path).
func select_pattern(id: StringName) -> bool:
	var item := _item_for(id)
	if item < 0:
		return false
	pattern_choice.select(item)
	_selection_changed(item)
	return true


func _selection_changed(item: int) -> void:
	var entry := _entry_at(item)
	match entry.get("kind", &""):
		&"open_panel":
			pattern_choice.select(_last_item)
			_open_script_panel()
		&"script":
			if not apply_script(entry.path, _custom_origin):
				pattern_choice.select(_last_item)
		_:
			_entry = entry
			_last_item = item
			restart()


## Motion options follow the shape: lasers turn, bullets go straight or wave,
## the legacy projectile only goes straight.
func _refresh_motion_items() -> void:
	var previous := motion_choice.selected
	motion_choice.clear()
	var items: Array
	match shape_choice.selected:
		SHAPE_LASER: items = ["오른쪽 선회", "왼쪽 선회"]
		SHAPE_LEGACY: items = ["직선 이동"]
		_: items = ["직선 이동", "파동 이동"]
	for text in items:
		motion_choice.add_item(text)
	motion_choice.select(clampi(previous, 0, items.size() - 1))


func _shape_changed(_index: int) -> void:
	_refresh_motion_items()
	restart()


func _motion_changed(_index: int) -> void:
	restart()


func restart() -> void:
	shape_choice.disabled = not is_combo()
	motion_choice.disabled = not is_combo()
	_refresh_focus_chain()
	if world.has_meta("projectile_trails"):
		var trails = world.get_meta("projectile_trails")
		if is_instance_valid(trails): trails.clear()
	_clear_world_bullets()
	pattern_player.stop()
	hits = 0
	cleared = 0
	api_probe.reset()
	_invincible_left = 0.0
	hurtbox.is_invincible = false
	target.position = Vector2(FIELD_SIZE.x * 0.5, FIELD_SIZE.y - 30)
	safety_meter.reset_measurements()
	get_tree().paused = false
	pause_button.text = "일시정지"
	start_pattern()
	details_label.text = _details_text()
	details_label.clip_text = true
	details_label.custom_minimum_size.x = 184
	_toggle_hitboxes(hitbox_button.button_pressed)
	_reset_fps()
	_update_status()


func _details_text() -> String:
	match _entry.get("kind", &""):
		&"demo":
			return _entry.details
		&"script":
			var summary := _script_summary(_custom_path)
			return _custom_path.get_file() + "\n" + (summary if not summary.is_empty() else "저장 후 F5 · 표적 WASD")
	if shape_choice.selected == SHAPE_LASER:
		return "90px/s · 몸통 1.4초\n70°/s 선회 · 4초마다 발사"
	return "속도 95px/s · 간격 0.9초\n파동: 진폭 12px / 주기 1.2초"


## First `##` doc line of a pattern script, for the details line.
func _script_summary(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("##"):
			return line.trim_prefix("##").strip_edges().trim_prefix("Showcase:").strip_edges()
	return ""


func start_pattern() -> void:
	pattern_player.show_hitbox = hitbox_button.button_pressed
	emitter.position = Vector2(FIELD_SIZE.x * 0.5, 28)
	var sequence: BarrageSequence
	match _entry.get("kind", &""):
		&"script":
			emitter.position = [Vector2(208, 28), Vector2(208, 144), Vector2(208, 260)][_custom_origin]
			sequence = _custom_sequence
		&"demo":
			sequence = _demo_sequence(_entry.id)
		_:
			if shape_choice.selected == SHAPE_LASER:
				emitter.position.y = 85
			sequence = BarrageSequence.new().fire(_make_volley())
			sequence.wait(4.0 if shape_choice.selected == SHAPE_LASER else 0.9)
			if shape_choice.selected == SHAPE_LASER and _entry.id == &"ring16":
				sequence.rotate(15)
			sequence.repeat()
	if sequence == null or not pattern_player.play(sequence, emitter, world, target):
		push_error(pattern_player.last_error)


func _demo_sequence(id: StringName) -> BarrageSequence:
	match id:
		&"laser_flower":
			emitter.position.y = 85
			var laser := BarrageShot.new()
			laser.kind = BarrageShot.Kind.TRAIL_LASER
			laser.behavior = BulletBehavior.new().turn_at(70, 1.5)
			var flower := BarrageVolley.new()
			flower.shot = laser
			flower.layout = BarrageVolley.Layout.RING
			flower.count = 12
			flower.speed = 90
			return BarrageSequence.new().fire(flower).wait(4.0).rotate(15).repeat()
		&"rotating_ring":
			return ROTATING_RING
		&"mixed_sixteen":
			emitter.position = Vector2(FIELD_SIZE) * 0.5
			return MIXED_SIXTEEN.new()
		&"behavior_morph":
			var shot := preload("res://resources/projectiles/round_straight_shot.tres").duplicate(true) as BarrageShot
			shot.behavior = BulletBehavior.new().wait(0.3).parallel([
				BulletAction.turn_by(90, 1.2),
				BulletAction.tint_to(Color(0.15, 0.7, 1.0), 1.2),
				BulletAction.visual_scale_to(2.5, 1.2),
			]).wait(0.3).opacity_to(0.15, 0.7)
			return BarrageSequence.new().fire_fan(shot, 5, 48, 70).wait(3).repeat()
		&"homing_round", &"homing_laser":
			var shot := BarrageShot.new()
			shot.appearance = APPEARANCES[0]
			shot.behavior = BulletBehavior.new().homing(90, 4)
			shot.lifetime = 6
			if id == &"homing_laser":
				shot.kind = BarrageShot.Kind.TRAIL_LASER
				shot.trail_duration = 0.7
			return BarrageSequence.new().fire_fan(shot, 3, 80, 70).wait(2).repeat()
	return null


func _make_volley() -> BarrageVolley:
	var shot := BarrageShot.new()
	if shape_choice.selected == SHAPE_LASER:
		shot.kind = BarrageShot.Kind.TRAIL_LASER
		shot.behavior = BulletBehavior.new().turn_at(-70 if motion_choice.selected == 1 else 70, 1.5)
	elif shape_choice.selected == SHAPE_LEGACY:
		shot.kind = BarrageShot.Kind.LEGACY
	else:
		shot.appearance = preload("res://resources/projectiles/needle.tres") if shape_choice.selected == SHAPE_NEEDLE else APPEARANCES[shape_choice.selected]
		shot.behavior = BEHAVIORS[motion_choice.selected]
		shot.lifetime = 8.0
		if shape_choice.selected == SHAPE_NEEDLE:
			shot.trail_effect = preload("res://resources/projectiles/diamond_trail.tres")
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.speed = 90 if shape_choice.selected == SHAPE_LASER else 95
	match _entry.get("id", &""):
		&"fan5":
			volley.layout = BarrageVolley.Layout.FAN
			volley.count = 5
		&"ring16":
			volley.layout = BarrageVolley.Layout.RING
			volley.count = 16
		&"single_diagonal":
			volley.angle_degrees = rad_to_deg(Vector2.DOWN.angle_to(Vector2(0.5, 1)))
	return volley


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "계속 재생" if get_tree().paused else "일시정지"
	_reset_fps()


func _toggle_safety(enabled: bool) -> void:
	safety_meter.set_process(enabled)
	safety_meter.reset_measurements()
	safety_button.text = "안전 비율 ON" if enabled else "안전 비율 OFF"
	_reset_fps()
	_update_status()


func _reset_fps() -> void:
	_fps_started_usec = Time.get_ticks_usec()
	_fps_frames = 0
	fps_label.text = "FPS -- | -- ms"


func _update_fps() -> void:
	_fps_frames += 1
	var elapsed := (Time.get_ticks_usec() - _fps_started_usec) / 1000000.0
	if elapsed >= 0.5:
		fps_label.text = "FPS %.0f | %.1f ms" % [_fps_frames / elapsed, elapsed * 1000.0 / _fps_frames]
		_fps_started_usec = Time.get_ticks_usec()
		_fps_frames = 0


func _update_status() -> void:
	status_label.text = "피격 %d   소거 %d   " % [hits, cleared]
	if safety_button.button_pressed:
		status_label.text += "정지 안전 %.0f%%" % (safety_meter.passive_safe_ratio * 100)
	else:
		status_label.text += "안전 비율 OFF"
	var api_summary: String = api_probe.summary()
	if not api_summary.is_empty():
		status_label.text += "   " + api_summary


func _toggle_hitboxes(enabled: bool) -> void:
	pattern_player.show_hitbox = enabled
	# New projectiles share a single instanced debug renderer.
	var legacy := is_combo() and shape_choice.selected == SHAPE_LEGACY
	get_tree().debug_collisions_hint = enabled and legacy
	var renderer = world.get_meta("projectile_renderer", null)
	if is_instance_valid(renderer):
		renderer.extra_debug_shapes.clear()
		if enabled and not legacy:
			renderer.extra_debug_shapes.append(hurtbox.get_child(0))
	for bullet in get_tree().get_nodes_in_group("enemy_projectiles"):
		if world.is_ancestor_of(bullet) and bullet is FoundationBullet:
			bullet.show_hitbox = enabled
		elif world.is_ancestor_of(bullet) and bullet is CurvedLaser:
			bullet.show_hitbox = enabled


func clear_bullets() -> void:
	cleared += _clear_world_bullets()


func _clear_world_bullets() -> int:
	return EnemyBullets.cancel_all(world, EnemyBullets.get_all(world), EnemyBullets.REASON_LAB)


func _on_hurt(_hitbox: HitboxComponent) -> void:
	if _invincible_left > 0:
		return
	hits += 1
	_invincible_left = 0.6
	hurtbox.is_invincible = true


func _process(delta: float) -> void:
	_update_fps()
	if target == null:
		return
	if not get_tree().paused:
		var movement := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		)
		target.position += movement.limit_length() * 150 * delta
		target.position = target.position.clamp(Vector2(10, 10), Vector2(FIELD_SIZE) - Vector2(10, 10))
		_invincible_left = maxf(0.0, _invincible_left - delta)
		hurtbox.is_invincible = _invincible_left > 0
		target.modulate.a = 0.4 if _invincible_left > 0 else 1.0
	_update_status()


func _exit_tree() -> void:
	get_tree().paused = false
	get_tree().debug_collisions_hint = false


func _build_script_panel() -> void:
	_script_shade = ColorRect.new()
	_script_shade.color = Color(0, 0, 0, 0.8)
	_script_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_script_shade.hide()
	add_child(_script_shade)
	_script_panel = PanelContainer.new()
	_script_panel.set_script(preload("res://labs/bullet/pattern_panel.gd"))
	_script_shade.add_child(_script_panel)
	_script_panel.apply_requested.connect(apply_script)
	_script_panel.close_requested.connect(_close_script_panel)


func _open_script_panel() -> void:
	if not _script_shade.visible:
		_saved_pause = get_tree().paused
		_saved_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	for control in _controls: control.focus_mode = Control.FOCUS_NONE
	_script_shade.show()
	_script_panel.refresh(_custom_path if not _custom_path.is_empty() else "res://patterns/lab_example_pattern.gd", _custom_origin)


func _close_script_panel() -> void:
	_script_shade.hide()
	_refresh_focus_chain()
	get_tree().paused = _saved_pause
	if is_instance_valid(_saved_focus): _saved_focus.grab_focus()
	else: _script_button.grab_focus()
	_reset_fps()


func apply_script(path: String, origin_index: int) -> bool:
	var result := PATTERN_LOADER.load_pattern(path)
	if not result.error.is_empty():
		_open_script_panel()
		_script_panel.path_input.text = path
		_script_panel.origin_choice.select(clampi(origin_index, 0, 2))
		_script_panel.error_label.text = result.error
		return false
	_custom_sequence = result.sequence
	_custom_path = result.path
	_custom_origin = clampi(origin_index, 0, 2)
	_script_shade.hide()
	_select_script_entry(_custom_path)
	restart()
	_script_button.grab_focus()
	return true


## Points the dropdown at a script path, adding a "직접 · file" item for paths
## outside patterns/ (reused for the next such path).
func _select_script_entry(path: String) -> void:
	var item := _item_for(StringName(path))
	if item < 0:
		item = _item_for(&"custom")
		if item < 0:
			var open_item := _item_for(&"open_panel")
			_entries.append({"kind": &"script", "id": &"custom", "label": "", "path": path})
			pattern_choice.add_item("", -1)
			# Move the new item above "경로 직접 열기…".
			pattern_choice.set_item_text(pattern_choice.item_count - 1, pattern_choice.get_item_text(open_item))
			pattern_choice.set_item_metadata(pattern_choice.item_count - 1, pattern_choice.get_item_metadata(open_item))
			item = open_item
			pattern_choice.set_item_metadata(item, _entries.size() - 1)
		_entries[pattern_choice.get_item_metadata(item)].path = path
		pattern_choice.set_item_text(item, "직접 · " + path.get_file())
	pattern_choice.select(item)
	_entry = _entry_at(item)
	_last_item = item


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE and _script_shade.visible:
		_close_script_panel()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F5:
		if _script_shade.visible:
			apply_script(_script_panel.path_input.text, _script_panel.origin_choice.selected)
		elif not _custom_path.is_empty(): apply_script(_custom_path, _custom_origin)
		else: _open_script_panel()
		get_viewport().set_input_as_handled()
