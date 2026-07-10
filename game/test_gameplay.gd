extends Node2D

var debug := false

#region node variables
@onready var hitbox: Area2D = %HitBox
@onready var collision_shape: CollisionShape2D = %HitBox/CollisionShape2D
@onready var cut_timer: Timer = %CutTimer
@onready var timer_label: Label = %TimerLabel
#endregion

#region mouse variables
var prev_mouse := Vector2.ZERO
var was_inside := false
var entrance_point := Vector2.ZERO
var mouse := Vector2.ZERO
var inside := false
var vector_mouse_velocity := Vector2.ZERO
var scalar_mouse_velocity: float = 0.0

var minimum_cut_speed: float = 500.0
#endregion

var cut_mode: bool = false
var cut_timer_going: bool = false
var cut_time_limit: float = 0.7
var last_reject_reason := ""

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
	timer_label.visible = debug
	
	prev_mouse = get_local_mouse_position()
	mouse = prev_mouse
	inside = _is_inside(mouse)
	was_inside = inside
	
	cut_timer.wait_time = 0.7
	cut_timer.timeout.connect(_on_cut_timer_timeout)

func _process(_delta: float) -> void:
	cut_mode = Input.is_action_pressed("cut_mode") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	# read velocity before cut checks so exit frame uses current speed
	vector_mouse_velocity = Input.get_last_mouse_velocity()
	scalar_mouse_velocity = vector_mouse_velocity.length()

	mouse = get_local_mouse_position()
	inside = _is_inside(mouse)

	_handle_mouse_enter_exit()
	_update_timer_label()

	was_inside = inside
	prev_mouse = mouse


func _is_inside(point: Vector2) -> bool:
	# convert local mouse → global for the rect check
	return rect.has_point(to_global(point))
	
func _handle_mouse_enter_exit() -> void:
	# just entered:
	if inside and not was_inside:
		if not cut_mode:
			return
		entrance_point = prev_mouse
		cut_timer.stop()
		cut_timer.start()
		cut_timer_going = true
		return

	# just exited — still process even if click released this same frame
	elif not inside and was_inside:
		var reject_reason := _check_valid_line(entrance_point, mouse, rect_edges)
		last_reject_reason = reject_reason if reject_reason != "" else "line drawn"
		if reject_reason == "":
			_create_line(entrance_point, mouse)
		cut_timer.stop()
		cut_timer_going = false
		return

	# release click mid-cut (not on exit frame)
	if not cut_mode:
		cut_timer.stop()
		cut_timer_going = false

func _check_valid_line(from: Vector2, to: Vector2, edges: Array[Array]) -> String:
	if cut_timer.is_stopped():
		return "timer expired"

	var intersected_edges := []
	for edge in edges:
		if Geometry2D.segment_intersects_segment(edge[0], edge[1], from, to):
			intersected_edges.append(edge)
	if intersected_edges.is_empty():
		return "no edge cross"

	if scalar_mouse_velocity < minimum_cut_speed:
		return "too slow"

	return ""
			
func _on_cut_timer_timeout() -> void:
	cut_timer_going = false


func _update_timer_label() -> void:
	var time_left_text := "stopped"
	if not cut_timer.is_stopped():
		time_left_text = "%.2fs" % cut_timer.time_left

	timer_label.text = (
		"timer: %s\n" % time_left_text
		+ "cut_mode: %s\n" % str(cut_mode)
		+ "inside: %s\n" % str(inside)
		+ "speed: %.0f (min %.0f)\n" % [scalar_mouse_velocity, minimum_cut_speed]
		+ "last: %s" % last_reject_reason
	)

func _create_line(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 10.0
	line.default_color = Color.BLACK
	line.z_index = 5
	line.add_point(from)
	line.add_point(to)
	add_child(line)
