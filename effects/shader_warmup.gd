class_name ShaderWarmup
extends Node

## First-start pipeline warm-up (docs/design/scene-flow.md 「Menu」).
##
## The renderer compiles each shader / blend / particle variant the first time
## it is drawn. Measured cold on the main display: the ship engine particles
## ~170 ms, the orbital-ring backdrop shader ~90 ms, the HDR playfield glow
## ~40 ms, elite glow / bullet batches / card surfaces 30-60 ms each. Left to
## the game they land on the World entry frame and on the first bullet, elite,
## explosion and offer of a run. This node draws representative instances in
## two offscreen SubViewports (HDR like the playfield, SDR like the overlay
## UI) for a few frames while the menu's black fade covers the screen, then
## frees itself. Everything it instantiates is already cached by the
## world.tscn preload, so no file loads happen here.

signal finished

const FRAMES := 3
const STAGE_SIZE := Vector2i(160, 120)

## Set once a warm-up has run in this process; the menu skips later starts.
static var completed := false

var _frames_left := FRAMES


func _ready() -> void:
	completed = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hdr := _make_stage(true)
	var sdr := _make_stage(false)
	_populate_playfield(hdr)
	_populate_overlay(sdr)


func _process(_delta: float) -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	set_process(false)
	finished.emit()
	queue_free()


func _make_stage(hdr: bool) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "HdrStage" if hdr else "SdrStage"
	viewport.size = STAGE_SIZE
	viewport.use_hdr_2d = hdr
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = not hdr
	add_child(viewport)
	if hdr:
		var gameplay := load("res://gameplay.tscn") as PackedScene
		var environment := _find_environment(gameplay)
		if environment != null:
			var world_environment := WorldEnvironment.new()
			world_environment.environment = environment
			viewport.add_child(world_environment)
	return viewport


## The playfield Environment from gameplay.tscn's scene state (no instantiate).
static func _find_environment(scene: PackedScene) -> Environment:
	if scene == null:
		return null
	var state := scene.get_state()
	for node_index in state.get_node_count():
		if state.get_node_type(node_index) != "WorldEnvironment":
			continue
		for property_index in state.get_node_property_count(node_index):
			if state.get_node_property_name(node_index, property_index) == "environment":
				return state.get_node_property_value(node_index, property_index) as Environment
	return null


func _populate_playfield(stage: SubViewport) -> void:
	var background := _instance("res://effects/space_background.tscn")
	if background != null:
		background.set("backdrop", load("res://resources/backdrop/default_backdrop.tres"))
		stage.add_child(background)
	# Ship and elite visuals only: their Anchor subtrees carry the glow
	# materials and the engine particles without any gameplay component.
	var ship_anchor := _detach_anchor("res://player_ship/ship.tscn")
	if ship_anchor != null:
		ship_anchor.position = Vector2(40, 60)
		stage.add_child(ship_anchor)
	var elite_anchor := _detach_anchor("res://enemies/elite_fighter.tscn")
	if elite_anchor != null:
		elite_anchor.position = Vector2(80, 40)
		stage.add_child(elite_anchor)
	var enemy_anchor := _detach_anchor("res://enemies/enemy.tscn")
	if enemy_anchor != null:
		enemy_anchor.position = Vector2(120, 40)
		stage.add_child(enemy_anchor)
	var flash := Sprite2D.new()
	flash.texture = load("res://icon.svg")
	flash.scale = Vector2(0.1, 0.1)
	flash.position = Vector2(20, 20)
	flash.material = load("res://effects/white_flash_material.tres")
	stage.add_child(flash)
	var explosion := _instance("res://effects/explosion_effect.tscn")
	if explosion != null:
		for child in explosion.get_children():
			if child is AudioStreamPlayer:
				child.stream = null
		explosion.position = Vector2(60, 90)
		stage.add_child(explosion)
	# Shared hit-effect renderer: antialiased lines + gradient flares, additive.
	var impact := ImpactVfx.new()
	impact.material = load("res://effects/additive_unshaded_material.tres")
	stage.add_child(impact)
	var profile := load("res://effects/impact_profiles/blaster.tres") as ImpactProfile
	if profile != null:
		impact.emit_impact(Vector2(70, 70), profile, Vector2.DOWN, 1.0, false, 12.0)
	var blaster := _instance("res://projectiles/player_blaster.tscn")
	if blaster != null:
		blaster.position = Vector2(100, 110)
		stage.add_child(blaster)
	# Bullet kinds: round mesh batch, textured batch, trail particles, laser ribbon.
	var bullets := Node2D.new()
	bullets.name = "Bullets"
	stage.add_child(bullets)
	for path in [
		"res://resources/projectiles/round_straight_shot.tres",
		"res://resources/projectiles/rice_wave_shot.tres",
		"res://resources/projectiles/needle_straight_shot.tres",
		"res://resources/projectiles/elite_fountain_laser_shot.tres",
	]:
		var shot := load(path) as BarrageShot
		if shot != null and shot.is_valid():
			shot.spawn(bullets, Vector2(30, 30), Vector2.DOWN, 20.0)
	var trail_shot := BarrageShot.new()
	trail_shot.appearance = load("res://resources/projectiles/round.tres")
	trail_shot.behavior = BulletBehavior.new()
	trail_shot.trail_effect = load("res://resources/projectiles/diamond_trail.tres")
	if trail_shot.is_valid():
		trail_shot.spawn(bullets, Vector2(50, 20), Vector2.DOWN, 60.0)


func _populate_overlay(stage: SubViewport) -> void:
	var offset := 0.0
	for path in [
		"res://menus/cards/augment_card_silver.tscn",
		"res://menus/cards/augment_card_gold.tscn",
		"res://menus/cards/augment_card_prismatic.tscn",
		"res://menus/cards/augment_card_enemy.tscn",
	]:
		var card := _instance(path) as Control
		if card == null:
			continue
		card.position = Vector2(offset, 0.0)
		offset += 40.0
		stage.add_child(card)
		if card.has_method("configure_copy"):
			card.call("configure_copy", "워밍업", "셰이더 준비", load("res://icon.svg"))
	var warning := EncounterStepWarning.new()
	warning.warning_duration = 1.0
	stage.add_child(warning)


static func _instance(path: String) -> Node:
	var scene := load(path) as PackedScene
	return scene.instantiate() if scene != null else null


## Visual-only subtree of an actor scene; the rest is freed without _ready.
static func _detach_anchor(path: String) -> Node2D:
	var actor := _instance(path)
	if actor == null:
		return null
	var anchor := actor.get_node_or_null("Anchor") as Node2D
	if anchor != null:
		actor.remove_child(anchor)
	actor.free()
	return anchor
