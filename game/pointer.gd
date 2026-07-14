extends CharacterBody2D

@export var base_speed: float = 380.0
@export var bounce_speed_variance: float = 0.12
@export var bounce_angle_variance: float = 0.1
@export var wall_margin: float = 4.0

var speed: float = 380.0
var direction := Vector2.ZERO


func _ready() -> void:
	direction = Vector2.from_angle(randf() * TAU)
	speed = _random_speed()
	_update_sprite_rotation()


func _physics_process(delta: float) -> void:
	var bounds := _get_polygon_points()
	if bounds.is_empty():
		return

	var from := position
	var to := from + direction * speed * delta

	if Geometry2D.is_point_in_polygon(to, bounds):
		position = to
		_update_sprite_rotation()
		return

	var bounce := _bounce_off_edges(from, to, bounds)
	_apply_bounce(bounce.direction, bounce.normal, bounds)
	position = bounce.position

	if not Geometry2D.is_point_in_polygon(position, bounds):
		position = _nudge_inside(position, bounds)

	_update_sprite_rotation()


func _apply_bounce(base_direction: Vector2, normal: Vector2, bounds: PackedVector2Array) -> void:
	var jitter := randf_range(-bounce_angle_variance, bounce_angle_variance)
	direction = base_direction.rotated(jitter).normalized()

	if normal != Vector2.ZERO and direction.dot(normal) < 0.0:
		direction = direction.bounce(normal).normalized()

	speed = _random_speed()


func _random_speed() -> float:
	return base_speed * randf_range(1.0 - bounce_speed_variance, 1.0 + bounce_speed_variance)


func _update_sprite_rotation() -> void:
	rotation = direction.angle()


func _nudge_inside(point: Vector2, bounds: PackedVector2Array) -> Vector2:
	var centroid := _polygon_centroid(bounds)
	var nudged := point
	for i in 8:
		if Geometry2D.is_point_in_polygon(nudged, bounds):
			return nudged
		nudged = nudged.lerp(centroid, 0.2)
	return centroid


func _get_polygon_points() -> PackedVector2Array:
	var node := get_parent()
	while node:
		if node.has_method("get_polygon_points"):
			return node.get_polygon_points()
		node = node.get_parent()
	return PackedVector2Array()


func _bounce_off_edges(from: Vector2, to: Vector2, bounds: PackedVector2Array) -> Dictionary:
	var closest_hit := Vector2.ZERO
	var closest_dist_sq := INF
	var hit_normal := Vector2.ZERO

	for i in bounds.size():
		var a := bounds[i]
		var b := bounds[(i + 1) % bounds.size()]
		var hit = Geometry2D.segment_intersects_segment(from, to, a, b)
		if hit == null:
			continue

		var dist_sq := from.distance_squared_to(hit)
		if dist_sq >= closest_dist_sq:
			continue

		closest_dist_sq = dist_sq
		closest_hit = hit
		hit_normal = _edge_normal_inward(a, b, bounds)

	if closest_dist_sq == INF:
		var centroid := _polygon_centroid(bounds)
		var away := (from - centroid).normalized()
		return {
			"direction": away,
			"normal": Vector2.ZERO,
			"position": from,
		}

	var new_direction := direction.bounce(hit_normal).normalized()
	var new_position := closest_hit + hit_normal * wall_margin
	return {
		"direction": new_direction,
		"normal": hit_normal,
		"position": new_position,
	}


func _edge_normal_inward(a: Vector2, b: Vector2, bounds: PackedVector2Array) -> Vector2:
	var edge := (b - a).normalized()
	var normal := Vector2(-edge.y, edge.x)
	var midpoint := (a + b) * 0.5
	var to_inside := _polygon_centroid(bounds) - midpoint
	if normal.dot(to_inside) < 0.0:
		normal = -normal
	return normal


func _polygon_centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / points.size()
