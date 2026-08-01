extends SceneTree

## 함선 시설 강화가 공통 스탯과 오른쪽 UI에 반영되는지 확인한다.
## 밸런스 수치는 미확정이라 절대값이 아니라 "레벨업 전/후 변화"만 검증한다.

const FACILITY_IDS: Array[StringName] = [
	&"weapon_room", &"hangar", &"engine", &"hull", &"radar", &"shield",
]
const SHIP_PANEL_PATH := "Layout/RightPanel/Margin/VBox/ShipPanel"
const STATUS_HUD_PATH := "Layout/LeftPanel/Margin/VBox/ShipStatusHud"
const GAMEPLAY_PATH := "Layout/Playfield/ViewportContainer/PlayfieldViewport/Gameplay"
const MAIN_LASER_PATH := "res://resources/weapons/definitions/main_laser.tres"
const AUX_CANNON_PATH := "res://resources/weapons/definitions/aux_test_cannon.tres"
const AUX_MISSILE_PATH := "res://resources/weapons/definitions/aux_homing_missile.tres"

var failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Control = load("res://world.tscn").instantiate() as Control
	root.add_child(world)
	var gameplay: Node = world.get_node(GAMEPLAY_PATH)
	var ship: Node2D = gameplay.get_node("Ship") as Node2D
	var registry: ShipFacilityRegistry = gameplay.get_node("ShipFacilityRegistry") as ShipFacilityRegistry
	var panel: ShipPanel = world.get_node(SHIP_PANEL_PATH) as ShipPanel
	var loadout: PlayerWeaponLoadout = ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	var applier: ShipFacilityApplier = ship.call("get_facility_applier") as ShipFacilityApplier
	var move_component: MoveComponent = ship.get_node("MoveComponent") as MoveComponent
	var stats: StatsComponent = ship.get_node("StatsComponent") as StatsComponent
	var shield: ShieldComponent = ship.get_node("ShieldComponent") as ShieldComponent
	var hurtbox: HurtboxComponent = ship.get_node("PlayerHitPoint/HurtboxComponent") as HurtboxComponent
	var offer: AugmentOfferController = gameplay.get_node("AugmentOfferController") as AugmentOfferController
	var status_hud: ShipStatusHud = world.get_node(STATUS_HUD_PATH) as ShipStatusHud
	for _index in 4:
		await process_frame

	_expect(registry != null, "gameplay carries a ShipFacilityRegistry")
	_expect(panel != null, "right panel carries a ShipPanel")
	if registry == null or panel == null:
		_finish()
		return

	_check_right_panel_fits(world)

	_check_initial_state(registry, panel)
	await _check_weapon_room(registry, loadout, panel)
	await _check_hangar(registry, loadout)
	_check_engine(registry, move_component)
	_check_hull(registry, applier, stats)
	_check_radar(registry, applier)
	_check_shield(registry, applier, shield)
	_check_shield_gate(stats, shield, hurtbox)
	_check_status_hud(status_hud, stats, shield, applier)
	await _check_depletion_still_clears_slot(loadout)
	_check_ui_selection_is_read_only(registry, panel)
	_check_facility_augments(offer, registry, loadout)

	_finish()


## 우측 패널은 세로 여유가 거의 없어, 내용이 실제 가용 높이를 넘지 않는지 확인한다.
func _check_right_panel_fits(world: Control) -> void:
	var right_panel: Control = world.get_node("Layout/RightPanel") as Control
	var margin: MarginContainer = world.get_node("Layout/RightPanel/Margin") as MarginContainer
	var box: VBoxContainer = world.get_node("Layout/RightPanel/Margin/VBox") as VBoxContainer
	var available: float = right_panel.size.y - float(
		margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom")
	)
	_expect(
		box.get_combined_minimum_size().y <= available,
		"ship panel and weapon HUD fit inside the right panel (%s > %s)" % [
			box.get_combined_minimum_size().y, available,
		],
	)


func _check_initial_state(registry: ShipFacilityRegistry, panel: ShipPanel) -> void:
	for facility_id in FACILITY_IDS:
		_expect(registry.has_facility(facility_id), "registry knows facility '%s'" % facility_id)
		_expect(
			registry.get_facility_level(facility_id) == 1,
			"facility '%s' starts at Lv.1" % facility_id,
		)
	var module: ShipFacilityModule = panel.get_node("WeaponRoom") as ShipFacilityModule
	_expect(module != null, "ship panel holds a weapon room module")
	if module != null:
		var name_label: Label = module.get_node("NameLabel") as Label
		var level_label: Label = module.get_node("LevelLabel") as Label
		var icon: TextureRect = module.get_node("Icon") as TextureRect
		_expect(level_label.text.contains("Lv.1"), "weapon room module prints its level")
		_expect(name_label.text.contains("무기실"), "weapon room module prints its display name")
		_expect(icon.texture != null, "weapon room module shows its facility icon")
	_expect(
		not panel.get_detail_text().is_empty(),
		"facility detail starts with a selected facility",
	)


