class_name ResonanceRule
extends Node

## Prismatic rule: every enemy defeat makes the next equipped weapon in bay
## order fire once more (WeaponSystem.fire_bonus_shot). Weapons that cannot
## (orbital barrier) are skipped. Bonus shots are at least `min_interval`
## gameplay seconds apart; defeats in between are dropped. All weapons fire at
## `fire_rate_mult` for the run.

signal bonus_fired(weapon: WeaponSystem)

@export var fire_rate_mult := 0.8
@export var min_interval := 0.1

var _loadout: PlayerWeaponLoadout
var _next_index := 0
var _clock := 0.0
var _last_bonus := -INF


func install(ship: Node2D, loadout: PlayerWeaponLoadout) -> void:
	_loadout = loadout
	loadout.set_rule_fire_rate_multiplier(loadout.get_rule_fire_rate_multiplier() * fire_rate_mult)
	name = "ResonanceRule"
	ship.add_child(self)


func _ready() -> void:
	add_to_group(Enemy.DEFEAT_LISTENER_GROUP)


func _physics_process(delta: float) -> void:
	_clock += delta


func on_enemy_defeated(_enemy: Node) -> void:
	if _clock - _last_bonus < min_interval:
		return
	_last_bonus = _clock
	# Defeats arrive inside physics callbacks; spawn the shot outside them.
	_fire_next.call_deferred()


func _fire_next() -> void:
	if _loadout == null or not is_instance_valid(_loadout):
		return
	var weapons := _loadout.get_all_weapon_systems()
	for attempt in weapons.size():
		var index := (_next_index + attempt) % weapons.size()
		if weapons[index].fire_bonus_shot():
			_next_index = (index + 1) % weapons.size()
			bonus_fired.emit(weapons[index])
			return
