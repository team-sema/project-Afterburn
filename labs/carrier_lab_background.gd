extends CanvasLayer
## Screen-space Lab starfield: camera pullback must never expose its edges.
const TEXTURES = [preload("res://assets/backgrounds/space.png"), preload("res://assets/backgrounds/far_stars.png"), preload("res://assets/backgrounds/close_stars.png")]
const SPEEDS = [2.0,5.0,20.0]
var scroll := PackedFloat32Array([0,0,0])
var tiles: Array[TextureRect] = []
func _ready() -> void:
	layer = -100
	follow_viewport_enabled = false
	for texture in TEXTURES:
		for copy in 2:
			var tile := TextureRect.new()
			tile.texture = texture
			tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tile.stretch_mode = TextureRect.STRETCH_TILE
			tile.size = Vector2(240,360)
			tile.position.y = -360 * copy
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tile)
			tiles.append(tile)
func _process(delta: float) -> void:
	for i in 3:
		scroll[i] = fposmod(scroll[i] + SPEEDS[i]*delta,360)
		tiles[i*2].position.y = scroll[i]
		tiles[i*2+1].position.y = scroll[i]-360
