class_name AugmentBreakpointIntro
extends Control

@onready var breakpoint_card: PanelContainer = $CenterContainer/BreakpointCard
@onready var event_label: Label = $CenterContainer/BreakpointCard/MarginContainer/VBoxContainer/EventLabel
@onready var title_label: Label = $CenterContainer/BreakpointCard/MarginContainer/VBoxContainer/TitleLabel
@onready var accent_bar: ColorRect = $CenterContainer/BreakpointCard/MarginContainer/VBoxContainer/AccentBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var band: ColorRect = $Band


func play_intro(accent_color: Color) -> void:
	set_accent_color(accent_color)
	visible = true
	band.pivot_offset = band.size * 0.5
	# The card overshoots 0.92 -> 1.03 -> 1.0 within 0.38 s, holds exactly 1.0
	# while readable, and shrinks to 0.97 only during the final fade. The old
	# slow 1.02 -> 1.0 glide kept the pixel font and 1px border off the pixel
	# grid for the whole intro, which read as a constant tremble.
	breakpoint_card.pivot_offset = breakpoint_card.size * 0.5
	animation_player.play(&"reveal")
	await animation_player.animation_finished
	visible = false


func set_accent_color(accent_color: Color) -> void:
	var panel_style := breakpoint_card.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	panel_style.bg_color = Color(
		0.01 + accent_color.r * 0.06,
		0.01 + accent_color.g * 0.035,
		0.02 + accent_color.b * 0.05,
		0.98,
	)
	panel_style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.9)
	panel_style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.28)
	breakpoint_card.add_theme_stylebox_override(&"panel", panel_style)

	var eyebrow_settings := event_label.label_settings.duplicate() as LabelSettings
	eyebrow_settings.font_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.9)
	event_label.label_settings = eyebrow_settings

	var title_settings := title_label.label_settings.duplicate() as LabelSettings
	var outline_color := accent_color.darkened(0.55)
	outline_color.a = 0.8
	title_settings.outline_color = outline_color
	title_label.label_settings = title_settings
	accent_bar.color = accent_color
	band.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.12)
