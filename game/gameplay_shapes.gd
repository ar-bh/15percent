extends Node2D

var debug := false

#region node variables
@onready var cut_timer: Timer = %CutTimer
@onready var timer_label: Label = %TimerLabel

@onready var background_texture: TextureRect = get_node_or_null("../BackgroundLayer/Background/Parallax2D/TextureRect")
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
@export var min_polygon_sides: int = 4
@export var max_polygon_sides: int = 8
@export var polygon_radius: float = 400.0
var polygon_center := Vector2.ZERO
var full_area: float
var current_area: float
var current_area_percent: float

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

func _get_random_polygon_points() -> PackedVector2Array:
	polygon_sides = randi_range(min_polygon_sides, max_polygon_sides)
	var start_angle := randf() * TAU
	var angle_step := TAU / float(polygon_sides)
	var points := PackedVector2Array()

	for side in polygon_sides:
		var angle := start_angle + angle_step * side
		var radius := polygon_radius * randf_range(0.88, 1.12)
		points.append(polygon_center + Vector2(cos(angle), sin(angle)) * radius)

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

const MAIN_GAMEPLAY_SCENE := "res://game/main_gameplay.tscn"
const START_SCREEN_SCENE := "res://game/start_screen.tscn"
const AREA_THRESHOLD := 15.0
const HIGH_SCORE_PATH := "user://high_score.dat"

var game_over := false
var awaiting_next := false
var allow_next_prompt := true
var delete_cutoff_pointers := false
var level_number := 1
var high_score := 0

@onready var area_label: Label = get_parent().get_node("UI/AreaLabel")
@onready var level_label: Label = get_parent().get_node("UI/ScorePanel/LevelLabel")
@onready var high_score_label: Label = get_parent().get_node("UI/ScorePanel/HighScoreLabel")
@onready var game_panel: Panel = get_parent().get_node("UI/GamePanel")
@onready var message_label: Label = get_parent().get_node("UI/GamePanel/VBoxContainer/MessageLabel")
@onready var restart_button: Button = get_parent().get_node("UI/GamePanel/VBoxContainer/ButtonRow/RestartButton")
@onready var menu_button: Button = get_parent().get_node("UI/GamePanel/VBoxContainer/ButtonRow/MenuButton")
@onready var next_button: Button = get_parent().get_node("UI/GamePanel/VBoxContainer/ButtonRow/NextButton")

#endregion

func _ready() -> void:
	_load_high_score()
	_update_score_labels()

	polygon_points = _get_polygon_points(polygon_sides, polygon_center, polygon_radius)
	polygon_edges = _get_polygon_edges(polygon_points)
	_set_up_polygons_once(polygon_sides, polygon_center, polygon_radius, polygon_points)
	update_polygon(polygon_sides, polygon_center, polygon_radius, polygon_points)
	
	full_area = _polygon_area(polygon_points)
	
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

	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	next_button.pressed.connect(_on_next_pressed)
	game_panel.visible = false
	#endregion

func _on_window_resized() -> void:
	if shape_group != null and is_instance_valid(shape_group):
		_apply_outline(shape_group)


func on_viewport_resized() -> void:
	_on_window_resized()

func _process(_delta: float) -> void:
	current_area = _polygon_area(polygon_points)
	current_area_percent = (current_area / full_area) * 100.0
	area_label.text = "%.1f%%" % current_area_percent

	if game_over or awaiting_next:
		MouseCursor.set_cut_mode(false)
		return

	#region cutting
	last_delta = max(_delta, 0.0001)
	cut_mode = Input.is_action_pressed("cut_mode") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	MouseCursor.set_cut_mode(cut_mode)

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

	if Input.is_action_just_pressed("debug_mode"):
		debug = not debug
		timer_label.visible = debug

	if Input.is_action_just_pressed("delete_cutoff_pointers"):
		delete_cutoff_pointers = not delete_cutoff_pointers

	if Input.is_action_just_pressed("add_pointer"):
		_add_pointer()

	if Input.is_action_just_pressed("remove_pointer"):
		_remove_one_pointer()

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
		_spawn_one_pointer()


