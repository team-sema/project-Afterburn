class_name EnemyAugment
extends Resource

@export var augment_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
## 0 allows unlimited stacks. 1 makes the augment one-time.
@export_range(0, 100, 1) var max_stacks := 0
@export var stat_modifiers: Array[EnemyStatModifier] = []
@export var behavior_components: Array[PackedScene] = []
## Optional EncounterPreset.encounter_id affected by this augment.
@export var target_spawn_id: StringName
@export_range(0, 100, 1) var additional_spawn_count := 0
