extends Node2D
class_name SwordArcFx

@export var lifetime := 0.14
@export var arc_color := Color(0.91, 0.894, 0.831, 0.85)
@export var arc_radius := 34.0
@export var arc_thickness := 4.0
@export var arc_span := 1.4
@export var arc_segments := 12

var age := 0.0
var facing_direction := 1
var _base_alpha := 0.85

func _ready() -> void:
	z_index = 70
	_base_alpha = arc_color.a
	modulate.a = 1.0

func setup(direction: int = 1, world_position: Vector2 = Vector2.ZERO) -> void:
	if direction != 0:
		facing_direction = 1 if direction > 0 else -1
	global_position = world_position
	scale.x = absf(scale.x) * float(facing_direction)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	var progress := clampf(age / maxf(lifetime, 0.001), 0.0, 1.0)
	modulate.a = 1.0 - smoothstep(0.35, 1.0, progress)
	queue_redraw()
	if progress >= 1.0:
		queue_free()

func _draw() -> void:
	var progress := clampf(age / maxf(lifetime, 0.001), 0.0, 1.0)
	var sweep_width := lerpf(arc_span, arc_span * 0.5, progress)
	var radius := lerpf(arc_radius * 0.85, arc_radius * 1.05, progress)
	var thickness := lerpf(arc_thickness, arc_thickness * 0.4, progress)
	var start_angle := -sweep_width * 0.5
	var step := sweep_width / float(maxi(arc_segments, 1))
	var points := PackedVector2Array()
	for i in range(arc_segments + 1):
		var angle := start_angle + step * float(i)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	var color := Color(arc_color.r, arc_color.g, arc_color.b, _base_alpha)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, thickness, true)
	if points.size() >= 2:
		var inner_color := Color(1.0, 1.0, 1.0, _base_alpha * 0.6)
		draw_line(points[0], points[points.size() - 1], inner_color, thickness * 0.35, true)