## 무기실은 주무기 공통 배율만 올리고, 보조무기와 무기 교체에는 영향을 주지 않는다.
func _check_weapon_room(
	registry: ShipFacilityRegistry,
	loadout: PlayerWeaponLoadout,
	panel: ShipPanel,
) -> void:
	if not _require_upgradable(registry, &"weapon_room"):
		return
	var main_weapon: WeaponSystem = loadout.get_main_slot().equipped_weapon_instance
	_expect(main_weapon != null, "main slot has a live weapon instance")
	if main_weapon == null:
		return

	var cannon: WeaponDefinition = load(AUX_CANNON_PATH) as WeaponDefinition
	loadout.equip_auxiliary_weapon(cannon, 0)
	await process_frame
	var aux_weapon: WeaponSystem = loadout.get_auxiliary_slot(0).equipped_weapon_instance
	var aux_damage_before: float = aux_weapon.get_effective_damage_multiplier()
	var main_damage_before: float = main_weapon.get_effective_damage_multiplier()

	_expect(registry.upgrade_facility(&"weapon_room"), "weapon room upgrades")
	await process_frame

	_expect(
		main_weapon.get_effective_damage_multiplier() > main_damage_before,
		"weapon room raises the equipped main weapon damage multiplier",
	)
	_expect(
		is_equal_approx(aux_weapon.get_effective_damage_multiplier(), aux_damage_before),
		"weapon room leaves auxiliary weapon damage untouched",
	)

	var facility_multiplier: float = loadout.get_facility_main_damage_multiplier()
	var laser: WeaponDefinition = load(MAIN_LASER_PATH) as WeaponDefinition
	loadout.equip_main_weapon(laser)
	await process_frame
	var swapped_weapon: WeaponSystem = loadout.get_main_slot().equipped_weapon_instance
	_expect(swapped_weapon != null, "swapped main weapon is instanced")
	if swapped_weapon != null:
		_expect(
			is_equal_approx(swapped_weapon.get_effective_damage_multiplier(), facility_multiplier),
			"weapon room bonus survives a main weapon swap",
		)
		_expect(
			swapped_weapon is LaserWeaponSystem
			and is_equal_approx((swapped_weapon as LaserWeaponSystem).beam_width_multiplier, 1.0),
			"weapon room does not touch weapon-specific behaviour (beam width)",
		)

	var module: ShipFacilityModule = panel.get_node("WeaponRoom") as ShipFacilityModule
	var level_label: Label = module.get_node("LevelLabel") as Label
	_expect(level_label.text.contains("Lv.2"), "ship panel refreshes the level immediately")


## 격납고는 최대 탄약만 올린다. 이미 쓴 탄약을 전부 회복시키지 않는다.
func _check_hangar(registry: ShipFacilityRegistry, loadout: PlayerWeaponLoadout) -> void:
	if not _require_upgradable(registry, &"hangar"):
		return
	var cannon_weapon: WeaponSystem = loadout.get_auxiliary_slot(0).equipped_weapon_instance
	_expect(cannon_weapon != null, "auxiliary slot 0 has a consumable weapon")
	if cannon_weapon == null:
		return

	for _shot in 3:
		cannon_weapon.call("fire")
	await process_frame
	var max_before: int = cannon_weapon.get_consumable_max()
	var remaining_before: int = cannon_weapon.get_consumable_remaining()
	_expect(remaining_before < max_before, "firing spends charges")

	_expect(registry.upgrade_facility(&"hangar"), "hangar upgrades")
	await process_frame

	var bonus: int = loadout.get_facility_auxiliary_ammo_bonus()
	_expect(bonus > 0, "hangar level feeds an auxiliary ammo bonus")
	_expect(
		cannon_weapon.get_consumable_max() == max_before + bonus,
		"hangar raises the maximum ammo of the equipped auxiliary weapon",
	)
	_expect(
		cannon_weapon.get_consumable_remaining() == remaining_before + bonus,
		"hangar grants only the added capacity, not a full refill",
	)

	var missile: WeaponDefinition = load(AUX_MISSILE_PATH) as WeaponDefinition
	loadout.equip_auxiliary_weapon(missile, 1)
	await process_frame
	var missile_weapon: WeaponSystem = loadout.get_auxiliary_slot(1).equipped_weapon_instance
	_expect(missile_weapon != null, "newly equipped auxiliary weapon is instanced")
	if missile_weapon != null:
		_expect(
			missile_weapon.get_consumable_max() == missile_weapon.get_consumable_remaining(),
			"a newly acquired auxiliary weapon starts at the raised maximum",
		)
		_expect(
			missile_weapon.get_consumable_capacity_bonus() == bonus,
			"the hangar bonus applies to auxiliary weapons acquired later",
		)


