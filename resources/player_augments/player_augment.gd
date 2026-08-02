class_name PlayerAugment
extends Resource

@export var augment_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var augment_type: PlayerAugmentKind.Kind = PlayerAugmentKind.Kind.STAT_MULTIPLIER
@export var icon: Texture2D
@export var stat_modifiers: Array[PlayerStatModifier] = []
@export var behavior_components: Array[PackedScene] = []
## Ship facility slot target. Unused for pure weapon offers (ACQUIRE/LEVEL/TRAIT).
@export var facility_id: StringName
## Relative pick weight inside the offer pool (data-tunable; not a fixed design %).
@export_range(0.0, 100.0, 0.01) var offer_weight := 1.0

## WEAPON_ACQUIRE / WEAPON_LEVEL / WEAPON_TRAIT
@export var weapon_definition: WeaponDefinition
## WEAPON_ACQUIRE: starting level when the weapon is first obtained.
@export_range(1, 3, 1) var starting_weapon_level := 1
## WEAPON_TRAIT (and optional ACQUIRE filter): which weapon this belongs to.
@export var target_weapon_id: StringName
## WEAPON_TRAIT: trait module id stored on weapon progress.
@export var trait_id: StringName
@export_range(1, 5, 1) var trait_rank_increase := 1
@export var trait_definition: WeaponTraitDefinition


func get_weapon_id() -> StringName:
	if target_weapon_id != &"":
		return target_weapon_id
	if weapon_definition != null:
		return weapon_definition.id
	return &""


func get_offer_title(loadout: PlayerWeaponLoadout = null) -> String:
	match augment_type:
		PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
			var weapon_name := _weapon_display_name()
			if loadout != null and loadout.has_weapon_progress(get_weapon_id()) \
					and not loadout.is_weapon_equipped(get_weapon_id()):
				var level := loadout.get_weapon_level(get_weapon_id())
				return "병기 모듈 복원\n%s Lv.%d" % [weapon_name, level]
			return "신규 병기 모듈\n%s" % weapon_name
		PlayerAugmentKind.Kind.WEAPON_LEVEL:
			var weapon_name := _weapon_display_name()
			if loadout != null and loadout.has_weapon_progress(get_weapon_id()):
				var level := loadout.get_weapon_level(get_weapon_id())
				return "%s 코어 강화\nLv.%d → Lv.%d" % [weapon_name, level, mini(level + 1, 3)]
			return "%s 코어 강화" % weapon_name
		PlayerAugmentKind.Kind.WEAPON_TRAIT:
			if trait_definition != null and trait_definition.display_name != "":
				return trait_definition.display_name
			return display_name
		_:
			return display_name


func get_offer_description(loadout: PlayerWeaponLoadout = null) -> String:
	match augment_type:
		PlayerAugmentKind.Kind.WEAPON_ACQUIRE:
			if loadout != null and loadout.has_weapon_progress(get_weapon_id()) \
					and not loadout.is_weapon_equipped(get_weapon_id()):
				var traits := loadout.get_weapon_traits(get_weapon_id())
				return "기록된 특성 모듈 %d개를 함께 복원합니다." % traits.size()
			if weapon_definition != null and weapon_definition.description != "":
				return weapon_definition.description
			return description
		PlayerAugmentKind.Kind.WEAPON_LEVEL:
			return "기본 성능이 증가합니다."
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
