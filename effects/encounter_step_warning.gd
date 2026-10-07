class_name EncounterStepWarning
extends Node2D

## ELITE / BOSS 관문 직전 맵 중앙 관문 경고 (run-pacing.md 「관문 경고」).
## WAVE에는 쓰지 않는다. `present()`로 띄우면 `warning_duration` 뒤 스스로 사라진다.
##
## 구성: 화면 폭의 반투명 검은 띠가 중앙에서 펼쳐지고, 띠 위아래로 해저드
## 스트라이프가 흐르며, 화면 테두리가 같은 색으로 맥동한다. 종류별 문구·색.
## 시작 시 `sounds/warning_sound.wav`를 SFX 버스로 1회 재생한다.

signal finished

const SFX_PATH := "res://sounds/warning_sound.wav"
const BAND_HEIGHT := 56.0
const STRIPE_GAP := 3.0
const STRIPE_THICKNESS := 3.0
const STRIPE_PERIOD := 16.0
const STRIPE_SCROLL_SPEED := 48.0
const SWEEP_DURATION := 0.25
const FADE_DURATION := 0.3
const PULSE_HZ := 2.5
const EDGE_THICKNESS := 5.0
const HEADLINE_SIZE := 30
const SUBLINE_SIZE := 11
const SUBLINE := "CLEAR THE LANE"

@export_range(0.2, 3.0, 0.05, "suffix:s") var warning_duration := 1.6
@export var kind := EncounterSequenceStep.Kind.ELITE

var _elapsed := 0.0
var _active := true


static func present(
	host: Node,
	step_kind: EncounterSequenceStep.Kind,
	duration := 1.6,
) -> EncounterStepWarning:
	assert(host != null, "EncounterStepWarning requires a host node.")
	var warning := EncounterStepWarning.new()
	warning.warning_duration = duration
	warning.kind = step_kind
	warning.z_index = 120
	warning.top_level = true
	host.add_child(warning)
	warning._pin_to_viewport_center()
	return warning


func _ready() -> void:
	_play_sfx()
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= warning_duration:
		_active = false
		hide()
		finished.emit()
		queue_free()
		return
	_pin_to_viewport_center()
	queue_redraw()


func is_warning_active() -> bool:
	return _active


func get_headline() -> String:
	match kind:
		EncounterSequenceStep.Kind.ELITE:
			return "ELITE INBOUND"
		EncounterSequenceStep.Kind.BOSS:
			return "BOSS INBOUND"
		_:
			return "WARNING"


func get_accent_color() -> Color:
	match kind:
		EncounterSequenceStep.Kind.BOSS:
			return Color(1.0, 0.2, 0.62)
		_:
			return Color(1.0, 0.32, 0.12)


func _play_sfx() -> void:
	if not ResourceLoader.exists(SFX_PATH):
		return
	var stream := load(SFX_PATH) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	add_child(player)
	player.play()


func _pin_to_viewport_center() -> void:
	global_position = get_viewport_rect().get_center()


func _draw() -> void:
	var rect := get_viewport_rect()
	var half_width := rect.size.x * 0.5
	var sweep := 1.0 - pow(1.0 - clampf(_elapsed / SWEEP_DURATION, 0.0, 1.0), 3.0)
	var remaining := warning_duration - _elapsed
	var fade := clampf(remaining / FADE_DURATION, 0.0, 1.0)
	# |sin| peaks twice per period, so halve the rate to land PULSE_HZ peaks per second.
	var pulse := 0.6 + 0.4 * absf(sin(_elapsed * PI * PULSE_HZ))
	var accent := get_accent_color()
	var band_half_width := half_width * sweep
	var band_half_height := BAND_HEIGHT * 0.5

	# Backdrop band so the text reads over bullets and enemies.
	draw_rect(
		Rect2(-band_half_width, -band_half_height, band_half_width * 2.0, BAND_HEIGHT),
		Color(0.0, 0.0, 0.0, 0.72 * fade),
	)
	# Hazard stripes just outside the band, scrolling sideways.
	var stripe_color := Color(accent.r, accent.g, accent.b, pulse * fade)
	var dim_color := Color(accent.r, accent.g, accent.b, 0.28 * fade)
	for sign_y in [-1.0, 1.0]:
		var y: float = sign_y * (band_half_height + STRIPE_GAP + STRIPE_THICKNESS * 0.5)
		draw_line(Vector2(-band_half_width, y), Vector2(band_half_width, y), dim_color, STRIPE_THICKNESS)
		var scroll := fposmod(_elapsed * STRIPE_SCROLL_SPEED * sign_y, STRIPE_PERIOD)
		var x := -band_half_width - STRIPE_PERIOD + scroll
		while x < band_half_width:
			var x0 := maxf(x, -band_half_width)
			var x1 := minf(x + STRIPE_PERIOD * 0.5, band_half_width)
			if x1 > x0:
				draw_line(
					Vector2(x0, y - STRIPE_THICKNESS * 0.5 * sign_y),
					Vector2(x1, y + STRIPE_THICKNESS * 0.5 * sign_y),
					stripe_color,
					STRIPE_THICKNESS,
				)
			x += STRIPE_PERIOD
	# Screen edge pulse.
	var edge_rect := Rect2(rect.position - global_position, rect.size).grow(-EDGE_THICKNESS * 0.5)
	draw_rect(edge_rect, Color(accent.r, accent.g, accent.b, 0.55 * pulse * fade), false, EDGE_THICKNESS)

	if sweep < 0.5:
		return
	var font: Font = ThemeDB.fallback_font
	var headline := get_headline()
	var headline_size := font.get_string_size(headline, HORIZONTAL_ALIGNMENT_LEFT, -1, HEADLINE_SIZE)
	var headline_pos := Vector2(-headline_size.x * 0.5, headline_size.y * 0.28 - 7.0)
	var text_alpha := clampf((sweep - 0.5) * 2.0, 0.0, 1.0) * fade
	draw_string(
		font,
		headline_pos + Vector2(1.5, 1.5),
		headline,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		HEADLINE_SIZE,
		Color(0.0, 0.0, 0.0, 0.7 * text_alpha),
	)
	draw_string(
		font,
		headline_pos,
		headline,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		HEADLINE_SIZE,
		Color(accent.r, accent.g, accent.b, (0.75 + 0.25 * pulse) * text_alpha),
	)
	var subline_size := font.get_string_size(SUBLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, SUBLINE_SIZE)
	draw_string(
		font,
		Vector2(-subline_size.x * 0.5, band_half_height - 5.0),
		SUBLINE,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		SUBLINE_SIZE,
		Color(1.0, 1.0, 1.0, 0.8 * text_alpha),
	)
