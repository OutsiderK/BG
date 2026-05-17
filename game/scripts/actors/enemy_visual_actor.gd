extends Node2D
class_name EnemyVisualActor

const SUPPORTED_STATES := [
	&"idle",
	&"move",
	&"telegraph",
	&"attack",
	&"hurt",
	&"death",
]

@export var base_color := Color(0.24, 0.39, 0.22, 1.0)
@export var shadow_color := Color(0.08, 0.12, 0.09, 1.0)
@export var rot_color := Color(0.45, 0.12, 0.12, 1.0)
@export var crack_color := Color(0.87, 0.91, 0.78, 1.0)
@export var sap_color := Color(0.58, 0.78, 0.26, 1.0)
@export var warning_color := Color(1.0, 0.84, 0.18, 0.88)
@export var attack_color := Color(0.86, 0.18, 0.1, 0.9)

var current_state: StringName = &"idle"
var facing := 1.0
var _state_time := 0.0
var _hurt_flash_time := 0.0

func _ready() -> void:
	z_index = 1
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_state_time += delta
	_hurt_flash_time = maxf(0.0, _hurt_flash_time - delta)
	queue_redraw()

func play_state(state_name: StringName) -> void:
	if not SUPPORTED_STATES.has(state_name):
		state_name = &"idle"
	if current_state == state_name:
		return
	current_state = state_name
	_state_time = 0.0
	queue_redraw()

func flash_hurt() -> void:
	_hurt_flash_time = 0.18
	play_state(&"hurt")

func set_facing_direction(direction: Vector2) -> void:
	if absf(direction.x) <= 0.01:
		return
	facing = signf(direction.x)
	queue_redraw()

func has_visual_state(state_name: StringName) -> bool:
	return SUPPORTED_STATES.has(state_name)