func _spawn_one_pointer() -> void:
	var spawn_pos = _random_point_in_polygon(polygon_points)
	if spawn_pos == null:
		return

	var pointer: CharacterBody2D = POINTER_SCENE.instantiate()
	pointer.position = spawn_pos
	pointer.z_index = 3
	pointer.set_physics_process(not game_over and not awaiting_next)
	shape_group.add_child(pointer)
	pointer_nodes.append(pointer)


func _add_pointer() -> void:
	pointer_count += 1
	_spawn_one_pointer()


func _remove_one_pointer() -> void:
	if pointer_nodes.is_empty():
		return
	pointer_count = maxi(0, pointer_count - 1)
	var pointer: CharacterBody2D = pointer_nodes.pop_back()
	pointer.queue_free()

func _remove_pointers_in_piece(piece_points: PackedVector2Array) -> void:
	for pointer in pointer_nodes.duplicate():
		if Geometry2D.is_point_in_polygon(pointer.position, piece_points):
			pointer_nodes.erase(pointer)
			pointer.queue_free()
			pointer_count = maxi(0, pointer_count - 1)

func _remove_pointers_outside(bounds: PackedVector2Array) -> void:
	for pointer in pointer_nodes.duplicate():
		if not Geometry2D.is_point_in_polygon(pointer.position, bounds):
			pointer_nodes.erase(pointer)
			pointer.queue_free()
			pointer_count = maxi(0, pointer_count - 1)

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
			else:
				_perform_cut(prev_mouse, mouse)
		return

	if not cut_mode:
		cut_timer.stop()
		cut_timer_going = false

func _count_pointers_in_piece(piece_points: PackedVector2Array) -> int:
	var count := 0
	for pointer in pointer_nodes:
		if Geometry2D.is_point_in_polygon(pointer.position, piece_points):
			count += 1
	return count


