class_name PlayerAugment
extends Resource

const ROMAN := ["", "I", "II", "III", "IV", "V"]

@export var augment_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var augment_type: PlayerAugmentKind.Kind = PlayerAugmentKind.Kind.STAT_MULTIPLIER
@export var icon: Texture2D
@export var stat_modifiers: Array[PlayerStatModifier] = []
@export var behavior_components: Array[PackedScene] = []
## Compatibility primary tag. Facility effects no longer own per-facility slots.
@export var facility_id: StringName
## Classification tags used for identity, icons and future synergies.
@export var module_tags: Array[StringName] = []
## Per-module facility effect. Preferred over ShipFacilityDefinition curves when set.
@export var facility_module_effect: FacilityModuleEffect
## Relative pick weight inside the offer pool (data-tunable; not a fixed design %).
@export_range(0.0, 100.0, 0.01) var offer_weight := 1.0

## WEAPON_ACQUIRE / WEAPON_TRAIT
@export var weapon_definition: WeaponDefinition
## WEAPON_TRAIT (and optional ACQUIRE filter): which weapon this belongs to.
@export var target_weapon_id: StringName
## WEAPON_TRAIT: module id stored on weapon progress.
@export var trait_id: StringName
@export_range(1, 3, 1) var trait_rank_increase := 1
@export var trait_definition: WeaponTraitDefinition


func get_weapon_id() -> StringName:
	if target_weapon_id != &"":
		return target_weapon_id
	if weapon_definition != null:
		return weapon_definition.id
	return &""


func get_module_tags() -> Array[StringName]:
	var tags := module_tags.duplicate()
	if facility_id != &"" and not tags.has(facility_id):
		tags.push_front(facility_id)
	return tags


func has_module_tag(tag: StringName) -> bool:
	return tag != &"" and get_module_tags().has(tag)


func get_primary_module_tag() -> StringName:
	var tags := get_module_tags()
	return tags[0] if not tags.is_empty() else &""


func get_offer_title(loadout: PlayerWeaponLoadout = null) -> String:
	match augment_type:
		PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
			return "신규 병기 모듈\n%s" % _weapon_display_name()
		PlayerAugmentKind.Kind.WEAPON_TRAIT:
			var trait_name := display_name
			if trait_definition != null and trait_definition.display_name != "":
				trait_name = trait_definition.display_name
			var next_rank := trait_rank_increase
			if loadout != null:
				var current_rank := int(
					loadout.get_weapon_traits(get_weapon_id()).get(trait_id, 0)
				)
				next_rank = mini(
					current_rank + trait_rank_increase,
					loadout.get_trait_max_rank(trait_id),
				)
			return "%s\n모듈 Lv.%s" % [trait_name, ROMAN[clampi(next_rank, 1, ROMAN.size() - 1)]]
		_:
			return display_name


func get_offer_description(_loadout: PlayerWeaponLoadout = null) -> String:
	match augment_type:
		PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
			if weapon_definition != null and weapon_definition.description != "":
				return weapon_definition.description
			return description
		PlayerAugmentKind.Kind.WEAPON_TRAIT:
			if trait_definition != null and trait_definition.description != "":
				return trait_definition.description
			return description
		_:
			return description


func get_offer_icon() -> Texture2D:
	if icon != null:
		return icon
	if weapon_definition != null and weapon_definition.icon != null:
		return weapon_definition.icon
	if trait_definition != null:
		return trait_definition.icon
	return null


func _weapon_display_name() -> String:
	if weapon_definition != null and weapon_definition.display_name != "":
		return weapon_definition.display_name
	var id := get_weapon_id()
	return String(id) if id != &"" else display_name
