extends SceneTree

const FACILITY_IDS: Array[StringName] = [
	&"weapon_room", &"hangar", &"engine", &"hull", &"radar", &"shield",
]
const SHIP_PANEL_PATH := "Layout/RightPanel/Margin/VBox/ShipPanel"
const WEAPON_HUD_PATH := "Layout/RightPanel/Margin/VBox/WeaponBox/Margin/WeaponLoadoutHud"
const GAMEPLAY_PATH := "Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay"

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := (load("res://world.tscn") as PackedScene).instantiate() as Control
	root.add_child(world)
	var gameplay: Node = world.get_node(GAMEPLAY_PATH)
	var playfield := world.get_node("Layout/Playfield") as Control
	var ship := gameplay.get_node("Ship") as Node2D
	var registry := gameplay.get_node("PlayerAugmentRegistry") as PlayerAugmentRegistry
	var panel := world.get_node(SHIP_PANEL_PATH) as ShipPanel
	var weapon_hud := world.get_node(WEAPON_HUD_PATH) as WeaponLoadoutHud
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
	await _check_offer_layout(selection_ui, loadout, panel, weapon_hud, playfield)
	_check_engine_modules(registry, move_component, panel)
	_check_facility_effect_modules(registry, loadout, facility_applier, stats, shield)
	_check_replacement(registry, loadout)
	_check_swap_overlay(swap_ui, registry)
	_check_capacity_limits(registry, swap_ui, panel)
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
	_expect(registry.get_slot_capacity() == 5, "universal pool starts with five slots")
	_expect(registry.get_installed_count() == 0, "universal pool starts empty")
	_expect(panel.get_node_or_null("WeaponRoom") == null, "legacy facility tiles are removed")
	_expect(panel.get_node_or_null("ShipDiagram") == null, "legacy ship diagram is removed")
	_expect(panel.slot_rack.get_visible_slot_count() == 5, "honeycomb draws all five starting slots")
	_expect(panel.slot_rack.get_slot_icon(0) == null, "universal rack shows an empty starting slot")
	var slot_size := panel.slot_rack.get_slot_rect(0).size
	_expect(
		is_equal_approx(slot_size.x, 28.0) and is_equal_approx(slot_size.y, 28.0 * 0.866025),
		"flat-top hex slots use the enlarged module scale",
	)
	_expect(panel.get_detail_text().contains("범용 슬롯 0/5"), "ship panel shows universal slot usage")
	var slot_zero := panel.slot_rack.get_slot_polygon(0)
	var slot_one := panel.slot_rack.get_slot_polygon(1)
	_expect(
		slot_zero[2].is_equal_approx(slot_one[0])
		and slot_zero[3].is_equal_approx(slot_one[5]),
		"adjacent hex slots share an edge without a gap",
	)


func _check_pool_targets(offer: AugmentOfferController, registry: PlayerAugmentRegistry) -> void:
	for augment in offer.player_augment_pool:
		if PlayerAugmentKind.is_weapon_offer(augment.augment_type):
			continue
		_expect(not augment.module_tags.is_empty(), "%s declares an explicit module tag" % augment.augment_id)
		_expect(
			registry.has_facility(augment.get_primary_module_tag()),
			"%s uses a registered primary tag" % augment.augment_id,
		)


