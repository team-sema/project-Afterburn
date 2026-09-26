class_name WeaponTraitDefinition
extends Resource

## `{key}` inserts the rank's param value; `{key%}` inserts it ×100.
const PLACEHOLDER_PATTERN := "\\{([A-Za-z0-9_]+)(%?)\\}"

@export var trait_id: StringName
@export var display_name: String = ""
## Template filled per rank by format_description(); numbers live in params only.
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var target_weapon_id: StringName
## Silver: small stackable stat (Lv.V) · Gold: behaviour change (Lv.III) · Prismatic: rule change (Lv.I).
@export var tier: PlayerAugment.Tier = PlayerAugment.Tier.GOLD
@export_range(1, 5, 1) var max_rank := 3
## Lv.I combat tuning values read by the owning WeaponSystem via get_trait_param().
@export var params: Dictionary = {}
## Lv.II, Lv.III ... overrides in order. Each entry only needs changed keys.
@export var rank_overrides: Array[Dictionary] = []

static var _placeholder_regex: RegEx


func get_params_for_rank(rank: int) -> Dictionary:
	var resolved := params.duplicate(true)
	var override_count := mini(maxi(rank - 1, 0), rank_overrides.size())
	for index in override_count:
		resolved.merge(rank_overrides[index], true)
	return resolved


func get_param_for_rank(rank: int, key: StringName, default_value: Variant = null) -> Variant:
	var resolved := get_params_for_rank(clampi(rank, 1, max_rank))
	if resolved.has(key):
		return resolved[key]
	var string_key := String(key)
	if resolved.has(string_key):
		return resolved[string_key]
	return default_value


## Fills the description template with `rank` values. With previous_rank > 0,
## values that change between the two ranks render as `old→new`.
func format_description(rank: int, previous_rank: int = 0) -> String:
	var current := get_params_for_rank(clampi(rank, 1, max_rank))
	var previous := {}
	if previous_rank > 0:
		previous = get_params_for_rank(clampi(previous_rank, 1, max_rank))
	var text := description
	var matches := _get_placeholder_regex().search_all(text)
	for index in range(matches.size() - 1, -1, -1):
		var found: RegExMatch = matches[index]
		var key := found.get_string(1)
		if not current.has(key):
			continue
		var percent := found.get_string(2) == "%"
		var value := _format_value(current[key], percent)
		if previous.has(key) and not _same_value(previous[key], current[key]):
			value = "%s→%s" % [_format_value(previous[key], percent), value]
		text = text.substr(0, found.get_start()) + value + text.substr(found.get_end())
	return text


static func _get_placeholder_regex() -> RegEx:
	if _placeholder_regex == null:
		_placeholder_regex = RegEx.create_from_string(PLACEHOLDER_PATTERN)
	return _placeholder_regex


static func _format_value(value: Variant, percent: bool) -> String:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return str(value)
	var number := float(value) * (100.0 if percent else 1.0)
	if is_equal_approx(number, roundf(number)):
		return str(roundi(number))
	return String.num(number, 2)


static func _same_value(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if numeric.has(typeof(a)) and numeric.has(typeof(b)):
		return is_equal_approx(float(a), float(b))
	return a == b
