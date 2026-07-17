extends Node2D

@onready var background: Control = $BackgroundLayer/Background
@onready var background_texture1: TextureRect = $BackgroundLayer/Background/Parallax2D/TextureRect
@onready var background_parallax: Parallax2D = $BackgroundLayer/Background/Parallax2D
@onready var camera: Camera2D = $Camera2D
@onready var gameplay_shapes: Node2D = $GameplayShapes

const BACKGROUND_TEXTURE_SIZE := Vector2(2165, 1080)
const GAMEPLAY_Y_OFFSET := 64.0

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_window_resized)
	tree_exiting.connect(_on_tree_exiting)
	_on_window_resized()
	camera.make_current()


func _on_tree_exiting() -> void:
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO


func _on_window_resized() -> void:
	var viewport_size := get_viewport_rect().size
	var screen_center := viewport_size / 2.0

	camera.position = screen_center
	gameplay_shapes.position = screen_center + Vector2(0, GAMEPLAY_Y_OFFSET)

	if gameplay_shapes.has_method("on_viewport_resized"):
		gameplay_shapes.on_viewport_resized()

	background.size = viewport_size

	var scale_factor := maxf(
		viewport_size.x / BACKGROUND_TEXTURE_SIZE.x,
		viewport_size.y / BACKGROUND_TEXTURE_SIZE.y
	)

	background_parallax.scale = Vector2(scale_factor, scale_factor)
	background_texture1.size = BACKGROUND_TEXTURE_SIZE
	background_parallax.repeat_size = BACKGROUND_TEXTURE_SIZE


func screen_shake(intensity: float = 10.0, duration: float = 0.18) -> void:
	if not is_instance_valid(camera):
		return

	var tween := create_tween()
	var shakes := 5
	var step := duration / float(shakes)
	for i in shakes - 1:
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(camera, "offset", offset, step)
	tween.tween_property(camera, "offset", Vector2.ZERO, step)