func _check_engine(registry: ShipFacilityRegistry, move_component: MoveComponent) -> void:
	if not _require_upgradable(registry, &"engine"):
		return
	var multiplier_before: float = move_component.velocity_multiplier
	_expect(registry.upgrade_facility(&"engine"), "engine upgrades")
	_expect(
		move_component.velocity_multiplier > multiplier_before,
		"engine level reaches the player's move speed immediately",
	)


## 선체는 최대 내구도만 올리고, 늘어난 만큼만 현재 선체가 함께 오른다.
func _check_hull(
	registry: ShipFacilityRegistry,
	applier: ShipFacilityApplier,
	stats: StatsComponent,
) -> void:
	if not _require_upgradable(registry, &"hull"):
		return
	var hull_before: int = stats.health
	var max_hull_before: int = applier.get_max_hull()
	_expect(registry.upgrade_facility(&"hull"), "hull upgrades")
	var bonus_delta: int = applier.get_max_hull() - max_hull_before
	_expect(bonus_delta > 0, "hull level raises max hull")
	_expect(
		applier.get_max_hull() == applier.base_max_hull + applier.get_max_hull_bonus(),
		"max hull stays split into base and hull facility bonus",
	)
	_expect(
		stats.health == hull_before + bonus_delta,
		"the max hull increase is added to the current hull",
	)


## 레이더는 수집 반경만 넓힌다.
func _check_radar(registry: ShipFacilityRegistry, applier: ShipFacilityApplier) -> void:
	if not _require_upgradable(registry, &"radar"):
		return
	var radius_before: float = applier.get_collection_radius()
	_expect(radius_before > 0.0, "the ship exposes a pickup collection radius")
	_expect(registry.upgrade_facility(&"radar"), "radar upgrades")
	_expect(
		applier.get_collection_radius() > radius_before,
		"radar widens the pickup collection radius",
	)
	_expect(
		is_equal_approx(
			applier.get_collection_radius(),
			applier.base_collection_radius
			* registry.get_effect_total(ShipFacilityDefinition.Effect.PICKUP_RANGE),
		),
		"collection radius stays base × radar multiplier",
	)


## 실드는 선체와 분리된 자원이며, 늘어난 최대치만큼 현재 실드도 함께 오른다.
func _check_shield(
	registry: ShipFacilityRegistry,
	applier: ShipFacilityApplier,
	shield: ShieldComponent,
) -> void:
	if not _require_upgradable(registry, &"shield"):
		return
	_expect(shield != null, "the ship carries a ShieldComponent")
	if shield == null:
		return
	var max_hull_before: int = applier.get_max_hull()
	var current_before: int = shield.get_current_shield()
	var max_before: int = shield.get_max_shield()
	_expect(registry.upgrade_facility(&"shield"), "shield upgrades")
	var delta: int = shield.get_max_shield() - max_before
	_expect(delta > 0, "shield level raises the max shield")
	_expect(
		shield.get_current_shield() == current_before + delta,
		"the max shield increase is added to the current shield",
	)
	_expect(
		applier.get_max_hull() == max_hull_before,
		"the shield facility leaves max hull untouched",
	)


## 실드 게이트: 실드가 1 이상이면 초과 피해가 선체로 넘어가지 않는다.
func _check_shield_gate(
	stats: StatsComponent,
	shield: ShieldComponent,
	hurtbox: HurtboxComponent,
) -> void:
	if shield == null or hurtbox == null:
		_expect(false, "shield gate needs a ShieldComponent and the player hurtbox")
		return
	if shield.get_current_shield() < 1:
		shield.restore_shield(1)
	_expect(shield.get_current_shield() >= 1, "the shield is charged before the gated hit")
	var hull_before: int = stats.health

	var heavy_hit := HitboxComponent.new()
	heavy_hit.damage = 50
	hurtbox.hurt.emit(heavy_hit)
	heavy_hit.free()
	_expect(stats.health == hull_before, "a gated hit does not spill overkill into the hull")
	_expect(shield.get_current_shield() == 0, "a gated hit leaves the shield at 0")

	var light_hit := HitboxComponent.new()
	light_hit.damage = 1
	hurtbox.hurt.emit(light_hit)
	light_hit.free()
	_expect(stats.health == hull_before - 1, "with no shield left the hull takes the damage")

	shield.restore_shield(99)
	_expect(
		shield.get_current_shield() == shield.get_max_shield(),
		"restore_shield never exceeds the max shield",
	)


