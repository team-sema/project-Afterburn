class_name EnemyHealthBarComponent
extends Node2D

@export var actor: Enemy
@export var stats_component: StatsComponent
@export var enabled := true
@export_range(0.1, 10.0, 0.1, "suffix:s") var visible_duration := 1.5
@export_range(0.05, 2.0, 0.05, "suffix:s") var fade_duration := 0.25
@export var screen_offset := Vector2(0.0, -22.0)
@export var bar_size := Vector2(34.0, 4.0)
@export var background_color := Color(0.04, 0.025, 0.07, 0.92)
@export var fill_color := Color(1.0, 0.18, 0.38, 0.98)
@export var border_color := Color(1.0, 0.72, 0.82, 0.9)

var _maximum_health := 1
var _last_health := 1
var _health_ratio := 1.0
var _fade_tween: Tween


func _ready() -> void:
	assert(actor != null, "EnemyHealthBarComponent requires an Enemy actor.")
	assert(stats_component != null, "EnemyHealthBarComponent requires a StatsComponent.")
	top_level = true
	visible = false
	modulate.a = 0.0
	_maximum_health = maxi(1, stats_component.health)
	_last_health = stats_component.health
	_health_ratio = clampf(float(_last_health) / float(_maximum_health), 0.0, 1.0)
	stats_component.health_changed.connect(_on_health_changed)
	set_process(_is_eligible())
	_sync_transform()
	queue_redraw()


func _process(_delta: float) -> void:
	_sync_transform()


func _draw() -> void:
	var top_left := -bar_size * 0.5
	var border_rect := Rect2(top_left - Vector2.ONE, bar_size + Vector2.ONE * 2.0)
	var background_rect := Rect2(top_left, bar_size)
	draw_rect(border_rect, border_color)
	draw_rect(background_rect, background_color)
	if _health_ratio <= 0.0:
		return
	var fill_rect := background_rect
	fill_rect.size.x *= _health_ratio
	draw_rect(fill_rect, fill_color)


func get_health_ratio() -> float:
	return _health_ratio


func _on_health_changed() -> void:
	var current_health := stats_component.health
	if current_health > _maximum_health:
		_maximum_health = current_health
	_health_ratio = clampf(float(current_health) / float(_maximum_health), 0.0, 1.0)
	queue_redraw()

	var took_damage := current_health < _last_health
	_last_health = current_health
	if not took_damage or not _is_eligible():
		return
	set_process(true)
	_sync_transform()
	_show_temporarily()


func _show_temporarily() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = true
	modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.tween_interval(visible_duration)
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(hide)


func _is_eligible() -> bool:
	return enabled and (actor.is_elite or actor.is_boss)


func _sync_transform() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	global_position = actor.global_position + screen_offset
	global_rotation = 0.0
