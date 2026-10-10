extends Control
## Six textured panels and live instruments share the launch's pause-aware time.
const FRAME := preload("res://assets/ui/cockpit/pilot_visor_frame.png")
const POWER := preload("res://menus/cockpit_power.gdshader")
const LAMP_MASK := preload("res://assets/ui/cockpit/pilot_visor_lamps_mask.png")
const WARNING_PERIOD := 0.8
const BREAK_DURATION := 0.16
const RECOVERY_DURATION := 0.55
const RECOVERY_HOLD := 0.12
const BREAK_COLOR := Color(1.0, 0.48, 0.38)
const RECOVERY_COLOR := Color(0.15, 1.0, 0.38)
const Geometry := preload("res://menus/cockpit_geometry.gd")
const DELAYS := [0.0, 0.08, 0.18, 0.25, 0.34, 0.41]
## Launch time by which every panel has slid home (last delay + 0.82s travel).
const DEPLOY_END := 1.25
var panels: Array[Control] = []
var instruments: Array[Dictionary] = []
var deployment_time := 2.6
var _launch: LaunchSequence
var _shield_warning := false
var _warning_elapsed := 0.0
var _shield_initialized := false
var _transition := ""
var _transition_elapsed := 0.0

## Controls all nine lamps; blend=0 restores the original amber artwork.
func set_indicator_style(color: Color, blend: float = 1.0, brightness: float = 1.0) -> void:
	for panel in panels:
		var material := panel.get_child(0).material as ShaderMaterial
		material.set_shader_parameter("lamp_color", color)
		material.set_shader_parameter("lamp_blend", clampf(blend, 0.0, 1.0))
		material.set_shader_parameter("lamp_brightness", clampf(brightness, 0.0, 2.0))

func _on_shield_changed(current: int, _maximum: int) -> void:
	var warning := current <= 0
	if not _shield_initialized:
		_shield_initialized = true
		_shield_warning = warning
		set_indicator_style(Color.RED, 1.0 if warning else 0.0)
		set_process(warning)
		return
	if warning == _shield_warning:
		return
	_shield_warning = warning
	_warning_elapsed = 0.0
	_transition_elapsed = 0.0
	_transition = "break" if warning else "recovery"
	set_process(true)
	_process(0.0)

func _process(delta: float) -> void:
	if not _transition.is_empty():
		var duration := BREAK_DURATION if _transition == "break" else RECOVERY_DURATION
		var remaining := maxf(0.0, duration - _transition_elapsed)
		_transition_elapsed += delta
		if _transition_elapsed < duration:
			if _transition == "break":
				var t := _transition_elapsed / BREAK_DURATION
				set_indicator_style(BREAK_COLOR.lerp(Color.RED, t), 1.0, lerpf(1.65, 1.0, t))
			else:
				var t := smoothstep(RECOVERY_HOLD, RECOVERY_DURATION, _transition_elapsed)
				set_indicator_style(RECOVERY_COLOR, 1.0 - t, lerpf(1.25, 1.0, t))
			return
		delta = maxf(0.0, delta - remaining)
		_transition = ""
	if not _shield_warning:
		set_indicator_style(Color.RED, 0.0, 1.0)
		set_process(false)
		return
	_warning_elapsed = fmod(_warning_elapsed + delta, WARNING_PERIOD)
	var brightness := lerpf(0.18, 1.0, 0.5 + 0.5 * cos(TAU * _warning_elapsed / WARNING_PERIOD))
	set_indicator_style(Color.RED, 1.0, brightness)

func _on_ship_exiting() -> void:
	set_process(false)