func _check_engine_modules(
	registry: PlayerAugmentRegistry,
	move_component: MoveComponent,
	panel: ShipPanel,
) -> void:
	var base_speed := move_component.velocity_multiplier
	var engine_module := load(
		"res://resources/player_augments/facilities/facility_engine.tres"
	) as PlayerAugment
	_expect(engine_module.has_module_tag(&"engine"), "engine category is preserved as a module tag")
	_expect(registry.install_augment(engine_module) == 0, "first engine module fills universal slot zero")
	_expect(
		is_equal_approx(move_component.velocity_multiplier, base_speed * 1.25),
		"engine facility module applies its movement multiplier",
	)
	_expect(registry.install_augment(engine_module) == 1, "same-tag module uses another universal slot")
	var engine_definition := registry.get_facility_definition(&"engine")
	_expect(
		panel.slot_rack.get_slot_icon(1) == engine_definition.icon,
		"installed slot temporarily uses its primary tag icon",
	)
	panel.slot_rack.slot_hovered.emit(1)
	_expect(
		panel.get_detail_text().contains("엔진") and panel.get_detail_text().contains(engine_module.display_name),
		"installed hex hover shows its tag and actual module name",
	)
	panel.slot_rack.slot_hover_exited.emit()
	_expect(
		is_equal_approx(move_component.velocity_multiplier, base_speed * 1.25 * 1.25),
		"two engine modules multiply move-speed module effects (×1.25²)",
	)
	_expect(
		is_equal_approx(move_component.velocity_multiplier, base_speed * 1.25 * 1.25),
		"same-tag modules keep the product stack",
	)
	_expect(registry.get_installed_count_by_tag(&"engine") == 2, "tag query finds both engine modules")
	registry.clear_augments()
	_expect(registry.get_slot_capacity() == 5, "clear resets the universal capacity")


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
	_expect(not registry.has_empty_slot(), "five mixed tags fill the shared starting pool")
	_expect(
		is_equal_approx(loadout.get_facility_damage_multiplier(), 1.15),
		"weapon-room module applies equipped weapon damage",
	)
	var hangar_def := load("res://resources/facilities/definitions/hangar.tres") as ShipFacilityDefinition
	_expect(hangar_def.display_name == "동력로", "hangar facility display is renamed to 동력로")
	_expect(hangar.display_name.contains("과충전"), "hangar module is the periodic overcharge reactor")
	_expect(is_equal_approx(hangar_def.get_value_for_module_count(1), 0.0), "hangar definition curve stays inert")
	_expect(applier.get_max_hull() == base_hull + 1, "hull module increases maximum hull")
	_expect(stats.health == applier.get_max_hull(), "maximum hull increase also raises current hull")
	_expect(
		is_equal_approx(applier.get_collection_radius(), base_radius * 1.5),
		"radar module increases collection radius",
	)
	_expect(shield.get_max_shield() == 2, "shield module adds +1 on top of base max 1")
	_expect(shield.get_current_shield() == 2, "max increase also raises current shield")


func _check_replacement(registry: PlayerAugmentRegistry, loadout: PlayerWeaponLoadout) -> void:
	var engine := load(
		"res://resources/player_augments/facilities/facility_engine.tres"
	) as PlayerAugment
	# weapon_room already has one damage module from _check_facility_effect_modules
	var fire_rate := load(
		"res://resources/player_augments/facilities/facility_weapon_room_fire_rate.tres"
	) as PlayerAugment
	_expect(
		registry.install_augment(fire_rate) == -1,
		"full weapon room requires an explicit replacement index",
	)
	_expect(registry.install_augment(fire_rate, &"", 0) == 0, "replacement installs fire-rate module")
	_expect(
		is_equal_approx(loadout.get_facility_damage_multiplier(), 1.0),
		"replacing damage module removes its common damage bonus",
	)
	_expect(
		is_equal_approx(loadout.get_facility_fire_rate_multiplier(), 1.15),
		"weapon-room fire-rate module applies to equipped weapons",
	)
	var equipped_weapon := loadout.get_bay(0).equipped_weapon_instance as WeaponSystem
	_expect(
		equipped_weapon != null
		and is_equal_approx(equipped_weapon.get_effective_fire_rate_multiplier(), 1.15),
		"equipped weapon receives the facility fire-rate multiplier",
	)
	_expect(registry.get_installed_count_by_tag(&"weapon_room") == 1, "weapon-room tag still has one module after replace")
	_expect(engine != null, "engine facility module resource loads")


