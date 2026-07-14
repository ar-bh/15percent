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

#region cut variables
var cut_mode: bool = false
var cut_timer_going: bool = false
var cut_time_limit: float = 0.7
var last_reject_reason := ""
#endregion

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
var polygon_edges: Array


func _get_polygon_edges(points: PackedVector2Array) -> Array:
	var edges := []
	for i in points.size():
		var next_i := (i + 1) % points.size()
		edges.append([points[i], points[next_i]])
	return edges

#func _delete_polygon_children() -> void:
	#for child in get_children():
		#if child is CanvasGroup:
			#child.free()

func _apply_outline(group: CanvasGroup) -> void:
	if outline_material == null:
		outline_material = ShaderMaterial.new()
		outline_material.shader = preload("res://game_assets/group_outline.gdshader")
		outline_material.set_shader_parameter("line_color", Color(0.08, 0.08, 0.08, 1.0))
		outline_material.set_shader_parameter("line_thickness", 10)
	outline_material.set_shader_parameter("viewport_scale", get_viewport_rect().size / DESIGN_VIEWPORT)
	group.fit_margin = 16.0
	group.material = outline_material

# gets the points to actually build the polygon
func _get_polygon_points(sides: int, center: Vector2, radius: float, start_angle: float = -PI / 2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var angle_step := TAU / sides

	for side in sides:
		var angle := start_angle + angle_step * side
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	return points

func get_polygon_points() -> PackedVector2Array:
	return polygon_points

func _set_up_polygons_once(sides: int, center: Vector2, radius: float, shape_points: PackedVector2Array) -> void:
	shape_group = CanvasGroup.new()
	shape_polygon = Polygon2D.new()
	collision_polygon = CollisionPolygon2D.new()
	
	shape_polygon.polygon = shape_points
	collision_polygon.polygon = shape_points
	
	shape_polygon.add_child(collision_polygon)
	shape_group.add_child(shape_polygon)
	add_child(shape_group)
	
	_apply_outline(shape_group)
	_arrange_themes()

func update_polygon(sides: int, center: Vector2, radius: float, shape_points: PackedVector2Array) -> void:
	shape_polygon.polygon = shape_points
	collision_polygon.polygon = shape_points

#endregion

#region cut piece
const CUT_PIECE_ANIM_DURATION := 0.4
const CUT_PIECE_DISAPPEAR := false

#endregion

#region THEMES!

var themes_list := {
	"regular": {
		"pointer": preload("res://game_assets/themes/regular_pointer.png"),
		"background": preload("res://game_assets/themes/regular_background.png"),
		"appearance_type": "color",
		"color": Color("#ed7440"),
	},
}
@export var theme: String = "regular"

#endregion

#region pointer variables
const POINTER_SCENE := preload("res://game/pointer.tscn")
@export var pointer_count := 2

var pointer_nodes: Array[CharacterBody2D] = []

#endregion

func _ready() -> void:
	polygon_points = _get_polygon_points(polygon_sides, polygon_center, polygon_radius)
	polygon_edges = _get_polygon_edges(polygon_points)
	_set_up_polygons_once(polygon_sides, polygon_center, polygon_radius, polygon_points)
	update_polygon(polygon_sides, polygon_center, polygon_radius, polygon_points)
	_spawn_pointers()

	#region cutting

	timer_label.visible = debug

	prev_mouse = get_local_mouse_position()
	mouse = prev_mouse
	inside = _is_inside(mouse)
	was_inside = inside

	cut_timer.wait_time = 0.7
	cut_timer.timeout.connect(_on_cut_timer_timeout)
	get_tree().root.size_changed.connect(_on_window_resized)
	#endregion

func _on_window_resized() -> void:
	if shape_group != null and is_instance_valid(shape_group):
		_apply_outline(shape_group)

func _process(_delta: float) -> void:
	#region cutting
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
	#endregion

func _arrange_themes() -> void:
	if shape_polygon == null or not is_instance_valid(shape_polygon):
		return
		
	if not themes_list.has(theme):
		return
		
	var theme_data: Dictionary = themes_list[theme]
	
	if background_texture != null and theme_data.has("background"):
		background_texture.texture = theme_data["background"]
		

	if theme_data.get("appearance_type") == "color":
		shape_polygon.texture = null
		shape_polygon.color = theme_data["color"]
	elif theme_data.has("texture"):
		shape_polygon.texture = theme_data["texture"]


#region pointers
func _spawn_pointers() -> void:
	for i in pointer_count:
		var spawn_pos = _random_point_in_polygon(polygon_points)
		if spawn_pos == null:
			continue
			
		var pointer: CharacterBody2D = POINTER_SCENE.instantiate()
		pointer.position = spawn_pos
		pointer.z_index = 3
		shape_group.add_child(pointer)
		pointer_nodes.append(pointer)

func _remove_pointers_outside(bounds: PackedVector2Array) -> void:
	for pointer in pointer_nodes.duplicate():
		if not Geometry2D.is_point_in_polygon(pointer.position, bounds):
			pointer_nodes.erase(pointer)
			pointer.queue_free()

func _random_point_in_polygon(bounds: PackedVector2Array) -> Variant:
	if bounds.is_empty():
		return null
		
	var min_x := bounds[0].x
	var max_x := bounds[0].x
	var min_y := bounds[0].y
	var max_y := bounds[0].y
	
	for point in bounds:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
		
	for attempt in 100:
		var candidate := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		if Geometry2D.is_point_in_polygon(candidate, bounds):
			return candidate
			
	return null

#endregion


#region cutting gameplay functions
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
			
			if debug:
				_create_line(prev_mouse, mouse)
			
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

	_remove_pointers_outside(polygon_points)
	update_polygon(polygon_sides, polygon_center, polygon_radius, polygon_points)
	
	if polygon1_points == keeper:
		_animate_cut_piece(polygon2_points)
	else:
		_animate_cut_piece(polygon1_points)

func _animate_cut_piece(cut_piece_points: PackedVector2Array) -> void:
	var cut_group := CanvasGroup.new()
	var cut_piece := Polygon2D.new()
	cut_piece.polygon = cut_piece_points

	if themes_list.has(theme) and themes_list[theme].get("appearance_type") == "color":
		cut_piece.color = themes_list[theme]["color"]

	cut_group.add_child(cut_piece)
	
	_apply_outline(cut_group)
	add_child(cut_group)
	

	var cut_piece_tween := create_tween()
	cut_piece_tween.set_ease(Tween.EASE_IN)
	cut_piece_tween.set_trans(Tween.TRANS_QUAD)
	cut_piece_tween.set_parallel(true)

	var screen_size = get_viewport().get_visible_rect().size

	var piece_center := Vector2.ZERO
	for pt in cut_piece_points:
		piece_center += pt
	piece_center /= cut_piece_points.size()

	var dist_left = piece_center.x
	var dist_right = screen_size.x - piece_center.x
	var dist_top = piece_center.y
	var dist_bottom = screen_size.y - piece_center.y

	var closest_dist = min(dist_left, dist_right, dist_top, dist_bottom)

	if closest_dist == dist_left:
		cut_piece_tween.tween_property(cut_group, "position:x", cut_group.position.x - (dist_left + 100.0), CUT_PIECE_ANIM_DURATION)
	elif closest_dist == dist_right:
		cut_piece_tween.tween_property(cut_group, "position:x", cut_group.position.x + (dist_right + 100.0), CUT_PIECE_ANIM_DURATION)
	elif closest_dist == dist_top:
		cut_piece_tween.tween_property(cut_group, "position:y", cut_group.position.y - (dist_top + 100.0), CUT_PIECE_ANIM_DURATION)
	elif closest_dist == dist_bottom:
		cut_piece_tween.tween_property(cut_group, "position:y", cut_group.position.y + (dist_bottom + 100.0), CUT_PIECE_ANIM_DURATION)

	if CUT_PIECE_DISAPPEAR:
		cut_piece_tween.tween_property(cut_group, "modulate:a", 0.0, CUT_PIECE_ANIM_DURATION)

	cut_piece_tween.chain().finished.connect(func() -> void:
		cut_group.queue_free()
	)

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
#endregion
