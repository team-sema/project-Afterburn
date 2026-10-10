extends Control
## Transient, pause-aware cockpit reports. No backlog while disabled.
## Three rows in combat; the launch widens the window to five rows and
## streams the ship's boot log through it on the launch's own game clock.
const FONT := preload("res://fonts/Mulmaru_hud.ttf")
const PROJECTION := preload("res://menus/combat_event_log.gdshader")
const OPACITY := 0.82
const CYAN := Color(0.42, 0.91, 0.94)
const ALERT := Color(1.0, 0.26, 0.24)
const LIFETIME := 2.8
const LAUNCH_LIFETIME := 1.5
const HIGHLIGHT_LIFETIME := 3.5
const HIGHLIGHT := Color(0.93, 1.0, 1.0)
const SLIDE := 0.18
const LINE_HEIGHT := 14.0
const WIDTH := 180.0
const PADDING := Vector2(4, 3)
const COMBAT_ROWS := 3
const LAUNCH_ROWS := 5
## Launch-clock seconds → boot report. Bursts early, slows as the ship
## settles, and the highlight line lingers alone once the rest has drained.
const LAUNCH_LOG: Array[Dictionary] = [
	{"at": 0.10, "key": &"launch_reactor", "text": "REACTOR SPIN-UP"},
	{"at": 0.22, "key": &"launch_fuel", "text": "FUEL PRESSURE OK"},
	{"at": 0.32, "key": &"launch_ignition", "text": "IGNITION", "urgent": true},
	{"at": 0.50, "key": &"launch_burner", "text": "AFTERBURNER LIT"},
	{"at": 0.70, "key": &"launch_velocity", "text": "VELOCITY CLIMBING"},
	{"at": 0.95, "key": &"launch_dampers", "text": "INERTIAL DAMPERS ON"},
	{"at": 1.30, "key": &"launch_canopy", "text": "CANOPY SEALED"},
	{"at": 1.65, "key": &"launch_shield", "text": "SHIELD GRID CHARGED"},
	{"at": 2.00, "key": &"launch_controls", "text": "CONTROLS TO PILOT"},
	{"at": 2.45, "key": &"launch_highlight", "text": "AFTERBURN: ENGAGE", "highlight": true},
]
var entries: Array[Dictionary] = []
var _enabled := true
var _last_shield := 0
var _slide_age := 0.0
var _scan_age := 1.0
## Rows the layout and eviction use right now.
var _rows := COMBAT_ROWS
## Rows the box is physically sized for; shrinks only once rows slid up.
var _box_rows := COMBAT_ROWS
## Rows requested by the launch; a shrink waits until entries fit.
var _target_rows := COMBAT_ROWS
var _launch_index := 0
var _projection: ShaderMaterial
var _ink_viewport: SubViewport
var _ink: Control
var _display: TextureRect

func configure(shield: ShieldComponent) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	position = Vector2(178, 28)
	_ink_viewport = SubViewport.new()
	_ink_viewport.name = "InkViewport"
	_ink_viewport.size_2d_override_stretch = true
	_ink_viewport.transparent_bg = true
	_ink_viewport.disable_3d = true
	_ink_viewport.gui_disable_input = true
	_ink_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_ink_viewport)
	_ink = Control.new()
	_ink.position = PADDING
	_ink.clip_contents = true
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ink_viewport.add_child(_ink)
	_display = TextureRect.new()
	_display.name = "CurvedProjection"
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.texture = _ink_viewport.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_projection = ShaderMaterial.new()
	_projection.shader = PROJECTION
	_display.material = _projection
	add_child(_display)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_resize_box(COMBAT_ROWS)
	_last_shield = shield.get_current_shield()
	shield.shield_changed.connect(_on_shield_changed)
	GameSettings.instance.combat_event_log_changed.connect(_on_enabled_changed)
	_on_enabled_changed(GameSettings.instance.is_combat_event_log_enabled())

## Streams LAUNCH_LOG while `launch` plays; the window returns to three rows
## once the launch ends and the boot lines have drained to fit.
func configure_launch(launch: LaunchSequence) -> void:
	launch.launch_started.connect(_on_launch_started)
	launch.launch_advanced.connect(_on_launch_advanced)
	launch.launch_finished.connect(_request_rows.bind(COMBAT_ROWS))
	if launch.is_launching:
		_on_launch_started()
		_on_launch_advanced(launch.elapsed)

func _on_launch_started() -> void:
	_launch_index = 0
	_request_rows(LAUNCH_ROWS)

