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


## Background preload of every card in the offer folders, one file at a time,
## so the folder scan in AugmentOfferController._ready finds them cached.
## The menu starts this once world.tscn has loaded (cards and the evolved
## enemy scenes the enemy pool references are not world.tscn dependencies, and
## loading them cold on the main thread held the World entry frame ~190 ms).
## Loads run strictly one after another: parallel threaded requests that share
## dependencies with the scene load produced parse errors.
static var _preload_queue := PackedStringArray()
static var _preload_current := ""
static var _preloaded: Array[Resource] = []


static func begin_background_preload(
	directories: Array[String] = [DEFAULT_PLAYER_DIR, DEFAULT_ENEMY_DIR],
) -> int:
	for directory_path in directories:
		for resource_path in _collect_resource_paths(directory_path):
			if not ResourceLoader.has_cached(resource_path) and not _preload_queue.has(resource_path):
				_preload_queue.append(resource_path)
	_advance_background_preload()
	return _preload_queue.size() + (1 if _preload_current != "" else 0)


## Call every frame while a preload is pending; returns true while work remains.
static func poll_background_preload() -> bool:
	if _preload_current == "":
		return false
	match ResourceLoader.load_threaded_get_status(_preload_current):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return true
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(_preload_current)
			if resource != null:
				_preloaded.append(resource)
		_:
			pass
	_preload_current = ""
	_advance_background_preload()
	return _preload_current != ""


static func is_background_preload_pending() -> bool:
	return _preload_current != "" or not _preload_queue.is_empty()


static func _advance_background_preload() -> void:
	while _preload_current == "" and not _preload_queue.is_empty():
		var resource_path := _preload_queue[0]
		_preload_queue.remove_at(0)
		if ResourceLoader.has_cached(resource_path):
			continue
		if ResourceLoader.load_threaded_request(resource_path) == OK:
			_preload_current = resource_path


static func _collect_resource_paths(directory_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return out
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var resource_path := directory_path.path_join(file_name)
			if directory.current_is_dir():
				out.append_array(_collect_resource_paths(resource_path))
			elif file_name.ends_with(".tres"):
				out.append(resource_path)
		file_name = directory.get_next()
	directory.list_dir_end()
	return out


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
