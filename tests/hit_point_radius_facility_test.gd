extends SceneTree

## The hull facility card "압축 코어" shrinks the player hit point radius by one
## pixel per installed copy, the hurtbox and the marker follow, and the radius
## never drops below the readable minimum.

const GAMEPLAY_PATH := "Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay"
const CARD_PATH := "res://resources/player_augments/facilities/facility_hull_hit_point.tres"

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := (load("res://world.tscn") as PackedScene).instantiate() as Control
	root.add_child(world)
	var gameplay: Node = world.get_node(GAMEPLAY_PATH)
	var ship := gameplay.get_node("Ship") as Node2D
	var registry := gameplay.get_node("PlayerAugmentRegistry") as PlayerAugmentRegistry
	var applier := ship.call("get_facility_applier") as ShipFacilityApplier
	var hit_point := ship.get_node("PlayerHitPoint") as PlayerHitPoint
	var shape_node := hit_point.get_node("HurtboxComponent/CollisionShape2D") as CollisionShape2D
	var core := hit_point.get_node("Visual/Core") as PlayerHitPointCore
	for _index in 4:
		await process_frame

	var card := load(CARD_PATH) as PlayerAugment
	_expect(card != null and card.facility_module_effect != null, "hit point card loads with an effect")
	_expect(card.get_primary_module_tag() == &"hull", "hit point card is a hull module")
	_expect(card.tier == PlayerAugment.Tier.SILVER, "hit point card is a silver always-on module")
	_expect(
		card.facility_module_effect.kind == FacilityModuleEffect.Kind.HIT_POINT_RADIUS_ADD
		and is_equal_approx(card.facility_module_effect.primary, -1.0),
		"hit point card subtracts one pixel of radius",
	)

	var base_radius := hit_point.radius
	_expect(is_equal_approx(base_radius, PlayerHitPoint.BASE_RADIUS), "hit point starts at the base radius")
	_expect(is_equal_approx(applier.get_hit_point_radius(), base_radius), "applier reports the base radius")

	_expect(registry.install_augment(card) >= 0, "hit point card installs in a universal slot")
	_expect(is_equal_approx(hit_point.radius, base_radius - 1.0), "one card shrinks the radius by one pixel")
	_expect(is_equal_approx(applier.get_hit_point_radius(), base_radius - 1.0), "applier reports the shrunk radius")
	_expect(
		is_equal_approx(_hurtbox_world_radius(shape_node), base_radius - 1.0),
		"hurtbox collision radius follows the shrunk radius",
	)
	_expect(is_equal_approx(core.radius, base_radius - 1.0), "marker is redrawn at the shrunk radius")
	_expect(core.get_global_transform().get_scale().is_equal_approx(Vector2.ONE), "marker keeps a one pixel outline")

	_expect(registry.install_augment(card) >= 0, "a second copy installs")
	_expect(
		is_equal_approx(hit_point.radius, ShipFacilityApplier.MIN_HIT_POINT_RADIUS),
		"stacked copies stop at the minimum radius",
	)

	_expect(registry.uninstall_augment(card.augment_id), "first copy uninstalls")
	_expect(registry.uninstall_augment(card.augment_id), "second copy uninstalls")
	_expect(is_equal_approx(hit_point.radius, base_radius), "removing the cards restores the base radius")
	_expect(
		is_equal_approx(_hurtbox_world_radius(shape_node), base_radius),
		"hurtbox collision radius is restored",
	)

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("hit point radius facility test: PASS")
		quit()
		return
	for failure in failures:
		push_error("hit point radius facility test: %s" % failure)
	quit(1)


func _hurtbox_world_radius(shape_node: CollisionShape2D) -> float:
	var circle := shape_node.shape as CircleShape2D
	return circle.radius * shape_node.get_global_transform().get_scale().x


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
