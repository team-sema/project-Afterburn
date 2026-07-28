extends ParallaxBackground

@onready var space_layer: ParallaxLayer = %SpaceLayer
@onready var far_stars_layer: ParallaxLayer = %FarStarsLayer
@onready var close_stars_layer: ParallaxLayer = %CloseStarsLayer
@onready var space: TextureRect = $SpaceLayer/Space
@onready var far_stars: TextureRect = $FarStarsLayer/FarStars
@onready var close_stars: TextureRect = $CloseStarsLayer/CloseStars


func _ready() -> void:
	_resize_to_viewport()
	get_viewport().size_changed.connect(_resize_to_viewport)


func _process(delta: float) -> void:
	space_layer.motion_offset.y += 2 * delta
	far_stars_layer.motion_offset.y += 5 * delta
	close_stars_layer.motion_offset.y += 20 * delta


func _resize_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	for texture_rect in [space, far_stars, close_stars]:
		texture_rect.position = Vector2.ZERO
		texture_rect.size = viewport_size
	for layer in [space_layer, far_stars_layer, close_stars_layer]:
		layer.motion_mirroring.y = viewport_size.y