func _on_launch_advanced(time: float) -> void:
	while _launch_index < LAUNCH_LOG.size() and LAUNCH_LOG[_launch_index].at <= time:
		var line: Dictionary = LAUNCH_LOG[_launch_index]
		_launch_index += 1
		var highlight: bool = line.get("highlight", false)
		post_event(line.key, line.text, line.get("urgent", false),
			HIGHLIGHT_LIFETIME if highlight else LAUNCH_LIFETIME, HIGHLIGHT if highlight else CYAN)

func _on_shield_changed(current: int, _maximum: int) -> void:
	if current == 0 and _last_shield > 0:
		post_event(&"shield_lost", "SHIELD LOST", true)
	elif current > 0 and _last_shield == 0:
		post_event(&"shield_online", "SHIELD ONLINE")
	_last_shield = current

func on_augment_ready(ready: bool) -> void:
	if ready:
		post_event(&"augment_ready", "AUGMENT READY [C]")

func post_event(key: StringName, message: String, urgent: bool = false, lifetime: float = LIFETIME, tone: Color = CYAN) -> void:
	if not _enabled:
		return
	for entry in entries:
		if entry.key == key:
			return
	while entries.size() >= _rows:
		var oldest: Dictionary = entries.pop_front()
		_ink.remove_child(oldest.label)
		oldest.label.queue_free()
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_shadow_color", Color(0, 0.02, 0.03, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.text = "> " + message
	var below := float(_rows) * LINE_HEIGHT
	label.position.y = maxf(below, entries[-1].label.position.y + LINE_HEIGHT) if not entries.is_empty() else below
	label.modulate.a = 0.0
	_ink.add_child(label)
	entries.append({"key": key, "label": label, "age": 0.0, "urgent": urgent, "lifetime": lifetime, "tone": tone, "start_y": label.position.y})
	_retarget()
	_scan_age = 0.0
	_projection.set_shader_parameter("scan_age", _scan_age)
	_update_rendering()
	set_process(true)

func _on_enabled_changed(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled
	if not enabled:
		for entry in entries:
			_ink.remove_child(entry.label)
			entry.label.queue_free()
		entries.clear()
		_settle_rows()
	_update_rendering()
	set_process(not entries.is_empty() or _box_rows != _rows)

func _update_rendering() -> void:
	_display.visible = _enabled and not entries.is_empty()
	_ink_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _display.visible else SubViewport.UPDATE_DISABLED

func _request_rows(rows: int) -> void:
	_target_rows = rows
	_settle_rows()
	set_process(not entries.is_empty() or _box_rows != _rows)

## Grows at once; shrinks only when the remaining rows fit the smaller window.
func _settle_rows() -> void:
	if _target_rows == _rows or entries.size() > _target_rows:
		return
	_rows = _target_rows
	if _rows > _box_rows or entries.is_empty():
		_resize_box(_rows)
	_retarget()

## Box, offscreen ink (3x for edge quality) and projection share one height.
func _resize_box(rows: int) -> void:
	_box_rows = rows
	size = Vector2(WIDTH, float(rows) * LINE_HEIGHT + PADDING.y * 2.0)
	_ink_viewport.size = Vector2i(size) * 3
	_ink_viewport.size_2d_override = Vector2i(size)
	_ink.size = Vector2(WIDTH - PADDING.x, float(rows) * LINE_HEIGHT)
	_display.size = size

func _retarget() -> void:
	_slide_age = 0.0
	for entry in entries:
		entry.start_y = entry.label.position.y

func _process(delta: float) -> void:
	_scan_age = minf(1.0, _scan_age + delta)
	_projection.set_shader_parameter("scan_age", _scan_age)
	var expired := false
	for i in range(entries.size() - 1, -1, -1):
		entries[i].age += delta
		if entries[i].age >= entries[i].lifetime:
			_ink.remove_child(entries[i].label)
			entries[i].label.queue_free()
			entries.remove_at(i)
			expired = true
	if expired:
		_retarget()
		_settle_rows()
	_slide_age = minf(SLIDE, _slide_age + delta)
	for i in entries.size():
		var entry := entries[i]
		var label: Label = entry.label
		var target := float(_rows - entries.size() + i) * LINE_HEIGHT
		label.position.y = lerpf(entry.start_y, target, 1.0 - pow(1.0 - _slide_age / SLIDE, 3.0))
		label.modulate.a = minf(clampf(entry.age / SLIDE, 0, 1), clampf((entry.lifetime - entry.age) / 0.6, 0, 1)) * OPACITY
		label.add_theme_color_override("font_color", ALERT if entry.urgent and entry.age < 0.35 else entry.tone)
	if _box_rows != _rows and _slide_age >= SLIDE:
		_resize_box(_rows)
	_update_rendering()
	set_process(not entries.is_empty() or _box_rows != _rows)
