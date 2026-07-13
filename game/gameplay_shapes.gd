extends Node2D

var debug := true

#region node variables
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
var peak_cut_speed: float = 0.0
var last_delta: float = 0.016
#endregion

var cut_mode: bool = false
var cut_timer_going: bool = false
var cut_time_limit: float = 0.7
var last_reject_reason := ""

#region create and define polygon shape and mouse variables
@export var polygon_sides: int = 4
@export var polygon_radius: float = 400.0
@onready var polygon_center: Vector2 = Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2)

var shape_polygon: Polygon2D
var collision_polygon: CollisionPolygon2D
@onready var polygon_points: PackedVector2Array = _get_polygon_points(polygon_sides, polygon_center, polygon_radius)
@onready var polygon_edges: Array = _get_polygon_edges(polygon_points)


func _get_polygon_edges(points: PackedVector2Array) -> Array:
	var edges := []
	for i in points.size():
		var next_i := (i + 1) % points.size()
		edges.append([points[i], points[next_i]])
	return edges

func _delete_polygon_children() -> void:
	for child in get_children():
		if child is Polygon2D:
			child.queue_free()

func _get_polygon_points(sides: int, center: Vector2, radius: float, start_angle: float = -PI / 2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var angle_step := TAU / sides # TAU = 2 * PI = full circle
	
	for side in sides:
		var angle := start_angle + angle_step * side
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	
	return points
	
func draw_new_polygon(sides: int, center: Vector2, radius: float, shape_points: PackedVector2Array, start_angle: float = -PI / 2 ) -> void:
	shape_polygon = Polygon2D.new()
	collision_polygon = CollisionPolygon2D.new()
	
	shape_polygon.polygon = shape_points
	collision_polygon.polygon = shape_points
	
	add_child(shape_polygon)
	shape_polygon.add_child(collision_polygon)

#endregion


func _ready() -> void:
	#region onready make polygon shape and collision
	_delete_polygon_children()
	draw_new_polygon(polygon_sides, polygon_center, polygon_radius, polygon_points)
	#endregion
	
	
	
	timer_label.visible = debug
	
	prev_mouse = get_local_mouse_position()
	mouse = prev_mouse
	inside = _is_inside(mouse)
	was_inside = inside
	
	cut_timer.wait_time = 0.7
	cut_timer.timeout.connect(_on_cut_timer_timeout)

func _process(_delta: float) -> void:
	last_delta = max(_delta, 0.0001)
	cut_mode = Input.is_action_pressed("cut_mode") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	# read velocity before cut checks so exit frame uses current speed
	vector_mouse_velocity = Input.get_last_mouse_velocity()
	scalar_mouse_velocity = vector_mouse_velocity.length()
	var frame_speed := prev_mouse.distance_to(get_local_mouse_position()) / last_delta

	mouse = get_local_mouse_position()
	inside = _is_inside(mouse)

	if inside and cut_timer_going:
		peak_cut_speed = max(peak_cut_speed, scalar_mouse_velocity, frame_speed)

	_handle_mouse_enter_exit(frame_speed)
	_update_timer_label()

	was_inside = inside
	prev_mouse = mouse


func _is_inside(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon_points)
	
func _handle_mouse_enter_exit(frame_speed: float) -> void:
	# just entered:
	if inside and not was_inside:
		if not cut_mode:
			return
		entrance_point = prev_mouse
		peak_cut_speed = max(scalar_mouse_velocity, frame_speed)
		cut_timer.stop()
		cut_timer.start()
		cut_timer_going = true
		return

	# just exited — still process even if click released this same frame
	elif not inside and was_inside:
		peak_cut_speed = max(peak_cut_speed, scalar_mouse_velocity, frame_speed)
		var reject_reason := _check_valid_line(entrance_point, mouse, polygon_edges, true)
		last_reject_reason = reject_reason if reject_reason != "" else "line drawn"
		
		# line is valid
		if reject_reason == "":
			#_create_line(entrance_point, mouse)
			_perform_cut(entrance_point, mouse)
			
		
		cut_timer.stop()
		cut_timer_going = false
		
		
		return

	# fast swipe: crossed through in one frame without registering inside
	elif not inside and not was_inside and cut_mode:
		peak_cut_speed = max(scalar_mouse_velocity, frame_speed)
		var reject_reason := _check_valid_line(prev_mouse, mouse, polygon_edges, false)
		last_reject_reason = reject_reason if reject_reason != "" else "line drawn (fast)"
		if reject_reason == "":
			_perform_cut(prev_mouse, mouse)
		return

	# release click mid-cut (not on exit frame)
	if not cut_mode:
		cut_timer.stop()
		cut_timer_going = false

func _perform_cut(from: Vector2, to: Vector2):
	var hits := []
	
	for i in polygon_edges.size():
		var edge = polygon_edges[i]
		var hit = Geometry2D.segment_intersects_segment(from, to, edge[0], edge[1])
		if hit != null:
			hits.append({"point": hit, "edge_index": i,})
		
	if hits.size() != 2:
		return

	hits.sort_custom(func(a, b):
		return from.distance_squared_to(a.point) < from.distance_squared_to(b.point)
	)

	var cut_a: Vector2 = hits[0].point
	var cut_b: Vector2 = hits[1].point
	var edge_a: int = hits[0].edge_index
	var edge_b: int = hits[1].edge_index
	
	if edge_a == edge_b:
		return
		
	
	var polygon1_points := _build_piece(cut_a, edge_a, cut_b, edge_b, true)
	var polygon2_points := _build_piece(cut_a, edge_a, cut_b, edge_b, false)
		
	var area1 := _polygon_area(polygon1_points)
	var area2 := _polygon_area(polygon2_points)
	var keeper := polygon1_points if area1 >= area2 else polygon2_points
	
	polygon_points = keeper
	polygon_edges = _get_polygon_edges(polygon_points)
	
	_delete_polygon_children()
	draw_new_polygon(polygon_sides, polygon_center, polygon_radius, polygon_points)
		
func _build_piece(start_cut: Vector2, start_edge: int, end_cut: Vector2, end_edge: int, forward: bool) -> PackedVector2Array:
	var piece := PackedVector2Array()
	var n := polygon_points.size()
	
	piece.append(start_cut)
	
	if forward:
		var idx := (start_edge + 1) % n
		while idx != (end_edge + 1) % n:
			piece.append(polygon_points[idx])
			idx = (idx + 1) % n
	else:
		var idx := start_edge
		while idx != end_edge:
			piece.append(polygon_points[idx])
			idx = (idx - 1 + n) % n
			
	piece.append(end_cut)
	return piece

func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		var j := (i + 1) % points.size()
		area += points[i].x * points[j].y - points[j].x * points[i].y
	return abs(area) * 0.5			
			
func _check_valid_line(from: Vector2, to: Vector2, edges: Array, require_timer: bool = true) -> String:
	if require_timer and cut_timer.is_stopped():
		return "timer expired"

	var intersected_edges := []
	for edge in edges:
		if Geometry2D.segment_intersects_segment(edge[0], edge[1], from, to):
			intersected_edges.append(edge)
	if intersected_edges.size() != 2:
		return "no edge cross"

	if peak_cut_speed < minimum_cut_speed:
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
		+ "speed: %.0f (peak %.0f, min %.0f)\n" % [scalar_mouse_velocity, peak_cut_speed, minimum_cut_speed]
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