func configure(world: Control) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	z_index = 0
	# Draw the frame behind instruments, but above the rectangular battle texture.
	var layout := get_parent()
	layout.move_child(self, 2)
	var partitions := [
		PackedVector2Array([Vector2(0, 0), Vector2(320, 0), Vector2(320, 18), Vector2(142, 18), Vector2(22, 50), Vector2(0, 108)]),
		PackedVector2Array([Vector2(0, 108), Vector2(22, 50), Vector2(142, 18), Vector2(320, 18), Vector2(320, 249), Vector2(128, 249), Vector2(0, 211)]),
		PackedVector2Array([Vector2(0, 211), Vector2(128, 249), Vector2(320, 249), Vector2(320, 360), Vector2(0, 360)]),
	]
	for side in 2:
		for row in 3:
			var panel := Control.new()
			panel.name = ["Left", "Right"][side] + ["Canopy", "Console", "Wing"][row]
			panel.mouse_filter = MOUSE_FILTER_IGNORE
			var mesh := Polygon2D.new()
			var points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for point: Vector2 in partitions[row]:
				var vertex := Vector2(640.0 - point.x, point.y) if side == 1 else point
				points.append(vertex)
				uvs.append(vertex / Geometry.SHELL_SIZE * FRAME.get_size())
			mesh.polygon = points
			mesh.uv = uvs
			mesh.texture = FRAME
			mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var material := ShaderMaterial.new()
			material.shader = POWER
			material.set_shader_parameter("lamp_mask", LAMP_MASK)
			mesh.material = material
			panel.add_child(mesh)
			add_child(panel)
			panels.append(panel)
	var left := "Layout/LeftPanel/Margin/VBox/"
	var right := "Layout/RightPanel/Margin/VBox/"
	for item in [[left + "ScoreTitle", 0], [left + "ScoreValue", 0],
		[left + "ProgressionHud/ThreatLabel", 1], [left + "ProgressionHud/ThreatBar", 1],
		[left + "ShipStatusHud", 2], [left + "ProgressionHud/ExperienceLabel", 2],
		[left + "ProgressionHud/ExperienceBar", 2], [right + "LoadoutTitle", 4],
		[right + "ShipPanel", 4],
		[right + "WeaponBox/Margin/WeaponLoadoutHud/BayTitle", 4],
		[right + "WeaponBox/Margin/WeaponLoadoutHud/BayRow", 4],
		[right + "WeaponBox/Margin/WeaponLoadoutHud/DetailColumns/SelectedCol", 5],
		[right + "WeaponBox/Margin/WeaponLoadoutHud/DetailColumns/ModulesCol", 5],
		[right + "WeaponBox/Margin/WeaponLoadoutHud/WeaponDetailFooterClip", 5]]:
		var node := world.get_node(item[0]) as Control
		instruments.append({"node": node, "home": node.position, "panel": item[1]})
	# Keep instruments after the frame without raising them over modal settings.
	layout.move_child(world.get_node("Layout/LeftPanel"), layout.get_child_count() - 1)
	var gauge := Control.new()
	gauge.name = "ShieldArc"
	gauge.set_script(preload("res://menus/cockpit_shield_gauge.gd"))
	world.get_node(left + "ShipStatusHud").add_child(gauge)
	gauge.position = Vector2(0, 16)
	gauge.size = Vector2(96, 16)
	var ship := world.gameplay.get_node("Ship") as Node2D
	var shield := ship.get_node("ShieldComponent") as ShieldComponent
	shield.shield_changed.connect(_on_shield_changed)
	ship.tree_exiting.connect(_on_ship_exiting)
	_on_shield_changed(shield.get_current_shield(), shield.get_max_shield())
	ship.get_node("PositionClampComponent").cockpit_boundary = true
	ship.position.x = Geometry.FIELD_WIDTH * 0.5
	_launch = world.gameplay.get_node("LaunchSequence") as LaunchSequence
	_launch.launch_started.connect(_on_launch_started)
	_launch.launch_advanced.connect(set_deployment_time)
	set_deployment_time(0.0 if _launch.is_launching else 2.6)

func _on_launch_started() -> void:
	set_deployment_time(0.0)

func _offset(index: int, time: float) -> Vector2:
	var side := -1.0 if index < 3 else 1.0
	var row := index % 3
	var t := clampf((time - float(DELAYS[index])) / 0.82, 0.0, 1.0)
	var remaining := pow(1.0 - t, 4.0)
	return Vector2(side * 350.0, [-70.0, 0.0, 105.0][row]) * remaining

func _power(index: int, time: float) -> float:
	var t := time - float(DELAYS[index]) - 0.48
	if t < 0.0:
		return 0.0
	if t > 0.8:
		return 1.0
	# Deterministic, brief ignition pulses; no flicker after boot.
	return 0.2 if (t < 0.08 or (t > 0.16 and t < 0.23) or (t > 0.34 and t < 0.38)) else 0.85

func set_deployment_time(time: float) -> void:
	deployment_time = time
	for i in panels.size():
		var panel := panels[i]
		panel.position = _offset(i, time)
		var material := panel.get_child(0).material as ShaderMaterial
		material.set_shader_parameter("power", _power(i, time))
		material.set_shader_parameter("scan", clampf((time - float(DELAYS[i]) - 0.5) / 0.8, 0.0, 1.0))
	for item in instruments:
		var node := item.node as Control
		var index := int(item.panel)
		node.position = item.home + _offset(index, time)
		node.modulate.a = _power(index, time)
