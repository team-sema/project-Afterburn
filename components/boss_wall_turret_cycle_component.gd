class_name BossWallTurretCycleComponent
extends Node
## Multi-slot cycle: rest → appear (2–3 turrets + cores) → dense spiral → hide.
## Destroying a turret stops that muzzle; all down → core linger.

const TURRET_PATTERN := preload("res://patterns/boss_wall_turret_pattern.gd")

@export var enemy_path: NodePath = NodePath("..")
@export var turret_root_path: NodePath = NodePath("../Turrets")
@export var entry_delay := 0.5
@export var appear_duration := 0.28
@export var disappear_duration := 0.2
@export var rest_duration_min := 4.0
@export var rest_duration_max := 6.0
@export var active_duration := 8.0
@export var core_linger_after_turret := 2.5
@export var turrets_per_cycle_min := 2
@export var turrets_per_cycle_max := 3
@export var fire_wave_count := 3
@export var shots_per_burst := 5

var _enemy: Enemy
var _turret_root: Node2D
var _slots: Array[Node2D] = []
var _barrage_player: BarragePlayer
var _phase := &"entry"
var _timer := 0.0
var _active: Array[Node2D] = []
var _firing: Array[Node2D] = []
var _last_indices: Array[int] = []
var _ready_to_cycle := false
var _core_linger := false
var _world: Node2D


func _ready() -> void:
	_enemy = get_node_or_null(enemy_path) as Enemy
	_turret_root = get_node_or_null(turret_root_path) as Node2D
	assert(_enemy != null, "BossWallTurretCycleComponent requires an Enemy.")
	assert(_turret_root != null, "BossWallTurretCycleComponent requires a Turrets root.")
	for child in _turret_root.get_children():
		if child is Node2D:
			var slot := child as Node2D
			_slots.append(slot)
			_hide_slot(slot)
			_wire_turret_death(slot)
	var default_shoot := _enemy.get_node_or_null("EnemyShootComponent") as Node
	if default_shoot != null:
		default_shoot.set_process(false)
		default_shoot.set_physics_process(false)
		default_shoot.process_mode = Node.PROCESS_MODE_DISABLED
	_barrage_player = BarragePlayer.new()
	_barrage_player.name = "BossWallBarragePlayer"
	add_child(_barrage_player)
	_barrage_player.finished.connect(_on_barrage_finished)
	set_process(true)


func _process(delta: float) -> void:
	if _enemy == null or _enemy.is_queued_for_deletion():
		return
	if _enemy.stats_component != null and _enemy.stats_component.health <= 0:
		_barrage_player.stop()
		return
	for slot in _active:
		_pulse_core(slot, delta)
	if _barrage_player.running:
		_barrage_player.advance(delta)
	if not _ready_to_cycle:
		if _enemy.movement_controller != null and _enemy.movement_controller.get_current_step_index() < 1:
			return
		_ready_to_cycle = true
		_phase = &"rest"
		_timer = entry_delay
		return
	_timer -= delta
	if _timer > 0.0:
		return
	match _phase:
		&"rest":
			_begin_appear()
		&"appear":
			_begin_fire()
		&"fire", &"core_linger":
			_begin_disappear()
		&"disappear":
			_phase = &"rest"
			_timer = randf_range(rest_duration_min, rest_duration_max)


func _begin_appear() -> void:
	_active = _pick_slots()
	_firing = _active.duplicate()
	_core_linger = false
	for slot in _active:
		_reset_turret_hp(slot)
		_show_slot(slot, true)
	_phase = &"appear"
	_timer = appear_duration


func _begin_fire() -> void:
	_phase = &"fire"
	_timer = active_duration
	_core_linger = false
	_world = get_tree().get_first_node_in_group("gameplay_world") as Node2D
	if _world == null:
		_world = get_tree().current_scene as Node2D
	if _firing.is_empty():
		_begin_disappear()
		return
	if not _start_barrage_from_firing():
		_begin_disappear()


func _start_barrage_from_firing() -> bool:
	if _world == null or _firing.is_empty():
		return false
	var offsets: Array = []
	var start_angles: Array = []
	for i in _firing.size():
		var slot := _firing[i]
		# Appear tween must be finished; lock scale before sampling muzzle.
		slot.scale = Vector2.ONE
		var muzzle := _resolve_muzzle(slot)
		if muzzle == null:
			continue
		var local_origin := _enemy.to_local(muzzle.global_position)
		if not local_origin.is_finite() or local_origin.is_equal_approx(Vector2.ZERO):
			# Fall back to authored slot layout if transform sampling failed.
			local_origin = slot.position + Vector2(0, 12)
		offsets.append(local_origin)
		start_angles.append(float(i) * 12.0)
	if offsets.is_empty():
		return false
	var sequence := TURRET_PATTERN.new() as BarrageSequence
	sequence.build({
		"origin_offsets": offsets,
		"start_angles": start_angles,
		"wave_count": fire_wave_count,
		"shots_per_burst": shots_per_burst,
	})
	if sequence.steps.is_empty():
		push_error("Boss wall turret pattern built no steps.")
		return false
	if not _barrage_player.play(sequence, _enemy, _world):
		push_error(_barrage_player.last_error)
		return false
	_barrage_player.set_physics_process(false)
	return true


