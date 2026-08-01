extends SceneTree

const FACILITY_IDS: Array[StringName] = [
	&"weapon_room", &"hangar", &"engine", &"hull", &"radar", &"shield",
]
const SHIP_PANEL_PATH := "Layout/RightPanel/Margin/VBox/ShipPanel"
const GAMEPLAY_PATH := "Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay"

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := (load("res://world.tscn") as PackedScene).instantiate() as Control
	root.add_child(world)
	var gameplay: Node = world.get_node(GAMEPLAY_PATH)
	var ship := gameplay.get_node("Ship") as Node2D
	var registry := gameplay.get_node("PlayerAugmentRegistry") as PlayerAugmentRegistry
	var panel := world.get_node(SHIP_PANEL_PATH) as ShipPanel
	var offer := gameplay.get_node("AugmentOfferController") as AugmentOfferController
	var selection_ui := offer.selection_ui
	var swap_ui := offer.module_swap_ui
	var loadout := ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	var move_component := ship.get_node("MoveComponent") as MoveComponent
	var facility_applier := ship.call("get_facility_applier") as ShipFacilityApplier
	var stats := ship.get_node("StatsComponent") as StatsComponent
	var shield := ship.get_node("ShieldComponent") as ShieldComponent
	for _index in 4:
		await process_frame

	_check_initial_slots(registry, panel)
	_check_pool_targets(offer, registry)
	await _check_offer_layout(selection_ui)
	await _check_module_keyboard_activation()
	_check_engine_modules(registry, move_component, panel)
	_check_facility_effect_modules(registry, loadout, facility_applier, stats, shield)
	_check_replacement(registry, loadout)
	_check_swap_overlay(swap_ui, registry)
	_check_right_panel_fits(world)

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ship facility upgrade test: PASS")
		quit()
		return
	for failure in failures:
		push_error("ship facility upgrade test: %s" % failure)
	quit(1)


func _check_initial_slots(registry: PlayerAugmentRegistry, panel: ShipPanel) -> void:
	for facility_id in FACILITY_IDS:
		_expect(registry.has_facility(facility_id), "registry knows facility '%s'" % facility_id)
		_expect(registry.get_slot_capacity(facility_id) == 1, "%s starts with one slot" % facility_id)
		_expect(registry.get_installed_count(facility_id) == 0, "%s starts empty" % facility_id)
	var weapon_room := panel.get_node("WeaponRoom") as ShipFacilityModule
	_expect(not weapon_room.has_node("LevelLabel"), "ship panel does not show a numeric slot counter")
	_expect(weapon_room.get_visual_slot_count() == 1, "ship panel draws the default empty slot")
	_expect(weapon_room.get_slot_rect(0).size == Vector2(18, 18), "ship panel slot is large enough for an icon")


func _check_pool_targets(offer: AugmentOfferController, registry: PlayerAugmentRegistry) -> void:
	for augment in offer.player_augment_pool:
		_expect(augment.facility_id != &"", "%s declares a target facility" % augment.augment_id)
		_expect(
			registry.has_facility(augment.facility_id),
			"%s targets a registered facility" % augment.augment_id,
		)


func _check_engine_modules(
	registry: PlayerAugmentRegistry,
	move_component: MoveComponent,
	panel: ShipPanel,
) -> void:
	var base_speed := move_component.velocity_multiplier
	var speed_module := load(
		"res://resources/player_augments/player_move_speed_boost_1_2.tres"
	) as PlayerAugment
	var engine_module := load(
		"res://resources/player_augments/facilities/facility_engine.tres"
	) as PlayerAugment
	_expect(registry.install_augment(speed_module) == 0, "first engine module fills the default slot")
	_expect(
		is_equal_approx(move_component.velocity_multiplier, base_speed * 1.2),
		"installed stat module applies its movement multiplier",
	)
	_expect(registry.install_augment(engine_module) == -1, "full facility rejects install without replacement")
	_expect(registry.expand_slots(&"engine"), "engine expands to two slots")
	_expect(registry.install_augment(engine_module) == 1, "expanded empty slot accepts a module")
	var engine_chip := panel.get_facility_module(&"engine")
	_expect(
		engine_chip.get_slot_icon(1) == engine_module.icon,
		"installed augment icon is exposed by its visual slot",
	)
	_expect(
		is_equal_approx(move_component.velocity_multiplier, base_speed * 1.2 * 1.1),
		"stat and facility effect modules compose",
	)
	_expect(registry.install_augment(engine_module, &"", 0) == 0, "occupied slot can be replaced")
	_expect(registry.get_stack_count(speed_module.augment_id) == 0, "replaced stat module leaves active set")
	_expect(
		is_equal_approx(move_component.velocity_multiplier, base_speed * 1.2),
		"replacing a module removes its effect and recomputes remaining modules",
	)
	_expect(registry.expand_slots(&"engine"), "engine expands to the maximum three slots")
	_expect(not registry.expand_slots(&"engine"), "facility cannot expand beyond three slots")