## 전투 HUD는 선체·실드의 현재값을 그대로 보여준다.
func _check_status_hud(
	status_hud: ShipStatusHud,
	stats: StatsComponent,
	shield: ShieldComponent,
	applier: ShipFacilityApplier,
) -> void:
	_expect(status_hud != null, "the left panel carries a hull/shield HUD")
	if status_hud == null:
		return
	status_hud.refresh()
	var hull_label: Label = status_hud.get_node("HullLabel") as Label
	var shield_label: Label = status_hud.get_node("ShieldLabel") as Label
	var hull_bar: ProgressBar = status_hud.get_node("HullBar") as ProgressBar
	_expect(
		hull_label.text.contains("%d / %d" % [stats.health, applier.get_max_hull()]),
		"the hull gauge prints current / max hull (%s)" % hull_label.text,
	)
	_expect(
		shield_label.text.contains(
			"%d / %d" % [shield.get_current_shield(), shield.get_max_shield()]
		),
		"the shield gauge prints current / max shield (%s)" % shield_label.text,
	)
	_expect(
		is_equal_approx(hull_bar.value, float(stats.health)),
		"the hull bar follows the current hull",
	)


## 격납고 강화 후에도 기존 소진 규칙(탄약 0 → 슬롯 제거)이 유지되는지 확인한다.
func _check_depletion_still_clears_slot(loadout: PlayerWeaponLoadout) -> void:
	var weapon: WeaponSystem = loadout.get_auxiliary_slot(0).equipped_weapon_instance
	if weapon == null:
		_expect(false, "auxiliary slot 0 still holds a weapon before depletion")
		return
	var shots: int = weapon.get_consumable_max() + 4
	for _shot in shots:
		if not is_instance_valid(weapon):
			break
		weapon.call("fire")
	await process_frame
	await process_frame
	_expect(
		loadout.get_auxiliary_slot(0).is_empty(),
		"a depleted auxiliary weapon still clears its slot",
	)


func _check_ui_selection_is_read_only(registry: ShipFacilityRegistry, panel: ShipPanel) -> void:
	var levels_before: Array[int] = []
	for facility_id in FACILITY_IDS:
		levels_before.append(registry.get_facility_level(facility_id))
	panel.select_facility(&"engine")
	_expect(panel.get_selected_facility_id() == &"engine", "selecting a facility updates the panel")
	_expect(
		panel.get_detail_text().contains("엔진"),
		"facility detail shows the selected facility",
	)
	var index := 0
	for facility_id in FACILITY_IDS:
		_expect(
			registry.get_facility_level(facility_id) == levels_before[index],
			"UI selection does not change facility levels ('%s')" % facility_id,
		)
		index += 1


## 시설 레벨을 올리는 유일한 인게임 경로가 오그먼트인지 확인한다.
## 오퍼 UI는 일시정지·await를 타므로 후보 판정과 적용 함수만 직접 호출한다.
func _check_facility_augments(
	offer: AugmentOfferController,
	registry: ShipFacilityRegistry,
	loadout: PlayerWeaponLoadout,
) -> void:
	_expect(offer != null, "gameplay carries an AugmentOfferController")
	if offer == null:
		return
	var facility_augments: Dictionary = {}
	for augment in offer.player_augment_pool:
		if augment != null and augment.augment_type == PlayerAugmentKind.Kind.UPGRADE_FACILITY:
			facility_augments[augment.facility_id] = augment
	for facility_id in FACILITY_IDS:
		_expect(
			facility_augments.has(facility_id),
			"the offer pool carries a facility augment for '%s'" % facility_id,
		)
	var card: PlayerAugment = facility_augments.get(&"weapon_room") as PlayerAugment
	if card == null:
		return
	_expect(card.icon != null, "a facility augment card carries an icon")

	var level_before: int = registry.get_facility_level(&"weapon_room")
	_expect(
		offer._is_player_augment_available(card, loadout),
		"an upgradable facility augment is offered",
	)
	offer._upgrade_facility(card)
	_expect(
		registry.get_facility_level(&"weapon_room") == level_before + card.facility_level_gain,
		"picking a facility augment raises the facility level",
	)

	while registry.can_upgrade_facility(&"weapon_room"):
		registry.upgrade_facility(&"weapon_room")
	_expect(
		not offer._is_player_augment_available(card, loadout),
		"a maxed facility no longer shows up in the offer",
	)


## 레벨 표가 Lv.1뿐이면 강화 검증을 할 수 없으므로 실패로 남긴다.
func _require_upgradable(registry: ShipFacilityRegistry, facility_id: StringName) -> bool:
	if registry.can_upgrade_facility(facility_id):
		return true
	_expect(false, "facility '%s' needs at least two level values to be tested" % facility_id)
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ship facility upgrade test: PASS")
		quit()
		return
	for failure in failures:
		push_error("ship facility upgrade test: %s" % failure)
	quit(1)
