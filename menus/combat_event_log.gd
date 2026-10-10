extends Control
## Transient, pause-aware cockpit reports. No backlog while disabled.
const FONT := preload("res://fonts/Mulmaru_hud.ttf")
const PROJECTION := preload("res://menus/combat_event_log.gdshader")
const OPACITY := 0.82
const CYAN := Color(0.42, 0.91, 0.94)
const ALERT := Color(1.0, 0.26, 0.24)
const LIFETIME := 2.8
const SLIDE := 0.18
const LINE_HEIGHT := 14.0
var entries: Array[Dictionary] = []
var _enabled := true
var _last_shield := 0
var _slide_age := 0.0
var _scan_age := 1.0
var _projection: ShaderMaterial
var _ink_viewport: SubViewport
var _ink: Control
var _display: TextureRect

func configure(shield: ShieldComponent) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	position = Vector2(178, 28)
	size = Vector2(180, 48)
	_ink_viewport = SubViewport.new()
	_ink_viewport.name = "InkViewport"
	_ink_viewport.size = Vector2i(540, 144)
	_ink_viewport.size_2d_override = Vector2i(180, 48)
	_ink_viewport.size_2d_override_stretch = true
	_ink_viewport.transparent_bg = true
	_ink_viewport.disable_3d = true
	_ink_viewport.gui_disable_input = true
	_ink_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_ink_viewport)
	_ink = Control.new()
	_ink.position = Vector2(4, 3)
	_ink.size = Vector2(176, 42)
	_ink.clip_contents = true
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ink_viewport.add_child(_ink)
	_display = TextureRect.new()
	_display.name = "CurvedProjection"
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.texture = _ink_viewport.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.size = size
	_projection = ShaderMaterial.new()
	_projection.shader = PROJECTION
	_display.material = _projection
	add_child(_display)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_last_shield = shield.get_current_shield()
	shield.shield_changed.connect(_on_shield_changed)
	GameSettings.instance.combat_event_log_changed.connect(_on_enabled_changed)
	_on_enabled_changed(GameSettings.instance.is_combat_event_log_enabled())

func _on_shield_changed(current: int, _maximum: int) -> void:
	if current == 0 and _last_shield > 0:
		post_event(&"shield_lost", "SHIELD LOST", true)
	elif current > 0 and _last_shield == 0:
		post_event(&"shield_online", "SHIELD ONLINE")
	_last_shield = current

func on_augment_ready(ready: bool) -> void:
	if ready:
		post_event(&"augment_ready", "AUGMENT READY [C]")

func post_event(key: StringName, message: String, urgent: bool = false) -> void:
	if not _enabled:
		return
	for entry in entries:
		if entry.key == key:
			return
	if entries.size() == 3:
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
	label.position.y = maxf(42.0, entries[-1].label.position.y + LINE_HEIGHT) if not entries.is_empty() else 42.0
	label.modulate.a = 0.0
	_ink.add_child(label)
	entries.append({"key": key, "label": label, "age": 0.0, "urgent": urgent, "start_y": label.position.y})
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
	_update_rendering()
	set_process(not entries.is_empty())

func _update_rendering() -> void:
	_display.visible = _enabled and not entries.is_empty()
	_ink_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _display.visible else SubViewport.UPDATE_DISABLED

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
		if entries[i].age >= LIFETIME:
			_ink.remove_child(entries[i].label)
			entries[i].label.queue_free()
			entries.remove_at(i)
			expired = true
	if expired:
		_retarget()
	_slide_age = minf(SLIDE, _slide_age + delta)
	for i in entries.size():
		var entry := entries[i]
		var label: Label = entry.label
		var target := float(3 - entries.size() + i) * LINE_HEIGHT
		label.position.y = lerpf(entry.start_y, target, 1.0 - pow(1.0 - _slide_age / SLIDE, 3.0))
		label.modulate.a = minf(clampf(entry.age / SLIDE, 0, 1), clampf((LIFETIME - entry.age) / 0.6, 0, 1)) * OPACITY
		label.add_theme_color_override("font_color", ALERT if entry.urgent and entry.age < 0.35 else CYAN)
	_update_rendering()
	set_process(not entries.is_empty())