func _check_facility_effect_modules(
	registry: PlayerAugmentRegistry,
	loadout: PlayerWeaponLoadout,
	applier: ShipFacilityApplier,
	stats: StatsComponent,
	shield: ShieldComponent,
) -> void:
	var weapon_room := load(
		"res://resources/player_augments/facilities/facility_weapon_room.tres"
	) as PlayerAugment
	var hangar := load(
		"res://resources/player_augments/facilities/facility_hangar.tres"
	) as PlayerAugment
	var hull := load(
		"res://resources/player_augments/facilities/facility_hull.tres"
	) as PlayerAugment
	var radar := load(
		"res://resources/player_augments/facilities/facility_radar.tres"
	) as PlayerAugment
	var shield_module := load(
		"res://resources/player_augments/facilities/facility_shield.tres"
	) as PlayerAugment
	var base_hull := applier.get_max_hull()
	var base_radius := applier.get_collection_radius()

	registry.install_augment(weapon_room)
	registry.install_augment(hangar)
	registry.install_augment(hull)
	registry.install_augment(radar)
	registry.install_augment(shield_module)
	_expect(
		is_equal_approx(loadout.get_facility_main_damage_multiplier(), 1.15),
		"weapon-room module applies main weapon damage",
	)
	_expect(loadout.get_facility_auxiliary_ammo_bonus() == 4, "hangar module adds auxiliary ammo")
	_expect(applier.get_max_hull() == base_hull + 1, "hull module increases maximum hull")
	_expect(stats.health == applier.get_max_hull(), "maximum hull increase also raises current hull")
	_expect(
		is_equal_approx(applier.get_collection_radius(), base_radius * 1.15),
		"radar module increases collection radius",
	)
	_expect(shield.get_max_shield() == 1, "shield module increases maximum shield")


func _check_replacement(registry: PlayerAugmentRegistry, loadout: PlayerWeaponLoadout) -> void:
	var damage_module := load(
		"res://resources/player_augments/player_weapon_damage_boost_1_2.tres"
	) as PlayerAugment
	_expect(
		registry.install_augment(damage_module) == -1,
		"full weapon room requires an explicit replacement index",
	)
	_expect(registry.install_augment(damage_module, &"", 0) == 0, "replacement installs incoming module")
	_expect(
		is_equal_approx(loadout.get_facility_main_damage_multiplier(), 1.0),
		"replacing facility module removes its main-only effect",
	)
	var main_weapon := loadout.get_main_slot().equipped_weapon_instance
	_expect(
		is_equal_approx(main_weapon.get_effective_damage_multiplier(), 1.2),
		"replacement stat module applies its global weapon damage effect",
	)