func _check_offer_layout(
	selection_ui: AugmentSelectionOverlay,
	loadout: PlayerWeaponLoadout,
	status_ship_panel: ShipPanel,
	weapon_hud: WeaponLoadoutHud,
	playfield: Control,
) -> void:
	selection_ui.configure_weapon_loadout(loadout)
	var button_1 := selection_ui.get_node(
		"MarginContainer/PanelContainer/VBoxContainer/ChoiceCarousel/ChoiceButton1"
	) as Button
	var button_2 := selection_ui.get_node(
		"MarginContainer/PanelContainer/VBoxContainer/ChoiceCarousel/ChoiceButton2"
	) as Button
	var button_3 := selection_ui.get_node(
		"MarginContainer/PanelContainer/VBoxContainer/ChoiceCarousel/ChoiceButton3"
	) as Button
	var expand_button := selection_ui.get_node(
		"MarginContainer/PanelContainer/VBoxContainer/SlotActionLabel"
	) as Button
	var reroll_button := selection_ui.get_node("%RerollButton") as Button
	_expect(button_1.get_parent() == button_3.get_parent(), "three choices share the carousel host")
	_expect(
		button_1.get_parent().name == "ChoiceCarousel",
		"augment choices use the cylinder carousel instead of a flat HBox row",
	)
	_expect(
		selection_ui.get_node_or_null("%OfferShipPanel") == null
		and selection_ui.get_node_or_null("%OfferWeaponPreview") == null,
		"offer no longer duplicates STATUS ship and weapon panels",
	)
	_expect(not selection_ui.prompt_label.visible, "choice view omits the redundant instruction copy")
	_expect(button_1.size.y > button_1.size.x, "augment cards use a taller portrait proportion")
	for button in [button_1, button_2, button_3]:
		_expect(
			button.get_theme_stylebox(&"disabled") == button.get_theme_stylebox(&"normal"),
			"augment card keeps the same content margins when selection disables input",
		)
	var offer_rect := selection_ui.choice_container.get_global_rect()
	var playfield_rect := playfield.get_global_rect()
	_expect(
		offer_rect.position.x >= playfield_rect.position.x - 0.5
		and offer_rect.position.x + offer_rect.size.x
		<= playfield_rect.position.x + playfield_rect.size.x + 0.5,
		"the whole augment window stays inside the central playfield",
	)
	selection_ui.set_reroll_state(2, true)
	_expect(
		reroll_button.text == "[R] 리롤 (2)"
		and selection_ui.get_node_or_null("%RerollLabel") == null,
		"reroll uses one compact button without a duplicate count label",
	)
	var fire_rate := load(
		"res://resources/player_augments/facilities/facility_weapon_room_fire_rate.tres"
	) as PlayerAugment
	var move_speed := load(
		"res://resources/player_augments/facilities/facility_engine.tres"
	) as PlayerAugment
	var acquire_laser := load(
		"res://resources/player_augments/weapon/acquire_main_laser.tres"
	) as PlayerAugment
	selection_ui._set_choices([fire_rate, move_speed, acquire_laser])
	selection_ui._focused_choice_index = 0
	selection_ui._showing_ship_modules = true
	selection_ui._set_ship_section_visible(true)
	selection_ui._set_choice_buttons_visible(true)
	selection_ui.visible = true
	selection_ui.choice_container.visible = true
	selection_ui.breakpoint_intro.visible = false
	selection_ui._set_input_enabled(true)
	selection_ui._highlight_choice(1)
	await create_timer(selection_ui.carousel_transition_duration + 0.05, true).timeout
	_expect(
		status_ship_panel.get_selected_facility_id() == &"engine",
		"facility focus highlights the existing right STATUS ship panel",
	)
	_expect(
		status_ship_panel.slot_rack.has_module_preview()
		and status_ship_panel.slot_rack.get_module_preview_index() == 0,
		"facility focus previews its icon in the first empty STATUS slot",
	)
	var engine_definition := selection_ui._player_registry.get_facility_definition(&"engine")
	_expect(
		status_ship_panel.slot_rack.get_slot_icon(0) == engine_definition.icon,
		"facility preview uses the matching facility icon",
	)
	var initial_module_alpha: float = status_ship_panel.slot_rack.get_preview_alpha()
	paused = true
	await create_timer(0.5, true).timeout
	paused = false
	_expect(
		not is_equal_approx(status_ship_panel.slot_rack.get_preview_alpha(), initial_module_alpha),
		"facility icon preview keeps blinking while gameplay is paused",
	)
	_expect(selection_ui.get_focused_choice_index() == 1, "carousel tracks the focused card")
	_expect(button_2.z_index > button_1.z_index, "focused carousel card renders in front")
	_expect(button_2.modulate.a > button_1.modulate.a, "side cards are more transparent than focus")
	_expect(button_2.scale.x > button_1.scale.x, "side cards are smaller than focus")
	var down_path: NodePath = button_1.focus_neighbor_bottom
	_expect(not down_path.is_empty(), "augment card has a keyboard path to reroll")
	_expect(
		button_1.get_node(down_path) == reroll_button,
		"down from an augment card enters the reroll button",
	)
	button_1.grab_focus()
	await create_timer(selection_ui.carousel_transition_duration + 0.05, true).timeout
	var viewport_height := selection_ui.get_viewport().get_visible_rect().size.y
	_expect(
		selection_ui.choice_container.global_position.y >= -0.5,
		"player offer title stays inside the top of the viewport",
	)
	_expect(
		selection_ui.choice_container.global_position.y + selection_ui.choice_container.size.y
		<= viewport_height + 0.5,
		"player offer panel stays inside the bottom of the viewport",
	)
	paused = true
	await _press_action(&"ui_right")
	_expect(root.gui_get_focus_owner() == button_2, "ui_right rotates focus to the next card")
	_expect(selection_ui.get_focused_choice_index() == 1, "right rotation updates carousel focus")
	var first_rotation := selection_ui._carousel_tween
	await _press_action(&"ui_right")
	_expect(
		selection_ui._carousel_tween == first_rotation
		and selection_ui.get_focused_choice_index() == 1,
		"rapid repeat is ignored while the carousel is on cooldown",
	)
	await create_timer(selection_ui.carousel_min_rotation_interval + 0.05, true).timeout
	_expect(
		root.gui_get_focus_owner() == button_2
		and selection_ui.get_focused_choice_index() == 1,
		"ignored rapid press does not rotate after release or cooldown",
	)
	await _press_action(&"ui_right")
	_expect(
		root.gui_get_focus_owner() == button_3
		and selection_ui.get_focused_choice_index() == 2,
		"a fresh press after the interval rotates once",
	)
	await create_timer(selection_ui.carousel_min_rotation_interval + 0.05, true).timeout
	await _press_action(&"ui_left")
	await create_timer(selection_ui.carousel_min_rotation_interval + 0.05, true).timeout
	await _press_action(&"ui_left")
	await create_timer(selection_ui.carousel_min_rotation_interval + 0.05, true).timeout
	_expect(root.gui_get_focus_owner() == button_1, "left rotation returns to the first card")
	_expect(
		button_1.focus_neighbor_left == button_1.get_path_to(button_1)
		and button_1.focus_neighbor_right == button_1.get_path_to(button_1),
		"carousel cards do not auto-navigate left/right via focus neighbors",
	)
	await _press_action(&"ui_down")
	_expect(root.gui_get_focus_owner() == reroll_button, "ui_down moves focus from card to reroll")
	await _press_action(&"ui_down")
	_expect(root.gui_get_focus_owner() == expand_button, "second ui_down enters universal expansion")
	_expect(status_ship_panel.slot_rack.has_expansion_preview(), "right STATUS reveals the next hex slot")
	_expect(
		not status_ship_panel.slot_rack.has_module_preview(),
		"slot expansion focus replaces the facility-module preview",
	)
	_expect(status_ship_panel.slot_rack.get_visible_slot_count() == 6, "preview adds exactly one hex slot")
	var first_row_hex := status_ship_panel.slot_rack.get_slot_polygon(0)
	var second_row_hex := status_ship_panel.slot_rack.get_slot_polygon(5)
	_expect(
		first_row_hex.size() >= 5
		and second_row_hex.size() >= 2
		and first_row_hex[3].is_equal_approx(second_row_hex[1])
		and first_row_hex[4].is_equal_approx(second_row_hex[0]),
		"honeycomb rows share flat edges without gaps",
	)
	var initial_preview_alpha := status_ship_panel.slot_rack.get_preview_alpha()
	await create_timer(0.5, true).timeout
	_expect(
		not is_equal_approx(status_ship_panel.slot_rack.get_preview_alpha(), initial_preview_alpha),
		"next hex keeps blinking while gameplay is paused",
	)
	await _press_action(&"ui_up")
	_expect(root.gui_get_focus_owner() == reroll_button, "ui_up returns from expansion to reroll")
	_expect(not status_ship_panel.slot_rack.has_expansion_preview(), "leaving expansion hides the preview hex")
	_expect(status_ship_panel.slot_rack.has_module_preview(), "leaving expansion restores card preview")
	await _press_action(&"ui_up")
	paused = false
	_expect(root.gui_get_focus_owner() == button_1, "second ui_up returns to the focused card")
	_expect(
		selection_ui.slot_action_label.text.contains("범용 슬롯"),
		"facility preview identifies the shared slot pool",
	)
	selection_ui._set_choices([acquire_laser, move_speed, fire_rate])
	selection_ui._focused_choice_index = 0
	selection_ui._set_choice_buttons_visible(true)
	selection_ui._highlight_choice(0)
	_expect(not expand_button.disabled, "weapon acquisition keeps universal facility-slot expansion")
	_expect(
		selection_ui.slot_action_label.text.contains("범용 슬롯"),
		"weapon focus keeps the slot expansion label instead of a weapon banner",
	)
	_expect(
		button_1.get_node(button_1.focus_neighbor_bottom) == reroll_button,
		"weapon cards still navigate down to the reroll button",
	)
	_expect(
		reroll_button.get_node(reroll_button.focus_neighbor_bottom) == expand_button,
		"weapon cards still navigate from reroll to universal expansion",
	)
	_expect(
		status_ship_panel.get_selected_facility_id() == &"",
		"weapon acquisition clears unrelated facility highlight",
	)
	_expect(
		weapon_hud.is_augment_preview_active(),
		"weapon acquisition uses the existing right STATUS weapon HUD",
	)
	_expect(
		weapon_hud.get_preview_bay_index() == loadout.get_first_empty_bay(),
		"new weapon blinks in the first empty STATUS bay",
	)
	var initial_weapon_alpha: float = weapon_hud.get_preview_alpha()
	paused = true
	await create_timer(0.5, true).timeout
	paused = false
	_expect(
		not is_equal_approx(weapon_hud.get_preview_alpha(), initial_weapon_alpha),
		"new weapon preview keeps blinking while gameplay is paused",
	)

	var laser := load("res://resources/weapons/definitions/main_laser.tres") as WeaponDefinition
	var cannon := load("res://resources/weapons/definitions/aux_test_cannon.tres") as WeaponDefinition
	var acquire_shotgun := load(
		"res://resources/player_augments/weapon/acquire_main_shotgun.tres"
	) as PlayerAugment
	_expect(loadout.offer_equip_weapon(laser), "test fills second bay")
	_expect(loadout.offer_equip_weapon(cannon), "test fills third bay")
	selection_ui._set_choices([acquire_shotgun, move_speed, fire_rate])
	selection_ui._focused_choice_index = 0
	selection_ui._set_choice_buttons_visible(true)
	selection_ui._highlight_choice(0)
	_expect(not weapon_hud.is_augment_preview_active(), "full bays skip speculative weapon blink")
	loadout.unequip_weapon(&"main_laser")
	loadout.clear_weapon_progress(&"main_laser")
	loadout.unequip_weapon(&"aux_test_cannon")
	loadout.clear_weapon_progress(&"aux_test_cannon")

	var trait_blaster := load(
		"res://resources/player_augments/weapon/trait_blaster_rapid_loader.tres"
	) as PlayerAugment
	selection_ui._set_choices([trait_blaster, move_speed, fire_rate])
	selection_ui._focused_choice_index = 0
	selection_ui._set_choice_buttons_visible(true)
	selection_ui._highlight_choice(0)
	_expect(
		weapon_hud.is_augment_preview_active() and weapon_hud.get_preview_bay_index() == 0,
		"weapon trait focus highlights its target STATUS bay",
	)
	_expect(
		weapon_hud.has_module_augment_preview()
		and weapon_hud.get_preview_module_trait_id() == &"blaster_rapid_loader",
		"weapon trait previews its next module level in the STATUS module grid",
	)
	var initial_trait_alpha: float = weapon_hud.get_preview_alpha()
	paused = true
	await create_timer(0.5, true).timeout
	paused = false
	_expect(
		not is_equal_approx(weapon_hud.get_preview_alpha(), initial_trait_alpha),
		"weapon module preview keeps blinking while gameplay is paused",
	)
	selection_ui._highlight_choice(1)
	_expect(not weapon_hud.is_augment_preview_active(), "facility focus clears weapon preview")
	_expect(not weapon_hud.has_module_augment_preview(), "facility focus clears weapon module preview")
	_expect(
		status_ship_panel.get_selected_facility_id() == &"engine",
		"facility focus restores its own STATUS highlight",
	)
	selection_ui._on_choice_pressed(2)
	_expect(
		selection_ui.get_focused_choice_index() == 2,
		"clicking a side card rotates it into focus before selection",
	)
	selection_ui._set_input_enabled(false)
	selection_ui._clear_status_preview()
	selection_ui.visible = false
	var enemy_choices: Array[EnemyAugment] = [
		load("res://resources/enemy_augments/enemy_health_boost_1_2.tres") as EnemyAugment,
		load("res://resources/enemy_augments/enemy_move_speed_boost_1_2.tres") as EnemyAugment,
		load("res://resources/enemy_augments/enemy_fire_volume_boost.tres") as EnemyAugment,
	]
	selection_ui._set_choices(enemy_choices)
	selection_ui._showing_ship_modules = false
	selection_ui._set_ship_section_visible(false)
	selection_ui.set_reroll_state(-1, false)
	selection_ui._set_choice_buttons_visible(true)
	selection_ui._set_input_enabled(true)
	selection_ui._highlight_choice(0)
	_expect(
		button_1.focus_neighbor_bottom.is_empty(),
		"enemy offer keeps keyboard navigation within its carousel",
	)
	_expect(
		button_1.focus_neighbor_right == button_1.get_path_to(button_1),
		"enemy carousel still owns left/right instead of cycling focus neighbors",
	)
	_expect(not weapon_hud.is_augment_preview_active(), "enemy offer leaves player STATUS preview clear")
	selection_ui._set_input_enabled(false)


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
	swap_ui.open(registry, incoming)
	var first_button := swap_ui.get_node(
		"MarginContainer/VBoxContainer/SlotScroll/SlotList/SlotButton1"
	) as Button
	_expect(swap_ui.visible, "full universal pool opens the module replacement window")
	_expect(first_button.text.contains("사격 통제 장치"), "replacement window identifies installed module")
	_expect(first_button.text.contains("무기실"), "replacement row preserves the module tag name")
	swap_ui.close()


