class_name BossCarrierEnemy
extends Enemy

## Main-game shell for the carrier boss (docs/design/bosses/carrier.md 「본 게임 연결」).
## The gate flow (ThreatEliteController) needs one Enemy with a StatsComponent;
## the carrier itself (enemies/carrier/carrier_boss.gd) is a top-level child
## that moves and fights in playfield coordinates exactly as in the Lab.
## This shell has no body, hurtbox or contact hitbox: it mirrors the carrier's
## required-part HP into its StatsComponent (never below 1 while the wreck
## sinks) and drops to 0 when the sinking finishes, which triggers the normal
## boss settlement (score, XP drop, bullet-cancel reward, Threat, enemy offer).

const CarrierBoss := preload("res://enemies/carrier/carrier_boss.gd")
## Hull-local point where the shell parks for its death effect and XP drop.
const BRIDGE_OFFSET := Vector2(0.0, -630.0)
const HULL_Z_INDEX := -2
const HEALTH_BAR_Z_INDEX := 50

var carrier: Node2D


func _ready() -> void:
	super._ready()
	_disable_shell_collision()
	var anchor := get_node_or_null("Anchor") as Node2D
	if anchor != null:
		anchor.visible = false
	var health_bar := get_node_or_null("EnemyHealthBar") as EnemyHealthBarComponent
	if health_bar != null:
		health_bar.z_index = HEALTH_BAR_Z_INDEX
		health_bar.set_pinned_to_top(true)
	_spawn_carrier()


func _disable_shell_collision() -> void:
	for area in [hurtbox_component, get_node_or_null("HitboxComponent")]:
		if area == null:
			continue
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
		for child in area.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred("disabled", true)


func _spawn_carrier() -> void:
	var tree := get_tree()
	var world := tree.get_first_node_in_group("gameplay_world") as Node2D
	if world == null:
		world = tree.current_scene as Node2D
	assert(world != null, "BossCarrierEnemy requires a gameplay_world node.")
	carrier = CarrierBoss.new()
	carrier.world = world
	carrier.target = tree.get_first_node_in_group("player") as Node2D
	# Keep the Lab's playfield coordinates regardless of where the spawner put this shell.
	carrier.top_level = true
	carrier.z_index = HULL_Z_INDEX
	carrier.health_changed.connect(_on_carrier_health_changed)
	carrier.destruction_started.connect(_on_carrier_destruction_started)
	carrier.destruction_finished.connect(_on_carrier_destruction_finished)
	add_child(carrier)
	stats_component.health = carrier.maximum


func _on_carrier_health_changed(current: int, _maximum: int) -> void:
	if _is_dying:
		return
	stats_component.health = maxi(1, current)


func _on_carrier_destruction_started() -> void:
	# Death effect and the guaranteed XP drop appear at the bridge, on screen.
	if carrier != null and is_instance_valid(carrier):
		var rect := get_viewport_rect().grow(-24.0)
		var park := carrier.to_global(BRIDGE_OFFSET)
		global_position = park.clamp(rect.position, rect.end)
	movement_controller.stop()


func _on_carrier_destruction_finished() -> void:
	stats_component.health = 0
