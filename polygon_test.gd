extends Node2D
#
#@onready var increase_side_button: Button = %IncreaseSideButton
#@onready var decrease_side_button: Button = %DecreaseSideButton
#
#@export var polygon_sides: int = 10
#@onready var polygon_center: Vector2 = Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2)
#@export var polygon_radius: float = 200.0
#
#var shape_polygon: Polygon2D
#var collision_polygon: CollisionPolygon2D
#
## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#draw_new_polygon(polygon_sides, polygon_center, polygon_radius)
	#
	#increase_side_button.pressed.connect(_on_increase_side_button_pressed)
	#decrease_side_button.pressed.connect(_on_decrease_side_button_pressed)
	#
#func _on_increase_side_button_pressed():
	#delete_polygon_children()
	#polygon_sides += 1
	#draw_new_polygon(polygon_sides, polygon_center, polygon_radius)
	#
#func _on_decrease_side_button_pressed():
	#delete_polygon_children()
	#polygon_sides -= 1
	#draw_new_polygon(polygon_sides, polygon_center, polygon_radius)
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
#
#func draw_new_polygon(sides: int, center: Vector2, radius: float, start_angle: float = -PI/2):
	#shape_polygon = Polygon2D.new()
	#collision_polygon = CollisionPolygon2D.new()
	#
	#var shape_points: PackedVector2Array = make_regular_polygon(sides, center, radius)
	#
	#shape_polygon.polygon = shape_points
	#collision_polygon.polygon = shape_points
	#
	#add_child(shape_polygon)
	#shape_polygon.add_child(collision_polygon)
#
#func make_regular_polygon(sides: int, center: Vector2, radius: float, start_angle: float = -PI/2) -> PackedVector2Array:
	#var points := PackedVector2Array()
	#var angle_step := TAU / sides # TAU = 2 * PI = full circle
	#
	#for side in sides:
		#var angle := start_angle + angle_step * side
		#points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		#
	#return points
#
#func delete_polygon_children():
	#for child in get_children():
		#if child is Polygon2D or child is CollisionPolygon2D:
			#child.queue_free()
