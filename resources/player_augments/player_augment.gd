class_name PlayerAugment
extends Resource

@export var augment_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var augment_type: PlayerAugmentKind.Kind = PlayerAugmentKind.Kind.STAT_MULTIPLIER
@export var icon: Texture2D
@export var stat_modifiers: Array[PlayerStatModifier] = []
@export var behavior_components: Array[PackedScene] = []
@export var weapon_definition: WeaponDefinition
## UPGRADE_FACILITY 전용. 레벨별 효과값과 최대 레벨은 ShipFacilityDefinition이 정본이라
## 여기서는 대상 시설과 증가량만 갖는다.
@export var facility_id: StringName
@export_range(1, 5, 1) var facility_level_gain := 1
