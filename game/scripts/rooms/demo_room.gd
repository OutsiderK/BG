extends Node2D
class_name DemoRoom

const LANE_WEAK_ALPHA := 0.16
const LANE_STRONG_ALPHA := 0.78
const LANE_BASE_COLOR := Color(0.36, 0.73, 0.55, 1.0)
const PLAYER_LANDING_COLOR := Color(0.95, 0.86, 0.42, 0.92)
const ENEMY_LANDING_COLOR := Color(0.95, 0.28, 0.26, 0.9)
const PLAYER_SNAP_COLOR := Color(0.50, 0.88, 1.0, 0.92)
const ENEMY_SNAP_COLOR := Color(1.0, 0.64, 0.36, 0.9)
const LANDING_HINT_SIZE := 34.0
const SNAP_HINT_SIZE := 42.0
const HINT_THICKNESS := 4.0
const SNAP_HINT_DURATION := 0.7

@export var lane_profile: Resource

@onready var player_spawn: Marker2D = %PlayerSpawn
@onready var unfold_floor_center: Marker2D = %UnfoldFloorCenter
@onready var enemy_spawns: Node2D = %EnemySpawns
@onready var collapse_relocation_points: Node2D = %CollapseRelocationPoints
@onready var next_room_entries: Node2D = %NextRoomEntries
@onready var lane_preview: Node2D = $LanePreview
@onready var lane_markers: Node2D = $UnfoldData/LaneMarkers
@onready var landing_hints: Node2D = %LandingHints
@onready var snap_hints: Node2D = %SnapHints

var _landing_hint_nodes := {}

func _ready() -> void:
	_connect_unfold_signals()
	UnfoldManager.set_room_adapter(self)
	_set_lane_preview_strength(false)
	_clear_landing_hints()

func get_lane_profile() -> Resource:
	return lane_profile

func get_room_lane_profile() -> Resource:
	return lane_profile

func get_unfold_lanes() -> Array[float]:
	return _get_lane_y_values()

func get_unfold_floor_center() -> Vector2:
	return unfold_floor_center.global_position

func get_player_spawn_position() -> Vector2:
	return player_spawn.global_position

func get_enemy_spawn_positions() -> Array[Vector2]:
	return _collect_marker_positions(enemy_spawns)

func get_collapse_relocation_positions() -> Array[Vector2]:
	return _collect_marker_positions(collapse_relocation_points)

func get_next_room_entry_positions() -> Array[Vector2]:
	return _collect_marker_positions(next_room_entries)

func map_player_to_unfolded(player: Node, vertical_position: Vector2) -> Vector2:
	var target := Vector2(_clamp_room_x(vertical_position.x), unfold_floor_center.global_position.y)
	_update_landing_hint(_landing_key("player", player), target, true)
	return target

func map_enemy_to_unfolded(enemy: Node, vertical_position: Vector2, lane_index: int) -> Vector2:
	var target := Vector2(_clamp_room_x(vertical_position.x), _get_lane_y(lane_index))
	_update_landing_hint(_landing_key("enemy", enemy), target, false)
	return target

func restore_player_to_vertical(player: Node, unfold_position: Vector2, reason: String) -> Vector2:
	var restored_position: Vector2
	if lane_profile != null and lane_profile.has_method("get_player_restore_position"):
		restored_position = lane_profile.call("get_player_restore_position", unfold_position)
	else:
		restored_position = Vector2(_clamp_room_x(unfold_position.x), player_spawn.global_position.y)
	if reason == "collapse":
		_show_snap_hint(_landing_key("player_snap", player), restored_position, true)
	return restored_position

func restore_enemy_to_vertical(enemy: Node, unfold_position: Vector2, reason: String) -> Vector2:
	var restored_position: Vector2
	if lane_profile != null and lane_profile.has_method("get_enemy_restore_position"):
		restored_position = lane_profile.call("get_enemy_restore_position", unfold_position)
	else:
		restored_position = _get_nearest_collapse_relocation(unfold_position)
	if reason == "collapse":
		_show_snap_hint(_landing_key("enemy_snap", enemy), restored_position, false)
	return restored_position

func pick_enemy_unfold_lane(_enemy: Node, enemy_index: int, player_unfold_position: Vector2, preferred_lane: int = -1) -> int:
	var lane_count := _get_lane_count()
	if lane_count <= 0:
		return 0
	if preferred_lane >= 0:
		return wrapi(preferred_lane, 0, lane_count)
	var lanes: Array[int] = []
	for lane_index in range(lane_count):
		lanes.append(lane_index)
	lanes.sort_custom(func(a: int, b: int) -> bool:
		var distance_a := absf(_get_lane_y(a) - player_unfold_position.y)
		var distance_b := absf(_get_lane_y(b) - player_unfold_position.y)
		if is_equal_approx(distance_a, distance_b):
			return a < b
		return distance_a > distance_b
	)
	return lanes[wrapi(enemy_index, 0, lanes.size())]

func _collect_marker_positions(parent: Node) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for child in parent.get_children():
		if child is Marker2D:
			positions.append(child.global_position)
	return positions

func _connect_unfold_signals() -> void:
	if not UnfoldManager.unfold_transition_started.is_connected(_on_unfold_transition_started):
		UnfoldManager.unfold_transition_started.connect(_on_unfold_transition_started)
	if not UnfoldManager.unfold_entered.is_connected(_on_unfold_entered):
		UnfoldManager.unfold_entered.connect(_on_unfold_entered)
	if not UnfoldManager.unfold_ended.is_connected(_on_unfold_ended):
		UnfoldManager.unfold_ended.connect(_on_unfold_ended)
	if not UnfoldManager.mapping_applied.is_connected(_on_mapping_applied):
		UnfoldManager.mapping_applied.connect(_on_mapping_applied)

