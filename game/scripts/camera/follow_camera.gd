extends Camera2D
class_name FollowCamera

@export var follow_speed := 10.0
@export var target_path: NodePath
@export var room_bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
@export var default_shake_strength := 6.0
@export var default_shake_duration := 0.12

var target: Node2D

var _shake_remaining := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	make_current()
	_apply_room_limits()
	if not target_path.is_empty():
		set_follow_target(get_node_or_null(target_path) as Node2D)
	if target != null:
		global_position = _get_clamped_position(target.global_position)

func _physics_process(delta: float) -> void:
	if target != null:
		var desired_position := _get_clamped_position(target.global_position)
		var follow_weight := 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(desired_position, follow_weight)
	_update_shake(delta)

func set_follow_target(new_target: Node2D) -> void:
	target = new_target
	if is_node_ready() and target != null:
		global_position = _get_clamped_position(target.global_position)

func set_room_bounds(bounds: Rect2) -> void:
	room_bounds = bounds
	_apply_room_limits()
	if target != null:
		global_position = _get_clamped_position(target.global_position)

func shake(strength := -1.0, duration := -1.0) -> void:
	var resolved_strength := default_shake_strength if strength < 0.0 else strength
	var resolved_duration := default_shake_duration if duration < 0.0 else duration
	if resolved_strength <= 0.0 or resolved_duration <= 0.0:
		return
	_shake_strength = maxf(_shake_strength, resolved_strength)
	_shake_duration = maxf(_shake_duration, resolved_duration)
	_shake_remaining = maxf(_shake_remaining, resolved_duration)

func is_shaking() -> bool:
	return _shake_remaining > 0.0

func _apply_room_limits() -> void:
	limit_left = roundi(room_bounds.position.x)
	limit_top = roundi(room_bounds.position.y)
	limit_right = roundi(room_bounds.position.x + room_bounds.size.x)
	limit_bottom = roundi(room_bounds.position.y + room_bounds.size.y)

func _get_clamped_position(world_position: Vector2) -> Vector2:
	var visible_size := get_viewport_rect().size / zoom
	var half_size := visible_size * 0.5
	var min_position := room_bounds.position + half_size
	var max_position := room_bounds.position + room_bounds.size - half_size

	return Vector2(
		_clamp_axis(world_position.x, min_position.x, max_position.x),
		_clamp_axis(world_position.y, min_position.y, max_position.y)
	)

func _clamp_axis(value: float, minimum: float, maximum: float) -> float:
	if minimum > maximum:
		return (minimum + maximum) * 0.5
	return clampf(value, minimum, maximum)

func _update_shake(delta: float) -> void:
	if _shake_remaining <= 0.0:
		_clear_shake()
		return

	_shake_remaining = maxf(0.0, _shake_remaining - delta)
	if _shake_remaining <= 0.0:
		_clear_shake()
		return

	var falloff := _shake_remaining / _shake_duration
	var raw_offset := Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	) * _shake_strength * falloff
	offset = _get_clamped_offset(raw_offset)

func _get_clamped_offset(raw_offset: Vector2) -> Vector2:
	var visible_size := get_viewport_rect().size / zoom
	var half_size := visible_size * 0.5
	var min_position := room_bounds.position + half_size
	var max_position := room_bounds.position + room_bounds.size - half_size
	return Vector2(
		_clamp_offset_axis(raw_offset.x, min_position.x - global_position.x, max_position.x - global_position.x),
		_clamp_offset_axis(raw_offset.y, min_position.y - global_position.y, max_position.y - global_position.y)
	)

func _clamp_offset_axis(value: float, minimum: float, maximum: float) -> float:
	if minimum > maximum:
		return 0.0
	return clampf(value, minimum, maximum)

func _clear_shake() -> void:
	offset = Vector2.ZERO
	_shake_remaining = 0.0
	_shake_duration = 0.0
	_shake_strength = 0.0
