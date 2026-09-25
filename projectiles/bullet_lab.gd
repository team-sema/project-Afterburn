extends Control

@export var start_with_laser := false
@export var start_with_api_demo := false
@export var start_with_behavior_demo := false
@export var start_with_needle := false
@export var start_with_homing := false
@export_file("*.gd") var test_pattern_path := ""
const PATTERN_LOADER = preload("res://labs/pattern_loader.gd")
var _custom_sequence: BarrageSequence
var _custom_path := ""
var _custom_origin := 0
var _last_pattern := 0
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

var world: Node2D
var target: Node2D
var hurtbox: HurtboxComponent
var safety_meter: SafeSpaceMeter
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
	if start_with_laser:
		shape_choice.select(4)
		motion_choice.select(2)
		pattern_choice.select(4)
	elif start_with_api_demo:
		shape_choice.select(1)
		pattern_choice.select(5)
	elif start_with_behavior_demo:
		pattern_choice.select(6)
	elif start_with_needle:
		shape_choice.select(5)
		motion_choice.select(1)
	elif start_with_homing:
		pattern_choice.select(8)
	restart()
	shape_choice.grab_focus()
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
	_script_button = _button(panel, "스크립트 열기 · F5 재실행", _open_script_panel)
	_script_button.add_theme_font_size_override("font_size", 12)
	shape_choice = _choice(panel, ["원탄 · 8px", "쌀탄 · 6×12px", "대형 구탄 · 20px", "기존 기본탄", "곡선 레이저", "바늘탄 · 텍스처"])
	motion_choice = _choice(panel, ["직선 이동", "파동 이동", "레이저 · 오른쪽 선회", "레이저 · 왼쪽 선회"])
	pattern_choice = _choice(panel, ["부채꼴 · 5발", "원형 · 16발", "단발 · 아래", "단발 · 대각선", "꽃잎 · 레이저 12줄", "API · 회전 링 연속 발사", "16방향 · 원탄 + S 레이저", "Behavior · 색/크기 변화", "호밍 · 원탄", "호밍 · 레이저", "스크립트 · 사용자 패턴"])
	shape_choice.item_selected.connect(_shape_changed)
	motion_choice.item_selected.connect(_motion_changed)
	pattern_choice.item_selected.connect(_selection_changed)
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
	panel.add_child(details_label)
	var help := Label.new()
	help.text = "WASD  기체 이동\n방향키 + Enter  메뉴\n피격 코어 2px / 무적 0.6초"
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


func _selection_changed(_index: int) -> void:
	if pattern_choice.selected == 10:
		pattern_choice.select(_last_pattern)
		_open_script_panel()
		return
	if pattern_choice.selected >= 6:
		shape_choice.select(0)
		motion_choice.select(0)
		restart()
		return
	if pattern_choice.selected == 5:
		shape_choice.select(1)
		motion_choice.select(0)
		restart()
		return
	if shape_choice.selected == 4:
		if motion_choice.selected < 2:
			motion_choice.select(2)
	elif pattern_choice.selected == 4:
		shape_choice.select(4)
		motion_choice.select(2)
	elif motion_choice.selected >= 2:
		motion_choice.select(0)
	if shape_choice.selected == 3:
		motion_choice.select(0)
	restart()


func _shape_changed(index: int) -> void:
	if pattern_choice.selected >= 5:
		pattern_choice.select(0)
	if index == 4:
		pattern_choice.select(4)
	elif pattern_choice.selected == 4:
		pattern_choice.select(0)
	_selection_changed(index)


func _motion_changed(index: int) -> void:
	if pattern_choice.selected >= 5:
		pattern_choice.select(0)
	if index >= 2:
		shape_choice.select(4)
	elif shape_choice.selected == 4:
		shape_choice.select(0)
		if pattern_choice.selected == 4:
			pattern_choice.select(0)
	if shape_choice.selected == 3 and index == 1:
		shape_choice.select(0)
	restart()


func restart() -> void:
	_last_pattern = pattern_choice.selected
	shape_choice.disabled = pattern_choice.selected == 10
	motion_choice.disabled = pattern_choice.selected == 10
	_refresh_focus_chain()
	if world.has_meta("projectile_trails"):
		var trails = world.get_meta("projectile_trails")
		if is_instance_valid(trails): trails.clear()
	_clear_world_bullets()
	pattern_player.stop()
	hits = 0
	cleared = 0
	_invincible_left = 0.0
	hurtbox.is_invincible = false
	target.position = Vector2(FIELD_SIZE.x * 0.5, FIELD_SIZE.y - 30)
	safety_meter.reset_measurements()
	get_tree().paused = false
	pause_button.text = "일시정지"
	start_pattern()
	details_label.text = "속도 95px/s · 간격 0.9초\n파동: 진폭 12px / 주기 1.2초"
	if shape_choice.selected == 4:
		details_label.text = "90px/s · 몸통 1.4초\n70°/s 선회 · 4초마다 발사"
	if pattern_choice.selected == 5:
		details_label.text = "API: 16발 × 6회 / 0.2초\n매회 10° 회전 → 1.2초 대기"
	elif pattern_choice.selected == 6:
		details_label.text = "원탄 8 + 레이저 8 / 22.5°\nS자 ±35° · 주기 2.4초"
	elif pattern_choice.selected == 7:
		details_label.text = "선회 + 색 + 시각 확대\n판정은 그대로 / 3초 주기"
	elif pattern_choice.selected in [8, 9]:
		details_label.text = "호밍 90°/s · 추적 4초\n70px/s · WASD로 회피"
	elif pattern_choice.selected == 10:
		details_label.text = _custom_path.get_file() + "\n저장 후 F5 · 표적 WASD"
	details_label.clip_text = true
	details_label.custom_minimum_size.x = 184
	_toggle_hitboxes(hitbox_button.button_pressed)
	_reset_fps()
	_update_status()


