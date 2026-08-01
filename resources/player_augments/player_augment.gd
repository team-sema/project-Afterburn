class_name PlayerAugment
extends Resource

@export var augment_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var augment_type: PlayerAugmentKind.Kind = PlayerAugmentKind.Kind.STAT_MULTIPLIER
@export var icon: Texture2D
@export var stat_modifiers: Array[PlayerStatModifier] = []
@export var behavior_components: Array[PackedScene] = []
## 모든 플레이어 증강은 이 함선 부위의 모듈 슬롯 하나를 차지한다.
@export var facility_id: StringName