func _check_offer_layout(selection_ui: AugmentSelectionOverlay) -> void:
	var button_1 := selection_ui.get_node("MarginContainer/PanelContainer/VBoxContainer/ChoiceRow/ChoiceButton1")
	var button_3 := selection_ui.get_node("MarginContainer/PanelContainer/VBoxContainer/ChoiceRow/ChoiceButton3")
	var ship_panel := selection_ui.get_node(
		"MarginContainer/PanelContainer/VBoxContainer/OfferShipPanel"
	) as ShipPanel
	_expect(button_1.get_parent() == button_3.get_parent(), "three augment choices share one horizontal row")
	_expect(ship_panel is ShipPanel, "player offer embeds the ship part UI below choices")
	var fire_rate := load(
		"res://resources/player_augments/player_fire_rate_boost_1_2.tres"
	) as PlayerAugment
	var move_speed := load(
		"res://resources/player_augments/player_move_speed_boost_1_2.tres"
	) as PlayerAugment
	selection_ui._set_choices([fire_rate, move_speed])
	selection_ui._showing_ship_modules = true
	selection_ui._set_ship_section_visible(true)
	selection_ui._set_choice_buttons_visible(true)
	selection_ui.visible = true
	selection_ui.choice_container.visible = true
	selection_ui.breakpoint_intro.visible = false
	selection_ui._set_input_enabled(true)
	selection_ui._highlight_choice(1)
	_expect(
		ship_panel.get_selected_facility_id() == &"engine",
		"focusing an augment highlights its target ship facility",
	)
	var weapon_room := ship_panel.get_facility_module(&"weapon_room")
	for facility_id in FACILITY_IDS:
		_expect(
			ship_panel.get_facility_module(facility_id).focus_mode == Control.FOCUS_ALL,
			"%s expansion option accepts keyboard focus" % facility_id,
		)
	var down_path: NodePath = button_1.focus_neighbor_bottom
	_expect(not down_path.is_empty(), "augment card has an explicit keyboard path to ship slots")
	_expect(
		button_1.get_node(down_path) == weapon_room,
		"down from an augment card enters its target ship part",
	)
	button_1.grab_focus()
	await process_frame
	paused = true
	await _press_action(&"ui_down")
	_expect(root.gui_get_focus_owner() == weapon_room, "ui_down moves focus from card to ship part")
	await _press_action(&"ui_up")
	paused = false
	_expect(root.gui_get_focus_owner() == button_1, "ui_up moves focus from ship part to card row")
	ship_panel._on_facility_focused(&"weapon_room")
	_expect(weapon_room.has_expansion_preview(), "focused ship part flashes its next slot")
	_expect(weapon_room.get_visual_slot_count() == 2, "expansion preview draws one upcoming slot")
	var initial_preview_alpha := weapon_room.get_preview_alpha()
	paused = true
	await create_timer(0.5, true).timeout
	paused = false
	_expect(
		not is_equal_approx(weapon_room.get_preview_alpha(), initial_preview_alpha),
		"expansion preview keeps blinking while the offer pauses gameplay",
	)
	_expect(
		not weapon_room.focus_neighbor_top.is_empty(),
		"top ship slot row has an explicit keyboard path back to augment cards",
	)
	selection_ui._set_input_enabled(false)
	selection_ui.visible = false
	var enemy_choices: Array[EnemyAugment] = [
		load("res://resources/enemy_augments/enemy_health_boost_1_2.tres") as EnemyAugment,
		load("res://resources/enemy_augments/enemy_move_speed_boost_1_2.tres") as EnemyAugment,
		load("res://resources/enemy_augments/enemy_fire_volume_boost.tres") as EnemyAugment,
	]
	selection_ui._set_choices(enemy_choices)
	selection_ui._showing_ship_modules = false
	selection_ui._set_ship_section_visible(false)
	selection_ui._set_choice_buttons_visible(true)
	selection_ui._set_input_enabled(true)
	_expect(
		button_1.focus_neighbor_bottom.is_empty(),
		"enemy offer keeps keyboard navigation within its card row",
	)
	_expect(
		not button_1.focus_neighbor_right.is_empty(),
		"enemy offer cards remain keyboard navigable",
	)
	selection_ui._set_input_enabled(false)


func _check_module_keyboard_activation() -> void:
	var module := (load("res://menus/ship_facility_module.tscn") as PackedScene).instantiate() as ShipFacilityModule
	root.add_child(module)
	await process_frame
	module.facility_id = &"engine"
	module.set_selection_enabled(true)
	var activated := [false]
	module.facility_clicked.connect(func(_facility_id: StringName) -> void: activated[0] = true)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	module._gui_input(accept)
	_expect(activated[0], "focused ship part can be selected with the keyboard accept action")
	module.queue_free()
	await process_frame


func _press_action(action: StringName) -> void:
	var pressed_event := InputEventAction.new()
	pressed_event.action = action
	pressed_event.pressed = true
	Input.parse_input_event(pressed_event)
	await process_frame
	var released_event := InputEventAction.new()
	released_event.action = action
	released_event.pressed = false
	Input.parse_input_event(released_event)
	await process_frame


func _check_swap_overlay(
	swap_ui: AugmentModuleSwapOverlay,
	registry: PlayerAugmentRegistry,
) -> void:
	var incoming := load(
		"res://resources/player_augments/facilities/facility_weapon_room.tres"
	) as PlayerAugment
	swap_ui.open(registry, &"weapon_room", incoming)
	var first_button := swap_ui.get_node("MarginContainer/VBoxContainer/SlotButton1") as Button
	_expect(swap_ui.visible, "full facility opens the module replacement window")
	_expect(first_button.text.contains("과충전 탄두"), "replacement window identifies installed module")
	swap_ui.close()


func _check_right_panel_fits(world: Control) -> void:
	var right_panel := world.get_node("Layout/RightPanel") as Control
	var margin := world.get_node("Layout/RightPanel/Margin") as MarginContainer
	var box := world.get_node("Layout/RightPanel/Margin/VBox") as VBoxContainer
	var available := right_panel.size.y - float(
		margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom")
	)
	_expect(box.get_combined_minimum_size().y <= available, "ship and weapon panels fit the right rail")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
