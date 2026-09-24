extends Node2D
## Schedule the shared enemy explosion; visual style belongs to that scene.
const FLASH = preload("res://effects/explosion_effect.tscn")
var radius := 21.0
var secondary := false
var age := 0.0
var bursts: Array[Dictionary] = []
var next_burst := 0

static func spawn(parent: Node2D, origin: Vector2, blast_radius: float, internal_blast := false) -> Node2D:
	var effect: Node2D = load("res://labs/carrier_destruction_effect.gd").new()
	effect.radius = blast_radius
	effect.secondary = internal_blast
	effect.position = parent.to_local(origin)
	parent.add_child(effect)
	return effect

func _ready() -> void:
	add_to_group("carrier_destruction_effects")
	z_index = 6
	if radius >= 100:
		# Spread the familiar explosion across the hull instead of inventing a new core.
		bursts = [
			{"time": 0.0, "offset": Vector2.ZERO, "radius": radius*0.5},
			{"time": 0.14, "offset": Vector2(-radius*0.38,-radius*0.2), "radius": radius*0.4},
			{"time": 0.28, "offset": Vector2(radius*0.38,radius*0.1), "radius": radius*0.45},
			{"time": 0.42, "offset": Vector2(-radius*0.1,radius*0.42), "radius": radius*0.4},
		]
	else:
		bursts.append({"time": 0.0, "offset": Vector2.ZERO, "radius": radius})
		if secondary:
			bursts.append({"time": 0.22, "offset": Vector2(radius*0.2,-radius*0.12), "radius": radius*0.7})
	_emit_due_bursts()

func _emit_due_bursts() -> void:
	while next_burst < bursts.size() and age >= float(bursts[next_burst]["time"]):
		var burst := bursts[next_burst]
		_flash(burst["offset"],burst["radius"],next_burst == 0)
		next_burst += 1

func _flash(offset: Vector2, blast_radius: float, audible: bool) -> void:
	var flash := FLASH.instantiate()
	flash.position = offset
	flash.set_effect_radius(blast_radius)
	# Preserve the shared scene's color, particles, flash envelope and animation speed.
	var audio: AudioStreamPlayer = flash.get_node("VariablePitchAudioStreamPlayer")
	audio.auto_play_with_variance = audible
	audio.volume_db = -12.0 if blast_radius < 30 else -8.0
	audio.pitch_min = clampf(1.35 - blast_radius * 0.006,0.45,1.25)
	audio.pitch_max = audio.pitch_min + 0.12
	add_child(flash)

func _process(delta: float) -> void:
	age += delta
	_emit_due_bursts()
	# Each shared explosion frees itself when its own animation completes.
	if next_burst == bursts.size() and get_child_count() == 0:
		queue_free()
