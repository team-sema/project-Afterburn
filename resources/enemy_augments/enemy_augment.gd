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
## Encounter spawned alongside every later elite gate (not bosses).
@export var elite_escort_preset: EncounterPreset
## Player rerolls removed from the run budget when this augment is chosen.
@export_range(0, 20, 1) var player_reroll_penalty := 0
## False = lab/debug only; folder scan skips it for runtime enemy offers.
@export var include_in_offer_pool := true
@export_group("Evolution")
## Every later spawn of this exact enemy scene becomes evolution_to instead.
## The card is offered only after evolution_from has spawned in the run.
@export var evolution_from: PackedScene
@export var evolution_to: PackedScene


func is_evolution() -> bool:
	return evolution_from != null and evolution_to != null