func _choose_keeper_piece(
	piece_a: PackedVector2Array,
	piece_b: PackedVector2Array,
	pointers_a: int,
	pointers_b: int
) -> PackedVector2Array:
	if pointers_a > pointers_b:
		return piece_a
	if pointers_b > pointers_a:
		return piece_b

	var area_a := _polygon_area(piece_a)
	var area_b := _polygon_area(piece_b)
	return piece_a if area_a >= area_b else piece_b


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

	_screen_shake()

	var polygon1_points := _build_piece(cut_a, edge_a, cut_b, edge_b, true)
	var polygon2_points := _build_piece(cut_a, edge_a, cut_b, edge_b, false)

	var pointers_in_polygon1 := _count_pointers_in_piece(polygon1_points)
	var pointers_in_polygon2 := _count_pointers_in_piece(polygon2_points)

	if pointers_in_polygon1 > 0 and pointers_in_polygon2 > 0 and not delete_cutoff_pointers:
		game_lost(from, to)
		return

	var keeper := _choose_keeper_piece(
		polygon1_points,
		polygon2_points,
		pointers_in_polygon1,
		pointers_in_polygon2
	)

	polygon_points = keeper
	polygon_edges = _get_polygon_edges(polygon_points)

	var discarded := polygon2_points if polygon1_points == keeper else polygon1_points
	if delete_cutoff_pointers:
		_remove_pointers_in_piece(discarded)
	_remove_pointers_outside(polygon_points)
	update_polygon(polygon_sides, polygon_center, polygon_radius, polygon_points)

	allow_next_prompt = true
	current_area = _polygon_area(polygon_points)
	current_area_percent = (current_area / full_area) * 100.0
	area_label.text = "%.1f%%" % current_area_percent
	_check_area_threshold()

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

	var half_screen := get_viewport().get_visible_rect().size / 2.0

	var piece_center := Vector2.ZERO
	for pt in cut_piece_points:
		piece_center += pt
	piece_center /= cut_piece_points.size()

	var dist_left = piece_center.x + half_screen.x
	var dist_right = half_screen.x - piece_center.x
	var dist_top = piece_center.y + half_screen.y
	var dist_bottom = half_screen.y - piece_center.y

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
	timer_label.z_index = 100
	if not cut_timer.is_stopped():
		time_left_text = "%.2fs" % cut_timer.time_left

	timer_label.text = (
		"timer: %s\n" % time_left_text
		+ "cut_mode: %s\n" % str(cut_mode)
		+ "inside: %s\n" % str(inside)
		+ "speed: %.0f (peak %.0f, min %.0f)\n" % [scalar_mouse_velocity, peak_cut_speed, minimum_cut_speed]
		+ "last: %s\n" % last_reject_reason
		+ "area: %s\n" % current_area_percent
		+ "cmd+3 (no lose, delete cut pointers): %s" % str(delete_cutoff_pointers)
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

#region game flow

func _set_pointer_movement(active: bool) -> void:
	for pointer in pointer_nodes:
		if is_instance_valid(pointer):
			pointer.set_physics_process(active)


func _clear_pointers() -> void:
	for pointer in pointer_nodes:
		if is_instance_valid(pointer):
			pointer.queue_free()
	pointer_nodes.clear()


func _clear_cut_debris() -> void:
	for child in get_children():
		if child is Line2D:
			child.queue_free()
		elif child is CanvasGroup and child != shape_group:
			child.queue_free()


func _reset_polygon() -> void:
	polygon_points = _get_random_polygon_points()
	polygon_edges = _get_polygon_edges(polygon_points)
	update_polygon(polygon_sides, polygon_center, polygon_radius, polygon_points)
	full_area = _polygon_area(polygon_points)
	current_area = full_area
	current_area_percent = 100.0
	area_label.text = "%.1f%%" % current_area_percent


func _screen_shake() -> void:
	var main := get_parent()
	if main.has_method("screen_shake"):
		main.screen_shake()


func _start_next_level() -> void:
	level_number += 1
	pointer_count += 1
	_clear_cut_debris()
	_clear_pointers()
	_reset_polygon()
	_spawn_pointers()
	awaiting_next = false
	allow_next_prompt = true
	_hide_game_panel()
	_set_pointer_movement(true)
	prev_mouse = get_local_mouse_position()
	mouse = prev_mouse
	was_inside = _is_inside(mouse)
	inside = was_inside
	cut_timer.stop()
	cut_timer_going = false
	_update_score_labels()


func _load_high_score() -> void:
	if not FileAccess.file_exists(HIGH_SCORE_PATH):
		high_score = 0
		return

	var file := FileAccess.open(HIGH_SCORE_PATH, FileAccess.READ)
	if file == null:
		high_score = 0
		return

	high_score = file.get_32()


func _save_high_score() -> void:
	var file := FileAccess.open(HIGH_SCORE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_32(high_score)


func _update_score_labels() -> void:
	level_label.text = "Level: %d" % level_number
	high_score_label.text = "High Score: %d" % high_score


func _record_level_beaten() -> void:
	if level_number > high_score:
		high_score = level_number
		_save_high_score()
	_update_score_labels()


func _show_game_panel(message: String, show_lose_buttons: bool, show_next_button: bool) -> void:
	message_label.text = message
	restart_button.visible = show_lose_buttons
	menu_button.visible = show_lose_buttons
	next_button.visible = show_next_button
	game_panel.visible = true
	MouseCursor.set_cut_mode(false)


func _hide_game_panel() -> void:
	game_panel.visible = false


func _check_area_threshold() -> void:
	if game_over or awaiting_next or not allow_next_prompt:
		return
	if current_area_percent <= AREA_THRESHOLD:
		_show_next_panel()


func _show_next_panel() -> void:
	awaiting_next = true
	allow_next_prompt = false
	_set_pointer_movement(false)
	cut_timer.stop()
	cut_timer_going = false
	_record_level_beaten()
	_show_game_panel("Level beaten!", false, true)


func game_lost(from: Vector2, to: Vector2) -> void:
	game_over = true
	_create_line(from, to)
	_set_pointer_movement(false)
	cut_timer.stop()
	cut_timer_going = false
	_show_game_panel("You lost", true, false)


func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_GAMEPLAY_SCENE)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(START_SCREEN_SCENE)


func _on_next_pressed() -> void:
	_start_next_level()

#endregion