func _on_unfold_transition_started(kind: String) -> void:
	if kind == "collapse":
		_set_lane_preview_strength(false)

func _on_mapping_applied() -> void:
	_set_lane_preview_strength(true)

func _on_unfold_entered() -> void:
	_set_lane_preview_strength(true)

func _on_unfold_ended(_reason: String) -> void:
	_set_lane_preview_strength(false)
	_clear_landing_hints()

func _set_lane_preview_strength(strong: bool) -> void:
	var alpha := LANE_STRONG_ALPHA if strong else LANE_WEAK_ALPHA
	for child in lane_preview.get_children():
		var lane_rect := child as ColorRect
		if lane_rect == null:
			continue
		var color := LANE_BASE_COLOR
		color.a = alpha
		lane_rect.color = color

func _update_landing_hint(key: String, global_point: Vector2, is_player_hint: bool) -> void:
	var color := PLAYER_LANDING_COLOR if is_player_hint else ENEMY_LANDING_COLOR
	var hint := _ensure_landing_hint(key, color)
	hint.global_position = global_point
	hint.visible = true
	hint.modulate = Color.WHITE
	hint.scale = Vector2(0.82, 0.82)
	var tween := create_tween()
	tween.tween_property(hint, "scale", Vector2.ONE, 0.14)

func _ensure_landing_hint(key: String, color: Color) -> Node2D:
	var hint = _landing_hint_nodes.get(key)
	if hint is Node2D and is_instance_valid(hint):
		_recolor_hint(hint, color)
		return hint
	var created := _create_cross_hint(key, color, LANDING_HINT_SIZE)
	landing_hints.add_child(created)
	_landing_hint_nodes[key] = created
	return created

func _show_snap_hint(key: String, global_point: Vector2, is_player_hint: bool) -> void:
	var color := PLAYER_SNAP_COLOR if is_player_hint else ENEMY_SNAP_COLOR
	var hint := _create_cross_hint(key, color, SNAP_HINT_SIZE)
	snap_hints.add_child(hint)
	hint.global_position = global_point
	hint.scale = Vector2(0.72, 0.72)
	var tween := create_tween()
	tween.tween_property(hint, "scale", Vector2(1.28, 1.28), SNAP_HINT_DURATION)
	tween.parallel().tween_property(hint, "modulate:a", 0.0, SNAP_HINT_DURATION)
	tween.tween_callback(Callable(hint, "queue_free"))

func _create_cross_hint(hint_name: String, color: Color, size: float) -> Node2D:
	var hint := Node2D.new()
	hint.name = hint_name
	hint.z_index = 1
	var horizontal := _create_hint_bar("Horizontal", color, Vector2(size, HINT_THICKNESS), Vector2(-size * 0.5, -HINT_THICKNESS * 0.5))
	var vertical := _create_hint_bar("Vertical", color, Vector2(HINT_THICKNESS, size), Vector2(-HINT_THICKNESS * 0.5, -size * 0.5))
	var center := _create_hint_bar("Center", color, Vector2(HINT_THICKNESS * 1.5, HINT_THICKNESS * 1.5), Vector2(-HINT_THICKNESS * 0.75, -HINT_THICKNESS * 0.75))
	hint.add_child(horizontal)
	hint.add_child(vertical)
	hint.add_child(center)
	return hint

func _create_hint_bar(bar_name: String, color: Color, size: Vector2, position: Vector2) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.color = color
	bar.size = size
	bar.position = position
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _recolor_hint(hint: Node, color: Color) -> void:
	for child in hint.get_children():
		var bar := child as ColorRect
		if bar != null:
			bar.color = color

func _clear_landing_hints() -> void:
	for child in landing_hints.get_children():
		child.queue_free()
	_landing_hint_nodes.clear()

func _landing_key(prefix: String, node: Node) -> String:
	if node != null and is_instance_valid(node):
		return "%s_%s" % [prefix, node.get_instance_id()]
	return "%s_unknown" % prefix

func _get_lane_y_values() -> Array[float]:
	var values: Array[float] = []
	for child in lane_markers.get_children():
		var marker := child as Marker2D
		if marker != null:
			values.append(marker.global_position.y)
	if not values.is_empty():
		return values
	if lane_profile != null and lane_profile.has_method("get_lane_count") and lane_profile.has_method("get_lane_z"):
		for lane_index in range(int(lane_profile.call("get_lane_count"))):
			values.append(float(lane_profile.call("get_lane_z", lane_index)))
	if values.is_empty():
		values.append(unfold_floor_center.global_position.y)
	return values

func _get_lane_count() -> int:
	return _get_lane_y_values().size()

func _get_lane_y(lane_index: int) -> float:
	var lane_values := _get_lane_y_values()
	if lane_values.is_empty():
		return unfold_floor_center.global_position.y
	return lane_values[wrapi(lane_index, 0, lane_values.size())]

func _clamp_room_x(x: float) -> float:
	if lane_profile != null:
		var x_min = lane_profile.get("x_min")
		var x_max = lane_profile.get("x_max")
		if x_min is float and x_max is float:
			return clampf(x, x_min, x_max)
	return x

func _get_nearest_collapse_relocation(point: Vector2) -> Vector2:
	var positions := get_collapse_relocation_positions()
	if positions.is_empty():
		return Vector2(point.x, player_spawn.global_position.y)
	var nearest_position := positions[0]
	var nearest_distance := point.distance_to(nearest_position)
	for position in positions:
		var distance := point.distance_to(position)
		if distance < nearest_distance:
			nearest_position = position
			nearest_distance = distance
	return nearest_position