func _check_capacity_limits(
	registry: PlayerAugmentRegistry,
	swap_ui: AugmentModuleSwapOverlay,
	panel: ShipPanel,
) -> void:
	registry.clear_augments()
	for expected_capacity in range(
		PlayerAugmentRegistry.DEFAULT_SLOT_CAPACITY + 1,
		PlayerAugmentRegistry.MAX_SLOT_CAPACITY + 1
	):
		_expect(registry.expand_slots(), "universal pool expands to %d" % expected_capacity)
		_expect(
			registry.get_slot_capacity() == expected_capacity,
			"universal capacity reaches %d" % expected_capacity,
		)
	_expect(not registry.expand_slots(), "universal pool cannot exceed fifteen slots")
	var engine := load(
		"res://resources/player_augments/facilities/facility_engine.tres"
	) as PlayerAugment
	for index in PlayerAugmentRegistry.MAX_SLOT_CAPACITY:
		_expect(registry.install_augment(engine) == index, "universal slot %d accepts a module" % (index + 1))
	panel.set_augment_preview(engine)
	_expect(not panel.slot_rack.has_module_preview(), "full module pool skips incoming icon blink")
	swap_ui.open(registry, engine)
	_expect(
		swap_ui.get_node_or_null("MarginContainer/VBoxContainer/SlotScroll/SlotList/SlotButton15") != null,
		"replacement scroll builds all fifteen universal slot rows",
	)
	swap_ui.close()


