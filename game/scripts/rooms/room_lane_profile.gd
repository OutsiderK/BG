extends Resource
class_name RoomLaneProfile

@export var x_min := 0.0
@export var x_max := 1280.0
@export var z_min := 240.0
@export var z_max := 640.0
@export var lane_offsets: Array[float] = [-160.0, 0.0, 160.0]
@export var lane_z_values: Array[float] = []
@export var vertical_platform_y_values: Array[float] = [480.0]
@export var enemy_ground_y_values: Array[float] = [480.0]
@export var fallback_vertical_y := 480.0
@export var fallback_enemy_relocation := Vector2(640.0, 480.0)

func get_lane_offset(index: int) -> float:
	if lane_offsets.is_empty():
		return 0.0
	return lane_offsets[wrapi(index, 0, lane_offsets.size())]

func get_unfold_center_z() -> float:
	return (get_z_min() + get_z_max()) * 0.5

func get_lane_count() -> int:
	if not lane_z_values.is_empty():
		return lane_z_values.size()
	if not lane_offsets.is_empty():
		return lane_offsets.size()
	return 1

func normalize_lane_index(index: int) -> int:
	return wrapi(index, 0, get_lane_count())

func get_x_min() -> float:
	return minf(x_min, x_max)

func get_x_max() -> float:
	return maxf(x_min, x_max)

func get_z_min() -> float:
	return minf(z_min, z_max)

func get_z_max() -> float:
	return maxf(z_min, z_max)

func get_lane_z(index: int) -> float:
	if not lane_z_values.is_empty():
		return clampf(lane_z_values[normalize_lane_index(index)], get_z_min(), get_z_max())
	return clampf(get_unfold_center_z() + get_lane_offset(index), get_z_min(), get_z_max())

func get_nearest_lane_index(z: float) -> int:
	var lane_count := get_lane_count()
	var nearest_index := 0
	var nearest_distance := INF
	for lane_index in range(lane_count):
		var distance := absf(get_lane_z(lane_index) - z)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = lane_index
	return nearest_index

func get_lanes_sorted_away_from_z(z: float) -> Array[int]:
	var lanes: Array[int] = []
	for lane_index in range(get_lane_count()):
		lanes.append(lane_index)
	lanes.sort_custom(func(a: int, b: int) -> bool:
		var distance_a := absf(get_lane_z(a) - z)
		var distance_b := absf(get_lane_z(b) - z)
		if is_equal_approx(distance_a, distance_b):
			return a < b
		return distance_a > distance_b
	)
	return lanes

func pick_enemy_lane(player_unfold_position: Vector2, enemy_index: int, preferred_lane: int = -1) -> int:
	if preferred_lane >= 0:
		return normalize_lane_index(preferred_lane)
	var lanes := get_lanes_sorted_away_from_z(player_unfold_position.y)
	if lanes.is_empty():
		return 0
	return lanes[wrapi(enemy_index, 0, lanes.size())]

func clamp_unfold_point(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, get_x_min(), get_x_max()), clampf(point.y, get_z_min(), get_z_max()))

func get_nearest_legal_unfold_point(point: Vector2, lane_index: int = -1) -> Vector2:
	var legal_point := clamp_unfold_point(point)
	if lane_index >= 0:
		legal_point.y = get_lane_z(lane_index)
	return legal_point

func get_player_unfold_start(vertical_position: Vector2) -> Vector2:
	return get_nearest_legal_unfold_point(Vector2(vertical_position.x, get_unfold_center_z()))

func get_enemy_unfold_start(vertical_position: Vector2, lane_index: int) -> Vector2:
	return get_nearest_legal_unfold_point(Vector2(vertical_position.x, get_lane_z(lane_index)), lane_index)

func get_nearest_platform_y(point: Vector2) -> float:
	return _get_nearest_y(point.y, vertical_platform_y_values, fallback_vertical_y)

func get_nearest_enemy_ground_y(point: Vector2) -> float:
	return _get_nearest_y(point.y, enemy_ground_y_values, fallback_enemy_relocation.y)

func get_player_restore_position(unfold_position: Vector2) -> Vector2:
	return Vector2(clampf(unfold_position.x, get_x_min(), get_x_max()), get_nearest_platform_y(unfold_position))

func get_enemy_restore_position(unfold_position: Vector2) -> Vector2:
	if enemy_ground_y_values.is_empty():
		return Vector2(clampf(fallback_enemy_relocation.x, get_x_min(), get_x_max()), fallback_enemy_relocation.y)
	return Vector2(clampf(unfold_position.x, get_x_min(), get_x_max()), get_nearest_enemy_ground_y(unfold_position))

func _get_nearest_y(target_y: float, candidates: Array[float], fallback_y: float) -> float:
	if candidates.is_empty():
		return fallback_y
	var nearest_y := candidates[0]
	var nearest_distance := absf(target_y - nearest_y)
	for candidate in candidates:
		var distance := absf(target_y - candidate)
		if distance < nearest_distance:
			nearest_y = candidate
			nearest_distance = distance
	return nearest_y
