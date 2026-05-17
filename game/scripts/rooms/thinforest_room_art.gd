extends Node2D
class_name ThinforestRoomArt

@export_enum("backdrop", "midground", "foreground") var layer := "backdrop"
@export var room_size := Vector2(1280, 720)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	match layer:
		"backdrop":
			_draw_backdrop()
		"midground":
			_draw_midground()
		"foreground":
			_draw_foreground()

func _draw_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, room_size), Color(0.055, 0.088, 0.083, 1.0))
	draw_rect(Rect2(0, 0, room_size.x, 150), Color(0.068, 0.118, 0.098, 1.0))
	_draw_flat_leaf_strip(18, 86, Color(0.040, 0.075, 0.060, 0.92))
	_draw_flat_leaf_strip(95, 54, Color(0.090, 0.145, 0.104, 0.38))
	_draw_flat_leaf_strip(566, 66, Color(0.062, 0.106, 0.087, 0.44))

	for x in [-60.0, 140.0, 388.0, 668.0, 1024.0, 1226.0]:
		_draw_far_trunk(x, Color(0.035, 0.052, 0.047, 0.50))

	_draw_fog_band(168, 68, Color(0.52, 0.67, 0.60, 0.085))
	_draw_fog_band(302, 88, Color(0.44, 0.62, 0.56, 0.070))
	_draw_fog_band(502, 54, Color(0.63, 0.70, 0.58, 0.060))

func _draw_midground() -> void:
	_draw_ground_slab()
	_draw_branch_platform(Rect2(350, 418, 240, 24), true)
	_draw_branch_platform(Rect2(810, 338, 180, 24), false)
	_draw_trunk_column(Rect2(292, 400, 56, 116))
	_draw_root_wall(Rect2(675, 468, 120, 48))
	_draw_exit_rift(Rect2(1159, 424, 42, 92), 516)
	_draw_exit_rift(Rect2(1039, 264, 42, 92), 356)

func _draw_foreground() -> void:
	var vine_color := Color(0.26, 0.38, 0.28, 0.16)
	var leaf_color := Color(0.48, 0.66, 0.43, 0.12)
	for x in [34.0, 184.0, 1112.0, 1252.0]:
		draw_line(Vector2(x, 0), Vector2(x - 42, 182), vine_color, 5.0)
		draw_line(Vector2(x + 18, 8), Vector2(x + 2, 140), vine_color, 3.0)
	for rect in [
		Rect2(18, 92, 96, 18),
		Rect2(1076, 128, 154, 16),
		Rect2(72, 612, 190, 18),
		Rect2(944, 586, 232, 16),
	]:
		_draw_soft_leaf_cluster(rect, leaf_color)
	for start in [Vector2(0, 646), Vector2(1082, 642)]:
		draw_arc(start, 148, -1.15, 0.15, 18, Color(0.25, 0.20, 0.13, 0.15), 7.0)

func _draw_flat_leaf_strip(y: float, height: float, color: Color) -> void:
	var points := PackedVector2Array([
		Vector2(0, y + 12),
		Vector2(185, y),
		Vector2(420, y + height * 0.36),
		Vector2(720, y + height * 0.12),
		Vector2(1010, y + height * 0.46),
		Vector2(room_size.x, y + height * 0.22),
		Vector2(room_size.x, y + height),
		Vector2(0, y + height),
	])
	draw_colored_polygon(points, color)

func _draw_far_trunk(x: float, color: Color) -> void:
	draw_rect(Rect2(x, 94, 44, 494), color)
	draw_rect(Rect2(x + 28, 130, 18, 440), Color(color.r * 1.3, color.g * 1.25, color.b * 1.18, color.a * 0.54))
	draw_line(Vector2(x + 8, 248), Vector2(x - 78, 336), Color(color.r, color.g, color.b, color.a * 0.48), 13.0)
	draw_line(Vector2(x + 37, 206), Vector2(x + 122, 268), Color(color.r, color.g, color.b, color.a * 0.42), 9.0)

func _draw_fog_band(y: float, height: float, color: Color) -> void:
	draw_rect(Rect2(0, y, room_size.x, height), color)
	draw_line(Vector2(0, y + height * 0.28), Vector2(room_size.x, y + height * 0.08), Color(color.r, color.g, color.b, color.a * 0.72), 6.0)
	draw_line(Vector2(96, y + height * 0.74), Vector2(room_size.x - 80, y + height * 0.56), Color(color.r, color.g, color.b, color.a * 0.55), 4.0)