func _draw() -> void:
	var flip := Transform2D(Vector2(facing, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
	draw_set_transform_matrix(flip)

	var pulse := sin(_state_time * 7.0)
	var crouch := 0.0
	var lunge := 0.0
	var bob := 0.0
	var broken := 0.0
	match current_state:
		&"move":
			bob = pulse * 1.8
		&"telegraph":
			crouch = 4.0 + maxf(0.0, pulse) * 1.2
		&"attack":
			lunge = 7.0
			crouch = 2.0
		&"hurt":
			broken = 2.0
		&"death":
			crouch = 10.0
			broken = 6.0
		_:
			bob = pulse * 0.8

	var body_tint := base_color
	if current_state == &"telegraph":
		body_tint = body_tint.lerp(warning_color, 0.25)
	elif current_state == &"attack":
		body_tint = body_tint.lerp(attack_color, 0.32)
	elif current_state == &"death":
		body_tint = body_tint.darkened(0.38)
	if _hurt_flash_time > 0.0:
		body_tint = Color.WHITE.lerp(body_tint, 0.38)

	_draw_ground_shadow(crouch)
	if current_state == &"telegraph":
		_draw_warning_splinters(crouch, pulse)

	_draw_back_plates(body_tint, crouch, lunge, bob, broken)
	_draw_core(body_tint, crouch, lunge, bob, broken)
	_draw_head(body_tint, crouch, lunge, bob, broken)
	_draw_legs(crouch, lunge, bob, broken)
	_draw_cracks(crouch, lunge, bob, broken)

	if current_state == &"attack":
		_draw_attack_splinter(crouch, lunge)
	elif current_state == &"death":
		_draw_death_shards(crouch, broken)

func _draw_ground_shadow(crouch: float) -> void:
	var alpha := 0.28 if current_state != &"death" else 0.16
	_draw_flat_ellipse(Vector2(2.0, -1.0), Vector2(26.0, 5.0 + crouch * 0.18), Color(0.02, 0.025, 0.02, alpha))

func _draw_back_plates(tint: Color, crouch: float, lunge: float, bob: float, broken: float) -> void:
	var lift := bob + crouch * 0.45
	var rear_plate := PackedVector2Array([
		Vector2(-23.0 - broken, -17.0 + lift),
		Vector2(-12.0, -32.0 + lift),
		Vector2(-3.0 + lunge * 0.3, -24.0 + lift),
		Vector2(-7.0, -12.0 + crouch),
	])
	var mid_plate := PackedVector2Array([
		Vector2(-9.0, -25.0 + lift),
		Vector2(8.0 + lunge * 0.55, -31.0 + lift),
		Vector2(18.0 + lunge, -20.0 + crouch),
		Vector2(2.0, -10.0 + crouch),
	])
	draw_colored_polygon(rear_plate, shadow_color.lerp(tint, 0.5))
	draw_polyline(_closed(rear_plate), crack_color.darkened(0.3), 1.0)
	draw_colored_polygon(mid_plate, tint)
	draw_polyline(_closed(mid_plate), shadow_color, 1.0)

func _draw_core(tint: Color, crouch: float, lunge: float, bob: float, broken: float) -> void:
	var lift := bob + crouch * 0.35
	var core := PackedVector2Array([
		Vector2(-18.0 - broken * 0.4, -15.0 + lift),
		Vector2(-5.0, -27.0 + lift),
		Vector2(20.0 + lunge, -21.0 + lift),
		Vector2(24.0 + lunge * 0.7, -9.0 + crouch),
		Vector2(5.0, -5.0 + crouch),
		Vector2(-15.0, -7.0 + crouch),
	])
	draw_colored_polygon(core, tint.darkened(0.08))
	draw_polyline(_closed(core), shadow_color, 1.25)
	draw_line(Vector2(-12.0, -13.0 + lift), Vector2(12.0 + lunge * 0.45, -17.0 + lift), rot_color, 3.0)
	draw_line(Vector2(-6.0, -10.0 + lift), Vector2(18.0 + lunge * 0.55, -12.0 + lift), sap_color.darkened(0.08), 2.0)

func _draw_head(tint: Color, crouch: float, lunge: float, bob: float, broken: float) -> void:
	var lift := bob + crouch * 0.25
	var head := PackedVector2Array([
		Vector2(16.0 + lunge, -23.0 + lift),
		Vector2(31.0 + lunge + broken * 0.3, -19.0 + lift),
		Vector2(27.0 + lunge, -9.0 + crouch),
		Vector2(14.0 + lunge * 0.6, -11.0 + crouch),
	])
	draw_colored_polygon(head, tint.lerp(rot_color, 0.18))
	draw_polyline(_closed(head), shadow_color, 1.25)
	var eye_color := Color(0.86, 1.0, 0.33, 0.92)
	if current_state == &"hurt":
		eye_color = Color.WHITE
	elif current_state == &"death":
		eye_color = Color(0.2, 0.3, 0.16, 0.55)
	draw_line(Vector2(22.0 + lunge, -17.0 + lift), Vector2(28.0 + lunge, -15.0 + lift), eye_color, 1.5)

func _draw_legs(crouch: float, lunge: float, bob: float, broken: float) -> void:
	var leg_color := shadow_color.lerp(base_color, 0.35)
	var front_foot := Vector2(25.0 + lunge, -2.0)
	var rear_foot := Vector2(-17.0 - broken * 0.35, -1.0)
	if current_state == &"move":
		front_foot.x += sin(_state_time * 14.0) * 3.0
		rear_foot.x -= sin(_state_time * 14.0) * 2.0
	draw_line(Vector2(14.0 + lunge * 0.5, -9.0 + crouch + bob * 0.2), front_foot, leg_color, 4.0)
	draw_line(Vector2(-9.0, -8.0 + crouch + bob * 0.2), rear_foot, leg_color, 4.0)
	draw_line(front_foot + Vector2(-5.0, 0.0), front_foot + Vector2(7.0, 0.0), rot_color.darkened(0.2), 2.0)
	draw_line(rear_foot + Vector2(-6.0, 0.0), rear_foot + Vector2(5.0, 0.0), rot_color.darkened(0.2), 2.0)

func _draw_cracks(crouch: float, lunge: float, bob: float, broken: float) -> void:
	var lift := bob + crouch * 0.32
	var crack_alpha := 0.92 if current_state != &"death" else 0.5
	var crack := Color(crack_color.r, crack_color.g, crack_color.b, crack_alpha)
	draw_line(Vector2(-2.0, -24.0 + lift), Vector2(3.0, -18.0 + lift), crack, 1.2)
	draw_line(Vector2(3.0, -18.0 + lift), Vector2(-1.0, -12.0 + crouch), crack, 1.2)
	draw_line(Vector2(10.0 + lunge * 0.45, -23.0 + lift), Vector2(17.0 + lunge * 0.55, -15.0 + lift), crack, 1.2)
	draw_line(Vector2(-16.0 - broken * 0.4, -16.0 + lift), Vector2(-9.0, -12.0 + lift), crack.darkened(0.15), 1.0)

func _draw_warning_splinters(crouch: float, pulse: float) -> void:
	var reach := 22.0 + maxf(0.0, pulse) * 4.0
	var alpha := 0.55 + maxf(0.0, pulse) * 0.25
	var color := Color(warning_color.r, warning_color.g, warning_color.b, alpha)
	draw_line(Vector2(18.0, -16.0 + crouch), Vector2(18.0 + reach, -20.0 + crouch), color, 2.0)
	draw_line(Vector2(20.0, -11.0 + crouch), Vector2(18.0 + reach * 0.8, -7.0 + crouch), color, 2.0)
	draw_line(Vector2(24.0, -23.0 + crouch * 0.4), Vector2(24.0 + reach * 0.55, -32.0 + crouch * 0.4), color.darkened(0.05), 1.5)

func _draw_attack_splinter(crouch: float, lunge: float) -> void:
	var splinter := PackedVector2Array([
		Vector2(27.0 + lunge, -17.0 + crouch * 0.3),
		Vector2(53.0 + lunge, -12.0 + crouch * 0.2),
		Vector2(27.0 + lunge, -8.0 + crouch),
	])
	draw_colored_polygon(splinter, attack_color)
	draw_polyline(_closed(splinter), crack_color, 1.0)

func _draw_death_shards(crouch: float, broken: float) -> void:
	var shard_color := shadow_color.lerp(rot_color, 0.4)
	draw_line(Vector2(-18.0 - broken, -8.0 + crouch), Vector2(-29.0, -2.0), shard_color, 3.0)
	draw_line(Vector2(8.0, -7.0 + crouch), Vector2(19.0, -1.0), shard_color, 3.0)
	draw_line(Vector2(22.0, -10.0 + crouch), Vector2(34.0, -3.0), crack_color.darkened(0.35), 2.0)

func _draw_flat_ellipse(center: Vector2, radius: Vector2, color: Color, point_count: int = 24) -> void:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed_points := PackedVector2Array(points)
	if points.size() > 0:
		closed_points.append(points[0])
	return closed_points