func _resolve_muzzle(slot: Node2D) -> Node2D:
	var marker := slot.get_node_or_null("Turret/Muzzle") as Node2D
	if marker != null:
		return marker
	return slot.get_node_or_null("Turret") as Node2D


func _on_barrage_finished() -> void:
	# Finite burst waves done — stay in fire phase until active_duration ends (idle turrets).
	pass


func _begin_disappear() -> void:
	_barrage_player.stop()
	for slot in _active:
		_hide_slot(slot)
	_active.clear()
	_firing.clear()
	_core_linger = false
	_phase = &"disappear"
	_timer = disappear_duration


func _on_turret_destroyed(slot: Node2D) -> void:
	if not _active.has(slot) or not _firing.has(slot):
		return
	_firing.erase(slot)
	_set_part_active(slot.get_node_or_null("Turret") as Node2D, false)
	_barrage_player.stop()
	if _firing.is_empty():
		# All muzzles down — reward with longer core exposure.
		_core_linger = true
		_phase = &"core_linger"
		_timer = core_linger_after_turret
		return
	# Keep firing from remaining turrets for the rest of the window.
	if _phase == &"fire":
		_start_barrage_from_firing()


func _pick_slots() -> Array[Node2D]:
	var span := maxi(1, turrets_per_cycle_max - turrets_per_cycle_min + 1)
	var count := clampi(turrets_per_cycle_min + randi() % span, 1, _slots.size())
	var candidates: Array[int] = []
	for i in _slots.size():
		if not _last_indices.has(i):
			candidates.append(i)
	if candidates.size() < count:
		candidates.clear()
		for i in _slots.size():
			candidates.append(i)
	candidates.shuffle()
	var picked: Array[int] = []
	for i in mini(count, candidates.size()):
		picked.append(candidates[i])
	_last_indices = picked
	var result: Array[Node2D] = []
	for i in picked:
		result.append(_slots[i])
	return result


func _wire_turret_death(slot: Node2D) -> void:
	var turret := slot.get_node_or_null("Turret") as Node2D
	if turret == null:
		return
	var stats := turret.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return
	stats.no_health.connect(_on_turret_destroyed.bind(slot))


func _reset_turret_hp(slot: Node2D) -> void:
	var turret := slot.get_node_or_null("Turret") as Node2D
	if turret == null:
		return
	var stats := turret.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return
	stats.health = maxi(1, int(turret.get_meta("max_health", stats.health)))


func _show_slot(slot: Node2D, with_turret: bool) -> void:
	slot.visible = true
	slot.modulate.a = 1.0
	slot.scale = Vector2(0.45, 0.45)
	var tween := slot.create_tween()
	tween.tween_property(slot, "scale", Vector2.ONE, appear_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_part_active(slot.get_node_or_null("Turret") as Node2D, with_turret)
	_set_part_active(slot.get_node_or_null("Core") as Node2D, true)
	var bay := slot.get_node_or_null("Bay") as CanvasItem
	if bay != null:
		bay.visible = true


func _hide_slot(slot: Node2D) -> void:
	_set_part_active(slot.get_node_or_null("Turret") as Node2D, false)
	_set_part_active(slot.get_node_or_null("Core") as Node2D, false)
	var bay := slot.get_node_or_null("Bay") as CanvasItem
	if bay != null:
		bay.visible = false
	slot.visible = false
	slot.modulate.a = 0.0
	slot.scale = Vector2(0.4, 0.4)


func _set_part_active(part: Node2D, active: bool) -> void:
	if part == null:
		return
	part.visible = active
	var hurtbox := part.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox == null:
		return
	hurtbox.set_deferred("monitoring", active)
	hurtbox.set_deferred("monitorable", active)
	for child in hurtbox.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not active)


func _pulse_core(slot: Node2D, _delta: float) -> void:
	var core := slot.get_node_or_null("Core") as Node2D
	if core == null or not core.visible:
		return
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.012)
	core.scale = Vector2.ONE * pulse
	var glow := core.get_node_or_null("Glow") as CanvasItem
	if glow != null:
		glow.modulate.a = 0.35 + 0.35 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018))
