extends Node2D

#region node variables
@onready var hitbox: Area2D = %HitBox
@onready var collision_shape: CollisionShape2D = %HitBox/CollisionShape2D
#endregion

#region mouse variables
var prev_mouse := Vector2.ZERO
var was_inside := false
var entrance_point := Vector2.ZERO
var mouse := Vector2.ZERO
var inside := false
var vector_mouse_velocity := Vector2.ZERO
var scalar_mouse_velocity: float = 0.0

var minimum_cut_speed: float = 1000.0
#endregion

var cut_mode: bool = false

#region define rect shape and mouse variables
@onready var rect: Rect2 = _get_rect_local()
@onready var rect_edges: Array = _get_rect_edges(rect)
func _get_rect_local() -> Rect2:
	var shape := collision_shape.shape as RectangleShape2D
	var center := to_local(collision_shape.global_position)
	return Rect2(center - shape.size * 0.5, shape.size)
func _get_rect_edges(rect: Rect2) -> Array[Array]:
	return [
		[rect.position, Vector2(rect.end.x, rect.position.y)], # top (left -> right)
		[Vector2(rect.end.x, rect.position.y), rect.end], # right (top -> bottom)
		[rect.end, Vector2(rect.position.x, rect.end.y)], # bottom (right -> left)
		[Vector2(rect.position.x, rect.end.y), rect.position], # left: bottom -> top
	]
#endregion

func _ready() -> void:
	prev_mouse = get_local_mouse_position()
	mouse = prev_mouse
	inside = _is_inside(mouse)
	was_inside = inside
	
	

func _process(_delta: float) -> void:
	cut_mode = Input.is_action_pressed("cut_mode") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	mouse = get_local_mouse_position()
	inside = _is_inside(mouse)

	_handle_mouse_enter_exit()

	was_inside = inside
	prev_mouse = mouse
	vector_mouse_velocity = Input.get_last_mouse_velocity()
	scalar_mouse_velocity = vector_mouse_velocity.length()


func _is_inside(point: Vector2) -> bool:
	# convert local mouse → global for the rect check
	return rect.has_point(to_global(point))
	
func _handle_mouse_enter_exit() -> void:
	if not cut_mode:
		return
	# just entered:
	if inside and not was_inside:
		entrance_point = prev_mouse
		
	# just exited:
	elif not inside and was_inside:
		if _check_valid_line(entrance_point, mouse, rect_edges):
			_create_line(entrance_point, mouse)

func _check_valid_line(from: Vector2, to: Vector2, edges: Array[Array]) -> bool:
	# find the two edges that it intersects
	var intersected_edges := []
	for edge in edges:
		if Geometry2D.segment_intersects_segment(edge[0], edge[1], from, to):
			intersected_edges.append(edge)
	if len(intersected_edges)==0:
		return false
		
	if scalar_mouse_velocity < minimum_cut_speed:
		return false
		
	return true
			

func _create_line(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 10.0
	line.default_color = Color.BLACK
	line.z_index = 5
	line.add_point(from)
	line.add_point(to)
	add_child(line)
