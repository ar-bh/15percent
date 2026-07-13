extends Node2D

var debug := false

#region node variables
@onready var cut_timer: Timer = %CutTimer
@onready var timer_label: Label = %TimerLabel

@onready var background_texture: TextureRect = get_node_or_null("../Background/Parallax2D/TextureRect")
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

var shape_group: CanvasGroup
var shape_polygon: Polygon2D
var collision_polygon: CollisionPolygon2D
var outline_material: ShaderMaterial
const DESIGN_VIEWPORT := Vector2(1920, 1080)
var polygon_points: PackedVector2Array
var polygon_edges: Array = []


func _get_polygon_edges(points: PackedVector2Array) -> Array:
	var edges := []
	for i in points.size():
		var next_i := (i + 1) % points.size()
		edges.append([points[i], points[next_i]])
	return edges

func _delete_polygon_children() -> void:
	for child in get_children():
		if child is CanvasGroup:
			child.queue_free()

func _get_polygon_points(sides: int, center: Vector2, radius: float, start_angle: float = -PI / 2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var angle_step := TAU / sides

	for side in sides:
		var angle := start_angle + angle_step * side
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	return points

func draw_new_polygon(sides: int, center: Vector2, radius: float, shape_points: PackedVector2Array, start_angle: float = -PI / 2) -> void:
	shape_group = CanvasGroup.new()
	shape_polygon = Polygon2D.new()
	collision_polygon = CollisionPolygon2D.new()
	shape_polygon.polygon = shape_points
	collision_polygon.polygon = shape_points
	shape_polygon.add_child(collision_polygon)
	shape_group.add_child(shape_polygon)
	add_child(shape_group)

#endregion

#region THEMES!

var themes_list := {
	"regular": {
		"pointer": preload("res://game_assets/themes/regular_pointer.png"),
		"background": preload("res://game_assets/themes/regular_background.png"),
		"appearance_type": "color",
		"color": Color8(237, 116, 64),
	},
}
@export var theme: String = "regular"

#endregion

func _ready() -> void:
	polygon_points = _get_polygon_points(polygon_sides, polygon_center, polygon_radius)
	polygon_edges = _get_polygon_edges(polygon_points)

	_delete_polygon_children()
	draw_new_polygon(polygon_sides, polygon_center, polygon_radius, polygon_points)

	_arrange_themes()
	_apply_shader()
	get_tree().root.size_changed.connect(_on_window_resized)

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

func _arrange_themes() -> void:
	if shape_polygon == null or not is_instance_valid(shape_polygon):
		return

	if not themes_list.has(theme):
		return

	var theme_data: Dictionary = themes_list[theme]

	if background_texture != null and theme_data.has("background"):
		background_texture.texture = theme_data["background"]

	if theme_data.get("appearance_type") == "color":
		shape_polygon.color = theme_data["color"]
	elif theme_data.has("texture"):
		shape_polygon.texture = theme_data["texture"]

func _apply_shader() -> void:
	if shape_group == null or not is_instance_valid(shape_group):
		return
	if outline_material == null:
		outline_material = ShaderMaterial.new()
		outline_material.shader = preload("res://game_assets/group_outline.gdshader")
		outline_material.set_shader_parameter("line_color", Color(0.08, 0.08, 0.08, 1.0))
		outline_material.set_shader_parameter("line_thickness", 5)
	_update_outline_scale()
	shape_group.material = outline_material

func _update_outline_scale() -> void:
	if outline_material == null:
		return
	outline_material.set_shader_parameter("viewport_scale", get_viewport_rect().size / DESIGN_VIEWPORT)

func _on_window_resized() -> void:
	_update_outline_scale()

func _is_inside(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon_points)

func _handle_mouse_enter_exit(frame_speed: float) -> void:
	if inside and not was_inside:
		if not cut_mode:
			return
		entrance_point = prev_mouse
		peak_cut_speed = max(scalar_mouse_velocity, frame_speed)
		cut_timer.stop()
		cut_timer.start()
		cut_timer_going = true
		return

	elif not inside and was_inside:
		peak_cut_speed = max(peak_cut_speed, scalar_mouse_velocity, frame_speed)
		var reject_reason := _check_valid_line(entrance_point, mouse, polygon_edges, true)
		last_reject_reason = reject_reason if reject_reason != "" else "line drawn"

		if reject_reason == "":
			_perform_cut(entrance_point, mouse)

		cut_timer.stop()
		cut_timer_going = false
		return

	elif not inside and not was_inside and cut_mode:
		peak_cut_speed = max(scalar_mouse_velocity, frame_speed)
		var reject_reason := _check_valid_line(prev_mouse, mouse, polygon_edges, false)
		last_reject_reason = reject_reason if reject_reason != "" else "line drawn (fast)"
		if reject_reason == "":
			_perform_cut(prev_mouse, mouse)
		return

	if not cut_mode:
		cut_timer.stop()
		cut_timer_going = false

func _perform_cut(from: Vector2, to: Vector2) -> void:
	var hits := []

	for i in polygon_edges.size():
		var edge = polygon_edges[i]
		var hit = Geometry2D.segment_intersects_segment(from, to, edge[0], edge[1])
		if hit != null:
			hits.append({"point": hit, "edge_index": i})

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
	_arrange_themes()
	_apply_shader()

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