func _check_right_panel_fits(world: Control) -> void:
	var layout := world.get_node("Layout") as Control
	var left := world.get_node("Layout/LeftPanel") as Control
	var play := world.get_node("Layout/Playfield") as Control
	var right_panel := world.get_node("Layout/RightPanel") as Control
	var margin := world.get_node("Layout/RightPanel/Margin") as MarginContainer
	var box := world.get_node("Layout/RightPanel/Margin/VBox") as VBoxContainer
	# Compare against the shell viewport, not the panel's inflated size after overflow.
	var shell := layout.size
	var margin_y := float(
		margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom")
	)
	var margin_x := float(
		margin.get_theme_constant("margin_left") + margin.get_theme_constant("margin_right")
	)
	_expect(shell.y >= 360.0 - 0.5, "world shell keeps 360px height")
	_expect(
		box.get_combined_minimum_size().y <= shell.y - margin_y + 0.5,
		"ship and weapon panels fit the right rail height",
	)
	_expect(
		box.get_combined_minimum_size().x <= right_panel.custom_minimum_size.x - margin_x + 0.5
		or box.get_combined_minimum_size().x <= 200.0 - margin_x + 0.5,
		"weapon bay clusters fit the 200px right rail width",
	)
	_expect(
		left.size.x + play.size.x + right_panel.size.x <= shell.x + 1.0,
		"left + playfield + right fit 640px shell width",
	)
	_expect(right_panel.size.y <= shell.y + 0.5, "right rail does not overflow shell height")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
