class_name BossWallEnemy
extends Enemy
## Full-width top wall. Hit juice only on the active turret (not the wall body).


@export var body_damage_scale := 0.08
@export var turret_punch_scale := 1.2
@export var turret_punch_duration := 0.14


func _ready() -> void:
	super._ready()
	var health_bar := get_node_or_null("EnemyHealthBar") as EnemyHealthBarComponent
	if health_bar != null:
		health_bar.enabled = false
		health_bar.visible = false
		health_bar.set_process(false)

	# Keep authored near-white wall tint (no forced crimson).
	hurtbox_component.set_meta("incoming_damage_scale", body_damage_scale)
	hurtbox_component.blocks_pierce = true
	for child in hurtbox_component.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = false
	hurtbox_component.monitoring = true
	hurtbox_component.monitorable = true

	# Drop Enemy body flash/shake/scale — wall chips with no punch juice.
	_disconnect_self_hurt_feedback(hurtbox_component)

	for slot in $Turrets.get_children():
		var turret := slot.get_node_or_null("Turret") as Node2D
		if turret != null:
			var turret_stats := turret.get_node_or_null("StatsComponent") as StatsComponent
			if turret_stats != null:
				turret.set_meta("max_health", turret_stats.health)
			var turret_hurt := turret.get_node_or_null("HurtboxComponent") as HurtboxComponent
			if turret_hurt != null:
				turret_hurt.hurt.connect(_on_turret_hurt.bind(turret))
		var weak_core := slot.get_node_or_null("Core") as Node2D
		if weak_core != null:
			var core_hurt := weak_core.get_node_or_null("HurtboxComponent") as HurtboxComponent
			if core_hurt != null:
				# Core deals boss damage but keeps juice on the turret bay only when present.
				core_hurt.hurt.connect(_on_core_hurt.bind(slot))


func _disconnect_self_hurt_feedback(hurtbox: HurtboxComponent) -> void:
	for connection in hurtbox.hurt.get_connections():
		var cb: Callable = connection["callable"]
		if cb.get_object() == self:
			hurtbox.hurt.disconnect(cb)


func _on_turret_hurt(_hitbox: HitboxComponent, turret: Node2D) -> void:
	_punch_part(turret)
	hit_sound_player.play_with_variance()


func _on_core_hurt(_hitbox: HitboxComponent, slot: Node2D) -> void:
	# Prefer turret punch if still visible; otherwise punch the core diamond only.
	var turret := slot.get_node_or_null("Turret") as Node2D
	if turret != null and turret.visible:
		_punch_part(turret)
	else:
		var core := slot.get_node_or_null("Core") as Node2D
		if core != null:
			_punch_part(core)
	hit_sound_player.play_with_variance()


func _punch_part(part: Node2D) -> void:
	if part == null or not is_instance_valid(part):
		return
	var base := part.scale
	if part.has_meta("punch_base_scale"):
		base = part.get_meta("punch_base_scale") as Vector2
	else:
		part.set_meta("punch_base_scale", base)
	var tween := part.create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(part, "scale", base * turret_punch_scale, turret_punch_duration * 0.35)
	tween.tween_property(part, "scale", base, turret_punch_duration * 0.65)
	for child in part.get_children():
		if child is CanvasItem and (child.name == "Sprite" or child.name == "Glow"):
			var item := child as CanvasItem
			var original := item.modulate
			item.modulate = Color(1.6, 1.6, 1.6, original.a)
			var flash_tween := item.create_tween()
			flash_tween.tween_property(item, "modulate", original, turret_punch_duration)
