class_name ThreatMonitorLab
extends Control

@onready var gameplay: Node2D = $Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay
@onready var monitor: Node = $ThreatMonitor
@onready var graph: Control = %ThreatGraph


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ship := gameplay.get_node("Ship") as Node2D
	var hurtbox := ship.get_node("PlayerHitPoint/HurtboxComponent") as HurtboxComponent
	assert(hurtbox != null, "Threat monitor lab requires the ship HurtboxComponent.")
	hurtbox.is_invincible = true
	monitor.sample_updated.connect(_update_display)
	%RestartButton.pressed.connect(_restart)
	_update_display(monitor.take_sample_now())


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var key := key_event.physical_keycode
	if key == KEY_NONE:
		key = key_event.keycode
	if key == KEY_R:
		_restart()
		get_viewport().set_input_as_handled()


func _restart() -> void:
	if get_tree().paused:
		get_tree().paused = false
	get_tree().reload_current_scene()


func _update_display(sample: Dictionary) -> void:
	if sample.is_empty():
		return
	%CurrentValue.text = "%05.1f" % float(sample.current)
	%SmoothValue.text = "%05.1f" % float(sample.smooth)
	%PeakValue.text = "%05.1f" % float(sample.peak)
	%DoseValue.text = "%07.1f" % float(sample.dose)
	_set_component(&"Attack", float(sample.attack))
	_set_component(&"Space", float(sample.space))
	_set_component(&"Reaction", float(sample.reaction))
	_set_component(&"Removal", float(sample.removal))
	_set_component(&"Pattern", float(sample.pattern))
	%EnemyCount.text = "적                 %3d" % int(sample.enemy_count)
	%ProjectileCount.text = "적탄               %3d" % int(sample.projectile_count)
	%RelevantProjectileCount.text = "방어 구역 진입 탄   %3d" % int(sample.relevant_projectile_count)
	%ConcurrentSources.text = "동시 공격원         %3d" % int(sample.active_source_count)
	%ThreatFamilies.text = "공격 종류           %3d" % int(sample.threat_family_count)
	%AttackRate.text = "예상 적탄/초       %5.1f" % float(sample.attack_rate)
	%RemovalTime.text = "제거 예상          %5.1fs" % float(sample.removal_seconds)
	%PassiveSafeRatio.text = "정지 안전 비율     %5.1f%%" % (float(sample.passive_safe_ratio) * 100.0)
	%Fragmentation.text = "안전 공간 분절     %5.1f%%" % (float(sample.fragmentation) * 100.0)
	var reaction_time := float(sample.min_reaction_time)
	%ReactionTime.text = (
		"최소 대응 여유       --"
		if reaction_time < 0.0
		else "최소 대응 여유    %5.2fs" % reaction_time
	)
	%SampleCount.text = "표본               %5d" % int(sample.sample_count)
	graph.set_values(monitor.get_history_values())


func _set_component(prefix: StringName, value: float) -> void:
	var label := find_child("%sValue" % prefix, true, false) as Label
	var bar := find_child("%sBar" % prefix, true, false) as ProgressBar
	assert(label != null and bar != null, "Threat monitor component controls must exist.")
	label.text = "%3.0f" % (value * 100.0)
	bar.value = value * 100.0
