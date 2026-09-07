@tool
extends Control
## Beveled metal and spectral glass, with a separate crisp text layer.

@export_group("Decoration")
@export var rotating_orbits_enabled := false
@export var static_arcs_enabled := true
@export var side_gems_enabled := false
@export var decoration_color := Color("adcfee")
@export_range(1.0, 50.0, 0.5) var medallion_radius := 23.0
@export_range(1.0, 60.0, 0.5) var orbit_radius := 28.0
@export_range(-3.0, 3.0, 0.05) var orbit_speed := 0.45
@export_range(0.1, 6.0, 0.05) var orbit_arc_length := 1.35
@export var orbit_colors := PackedColorArray([Color("87ecff"), Color("d4a2ff"), Color("ffe7bd")])
@export var gem_size := Vector2(4, 6)
@export_group("Particles")
@export var particles_enabled := false
@export_range(0, 32) var particle_count := 8
@export_range(0.0, 2.0, 0.01) var particle_speed := 0.18
@export_range(0.0, 1.0, 0.01) var particle_opacity := 0.65
@export_group("Animation")
@export_range(0.0, 4.0, 0.05) var animation_speed := 1.0
@export_range(0.1, 5.0, 0.1) var focus_fade_speed := 1.4
@export var animate_tier_accent := false
@export_group("Editor Preview")
@export var preview_animate := true
@export var preview_focused := true
@export_range(0.0, 60.0, 0.1) var preview_time := 0.0

var elapsed := 0.0
@onready var title_label: Label = $Title
@onready var description_label: Label = $Description
@onready var icon: TextureRect = $Icon
var surface: ShaderMaterial
var was_active := false
var activation := 0.0
var _title_font_size := 14
var _description_font_size := 12
var _title_height := 34.0
var _description_height := 49.0


func _ready() -> void:
	surface = $Surface.material as ShaderMaterial
	_title_font_size = title_label.get_theme_font_size("font_size")
	_description_font_size = description_label.get_theme_font_size("font_size")
	_title_height = title_label.size.y
	_description_height = description_label.size.y
	_process(0.0)


func configure(augment: PlayerAugment, loadout: PlayerWeaponLoadout) -> void:
	title_label.text = augment.get_offer_title(loadout)
	description_label.text = augment.get_offer_description(loadout)
	icon.texture = augment.get_offer_icon()
	_fit_copy(title_label, _title_font_size, _title_height)
	_fit_copy(description_label, _description_font_size, _description_height)
	queue_redraw()


func _fit_copy(label: Label, preferred_size: int, height: float) -> void:
	var font := label.get_theme_font("font")
	var font_size := preferred_size
	while font_size > 9:
		var measured := font.get_multiline_string_size(
			label.text, HORIZONTAL_ALIGNMENT_CENTER, label.size.x, font_size
		)
		if measured.y <= height:
			break
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func _process(delta: float) -> void:
	if not is_node_ready() or not is_visible_in_tree():
		return
	# Follow material replacements made in the Inspector as well as parameter edits.
	surface = $Surface.material as ShaderMaterial
	if surface == null:
		return
	if Engine.is_editor_hint() and not preview_animate:
		elapsed = preview_time
	else:
		elapsed += delta * animation_speed
	var button := get_parent() as Button
	var active := preview_focused if Engine.is_editor_hint() or button == null else not button.disabled and (button.has_focus() or button.is_hovered())
	if active and not was_active:
		activation = 1.0
	else:
		activation = maxf(0.0, activation - delta * focus_fade_speed)
	was_active = active
	surface.set_shader_parameter("motion", elapsed)
	surface.set_shader_parameter("emphasis", 1.0 if active else 0.0)
	surface.set_shader_parameter("activation", activation)
	surface.set_shader_parameter("surface_size", $Surface.size)
	surface.set_shader_parameter("card_size", size)
	surface.set_shader_parameter("surface_offset", $Surface.position)
	surface.set_shader_parameter("orb_center", $MedallionAnchor.position)
	surface.set_shader_parameter("halo_radius", orbit_radius)
	var tint := Color.from_hsv(fposmod(elapsed * 0.12, 1.0), 0.32, 1.0) if animate_tier_accent else Color.WHITE
	$TierLabel.modulate = tint
	$TierAccent.modulate = tint
	queue_redraw()


