class_name AugmentPoolLoader
extends RefCounted

## Shared folder scan for offer pools and labs.
## Player cards with offer_weight <= 0 are skipped.
## Enemy cards with include_in_offer_pool == false are skipped.

const DEFAULT_PLAYER_DIR := "res://resources/player_augments"
const DEFAULT_ENEMY_DIR := "res://resources/enemy_augments"

const OFFER_PLAYER_KINDS: Array[PlayerAugmentKind.Kind] = [
	PlayerAugmentKind.Kind.FACILITY_EFFECT,
	PlayerAugmentKind.Kind.WEAPON_ACQUIRE,
	PlayerAugmentKind.Kind.WEAPON_TRAIT,
	PlayerAugmentKind.Kind.SHIP_RULE,
]


static func load_player_augments(
	directory_path: String = DEFAULT_PLAYER_DIR,
	allowed_kinds: Array = OFFER_PLAYER_KINDS,
	require_positive_offer_weight := true,
) -> Array[PlayerAugment]:
	var out: Array[PlayerAugment] = []
	for resource in _collect_resources(directory_path):
		if resource is PlayerAugment:
			var augment := resource as PlayerAugment
			if not allowed_kinds.is_empty() and not allowed_kinds.has(augment.augment_type):
				continue
			if require_positive_offer_weight and augment.offer_weight <= 0.0:
				continue
			out.append(augment)
	out.sort_custom(
		func(a: PlayerAugment, b: PlayerAugment) -> bool:
			if a.augment_type != b.augment_type:
				return a.augment_type < b.augment_type
			return String(a.augment_id) < String(b.augment_id)
	)
	return out


static func load_enemy_augments(
	directory_path: String = DEFAULT_ENEMY_DIR,
	offer_pool_only := true,
) -> Array[EnemyAugment]:
	var out: Array[EnemyAugment] = []
	for resource in _collect_resources(directory_path):
		if resource is EnemyAugment:
			var augment := resource as EnemyAugment
			if offer_pool_only and not augment.include_in_offer_pool:
				continue
			out.append(augment)
	out.sort_custom(
		func(a: EnemyAugment, b: EnemyAugment) -> bool:
			return String(a.augment_id) < String(b.augment_id)
	)
	return out


static func load_player_offer_pool(
	directory_path: String = DEFAULT_PLAYER_DIR,
) -> Array[PlayerAugment]:
	return load_player_augments(directory_path, OFFER_PLAYER_KINDS, true)


static func load_enemy_offer_pool(
	directory_path: String = DEFAULT_ENEMY_DIR,
) -> Array[EnemyAugment]:
	return load_enemy_augments(directory_path, true)


static func _collect_resources(directory_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_error("AugmentPoolLoader: cannot open '%s'." % directory_path)
		return out
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var resource_path := directory_path.path_join(file_name)
			if directory.current_is_dir():
				out.append_array(_collect_resources(resource_path))
			elif file_name.ends_with(".tres"):
				var resource := load(resource_path)
				if resource is Resource:
					out.append(resource as Resource)
		file_name = directory.get_next()
	directory.list_dir_end()
	return out
