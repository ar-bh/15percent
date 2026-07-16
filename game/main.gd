extends Node2D

@onready var background: Control = $Background
@onready var background_texture1: TextureRect = $Background/Parallax2D/TextureRect
@onready var background_parallax: Parallax2D = $Background/Parallax2D

const BACKGROUND_TEXTURE_SIZE := Vector2(2165, 1080)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().root.size_changed.connect(_on_window_resized)
	_on_window_resized()

func _on_window_resized() -> void:
	var viewport_size := get_viewport_rect().size
	
	background.size = viewport_size
	background.position = Vector2.ZERO
	
	var scale_factor := maxf(
		viewport_size.x / BACKGROUND_TEXTURE_SIZE.x,
		viewport_size.y / BACKGROUND_TEXTURE_SIZE.y
	)

	background_parallax.scale = Vector2(scale_factor, scale_factor)
	
	background_texture1.size = BACKGROUND_TEXTURE_SIZE
	background_parallax.repeat_size = BACKGROUND_TEXTURE_SIZE