func _draw_ground_slab() -> void:
	draw_rect(Rect2(0, 516, room_size.x, 204), Color(0.118, 0.126, 0.073, 1.0))
	draw_rect(Rect2(0, 516, room_size.x, 10), Color(0.374, 0.284, 0.151, 1.0))
	draw_rect(Rect2(0, 528, room_size.x, 15), Color(0.198, 0.164, 0.092, 1.0))
	for x in range(0, 1280, 92):
		draw_line(Vector2(x, 528), Vector2(x + 58, 720), Color(0.074, 0.082, 0.052, 0.38), 3.0)
	for x in range(-40, 1280, 170):
		draw_arc(Vector2(x, 560), 98, -0.20, 1.08, 16, Color(0.276, 0.206, 0.120, 0.52), 6.0)

func _draw_branch_platform(rect: Rect2, heavier: bool) -> void:
	var bark := Color(0.318, 0.214, 0.116, 1.0)
	var rim := Color(0.586, 0.428, 0.204, 1.0)
	var underside := Color(0.150, 0.104, 0.063, 1.0)
	draw_rect(rect, bark)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), rim)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 7), Vector2(rect.size.x, 7)), underside)
	draw_line(rect.position + Vector2(12, 12), rect.position + Vector2(rect.size.x - 18, 9), Color(0.704, 0.526, 0.263, 0.45), 2.0)
	draw_line(rect.position + Vector2(20, 20), rect.position + Vector2(rect.size.x - 10, 17), Color(0.087, 0.061, 0.039, 0.52), 2.0)
	var root_drop := 22.0 if heavier else 14.0
	for x in [rect.position.x + 28, rect.position.x + rect.size.x - 44]:
		draw_line(Vector2(x, rect.position.y + rect.size.y), Vector2(x - 8, rect.position.y + rect.size.y + root_drop), Color(0.190, 0.125, 0.071, 0.78), 5.0)

func _draw_trunk_column(rect: Rect2) -> void:
	draw_rect(rect, Color(0.214, 0.132, 0.077, 1.0))
	draw_rect(Rect2(rect.position + Vector2(6, 0), Vector2(10, rect.size.y)), Color(0.380, 0.254, 0.128, 0.70))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 11, 0), Vector2(6, rect.size.y)), Color(0.090, 0.058, 0.038, 0.64))
	draw_line(rect.position + Vector2(4, 4), rect.position + Vector2(rect.size.x - 8, 30), Color(0.603, 0.430, 0.203, 0.38), 3.0)
	draw_line(rect.position + Vector2(7, 66), rect.position + Vector2(rect.size.x - 4, 100), Color(0.062, 0.040, 0.028, 0.50), 3.0)

func _draw_root_wall(rect: Rect2) -> void:
	draw_rect(rect, Color(0.250, 0.158, 0.087, 1.0))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7)), Color(0.545, 0.385, 0.178, 1.0))
	for offset in [12.0, 42.0, 76.0, 108.0]:
		draw_line(rect.position + Vector2(offset, 6), rect.position + Vector2(offset - 22, rect.size.y), Color(0.111, 0.076, 0.048, 0.56), 5.0)
	draw_arc(rect.position + Vector2(14, rect.size.y), 54, -1.20, -0.12, 14, Color(0.358, 0.235, 0.125, 0.55), 6.0)
	draw_arc(rect.position + Vector2(rect.size.x - 6, rect.size.y), 58, -3.02, -1.88, 14, Color(0.358, 0.235, 0.125, 0.45), 5.0)

func _draw_exit_rift(rect: Rect2, floor_y: float) -> void:
	draw_rect(rect, Color(0.052, 0.138, 0.130, 0.72))
	draw_rect(Rect2(rect.position + Vector2(6, 0), Vector2(5, rect.size.y)), Color(0.450, 0.720, 0.610, 0.28))
	draw_line(rect.position + Vector2(rect.size.x * 0.54, 2), Vector2(rect.position.x + rect.size.x * 0.42, floor_y), Color(0.670, 0.935, 0.770, 0.38), 2.0)
	draw_line(rect.position + Vector2(0, rect.size.y * 0.32), rect.position + Vector2(rect.size.x, rect.size.y * 0.24), Color(0.226, 0.459, 0.371, 0.46), 2.0)

func _draw_soft_leaf_cluster(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array([
		rect.position + Vector2(0, rect.size.y * 0.55),
		rect.position + Vector2(rect.size.x * 0.24, 0),
		rect.position + Vector2(rect.size.x * 0.68, rect.size.y * 0.15),
		rect.position + Vector2(rect.size.x, rect.size.y * 0.48),
		rect.position + Vector2(rect.size.x * 0.76, rect.size.y),
		rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.86),
	])
	draw_colored_polygon(points, color)