func _gem(center: Vector2, extent: Vector2, tint: Color) -> void:
	var top := center - Vector2(0, extent.y)
	var bottom := center + Vector2(0, extent.y)
	var left := center - Vector2(extent.x, 0)
	var right := center + Vector2(extent.x, 0)
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), tint.darkened(0.4))
	draw_colored_polygon(PackedVector2Array([top, center, left]), tint.lightened(0.65))
	draw_colored_polygon(PackedVector2Array([top, right, center]), tint)
	draw_colored_polygon(PackedVector2Array([left, center, bottom]), tint.darkened(0.12))
	draw_line(top, right, tint.lightened(0.8), 0.6, true)


func _draw() -> void:
	if not is_node_ready():
		return
	var metal := decoration_color
	var light := metal.lightened(0.55)
	var center: Vector2 = $MedallionAnchor.position
	# An engraved medallion replaces the heavy square icon socket.
	draw_circle(center, medallion_radius, Color(0.025, 0.045, 0.07, 0.85), true, -1.0, true)
	draw_arc(center, medallion_radius, 0, TAU, 80, Color(metal, 0.55), 0.7, true)
	var crest: Vector2 = $CrestAnchor.position
	var divider: Vector2 = $DividerAnchor.position
	var ornament: Vector2 = $OrnamentAnchor.position
	for side in [-1, 1]:
		var x := float(side)
		draw_polyline(PackedVector2Array([crest + Vector2(x * 32, 0), crest + Vector2(x * 24, 4), crest + Vector2(x * 19, 4)]), Color(metal, 0.55), 0.8, true)
		draw_polyline(PackedVector2Array([divider + Vector2(x * 53, -1), divider + Vector2(x * 22, -1), divider + Vector2(x * 7, 1)]), Color(metal, 0.42), 0.7, true)
		draw_polyline(PackedVector2Array([ornament + Vector2(x * 42, -2), ornament + Vector2(x * 20, -2), ornament + Vector2(x * 12, 2)]), Color(metal, 0.6), 0.8, true)
	_gem(divider, Vector2(3, 2), light)
	_gem(ornament, gem_size, metal)
	if side_gems_enabled:
		_gem(ornament + Vector2(-11, -1), gem_size * 0.5, metal)
		_gem(ornament + Vector2(11, -1), gem_size * 0.5, metal)
	if rotating_orbits_enabled:
		# Opposing spectral arcs and orbiting crystal flecks stay above the text.
		for n in orbit_colors.size():
			var angle := elapsed * orbit_speed + n * TAU / float(orbit_colors.size())
			var tint := orbit_colors[n]
			draw_arc(center, orbit_radius, angle, angle + orbit_arc_length, 32, Color(tint, 0.8), 1.1, true)
			_gem(center + Vector2.from_angle(angle) * orbit_radius, Vector2(2, 3), tint)
	if particles_enabled:
		var area: Rect2 = $ParticlesArea.get_rect()
		for n in particle_count:
			var phase := fposmod(elapsed * particle_speed + n * 0.137, 1.0)
			var at := area.position + Vector2(n * area.size.x / maxf(1.0, particle_count - 1), (1.0 - phase) * area.size.y)
			var opacity := sin(phase * PI) * particle_opacity
			draw_line(at - Vector2(0, 2), at + Vector2(0, 2), Color(light, opacity), 0.7, true)
			draw_line(at - Vector2(1.5, 0), at + Vector2(1.5, 0), Color(light, opacity), 0.7, true)
	if static_arcs_enabled:
		draw_arc(center, orbit_radius - 1, -2.8, -0.35, 48, Color(light, 0.65), 1.0, true)
		draw_arc(center, orbit_radius - 1, 0.35, 2.8, 48, Color(metal, 0.35), 0.7, true)
