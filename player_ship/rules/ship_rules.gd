class_name ShipRules
extends RefCounted

## Availability and application of run rule cards (`PlayerAugment.rule_id`,
## augments.md 규칙 카드). Rules that keep acting install a node under the ship.

const FOURTH_WEAPON_BAY := &"fourth_weapon_bay"
const TIME_WARP := &"time_warp"
const BRINK := &"brink"
const RESONANCE_FIRE := &"resonance_fire"

const FOURTH_WEAPON_BAY_DAMAGE_MULTIPLIER := 0.85
const FOURTH_WEAPON_BAY_COUNT := 4

const RUNTIME_SCRIPTS := {
	TIME_WARP: preload("res://player_ship/rules/time_warp_rule.gd"),
	BRINK: preload("res://player_ship/rules/brink_rule.gd"),
	RESONANCE_FIRE: preload("res://player_ship/rules/resonance_rule.gd"),
}


static func is_available(rule_id: StringName, ship: Node2D, loadout: PlayerWeaponLoadout) -> bool:
	match rule_id:
		FOURTH_WEAPON_BAY:
			return loadout != null and loadout.get_max_equipped_weapon_count() < FOURTH_WEAPON_BAY_COUNT
		TIME_WARP:
			return _applier(ship) != null
		BRINK:
			var shield := _shield(ship)
			return shield != null and shield.get_max_shield() >= 1
		RESONANCE_FIRE:
			return ship != null and loadout != null
		_:
			return false


## Applies the rule once; returns false when it is unknown or unavailable.
static func apply(rule_id: StringName, ship: Node2D, loadout: PlayerWeaponLoadout) -> bool:
	if not is_available(rule_id, ship, loadout):
		return false
	if rule_id == FOURTH_WEAPON_BAY:
		loadout.add_weapon_bays(FOURTH_WEAPON_BAY_COUNT - loadout.get_max_equipped_weapon_count())
		loadout.set_rule_damage_multiplier(
			loadout.get_rule_damage_multiplier() * FOURTH_WEAPON_BAY_DAMAGE_MULTIPLIER
		)
		return true
	var script := RUNTIME_SCRIPTS.get(rule_id) as GDScript
	if script == null:
		return false
	var runtime: Node = script.new()
	runtime.call(&"install", ship, loadout)
	return true


## The installed runtime node for `rule_id`, or null.
static func get_runtime(ship: Node, rule_id: StringName) -> Node:
	var script := RUNTIME_SCRIPTS.get(rule_id) as GDScript
	if ship == null or script == null:
		return null
	for child in ship.get_children():
		if child.get_script() == script:
			return child
	return null


static func _applier(ship: Node) -> PlayerAugmentApplier:
	return ship.get_node_or_null("PlayerAugmentApplier") as PlayerAugmentApplier if ship != null else null


static func _shield(ship: Node) -> ShieldComponent:
	return ship.get_node_or_null("ShieldComponent") as ShieldComponent if ship != null else null
