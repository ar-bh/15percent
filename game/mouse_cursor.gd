extends Node

const CURSOR_TEXTURE := preload("res://game_assets/themes/chainsaw_cursor.png")
const CURSOR_MAX_SIZE := 80

var _chainsaw_texture: ImageTexture
var _hotspot := Vector2.ZERO
var _cut_mode_active := false
var _last_scene: Node


func _ready() -> void:
	_build_chainsaw_texture()
	_last_scene = get_tree().current_scene
	apply_default()


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _last_scene:
		_last_scene = scene
		_cut_mode_active = false
		_apply_current()


func set_cut_mode(active: bool) -> void:
	if active == _cut_mode_active:
		return
	_cut_mode_active = active
	_apply_current()


func apply_default() -> void:
	_cut_mode_active = false
	_apply_current()


func _apply_current() -> void:
	if _chainsaw_texture == null:
		return

	if _cut_mode_active:
		Input.set_custom_mouse_cursor(_chainsaw_texture, Input.CURSOR_ARROW, _hotspot)
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


func _build_chainsaw_texture() -> void:
	var image := CURSOR_TEXTURE.get_image()
	if image.is_empty():
		push_error("MouseCursor: failed to load chainsaw texture image.")
		return
	if image.is_compressed():
		image.decompress()
	image = image.duplicate()
	var size := image.get_size()
	var scale := CURSOR_MAX_SIZE / float(maxi(size.x, size.y))
	var scaled_size := Vector2i(maxi(1, int(size.x * scale)), maxi(1, int(size.y * scale)))

	image.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_NEAREST)
	image.flip_x()

	var tip := _find_blade_tip_hotspot(image)
	_hotspot = tip

	_chainsaw_texture = ImageTexture.create_from_image(image)


func _find_blade_tip_hotspot(image: Image) -> Vector2:
	var size := image.get_size()
	var mid_x := size.x / 2

	for y in range(size.y):
		for x in range(mid_x):
			if image.get_pixel(x, y).a > 0.1:
				return Vector2(x, y)

	return Vector2(0, 0)
