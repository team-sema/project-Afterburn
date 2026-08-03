class_name WeaponLoadoutHud
extends VBoxContainer

## Equipped weapon bay clusters + detail strip. No weapon records.

@export var ship: Node2D

@onready var bay_row: HBoxContainer = %BayRow
@onready var detail_label: Label = %WeaponDetail

var _bay_clusters: Array[WeaponCoreCluster] = []


func _ready() -> void:
	if ship == null:
		return
	var loadout := _get_loadout()
	if loadout == null:
		return
	loadout.loadout_changed.connect(refresh)
	call_deferred("refresh")


func refresh() -> void:
	var loadout := _get_loadout()
	if loadout == null:
		_clear_container(bay_row)
		_bay_clusters.clear()
		if detail_label != null:
			detail_label.text = "무기 상태 없음"
		return
	_rebuild_bays(loadout)


func _rebuild_bays(loadout: PlayerWeaponLoadout) -> void:
	_clear_container(bay_row)
	_bay_clusters.clear()
	var count := loadout.get_max_equipped_weapon_count()
	for index in count:
		var cluster := _make_cluster()
		bay_row.add_child(cluster)
		_bay_clusters.append(cluster)
		var bay := loadout.get_bay(index)
		if bay == null or bay.is_empty():
			cluster.bind_weapon(&"", null, 1, {}, false, false)
			continue
		cluster.bind_weapon(
			bay.equipped_weapon_id,
			loadout.get_weapon_icon(bay.equipped_weapon_id),
			loadout.get_weapon_level(bay.equipped_weapon_id),
			loadout.get_weapon_traits(bay.equipped_weapon_id),
			false,
			true,
		)


func _make_cluster() -> WeaponCoreCluster:
	var cluster := WeaponCoreCluster.new()
	cluster.core_size = Vector2(34, 34)
	cluster.trait_size = Vector2(14, 14)
	cluster.orbit_radius = 18.0
	cluster.core_selected.connect(_on_core_selected)
	cluster.trait_selected.connect(_on_trait_selected)
	return cluster


func _on_core_selected(weapon_id: StringName, _is_record: bool) -> void:
	var loadout := _get_loadout()
	if loadout == null or detail_label == null:
		return
	if weapon_id == &"":
		detail_label.text = "빈 장착 베이"
		return
	var definition := loadout.get_weapon_definition(weapon_id)
	var weapon_name := loadout.get_weapon_display_name(weapon_id)
	var level := loadout.get_weapon_level(weapon_id)
	var traits := loadout.get_weapon_traits(weapon_id)
	var attack := ""
	if definition != null and definition.attack_summary != "":
		attack = definition.attack_summary
	elif definition != null:
		attack = definition.description
	detail_label.text = "%s · 장착 중\nLv.%d\n%s\n%s" % [
		weapon_name,
		level,
		attack,
		_format_traits(traits),
	]


func _on_trait_selected(weapon_id: StringName, trait_id: StringName, _is_record: bool) -> void:
	var loadout := _get_loadout()
	if loadout == null or detail_label == null:
		return
	var rank := int(loadout.get_weapon_traits(weapon_id).get(trait_id, 0))
	detail_label.text = "특성 · %s\n단계 %d\n전투 효과는 아직 연결되지 않음" % [
		String(trait_id),
		rank,
	]


func _format_traits(trait_ranks: Dictionary) -> String:
	if trait_ranks.is_empty():
		return "특성 없음"
	var parts: PackedStringArray = []
	for key in trait_ranks.keys():
		parts.append("%s %d" % [String(key), int(trait_ranks[key])])
	parts.sort()
	return "특성: " + ", ".join(parts)


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _get_loadout() -> PlayerWeaponLoadout:
	if ship != null and ship.has_method("get_weapon_loadout"):
		return ship.call("get_weapon_loadout") as PlayerWeaponLoadout
	return null