func start_pattern() -> void:
	pattern_player.show_hitbox = hitbox_button.button_pressed
	emitter.position = Vector2(FIELD_SIZE.x * 0.5, 85 if shape_choice.selected == 4 else 28)
	var sequence: BarrageSequence
	if pattern_choice.selected == 10 and _custom_sequence != null:
		emitter.position = [Vector2(208, 28), Vector2(208, 144), Vector2(208, 260)][_custom_origin]
		sequence = _custom_sequence
	elif pattern_choice.selected == 5:
		sequence = ROTATING_RING
	elif pattern_choice.selected == 6:
		emitter.position = Vector2(FIELD_SIZE) * 0.5
		sequence = MIXED_SIXTEEN.new()
	elif pattern_choice.selected == 7:
		var shot := preload("res://resources/projectiles/round_straight_shot.tres").duplicate(true) as BarrageShot
		shot.behavior = BulletBehavior.new().wait(0.3).parallel([
			BulletAction.turn_by(90, 1.2),
			BulletAction.tint_to(Color(0.15, 0.7, 1.0), 1.2),
			BulletAction.visual_scale_to(2.5, 1.2),
		]).wait(0.3).opacity_to(0.15, 0.7)
		sequence = BarrageSequence.new().fire_fan(shot, 5, 48, 70).wait(3).repeat()
	elif pattern_choice.selected in [8, 9]:
		var shot := BarrageShot.new()
		shot.appearance = APPEARANCES[0]
		shot.behavior = BulletBehavior.new().homing(90, 4)
		shot.lifetime = 6
		if pattern_choice.selected == 9:
			shot.kind = BarrageShot.Kind.TRAIL_LASER
			shot.trail_duration = 0.7
		sequence = BarrageSequence.new().fire_fan(shot, 3, 80, 70).wait(2).repeat()
	else:
		sequence = BarrageSequence.new().fire(_make_volley())
		sequence.wait(4.0 if shape_choice.selected == 4 else 0.9)
		if shape_choice.selected == 4 and pattern_choice.selected in [1, 4]:
			sequence.rotate(15)
		sequence.repeat()
	if not pattern_player.play(sequence, emitter, world, target):
		push_error(pattern_player.last_error)


func _make_volley() -> BarrageVolley:
	var shot := BarrageShot.new()
	if shape_choice.selected == 4:
		shot.kind = BarrageShot.Kind.TRAIL_LASER
		shot.behavior = BulletBehavior.new().turn_at(-70 if motion_choice.selected == 3 else 70, 1.5)
	elif shape_choice.selected == 3:
		shot.kind = BarrageShot.Kind.LEGACY
	else:
		shot.appearance = preload("res://resources/projectiles/needle.tres") if shape_choice.selected == 5 else APPEARANCES[shape_choice.selected]
		shot.behavior = BEHAVIORS[motion_choice.selected]
		shot.lifetime = 8.0
		if shape_choice.selected == 5:
			shot.trail_effect = preload("res://resources/projectiles/diamond_trail.tres")
	var volley := BarrageVolley.new()
	volley.shot = shot
	volley.speed = 90 if shape_choice.selected == 4 else 95
	match pattern_choice.selected:
		0:
			volley.layout = BarrageVolley.Layout.FAN
			volley.count = 5
		1, 4:
			volley.layout = BarrageVolley.Layout.RING
			volley.count = 12 if pattern_choice.selected == 4 else 16
		3:
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


func _toggle_hitboxes(enabled: bool) -> void:
	pattern_player.show_hitbox = enabled
	# New projectiles share a single instanced debug renderer.
	get_tree().debug_collisions_hint = enabled and shape_choice.selected == 3
	var renderer = world.get_meta("projectile_renderer", null)
	if is_instance_valid(renderer):
		renderer.extra_debug_shapes.clear()
		if enabled and shape_choice.selected != 3:
			renderer.extra_debug_shapes.append(hurtbox.get_child(0))
	for bullet in get_tree().get_nodes_in_group("enemy_projectiles"):
		if world.is_ancestor_of(bullet) and bullet is FoundationBullet:
			bullet.show_hitbox = enabled
		elif world.is_ancestor_of(bullet) and bullet is CurvedLaser:
			bullet.show_hitbox = enabled


func clear_bullets() -> void:
	cleared += _clear_world_bullets()


func _clear_world_bullets() -> int:
	var count := 0
	for bullet in get_tree().get_nodes_in_group("enemy_projectiles"):
		if world.is_ancestor_of(bullet) and not bullet.is_queued_for_deletion():
			bullet.queue_free()
			count += 1
	return count


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
	_script_panel.set_script(preload("res://labs/pattern_panel.gd"))
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
	_refresh_focus_chain()
	pattern_choice.select(10)
	restart()
	_script_button.grab_focus()
	return true


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
